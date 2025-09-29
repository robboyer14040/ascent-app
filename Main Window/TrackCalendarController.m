//
//  TrackCalendarController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "TrackCalendarController.h"
#import "CalendarView.h"
#import "Selection.h"
#import "TrackBrowserDocument.h"


@interface TrackCalendarController ()
- (BOOL) _calendarViewActive;
@end


@implementation TrackCalendarController

@synthesize document=_document, selection=_selection;
@synthesize calendarView = _calendarView;

- (void)dealloc {
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    NSDate *calDate = [NSDate date];
    if (_selection.selectedTrack) {
        calDate = _selection.selectedTrack.creationTime;
    }
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.locale   = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // or user’s locale
    fmt.timeZone = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"]; // or nil for system TZ
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    [_calendarView invalidateCache];
    [_calendarView resetWeekStartDay];
    [_calendarView setVisibleMonth:calDate];
    [_calendarView setSelectedDay:calDate];
    [_calendarView setShowsDaysForOtherMonths:YES];
    [_calendarView setTracks:[_document trackArray]];        // @@FIXME@@
    [_calendarView setSelectedTrack:_selection.selectedTrack];
}

- (void)injectDependencies {
    // use _document / _selection as needed
}

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
}


- (void)selectLastImportedTrack:(Track *)lastImportedTrack
{
    /// FIX if (lastImportedTrack && [self calendarViewActive]) {
        NSDate *date = lastImportedTrack.creationTime;

        // Create an NSCalendarDate representing the same instant,
        // without using -dateWithCalendarFormat:timeZone:
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSCalendarDate *calDate =
            [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:date.timeIntervalSinceReferenceDate];
        #pragma clang diagnostic pop

        [_calendarView setVisibleMonth:calDate];
        [_calendarView setSelectedDay:calDate];
   /// FIX }
}

- (void)processCut:(id)sender
{
}

- (void)processCopy:(id)sender
{
}

- (void)processPaste:(id)sender
{
}

- (void)processDelete:(id)sender
{
}

-(void) setContextualMenu:(NSMenu*)menu
{
    [_calendarView setMenu:menu];
}


- (BOOL) _calendarViewActive
{
    /// FIX  return [calOrBrowControl selectedSegment]  == 0;
    return NO;
}


- (NSMutableArray*) prepareArrayOfSelectedTracks
{
    return nil;
}


- (void) updateAfterImport
{
}


- (NSString*) buildSummaryTextOutput:(char)sep
{
    return nil;
}

- (IBAction)importTCX:(id)sender
{
    
}


- (IBAction)importFIT:(id)sender
{
    
}

- (IBAction)importHRM:(id)sender
{
    
}

- (IBAction)importGPX:(id)sender
{
    
}

- (IBAction)exportGPX:(id)sender
{
    
}

- (IBAction)googleEarthFlyBy:(id)sender
{
    
}

- (IBAction)exportKML:(id)sender
{
    
}

- (IBAction)exportTCX:(id)sender
{
    
}

- (IBAction)exportCSV:(id)sender
{
    
}

- (IBAction)exportTXT:(id)sender
{
    
}

- (IBAction)exportSummaryCSV:(id)sender
{
    
}

- (IBAction)exportSummaryTXT:(id)sender
{
    
}

- (IBAction)exportLatLonText:(id)sender
{
    
}

- (IBAction) mailActivity:(id)sender
{
    
}


- (IBAction)saveSelectedTracks:(id)sender
{
    
}


- (IBAction)enrichSelectedTracks:(id)sender
{
    
}


- (IBAction) addActivity:(id)sender
{
    
}


- (IBAction) splitActivity:(id)sender
{
    
}


- (IBAction) compareActivities:(id)sender
{
    
}


- (IBAction) combineActivities:(id)sender
{
    
}


- (IBAction) showActivityDetail:(id)sender
{
    
}


- (IBAction) showMapDetail:(id)sender
{
    
}





@end
