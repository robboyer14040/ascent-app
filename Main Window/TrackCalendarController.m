//
//  TrackCalendarController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "TrackCalendarController.h"


@interface TrackCalendarController ()
- (BOOL) _calendarViewActive;
@end


@implementation TrackCalendarController

@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // set up calendar UI, data sources, etc.
}

- (void)injectDependencies {
    // use _document / _selection as needed
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

        /// FIX [calendarView setVisibleMonth:calDate];
        /// FIX [calendarView setSelectedDay:calDate];
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

@end
