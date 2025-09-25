//
//  TrackListController.m
//  Ascent
//
//  Created by Rob Boyer on 9/24/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "ActivityOutlineView.h"
#import "TrackListController.h"
#import "TrackClipboardSerializer.h"
#import "TrackBrowserDocument.h"
#import "TrackBrowserItem.h"
#import "Track.h"
#import "Lap.h"
#import "Utils.h"


@interface TrackListController()
{
    NSMutableDictionary*            yearItems;
    NSMutableDictionary*            searchItems;
    NSMutableDictionary*            flatBIDict;
    NSDictionary *                  weekAttrs;
    NSDictionary *                  activityAttrs;
    TrackBrowserDocument*           tbDocument;
    NSMutableSet*                   expandedItems;
    NSMutableArray*                 expandedItemNames;
    NSMutableSet*                   selectedItemsAtExpand;
    NSString*                       searchCriteria;
    int                             searchOptions;
    int                             seqno;
    int                             viewType;
    SEL                             itemComparator;
    SEL                             reverseItemComparator;
    BOOL                            isRestoringExpandedState;
}
- (NSMutableDictionary*)outlineDict;
- (TrackBrowserItem*)findStartingTrackItem:(Track*)track dict:(NSDictionary*)dict;
- (NSMutableSet *)selectedItemsAtExpand;
- (void)selectedItemsAtExpand:(NSMutableSet *)set;
- (void)doSetSearchCriteriaToString:(NSString*)s;
- (BOOL) passesSearchCriteria:(Track*)track;
- (BOOL) isSearchUnderway;
- (BOOL) isBrowserEmpty;
- (void) reloadTable;
- (void) handleDoubleClickInOutlineView:(SEL) sel;
- (NSMutableDictionary *)yearItems;
- (NSMutableDictionary *)searchItems;
- (void)resetBrowserTrackRow:(Track*)trk extend:(BOOL)ext;
- (void) resetBrowserSelection;
- (void)selectBrowserRowsForTracks:(NSArray*)trks;

@end


@implementation TrackListController

- (void)dealloc
{
    [_dragRows release];
    [_tracks release];
    [searchCriteria release];
    [searchItems release];
    [yearItems release];
    [weekAttrs release];
    [activityAttrs release];
    [expandedItemNames release];
    [_topSortedKeys release];
    [flatBIDict release];
    [selectedItemsAtExpand release];
    [expandedItems release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    // Drag types + masks
    [_outlineView registerForDraggedTypes:[NSArray arrayWithObject:@"com.montebellosoftware.ascent.tracks"]];
    [_outlineView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
    [_outlineView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

    // Make sure actions reach us
    self.view.nextResponder = self;
    reverseSort = [Utils boolFromDefaults:RCBDefaultBrowserSortInReverse];
    itemComparator          = @selector(compare:);
    reverseItemComparator   = @selector(reverseCompare:);
    yearItems = [NSMutableDictionary dictionary];
    [yearItems retain];
    searchItems = [NSMutableDictionary dictionary];
    [searchItems retain];
    flatBIDict = [[NSMutableDictionary dictionaryWithCapacity:128] retain];
    searchCriteria = [[NSString alloc] initWithString:@""];
    searchOptions = kSearchTitles;
    expandedItems = [[NSMutableSet alloc] init];
    selectedItemsAtExpand = [[NSMutableSet alloc] init];
    _topSortedKeys = nil;
    expandedItemNames = nil;
    isRestoringExpandedState = NO;
    seqno = 0;
    viewType = kViewTypeCurrent;
    NSColor *txtColor = [NSColor redColor];
    NSFont *txtFont = [NSFont boldSystemFontOfSize:14];
    weekAttrs = [NSDictionary dictionaryWithObjectsAndKeys:txtFont,
                 NSFontAttributeName, txtColor, NSForegroundColorAttributeName,  nil];
 
    txtFont = [NSFont boldSystemFontOfSize:12];
    txtColor = [NSColor colorNamed:@"TextPrimary"];
    activityAttrs = [NSDictionary dictionaryWithObjectsAndKeys:txtFont,
                     NSFontAttributeName, txtColor, NSForegroundColorAttributeName,  nil];
    [weekAttrs retain];
    [activityAttrs retain];
}


- (void)buildBrowser:(BOOL)expandLastItem
{
    BOOL searchUnderway = [self isSearchUnderway];
    NSMutableDictionary *topDict = searchUnderway ? [self searchItems] : [self yearItems];

    [expandedItems removeAllObjects];
    [topDict removeAllObjects];

    // Calendar we’ll use for date math; we’ll set its timeZone per-track
    NSCalendar *baseCal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];

    NSMutableArray *trackArray = [tbDocument trackArray];
    NSUInteger numTracks = [trackArray count];

    int timeFormat = [Utils intFromDefaults:RCBDefaultTimeFormat];
    int weekStartDay = [Utils intFromDefaults:RCBDefaultWeekStartDay]; // 0=Sun, 1=Mon (existing behavior)

    // ---------- Formatters (we’ll update timeZone each iteration) ----------
    NSDateFormatter *fmtDay   = [[[NSDateFormatter alloc] init] autorelease];
    NSDateFormatter *fmtLap   = [[[NSDateFormatter alloc] init] autorelease];
    NSDateFormatter *fmtYear  = [[[NSDateFormatter alloc] init] autorelease];
    NSDateFormatter *fmtMonth = [[[NSDateFormatter alloc] init] autorelease];
    NSDateFormatter *fmtWeekD = [[[NSDateFormatter alloc] init] autorelease]; // date inside “Week of …”

    fmtDay.locale = fmtLap.locale = fmtYear.locale = fmtMonth.locale = fmtWeekD.locale = [NSLocale currentLocale];

    // Day (activity) title format
    if (timeFormat == 0) {
        // like “Friday, June 29, 2012 at 03:01:24PM”
        fmtDay.dateFormat = @"EEE, MMM dd, yyyy 'at' hh:mma";
        fmtLap.dateFormat = @"hh:mma";            // shown after “Lap N at ”
    } else {
        // like “Friday, June 29, 2012 at 15:01:24”
        fmtDay.dateFormat = @"EEE, MMM dd, yyyy 'at' HH:mm:ss";
        fmtLap.dateFormat = @"HH:mm:ss";
    }

    // Year & month keys (match “%Y Activities” and “%B '%y”)
    fmtYear.dateFormat  = @"yyyy 'Activities'";
    fmtMonth.dateFormat = @"MMMM ''yy";

    // Date portion used in “Week of …”
    fmtWeekD.dateFormat = @"MMM dd, yyyy";

    ++seqno;

    for (NSUInteger i = 0; i < numTracks; i++) {
        Track *track = [trackArray objectAtIndex:i];

        // Resolve timezone (prefer IANA name, else stored offset)
        NSTimeZone *tz = nil;
        if ([track respondsToSelector:@selector(timeZoneName)]) {
            NSString *tzName = track.timeZoneName;
            if (tzName.length) tz = [NSTimeZone timeZoneWithName:tzName];
        }
        if (!tz) tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];

        if (![self passesSearchCriteria:track]) continue;

        NSDate *trackDate = [track creationTime];
        if (!trackDate) { NSLog(@"nil TRACK CREATION DATE MISSING!"); continue; }

        // Set per-track time zone on calendar & formatters
        NSCalendar *cal = [baseCal copy];
        cal.timeZone = tz;
        fmtDay.timeZone = fmtLap.timeZone = fmtYear.timeZone = fmtMonth.timeZone = fmtWeekD.timeZone = tz;

        // Start-of-day for track date in its zone
        NSDate *startOfDay = [cal startOfDayForDate:trackDate];

        // Components we still need (year/month/day/weekday)
        NSDateComponents *dmwy = [cal components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday)
                                        fromDate:startOfDay];
        NSInteger year  = dmwy.year;
        NSInteger month = dmwy.month;

        // -------- Compute first day of this week (respecting your weekStartDay 0/1) --------
        // Apple weekday: 1=Sun … 7=Sat. Convert to 0..6.
        NSInteger weekdayZero = dmwy.weekday - 1;     // 0=Sun … 6=Sat
        NSInteger offset = ( (weekdayZero - weekStartDay) % 7 + 7 ) % 7; // days since week start
        NSDateComponents *minus = [[[NSDateComponents alloc] init] autorelease];
        minus.day = -offset;
        NSDate *startOfWeek = [cal dateByAddingComponents:minus toDate:startOfDay options:0];

        // -------- Keys/titles (formatted strings) --------
        NSString *yearKey   = [fmtYear  stringFromDate:startOfDay];
        NSString *monthKey  = [fmtMonth stringFromDate:startOfDay];
        NSString *weekHuman = [NSString stringWithFormat:@"Week of %@", [fmtWeekD stringFromDate:startOfWeek]];
        NSString *dayKey    = [fmtDay   stringFromDate:trackDate];

        // Build hierarchy
        NSMutableDictionary *curDict = topDict;
        TrackBrowserItem *yearBI = nil, *monthBI = nil, *weekBI = nil;

        if ((viewType == kViewTypeCurrent) || (viewType == kViewTypeYears)) {
            yearBI = [flatBIDict objectForKey:yearKey];
            if (!yearBI) {
                yearBI = [[[TrackBrowserItem alloc] initWithData:nil
                                                             lap:nil
                                                            name:yearKey
                                                            date:startOfDay
                                                            type:kTypeYear
                                                          parent:nil] autorelease];
                [flatBIDict setObject:yearBI forKey:yearKey];
            } else {
                [yearBI invalidateCache:NO];
            }
            [curDict setObject:yearBI forKey:yearKey];
            curDict = [yearBI children];
            if (yearBI.seqno != seqno) { [curDict removeAllObjects]; yearBI.seqno = seqno; }
        }

        if ((viewType == kViewTypeCurrent) || (viewType == kViewTypeYears) || (viewType == kViewTypeMonths)) {
            monthBI = [flatBIDict objectForKey:monthKey];
            if (!monthBI) {
                monthBI = [[[TrackBrowserItem alloc] initWithData:nil
                                                             lap:nil
                                                            name:monthKey
                                                            date:startOfDay
                                                            type:kTypeMonth
                                                          parent:yearBI] autorelease];
                [flatBIDict setObject:monthBI forKey:monthKey];
            } else {
                [monthBI invalidateCache:NO];
            }
            [curDict setObject:monthBI forKey:monthKey];
            curDict = [monthBI children];
            [monthBI setParentItem:yearBI];
            if (monthBI.seqno != seqno) { [curDict removeAllObjects]; monthBI.seqno = seqno; }
        }

        if ((viewType == kViewTypeCurrent) || (viewType == kViewTypeWeeks)) {
            // Keep cache key unique when week spans years by suffixing year/month unless Weeks view
            NSString *weekKey = weekHuman;
            if (viewType != kViewTypeWeeks) {
                weekKey = [weekKey stringByAppendingFormat:@"_%ld_%ld", (long)year, (long)month];
            }
            weekBI = [flatBIDict objectForKey:weekKey];
            if (!weekBI) {
                weekBI = [[[TrackBrowserItem alloc] initWithData:nil
                                                           lap:nil
                                                          name:weekHuman    // user-visible
                                                          date:startOfWeek
                                                          type:kTypeWeek
                                                        parent:monthBI] autorelease];
                [flatBIDict setObject:weekBI forKey:weekKey];
            } else {
                [weekBI invalidateCache:NO];
            }
            [weekBI setParentItem:monthBI];
            [curDict setObject:weekBI forKey:weekKey];
            curDict = [weekBI children];
            if (weekBI.seqno != seqno) { [curDict removeAllObjects]; weekBI.seqno = seqno; }
        }

        // Activity node (day)
        TrackBrowserItem *activityBI = [flatBIDict objectForKey:dayKey];
        if (!activityBI) {
            activityBI = [[[TrackBrowserItem alloc] initWithData:track
                                                            lap:nil
                                                           name:dayKey
                                                           date:trackDate
                                                           type:kTypeActivity
                                                         parent:weekBI] autorelease];
            [flatBIDict setObject:activityBI forKey:dayKey];
        } else {
            if (track != [activityBI track]) {
                [activityBI invalidateCache:NO];
                [activityBI setTrack:track];
                [activityBI setDate:trackDate];
            }
        }
        [activityBI setParentItem:weekBI];
        [curDict setObject:activityBI forKey:dayKey];
        curDict = [activityBI children];
        if (activityBI.seqno != seqno) { [curDict removeAllObjects]; activityBI.seqno = seqno; }

        // Laps (optional)
        NSMutableDictionary *lapItems = [activityBI children];
        NSArray *laps = [track laps];
        NSUInteger numLaps = [laps count];
        if (numLaps > 0) {
            Lap *firstLap = [laps objectAtIndex:0];
            float lapEndTime = [firstLap startingWallClockTimeDelta] + [track durationOfLap:firstLap];
            if ((numLaps > 1) || (lapEndTime < [track duration])) {
                for (NSUInteger li = 0; li < numLaps; li++) {
                    Lap *lap = [laps objectAtIndex:li];

                    NSString *prefix = (li == (numLaps - 1)) ? @"Finish at " : [NSString stringWithFormat:@"Lap %lu at ", (unsigned long)(li + 1)];
                    NSString *timeStr = [fmtLap stringFromDate:[track lapEndTime:lap]];
                    NSString *label = [prefix stringByAppendingString:timeStr];

                    TrackBrowserItem *child = [[[TrackBrowserItem alloc] initWithData:track
                                                                                  lap:(Lap *)lap
                                                                                 name:label
                                                                                 date:[track lapStartTime:lap]
                                                                                 type:kTypeLap
                                                                               parent:activityBI] autorelease];
                    [lapItems setObject:child forKey:label];
                }
            }
        }

        [cal release]; // we copied baseCal
    }

    [self reloadTable];
    [self resetInfoLabels];
    if (expandLastItem) {
        if (reverseSort) [self expandFirstItem];
        else             [self expandLastItem];
    }
}



-(NSMutableDictionary*) outlineDict
{
    if ([[self searchCriteria] isEqualToString:@""] && ([searchItems count] == 0))
    {
        return yearItems;
    }
    return searchItems;
}

- (BOOL) isSearchUnderway
{
    return  ![searchCriteria isEqualToString:@""];
}


- (BOOL) isBrowserEmpty
{
    NSDictionary* dict;
    if ([self isSearchUnderway])
    {
        dict = [self searchItems];
    }
    else
    {
        dict = [self yearItems];
    }
    return [dict count] == 0;
}

- (void) handleDoubleClickInOutlineView:(SEL) sel
{
    //NSLog(@"dc\n");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TBSelectionDoubleClicked" object:self];
}

- (BOOL) passesSearchCriteria:(Track*)track
{
    BOOL ret = NO;
    if ([searchCriteria isEqualToString:@""] )
    {
        ret = YES;
    }
    else
    {
        if (FLAG_IS_SET(searchOptions, kSearchTitles))
        {
            NSString* name = [track name];
            if (!name)
                name = [track attribute:kName];
            
            NSRange r = [name rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
        }
        if (!ret && (FLAG_IS_SET(searchOptions, kSearchNotes)))
        {
            NSString* s = [track attribute:kNotes];
            NSRange r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
        }
        if (!ret && (FLAG_IS_SET(searchOptions, kSearchActivityType)))
        {
            NSString* s = [track attribute:kActivity];
            NSRange r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
        }
        if (!ret && (FLAG_IS_SET(searchOptions, kSearchEquipment)))
        {
            NSString* s = [track attribute:kEquipment];
            NSRange r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
        }
        if (!ret && (FLAG_IS_SET(searchOptions, kSearchEventType)))
        {
            NSString* s = [track attribute:kEventType];
            NSRange r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
        }
        if (!ret && (FLAG_IS_SET(searchOptions, kSearchKeywords)))
        {
            NSString* s = [track attribute:kKeyword1];
            NSRange r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
            ret = (r.location != NSNotFound);
            if (!ret)
            {
                s = [track attribute:kKeyword2];
                r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
                ret = (r.location != NSNotFound);
            }
            if (!ret)
            {
                s = [track attribute:kKeyword3];
                r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
                ret = (r.location != NSNotFound);
            }
            if (!ret)
            {
                s = [track attribute:kKeyword4];
                r = [s rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
                ret = (r.location != NSNotFound);
            }
        }
    }
    return ret;
}


-(TrackBrowserItem*) findStartingTrackItem:(Track*)track dict:(NSDictionary*)dict
{
    TrackBrowserItem* ret = nil;
    NSEnumerator *enumerator = [dict objectEnumerator];
    TrackBrowserItem* bi = [enumerator nextObject];
    while (bi)
    {
        if (([bi track] == track) && ([bi lap] == nil))
        {
            ret = bi;
        }
        else if ([bi children] != nil)
        {
            ret = [self findStartingTrackItem:track dict:[bi children]];
        }
        if (ret != nil) break;
        bi = [enumerator nextObject];
    }
    return ret;
}


- (NSMutableSet *)selectedItemsAtExpand
{
    return selectedItemsAtExpand;
}


- (void)selectedItemsAtExpand:(NSMutableSet *)set
{
    if (set != selectedItemsAtExpand)
    {
        [selectedItemsAtExpand release];
        selectedItemsAtExpand = [set retain];
    }
}



//---- data source for the OUTLINE VIEW ------------------------------------------------------------

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
        NSMutableDictionary* topDict = [self outlineDict];
        
        if (item == nil)
        {
            NSUInteger numYears = [topDict count];
            if (index < numYears)
            {
                if (!self.topSortedKeys)
                {
                    if (reverseSort == NO)
                        self.topSortedKeys = [topDict keysSortedByValueUsingSelector:itemComparator];
                    else
                        self.topSortedKeys = [topDict keysSortedByValueUsingSelector:reverseItemComparator];
                }
                NSString* key = [self.topSortedKeys objectAtIndex:index];
                TrackBrowserItem* bi = [topDict objectForKey:key];
                return bi;
            }
        }
        else
        {
            TrackBrowserItem* bi = (TrackBrowserItem*) item;
            NSMutableDictionary* dict = [bi children];
            if (dict != nil)
            {
                if (!bi.sortedChildKeys || (bi.sortedChildKeysSeqno != seqno))
                {
                    bi.sortedChildKeysSeqno = seqno;
                    
                    if ((reverseSort == YES) && ([bi type] != kTypeActivity))
                        bi.sortedChildKeys = [dict keysSortedByValueUsingSelector:reverseItemComparator];
                    else
                        bi.sortedChildKeys = [dict keysSortedByValueUsingSelector:itemComparator];
                }
                
                NSUInteger num = [bi.sortedChildKeys count];
                if (num > 0)
                {
                    return [dict objectForKey:[bi.sortedChildKeys objectAtIndex:index]];
                }
            }
        }
    return nil;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (item == nil)
        return NO;
    
    if ([item children] != nil)
    {
        if ([[item children] count] > 0)
        {
            return YES;
        }
    }
    return NO;
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil)
    {
        return [[self outlineDict] count];
    }
    else
    {
        return [[item children] count];
    }
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString* identifier = [tableColumn identifier];
    if (identifier != nil)
    {
        if (item != nil)
        {
            id it = [item valueForKey:identifier];
            return it;
        }
    }
    return @"";
}



- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
    NSDictionary* dict = [notification userInfo];
    TrackBrowserItem* bi = [dict valueForKey:@"NSObject"];
    [bi setExpanded:YES];
    if (!isRestoringExpandedState) [self storeExpandedState];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
    NSDictionary* dict = [notification userInfo];
    TrackBrowserItem* bi = [dict valueForKey:@"NSObject"];
    [bi setExpanded:NO];
    if (!isRestoringExpandedState) [self storeExpandedState];
}


//- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
//                  validateDrop:(id<NSDraggingInfo>)info
//                  proposedItem:(id)item
//            proposedChildIndex:(NSInteger)index
//{
//    NSPasteboard *pboard = [info draggingPasteboard];
//    
//    // Accept any file URLs
//    NSDictionary *opts = @{
//        NSPasteboardURLReadingFileURLsOnlyKey: @YES
//    };
//    
//    if ([pboard canReadObjectForClasses:@[ [NSURL class] ] options:opts]) {
//        return NSDragOperationCopy;
//    }
//    return NSDragOperationNone;
//}


//- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)item childIndex:(int)index
//{
//    [self processFileDrag:info];
//    return YES;
//}
//

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
    NSMutableArray* arr = [NSMutableArray arrayWithCapacity:4];
    NSArray* trackArray = [tbDocument trackArray];
    for (TrackBrowserItem* bi in items)
    {
        if ([bi type] == kTypeActivity)
        {
            NSUInteger idx = [trackArray indexOfObjectIdenticalTo:[bi track]];
            if (idx != NSNotFound)
            {
                [arr addObject:[NSNumber numberWithInt:(int)idx]];
            }
        }
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:arr];
    [pboard declareTypes:[NSArray arrayWithObject:ActivityDragType] owner:self];
    [pboard setData:data forType:ActivityDragType];
    return YES;
}



//-----outline view delegate methods -----------------------------------------------------

- (void)outlineView:(NSOutlineView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn item:(id)item
{
    NSColor* txtColor = nil;
    ///if (aTableView == trackTableView)
    {
        TrackBrowserItem* bi = (TrackBrowserItem*)item;
        if ([bi track] == nil)
        {
            if ([_outlineView isRowSelected:[_outlineView rowForItem:item]] && ([[_outlineView window] firstResponder] == _outlineView))
            {
                txtColor = [NSColor whiteColor];
            }
            else
            {
                switch ([bi type])
                {
                    default:
                        txtColor = [NSColor colorNamed:@"TextPrimary"];
                        break;
                        
                    case kTypeYear:
                        txtColor = [Utils colorFromDefaults:RCBDefaultBrowserYearColor];
                        break;
                        
                    case kTypeMonth:
                        txtColor = [Utils colorFromDefaults:RCBDefaultBrowserMonthColor];
                        break;
                        
                    case kTypeWeek:
                        txtColor = [Utils colorFromDefaults:RCBDefaultBrowserWeekColor];
                        break;
                }
            }
            [aCell setFont:boldLineLargeFont];
        }
        else
        {
            if ([_outlineView isRowSelected:[_outlineView rowForItem:item]] && ([[_outlineView window] firstResponder] == _outlineView))
            {
                txtColor = [NSColor whiteColor];
            }
            switch ([bi type])
            {
                default:
                    if (txtColor == nil) txtColor = [NSColor colorNamed:@"TextPrimary"];
                    [aCell setFont:lineFont];
                    break;
                    
                case kTypeActivity:
                    if (txtColor == nil) txtColor = [Utils colorFromDefaults:RCBDefaultBrowserActivityColor];
                    [aCell setFont:boldLineMediumFont];
                    break;
                    
                case kTypeLap:
                    if (txtColor == nil) txtColor = [Utils colorFromDefaults:RCBDefaultBrowserLapColor];
                    [aCell setFont:boldLineSmallFont];
                    break;
            }
        }
        if (txtColor == nil) txtColor =  [NSColor colorNamed:@"TextPrimary"];
        [aCell setTextColor:txtColor];
        
    }
}


NSString*      gCompareString = nil;         // @@FIXME@@

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn
{
    {
        if (sortColumn == tableColumn)
            reverseSort = !reverseSort;
        else
            reverseSort = NO;
        [Utils setBoolDefault:reverseSort forKey:RCBDefaultBrowserSortInReverse];
        [outlineView setIndicatorImage:nil
                         inTableColumn:sortColumn];
        [outlineView setIndicatorImage: (reverseSort ?
                                         [NSTableView _defaultTableHeaderReverseSortImage] :
                                         [NSTableView _defaultTableHeaderSortImage])
                         inTableColumn: tableColumn];
        
        sortColumn = tableColumn;
        if ([[tableColumn identifier] isEqualToString:@"name"])
            gCompareString = nil;
        else
            gCompareString = [tableColumn identifier];
        
        if ([_outlineView columnUsesStringCompare:[tableColumn identifier]])
        {
            itemComparator          = @selector(compareString:);
            reverseItemComparator   = @selector(reverseCompareString:);
        }
        else
        {
            itemComparator          = @selector(compare:);
            reverseItemComparator   = @selector(reverseCompare:);
        }
        ++seqno;
        [self reloadTable];
        [outlineView deselectAll:self];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
    [expandedItems addObject:item];
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
    [expandedItems removeObject:item];
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    [selectedItemsAtExpand removeAllObjects];
    NSIndexSet* is = [_outlineView selectedRowIndexes];
    NSUInteger idx = [is firstIndex];
    while (idx != NSNotFound)
    {
        [selectedItemsAtExpand addObject:[_outlineView itemAtRow:idx]];
        idx = [is indexGreaterThanIndex:idx];
    }
    [self performSelectorOnMainThread:@selector(doSelChange) withObject:nil waitUntilDone:YES];
}







#pragma mark - Copy / Paste





- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    SEL a = [item action];
    if (a == @selector(copy:)) {
        return [[self _selectedTracks] count] > 0;
    }
    if (a == @selector(paste:)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        return [pb canReadItemWithDataConformingToTypes:[NSArray arrayWithObject:@"com.montebellosoftware.ascent.tracks"]];
    }
    return YES;
}


- (IBAction)cut:(id)sender
{
    [self copy:sender];
    [self storeExpandedState];
    [self delete:sender];
    [self restoreExpandedState];
    [trackTableView deselectAll:sender];
}



- (IBAction)copy:(id)sender
{
    NSArray *sel = [self _selectedTracks];
    if ([sel count] == 0) {
        NSBeep();
        return;
    }
    NSError *err = nil;
    NSString *json = [TrackClipboardSerializer serializeTracksToJSONString:sel error:&err];
    if (json == nil) {
        NSBeep();
        return;
    }
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];

    NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
    [item setData:[json dataUsingEncoding:NSUTF8StringEncoding] forType:@"com.montebellosoftware.ascent.tracks"];

    NSString *names = [[sel valueForKey:@"name"] componentsJoinedByString:@", "];
    if ([names length] == 0) {
        names = @"Tracks";
    }
    [item setString:names forType:NSPasteboardTypeString];

    [pb writeObjects:[NSArray arrayWithObject:item]];
}

- (IBAction)paste:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSPasteboardItem *item = [[pb pasteboardItems] firstObject];
    if (!item) {
        NSBeep();
        return;
    }
    NSData *data = [item dataForType:@"com.montebellosoftware.ascent.tracks"];
    if (!data) {
        NSBeep();
        return;
    }
    NSString *json = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (!json) {
        NSBeep();
        return;
    }
    NSError *err = nil;
    NSArray *tracks = [TrackClipboardSerializer deserializeTracksFromJSONString:json error:&err];
    if (!tracks) {
        NSBeep();
        return;
    }
    [self _importTracks:tracks];
}


- (IBAction)delete:(id)sender
{
    NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
    if ([arr count] > 0)
    {
        [_outlineView deselectAll:self];
        [tbDocument deleteTracks:arr];
        [[_outlineView window] setDocumentEdited:YES];      /// ????
        [tbDocument updateChangeCount:NSChangeDone];
    }
}



#pragma mark - Drag source (lazy payload)

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)ov pasteboardWriterForItem:(id)item
{
    // Provide a writer per dragged row/item
    NSPasteboardItem *pbItem = [[[NSPasteboardItem alloc] init] autorelease];
    Track *t = (Track *)item;
    NSString *name = (t.name != nil) ? t.name : @"Track";
    [pbItem setString:name forType:NSPasteboardTypeString];
    [pbItem setDataProvider:self forTypes:[NSArray arrayWithObject:@"com.montebellosoftware.ascent.tracks"]];
    return pbItem;
}

- (void)outlineView:(NSOutlineView *)ov
     draggingSession:(NSDraggingSession *)session
willBeginAtScreenPoint:(NSPoint)screenPoint
           forItems:(NSArray *)items
{
    // Capture dragged rows
    NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
    NSEnumerator *e = [items objectEnumerator];
    id it = nil;
    while ((it = [e nextObject])) {
        NSInteger r = [ov rowForItem:it];
        if (r != -1) {
            [rows addIndex:(NSUInteger)r];
        }
    }
    [_dragRows release];
    _dragRows = [rows copy];
}

- (void)outlineView:(NSOutlineView *)ov
     draggingSession:(NSDraggingSession *)session
endedAtScreenPoint:(NSPoint)screenPoint
          operation:(NSDragOperation)operation
{
    [_dragRows release];
    _dragRows = nil;
}

- (void)pasteboard:(NSPasteboard *)pasteboard
             item:(NSPasteboardItem *)item
provideDataForType:(NSPasteboardType)type
{
    if (![type isEqualToString:@"com.montebellosoftware.ascent.tracks"]) {
        return;
    }

    NSIndexSet *rows = (_dragRows != nil) ? _dragRows : [_outlineView selectedRowIndexes];
    NSMutableArray *sel = [NSMutableArray array];
    NSUInteger idx = [rows firstIndex];
    while (idx != NSNotFound) {
        id node = [_outlineView itemAtRow:(NSInteger)idx];
        if ([node isKindOfClass:[Track class]]) {
            [sel addObject:node];
        }
        idx = [rows indexGreaterThanIndex:idx];
    }

    NSError *err = nil;
    NSString *json = [TrackClipboardSerializer serializeTracksToJSONString:sel error:&err];
    if (!json) {
        return;
    }
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        [item setData:data forType:@"com.montebellosoftware.ascent.tracks"];
    }
}

#pragma mark - Drag destination

- (NSDragOperation)outlineView:(NSOutlineView *)ov
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index
{
    NSPasteboard *pb = [info draggingPasteboard];
    if ([pb canReadItemWithDataConformingToTypes:[NSArray arrayWithObject:@"com.montebellosoftware.ascent.tracks"]]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov
         acceptDrop:(id<NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)index
{
    NSPasteboard *pb = [info draggingPasteboard];
    NSPasteboardItem *pbItem = [[pb pasteboardItems] firstObject];
    if (!pbItem) {
        return NO;
    }

    NSData *data = [pbItem dataForType:@"com.montebellosoftware.ascent.tracks"];
    if (!data) {
        return NO;
    }

    NSString *json = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (!json) {
        return NO;
    }

    NSError *err = nil;
    NSArray *tracks = [TrackClipboardSerializer deserializeTracksFromJSONString:json error:&err];
    if (!tracks) {
        return NO;
    }

    [self _importTracks:tracks];
    return YES;
}

#pragma mark - Helpers

- (NSArray *)_selectedTracks
{
    NSMutableArray *out = [NSMutableArray array];
    NSIndexSet *rows = [_outlineView selectedRowIndexes];
    NSUInteger i = [rows firstIndex];
    while (i != NSNotFound) {
        id item = [_outlineView itemAtRow:(NSInteger)i];
        if ([item isKindOfClass:[Track class]]) {
            [out addObject:item];
        }
        i = [rows indexGreaterThanIndex:i];
    }
    return out;
}

- (void)_importTracks:(NSArray *)tracks
{
    // Tracks here are deserialized (fresh). Re-key is typically done inside the document’s import.
    NSError *err = nil;
    BOOL ok = [self.document importTracksFromClipboard:tracks error:&err];
    if (!ok) {
        NSBeep();
        return;
    }

    // Refresh data after import (adapt to your fetch path)
    // self.tracks = [self.document fetchTracks];
    // [self.outline reloadData];
}


- (void)resetBrowserTrackRow:(Track*)trk extend:(BOOL)ext
{
    TrackBrowserItem* biOfTrack = [self findStartingTrackItem:trk
                                                         dict:[self outlineDict]];
    NSInteger row = [_outlineView rowForItem:biOfTrack];
    if (row >= 0)
    {
        NSMutableIndexSet* is = [NSMutableIndexSet indexSetWithIndex:row];
        [_outlineView selectRowIndexes:is
                    byExtendingSelection:ext];
    }
}

- (void) resetBrowserSelection
{
    [self resetBrowserTrackRow:currentlySelectedTrack
                        extend:NO];
}


-(void)selectBrowserRowsForTracks:(NSArray*)trks
{
    NSUInteger num = [trks count];
    for (int i=0; i<num; i++)
    {
        [self resetBrowserTrackRow:[trks objectAtIndex:i]
                            extend:(i!=0)];
    }
}



@end
