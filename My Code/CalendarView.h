//
//  CalendarView.h
//  Ascent
//
//  Created by Rob Boyer on 9/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/NSControl.h>

@class NSCalendarDate, NSMutableArray;
@class NSTableHeaderCell, NSTextFieldCell;
@class CalendarView;
@class Track;

#import <AppKit/NSNibDeclarations.h>

@interface NSObject (OACalendarViewDelegate)
- (int)calendarView:(CalendarView *)aCalendarView highlightMaskForVisibleMonth:(NSDate *)visibleMonth;
- (void)calendarView:(CalendarView *)aCalendarView willDisplayCell:(id)aCell forDate:(NSDate *)aDate;	// implement this on the target if you want to be able to set up the date cell. The cell is only used for drawing (and is reused for every date), so you can not, for instance, enable/disable dates by enabling or disabling the cell.
- (BOOL)calendarView:(CalendarView *)aCalendarView shouldSelectDate:(NSDate *)aDate;	// implement this on the target if you need to prevent certain dates from being selected. The target is responsible for taking into account the selection type
- (void)calendarView:(CalendarView *)aCalendarView didChangeVisibleMonth:(NSDate *)aDate;	// implement this on the target if you want to know when the visible month changes
@end


typedef enum _OACalendarViewSelectionType {
    OACalendarViewSelectByDay = 0,		// one day
    OACalendarViewSelectByWeek = 1,		// one week (from Sunday to Saturday) 
    OACalendarViewSelectByWeekday = 2,    	// all of one weekday (e.g. Monday) for a whole month
} OACalendarViewSelectionType;

enum
{
	kMaxDisplayedActivitySummaries = 4,
};

@interface CalendarView : NSControl
{
	NSNumberFormatter*			numberFormatter;
    NSDate *                    visibleMonth;
    NSMutableArray *			selectedDays;
    NSView *					monthAndYearView;
    NSTextFieldCell *			monthAndYearTextFieldCell;
    NSTableHeaderCell *			dayOfWeekCell[7];
    NSTextFieldCell *			dayOfMonthCell;
    NSTextFieldCell *			activitySummaryCell[kMaxDisplayedActivitySummaries];
	NSTextFieldCell *			totalSummaryCell;
	NSMutableArray *			buttons;
	NSArray*					tracks;
	NSArray*					lastClickedTrackArray;
	Track*						selectedTrack;
	NSMutableArray*				selectedTrackInfoArray;
	NSMutableDictionary*		activityDict;
	BOOL						cacheIsValid;
	BOOL						useStatuteUnits;
	BOOL						useTime24;
    int							dayHighlightMask;
	int							trackIndex;
    OACalendarViewSelectionType selectionType;
  	NSImage*					trackDragImage;
    NSInteger                   displayFirstDayOfWeek;
 
    float columnWidth;
    float rowHeight;
    NSRect monthAndYearRect;
    NSRect gridHeaderAndBodyRect;
    NSRect gridHeaderRect;
    NSRect gridBodyRect;
    struct {
        unsigned int showsDaysForOtherMonths:1;
        unsigned int targetProvidesHighlightMask:1;
        unsigned int targetWatchesCellDisplay:1;
        unsigned int targetWatchesVisibleMonth:1;
        unsigned int targetApprovesDateSelection:1;
    } flags;
}
@property(nonatomic, retain) NSImage* trackDragImage;
@property(nonatomic, readonly) NSArray* selectedTrackArray;

- (NSDate *)visibleMonth;
- (void)setVisibleMonth:(NSDate *)aDate;

- (NSDate *)selectedDay;
- (void)setSelectedDay:(NSDate *)newSelectedDay;

- (int)dayHighlightMask;
- (void)setDayHighlightMask:(int)newMask;
- (void)updateHighlightMask;

- (BOOL)showsDaysForOtherMonths;
- (void)setShowsDaysForOtherMonths:(BOOL)value;

- (OACalendarViewSelectionType)selectionType;
- (void)setSelectionType:(OACalendarViewSelectionType)value;

- (NSArray *)selectedDays;

- (void)setTracks:(NSArray *)value;
- (void)setSelectedTrack:(Track*)trk;
- (Track*)selectedTrack;

- (void)resetWeekStartDay;		// reads current setting from preferences and updates calendar

	// Actions
- (IBAction)previousMonth:(id)sender;
- (IBAction)nextMonth:(id)sender;
- (IBAction)previousYear:(id)sender;
- (IBAction)nextYear:(id)sender;

- (void)keyDown:(NSEvent *)theEvent;

- (void)invalidateCache;

@end

// **fixme** move this and implementation into separate files!
@interface NSDate ( GregorianCalendar )

-(NSInteger) monthOfYear;
-(NSInteger) weekOfMonth;
-(NSInteger) dayOfWeek;
-(NSInteger) dayOfMonth;
-(NSInteger) hourOfDay;
-(NSInteger) minuteOfHour;
-(NSInteger) secondOfMinute;
-(NSDate*) firstDayOfMonth;
-(NSDate*) dateByAddingYears:(NSInteger)years months:(NSInteger)months days:(NSInteger)days hours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds;
-(NSDate*) dateByRoundingToHourOfDay:(NSInteger)hour minute:(NSInteger)minute;
-(NSInteger) numberOfDaysInMonth;

@end

