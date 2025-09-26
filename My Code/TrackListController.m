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
#import "Selection.h"
#import "AnimTimer.h"


enum
{
    kTagSearchTitles        = 10,
    kTagSearchNotes         = 11,
    kTagSearchKeywords      = 12,
    kTagSearchActivityType  = 13,
    kTagSearchEquipment     = 14,
    kTagSearchEventType     = 15,
};

@interface NSTableView(SortImages)
+ (NSImage *) _defaultTableHeaderSortImage;
+ (NSImage *) _defaultTableHeaderReverseSortImage;
@end


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
    NSFont*                         lineFont;
    NSFont*                         boldLineLargeFont;
    NSFont*                         boldLineMediumFont;
    NSFont*                         boldLineSmallFont;
    NSTableColumn*                  sortColumn;
    int                             currentTrackPos, numPos;
}
- (void)reloadData;
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
- (void)resetBrowserTrackRow:(Track*)trk extend:(BOOL)ext;
- (void) resetBrowserSelection;
- (void)selectBrowserRowsForTracks:(NSArray*)trks;
- (void)doSetSearchOptions:(int)opts;
- (void)doSetSearchCriteria:(NSString*)s;
- (NSString*)searchCriteria;
- (int)searchOptions;
- (IBAction)setSearchOptions:(id)sender;
- (IBAction)setSearchCriteria:(id)sender;
int searchTagToMask(int searchTag);
- (void)expandFirstItem;
-(void) doSelChange;
- (void)stopAnimations;
- (void)expandLastItem;
-(void) restoreSelectedRowsAfterExpand;
- (void) restoreExpandedState;
-(NSMutableArray*) prepareArrayOfSelectedTracks;
-(NSMutableArray*) prepareArrayOfSelectedBrowserItemsWithTracks;
-(void) addTracksInItem:(TrackBrowserItem*)bi toArray:(NSMutableArray*)arr;
-(void) addBrowserItemsWithTracks:(TrackBrowserItem*)bi toArray:(NSMutableArray*)arr;
-(void)rebuildBrowserAndRestoreState:(Track*)track selectLap:(Lap*)lap;
-(void)resetSelectedTrack:(Track*)trk lap:(Lap*)lap;
@end


@implementation TrackListController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize outlineView = _outlineView;
@synthesize outlineScrollView = _outlineScrollView;


- (void)dealloc
{
    if (_selection != nil) {
        [_selection release];
    }
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
    yearItems = [[NSMutableDictionary dictionary] retain];
    searchItems = [[NSMutableDictionary dictionary] retain];
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
    lineFont = [NSFont fontWithName:@"Lucida Grande" size:11.0];
    [lineFont retain];
    boldLineLargeFont = [NSFont fontWithName:@"Lucida Grande Bold" size:12.0];
    [boldLineLargeFont retain];
    boldLineMediumFont = [NSFont fontWithName:@"Lucida Grande Bold" size:11.0];
    [boldLineMediumFont retain];
    boldLineSmallFont = [NSFont fontWithName:@"Lucida Grande Bold" size:10.0];
    [boldLineSmallFont retain];
    
    // Outline basic setup
    if (_outlineView != nil) {
        _outlineView.dataSource = self;
        _outlineView.delegate = self;
        _outlineView.usesAlternatingRowBackgroundColors = YES;
        _outlineView.autosaveName = @"TrackListOutline";
        _outlineView.floatsGroupRows = YES;
        _outlineView.rowHeight = 20.0;

        // If first column exists, allow it to autosize.
        NSTableColumn *first = nil;
        if (_outlineView.tableColumns.count > 0) {
            first = _outlineView.tableColumns.firstObject;
        }
        if (first != nil) {
            first.resizingMask = NSTableColumnAutoresizingMask;
        }
    }

    // Seed with an empty model snapshot.
    ///[self loadItemsFromDocument];
    [self reloadData];

}


#pragma mark - Dependencies

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];

    // You can react to selection changes here if needed.
}

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    ///[self loadItemsFromDocument];
    [self reloadData];
}

- (void)injectDependencies
{
    // No-op for now. Keep for parity with the rest of the controllers.
}


- (void)reloadData
{
    if (_outlineView == nil) {
        return;
    }
    [_outlineView reloadData];

    // Restore an expanded baseline if you like.
    // [_outlineView expandItem:nil expandChildren:YES];
}

- (void)buildBrowser:(BOOL)expandLastItem
{
    BOOL searchUnderway = [self isSearchUnderway];
    NSMutableDictionary *topDict = searchUnderway ? searchItems : yearItems;

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
   /// [self resetInfoLabels];
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
        dict = searchItems;
    }
    else
    {
        dict = yearItems;
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
    [_outlineView deselectAll:sender];
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
    [self resetBrowserTrackRow:_selection.selectedTrack
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



- (void)doSetSearchCriteria:(NSString*)s
{
   if (s != searchCriteria)
   {
      [searchCriteria release];
      searchCriteria = s;
      [searchCriteria retain];
   }
}


- (NSString*)searchCriteria
{
   return searchCriteria;
}


- (int)searchOptions
{
   return searchOptions;
}


-(void)doSetSearchCriteriaToString:(NSString*)s
{
    if (nil != tbDocument)
    {
        [self storeExpandedState];
        NSString* prevSC = [self searchCriteria];
        if (prevSC != nil)
        {
            [prevSC retain];
            [self doSetSearchCriteria:s];
            if (![prevSC isEqualToString:@""] && [s isEqualToString:@""])
            {
                [searchItems removeAllObjects];
            }
            [self buildBrowser:NO];
            [prevSC release];
        }
        [self restoreExpandedState];
    }
}


- (IBAction)setSearchCriteria:(id)sender
{
//    if ([self calendarViewActive])
//    {
//        [self doToggleCalendarAndBrowser:1];
//    }
    [self doSetSearchCriteriaToString:[sender stringValue]];
}



int searchTagToMask(int searchTag)
{
   switch (searchTag)
   {
      case kTagSearchTitles:
         return kSearchTitles;
         
      case kTagSearchNotes:
         return kSearchNotes;
         
      case kTagSearchKeywords:
         return kSearchKeywords;
      
      case kTagSearchActivityType:
         return kSearchActivityType;

      case kTagSearchEquipment:
         return kSearchEquipment;
     
      case kTagSearchEventType:
          return kSearchEventType;
   }
   return 0;
}
         

- (IBAction)setSearchOptions:(id)sender
{
   NSMenuItem* item = sender;
   [item setState:[item state] == NSControlStateValueOn ? NSControlStateValueOff : NSControlStateValueOn];
   int theTag = (int)[item tag];
   int flags = [self searchOptions];
   BOOL state = [item state];
   int mask = searchTagToMask(theTag);
   if (state == YES)
   {
      SET_FLAG(flags, mask);
   }
   else
   {
      CLEAR_FLAG(flags, mask);
   }
   [self doSetSearchOptions:flags];
   [self buildBrowser:NO];
}


- (void)doSetSearchOptions:(int)opts
{
    [Utils setIntDefault:opts forKey:RCBDefaultSearchOptions];
    searchOptions = opts;
}


- (void)expandFirstItem
{
   int rows = (int)[_outlineView numberOfRows];
   if (rows > 0)
   {
      id item = [_outlineView  itemAtRow:0];
      [_outlineView  expandItem:item];
      int row = 1;
      while (([[item children] count]) != 0)
      {
         item = [_outlineView itemAtRow:row++];
         [_outlineView expandItem:item];
      }
   }
}


- (void)stopAnimations
{
   [[AnimTimer defaultInstance] stop:self];
}


- (void)expandLastItem
{
   int rows = (int)[_outlineView numberOfRows];
   if (rows > 0)
   {
      id item = [_outlineView  itemAtRow:(rows-1)];
      [_outlineView  expandItem:item];
      int row = (int)[_outlineView numberOfRows]-1;
      while (([[item children] count]) != 0)
      {
         item = [_outlineView itemAtRow:row];
         [_outlineView expandItem:item];
         row = (int)[_outlineView numberOfRows]-1;
      }
   }
}


-(void) doSelChange
{
    [self stopAnimations];
    int row = (int)[_outlineView  selectedRow];
    if (row != -1)
    {
        TrackBrowserItem* bi = [_outlineView  itemAtRow:row];
        [self resetSelectedTrack:[bi track] lap:[bi lap]];
    }
    else
    {
        [self resetSelectedTrack:nil
                             lap:nil];
    }
}


-(void) restoreSelectedRowsAfterExpand
{
    NSMutableIndexSet* is = [NSMutableIndexSet indexSet];
    NSSet* localSet = [NSSet setWithSet:selectedItemsAtExpand];
    for (id item in localSet)
    {
        int idx = (int)[_outlineView rowForItem:item];
        if (idx != -1)
        {
            [is addIndex:idx];
        }
    }
    [_outlineView selectRowIndexes:is
                byExtendingSelection:NO];
    
}


- (void) storeExpandedState
{
#if 0
    [expandedItems removeAllObjects];
    int count = [trackTableView numberOfRows];
    [selectedItemsAtExpand removeAllObjects];
    for (int i=0; i<count; i++)
    {
        id item = [trackTableView itemAtRow:i];
        if ([trackTableView isRowSelected:i])
        {
            [selectedItemsAtExpand addObject:item];
        }
        if ([trackTableView isItemExpanded:item])
        {
            [expandedItems addObject:item];
        }
    }
#endif
}


- (void) restoreExpandedState
{
    int num = (int)[expandedItems count];
    if (num == 0) return;
    NSSet* localSet = [NSSet setWithSet:expandedItems];
    for (id item in localSet)
    {
        [_outlineView expandItem:item];
    }
    [self restoreSelectedRowsAfterExpand];
}



// fixme move this to TrackPaneController
-(NSMutableArray*) prepareArrayOfSelectedTracks
{
    NSMutableArray* arr = nil;
//    if ([self calendarViewActive])
//    {
//        if ([calendarView selectedTrack] != nil)
//        {
//            arr = [NSMutableArray arrayWithArray:[calendarView selectedTrackArray]];
//        }
//    }
//    else
    {
            
        NSIndexSet* selSet = [_outlineView selectedRowIndexes];
        arr = [NSMutableArray arrayWithCapacity:[selSet count]];
        NSInteger idx = [selSet firstIndex];
        while (idx != NSNotFound)
        {
            TrackBrowserItem* bi = [_outlineView itemAtRow:idx];
            if (bi != nil)
            {
                [self addTracksInItem:bi
                           toArray:arr];
                
            }
            idx = [selSet indexGreaterThanIndex:idx];
        }
    }
    return arr;
}


-(void) addBrowserItemsWithTracks:(TrackBrowserItem*)bi toArray:(NSMutableArray*)arr
{
   NSMutableDictionary* childDict = [bi children];
   if (childDict != nil)
   {
      NSEnumerator *enumerator = [childDict objectEnumerator];
      id bic;
      while ((bic = [enumerator nextObject]) != nil)
      {
         [self addBrowserItemsWithTracks:bic
                                 toArray:arr];
      }
   }
   Track* track = [bi track];
   if ((track != nil) && ([bi lap] == nil) && ([arr indexOfObjectIdenticalTo:track] == NSNotFound))
   {
      [arr addObject:bi];
   }
}



-(NSMutableArray*) prepareArrayOfSelectedBrowserItemsWithTracks
{
   NSIndexSet* selSet = [_outlineView selectedRowIndexes];
   NSMutableArray* arr = [NSMutableArray arrayWithCapacity:[selSet count]];
   NSInteger idx = [selSet firstIndex];
   while (idx != NSNotFound)
   {
      TrackBrowserItem* bi = [_outlineView itemAtRow:idx];
      if (bi != nil)
      {
         [self addBrowserItemsWithTracks:bi
                                 toArray:arr];
      }
      idx = [selSet indexGreaterThanIndex:idx];
   }
   return arr;
}


-(void)rebuildBrowserAndRestoreState:(Track*)track selectLap:(Lap*)lap;
{
    [self storeExpandedState];
    [self buildBrowser:NO];
    [self restoreExpandedState];
    [self resetSelectedTrack:track
                         lap:lap];
    [self resetBrowserSelection];
}


-(void) reloadTable
{
    self.topSortedKeys = nil;
    [_outlineView reloadData];
//    [metricsEventTable reloadData];
//    //[totalActvitiesField setStringValue:[NSString stringWithFormat:@"%d activities", [[tbDocument trackArray] count]]];
//    //[totalActvitiesField display];
//    if ([self calendarViewActive])
//    {
//        [calendarView invalidateCache];
//        [calendarView setNeedsDisplay:YES];
//    }
}


-(void)resetSelectedTrack:(Track*)trk lap:(Lap*)lap
{

    _selection.selectedTrack = trk;
    _selection.selectedLap = lap;
    [[AnimTimer defaultInstance] setAnimTime:0];
    [tbDocument setCurrentlySelectedTrack:trk];
    [tbDocument setSelectedLap:lap];
    ///[self buildInfoPopupMenus];

        if (_selection.selectedTrack != nil)
        {
            ///[activityDetailButton setEnabled:YES];
            ///[detailedMapButton setEnabled:YES];
            ///[compareActivitiesButton setEnabled:YES];
            ///[self enableControlsRequiringASelectedTrack:YES];
            BOOL hasPoints = [[trk goodPoints] count] > 1;
            ///[transparentMapAnimView setHidden:!hasPoints];
            ///[transparentMiniProfileAnimView setHidden:!hasPoints];
            ///[mapPathView setSelectedLap:currentlySelectedLap];
            ///[miniProfileView setSelectedLap:currentlySelectedLap];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LapSelectionChanged" object:_selection.selectedLap];
            ///[miniProfileView setCurrentTrack:currentlySelectedTrack];
            ///[mapPathView setCurrentTrack:currentlySelectedTrack];
           /// [self syncTrackToAttributesAndEditWindow:_selection.selectedTrack];
            ///[equipmentBox setTrack:trk];
            currentTrackPos = 0;
            _selection.selectedTrack.animTimeBegin = 0.0;
            _selection.selectedTrack.animTimeEnd =  _selection.selectedTrack.movingDuration;
        }
//        else
//        {
            ///[activityDetailButton setEnabled:NO];
            ///[detailedMapButton setEnabled:NO];
//            [compareActivitiesButton setEnabled:NO];
//            [transparentMapAnimView setHidden:YES];
//            [transparentMiniProfileAnimView setHidden:YES];
//            [self enableControlsRequiringASelectedTrack:NO];
//            [miniProfileView setCurrentTrack:nil];
//            [mapPathView setCurrentTrack:nil];
//            [mapPathView setSelectedLap:nil];
//            [miniProfileView setSelectedLap:nil];
//            [self clearAttributes];
//        }
        //[tbDocument selectionChanged];
//        [[AnimTimer defaultInstance] updateTimerDuration];
//        [mapPathView setDefaults];
//        [miniProfileView setNeedsDisplay:YES];
//        [metricsEventTable reloadData];
//        [self rebuildSplitTable];
//        [splitsGraphView setSplitArray:splitArray
//                           splitsTable:splitsTableView];
//        [miniProfileView setSplitArray:splitArray];
//        [mapPathView setSplitArray:splitArray];
        if (_selection.selectedLap)
        {
            float start = [_selection.selectedTrack lapActiveTimeDelta:_selection.selectedLap];
            float end = start + [_selection.selectedTrack movingDurationOfLap:_selection.selectedLap] - 1.0;    // end 1 second before next starts
            //printf("SELECT LAP, lap start:%0.1f end:%01.f\n", start, end);
//            [splitsGraphView setSelectedLapTimes:start
//                                             end:end];
        }
//        else
//        {
////            [splitsGraphView setSelectedLapTimes:-42.0
//                                             end:-43.0];
//        }
//        [splitsGraphView setGraphItem:[Utils intFromDefaults:RCBDefaultSplitGraphItem]];
//        [splitsTableView reloadData];
//    }
}

-(void) addTracksInItem:(TrackBrowserItem*)bi toArray:(NSMutableArray*)arr
{
   NSMutableDictionary* childDict = [bi children];
   if (childDict != nil)
   {
      NSEnumerator *enumerator = [childDict objectEnumerator];
      id bic;
      while ((bic = [enumerator nextObject]) != nil)
      {
         [self addTracksInItem:bic
                       toArray:arr];
      }
   }
   Track* track = [bi track];
   if ((track != nil) && ([bi lap] == nil) && ([arr indexOfObjectIdenticalTo:track] == NSNotFound))
   {
      [arr addObject:track];
   }
}



@end
