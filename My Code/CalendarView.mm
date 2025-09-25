//
//  CalendarView.mm
//  Ascent
//
//  Created by Rob Boyer on 9/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CalendarView.h"
#import "Defs.h"

// Copyright 2001-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "CalendarView.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OmniAppKit/NSImage-OAExtensions.h>
#import <OmniAppKit/NSBezierPath-OAExtensions.h>
#import "Track.h"
#import "Utils.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2006-09-07/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OACalendarView.m 79079 2006-09-07 22:35:32Z kc $")

extern NSString* ActivityDragType;



@implementation NSDate ( GregorianCalendar )

-(NSInteger) monthOfYear
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSMonthCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps month];
}


-(NSInteger) weekOfMonth
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSMonthCalendarUnit | NSWeekCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps weekOfMonth];
}


-(NSInteger) dayOfMonth
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSDayCalendarUnit | NSMonthCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps day];
}


-(NSInteger) dayOfWeek
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSDayCalendarUnit | NSWeekdayCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps weekday];
}


-(NSInteger) hourOfDay
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSHourCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps hour];
}


-(NSInteger) minuteOfHour
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSMinuteCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps minute];
}


-(NSInteger) secondOfMinute
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSSecondCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    return [comps second];
}


-(NSDate*) firstDayOfMonth
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekdayCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    
    [comps setDay:1];
    return [gregorian dateFromComponents:comps];
}



-(NSDate*) dateByAddingYears:(NSInteger)years months:(NSInteger)months days:(NSInteger)days hours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    NSDateComponents* deltaComps = [[[NSDateComponents alloc] init] autorelease];
    [deltaComps setCalendar:gregorian];
    [deltaComps setYear:years];
    [deltaComps setMonth:months];
    [deltaComps setDay:days];
    [deltaComps setHour:hours];
    [deltaComps setMinute:minutes];
    [deltaComps setSecond:seconds];
    NSDate* newDate = [gregorian dateByAddingComponents:deltaComps
                                                 toDate:self
                                                options:0];
    return newDate;
}


-(NSInteger) numberOfDaysInMonth
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    NSRange r = [gregorian rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:self];
    return r.length;
}




-(NSDate*) dateByRoundingToHourOfDay:(NSInteger)hour minute:(NSInteger)minute
{
    NSCalendar *gregorian = [[[NSCalendar alloc]
                              initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* comps = [gregorian components:unitFlags
                                           fromDate:self];
    
    [comps setHour:0];
    [comps setMinute:0];
    [comps setSecond:0];

    return [gregorian dateFromComponents:comps];
}

@end



@interface SelectedTrackInfo : NSObject
{
	Track*		track;
	NSRect		rect;
}
@property (nonatomic, retain) Track* track;
@property (nonatomic) NSRect rect;
@end

@implementation SelectedTrackInfo

@synthesize track;
@synthesize rect;

-(id)initWithTrack:(Track*)trk rect:(NSRect)r
{
	if (self = [super init])
	{
		self.track = trk;
		self.rect = r;
	}
	return self;
}

-(void)dealloc
{
	self.track = nil;
	[super dealloc];
}

- (BOOL)isEqual:(SelectedTrackInfo*)anObject
{
	return (anObject.track == track);
}

@end


//--------------------------------------------------------------------------------------------------------------
//---- ActivityOutlineView -------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------



/*
 Some Notes:
 
 - Setting the View Size: see the notes in -initWithFrame: for some guidelines for determining what size you will want to give this view. Those notes also give information about font sizes and how they affect us and the size calculations. If you set the view size to a non-optimal size, we won't use all the space.
 
 - Dynamically Adjusting the Cell Display: check out the "delegate" method -calendarView:willDisplayCell:forDate: in order to adjust the cell attributes (such as the font color, etc.). Note that if you make any changes which impact the cell size, the calendar is unlikely to draw as desired, so this is mostly useful for color changes. You can also use -calendarView:highlightMaskForVisibleMonth: to get highlighting of certain days. This is more efficient since we need only ask once for the month rather than once for each cell, but it is far less flexible, and currently doesn't allow control over the highlight color used. Also, don't bother to implement both methods: only the former will be used if it is available.
 
 - We should have a real delegate instead of treating the target as the delgate.
 
 - We could benefit from some more configurability: specify whether or not to draw vertical/horizontal grid lines, grid and border widths, fonts, whether or not to display the top control area, whether or not the user can change the displayed month/year independant of whether they can change the selected date, etc.
 
 - We could be more efficient, such as in only calculating things we need. The biggest problem (probably) is that we recalculate everything on every -drawRect:, simply because I didn't see an ideal place to know when we've resized. (With the current implementation, the monthAndYearRect would also need to be recalculated any time the month or year changes, so that the month and year will be correctly centered.)
 */


@interface CalendarView (Private)

- (NSButton *)_createButtonWithFrame:(NSRect)buttonFrame;

- (void)_calculateSizes;
- (void)_drawDaysOfMonthInRect:(NSRect)rect;
- (BOOL)_weeksStartOnMonday;
- (float)_maximumDayOfWeekWidth;
- (NSSize)_maximumDayOfMonthSize;
- (float)_minimumColumnWidth;
- (float)_minimumRowHeight;

- (NSDate *)_hitDateWithLocation:(NSPoint)targetPoint;
- (NSDate *)_hitWeekdayWithLocation:(NSPoint)targetPoint;
-(NSArray*)_activitiesOnDate:(NSDate*)dt;
-(void) _drawActivitiesInCell:(NSArray*)activityArray inFrame:(NSRect)cellFrame  isVisibleMonth:(BOOL)isVisibleMonth;
-(NSRect)rectForActivityAtIndex:(int)idx inFrame:(NSRect)cellFrame twoLineDisplay:(BOOL)twoLineDisplay numShowing:(int)num;
-(BOOL)isTwoLineDisplay:(NSArray*)activityArray inFrame:(NSRect)cellFrame numToShowPtr:(int*)numPtr;
-(BOOL)getHitRow:(NSPoint)targetPoint rowPointer:(int*)rowP columnPointer:(int*)colP;

@end

@interface CalendarView ()
@property(nonatomic, retain) NSMutableArray* selectedTrackInfoArray;
@end


@implementation CalendarView

@synthesize trackDragImage;
@synthesize selectedTrackInfoArray;
@dynamic selectedTrackArray;
const float OACalendarViewButtonWidth = 15.0;
const float OACalendarViewButtonHeight = 15.0;
const float OACalendarViewSpaceBetweenMonthYearAndGrid = 2.0;
const int OACalendarViewNumDaysPerWeek = 7;
const int OACalendarViewMaxNumWeeksIntersectedByMonth = 6;

//
// Init / dealloc
//

- (void) trackClick:(id)sender
{
}

- (id)initWithFrame:(NSRect)frameRect;
{
	useTime24 = [Utils intFromDefaults:RCBDefaultTimeFormat];
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];    

    // The calendar will only resize on certain boundaries. "Ideal" sizes are: 
    //     - width = (multiple of 7) + 1, where multiple >= 22; "minimum" width is 162
    //     - height = (multiple of 6) + 39, where multiple >= 15; "minimum" height is 129
    
    // In reality you can shrink it smaller than the minimums given here, and it tends to look ok for a bit, but this is the "optimum" minimum. But you will want to set your size based on the guidelines above, or the calendar will not actually fill the view exactly.
	
    // The "minimum" view size comes out to be 162w x 129h. (Where minimum.width = 23 [minimum column width] * 7 [num days per week] + 1.0 [for the side border], and minimum.height = 22 [month/year control area height; includes the space between control area and grid] + 17 [the  grid header height] + (15 [minimum row height] * 6 [max num weeks in month]). [Don't need to allow 1 for the bottom border due to the fact that there's no top border per se.]) (We used to say that the minimum height was 155w x 123h, but that was wrong - we weren't including the grid lines in the row/column sizes.)
    // These sizes will need to be adjusted if the font changes, grid or border widths change, etc. We use the controlContentFontOfSize:11.0 for the  - if the control content font is changed our calculations will change and the above sizes will be incorrect. Similarly, we use the default NSTextFieldCell font/size for the month/year header, and the default NSTableHeaderCell font/size for the day of week headers; if either of those change, the aove sizes will be incorrect.
	
    int index;
    NSUserDefaults *defaults;
    NSArray *shortWeekDays;
    NSRect buttonFrame;
    NSButton *button;
    NSBundle *thisBundle;
	cacheIsValid = NO;
	displayFirstDayOfWeek = 0;
    
    
	self.selectedTrackInfoArray = [NSMutableArray arrayWithCapacity:4];
    if ([super initWithFrame:frameRect] == nil)
        return nil;
    
    selectedDays = [[NSMutableArray alloc] init];
    activityDict = [[NSMutableDictionary alloc] init];
	tracks = nil;
    thisBundle = [NSBundle mainBundle];
    monthAndYearTextFieldCell = [[NSTextFieldCell alloc] init];
    NSDateFormatter *monthAndYearFormatter = [[[NSDateFormatter alloc] initWithDateFormat:@"%B %Y" allowNaturalLanguage:NO] autorelease];
    [monthAndYearTextFieldCell setFormatter:monthAndYearFormatter];
	
    defaults = [NSUserDefaults standardUserDefaults];
    //shortWeekDays = [defaults objectForKey:NSShortWeekDayNameArray];
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	shortWeekDays = [formatter shortStandaloneWeekdaySymbols];
	int dayIndex = 0;
	if ([self _weeksStartOnMonday]) dayIndex++;
    for (index = 0; index < OACalendarViewNumDaysPerWeek; index++) {
		
        dayOfWeekCell[index] = [[NSTableHeaderCell alloc] init];
        [dayOfWeekCell[index] setAlignment:NSTextAlignmentCenter];
        [dayOfWeekCell[index] setStringValue:[[shortWeekDays objectAtIndex:dayIndex] substringToIndex:1]];
		dayIndex++;
		if (dayIndex >= OACalendarViewNumDaysPerWeek) dayIndex = 0;
    }
	
    dayOfMonthCell = [[NSTextFieldCell alloc] init];
    [dayOfMonthCell setAlignment:NSTextAlignmentRight];
    [dayOfMonthCell setFont:[NSFont boldSystemFontOfSize:10.0]];
	
	for (int i=0; i<kMaxDisplayedActivitySummaries; i++)
	{
		activitySummaryCell[i] = [[NSTextFieldCell alloc] init];
		[activitySummaryCell[i] setAlignment:NSTextAlignmentLeft];
		[activitySummaryCell[i] setFont:[NSFont boldSystemFontOfSize:8.0]];
		[activitySummaryCell[i] setAction:@selector(trackClick:)];
		[activitySummaryCell[i] setTarget:self];
	}
	totalSummaryCell = [[NSTextFieldCell alloc] init];;
	[totalSummaryCell setAlignment:NSTextAlignmentCenter];
	[totalSummaryCell setFont:[NSFont boldSystemFontOfSize:9.0]];
	
    buttons = [[NSMutableArray alloc] initWithCapacity:2];
	
    monthAndYearView = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, frameRect.size.width, OACalendarViewButtonHeight)] autorelease];
    [monthAndYearView setAutoresizingMask:NSViewWidthSizable];
	
    // Add left/right buttons
	
    buttonFrame = NSMakeRect(0.0, 0.0, OACalendarViewButtonWidth, OACalendarViewButtonHeight);
    button = [self _createButtonWithFrame:buttonFrame];
    [button setImage:[NSImage imageNamed:@"LeftArrow" inBundle:thisBundle]];
    [button setAlternateImage:[NSImage imageNamed:@"LeftArrowPressed" inBundle:thisBundle]];
	
	
	[button setAction:@selector(previousMonth:)];
    [button setAutoresizingMask:NSViewMaxXMargin];
    [monthAndYearView addSubview:button];
	
    buttonFrame = NSMakeRect(frameRect.size.width - OACalendarViewButtonWidth, 0.0, OACalendarViewButtonWidth, OACalendarViewButtonHeight);
    button = [self _createButtonWithFrame:buttonFrame];
    [button setImage:[NSImage imageNamed:@"RightArrow" inBundle:thisBundle]];
    [button setAlternateImage:[NSImage imageNamed:@"RightArrowPressed" inBundle:thisBundle]];
    [button setAction:@selector(nextMonth:)];
    [button setAutoresizingMask:NSViewMinXMargin];
    [monthAndYearView addSubview:button];
	
    [self addSubview:monthAndYearView];
	
	//[self sizeToFit];
	//NSLog(@"frame: %@", NSStringFromRect([self frame]));
	
#if 0
    NSCalendarDate *aDate = [NSCalendarDate calendarDate];
    aDate = [NSCalendarDate dateWithYear:[aDate yearOfCommonEra] month:[aDate monthOfYear] day:[aDate dayOfMonth] hour:12 minute:0 second:0 timeZone:[aDate timeZone]];
#else
    NSDate* aDate = [NSDate date];
#endif
    [self setVisibleMonth:aDate];
    [self setSelectedDay:aDate];
    
	///[self registerForDraggedTypes:[NSArray arrayWithObjects:
	///							   NSFilenamesPboardType, nil]];
	
	numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[numberFormatter setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
	[numberFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
	[numberFormatter setLocale:[NSLocale currentLocale]];
#endif

	NSString* path = [[NSBundle mainBundle] pathForResource:@"TrackDragImage" ofType:@"png"];
	self.trackDragImage = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	[self registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, ActivityDragType, nil]];
	
	
	
	return self;
}



- (void)dealloc;
{
    int index;
    [dayOfMonthCell release];
	
    for (index = 0; index < OACalendarViewNumDaysPerWeek; index++)
        [dayOfWeekCell[index] release];
	
    [monthAndYearTextFieldCell release];
	for (int i=0; i<kMaxDisplayedActivitySummaries; i++)
	{
		[activitySummaryCell[i] release];
	}
	self.selectedTrackInfoArray = nil;
	self.trackDragImage = nil;
	[numberFormatter release];
	[totalSummaryCell release];
    [buttons release];
    [visibleMonth release];
    [selectedDays release];
	[activityDict release];
    [tracks release];
	[lastClickedTrackArray release];
	[selectedTrack release];
    [super dealloc];
}


- (void)resetWeekStartDay
{
	int dayIndex = 0;
	if ([self _weeksStartOnMonday]) dayIndex++;
    //NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    //NSArray* shortWeekDays = [defaults objectForKey:NSShortWeekDayNameArray];
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	NSArray* shortWeekDays = [formatter shortStandaloneWeekdaySymbols];

	for (int index = 0; index < OACalendarViewNumDaysPerWeek; index++) 
	{
        [dayOfWeekCell[index] setStringValue:[[shortWeekDays objectAtIndex:dayIndex] substringToIndex:1]];
		dayIndex++;
		if (dayIndex >= OACalendarViewNumDaysPerWeek) dayIndex = 0;
    }
	[self setNeedsDisplay:YES];
}


//
// NSControl overrides
//

+ (Class)cellClass;
{
    // We need to have an NSActionCell (or subclass of that) to handle the target and action; otherwise, you just can't set those values.
    return [NSActionCell class];
}

- (BOOL)acceptsFirstResponder;
{
	printf("+");
    return YES;
}

- (BOOL)refusesFirstResponder
{
	printf("#");
	return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
{
	return YES;
}

- (void)setEnabled:(BOOL)flag;
{
    unsigned int buttonIndex;
	
    [super setEnabled:flag];
    
    buttonIndex = [buttons count];
    while (buttonIndex--)
        [[buttons objectAtIndex:buttonIndex] setEnabled:flag];
}

- (void)sizeToFit;
{
    NSSize minimumSize;
	
    // we need calculateSizes in order to get the monthAndYearRect; would be better to restructure some of that
    // it would be good to refactor the size calculation (or pass it some parameters) so that we could merely calculate the stuff we need (or have _calculateSizes do all our work, based on the parameters we provide)
    [self _calculateSizes];
	
    minimumSize.height = monthAndYearRect.size.height + gridHeaderRect.size.height + ((OACalendarViewMaxNumWeeksIntersectedByMonth * [self _minimumRowHeight]));
    // This should really check the lengths of the months, and include space for the buttons.
    minimumSize.width = ([self _minimumColumnWidth] * OACalendarViewNumDaysPerWeek) + 1.0;
	
    [self setFrameSize:minimumSize];
    [self setNeedsDisplay:YES];
}


//
// NSView overrides
//

- (BOOL)isFlipped;
{
    return YES;
}

- (void)drawRect:(NSRect)rect;
{
    int columnIndex;
    NSRect tempRect;
    
    [self _calculateSizes];
    
	// for testing, to see if there's anything we're not covering
	//[[NSColor greenColor] set];
	//NSRectFill(gridHeaderAndBodyRect);
	// or...
	//NSRectFill([self bounds]);
    
    // draw the month/year
    [monthAndYearTextFieldCell drawWithFrame:monthAndYearRect inView:self];
    
    // draw the grid header
    tempRect = gridHeaderRect;
    tempRect.size.width = columnWidth;
    for (columnIndex = 0; columnIndex < OACalendarViewNumDaysPerWeek; columnIndex++) {
        [dayOfWeekCell[columnIndex] drawWithFrame:tempRect inView:self];
        tempRect.origin.x += columnWidth;
    }
	
    // draw the grid background
    [[NSColor controlBackgroundColor] set];
    NSRectFill(gridBodyRect);
	
    // fill in the grid
    [self _drawDaysOfMonthInRect:gridBodyRect];
    
    // draw a border around the whole thing. This ends up drawing over the top and right side borders of the header, but that's ok because we don't want their border, we want ours. Also, it ends up covering any overdraw from selected sundays and saturdays, since the selected day covers the bordering area where vertical grid lines would be (an aesthetic decision because we don't draw vertical grid lines, another aesthetic decision).
    [[NSColor gridColor] set];
    NSFrameRect(gridHeaderAndBodyRect);
}


- (void)setLastClickedTrackArray:(id)arr
{
	if (lastClickedTrackArray != arr)
	{
		[lastClickedTrackArray release];
		lastClickedTrackArray = [arr retain];
	}
}


- (void)rightMouseDown:(NSEvent *)mouseEvent
{
	if ([self isEnabled]) 
	{
		NSPoint location = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
		NSDate *hitDate = [self _hitDateWithLocation:location];
		if (hitDate) 
		{
			id target = [self target];
			if (!flags.targetApprovesDateSelection || [target calendarView:self shouldSelectDate:hitDate]) 
			{
				[self setSelectedDay:hitDate];
			}
		}
	}
	[super rightMouseDown:mouseEvent];
}



static BOOL sDragging = NO;

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	sDragging = NO;
}


- (void)mouseDragged:(NSEvent *)mouseEvent
{
	if (!sDragging && selectedTrack)
	{
		int count = selectedTrackInfoArray.count;
		if (count < 1) return;
		sDragging = YES;
		NSPoint location = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
		NSSize dragOffset = NSMakeSize(0.0, 0.0);
		NSSize s = self.trackDragImage.size;
		location.x -= (s.width/2.0);
		location.y += ((s.height * count)/2.0);
		NSPasteboard *pboard;
		
		pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pboard declareTypes:[NSArray arrayWithObject:ActivityDragType] owner:self];
		NSMutableArray* arr = [NSMutableArray arrayWithCapacity:count];
		NSSize imageSize;
		imageSize.width = self.trackDragImage.size.width;
		imageSize.height = count * (self.trackDragImage.size.height + 2.0);
		NSImage* anImage = [[[NSImage alloc] initWithSize:imageSize] autorelease];
		[anImage lockFocus];
		NSPoint p = NSZeroPoint;
		for (SelectedTrackInfo* sti in selectedTrackInfoArray)
		{
			NSUInteger idx = [tracks indexOfObjectIdenticalTo:sti.track];
			if (idx != NSNotFound)
			{
				[arr addObject:[NSNumber numberWithInt:idx]];
				[self.trackDragImage drawAtPoint:p
										fromRect:NSZeroRect
									   operation:NSCompositingOperationSourceOver
										fraction:1.0];
				p.y += (self.trackDragImage.size.height + 2.0);
			}
		}
		[anImage unlockFocus];
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:arr];
		[pboard setData:data forType:ActivityDragType];
		
		[self dragImage:anImage 
					 at:location
				 offset:dragOffset
				  event:mouseEvent 
			 pasteboard:pboard 
				 source:self 
			  slideBack:YES];
	}
}


- (void)mouseUp:(NSEvent *)mouseEvent
{
	if (!sDragging)
	{
		unsigned int modflags = [mouseEvent modifierFlags];
		BOOL shiftMask = (0 != (modflags & NSEventModifierFlagShift));
		if (!shiftMask) 
		{
			Track* lastSelected = selectedTrack;
			int count = selectedTrackInfoArray.count;
			if (selectedTrack && count > 0)
			{
				SelectedTrackInfo* searchSTI = [[[SelectedTrackInfo alloc] initWithTrack:selectedTrack
																					rect:NSZeroRect] autorelease];
				NSUInteger idx = [selectedTrackInfoArray indexOfObject:searchSTI];
				if (idx != NSNotFound)
				{
					SelectedTrackInfo* sti = [[selectedTrackInfoArray objectAtIndex:idx] retain];
					[selectedTrackInfoArray removeAllObjects];
					[selectedTrackInfoArray  addObject:sti];
					[sti autorelease];
				}
				else
				{
					[self setSelectedTrack:nil];
				}
				[self setNeedsDisplay:YES];
				if (lastSelected != selectedTrack)
				{
					NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObject:self
																			   forKey:@"Sender"];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackSelectionChanged" 
																		object:selectedTrack
																	  userInfo:dict];
				}
			}
		}
	}
	sDragging = NO;
}
	


- (void)keyDown:(NSEvent *)theEvent
{
	int kc = [theEvent keyCode];
	if (kc == 49)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
	}
	else if (kc == 51)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteSelectedRows" object:self];
	}
	else
	{
		[super keyDown:theEvent];
	}
}


- (void)mouseDown:(NSEvent *)mouseEvent;
{
    if ([self isEnabled]) 
	{
		if ([mouseEvent clickCount] >= 2)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TBSelectionDoubleClicked" object:self];
		}
		else
		{
			NSPoint location = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
			NSDate *hitDate = [self _hitDateWithLocation:location];
			if (hitDate) 
			{
				id target = [self target];
				if (!flags.targetApprovesDateSelection || [target calendarView:self shouldSelectDate:hitDate]) 
				{
					NSArray* activityArray = [self _activitiesOnDate:hitDate];
					NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObject:self
																				   forKey:@"Sender"];
					BOOL selChanged = NO;
					if (activityArray)
					{
						int num, hitRow, hitColumn;
						BOOL got = [self getHitRow:location
										rowPointer:&hitRow
									 columnPointer:&hitColumn];
						if (got)
						{
							NSRect cellFrame;
							cellFrame.size.height = rowHeight - 1.0f;
							cellFrame.size.width = columnWidth - 1.0f;
							cellFrame.origin.x = gridBodyRect.origin.x + (hitColumn * columnWidth) + 1.0;
							cellFrame.origin.y = gridBodyRect.origin.y + (hitRow * rowHeight) + 1.0;
							
							BOOL twoLineDisplay = [self isTwoLineDisplay:activityArray
																 inFrame:cellFrame
															numToShowPtr:&num];
							BOOL newDay = NO;
							if (lastClickedTrackArray != activityArray)
							{
								newDay = YES;
								[self setLastClickedTrackArray:activityArray];
							}
							for (int i=(num-1); i>=0; i--)
							{
								NSRect afr = [self rectForActivityAtIndex:i
																  inFrame:cellFrame
														   twoLineDisplay:twoLineDisplay
															   numShowing:num];
								if (NSMouseInRect(location, afr, NO) || ((i==0) && newDay))
								{
									Track* trk = [activityArray objectAtIndex:i];
									[self setSelectedTrack:trk];
									
									SelectedTrackInfo* sti = [[[SelectedTrackInfo alloc] initWithTrack:trk
																								  rect:afr] autorelease];
									
									if (![selectedTrackInfoArray containsObject:sti])
									{
										[selectedTrackInfoArray addObject:sti];
									}
									selChanged = YES;
									break;
								}
							}
						}
					}
					else
					{
						[self setLastClickedTrackArray:activityArray];
						[self setSelectedTrack:nil];
						[selectedTrackInfoArray removeAllObjects];
						selChanged = YES;
					}
					///if ([lastClickedTrackArray count] == 0)
					///{
					///	[self setSelectedTrack:nil];
					///	selChanged = YES;
					///}
					if (selChanged) [[NSNotificationCenter defaultCenter] postNotificationName:@"TrackSelectionChanged" 
																						object:selectedTrack
																					  userInfo:dict];
					[self setSelectedDay:hitDate];
					[self setNeedsDisplay:YES];
					//[self setVisibleMonth:hitDate];
					[self sendAction:[self action] to:target];
				}
			}
			else if (selectionType == OACalendarViewSelectByWeekday)
			{
				NSDate *hitWeekday = [self _hitWeekdayWithLocation:location];
				if (hitWeekday) 
				{
					if (!flags.targetApprovesDateSelection || [[self target] calendarView:self shouldSelectDate:hitWeekday]) 
					{
						[self setSelectedDay:hitWeekday];
						[self sendAction:[self action] to:[self target]];
					}
				}
			}
		}
	}
}


//
// API
//

- (NSDate *)visibleMonth;
{
    return visibleMonth;
}

- (void)setVisibleMonth:(NSDate *)aDate;
{
	cacheIsValid = NO;
    [visibleMonth release];
    visibleMonth = [[aDate firstDayOfMonth] retain];
    [monthAndYearTextFieldCell setObjectValue:visibleMonth];
	
    [self updateHighlightMask];
    [self setNeedsDisplay:YES];
    
    if (flags.targetWatchesVisibleMonth)
        [[self target] calendarView:self didChangeVisibleMonth:visibleMonth];
}

- (NSDate *)selectedDay;
{
    return [selectedDays count] ? [selectedDays objectAtIndex:0] : nil;
}

#define DAY_IN_SECONDS 86400

- (void)setSelectedDay:(NSDate *)nsd;
{
	NSDate * newSelectedDay = [nsd dateByAddingYears:0 months:0 days:0 hours:12-[nsd hourOfDay] minutes:-[nsd minuteOfHour] seconds:-[nsd secondOfMinute]];
    
    if ([selectedDays containsObject:newSelectedDay])
        return;
    if (newSelectedDay == nil) {
		[selectedDays removeAllObjects];
        [self setNeedsDisplay:YES];
		return;
    }
    
    if (0 == [selectedDays count]) {
		[selectedDays addObject:newSelectedDay];
        [self setNeedsDisplay:YES];
		return;
    }
    
    NSEvent *event = [NSApp currentEvent];
    unsigned int kflags = [event modifierFlags];
    BOOL shiftMask = (0 != (kflags & NSEventModifierFlagShift));
    BOOL commandMask = (0 != (kflags & NSEventModifierFlagCommand));
    
    NSCalendarDate *startDate = [selectedDays objectAtIndex:0];
    if (shiftMask) {
		
		NSTimeInterval start = [startDate timeIntervalSince1970];
		NSTimeInterval end = [newSelectedDay timeIntervalSince1970];
		
		if (start > end) {
			NSTimeInterval t = end;
			end = start;
			start = t;
		}
		
		[selectedDays removeAllObjects];
		
		while (start <= end ) {
			NSCalendarDate *date = [NSCalendarDate dateWithTimeIntervalSince1970:start];
			[selectedDays addObject:date];
			start+= DAY_IN_SECONDS;
		}
    } else if (commandMask) {
		[selectedDays addObject:newSelectedDay];
    } else {
		[selectedDays removeAllObjects];
		[selectedDays addObject:newSelectedDay];
    }
    
    [self setNeedsDisplay:YES];
}

- (int)dayHighlightMask;
{
    return dayHighlightMask;
}

- (void)setDayHighlightMask:(int)newMask;
{
    dayHighlightMask = newMask;
    [self setNeedsDisplay:YES];
}

- (void)updateHighlightMask;
{
    if (flags.targetProvidesHighlightMask) {
        int mask;
        mask = [[self target] calendarView:self highlightMaskForVisibleMonth:visibleMonth];
        [self setDayHighlightMask:mask];
    } else
        [self setDayHighlightMask:0];
	
    [self setNeedsDisplay:YES];
}

- (BOOL)showsDaysForOtherMonths;
{
    return flags.showsDaysForOtherMonths;
}

- (void)setShowsDaysForOtherMonths:(BOOL)value;
{
    if (value != flags.showsDaysForOtherMonths) {
        flags.showsDaysForOtherMonths = value;
		
        [self setNeedsDisplay:YES];
    }
}

- (OACalendarViewSelectionType)selectionType;
{
    return selectionType;
}

- (void)setSelectionType:(OACalendarViewSelectionType)value;
{
    //OBASSERT((value == OACalendarViewSelectByDay) || (value == OACalendarViewSelectByWeek) || (value == OACalendarViewSelectByWeekday));
    if (selectionType != value) {
        selectionType = value;
		
        [self setNeedsDisplay:YES];
    }
}

- (NSArray *)selectedDays;
{
    if (!selectedDays || [selectedDays count] <= 0 )
        return nil;
	
    NSDate *selectedDay = [self selectedDay];
    
    switch (selectionType) {
        case OACalendarViewSelectByDay:
            return selectedDays;
            break;
            
        case OACalendarViewSelectByWeek:
		{
			NSMutableArray *days;
			NSDate *day;
			int index;
			
			days = [NSMutableArray arrayWithCapacity:OACalendarViewNumDaysPerWeek];
			day = [selectedDay dateByAddingYears:0 months:0 days:-[selectedDay dayOfWeek] hours:0 minutes:0 seconds:0];
			for (index = 0; index < OACalendarViewNumDaysPerWeek; index++)
            {
				NSDate *nextDay = [day dateByAddingYears:0 months:0 days:index hours:0 minutes:0 seconds:0];
				if (flags.showsDaysForOtherMonths || [nextDay monthOfYear] == [selectedDay monthOfYear])
					[days addObject:nextDay];                    
			}
            
			return days;
		}            
            break;
			
        case OACalendarViewSelectByWeekday:
		{
			NSMutableArray *days;
			NSDate *day;
			int index;
			
			days = [NSMutableArray arrayWithCapacity:OACalendarViewMaxNumWeeksIntersectedByMonth];
			day = [selectedDay dateByAddingYears:0 months:0 days:-(([selectedDay weekOfMonth] - 1) * OACalendarViewNumDaysPerWeek) hours:0 minutes:0 seconds:0];
			for (index = 0; index < OACalendarViewMaxNumWeeksIntersectedByMonth; index++) {
				NSDate *nextDay = [day dateByAddingYears:0 months:0 days:(index * OACalendarViewNumDaysPerWeek) hours:0 minutes:0 seconds:0];
				if (flags.showsDaysForOtherMonths || [nextDay monthOfYear] == [selectedDay monthOfYear])
					[days addObject:nextDay];
			}
			
			return days;
		}
            break;
            
        default:
            [NSException raise:NSInvalidArgumentException format:@"OACalendarView: Unknown selection type: %d", selectionType];
            return nil;
            break;
    }
}


//
// Actions
//

- (IBAction)previousMonth:(id)sender;
{
    NSDate *newDate;
	
    newDate = [visibleMonth dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0];
    [self setVisibleMonth:newDate];
}

- (IBAction)nextMonth:(id)sender;
{
    NSDate *newDate;
	
    newDate = [visibleMonth dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
    [self setVisibleMonth:newDate];
}

- (IBAction)previousYear:(id)sender;
{
    NSDate *newDate;
	
    newDate = [visibleMonth dateByAddingYears:-1 months:0 days:0 hours:0 minutes:0 seconds:0];
    [self setVisibleMonth:newDate];
}

- (IBAction)nextYear:(id)sender;
{
    NSDate *newDate;
	
    newDate = [visibleMonth dateByAddingYears:1 months:0 days:0 hours:0 minutes:0 seconds:0];
    [self setVisibleMonth:newDate];
}


- (void)setTracks:(NSArray *)value 
{
    if (tracks != value) 
	{
		cacheIsValid = NO;
        [tracks release];
        tracks = [value retain];
    }
}


- (Track*)selectedTrack
{
	return selectedTrack;
}


- (void)setSelectedTrack:(Track*)trk
{
	if (selectedTrack != trk)
	{
		[selectedTrack release];
		selectedTrack = [trk retain];
	}
}


- (void)invalidateCache
{
	cacheIsValid = NO;
}

// default version of this causes an exception if clicked in a non-column area of the table
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if([theEvent type] == NSEventTypeRightMouseDown || ([theEvent type] == 
											   NSEventTypeLeftMouseDown && ([theEvent modifierFlags] & NSEventModifierFlagControl)))
	{
		return [self menu];
	}
	return nil;
}


@end


@implementation CalendarView (Private)

- (NSButton *)_createButtonWithFrame:(NSRect)buttonFrame;
{
    NSButton *button;
    
    button = [[[NSButton alloc] initWithFrame:buttonFrame] autorelease];
    [button setBezelStyle:NSShadowlessSquareBezelStyle];
    [button setBordered:NO];
    [button setImagePosition:NSImageOnly];
    [button setTarget:self];
    [button setContinuous:YES];
	//    [self addSubview:button];
    [buttons addObject:button];
	
    return button;
}

- (void)setTarget:(id)value;
{
    [super setTarget:value];
    flags.targetProvidesHighlightMask = [value respondsToSelector:@selector(calendarView:highlightMaskForVisibleMonth:)];
    flags.targetWatchesCellDisplay = [value respondsToSelector:@selector(calendarView:willDisplayCell:forDate:)];
    flags.targetApprovesDateSelection = [value respondsToSelector:@selector(calendarView:shouldSelectDate:)];
    flags.targetWatchesVisibleMonth = [value respondsToSelector:@selector(calendarView:didChangeVisibleMonth:)];
}

- (void)_calculateSizes;
{
    NSSize cellSize;
    NSRect viewBounds;
    NSRect topRect;
    NSRect discardRect;
    NSRect tempRect;
	
    viewBounds = [self bounds];
    
    // get the grid cell width (subtract 1.0 from the bounds width to allow for the border)
    columnWidth = floor((viewBounds.size.width - 3.0) / OACalendarViewNumDaysPerWeek);
    viewBounds.size.width = (columnWidth * OACalendarViewNumDaysPerWeek) + 3.0;
    
    // resize the month & year view to be the same width as the grid
    [monthAndYearView setFrameSize:NSMakeSize(viewBounds.size.width, [monthAndYearView frame].size.height)];
	
    // get the rect for the month and year text field cell
    cellSize = [monthAndYearTextFieldCell cellSize];
    NSDivideRect(viewBounds, &topRect, &gridHeaderAndBodyRect, ceil(cellSize.height + OACalendarViewSpaceBetweenMonthYearAndGrid), NSMinYEdge);
    NSDivideRect(topRect, &discardRect, &monthAndYearRect, floor((viewBounds.size.width - cellSize.width) / 2), NSMinXEdge);
    monthAndYearRect.size.width = cellSize.width;
    
    tempRect = gridHeaderAndBodyRect;
    // leave space for a one-pixel border on each side
    tempRect.size.width -= 2.0;
    tempRect.origin.x += 1.0;
    // leave space for a one-pixel border at the bottom (the top already looks fine)
    tempRect.size.height -= 2.0;
    tempRect.origin.y += 1.0;
	
    // get the grid header rect
    cellSize = [dayOfWeekCell[0] cellSize];
    NSDivideRect(tempRect, &gridHeaderRect, &gridBodyRect, ceil(cellSize.height), NSMinYEdge);
    
    // get the grid row height (add 1.0 to the body height because while we can't actually draw on that extra pixel, our bottom row doesn't have to draw a bottom grid line as there's a border right below us, so we need to account for that, which we do by pretending that next pixel actually does belong to us)
//rowHeight = floor((gridBodyRect.size.height + 1.0) / OACalendarViewMaxNumWeeksIntersectedByMonth);
    rowHeight = floor((gridBodyRect.size.height + 0.0) / OACalendarViewMaxNumWeeksIntersectedByMonth);
    
    // get the grid body rect
    gridBodyRect.size.height = (rowHeight * OACalendarViewMaxNumWeeksIntersectedByMonth) - 1.0;
    
    // adjust the header and body rect to account for any adjustment made while calculating even row heights
    gridHeaderAndBodyRect.size.height = NSMaxY(gridBodyRect) - NSMinY(gridHeaderAndBodyRect) + 1.0;
}


- (NSString*) keyFromCalendarDate:(NSDate*)cd
{
	///rcb return [cd descriptionWithCalendarFormat:@"%Y-%m-%d"];
	return [cd descriptionWithCalendarFormat:@"%Y-%m-%d"
                                    timeZone:nil
                                      locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}


- (void)_rebuildCache
{
	[activityDict removeAllObjects];
    //NSCalendarDate* firstDay = [visibleMonth firstDayOfMonth];
    //NSCalendarDate* lastDayPlusOne  = [visibleMonth dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
	int dayOffset = -[visibleMonth dayOfWeek] ;
	if ([self _weeksStartOnMonday]) dayOffset++;
	if (dayOffset > 0) dayOffset -= 7;
	NSDate* firstDay = [visibleMonth dateByAddingYears:0 months:0 days:dayOffset hours:0 minutes:0 seconds:0];
	int days = OACalendarViewMaxNumWeeksIntersectedByMonth * OACalendarViewNumDaysPerWeek;
	NSDate* lastDayPlusOne = [firstDay dateByAddingYears:0 months:0 days:days hours:0 minutes:0 seconds:0];
	firstDay = [firstDay dateByRoundingToHourOfDay:0
											minute:0];
	lastDayPlusOne = [lastDayPlusOne dateByRoundingToHourOfDay:0
														minute:0];
	int num = [tracks count];
	int i;
	for (i=0; i<num; i++)
	{
		Track* trk = [tracks objectAtIndex:i];
		NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[trk secondsFromGMT]];
		NSDate* calDate = [[trk creationTime] dateWithCalendarFormat:nil 
                                                            timeZone:tz];
		
        calDate = [calDate dateByAddingYears:0 months:0 days:0 hours:12-[calDate hourOfDay] minutes:-[calDate minuteOfHour] seconds:-[calDate secondOfMinute]];
		//calDate = [calDate dateByRoundingToHourOfDay:0
		//									  minute:0];
       // calDate = [calDate dateByAddingYears:0 months:0 days:0 hours:12 minutes:0 seconds:0];
		if (([calDate earlierDate:firstDay] == firstDay) &&
			([calDate earlierDate:lastDayPlusOne] == calDate))
		{
			NSString* key = [self keyFromCalendarDate:calDate];
			NSMutableArray* arr = [activityDict objectForKey:key];
			if (arr == nil)
			{
				arr = [NSMutableArray array];
				[activityDict setObject:arr forKey:key];
			}
			[arr addObject:trk];
		}
	}
	cacheIsValid = YES;
}


-(NSArray*)_activitiesOnDate:(NSDate*)dt
{
	if (!cacheIsValid) [self _rebuildCache];
	NSString* key = [self keyFromCalendarDate:dt];
	return [activityDict objectForKey:key];
	
}


#define DAY_OF_MONTH_FRAME_HEIGHT	14
#define ACTIVITY_CELL_2LINE_HEIGHT	22
#define ACTIVITY_CELL_1LINE_HEIGHT	11


- (void)_drawDaysOfMonthInRect:(NSRect)rect;
{
    NSRect cellFrame;
    int visibleMonthIndex;
    NSDate *thisDay;
    int index, row, column;
    NSSize cellSize;
	
    // the cell is actually one pixel shorter than the row height, because the row height includes the bottom grid line (or the top grid line, depending on which way you prefer to think of it)
    cellFrame.size.height = rowHeight - 1.0f;
    // the cell would actually be one pixel narrower than the column width but we don't draw vertical grid lines. instead, we want to include the area that would be grid line (were we drawing it) in our cell, because that looks a bit better under the header, which _does_ draw column separators. actually, we want to include the grid line area on _both sides_ or it looks unbalanced, so we actually _add_ one pixel, to cover that. below, our x position as we draw will have to take that into account. note that this means that sunday and saturday overwrite the outside borders, but the outside border is drawn last, so it ends up ok. (if we ever start drawing vertical grid lines, change this to be - 1.0, and adjust the origin appropriately below.)
    cellFrame.size.width = columnWidth - 1.0f;
	
    cellSize = [dayOfMonthCell cellSize];
   
    visibleMonthIndex = [visibleMonth monthOfYear];
    
    
	int dayOffset = -[visibleMonth dayOfWeek] ;
	if ([self _weeksStartOnMonday]) dayOffset++;
	if (dayOffset > 0) dayOffset -= 7;
		
    thisDay = [visibleMonth dateByAddingYears:0 months:0 days:dayOffset hours:0 minutes:0 seconds:0];
    
    
    useTime24 = [Utils intFromDefaults:RCBDefaultTimeFormat];
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];    
	
	for (row = column = index = 0; index < OACalendarViewMaxNumWeeksIntersectedByMonth * OACalendarViewNumDaysPerWeek; index++) 
	{
		NSColor *textColor;
		BOOL isVisibleMonth = ([thisDay monthOfYear] == visibleMonthIndex);
	
        // subtract 1.0 from the origin because we're including the area where vertical grid lines would be were we drawing them
        cellFrame.origin.x = rect.origin.x + (column * columnWidth) + 1.0;
        cellFrame.origin.y = rect.origin.y + (row * rowHeight) + 1.0;
		
        [dayOfMonthCell setIntValue:[thisDay dayOfMonth]];
  		
		float dayOfMonthFontSize = (isVisibleMonth ? 12.0 : 10.0);
		[dayOfMonthCell setFont:[NSFont boldSystemFontOfSize:dayOfMonthFontSize]];
		
        if (flags.showsDaysForOtherMonths || isVisibleMonth) 
		{
			BOOL shouldHighlightThisDay = NO;
		///	NSCalendarDate* selectedDay = [self selectedDay];
			NSDate* selectedDay = [self selectedDay];
			
  			if (selectedDay)
			{
                // We could just check if thisDay is in [self selectedDays]. However, that makes the selection look somewhat weird when we
                // are selecting by weekday, showing days for other months, and the visible month is the previous/next from the selected day.
                // (Some of the weekdays are shown as highlighted, and later ones are not.)
                // So, we fib a little to make things look better.
                switch (selectionType) 
				{
                    case OACalendarViewSelectByDay:
                        shouldHighlightThisDay = ([selectedDays containsObject:thisDay]);
                        break;
                        
                    case OACalendarViewSelectByWeek:
                        ///fixme rcb!!  shouldHighlightThisDay = [selectedDay isInSameWeekAsDate:thisDay];
                        break;
                        
                    case OACalendarViewSelectByWeekday:
                        shouldHighlightThisDay = ([selectedDay monthOfYear] == visibleMonthIndex && [selectedDay dayOfWeek] == [thisDay dayOfWeek]);
                        break;
                        
                    default:
                        [NSException raise:NSInvalidArgumentException format:@"OACalendarView: Unknown selection type: %d", selectionType];
                        break;
                }
			}
            
#if 0
			if (column == 0) {
				[[NSGraphicsContext currentContext] saveGraphicsState];
				NSBezierPath *clipPath = [NSBezierPath bezierPath]; 
				[clipPath appendBezierPathWithLeftRoundedRectangle:cellFrame withRadius:4.0];
				[clipPath addClip];
			} else if (column == 6) {
				[[NSGraphicsContext currentContext] saveGraphicsState];
				NSBezierPath *clipPath = [NSBezierPath bezierPath]; 
				[clipPath appendBezierPathWithRightRoundedRectangle:cellFrame withRadius:4.0];
				[clipPath addClip];
			}
#endif
			
            if (flags.targetWatchesCellDisplay) 
			{
                [[self target] calendarView:self willDisplayCell:dayOfMonthCell forDate:thisDay];
            } 
			else 
			{
                if ((dayHighlightMask & (1 << index)) == 0) 
				{
                    textColor = (isVisibleMonth ? [NSColor blackColor] : [NSColor grayColor]);
                } 
				else 
				{
                    textColor = [NSColor blueColor];
                }
                [dayOfMonthCell setTextColor:textColor];
            }
			

				//[[NSColor controlHighlightColor] set];
			[[NSColor grayColor] set];
			[NSBezierPath setDefaultLineWidth:1.0];
			[NSBezierPath strokeRect:cellFrame];
			
			if ([dayOfMonthCell drawsBackground]) 
			{
				[[dayOfMonthCell backgroundColor] set];
				[NSBezierPath fillRect:cellFrame];
				[dayOfMonthCell setDrawsBackground:NO];
			}

			NSRect discardRect, dayOfMonthFrame;
			NSArray* activityArray = [self _activitiesOnDate:thisDay];
			if (activityArray)
			{
				[self _drawActivitiesInCell:activityArray
								   inFrame:cellFrame
							 isVisibleMonth:isVisibleMonth];
			}
            //NSDivideRect(cellFrame, &discardRect, &dayOfMonthFrame, floor((cellFrame.size.height - cellSize.height) / 2.0), NSMinYEdge);
            NSDivideRect(cellFrame, &discardRect, &dayOfMonthFrame, DAY_OF_MONTH_FRAME_HEIGHT, NSMaxYEdge);
			[dayOfMonthCell drawInteriorWithFrame:dayOfMonthFrame inView:self];
			
			if (shouldHighlightThisDay && [self isEnabled]) {
				//[[NSColor selectedControlColor] set];
				[[NSColor blackColor] set];
				NSBezierPath *outlinePath = [NSBezierPath bezierPathWithRect:cellFrame];
				[outlinePath setLineWidth:2.0f];
				[outlinePath stroke];
			}
			
#if 0
			if (column == 0 || column == 6) {
				[[NSGraphicsContext currentContext] restoreGraphicsState];
			}
#endif
        }
        
        thisDay = [thisDay dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
        column++;
        if (column > OACalendarViewMaxNumWeeksIntersectedByMonth) {
            column = 0;
            row++;
        }
    }
}


-(NSRect)rectForActivityAtIndex:(int)idx inFrame:(NSRect)cellFrame twoLineDisplay:(BOOL)twoLineDisplay numShowing:(int)num
{
	NSRect fr = cellFrame;
	fr = NSInsetRect(fr, 1.0, 1.0);
	NSRect actFrame;
	NSRect discardRect;
	NSDivideRect(cellFrame, &actFrame, &discardRect, 12, NSMaxYEdge);
	int mult = twoLineDisplay ? 2 : 1;
	int fudge = twoLineDisplay ? -1 : +1;
	int indexFromTop = (num-(idx+1));
	actFrame.origin.y -= 2.0 + (indexFromTop * ((ACTIVITY_CELL_1LINE_HEIGHT*mult)+fudge));
	
	NSRect afr = NSInsetRect(actFrame, 1, 1);
	afr.size.height = twoLineDisplay ? ACTIVITY_CELL_2LINE_HEIGHT-3.0 : ACTIVITY_CELL_1LINE_HEIGHT-1.0;
	afr.origin.y -= (twoLineDisplay ? ACTIVITY_CELL_1LINE_HEIGHT-2.0 : 0.0);
	return afr;
	
}


-(BOOL)isTwoLineDisplay:(NSArray*)activityArray inFrame:(NSRect)cellFrame numToShowPtr:(int*)numPtr
{
	int numCanShow = (cellFrame.size.height-DAY_OF_MONTH_FRAME_HEIGHT)/ACTIVITY_CELL_2LINE_HEIGHT;
	if (numCanShow > kMaxDisplayedActivitySummaries)
	{
		numCanShow = kMaxDisplayedActivitySummaries;
	}
	int numActivities = [activityArray count];
	int num = numActivities;
	BOOL truncatedActivities = NO;
	BOOL twoLineDisplay = YES;
	if (numCanShow < numActivities) 
	{
		twoLineDisplay = NO;
		numCanShow = (cellFrame.size.height-DAY_OF_MONTH_FRAME_HEIGHT)/ACTIVITY_CELL_1LINE_HEIGHT;
		if (numCanShow > kMaxDisplayedActivitySummaries)
		{
			numCanShow = kMaxDisplayedActivitySummaries;
		}
		if (numCanShow < numActivities)
		{
			truncatedActivities = YES;
			num = numCanShow;
		}
	}
	if (numPtr)*numPtr = num;
	return twoLineDisplay;
}


-(void) _drawActivitiesInCell:(NSArray*)activityArray inFrame:(NSRect)cellFrame isVisibleMonth:(BOOL)isVisibleMonth
{
	NSColor* cellFrameColor = isVisibleMonth ? [NSColor selectedControlColor] : [NSColor secondarySelectedControlColor];
	NSRect fr = cellFrame;
	fr = NSInsetRect(fr, 1.0, 1.0);
	[cellFrameColor set];
	[NSBezierPath fillRect:fr];
	
	int num = 0;
	BOOL twoLineDisplay = [self isTwoLineDisplay:activityArray
										 inFrame:cellFrame
									numToShowPtr:&num];
	
	NSRect actFrame;
	NSRect discardRect;
	NSDivideRect(cellFrame, &actFrame, &discardRect, 12, NSMaxYEdge);
	actFrame.origin.y -= 2.0;
	//actFrame.origin.x += 2.0;
	//actFrame.size.width -= 2.0;
	[numberFormatter setMaximumFractionDigits:1];
	for (int i=num-1; i>=0; i--)
	{	
		Track* trk = [activityArray objectAtIndex:i];
		NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[trk secondsFromGMT]];
		NSCalendarDate* calDate = [[trk creationTime] dateWithCalendarFormat:nil 
																	timeZone:tz];
		NSString* s = [calDate descriptionWithCalendarFormat:(useTime24) ? @"%H:%M" : @"%I:%M%p" ];
		NSString* units = useStatuteUnits ?  @"mi" : @"km";
		float dist = [trk distance];
		if (!useStatuteUnits) dist = MilesToKilometers(dist);
		NSString* distString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dist]];
		s = [NSString stringWithFormat:@"%@ %@ %@%@", s, [trk attribute:kActivity], distString, units];
		
		NSRect afr = [self rectForActivityAtIndex:i
										  inFrame:cellFrame
								   twoLineDisplay:twoLineDisplay
									   numShowing:num];
		
		SelectedTrackInfo* sti = [[[SelectedTrackInfo alloc] initWithTrack:trk
																	  rect:afr] autorelease];
		if ([selectedTrackInfoArray containsObject:sti])
		{
			[[NSColor colorWithCalibratedRed:(244.0/255.0) green:(63.0/255.0) blue:(63.0/255.0) alpha:0.4] set];
		}
		else
		{
			if (isVisibleMonth)
			{
				[[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.4] set];
			}
			else
			{
				[[[NSColor selectedKnobColor] colorWithAlphaComponent:0.2] set];
			}
		}
		[activitySummaryCell[i] setTextColor:isVisibleMonth ? [NSColor blackColor]: [NSColor darkGrayColor]];
		NSBezierPath *selRect = [NSBezierPath bezierPath]; 
		[selRect appendBezierPathWithRoundedRectangle:afr 
										   withRadius:4.0];
		[selRect fill];
		[activitySummaryCell[i] setStringValue:s];
		[activitySummaryCell[i] drawInteriorWithFrame:actFrame 
											   inView:self];
		if (twoLineDisplay)
		{
			actFrame.origin.y -= (ACTIVITY_CELL_1LINE_HEIGHT-2);
			s = [trk attribute:kName];
			if ([s isEqualToString:@""])
			{
				s = [trk name];
			}
			[activitySummaryCell[i] setStringValue:s];
			[activitySummaryCell[i] drawInteriorWithFrame:actFrame 
												   inView:self];
		}
		actFrame.origin.y -= (ACTIVITY_CELL_1LINE_HEIGHT+1);
	}
}


- (BOOL)_weeksStartOnMonday
{
	return [Utils intFromDefaults:RCBDefaultWeekStartDay] == 1;
}


- (float)_maximumDayOfWeekWidth;
{
    float maxWidth;
    int index;
	
    maxWidth = 0;
    for (index = 0; index < OACalendarViewNumDaysPerWeek; index++) {
        NSSize cellSize;
		
        cellSize = [dayOfWeekCell[index] cellSize];
        if (maxWidth < cellSize.width)
            maxWidth = cellSize.width;
    }
	
    return ceil(maxWidth);
}

- (NSSize)_maximumDayOfMonthSize;
{
    NSSize maxSize;
    int index;
	
    maxSize = NSZeroSize; // I'm sure the height doesn't change, but I need to know the height anyway.
    for (index = 1; index <= 31; index++) {
        NSString *str;
        NSSize cellSize;
		
        str = [NSString stringWithFormat:@"%d", index];
        [dayOfMonthCell setStringValue:str];
        cellSize = [dayOfMonthCell cellSize];
        if (maxSize.width < cellSize.width)
            maxSize.width = cellSize.width;
        if (maxSize.height < cellSize.height)
            maxSize.height = cellSize.height;
    }
	
    maxSize.width = ceil(maxSize.width);
    maxSize.height = ceil(maxSize.height);
	
    return maxSize;
}

- (float)_minimumColumnWidth;
{
    float dayOfWeekWidth;
    float dayOfMonthWidth;
    
    dayOfWeekWidth = [self _maximumDayOfWeekWidth];	// we don't have to add 1.0 because the day of week cell whose width is returned here includes it's own border
    dayOfMonthWidth = [self _maximumDayOfMonthSize].width + 1.0;	// add 1.0 to allow for the grid. We don't actually draw the vertical grid, but we treat it as if there was one (don't respond to clicks "on" the grid, we have a vertical separator in the header, etc.) 
    return (dayOfMonthWidth > dayOfWeekWidth) ? dayOfMonthWidth : dayOfWeekWidth;
}

- (float)_minimumRowHeight;
{
    return [self _maximumDayOfMonthSize].height + 1.0;	// add 1.0 to allow for a bordering grid line
}

-(BOOL)getHitRow:(NSPoint)targetPoint rowPointer:(int*)rowP columnPointer:(int*)colP
{
    if (NSPointInRect(targetPoint, gridBodyRect) == NO)
        return NO;
	
    NSPoint offset = NSMakePoint(targetPoint.x - gridBodyRect.origin.x, targetPoint.y - gridBodyRect.origin.y);
    // if they exactly hit the grid between days, treat that as a miss
    if ((selectionType != OACalendarViewSelectByWeekday) && (((int)offset.y % (int)rowHeight) == 0))
        return NO;
    // if they exactly hit the grid between days, treat that as a miss
    if ((selectionType != OACalendarViewSelectByWeek) && ((int)offset.x % (int)columnWidth) == 0)
        return NO;
    *rowP = (int)(offset.y / rowHeight);
    *colP = (int)(offset.x / columnWidth);
	return YES;
}

- (NSDate *)_hitDateWithLocation:(NSPoint)targetPoint;
{
#if 0
    
    // rcb 7/6/2013 - not sure what this was about, doesn't work - ??
    
    NSInteger hitDayOfWeek;
    NSInteger targetDayOfMonth;
    
//    if (NSPointInRect(targetPoint, gridHeaderRect) == NO)
    if (NSPointInRect(targetPoint, gridBodyRect) == NO)
        return nil;
    
    offsetX = targetPoint.x - gridHeaderRect.origin.x;
    // if they exactly hit a border between weekdays, treat that as a miss (besides being neat in general, this avoids the problem where clicking on the righthand border would result in us incorrectly calculating that the _first_ day of the week was hit)
    if (((NSInteger)offsetX % (NSInteger)columnWidth) == 0)
        return nil;
    
    hitDayOfWeek = ((NSInteger)(offsetX / columnWidth) + displayFirstDayOfWeek) % OACalendarViewNumDaysPerWeek;
    
	NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDateComponents *thisDayComponents = [calendar components:NSDayCalendarUnit fromDate:visibleMonth];
    [thisDayComponents setDay:-([thisDayComponents day] - 1)];
    NSDate *firstDayOfMonth = [calendar dateByAddingComponents:thisDayComponents toDate:visibleMonth options:NSWrapCalendarComponents];
    NSDateComponents *firstDayComponents = [calendar components:NSWeekdayCalendarUnit fromDate:firstDayOfMonth];
    
    NSInteger firstDayOfWeek = [firstDayComponents weekday];
    if (hitDayOfWeek >= firstDayOfWeek)
        targetDayOfMonth = hitDayOfWeek - firstDayOfWeek + 1;
    else
        targetDayOfMonth = hitDayOfWeek + OACalendarViewNumDaysPerWeek - firstDayOfWeek + 1;
    
    NSDateComponents *targetDayComponent = [[[NSDateComponents alloc] init] autorelease];
    [targetDayComponent setDay:targetDayOfMonth-1];
    return [calendar dateByAddingComponents:targetDayComponent toDate:visibleMonth options:NSWrapCalendarComponents];

#else
    NSPoint offset;
    int firstDayOfWeek, targetDayOfMonth;
	NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDateComponents *thisDayComponents = [calendar components:NSDayCalendarUnit fromDate:visibleMonth];
    [thisDayComponents setDay:-([thisDayComponents day] - 1)];
    NSDate *firstDayOfMonth = [calendar dateByAddingComponents:thisDayComponents toDate:visibleMonth options:NSWrapCalendarComponents];
    firstDayOfWeek = [firstDayOfMonth dayOfWeek];
  	if ([self _weeksStartOnMonday])
		firstDayOfWeek--;
	if (firstDayOfWeek < 0) firstDayOfWeek += 7;
	
    int hitRow, hitColumn;
	BOOL got = [self getHitRow:targetPoint
					rowPointer:&hitRow
				 columnPointer:&hitColumn];
	if (!got) return nil;
//#if 0
    offset = NSMakePoint(targetPoint.x - gridBodyRect.origin.x, targetPoint.y - gridBodyRect.origin.y);
    // if they exactly hit the grid between days, treat that as a miss
    if ((selectionType != OACalendarViewSelectByWeekday) && (((int)offset.y % (int)rowHeight) == 0))
        return nil;
    // if they exactly hit the grid between days, treat that as a miss
    if ((selectionType != OACalendarViewSelectByWeek) && ((int)offset.x % (int)columnWidth) == 0)
        return nil;
    hitRow = (int)(offset.y / rowHeight);
    hitColumn = (int)(offset.x / columnWidth);
//#endif
	
    targetDayOfMonth = (hitRow * OACalendarViewNumDaysPerWeek) + hitColumn - firstDayOfWeek + 1;
    if (!flags.showsDaysForOtherMonths && (targetDayOfMonth < 1 || targetDayOfMonth > [visibleMonth numberOfDaysInMonth]))
        return nil;
	
    return [visibleMonth dateByAddingYears:0 months:0 days:targetDayOfMonth-1 hours:0 minutes:0 seconds:0];
#endif
}

- (NSDate *)_hitWeekdayWithLocation:(NSPoint)targetPoint;
{
    int hitDayOfWeek;
    int firstDayOfWeek, targetDayOfMonth;
    float offsetX;
	
    if (NSPointInRect(targetPoint, gridHeaderRect) == NO)
        return nil;
    
    offsetX = targetPoint.x - gridHeaderRect.origin.x;
    // if they exactly hit a border between weekdays, treat that as a miss (besides being neat in general, this avoids the problem where clicking on the righthand border would result in us incorrectly calculating that the _first_ day of the week was hit)
    if (((int)offsetX % (int)columnWidth) == 0)
        return nil;

    hitDayOfWeek = offsetX / columnWidth;
	
    firstDayOfWeek = [[visibleMonth firstDayOfMonth] dayOfWeek];
    if (hitDayOfWeek >= firstDayOfWeek)
        targetDayOfMonth = hitDayOfWeek - firstDayOfWeek + 1;
    else
        targetDayOfMonth = hitDayOfWeek + OACalendarViewNumDaysPerWeek - firstDayOfWeek + 1;
	
    return [visibleMonth dateByAddingYears:0 months:0 days:targetDayOfMonth-1 hours:0 minutes:0 seconds:0];
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender 
{
    NSPasteboard *pboard;
    pboard = [sender draggingPasteboard];
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) 
		return NSDragOperationCopy;
	else
		return NSDragOperationNone;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender 
{
	NSDictionary* dict = [NSDictionary dictionaryWithObject:sender 
													 forKey:@"infoObj"];
	// the MainWindowController do the heavy lifting
	[[NSNotificationCenter defaultCenter] postNotificationName:@"FilesDraggedIntoApp" 
														object:self
													  userInfo:dict];
    return YES;
}


-(NSArray*)selectedTrackArray
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:selectedTrackInfoArray.count];
	for (SelectedTrackInfo* sti in selectedTrackInfoArray)[arr addObject:sti.track];
	return arr;
}
		
		
@end
