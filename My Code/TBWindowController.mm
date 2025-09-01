 //
//  TBWindowController.mm
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "TBWindowController.h"
#import "TrackBrowserItem.h"
#import "TrackBrowserDocument.h"
#import "Track.h"
#import "TrackPoint.h"
#import "MapPathView.h"
#import "MiniProfileView.h"
#import "MapPoint.h"
#import "Lap.h"
#import "Defs.h"
#import "Utils.h"
#import "ActivityOutlineView.h"
#import "AnimTimer.h"
#import "TransparentMapView.h"
#import "TransparentMapWindow.h"
#import "RegController.h"
#import "BrowserColumnsWindowController.h"
//#import "EditNotesController.h"
#import "TrackDataEntryController.h"
#import "GMTOffsetController.h"
#import "AltSmoothingController.h"
#import "SplitActivityController.h"
#import "DistanceMethodController.h"
#import "TransparentView.h"
#import "ColorBoxView.h"
#import "CalendarView.h"
#import "SplitTableItem.h"
#import "SplitsGraphView.h"
#import "SplitsTableView.h"
#import "ProgressBarController.h"
#import "CustomSplitDistanceController.h"
#import "GarminSyncWindowController.h"
#import "EquipmentSelectorWindowController.h"
#import "EquipmentListWindowController.h"
#import "CompareWindowController.h"
#import "DMWindowController.h"
#import "SGWindowController.h"
#import "EquipmentLog.h"
#import "EquipmentBoxView.h"
#import "StravaAPI.h"
#import "StravaImporter.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

///#import "DBComm.h"

#import <unistd.h>			// for sleep

enum
{
	kCMEmailSelected,
	kCMSaveSelected,
	kCMGoogleFlyBy,
	kCMExportTCX,
	kCMExportGPX,
	kCMExportKML,
	kCMExportCSV,
	kCMExportTXT,
	kCMOpenActivityDetail,
	kCMOpenMapDetail,
	kCMOpenSummary,
	kCMOpenDataDetail,
	kCMCut,
	kCMCopy,
	kCMPaste,
	kCMAdjustGMTOffset,
	kCMAddActivity,
	kCMEditActivity,
	kCMExportSummaryCSV,
	kCMExportSummaryTXT,
	kCMAltitudeSmoothing,
	kCMPublish,
	kCMSplitActivity,
	kCMCombineActivities,
	kCMCompareActivities,
	kCMRefreshMap,
	kCMUploadToMobile,
};


NSString* getTempPath()
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [NSMutableString stringWithString:[paths objectAtIndex:0]];
	path = [path stringByAppendingPathComponent:PROGRAM_NAME];
	[Utils verifyDirAndCreateIfNecessary:path];
	path = [path stringByAppendingPathComponent:@"Temp"];
	[Utils verifyDirAndCreateIfNecessary:path];
	return path;
}


static NSToolbarItem* addToolbarItem(NSMutableDictionary *theDict,NSString *identifier,NSString *label,NSString *paletteLabel,NSString *toolTip,id target,SEL settingSelector, id itemContent,SEL action, NSMenu * menu);


//@implementation EditNotesField
//- (BOOL)becomeFirstResponder
//{
//	[[NSNotificationCenter defaultCenter] postNotificationName:@"EditNotes" object:self];
//	return NO;
//}
//@end



#define NormalSegmentedCellStyle 1
#define FlatSegmentedCellStyle 2



@implementation TBWindow
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
    mouseIsDown = NO;
    return [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];
}

- (void)mouseDown:(NSEvent *)ev
{
    mouseIsDown = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitDragComplete" object:self];
}


- (void)mouseUp:(NSEvent *)ev
{
    mouseIsDown = NO;
    [super mouseUp:ev];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitDragComplete" object:self];
}

-(BOOL) isMouseDown
{
    return mouseIsDown;
}

@end;


@implementation TBSplitView

- (id)initWithFrame:(NSRect)fr
{
    mouseIsDown = NO;
    return [super initWithFrame:fr];
}


- (void)mouseDown:(NSEvent *)ev
{
    mouseIsDown = YES;
    [super mouseDown:ev];   // NSSplitView handles mousedown/drag/up modally
    mouseIsDown = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitDragComplete" object:self];
}


- (void)mouseUp:(NSEvent *)ev
{
    mouseIsDown = NO;
    [super mouseUp:ev];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SplitDragComplete" object:self];
}

-(BOOL) isMouseDown
{
    return mouseIsDown;
}

@end



@interface NSSegmentedCell ( PrivateMethod )
- (void)_setSegmentedCellStyle:(int)style;
//- (void)setSegmentStyle:(int)style;
@end

@implementation FixedSegmentedControl

- (void)awakeFromNib
{
    [self setFrameSize:NSMakeSize([self frame].size.width, 25)];
}


- (NSCell *)cell
{
    id cell = [super cell];
	if ([NSSegmentedCell instancesRespondToSelector:@selector(setSegmentStyle:)]) 
	{
		[cell setSegmentStyle:NSSegmentStyleAutomatic];
    }
	else
	{
		[cell _setSegmentedCellStyle:NSSegmentStyleAutomatic];
    }
	return cell;
}
@end


@interface TextViewWithPlaceholder : NSTextView
{
	BOOL		showPlaceholder;
	NSString*	placeholderText;
	
}
@property (nonatomic, retain) NSString* placeholderText;
@property (nonatomic) BOOL		showPlaceholder;

- (void)drawViewBackgroundInRect:(NSRect)rect;
@end


@implementation TextViewWithPlaceholder


@synthesize placeholderText;
@synthesize showPlaceholder;

- (void) awakeFromNib
{
	self.placeholderText = nil;
	showPlaceholder = YES;
}


-(void)dealloc
{
	self.placeholderText = nil;
	[super dealloc];
}

- (void)drawViewBackgroundInRect:(NSRect)rect
{
	[super drawViewBackgroundInRect:rect];
	NSString* text = [[self textStorage] string];
	if (showPlaceholder && (!text || [text isEqualToString:@""]))
	{
		NSRect dbounds = [self bounds];
		[[self backgroundColor] set];
		[NSBezierPath fillRect:dbounds];
		NSMutableDictionary *fontAttrs = [[[NSMutableDictionary alloc] init] autorelease];
		NSFont* font =  [NSFont fontWithName:@"Lucida Grande" size:12.0];
		[fontAttrs setObject:font forKey:NSFontAttributeName];
		[fontAttrs setObject:[[NSColor blackColor] colorWithAlphaComponent:0.50] forKey:NSForegroundColorAttributeName];
		NSSize size = [placeholderText sizeWithAttributes:fontAttrs];
		float x = dbounds.origin.x + dbounds.size.width/2.0 - size.width/2.0;
		float y = (dbounds.size.height/2.0) - (size.height/2.0);
		[placeholderText drawAtPoint:NSMakePoint(x,y) 
					  withAttributes:fontAttrs];
	}
}

- (BOOL)becomeFirstResponder
{
	showPlaceholder = NO;
	[self setNeedsDisplay:YES];
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	showPlaceholder = YES;
	[self setNeedsDisplay:YES];
	return [super resignFirstResponder];
}


@end


@interface NSAppleScript (HandlerCalls)

- (NSAppleEventDescriptor *) callHandler: (NSString *) handler withArguments: (NSAppleEventDescriptor *) arguments errorInfo: (NSDictionary **) errorInfo;

@end

@implementation NSAppleScript (HandlerCalls)

- (NSAppleEventDescriptor *) callHandler: (NSString *) handler withArguments: (NSAppleEventDescriptor *) arguments errorInfo: (NSDictionary **) errorInfo {
   NSAppleEventDescriptor* event; 
   NSAppleEventDescriptor* targetAddress; 
   NSAppleEventDescriptor* subroutineDescriptor; 
   NSAppleEventDescriptor* result;
   
   /* This will be a self-targeted AppleEvent, so we need to identify ourselves using our process id */
   int pid = [[NSProcessInfo processInfo] processIdentifier];
   targetAddress = [[NSAppleEventDescriptor alloc] initWithDescriptorType: typeKernelProcessID bytes: &pid length: sizeof(pid)];
   
   /* Set up our root AppleEvent descriptor: a subroutine call (psbr) */
   event = [[NSAppleEventDescriptor alloc] initWithEventClass: 'ascr' eventID: 'psbr' targetDescriptor: targetAddress returnID: kAutoGenerateReturnID transactionID: kAnyTransactionID];
   
   /* Set up an AppleEvent descriptor containing the subroutine (handler) name */
   subroutineDescriptor = [NSAppleEventDescriptor descriptorWithString: handler];
   [event setParamDescriptor: subroutineDescriptor forKeyword: 'snam'];
   
   /* Add the provided arguments to the handler call */
   [event setParamDescriptor: arguments forKeyword: keyDirectObject];
   
   /* Execute the handler */
   result = [self executeAppleEvent: event error: errorInfo];
   
   [targetAddress release];
   [event release];
   
   return result;
}

@end



@interface NSTableView(SortImages)
+ (NSImage *) _defaultTableHeaderSortImage;
+ (NSImage *) _defaultTableHeaderReverseSortImage;
@end


//--------------------------------------------------------------------------------------------------------------------
//---- TBWindowController --------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------


@interface TBWindowController ()
- (NSMutableDictionary*)outlineDict;
- (TrackBrowserItem*)findStartingTrackItem:(Track*)track dict:(NSDictionary*)dict;
- (NSMutableSet *)selectedItemsAtExpand;
- (void)selectedItemsAtExpand:(NSMutableSet *)set;
- (BOOL) calendarViewActive;
-(void)doSetSearchCriteriaToString:(NSString*)s;
- (BOOL) passesSearchCriteria:(Track*)track;
- (BOOL) isSearchUnderway;
- (BOOL) isBrowserEmpty;
- (void) reloadTable;
- (void) handleDoubleClickInOutlineView:(SEL) sel;
- (void) startProgressIndicator:(NSString*)text;
- (void) updateProgressIndicator:(NSString*)msg;
- (void) endProgressIndicator;
- (void) doGPXImportWithProgress:(NSArray*)files;
- (void) doHRMImportWithProgress:(NSArray*)files;
- (void) doFITImportWithProgress:(NSArray*)files;
- (void) processFileDrag:(id < NSDraggingInfo >)info;
- (void)addDataFromFiles:(NSArray*) files;
- (void) postActivityImportLimitExeeded;
- (void) refreshMap:(id)sender;
- (void) selectLastImportedTrack:(Track*)lastImportedTrack;
-(void) updateCurrentTrackRow;
-(void)dismissCompareWindow:(id)sender;
-(void)dismissDetailedMapWindow:(id)sender;
- (void)doToggleCalendarAndBrowser:(int)v;
- (void)splitDragComplete:(NSNotification *)notification;
@end


@implementation TBWindowController

@synthesize topSortedKeys;


#define kIsPopup     0x00000001
#define kIsTextView  0x00000002


- (void) resetInfoLabels
{
   [customTextFieldLabel setStringValue:[Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
   [keyword1PopupLabel setStringValue:[Utils stringFromDefaults:RCBDefaultKeyword1Label]];
   [keyword2PopupLabel setStringValue:[Utils stringFromDefaults:RCBDefaultKeyword2Label]];
}



- (void) rebuildSplitOptionsMenu
{
	// menu is retained by various views using it, no need to release/retain it here
	splitOptionsMenu = [Utils buildSplitOptionsMenu:&splitLengthSubMenu
									   graphSubMenu:&splitGraphSubMenu];
	[splitOptionsControl setMenu:splitOptionsMenu
					  forSegment:0];
	[splitsTableView setMenu:splitOptionsMenu];
	[splitsGraphView setMenu:splitOptionsMenu];
}


- (void)prefChange:(NSNotification *)notification
{
	float v = [Utils floatFromDefaults:RCBDefaultMapTransparency];
	reverseSort = [Utils boolFromDefaults:RCBDefaultBrowserSortInReverse];
	[mapPathView setMapOpacity:v];
	//[mapOpacitySlider setFloatValue:v];
	v = [Utils floatFromDefaults:RCBDefaultPathTransparency];
	[mapPathView setPathOpacity:v];
	int idx = [Utils intFromDefaults:RCBDefaultMapType];
	//[mapDataTypePopup selectItemAtIndex:idx];
	[mapPathView setDataType:[Utils mapIndexToType:idx]];
	[mapPathView setShowIntervalMarkers:[Utils boolFromDefaults:RCBDefaultShowIntervalMarkers]];
	[mapPathView setIntervalIncrement:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	[mapPathView setScrollWheelSensitivity:[Utils floatFromDefaults:RCBDefaultScrollWheelSensitivty]];
	[mapPathView setNeedsDisplay:YES];

	[miniProfileView setNeedsDisplay:YES];
	[splitsTableView setNeedsDisplay:YES];
	[splitsGraphView setNeedsDisplay:YES];
	[trackTableView reloadData];
	[metricsEventTable reloadData];
	[weightUnitsField setStringValue:[Utils usingStatute] ? @"(lbs)" : @"(kg)"];
	if (currentlySelectedTrack != nil)
	{
		[self syncTrackToAttributesAndEditWindow:currentlySelectedTrack];
	}
	[self rebuildSplitOptionsMenu];
	[calendarView resetWeekStartDay];
}

- (void)resetBrowserTrackRow:(Track*)trk extend:(BOOL)ext
{
	TrackBrowserItem* biOfTrack = [self findStartingTrackItem:trk 
														 dict:[self outlineDict]];
    NSInteger row = [trackTableView rowForItem:biOfTrack];
	if (row >= 0)
	{
		NSMutableIndexSet* is = [NSMutableIndexSet indexSetWithIndex:row];
		[trackTableView selectRowIndexes:is
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


- (void)undoRedoCompleted:(NSNotification *)notification
{
}

- (id)initWithDocument:(TrackBrowserDocument*)doc
{
#if DEBUG_LEAKS
	NSLog(@"TBWindowController init,  doc:%x self:%x\n", doc, self);
#endif
	self = [super initWithWindowNibName:@"TrackBrowserDocument"];
	equipmentListWC = nil;
	yearItems = [NSMutableDictionary dictionary];
	[yearItems retain];
	searchItems = [NSMutableDictionary dictionary];
	[searchItems retain];
	flatBIDict = [[NSMutableDictionary dictionaryWithCapacity:128] retain];
	searchCriteria = [[NSString alloc] initWithString:@""];
	searchOptions = kSearchTitles;
	expandedItems = [[NSMutableSet alloc] init];
	splitArray = [[NSMutableArray alloc] init];
	selectedItemsAtExpand = [[NSMutableSet alloc] init];
	splitOptionsMenu = nil;
	tbDocument = doc;
	viewType = kViewTypeCurrent;
	isRestoringExpandedState = NO;
	currentlySelectedTrack = nil;
	currentlySelectedLap = nil;
	sortColumn = nil;
	searchMenu = nil;
	topSortedKeys = nil;
	itemComparator          = @selector(compare:);
	reverseItemComparator   = @selector(reverseCompare:);
	seqno = 0;
	equipmentListWC = nil;
	compareWC = nil;
    dmWC = nil;
    sgWC = nil;
    expandedItemNames = nil;
 	NSRect dummy;
	dummy.size.width = 10;
	dummy.size.height = 10;
	dummy.origin.x = 0;
	dummy.origin.y = 0;

#if 0
    transparentMapWindow = [[[TransparentMapWindow alloc] initWithContentRect:dummy
																  styleMask:NSWindowStyleMaskBorderless
																	backing:NSBackingStoreBuffered 
																	  defer:NO] retain];
#else
    NSWindowStyleMask style = NSWindowStyleMaskBorderless; // combine with | if needed
    transparentMapWindow = [[[TransparentMapWindow alloc] initWithContentRect:dummy
                                                                    styleMask:style
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:NO] retain]; // omit retain under ARC
#endif
    
	transparentMapAnimView = [[TransparentMapView alloc] initWithFrame:dummy
															   hasHUD:NO];
	[transparentMapWindow setContentView:transparentMapAnimView];

#if 0
    transparentMiniProfileWindow = [[[TransparentMapWindow alloc] initWithContentRect:dummy
																  styleMask:NSWindowStyleMaskBorderless
																	backing:NSBackingStoreBuffered 
																	  defer:NO] retain];
#else
    transparentMiniProfileWindow = [[[TransparentMapWindow alloc] initWithContentRect:dummy
                                                                  styleMask:NSWindowStyleMaskBorderless
                                                                    backing:NSBackingStoreBuffered
                                                                      defer:NO] retain];
#endif
	transparentMiniProfileAnimView = [[TransparentMapView alloc] initWithFrame:dummy
																	   hasHUD:NO];
	[transparentMiniProfileWindow setContentView:transparentMiniProfileAnimView];

	NSColor *txtColor = [NSColor redColor];
	NSFont *txtFont = [NSFont boldSystemFontOfSize:14];
	weekAttrs = [NSDictionary dictionaryWithObjectsAndKeys:txtFont,
	  NSFontAttributeName, txtColor, NSForegroundColorAttributeName,  nil];

	txtFont = [NSFont boldSystemFontOfSize:12];
	txtColor = [NSColor blackColor];
	activityAttrs = [NSDictionary dictionaryWithObjectsAndKeys:txtFont,
	  NSFontAttributeName, txtColor, NSForegroundColorAttributeName,  nil];
	reverseSort = [Utils boolFromDefaults:RCBDefaultBrowserSortInReverse];
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
	return self;
}


- (void)dealloc
{
#if DEBUG_LEAKS
	NSLog(@"tbwc BEGIN DEALLOC");
#endif
	[self dismissCompareWindow:self];
	[self dismissDetailedMapWindow:self];
	[metricsEventTable setDelegate:nil];
	[metricsEventTable setDataSource:nil];
	[splitsTableView setDelegate:nil];
	[splitsTableView setDataSource:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:tbDocument];
	[[NSNotificationCenter defaultCenter] removeObserver:calendarView];
	[[NSNotificationCenter defaultCenter] removeObserver:splitsTableView];
	[[NSNotificationCenter defaultCenter] removeObserver:splitsGraphView];
	[[NSNotificationCenter defaultCenter] removeObserver:trackTableView];
	[[NSNotificationCenter defaultCenter] removeObserver:metricsEventTable];
	if (equipmentListWC) 
	{
		[[NSNotificationCenter defaultCenter] removeObserver:equipmentListWC];
		[equipmentListWC dismiss:self];
	}
    [expandedItemNames release];
	[topSortedKeys release];
	[flatBIDict release];
	[equipmentListWC release];
	[trackTableView prepareToDie];
	[splitsTableView prepareToDie];
	[searchMenu release];
	[lineFont release];
	[selectedItemsAtExpand release];
	[mapViewDataTypeSubMenu release];
	[browserViewSubMenu release];
    [toolbarItems release];
 	[boldLineLargeFont release];
	[boldLineMediumFont release];
	[boldLineSmallFont release];
	[searchCriteria release];
	[searchItems release];
	[yearItems release];
	[weekAttrs release];
	[activityAttrs release];
	// [transparentMapWindow release]; don't need because setReleasedWhenClosed is set to "YES"
	[transparentMapAnimView release];
	//[transparentMiniProfileWindow release];   don't need because setReleasedWhenClosed is set to "YES" 
	[transparentMiniProfileAnimView release];
	[mapPathView prepareToDie];
	[mapPathView killAnimThread];
	[expandedItems release];
	[splitArray release];
	[currentlySelectedLap release];
	[currentlySelectedTrack release];
	[super dealloc];
#if DEBUG_LEAKS
	NSLog(@"tbwc END DEALLOC");
#endif
}


- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
	// workaround for cocoa bug -- crash when removing search field from toolbar
	//id obj = [[notification userInfo] objectForKey:@"item"];
	//if ([[obj itemIdentifier] isEqualTo:@"SearchBrowser"])
	//{
	//	printf("before remove, rc:%d\n", [searchMenu retainCount]);
	//	[[searchField cell] setSearchMenuTemplate:nil];
	//	printf("after remove, rc:%d\n", [searchMenu retainCount]);
	//}
}


- (void)toolbarWillAddItem:(NSNotification *)notification
{
	// workaround for cocoa bug -- crash when removing search field from toolbar
	//id obj = [[notification userInfo] objectForKey:@"item"];
	//if ([[obj itemIdentifier] isEqualTo:@"SearchBrowser"])
	//{
	//	printf("before add, rc:%d\n", [searchMenu retainCount]);
	//	[[searchField cell] setSearchMenuTemplate:searchMenu];
	//	printf("after add, rc:%d\n", [searchMenu retainCount]);
	//}
}


- (void) doSetViewType:(int)vt
{
	viewType = vt;
	[Utils setIntDefault:viewType forKey:RCBDefaultBrowserViewType];
	[Utils selectMenuItem:vt
				  forMenu:browserViewSubMenu];
	if (![self calendarViewActive]) [self buildBrowser:(viewType == kViewTypeCurrent)];
}   


// update the lines in the gui showing the track, but don't invalidate stat caches
// useful for things like 'equipment items' that don't use caching.
- (void)simpleUpdateBrowserTrack:(Track*)track
{
    NSInteger numRows = [trackTableView numberOfRows];
	for (int i=0; i<numRows; i++)
	{
		TrackBrowserItem* tbi = [trackTableView itemAtRow:i];
		if ([tbi track] == track)
		{
			[trackTableView setNeedsDisplayInRect:[trackTableView rectOfRow:i]];
			///printf("updating row %d\n", i);
			while (TrackBrowserItem* parentItem = [tbi parentItem])
			{
				[parentItem invalidateCache:NO];
                NSInteger sr = [trackTableView rowForItem:parentItem];
				[trackTableView setNeedsDisplayInRect:[trackTableView rectOfRow:sr]];
				///printf("updating (parent) row %d\n", sr);
				tbi = parentItem;
			}
		}
	}
}


- (void)trackChanged:(NSNotification *)notification
{
	Track* track = [notification object];
	///[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:track];
    NSInteger numRows = [trackTableView numberOfRows];
	for (int i=0; i<numRows; i++)
	{
		TrackBrowserItem* tbi = [trackTableView itemAtRow:i];
		if ([tbi track] == track)
		{
			[track invalidateStats];
			[tbi invalidateCache:YES];
			[trackTableView setNeedsDisplayInRect:[trackTableView rectOfRow:i]];
			///printf("updating row %d\n", i);
			while (TrackBrowserItem* parentItem = [tbi parentItem])
			{
				[parentItem invalidateCache:NO];
                NSInteger sr = [trackTableView rowForItem:parentItem];
				[trackTableView setNeedsDisplayInRect:[trackTableView rectOfRow:sr]];
				///printf("updating (parent) row %d\n", sr);
				tbi = parentItem;
			}
		}
	}
	///[trackTableView reloadData];
	if (track == currentlySelectedTrack)
	{
		[metricsEventTable reloadData];
		[miniProfileView setNeedsDisplay:YES];
		[mapPathView forceRedraw];
		[equipmentBox update];
	}
}

-(void)expandBrowserItemByName:(NSString*)name
{
    NSMutableArray* marr = [NSMutableArray arrayWithCapacity:8];
    TrackBrowserItem* item = [flatBIDict objectForKey:name];
    if (item)
    {
        [marr addObject:item];
        while ((item = [item parentItem]))
        {
            [marr addObject:item];
        }
        int count = (int)[marr count];
        for (int i=(count-1); i>=0; i--)
        {
            item = [marr objectAtIndex:i];
            //NSLog(@"expanding %@", [item name]);
            [trackTableView expandItem:item];
        }
    }
}


-(void)captureExpandedItemNames
{
    if (expandedItemNames) 
    {
       [expandedItemNames release]; 
       expandedItemNames = nil;
    }
    expandedItemNames = [[NSMutableArray arrayWithCapacity:8] retain];
    NSEnumerator *enumerator = [expandedItems objectEnumerator];
    id value;
    while ((value = [enumerator nextObject])) 
    {
        TrackBrowserItem* tbi = (TrackBrowserItem*)value;
        ///NSLog(@"capturing %@", [tbi name]);
        [expandedItemNames addObject:[tbi name]];
    }

}


-(void)expandCapturedExpandedItemsByName
{
    if (expandedItemNames)
    {
        NSUInteger count = [expandedItemNames count];
        for (int i=0; i<count; i++)
        {
            NSString* name = [expandedItemNames objectAtIndex:i];
            if (name)
            {
               [self expandBrowserItemByName:name];
            }
        }
        [expandedItemNames release];
        expandedItemNames = nil;
    }
}

-(void)restoreSelectedRowsViewToggle:(NSSet*)selectedSet
{
    NSMutableIndexSet* is = [NSMutableIndexSet indexSet];
	NSSet* localSet = [NSSet setWithSet:selectedSet];
	for (id item in localSet)
	{
        [self expandBrowserItemByName:[item name]];
        TrackBrowserItem* tbi = [flatBIDict objectForKey:[item name]];
        NSInteger idx = [trackTableView rowForItem:tbi];
		if (idx != -1)
		{
			[is addIndex:idx];
		}
	}
	[trackTableView selectRowIndexes:is
				byExtendingSelection:NO];
    
}



-(void)toggleBrowserView:(NSNotification *)notification
{
    if ([self calendarViewActive])
    {
        [self doToggleCalendarAndBrowser:1];
    }
    NSNumber* num = (NSNumber*)[notification object];
    if (num)
    {
        int nextViewType = [num intValue];
        if (nextViewType == kViewTypeBad)
        {
            nextViewType = (kViewTypeActvities == viewType) ? kViewTypeCurrent : kViewTypeActvities;
        }
        NSSet* selectedSet = [NSSet setWithSet:selectedItemsAtExpand];
        [self captureExpandedItemNames];
        [self doSetViewType:nextViewType];
        [self expandCapturedExpandedItemsByName];
        [self restoreSelectedRowsViewToggle:selectedSet];
    }
}


- (void)doProcessFileDrag:(NSNotification *)notification
{
	NSDictionary* dict = [notification userInfo];
	if (dict) [self processFileDrag:[dict objectForKey:@"infoObj"]];
}


- (void)trackSelectionChanged:(NSNotification *)notification
{
	Track* trk = [notification object];
	if ([[tbDocument trackArray] indexOfObjectIdenticalTo:trk] != NSNotFound)
	{
		[self resetSelectedTrack:trk lap:nil];
		if ([[notification userInfo] objectForKey:@"Sender"] != calendarView)
		{
			[self resetBrowserSelection];
		}
	}
	else if (trk == nil)
	{
		[self resetSelectedTrack:nil lap:nil];
	}
}


- (void)trackEdited:(NSNotification *)notification
{
	[mapPathView setCurrentTrack:currentlySelectedTrack];
	[miniProfileView setCurrentTrack:currentlySelectedTrack];
}


- (void)rebuildBrowserNotification:(NSNotification *)notification
{
   [self storeExpandedState];
   [self buildBrowser:NO];
   [self restoreExpandedState];
}


- (void)rebuildOutlineViewNotification:(NSNotification *)notification
{
   [trackTableView rebuild];
   [self resetInfoLabels];
}



-(void) buildContextualMenu
{
	NSMenu* cm = [[[NSMenu alloc] init] autorelease];

	//[cm setShowsStateColumn:YES];
	
	[[cm addItemWithTitle:@"Email..."
				   action:@selector(mailActivity:)
			keyEquivalent:@""] setTag:kCMEmailSelected];

	[[cm addItemWithTitle:@"Save..."
				   action:@selector(saveSelectedTracks:)
			keyEquivalent:@""] setTag:kCMSaveSelected];

	[[cm addItemWithTitle:@"Google Earth Fly-By..."
				   action:@selector(googleEarthFlyBy:)
			keyEquivalent:@""] setTag:kCMGoogleFlyBy];

	[cm addItem:[NSMenuItem separatorItem]];

	[[cm addItemWithTitle:@"Export as gpx..."
				   action:@selector(exportGPX:)
			keyEquivalent:@""] setTag:kCMExportGPX];

	[[cm addItemWithTitle:@"Export as kml..."
				   action:@selector(exportKML:)
			keyEquivalent:@""] setTag:kCMExportKML];

	[[cm addItemWithTitle:@"Export as tcx..."
				   action:@selector(exportTCX:)
			keyEquivalent:@""] setTag:kCMExportTCX];

	[[cm addItemWithTitle:@"Export activity as tab-separated values (tsv)..."
				   action:@selector(exportTXT:)
			keyEquivalent:@""] setTag:kCMExportTXT];

	[[cm addItemWithTitle:@"Export activity as comma-separated values (csv)..."
				   action:@selector(exportCSV:)
			keyEquivalent:@""] setTag:kCMExportCSV];

	[[cm addItemWithTitle:@"Export summary data as tab-separated values (tsv)..."
				   action:@selector(exportSummaryTXT:)
			keyEquivalent:@""] setTag:kCMExportSummaryTXT];

	[[cm addItemWithTitle:@"Export summary data as comma-separated values (csv)..."
				   action:@selector(exportSummaryCSV:)
			keyEquivalent:@""] setTag:kCMExportSummaryCSV];

	[cm addItem:[NSMenuItem separatorItem]];

	[[cm addItemWithTitle:@"Upload to Mobile"
				   action:@selector(syncStravaActivities:)
		    keyEquivalent:@""] setTag:kCMUploadToMobile];
	
	[cm addItem:[NSMenuItem separatorItem]];

	NSMenuItem* mi;
	mi = [cm addItemWithTitle:@"Add Activity..."
					   action:@selector(addActivity:)
				keyEquivalent:@"A"];
	[mi setTag:kCMAddActivity];
	[mi setKeyEquivalentModifierMask:NSEventModifierFlagControl];

	mi = [cm addItemWithTitle:@"Edit Activity..."
					   action:@selector(editActivity:)
				keyEquivalent:@"E"];
	[mi setTag:kCMEditActivity];
	[mi setKeyEquivalentModifierMask:NSEventModifierFlagControl];

	[[cm addItemWithTitle:@"Split Activity..."
				   action:@selector(splitActivity:)
			keyEquivalent:@""] setTag:kCMSplitActivity];
	
	[[cm addItemWithTitle:@"Compare Activities"
				   action:@selector(compareActivities:)
			keyEquivalent:@"y"] setTag:kCMCompareActivities];
	
	[[cm addItemWithTitle:@"Combine Activities"
				   action:@selector(combineActivities:)
			keyEquivalent:@""] setTag:kCMCombineActivities];
	
	[[cm addItemWithTitle:@"Adjust GMT Offset..."
				   action:@selector(getGMTOffset:)
			keyEquivalent:@""] setTag:kCMAdjustGMTOffset];

	[[cm addItemWithTitle:@"Altitude Smoothing..."
				   action:@selector(getAltitudeSmoothing:)
		    keyEquivalent:@""] setTag:kCMAltitudeSmoothing];

	
	[cm addItem:[NSMenuItem separatorItem]];

	mi = [cm addItemWithTitle:@"Open Activity Detail View"
					   action:@selector(showActivityDetail:)
				keyEquivalent:@"g"];
	[mi setTag:kCMOpenActivityDetail];

	mi = [cm addItemWithTitle:@"Open Map Detail View"
					   action:@selector(showMapDetail:)
				keyEquivalent:@"m"];
	[mi setTag:kCMOpenMapDetail];

	mi = [cm addItemWithTitle:@"Open Data Detail View"
					   action:@selector(showDataDetail:)
				keyEquivalent:@"D"];
	[mi setTag:kCMOpenDataDetail];

	[cm addItem:[NSMenuItem separatorItem]];

	[[cm addItemWithTitle:@"Refresh Map"
				   action:@selector(refreshMap:)
			keyEquivalent:@""] setTag:kCMRefreshMap];

	NSMenuItem* item = [cm itemWithTag:kCMUploadToMobile];
	[item setState:[currentlySelectedTrack uploadToMobile]];
	
	[trackTableView setMenu:cm];
	[calendarView setMenu:cm];
}   


- (void) setEmptyInfoPopup:(NSPopUpButton*)popup
{
   [popup removeAllItems];
   [popup addItemWithTitle:@""];
   [[popup menu] addItem:[NSMenuItem separatorItem]];
   [popup addItemWithTitle:@"Edit List..."];
   [popup selectItemAtIndex:0];
}


- (void) buildInfoPopupMenus
{
	if (currentlySelectedTrack == nil)
	{
		[setEquipmentButton setEnabled:NO];
		[self setEmptyInfoPopup:activityPopup];
		[self setEmptyInfoPopup:eventTypePopup];
		[self setEmptyInfoPopup:dispositionPopup];
		[self setEmptyInfoPopup:weatherPopup];
		[self setEmptyInfoPopup:effortPopup];
		[self setEmptyInfoPopup:keyword1Popup];
		[self setEmptyInfoPopup:keyword2Popup];
	}
	else
	{
		[setEquipmentButton setEnabled:YES];
		
		// setup menus in the edit window
		[Utils buildPopupMenuFromItems:RCBDefaultAttrActivityList 
								 popup:activityPopup 
					  currentSelection:[currentlySelectedTrack attribute:kActivity]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrEventTypeList 
								 popup:eventTypePopup
					  currentSelection:[currentlySelectedTrack attribute:kEventType]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrWeatherList 
								 popup:weatherPopup
					  currentSelection:[currentlySelectedTrack attribute:kWeather]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrDispositionList 
								 popup:dispositionPopup
					  currentSelection:[currentlySelectedTrack attribute:kDisposition]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrEffortList 
								 popup:effortPopup
					  currentSelection:[currentlySelectedTrack attribute:kEffort]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrKeyword1List 
								 popup:keyword1Popup
					  currentSelection:[currentlySelectedTrack attribute:kKeyword1]];
		[Utils buildPopupMenuFromItems:RCBDefaultAttrKeyword2List 
								 popup:keyword2Popup
					  currentSelection:[currentlySelectedTrack attribute:kKeyword2]];
	}
}   


- (void)doSetSearchOptions:(int)opts
{
	[Utils setIntDefault:opts forKey:RCBDefaultSearchOptions];
	searchOptions = opts;
}



-(BOOL) findTrack:(Track*)track dict:(NSDictionary*)dict stackArray:(NSMutableArray*)itemStack
{
	BOOL ret = NO;
	NSEnumerator *enumerator = [dict objectEnumerator];
	TrackBrowserItem* bi = [enumerator nextObject];
	while (bi)
	{
		[itemStack addObject:bi];
		if (([bi track] == track) && ([bi lap] == nil))
		{
			return YES;
		}
		else if ([bi children] != nil)
		{
			ret = [self findTrack:track dict:[bi children] stackArray:itemStack];
		}
		if (ret) break;
		else [itemStack removeObjectIdenticalTo:bi];
        bi = [enumerator nextObject];
	}
	return ret;
}




-(void) expandBrowserAtTrack:(Track*)track
{
	NSMutableArray* itemStack = [NSMutableArray arrayWithCapacity:3];
	if ([self findTrack:track dict:yearItems stackArray:itemStack])
	{
        NSUInteger num = [itemStack count];
		if (num > 0)
		{
            NSInteger row = [trackTableView selectedRow];
			if (row != -1)
			{
				[trackTableView collapseItem:[trackTableView itemAtRow:row] 
						collapseChildren:YES];
			}
			for (int i=0; i<num; i++)
			{
				[trackTableView expandItem:[itemStack objectAtIndex:i]];
			}
			row = [trackTableView rowForItem:[itemStack objectAtIndex:num-1]];
			[trackTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] 
					byExtendingSelection:NO];
			[trackTableView scrollRowToVisible:[trackTableView rowForItem:[itemStack objectAtIndex:num-1]]];
		}
	}
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


-(void) restoreSelectedRowsAfterExpand
{
	NSMutableIndexSet* is = [NSMutableIndexSet indexSet];
	NSSet* localSet = [NSSet setWithSet:selectedItemsAtExpand];
	for (id item in localSet)
	{
        NSInteger idx = [trackTableView rowForItem:item];
		if (idx != -1)
		{
			[is addIndex:idx];
		}
	}
	[trackTableView selectRowIndexes:is
				byExtendingSelection:NO];
    
}


- (void) restoreExpandedState
{
    NSUInteger num = [expandedItems count];
	if (num == 0) return;
	NSSet* localSet = [NSSet setWithSet:expandedItems];
	for (id item in localSet)
	{
		[trackTableView expandItem:item];
	}
    [self restoreSelectedRowsAfterExpand];
}


// set v to 0 for calendar, 1 for main browser
- (void)doToggleCalendarAndBrowser:(int)v
{
 	static BOOL sStateStored = NO;
	[calOrBrowControl setSelectedSegment:v];
    /*NSToolbarItem* si = */[toolbarItems objectForKey:@"SearchBrowser"];
    //allow in calendar view too, will force switch to browser [si setEnabled:v == 1];
    if (v == 1)		// going from calendar view to the browser
	{
		///[searchField setHidden:NO];
                                
		if ([self isBrowserEmpty]) [self buildBrowser:(viewType == kViewTypeCurrent)];
		[self resetSelectedTrack:[calendarView selectedTrack]
							 lap:nil];
		//[self expandBrowserAtTrack:currentlySelectedTrack];
		if (sStateStored) [self restoreExpandedState];
		sStateStored = NO;
	}
	else        // going from browser to calendar
	{
        [searchField setStringValue:@""];
        [self doSetSearchCriteriaToString:@""];
		// going from browser to calendar
		[self storeExpandedState];
		sStateStored = YES;
		///[searchField setHidden:YES];
		if (currentlySelectedTrack)
		{
#if 0
            NSCalendarDate* calDate = [[currentlySelectedTrack creationTime] dateWithCalendarFormat:nil
																						   timeZone:nil];
#else
            NSDate *calDate = currentlySelectedTrack.creationTime;

            NSDateFormatter *fmt = [NSDateFormatter new];
            fmt.locale   = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // or user’s locale
            fmt.timeZone = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"]; // or nil for system TZ
            fmt.dateStyle = NSDateFormatterMediumStyle;
            fmt.timeStyle = NSDateFormatterShortStyle;

#endif
			[calendarView setVisibleMonth:calDate];
			[calendarView setSelectedDay:calDate];
		}
		[calendarView setSelectedTrack:currentlySelectedTrack];
		[calendarView setTracks:[tbDocument trackArray]];		// @@FIXME@@
	}
 	[Utils setIntDefault:v
				  forKey:RCBDefaultLastMainDisplay];
	[mainBrowserTabView selectTabViewItemAtIndex:1-v];
}

-(void) changeView:(id)sender
{
	NSInteger tag = [(NSView*)sender tag];
	[self doSetViewType:(int)tag];
}

-(IBAction)setSplitOptions:(id)sender
{
}
- (NSMenu*) buildLeftOptsMenu
{
	int tag = 0;
	NSMenu* leftOptsMenu = [[[NSMenu alloc] initWithTitle:@"View Options"] autorelease];
	
    NSMenuItem* mi;
	mi = [leftOptsMenu addItemWithTitle:@"Toggle Info Display"
							action:@selector(toggleStatsInfo:)
                          keyEquivalent:@"i"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:0];

	NSMenuItem* parent = [leftOptsMenu addItemWithTitle:@"Browser View"
												 action:nil
										  keyEquivalent:@""];
	
	browserViewSubMenu = [[NSMenu alloc] init];
    
	mi = [browserViewSubMenu addItemWithTitle:@"Normal"
                                        action:@selector(changeView:)
                                 keyEquivalent:@"n"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:tag++];
	

    mi = [browserViewSubMenu addItemWithTitle:@"All Activities"
								   action:@selector(changeView:)
							keyEquivalent:@"a"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:tag++];

	mi = [browserViewSubMenu addItemWithTitle:@"All Weeks"
								   action:@selector(changeView:)
							keyEquivalent:@"w"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:tag++];

    mi = [browserViewSubMenu addItemWithTitle:@"All Months"
								   action:@selector(changeView:)
							keyEquivalent:@"m"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:tag++];

	mi = [browserViewSubMenu addItemWithTitle:@"All Years"
								   action:@selector(changeView:)
							keyEquivalent:@"y"];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [mi setTag:tag++];

	[leftOptsMenu setSubmenu:browserViewSubMenu
					 forItem:parent];
	int vt = [Utils intFromDefaults:RCBDefaultBrowserViewType];
	[[browserViewSubMenu itemWithTag:vt] setState:NSControlStateValueOn];
	
	tag = 0;
	int mt = [Utils intFromDefaults:RCBDefaultMapType];
	parent = [leftOptsMenu addItemWithTitle:@"Map Datum"
									  action:nil
										  keyEquivalent:@""];
	mapViewDataTypeSubMenu = [[NSMenu alloc] init];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"Hybrid (VirtualEarth)"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"Aerial (VirtualEarth)"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"Road (VirtualEarth)"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"(USGS) Aerial"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"(USGS) Urban"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu addItemWithTitle:@"(USGS) Topo"
									   action:@selector(setMapDataType:)
								keyEquivalent:@""] setTag:tag++];
	[[mapViewDataTypeSubMenu itemWithTag:mt] setState:NSControlStateValueOn];
	[leftOptsMenu setSubmenu:mapViewDataTypeSubMenu
					 forItem:parent];
	return leftOptsMenu;
}


- (void) updateSplitOptionsMenu
{
	///if ([splitsTableSubView isCollapsed])
    if ([splitsTableSubView isHidden])
	{
		[[splitOptionsMenu itemAtIndex:0] setTitle:@"Expand Splits Table"];
	}
	else
	{
		[[splitOptionsMenu itemAtIndex:0] setTitle:@"Collapse Splits Table"];
	}
}


-(void)splitGraphSelectionChange:(NSNotification *)aNotification
{
	NSMutableIndexSet* selSet = [NSMutableIndexSet indexSet];
    NSInteger num = [splitArray count];
	BOOL haveFirst = NO;
	for (int i=0; i<num; i++)
	{
		if ([[splitArray objectAtIndex:i] selected]) 
		{
			[selSet addIndex:i];
			if (!haveFirst)
			{
				haveFirst = YES;
				[splitsTableView scrollRowToVisible:i];
			}
		}
	}
	[splitsTableView selectRowIndexes:selSet byExtendingSelection:NO];
	[splitsGraphView setNeedsDisplay:YES];
	[miniProfileView setNeedsDisplay:YES];
	[mapPathView setNeedsDisplay:YES];
}


- (void)repositionTransparentWindows
{
	NSRect leftSplitViewFrame = [leftSplitView frame];
	NSRect rightSplitViewFrame = [rightSplitView frame];
	NSRect miniProfileFrame = [miniProfileSplitSubView frame];
	NSRect mapPathFrame = [mapPathSplitSubView frame];
	
	NSRect fr = [mapPathView frame];
	fr.origin.x = rightSplitViewFrame.origin.x + 8.0;
	fr.origin.y = (leftSplitViewFrame.size.height - mapPathFrame.size.height + 20.0);		// add space for split view dividers
	fr.origin = [[self window] convertPointToScreen:fr.origin];
	[transparentMapWindow setFrame:fr display:YES];
	
	fr = [miniProfileView frame];
	fr.origin.x = rightSplitViewFrame.origin.x + 8.0;
	fr.origin.y = (leftSplitViewFrame.size.height - mapPathFrame.size.height - miniProfileFrame.size.height + 14.0);
	fr.origin = [[self window] convertPointToScreen:fr.origin];
	[transparentMiniProfileWindow setFrame:fr display:YES];
}



-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual:@"SearchBrowser"]) 
    {
        enable = ![self calendarViewActive];
    } 
    else
    {
        // always enable print for this window
        enable = YES;
    }
    return enable;
}

-(IBAction)changeSearchItem:(id)sender
{
    printf("wtf\n");
}


- (void) awakeFromNib
{
	//searchMenu = [[[searchField cell] searchMenuTemplate] retain];
	//[[searchField cell] setSearchMenuTemplate:nil];
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"MainBrowserWindowFrame"];
	if (![[self window] setFrameUsingName:@"MainBrowserWindowFrame"])
	{
		[[self window] center];
	}
	cogMenu = [self buildLeftOptsMenu];
	[leftOptionsControl setMenu:cogMenu
					 forSegment:0];
	
	[self rebuildSplitOptionsMenu];
	// toolbar
	NSToolbar *toolbar=[[[NSToolbar alloc] initWithIdentifier:@"AscentMainToolbar"] autorelease];
    // Here we create the dictionary to hold all of our "master" NSToolbarItems.
    toolbarItems=[[NSMutableDictionary dictionary] retain];
    addToolbarItem(toolbarItems,@"BrowOrCal",@"Main View",@"Main View",@"Choose browser or calendar View",self,@selector(setView:),calOrBrowControl,@selector(toggleMainBrowser:),nil);
    addToolbarItem(toolbarItems,@"SplitsOptions",@"Splits Options", @"Splits Options",@"Choose splits options or press to toggle splits table display",self,@selector(setView:),splitOptionsControl,@selector(expandOrCollapseSplits:),splitOptionsMenu);
	addToolbarItem(toolbarItems,@"LeftOptionsCog",@"View Options", @"View Options",@"Choose browser view options or press to toggle stats display",self,@selector(setView:),leftOptionsControl,@selector(toggleStatsInfo:),cogMenu);
	addToolbarItem(toolbarItems,@"CompareActivities",@"Compare Activities", @"Compare Activities",@"Select activities and press to display compare window",self,@selector(setView:),compareActivitiesButton,@selector(showCompareWindow:),nil);
	addToolbarItem(toolbarItems,@"ActivityDetail",@"Activity Detail", @"Activity Detail",@"Press to display activity detail window",self,@selector(setView:),activityDetailButton,@selector(showActivityDetail:),nil);
    addToolbarItem(toolbarItems,@"MapDetail",@"Map Detail", @"Map Detail",@"Press to display map detail window",self,@selector(setView:),detailedMapButton,@selector(showMapDetail:),nil);
	addToolbarItem(toolbarItems,@"Summary",@"Summary Graphs", @"Summary Graphs",@"Press to display summary window",self,@selector(setView:),summaryButton,@selector(showSummaryGraph:),nil);
	addToolbarItem(toolbarItems,@"SearchBrowser",@"Search Activities",@"Search Activities",@"Enter text to search activities",self,@selector(setView:),searchField,@selector(setSearchCriteria:),nil);
    
    
    [toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration: YES]; 
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	[toolbar setShowsBaselineSeparator:NO];
    [[self window] setToolbar:toolbar];
	
	int vt = [Utils intFromDefaults:RCBDefaultBrowserViewType];
	if (IS_BETWEEN(0, vt, kNumViewTypes-1))
	{
		viewType = vt;
		[Utils selectMenuItem:vt
					  forMenu:browserViewSubMenu];
	}
	
	///[mainSplitView setAutosaveName:@"MainSplitView"
	///				   recursively:YES];
	[mainSplitView setAutosaveName:@"MainSplitView"];
	///[mainSplitView restoreState:YES];
	[mainSplitView adjustSubviews];
	[self setShouldCloseDocument:YES];
   
	
	////[trackTableView setAutosaveExpandedItems:YES];
	int i;
	for (i=0; i<kNumAttributes; i++)
	{
		attrMap[i].editControl  = nil;
		attrMap[i].attributeID = -1;
		attrMap[i].flags = 0;
		attrMap[i].transparentView = nil;
		attrMap[i].placeholderText = nil;
	}

	attrMap[kName].editControl = editActivityName;
	attrMap[kName].attributeID = kName;
	attrMap[kName].placeholderText = @"Click to enter activity title";

	attrMap[kActivity].editControl = activityPopup;
	attrMap[kActivity].attributeID = kActivity;
	attrMap[kActivity].flags = kIsPopup;

	attrMap[kDisposition].editControl = dispositionPopup;
	attrMap[kDisposition].attributeID = kDisposition;
	attrMap[kDisposition].flags = kIsPopup;

	attrMap[kEffort].editControl = effortPopup;
	attrMap[kEffort].attributeID = kEffort;
	attrMap[kEffort].flags = kIsPopup;

	attrMap[kEventType].editControl = eventTypePopup;
	attrMap[kEventType].attributeID = kEventType;
	attrMap[kEventType].flags = kIsPopup;

	//attrMap[kEquipment].editControl = equipmentPopup;
	//attrMap[kEquipment].attributeID = kEquipment;
	//attrMap[kEquipment].flags = kIsPopup;

	attrMap[kWeather].editControl = weatherPopup;
	attrMap[kWeather].attributeID = kWeather;
	attrMap[kWeather].flags = kIsPopup;

	attrMap[kWeight].editControl = editWeightField;
	attrMap[kWeight].attributeID = kWeight;

	attrMap[kKeyword1].editControl = keyword1Popup;
	attrMap[kKeyword1].attributeID = kKeyword1;
	attrMap[kKeyword1].flags = kIsPopup;

	attrMap[kKeyword2].editControl = keyword2Popup;
	attrMap[kKeyword2].attributeID = kKeyword2;
	attrMap[kKeyword2].flags = kIsPopup;

	attrMap[kKeyword3].editControl = customTextField;     // custom text field is stored in keyword 3
	attrMap[kKeyword3].attributeID = kKeyword3;

	attrMap[kNotes].editControl = notesTextView;
	attrMap[kNotes].attributeID = kNotes;
	attrMap[kNotes].flags = kIsTextView;
	attrMap[kNotes].placeholderText = @"Click to enter activity notes";
	//attrMap[kNotes].transparentView = notesTransparentView;
	
	// set tags on the attribute edit widgets (popups or textfields)
	for (i=0; i<kNumAttributes; i++)
	{
	  if ((attrMap[i].editControl != nil) && ((attrMap[i].flags & kIsTextView)==0))
	  {
		 [attrMap[i].editControl setTag:(NSInteger)attrMap[i].attributeID];
	  }
	}
      
	[trackTableView setDoubleAction:@selector(handleDoubleClickInOutlineView:)];

	int opts = [Utils intFromDefaults:RCBDefaultSearchOptions];
	[self doSetSearchOptions:opts];
	NSMenuItem* searchItem = [searchCategoryMenu itemWithTitle:@"Search"];
	if (searchItem)
	{
	   NSMenu* subMenu = [searchItem submenu];
	   if (subMenu && tbDocument)
	   {
		  int sopts = [self searchOptions];
		  NSMenuItem* item = [subMenu itemWithTag:kTagSearchTitles];
		  if (nil != item)
		  {
			  [item setState:FLAG_IS_SET(sopts, kSearchTitles) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
		  item = [subMenu itemWithTag:kTagSearchNotes];
		  if (nil != item)
		  {
			 [item setState:FLAG_IS_SET(sopts, kSearchNotes) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
		  item = [subMenu itemWithTag:kTagSearchKeywords];
		  if (nil != item)
		  {
			 [item setState:FLAG_IS_SET(sopts, kSearchKeywords) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
		  item = [subMenu itemWithTag:kTagSearchActivityType];
		  if (nil != item)
		  {
			 [item setState:FLAG_IS_SET(sopts, kSearchActivityType) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
		  item = [subMenu itemWithTag:kTagSearchEventType];
		  if (nil != item)
		  {
			  [item setState:FLAG_IS_SET(sopts, kSearchEventType) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
		  item = [subMenu itemWithTag:kTagSearchEquipment];
		  if (nil != item)
		  {
			  [item setState:FLAG_IS_SET(sopts, kSearchEquipment) ? NSControlStateValueOn : NSControlStateValueOff];
		  }
	   }
	}
	float opac = [Utils floatFromDefaults:@"DefaultMapTransparency"];
	[mapPathView setMapOpacity:opac];

	[self doToggleCalendarAndBrowser:[Utils intFromDefaults:RCBDefaultLastMainDisplay]];

	[[AnimTimer defaultInstance] registerForTimerUpdates:self];

	[mapPathView setTransparentView:transparentMapAnimView];
	[miniProfileView setTransparentView:transparentMiniProfileAnimView];
	NSRect fr = [mapPathView frame];
	//NSLog(@"vf: %1.0f, %1.0f %x", fr.origin.x, fr.origin.y, [self window]);
	fr.origin = [[self window] convertPointToScreen:fr.origin];
	//NSLog(@"wf: %1.0f, %1.0f", fr.origin.x, fr.origin.y);
	fr = NSInsetRect(fr, 10, 10);
	[transparentMapWindow setFrame:fr display:YES];
	fr.origin = NSZeroPoint;
	[transparentMapAnimView setBounds:fr];
	[transparentMapAnimView setFrame:fr];
	[[self window]  addChildWindow:(NSWindow*)transparentMapWindow ordered:NSWindowAbove];
	[transparentMapWindow setHasShadow:NO];

	[mapPathView setCurrentTrack:nil];
	[mapPathView setColorizePaths:NO];

	[miniProfileView setTransparentView:transparentMiniProfileAnimView];
	fr = [miniProfileView frame];
	fr.origin = [[self window] convertPointToScreen:fr.origin];
	fr = NSInsetRect(fr, 10, 10);
	//fr.origin.y += 50;
	[transparentMiniProfileWindow setFrame:fr display:YES];
	fr.origin = NSZeroPoint;
	[transparentMiniProfileAnimView setBounds:fr];
	[transparentMiniProfileAnimView setFrame:fr];
	[[self window]  addChildWindow:(NSWindow*)transparentMiniProfileWindow ordered:NSWindowAbove];
	[transparentMiniProfileWindow setHasShadow:NO];

	[miniProfileView setCurrentTrack:nil];

	NSView* view;
	if ([self calendarViewActive]) view = calendarView; else view = trackTableView;
	[[self window] makeFirstResponder:view]; 
	//[[self window] center];
	//[[self window] setFrameUsingName:@"TBWindowFrame"];

	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(prefChange:)
												name:@"PreferencesChanged"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(rebuildBrowserNotification:)
												name:@"RebuildBrowser"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(rebuildOutlineViewNotification:)
												name:@"RebuildOutlineView"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(undoRedoCompleted:)
												name:@"UndoRedoCompleted"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(trackChanged:)
												name:@"TrackChanged"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(trackEdited:)
												name:@"TrackEdited"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(trackSelectionChanged:)
												name:@"TrackSelectionChanged"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(splitGraphSelectionChange:)
												name:@"SplitSelected"
											  object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(doProcessFileDrag:)
												 name:@"FilesDraggedIntoApp"
											   object:calendarView];	// only want to hear from OUR calendar view!
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(delete:)
												 name:@"DeleteSelectedRows"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleBrowserView:)
												 name:@"ToggleBrowserView"
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(splitDragComplete:)
												 name:@"SplitDragComplete"
											   object:nil];
    
	NSTableColumn* col = [[trackTableView tableColumns] objectAtIndex:0];
	if (col != nil)
	{
	  NSImage* sortTriangle;
	  if (reverseSort)
	  {
		 sortTriangle = [NSTableView _defaultTableHeaderReverseSortImage];
	  }
	  else
	  {
		 sortTriangle = [NSTableView _defaultTableHeaderSortImage];
	  }
	  [trackTableView setIndicatorImage:sortTriangle
					  inTableColumn:col];
	  sortColumn = col;
	}

	[self buildContextualMenu];


	int idx = [Utils intFromDefaults:RCBDefaultBrowserTabView];
	int mx = (int)[infoStatsTabView numberOfTabViewItems];
	if (!IS_BETWEEN(0, idx, (mx-1)))
	{
		idx = 0;
	}
	[infoStatsTabView selectTabViewItemAtIndex:idx];
	[self buildInfoPopupMenus];
	[self resetInfoLabels];
	//[infoNotesScrollView setLineScroll:14];

	[calendarView setShowsDaysForOtherMonths:YES];
	[self updateSplitOptionsMenu];

	[[self window] makeKeyAndOrderFront:self];
	[self repositionTransparentWindows];

	SEL sel = @selector(equipmentButtonPushedAction:);
	NSMethodSignature* sig = [TBWindowController instanceMethodSignatureForSelector:sel];
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[equipmentBox setEquipmentButtonAction:inv];
	[weightUnitsField setStringValue:[Utils usingStatute] ? @"(lbs)" : @"(kg)"];
	
}


#if USE_RBSPLITVIEW

- (void)splitView:(RBSplitView*)sender wasResizedFrom:(float)oldDimension to:(float)newDimension 
{
	[sender saveState:YES];
	//} else if (sender==secondSplit) {
	//	[sender adjustSubviewsExcepting:nestedSplit];
	//}
	//[self repositionTransparentWindows];
}


- (void)splitView:(RBSplitView*)sender changedFrameOfSubview:(RBSplitSubview*)subview  from:(NSRect)fromRect  to:(NSRect)toRect
{
	if (subview == mapPathSplitSubView)
	{
		NSRect rightSplitViewFrame = [rightSplitView frame];
		NSRect leftSplitViewFrame = [leftSplitView frame];
		NSRect fr = toRect;
		fr.origin.x = rightSplitViewFrame.origin.x + 8.0;
		fr.origin.y = (leftSplitViewFrame.size.height - toRect.size.height + 20.0);		// add space for split view dividers
		fr.origin = [[self window] convertBaseToScreen:fr.origin];
		[transparentMapWindow setFrame:fr display:YES];
	}
	else if (subview == miniProfileSplitSubView)
	{
		NSRect rightSplitViewFrame = [rightSplitView frame];
		NSRect leftSplitViewFrame = [leftSplitView frame];
		NSRect mapPathFrame = [mapPathSplitSubView frame];
		NSRect miniProfileFrame = [miniProfileSplitSubView frame];
		NSRect fr = toRect;
		fr.origin.x = rightSplitViewFrame.origin.x + 8.0;
		fr.origin.y = (leftSplitViewFrame.size.height - mapPathFrame.size.height - miniProfileFrame.size.height + 14.0);
		fr.origin = [[self window] convertBaseToScreen:fr.origin];
		[transparentMiniProfileWindow setFrame:fr display:YES];
	}
	else if (subview == splitsGraphSubView)
	{
		if ([self window]) {
			[splitsGraphView resetTrackingRect];        
		}
	}
}



- (void)willAdjustSubviews:(RBSplitView*)sender
{
	if ((sender == rightSplitView)||(sender == mainSplitView))
	{
		if ([rightSplitView isDragging] || [mainSplitView isDragging])
		{
			//[transparentMapAnimView setHidden:YES];
			//[transparentMiniProfileAnimView setHidden:YES];
		}
	}
}


- (void)didAdjustSubviews:(RBSplitView*)sender
{
	[sender saveState:YES];
}


- (void)splitView:(RBSplitView*)sender didCollapse:(RBSplitSubview*)subview
{
	//[self repositionTransparentWindows];
	if ((subview == mapPathSplitSubView) || (subview == rightSplitView))
	{
		[transparentMapAnimView setHidden:YES];
	}
	if ((subview == miniProfileSplitSubView) || (subview == rightSplitView))
	{
		[transparentMiniProfileAnimView setHidden:YES];
	}
	if (subview == splitsTableSubView)
	{
		[self updateSplitOptionsMenu];
	}
	[sender saveState:YES];
}


- (void)splitView:(RBSplitView*)sender didExpand:(RBSplitSubview*)subview
{
	//[self repositionTransparentWindows];
	if ((subview == mapPathSplitSubView) || (subview == rightSplitView))
	{
		[transparentMapAnimView setHidden:YES];
	}
	if ((subview == miniProfileSplitSubView) || (subview == rightSplitView))
	{
		[transparentMiniProfileAnimView setHidden:YES];
	}
	if (subview == splitsTableSubView)
	{
		[self updateSplitOptionsMenu];
	}
	[sender saveState:YES];
}


- (void)dragFinished:(id)sender
{
	if (![rightSplitView isCollapsed])
	{
		BOOL hide = [[currentlySelectedTrack goodPoints] count] <= 1;
		if (![mapPathSplitSubView isCollapsed])
		{
			[transparentMapAnimView setHidden:hide];
		}
		if (![miniProfileSplitSubView isCollapsed])
		{
			[transparentMiniProfileAnimView setHidden:hide];
		}
	}
}



- (IBAction) expandOrCollapseSplits:(id)sender
{
	if ([splitsTableSubView isCollapsed])
	{
		[splitsTableSubView expand];
		//[splitsGraphSubView expand];
		
	}
	else
	{
		[splitsTableSubView collapse];
		//[splitsGraphSubView collapse];
	}
}


#else



- (void)splitDragComplete:(NSNotification *)notification
{
    TBSplitView* splitView = (TBSplitView*)[notification object];
    BOOL hidden = [splitView isMouseDown];
    ///NSLog(@"DRAG COMPLETED, hidden: %s", hidden ? "YES" : "NO");
    if (!hidden)
        [self syncTransparentViews];
    [transparentMapAnimView setHidden:hidden];
    [transparentMiniProfileAnimView setHidden:hidden];
    
}


- (BOOL)splitView:(TBSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return  ((subview != mainSplitView) && (subview != rightSplitView) && (subview != leftSplitView) && (subview != miniProfileSplitSubView));
}


- (IBAction) expandOrCollapseSplits:(id)sender
{
    [splitsTableSubView setHidden:![splitsTableSubView isHidden]];
}


- (BOOL)splitView:(TBSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
    return YES;
}

#define STATS_H 250.0f

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat retMin = proposedMin;
    CGFloat dividerThickness = [rightSplitView dividerThickness];
    NSRect bds = [rightSplitView bounds];
    //NSRect profileBounds = [miniProfileSplitSubView bounds];
    //NSRect mapBounds = [mapPathSplitSubView bounds];
    //NSRect statsBounds = [statsInfoSplitSubView bounds];
    if ((splitView == rightSplitView) && dividerIndex == 1)
    {
        retMin = bds.size.height - dividerThickness - STATS_H;
    }
    //if (splitView == rightSplitView) NSLog(@"all:%1.1f map:%1.1f profile:%1.1f stats:%1.1f,  min divider %d: %1.1f, return %1.1f",
    //      bds.size.height, mapBounds.size.height, profileBounds.size.height, statsBounds.size.height, dividerIndex, proposedMin, retMin);
    return retMin;
}


- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat retMax = proposedMax;
    CGFloat dividerThickness = [rightSplitView dividerThickness];
    NSRect bds = [rightSplitView bounds];
    //NSRect profileBounds = [miniProfileSplitSubView bounds];
    //NSRect mapBounds = [mapPathSplitSubView bounds];
    //NSRect statsBounds = [statsInfoSplitSubView bounds];
    if ((splitView == rightSplitView) && dividerIndex == 1)
    {
        retMax = bds.size.height - dividerThickness;
    }
    //if (splitView == rightSplitView) NSLog(@"all:%1.1f map:%1.1f profile:%1.1f stats:%1.1f,  max divider %d: %1.1f, return %1.1f",
    //      bds.size.height, mapBounds.size.height, profileBounds.size.height, statsBounds.size.height, dividerIndex, proposedMax, retMax);
    return retMax;
}


- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat retPos = proposedPosition;
    CGFloat dividerThickness = [rightSplitView dividerThickness];
    NSRect bds = [rightSplitView bounds];
    NSRect profileBounds = [miniProfileSplitSubView bounds];
    NSRect mapBounds = [mapPathSplitSubView bounds];
    NSRect statsBounds = [statsInfoSplitSubView bounds];
    if (splitView == rightSplitView)
    {
        if (dividerIndex== 0)
        {
        }
        else if (dividerIndex==1)
        {
            if (statsBounds.size.height == 0)
            {
                if (proposedPosition < (mapBounds.size.height + profileBounds.size.height + dividerThickness - (STATS_H/2)))
                {
                    statsBounds.size.height = STATS_H;
                    retPos = bds.size.height - (STATS_H + dividerThickness);
                }
                else
                {
                    statsBounds.size.height = 0.0f;
                    retPos = bds.size.height - dividerThickness;
                }
             }
            else
            {
                if (proposedPosition > (bds.size.height - (STATS_H/2 + dividerThickness)))
                {
                    statsBounds.size.height = 0.0f;
                    retPos = bds.size.height - dividerThickness;
                }
                else
                {
                    statsBounds.size.height = STATS_H;
                    retPos = bds.size.height - (STATS_H + dividerThickness);
                }
            }
        }
    }
    //if (splitView == rightSplitView) NSLog(@"all:%1.1f map:%1.1f profile:%1.1f stats:%1.1f, proposed pos divider %d: %1.1f, return %1.1f",
    //      bds.size.height, mapBounds.size.height, profileBounds.size.height, statsBounds.size.height, dividerIndex, proposedPosition, retPos);
    return retPos;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    if (splitView == rightSplitView)
    {
        CGFloat dividerThickness = [rightSplitView dividerThickness];
        NSSize overallFrameSize = splitView.frame.size;
        NSSize profileFrameSize = miniProfileSplitSubView.frame.size;
        NSSize mapFrameSize = mapPathSplitSubView.frame.size;
        NSSize statsFrameSize = statsInfoSplitSubView.frame.size;
         
        float deltaH = overallFrameSize.height - oldSize.height;
        deltaH = deltaH/2.0f;

        profileFrameSize.height += deltaH;
        mapFrameSize.height += deltaH;

        NSRect fr;
        fr.origin.x = 0.0f;
        fr.origin.y = 0.0f;
        fr.size.width = overallFrameSize.width;
        fr.size.height = mapFrameSize.height;
        mapPathSplitSubView.frame = fr;
        
        fr.origin.y += mapFrameSize.height;
        fr.origin.y += dividerThickness;
        fr.size.height = profileFrameSize.height;
        miniProfileSplitSubView.frame = fr;
        
        if (statsFrameSize.height != 0.0f)
        {
            fr.origin.y = overallFrameSize.height - STATS_H;
            fr.size.height = STATS_H;
        }
        else
        {
            fr.origin.y = overallFrameSize.height - dividerThickness;
            fr.size.height = 0.0f;
        }
        statsInfoSplitSubView.frame = fr;
    }
    else
        [splitView adjustSubviews];

}


- (void)splitViewWillResizeSubviews:(NSNotification *)aNotification
{
	{
        [transparentMapAnimView setHidden:YES];
        [transparentMiniProfileAnimView setHidden:YES];
	}
}


- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
 //   TBSplitView* splitView = (TBSplitView*)[aNotification object];
    if (![rightSplitView isMouseDown] && ![mainSplitView isMouseDown])
    {
        [self syncTransparentViews];
        [transparentMapAnimView setHidden:NO];
        [transparentMiniProfileAnimView setHidden:NO];
    }
}


-(void)syncTransparentViews
{
    float dividerThickness = [mainSplitView dividerThickness];
	NSRect rightSplitViewFrame = [rightSplitView frame];
    NSRect mapPathFrame = [mapPathSplitSubView frame];
    NSRect fr = mapPathFrame;
    fr.origin.x = rightSplitViewFrame.origin.x;
    fr.origin.y = (rightSplitViewFrame.size.height - fr.size.height + (2*dividerThickness));
    fr.origin = [[self window] convertPointToScreen:fr.origin];
    [transparentMapWindow setFrame:fr display:YES];
    
    NSRect miniProfileFrame = [miniProfileSplitSubView frame];
    fr = miniProfileFrame;
    fr.origin.x = rightSplitViewFrame.origin.x;
    fr.origin.y = (rightSplitViewFrame.size.height - mapPathFrame.size.height - miniProfileFrame.size.height + dividerThickness);
    fr.origin = [[self window] convertPointToScreen:fr.origin];
    [transparentMiniProfileWindow setFrame:fr display:YES];
    if ([self window])
    {
        [splitsGraphView resetTrackingRect];
    }
    ///[sender saveState:YES];
}



#endif




- (NSMutableDictionary *)yearItems {
   return [[yearItems retain] autorelease];
}


- (NSMutableDictionary *)searchItems {
   return [[searchItems retain] autorelease];
}


- (NSOutlineView*) trackTable
{
   return trackTableView;
}




- (void) setGMTOffset:(NSArray*)arr offset:(int)off
{
    NSUInteger count = [arr count];
   NSUndoManager* undo = [tbDocument undoManager];
   if (count > 0)
   {
      [self storeExpandedState];
      if (![undo isUndoing])
      {
         [undo setActionName:@"Adjust GMT Offset"];
      }
      int curOffset = [currentlySelectedTrack secondsFromGMTAtSync]/(60.0*60.0);
      [[undo prepareWithInvocationTarget:self] setGMTOffset:arr offset:curOffset];
      for (int i=0; i<count; i++)
      {
         Track* t = [arr objectAtIndex:i];
         [t setSecondsFromGMTAtSync:(off*60.0*60)];
      }
      [self buildBrowser:NO];
      [self restoreExpandedState];
      [[self window] setDocumentEdited:YES];
      [tbDocument updateChangeCount:NSChangeDone];
      if ([undo isUndoing] || [undo isRedoing])
      {
         [[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
      }
   }
}


-(void)doEnableDisableAutoPower:(NSArray*)trackArray enable:(BOOL)en
{
    NSUInteger count = [trackArray count];
	for (int i=0; i<count; i++)
	{
		Track* t = [trackArray objectAtIndex:i];
		[t setEnableCalculationOfPower:en];
		[t calculatePower];
	}
}


-(void)enableAutoPowerCalcAction:(NSArray*)arr actionName:(NSString*)actionName enable:(BOOL)en
{
    NSUInteger count = [arr count];
	NSUndoManager* undo = [tbDocument undoManager];
	if (count > 0)
	{
		[self storeExpandedState];
		if (![undo isUndoing])
		{
			[undo setActionName:actionName];
		}
		[[undo prepareWithInvocationTarget:self] enableAutoPowerCalcAction:arr actionName:actionName enable:!en];
		[self doEnableDisableAutoPower:arr 
								enable:en];
		[self restoreExpandedState];
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
		if ([undo isUndoing] || [undo isRedoing])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
		}
	}
}


- (void) enableAutoPowerCalculation:(id)sender
{
	NSArray* arr = [self prepareArrayOfSelectedTracks];
	[self enableAutoPowerCalcAction:arr
						 actionName:@"Enable Auto-Power Calculation"
							 enable:YES];
}


- (void) disableAutoPowerCalculation:(id)sender
{
	NSArray* arr = [self prepareArrayOfSelectedTracks];
	[self enableAutoPowerCalcAction:arr
						 actionName:@"Disable Auto-Power Calculation"
							 enable:NO];
}



- (void) setAltitudeSmoothing:(NSArray*)arr factor:(float)fact
{
    NSUInteger count = [arr count];
	NSUndoManager* undo = [tbDocument undoManager];
	if (count > 0)
	{
		if (![undo isUndoing])
		{
			[undo setActionName:@"Altitude Smoothing"];
		}
		float curFactor = [currentlySelectedTrack altitudeSmoothingFactor];
		[[undo prepareWithInvocationTarget:self] setAltitudeSmoothing:arr factor:curFactor];
 		for (int i=0; i<count; i++)
		{
 			TrackBrowserItem* bi = [arr objectAtIndex:i];
			Track* t = [bi track];
			[t setAltitudeSmoothingFactor:fact];
			[t fixupTrack];
			[bi invalidateCache:YES];
		}
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
		if ([undo isUndoing] || [undo isRedoing])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
		}
		[trackTableView reloadData];
		[metricsEventTable reloadData];
		[splitsGraphView setNeedsDisplay:YES];
		[miniProfileView setNeedsDisplay:YES];
	}
}


- (void) setDistanceMethod:(NSArray*)arr useOrig:(BOOL)useOrig
{
    NSUInteger count = [arr count];
   NSUndoManager* undo = [tbDocument undoManager];
   if (count > 0)
   {
      //[self storeExpandedState];
      if (![undo isUndoing])
      {
         [undo setActionName:@"Set Distance Method"];
      }
      NSMutableArray* newArr = [NSMutableArray arrayWithArray:arr];
      for (int i=0; i<count; i++)
      {
         TrackBrowserItem* bi = [arr objectAtIndex:i];
         Track* t = [bi track];
         if ((t != nil) && ([t useOrigDistance] != useOrig))
         {
            [newArr addObject:bi];         // store only the BrowserItem for the track we're actually changing
            [t setUseOrigDistance:useOrig];
            [t fixupTrack];
			 [bi invalidateCache:YES];
         }
      }
      [[undo prepareWithInvocationTarget:self] setDistanceMethod:newArr useOrig:!useOrig];
      //[self restoreExpandedState];
      [[self window] setDocumentEdited:YES];
      [tbDocument updateChangeCount:NSChangeDone];
      if ([undo isUndoing] || [undo isRedoing])
      {
         [[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
      }
      [trackTableView reloadData];
	  [metricsEventTable reloadData];
   }
}




- (IBAction) addActivity:(id)sender
{
	Track* t = nil;
    NSInteger row = [trackTableView selectedRow];
	if (row != -1)
	{
	  TrackBrowserItem* bi = [trackTableView itemAtRow:row];
	  t = [bi track];
	}
	NSDate* initialDate;
	if ([self calendarViewActive])
	{
        initialDate = [calendarView selectedDay];
	}
	else if (currentlySelectedTrack)
	{
		initialDate = [currentlySelectedTrack creationTime];
	}
	else
	{
		initialDate = [NSDate date];
	}
	TrackDataEntryController *deWC = [[TrackDataEntryController alloc] initWithTrack:nil
																		 initialDate:initialDate
																		   document:tbDocument
																  editExistingTrack:NO];
	NSRect fr = [[self window] frame];
	NSRect panelRect = [[deWC window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);

	[[deWC window] setFrameOrigin:origin];
	[deWC showWindow:self];
    NSModalResponse ok = [NSApp runModalForWindow:[deWC window]];
	if (ok == 0)
	{
		[self resetSelectedTrack:[deWC track]
							 lap:nil];
		[tbDocument addTracks:[NSMutableArray arrayWithObject:[deWC track]]];
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
		//[self reloadTable];
	}
	[[deWC window] orderOut:[self window]];
	[[self window] makeKeyAndOrderFront:self];
	[deWC release];
}


- (IBAction) editActivity:(id)sender
{
	if (currentlySelectedTrack)
	{
		TrackDataEntryController *deWC = [[TrackDataEntryController alloc] initWithTrack:currentlySelectedTrack
																			 initialDate:[currentlySelectedTrack creationTime]
																				document:tbDocument
																	   editExistingTrack:YES];
		NSRect fr = [[self window] frame];
		NSRect panelRect = [[deWC window] frame];
		NSPoint origin = fr.origin;
		origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
		origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
		
		[[deWC window] setFrameOrigin:origin];
		[deWC showWindow:self];
        NSModalResponse ok = [NSApp runModalForWindow:[deWC window]];
		if (ok == 0)
		{
			[tbDocument replaceTrack:currentlySelectedTrack with:[deWC track]];
			[self resetSelectedTrack:[deWC track]
								 lap:nil];
			[[self window] setDocumentEdited:YES];
			[tbDocument updateChangeCount:NSChangeDone];
		}
		[[deWC window] orderOut:[self window]];
		[[self window] makeKeyAndOrderFront:self];
		[deWC release];
	}
}


- (IBAction) insertLapMarker:(id)sender
{
	[self stopAnimations];
	[self storeExpandedState];
	if ([tbDocument insertLapMarker:[[AnimTimer defaultInstance] animTime] inTrack:currentlySelectedTrack])
	{
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
		[self restoreExpandedState];
		[self resetSelectedTrack:currentlySelectedTrack
							 lap:nil];
		[self resetBrowserSelection];
	}
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


- (IBAction) deleteLap:(id)sender
{
	if (currentlySelectedLap)
	{
        Track* savedTrack = currentlySelectedTrack;
		[self stopAnimations];
		[self storeExpandedState];
		if ([tbDocument deleteLap:currentlySelectedLap fromTrack:currentlySelectedTrack])
		{
			[[self window] setDocumentEdited:YES];
			[tbDocument updateChangeCount:NSChangeDone];
            [self buildBrowser:NO];
			[self restoreExpandedState];
			[self resetSelectedTrack:savedTrack
								 lap:nil];
			[self resetBrowserSelection];
		}
	}
}


-(void)compareActivities:(id)sender
{
	[self showCompareWindow:self];
}


- (IBAction) combineActivities:(id)sender
{
	NSArray* arr = [self prepareArrayOfSelectedTracks];
	if ([arr count] > 1)
	{
		[self stopAnimations];
		Track* track = [tbDocument combineTracks:arr];
		if (track)
		{
			[[self window] setDocumentEdited:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[self resetSelectedTrack:track
								 lap:nil];
			[self resetBrowserSelection];
		}
	}
}

	
-(IBAction) splitActivity:(id)sender
{

	NSArray* arr = [self prepareArrayOfSelectedBrowserItemsWithTracks];
	if ([arr count] == 1)
	{
		[self stopAnimations];
        NSTimeInterval threshold = [Utils intFromDefaults:RCBDefaultAutoSplitMinutes];
 		SplitActivityController *sac = [[SplitActivityController alloc] initWithInterval:threshold];
		NSRect fr = [[self window] frame];
		NSRect panelRect = [[sac window] frame];
		NSPoint origin = fr.origin;
		origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
		origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
		
		[[sac window] setFrameOrigin:origin];
		[sac showWindow:self];
        NSModalResponse ok = [NSApp runModalForWindow:[sac window]];
		Track* track = nil;
		if (ok == 0) 
		{
			int splitMethod = [sac splitMethod];
			Track* trk = [[arr objectAtIndex:0] track];
			if (splitMethod == kSplitUsingTimeInterval)
			{
				track = [tbDocument splitTrack:trk
								usingThreshold:[sac timeInterval]*60];
			}
			else if (splitMethod == kSplitAtCurrentTime)
			{
				track = [tbDocument splitTrack:trk
							 atActiveTimeDelta:[[AnimTimer defaultInstance] animTime]];
			}
		}
		[[sac window] orderOut:[self window]];
		[[self window] makeKeyAndOrderFront:self];
		[sac release];
		if (track)
		{
			[[self window] setDocumentEdited:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[self resetSelectedTrack:track
								 lap:nil];
			[self resetBrowserSelection];
		}
	}
}




- (IBAction) getCustomSplitDistance:(id)sender
{
	float cd = [Utils floatFromDefaults:RCBDefaultCustomSplitDistance];
	[customSplitDistanceWC setCustomDistance:cd];
    NSRect fr = [[self window] frame];
	NSRect panelRect = [[customSplitDistanceWC window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);

	[[customSplitDistanceWC window] setFrameOrigin:origin];
	[customSplitDistanceWC showWindow:self];
    NSModalResponse ok = [NSApp runModalForWindow:[customSplitDistanceWC window]];
	if (ok == 0)
	{
		//printf("set split length to %0.1f\n", [customSplitDistanceWC customDistance]);
		[Utils setFloatDefault:[customSplitDistanceWC customDistance] 
						forKey:RCBDefaultCustomSplitDistance];
		[self setSplitLength:sender];		// sender's tag is set to do the right thing when called here
		[self rebuildSplitOptionsMenu];		// custom length may have changed, and is shown in the menu
	}
	[[customSplitDistanceWC window] orderOut:[self window]];
	[[self window] makeKeyAndOrderFront:self];
}



- (IBAction) getGMTOffset:(id)sender
{
   NSArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] > 0)
   {
      Track* t = [arr objectAtIndex:0];
      GMTOffsetController *gmtOffsetWC = [[GMTOffsetController alloc] initWithOffset:[t secondsFromGMTAtSync]/(60.0*60.0)];
      NSRect fr = [[self window] frame];
      NSRect panelRect = [[gmtOffsetWC window] frame];
      NSPoint origin = fr.origin;
      origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
      origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
      
      [[gmtOffsetWC window] setFrameOrigin:origin];
      [gmtOffsetWC showWindow:self];
       NSModalResponse ok = [NSApp runModalForWindow:[gmtOffsetWC window]];
      if (ok == 0)
      {
         [self setGMTOffset:arr
                     offset:[gmtOffsetWC offset]];
      }
      [[gmtOffsetWC window] orderOut:[self window]];
      [[self window] makeKeyAndOrderFront:self];
      [gmtOffsetWC release];
   }
}


- (IBAction) getAltitudeSmoothing:(id)sender
{
	NSArray* arr = [self prepareArrayOfSelectedBrowserItemsWithTracks];
	if ([arr count] > 0)
	{
		Track* t = [[arr objectAtIndex:0] track];
 		AltSmoothingController *asWC = [[AltSmoothingController alloc] initWithFactor:[t altitudeSmoothingFactor]];
		NSRect fr = [[self window] frame];
		NSRect panelRect = [[asWC window] frame];
		NSPoint origin = fr.origin;
		origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
		origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
		
		[[asWC window] setFrameOrigin:origin];
		[asWC showWindow:self];
        NSModalResponse ok = [NSApp runModalForWindow:[asWC window]];
		if (ok == 0)
		{
			[self setAltitudeSmoothing:arr
								factor:[asWC factor]];
		}
		[[asWC window] orderOut:[self window]];
		[[self window] makeKeyAndOrderFront:self];
		[asWC release];
	}
}


- (IBAction) getDistanceMethod:(id)sender
{
   NSArray* arr = [self prepareArrayOfSelectedBrowserItemsWithTracks];
   if ([arr count] > 0)
   {
      Track* t = [[arr objectAtIndex:0] track];
      DistanceMethodController *dmc = [[DistanceMethodController alloc] initWithValue:[t useOrigDistance]];
      NSRect fr = [[self window] frame];
      NSRect panelRect = [[dmc window] frame];
      NSPoint origin = fr.origin;
      origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
      origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
      
      [[dmc window] setFrameOrigin:origin];
      [dmc showWindow:self];
       NSModalResponse ok = [NSApp runModalForWindow:[dmc window]];
      if (ok == 0)
      {
         [self setDistanceMethod:arr useOrig:[dmc useDistanceData]];
      }
      [[dmc window] orderOut:[self window]];
      [[self window] makeKeyAndOrderFront:self];
      [dmc release];
   }
}


- (IBAction) postColumnOptionsPanel:(id)sender
{
   [browserColumnsWC showWindow:self];
    NSModalResponse ok = [NSApp runModalForWindow:[browserColumnsWC window]];
   if (ok == 0) [trackTableView rebuild];
   [[browserColumnsWC window] orderOut:[self window]];
   [[self window] makeKeyAndOrderFront:self];
}


enum
{
	kIsPace				= 0x00000001,
	kUseNumberFormatter = 0x00000002
};

typedef float (*tConvertFunc)(float);

struct tEventInfo
{
	const char*		name;
	const char*		type;
	const char*		unitsStatute;
	const char*		unitsMetric;
	tStatType		statType;
	int				subIndex;
	tConvertFunc	convertFunc;
	int				flags;
};

static tEventInfo sEventInfo[] = 
{
	{ "Heart Rate",		"max", "bpm",		"bpm",              kST_Heartrate,		kMax, 0, kUseNumberFormatter },
	{ "Speed",			"max", "mph",		"km/h",             kST_MovingSpeed,	kMax, &MilesToKilometers, kUseNumberFormatter },
	{ "Pace",			"min", "min/mi",	"min/km",           kST_MovingSpeed,	kMax, 0, kIsPace },
	{ "Gradient",		"max", "%",			"%",                kST_Gradient,		kMax, 0, kUseNumberFormatter },
	{ "Gradient",		"min", "%",			"%",                kST_Gradient,		kMin, 0, kUseNumberFormatter },
	{ "Altitude",		"max", "ft",		"m",                kST_Altitude,		kMax, &FeetToMeters, kUseNumberFormatter },
	{ "Altitude",		"min", "ft",		"m",                kST_Altitude,		kMin, &FeetToMeters, kUseNumberFormatter },
	{ "Cadence",		"max", "rpm",		"rpm",              kST_Cadence,		kMax, 0, kUseNumberFormatter },
	{ "Cadence",		"min", "rpm",		"rpm",              kST_Cadence,		kMin, 0, kUseNumberFormatter },
	{ "Temperature",	"max", "\xC2\xB0""F",	"\xC2\xB0""C",	kST_Temperature,	kMax, &FahrenheightToCelsius, kUseNumberFormatter },
	{ "Temperature",	"min", "\xC2\xB0""F",	"\xC2\xB0""C",	kST_Temperature,	kMin, &FahrenheightToCelsius, kUseNumberFormatter },
};


- (id)objectValueForEventInfoTableColumn:aTableColumn
									 row:(int)rowIndex
{
	id value = @"";
	if (currentlySelectedLap || currentlySelectedTrack)
	{
		BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		tEventInfo& eventInfo = sEventInfo[rowIndex];
		id ident = [aTableColumn identifier];
		if ([ident isEqualToString:@"Metric"])
		{
			value = [NSString stringWithUTF8String:eventInfo.name];
		}
		else if ([ident isEqualToString:@"Type"])
		{
			value = [NSString stringWithUTF8String:eventInfo.type];
		}
		else if ([ident isEqualToString:@"Value"])
		{
			if (FLAG_IS_SET(eventInfo.flags, kIsPace))
			{	
				float val = [currentlySelectedTrack minPace:0];
				value = [Utils convertPaceValueToString:val];
			}
			else
			{
				float val = 0.0;
				if (currentlySelectedLap)
				{
					val = [currentlySelectedTrack statForLap:currentlySelectedLap
													statType:eventInfo.statType
													   index:eventInfo.subIndex
										   atActiveTimeDelta:0];
				}
				else
				{
					val = [currentlySelectedTrack statOrOverride:eventInfo.statType
														   index:eventInfo.subIndex
											   atActiveTimeDelta:0];
				}
				if ((eventInfo.statType == kST_Temperature) && (val == 0.0))
				{
					value = @"n/a";
				}
                else if (((eventInfo.statType == kST_Altitude)||(eventInfo.statType == kST_Gradient)) && (![currentlySelectedTrack hasElevationData] || (BAD_ALTITUDE == val)))
				{
					value = @"n/a";
				}
				else
				{
					NSNumberFormatter* fm = [[[NSNumberFormatter alloc] init] autorelease];
					[fm setNumberStyle:NSNumberFormatterDecimalStyle];
					[fm setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
					[fm setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
					[fm setLocale:[NSLocale currentLocale]];
#endif
					if (!useStatuteUnits && eventInfo.convertFunc) val = eventInfo.convertFunc(val);
					value = [fm stringFromNumber:[NSNumber numberWithFloat:val]];
				}
			}
		}
		else if ([ident isEqualToString:@"Units"])
		{
			BOOL isTemperature =  (eventInfo.statType == kST_Temperature);
			BOOL useCentigrade = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
			if (useStatuteUnits || (isTemperature && !useCentigrade))
			{
				value = [NSString stringWithUTF8String:eventInfo.unitsStatute];
			}
			else
			{
				value = [NSString stringWithUTF8String:eventInfo.unitsMetric];
			}
		}
		else
		{
			NSTimeInterval atTime;
			if (currentlySelectedLap)
			{
				[currentlySelectedTrack statForLap:currentlySelectedLap
											statType:eventInfo.statType
												index:eventInfo.subIndex
									atActiveTimeDelta:&atTime];
			}
			else
			{
				[currentlySelectedTrack statOrOverride:eventInfo.statType
											   index:eventInfo.subIndex
								   atActiveTimeDelta:&atTime];
			}
			int secs = (int)atTime;
			value = [NSString stringWithFormat:@"%02d:%02d:%02d", secs/3600, (secs/60)%60, secs % 60 ];
		}
	}
	return value;
}


- (void) gotoStatTime:(int)idx
{
	tEventInfo& eventInfo = sEventInfo[idx];
	NSTimeInterval atTime;
	if (currentlySelectedLap)
	{
		[currentlySelectedTrack statForLap:currentlySelectedLap
								  statType:eventInfo.statType
									 index:eventInfo.subIndex
						 atActiveTimeDelta:&atTime];
	}
	else
	{
		[currentlySelectedTrack statOrOverride:eventInfo.statType
										 index:eventInfo.subIndex
							 atActiveTimeDelta:&atTime];
	}
	[[AnimTimer defaultInstance] stop:self];
	[[AnimTimer defaultInstance] setAnimTime:atTime];
	
}


//---- helper methods for accessing splits table data ------------------------------------------------------------

- (void)rebuildSplitTable
{
	[splitArray removeAllObjects];
	
	if (currentlySelectedTrack)
	{
		[currentlySelectedTrack calculateTrackStats];
		float splitDist = [Utils currentSplitDistance];
		tStatData statData[kST_NumStats];
		float totalDistance = [currentlySelectedTrack distance];	
		int startIdx = 0;
		SplitTableItem* lastSplitItem = nil;
		NSTimeInterval startTime = 0.0;
		if (splitDist < 0.0)		// if dist < 0, then we use laps
		{
			NSArray* laps = [currentlySelectedTrack laps];
			int numLaps = [laps count];
			int endIdx;
			for (int i=0; i<numLaps; i++)
			{
				Lap* lap = [laps objectAtIndex:i];
				if (i < (numLaps-1))
					endIdx = [currentlySelectedTrack lapStartingIndex:[laps objectAtIndex:i+1]] - 1;
				else
					endIdx = [[currentlySelectedTrack goodPoints] count] - 1;

				[currentlySelectedTrack calculateStats:statData 
											  startIdx:[currentlySelectedTrack lapStartingIndex:lap]
												endIdx:endIdx];
					
				SplitTableItem* splitItem = [[[SplitTableItem alloc] initWithData:startTime
																		distance:[lap distance] 
																	   splitData:statData 
																	activityData:[currentlySelectedTrack statsArray]
																	   prevSplit:lastSplitItem] autorelease];    
				[splitArray addObject:splitItem];	// array takes ownership
				lastSplitItem = splitItem;
				startTime += [currentlySelectedTrack movingDurationOfLap:lap];
			}
		}
		else if ((splitDist > 0) && ([[currentlySelectedTrack goodPoints] count] > 1))
		{
			float curDist = splitDist;
			while ((curDist-splitDist) < totalDistance)
			{
				int endIdx = [currentlySelectedTrack findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:curDist
																								   startAt:startIdx];
				if (endIdx == -1) endIdx = (int)[[currentlySelectedTrack goodPoints] count] - 1;
				if (endIdx > startIdx)
				{				
					[currentlySelectedTrack calculateStats:statData 
												  startIdx:startIdx
													endIdx:endIdx];
												
					SplitTableItem* splitItem = [[[SplitTableItem alloc] initWithData:startTime
																			distance:curDist 
																		   splitData:statData 
																		activityData:[currentlySelectedTrack statsArray]
																		   prevSplit:lastSplitItem] autorelease];
					[splitArray addObject:splitItem];	// array takes ownership
					lastSplitItem = splitItem;
					//startTime = [[[currentlySelectedTrack goodPoints] objectAtIndex:endIdx] wallClockDelta];
                    // BUGFIX split start times and duration are always MOVING TIME
					startTime = [[[currentlySelectedTrack goodPoints] objectAtIndex:endIdx] activeTimeDelta];
				}
				curDist += splitDist;
				startIdx = endIdx;
			}
		}
		[splitsGraphView setSplitArray:splitArray
						   splitsTable:splitsTableView];
		[miniProfileView setSplitArray:splitArray];
		[mapPathView setSplitArray:splitArray];
	}
}


- (int)numberOfSplits
{
	return (int)[splitArray count];
}


- (id)objectValueForSplitsTableColumn:aTableColumn
								  row:(int)rowIndex
{
	id value = @"";
	if (currentlySelectedTrack)
	{
		NSString* identifier = [aTableColumn identifier];
		if (identifier != nil)
		{
			if (rowIndex < [splitArray count])
			{
				SplitTableItem* splitItem = [splitArray objectAtIndex:rowIndex];
				value = [splitItem valueForKey:identifier];
			}
		}
	}
	return value;
}


//---- data source for the MAX/MIN EVENTS AND SPLITS VIEWS -----------------------------------------------

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (aTableView == splitsTableView)
	{
		return [self numberOfSplits];
	}
	else
	{
		return sizeof(sEventInfo)/sizeof(tEventInfo);
	}
}


- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	id value;
	if (aTableView == splitsTableView)
	{
		value = [self objectValueForSplitsTableColumn:aTableColumn
												  row:rowIndex];
	}
	else
	{
		value = [self objectValueForEventInfoTableColumn:aTableColumn
													 row:rowIndex];
	}
	return value;
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSColor* txtColor = nil;
	if (aTableView == splitsTableView)
	{
		if (txtColor == nil) txtColor = [Utils colorFromDefaults:RCBDefaultBrowserActivityColor];
		[aCell setFont:boldLineSmallFont];
	}
	else
	{
		[aCell setFont:boldLineMediumFont];
	}
	if (txtColor == nil) txtColor =  [NSColor blackColor];
	[aCell setTextColor:txtColor];
}



- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	id obj = [aNotification object];
	if (obj == splitsTableView)
	{
		NSIndexSet* selSet = [splitsTableView selectedRowIndexes];
		[splitArray makeObjectsPerformSelector:@selector(deselect)];
		NSInteger idx = [selSet firstIndex];
		while (idx != NSNotFound)
		{
			[[splitArray objectAtIndex:idx] select];
			idx = [selSet indexGreaterThanIndex:idx];
		}
		[splitsGraphView setNeedsDisplay:YES];
		[miniProfileView setNeedsDisplay:YES];
		[mapPathView setNeedsDisplay:YES];
	}
	else if (obj == metricsEventTable)
	{
        NSInteger idx = [metricsEventTable selectedRow];
		if (idx != -1)
		{
			[self gotoStatTime:(int)idx];
		}
	}
}


//---- data source for the OUTLINE VIEW ------------------------------------------------------------

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (outlineView == trackTableView)
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
	}
	return nil;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (outlineView == trackTableView)
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
	}
   return NO;
}


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (outlineView == trackTableView)
	{
		if (item == nil)
		{
			return (int)[[self outlineDict] count];
		}
		else
		{
			return (int)[[item children] count];
		}
	}
	return 0;
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (outlineView == trackTableView)
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


- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                   validateDrop:(id<NSDraggingInfo>)info
                   proposedItem:(id)item
            proposedChildIndex:(int)index
{
    NSPasteboard *pboard = [info draggingPasteboard];

    // Accept any file URLs
    NSDictionary *opts = @{
        NSPasteboardURLReadingFileURLsOnlyKey: @YES
    };

    if ([pboard canReadObjectForClasses:@[ [NSURL class] ] options:opts]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)item childIndex:(int)index
{
	[self processFileDrag:info];
	return YES;
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
   if (aTableView == trackTableView)
   {
      TrackBrowserItem* bi = (TrackBrowserItem*)item;
      if ([bi track] == nil)
      {
         if ([trackTableView isRowSelected:[trackTableView rowForItem:item]] && ([[trackTableView window] firstResponder] == trackTableView))
         {
            txtColor = [NSColor whiteColor];
         }
         else
         {
            switch ([bi type])
            {
               default:
                  txtColor = [NSColor blackColor];
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
         if ([trackTableView isRowSelected:[trackTableView rowForItem:item]] && ([[trackTableView window] firstResponder] == trackTableView))
         {
            txtColor = [NSColor whiteColor];
         }
         switch ([bi type])
         {
            default:
               if (txtColor == nil) txtColor = [NSColor blackColor];
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
      if (txtColor == nil) txtColor =  [NSColor blackColor];
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
      
      if ([trackTableView columnUsesStringCompare:[tableColumn identifier]])
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
	NSIndexSet* is = [trackTableView selectedRowIndexes];
	NSUInteger idx = [is firstIndex];
	while (idx != NSNotFound)
	{
		[selectedItemsAtExpand addObject:[trackTableView itemAtRow:idx]];
		idx = [is indexGreaterThanIndex:idx];
	}
	[self performSelectorOnMainThread:@selector(doSelChange) withObject:nil waitUntilDone:YES];
}




//----------------------------------------------------------------------------------------


- (void)stopAnimations
{
   [[AnimTimer defaultInstance] stop:self];
}


- (void)expandLastItem
{
    NSInteger rows = [trackTableView numberOfRows];
   if (rows > 0)
   {
      id item = [trackTableView  itemAtRow:(rows-1)];
      [trackTableView  expandItem:item];
       NSInteger row = [trackTableView numberOfRows]-1;
      while (([[item children] count]) != 0)
      {
         item = [trackTableView itemAtRow:row];
         [trackTableView expandItem:item];
         row = [trackTableView numberOfRows]-1;
      }
   }
}


- (void)expandFirstItem
{
    NSInteger rows = [trackTableView numberOfRows];
   if (rows > 0)
   {
      id item = [trackTableView  itemAtRow:0];
      [trackTableView  expandItem:item];
      int row = 1;
      while (([[item children] count]) != 0)
      {
         item = [trackTableView itemAtRow:row++];
         [trackTableView expandItem:item];
      }
   }
}


- (void)windowDidLoad
{
   if (reverseSort)
	{
		[self expandFirstItem];
	}
	else
	{
		[self expandLastItem];
	}
}


-(void) beginAnimation
{
}


-(void) endAnimation
{
}


- (void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev  animating:(BOOL)anim;
{
    NSUInteger pos = 0;
	if (currentlySelectedTrack)
	{
        NSUInteger numPoints = [[currentlySelectedTrack goodPoints] count];
		pos = [currentlySelectedTrack animIndex];
		if (pos >= numPoints && numPoints > 0) pos = numPoints-1;
	}
	currentTrackPos = (int)pos;
    [miniProfileView updateTrackAnimation:currentTrackPos];
	[mapPathView updateTrackAnimation:currentTrackPos
							   animID:0];
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return [tbDocument undoManager];
}


- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	[mapPathView setNeedsDisplay:YES];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	[mapPathView setNeedsDisplay:YES];
}


- (IBAction)postMapDataTypeMenu:(id)sender
{
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    BOOL hidden = YES;
    [transparentMapAnimView setHidden:hidden];
    [transparentMiniProfileAnimView setHidden:hidden];
    return frameSize;
}





- (IBAction)setSplitLength:(id)sender
{
	NSInteger tag = [(NSView*)sender tag];
	[Utils setIntDefault:(int)tag
				  forKey:RCBDefaultSplitIndex];
	[self rebuildSplitTable];
	[splitsTableView reloadData];
	[Utils selectMenuItem:(int)tag
				  forMenu:splitLengthSubMenu];
}


- (IBAction)setSplitGraphItem:(id)sender
{
	NSInteger tag = [(NSView*)sender tag];
	[Utils setIntDefault:(int)tag
				  forKey:RCBDefaultSplitGraphItem];
	[splitsGraphView setGraphItem:(int)tag];
	[Utils selectMenuItem:(int)tag
				  forMenu:splitGraphSubMenu];
}


- (IBAction)setBrowserOptions:(id)sender
{
	//int idx = [sender indexOfSelectedItem];
	//int numMenuItems = [[browserOptionsPopup menu] numberOfItems];
	//for (int i=1; i<numMenuItems; i++)
	//{
	//	[[[browserOptionsPopup menu] itemAtIndex:i] setState:i == (idx+1) ? NSControlStateValueOn : NSControlStateValueOff];
	//}
	//[self doSetViewType:idx];
}




- (IBAction)setMapDataType:(id)sender
{
	NSInteger idx = [(NSView*)sender tag];
	int dt = (int)[Utils mapIndexToType:(int)idx];
	[mapPathView setDataType:dt];
	[Utils selectMenuItem:dt
				  forMenu:mapViewDataTypeSubMenu];
	
}


- (IBAction)setColorPathType:(id)sender
{
   int cpz = (int)[sender indexOfSelectedItem];
   [Utils setIntDefault:cpz forKey:RCBDefaultColorPathUsingZone];
   [mapPathView forceRedisplay];   
}


- (IBAction)setMapOpacity:(id)sender
{
   [mapPathView setMapOpacity:[sender floatValue]];
}



- (void) postNeedRegDialog:(NSString*)msg
{
   NSAlert *alert = [[[NSAlert alloc] init] autorelease];
   [alert addButtonWithTitle:@"Register"];
   [alert addButtonWithTitle:@"Not Yet"];
   [alert setMessageText:msg];
   [alert setInformativeText:@"Please purchase a registration key to enable all features."];
   [alert setAlertStyle:NSAlertStyleInformational];
   if ([alert runModal] == NSAlertFirstButtonReturn) 
   {
      NSWindow* w = [self window];
      RegController* rc = [[[RegController alloc] init] autorelease];
      [[rc window] center];
      [rc showWindow:self];
      [NSApp runModalForWindow:[rc window]];
      [[rc window] orderOut:w];
      [w makeKeyAndOrderFront:w];
   }
}


-(NSString*) formatDateIntervalAsString:(NSDate*)dt startDate:(NSDate*)st
{
   NSTimeInterval ti = [dt timeIntervalSinceDate:st];
   int hours = (int)ti/3600;
   int mins = (int)(ti/60.0) % 60;
   int secs = (int)ti % 60;
   return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
}


// outputs the current state of the browser to a csv or tab-seperated file
-(NSString*) buildSummaryTextOutput:(char)sep
{
	NSMutableString* lineString = [NSMutableString stringWithCapacity:4000];
	NSArray* colArray = [trackTableView tableColumns];
    NSUInteger numColumns = [colArray count];
	for (int col=0; col<numColumns; col++)
	{
		NSTableColumn* column = [colArray objectAtIndex:col];
		NSTableHeaderCell* cell = [column headerCell];
		NSString* s = [cell stringValue];
		if (col == (numColumns-1)) 
			[lineString appendString:[NSString stringWithFormat:@"%@", s]];
		else
			[lineString appendString:[NSString stringWithFormat:@"%@%c", s, sep]];
	}
	[lineString appendString:@"\n"];
	 
	int numRows = (int)[trackTableView numberOfRows];
	for (int r=0; r<numRows; r++)
	{
		TrackBrowserItem* bi = [trackTableView itemAtRow:r];
		if (bi)
		{
			for (int col=0; col<numColumns; col++)
			{
				NSTableColumn* column = [colArray objectAtIndex:col];
				id val = [self outlineView:trackTableView
				 objectValueForTableColumn:[colArray objectAtIndex:col]
									byItem:bi];
				NSCell* cell = [column dataCell];	// pick up the formatting from the cell, etc
				[cell setObjectValue:val];	
				NSMutableString* s = [NSMutableString stringWithString:[cell stringValue]];
				// get rid of characters that will screw up import into Excel or Numbers...
				[s replaceOccurrencesOfString:@"," 
								   withString:@" " 
									  options:0 
										range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@"\n" 
								   withString:@" " 
									  options:0 
										range:NSMakeRange(0, [s length])];
				[s replaceOccurrencesOfString:@"\t" 
								   withString:@" " 
									  options:0 
										range:NSMakeRange(0, [s length])];
				if (col == (numColumns-1)) 
					[lineString appendString:[NSString stringWithFormat:@"%@", s]];
				else
					[lineString appendString:[NSString stringWithFormat:@"%@%c", s, sep]];
			}
			[lineString appendString:@"\n"];
		}
	}
	return lineString;
}


- (IBAction)importTCX:(id)sender
{
	[self stopAnimations];
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && ((1 + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		NSOpenPanel* op = [NSOpenPanel openPanel];
		[op setAllowsMultipleSelection:YES];
		NSArray *fileTypes = [NSArray arrayWithObjects:@"tcx", @"hst", nil];
		int status = [op runModalForDirectory:nil
										 file:nil
										types:fileTypes];
		if (status == NSModalResponseOK)	
		{
			NSArray* names = [op filenames];
			if (!([RegController CHECK_REGISTRATION]) && (([names count] + numOld) > kNumUnregisteredTracks))
			{
				[self postActivityImportLimitExeeded];
			}
			else
			{
				[self doTCXImportWithProgress:names];
			}
		}
	}
}


- (IBAction)importFIT:(id)sender
{
	[self stopAnimations];
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && ((1 + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		NSOpenPanel* op = [NSOpenPanel openPanel];
		[op setAllowsMultipleSelection:YES];
		NSArray *fileTypes = [NSArray arrayWithObjects:@"fit", @"FIT", nil];
		int status = [op runModalForDirectory:nil
										 file:nil
										types:fileTypes];
		if (status == NSModalResponseOK)	
		{
			NSArray* names = [op filenames];
			if (!([RegController CHECK_REGISTRATION]) && (([names count] + numOld) > kNumUnregisteredTracks))
			{
				[self postActivityImportLimitExeeded];
			}
			else
			{
				[self doFITImportWithProgress:names];
			}
		}
	}
}



- (IBAction)importHRM:(id)sender
{
	[self stopAnimations];
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && ((1 + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		NSOpenPanel* op = [NSOpenPanel openPanel];
		[op setAllowsMultipleSelection:YES];
		NSArray *fileTypes = [NSArray arrayWithObjects:@"hrm", @"HRM", nil];
		int status = [op runModalForDirectory:nil
										 file:nil
										types:fileTypes];
		if (status == NSModalResponseOK)	
		{
			NSArray* names = [op filenames];
			if (!([RegController CHECK_REGISTRATION]) && (([names count] + numOld) > kNumUnregisteredTracks))
			{
				[self postActivityImportLimitExeeded];
			}
			else
			{
				[self doHRMImportWithProgress:names];
			}
		}
	}
}


- (IBAction)importGPX:(id)sender
{
	[self stopAnimations];
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && ((1 + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		NSOpenPanel* op = [NSOpenPanel openPanel];
		NSArray *fileTypes = [NSArray arrayWithObject:@"gpx"];
		[op setAllowsMultipleSelection:YES];
		int status = [op runModalForDirectory:nil
										 file:nil
										types:fileTypes];
		if (status == NSModalResponseOK)
		{
			NSArray* names = [op filenames];
			if (!([RegController CHECK_REGISTRATION]) && (([names count] + numOld) > kNumUnregisteredTracks))
			{
				[self postActivityImportLimitExeeded];
			}
			else
			{
				[self doGPXImportWithProgress:names];
			}
		}
	}
}


-(void)publish:(id)sender
{
#if 0
	NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
	if ([arr count] > 0)
	{
		DBComm* dbc = [[[DBComm alloc] init] autorelease];
		int result = [dbc loginUser:[Utils stringFromDefaults:RCBDefaultSharingAccountName]
							  email:[Utils stringFromDefaults:RCBDefaultSharingAccountEmail]
						   password:[Utils stringFromDefaults:RCBDefaultSharingAccountPassword]];
		
		if (result > 0)
		{
			[dbc publishTracks:arr];
		}
	}
#endif
}



-(NSString*) baseDirectoryForImportExport
{
	return [NSString stringWithFormat:@"%@/Desktop", NSHomeDirectory()];
}


-(NSString*) baseActivityFileName:(Track*)track fileType:(NSString*)ft
{
   NSDate* date = [track creationTime];
   NSMutableString* s = [NSMutableString stringWithString:@"%d-%b-%y %H_%M."];
   [s appendString:ft];
   NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
   NSString* baseName = [date descriptionWithCalendarFormat:s
                                                   timeZone:tz 
                                                     locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
   return baseName;
}


- (IBAction)exportTCX:(id)sender
{
   [self stopAnimations];
   NSArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] < 1)
   {
      NSAlert *alert = [[[NSAlert alloc] init] autorelease];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select one or more tracks in the browser for export"];
      //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
      NSSavePanel *sp;
      int runResult;
      
      /* create or get the shared instance of NSSavePanel */
      sp = [NSSavePanel savePanel];
      
      /* set up new attributes */
      [sp setRequiredFileType:@"tcx"];
      
      /* display the NSSavePanel */
      NSString* baseName = [self baseActivityFileName:[arr objectAtIndex:0]
                                             fileType:@"tcx"];
      runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport] 
									  file:baseName];
      
      /* if successful, save file under designated name */
      if (runResult == NSModalResponseOK) 
      {
         [tbDocument exportTCXFile:arr 
                          fileName:[sp filename]];
         
      }
   }
}



- (IBAction)exportGPX:(id)sender
{
   [self stopAnimations];
   NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] != 1)
   {
      NSAlert *alert = [[[NSAlert alloc] init] autorelease];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select a single track in the browser for export"];
      //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
      NSSavePanel *sp;
      int runResult;
      
      /* create or get the shared instance of NSSavePanel */
      sp = [NSSavePanel savePanel];
      
      /* set up new attributes */
      //[sp setAccessoryView:newView];
      [sp setRequiredFileType:@"gpx"];
      
      /* display the NSSavePanel */
      NSString* baseName = [self baseActivityFileName:[arr objectAtIndex:0]
                                             fileType:@"gpx"];
      runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport]  
									  file:baseName];
      
      /* if successful, save file under designated name */
      if (runResult == NSModalResponseOK) 
      {
         [tbDocument exportGPXFile:[arr objectAtIndex:0] 
                          fileName:[sp filename]];
         
      }
   }
}


- (IBAction)exportKML:(id)sender
{
   [self stopAnimations];
   NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] != 1)
   {
	   NSAlert *alert = [[[NSAlert alloc] init] autorelease];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select a single track in the browser for export"];
      //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
      NSSavePanel *sp;
      int runResult;
      
      /* create or get the shared instance of NSSavePanel */
      sp = [NSSavePanel savePanel];
      
      /* set up new attributes */
      //[sp setAccessoryView:newView];
      [sp setRequiredFileType:@"kml"];
      
      /* display the NSSavePanel */
      NSString* baseName = [self baseActivityFileName:[arr objectAtIndex:0]
                                             fileType:@"kml"];
      runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport]  
									  file:baseName];
      
      /* if successful, save file under designated name */
      if (runResult == NSModalResponseOK) 
      {
         [tbDocument exportKMLFile:[arr objectAtIndex:0] 
                          fileName:[sp filename]];
         
      }
   }
}




- (IBAction)googleEarthFlyBy:(id)sender
{
   [self stopAnimations];
   NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] != 1)
   {
 	   NSAlert *alert = [[[NSAlert alloc] init] autorelease];
     [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select a single track in the browser for fly-by"];
      //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
       NSError* error;
      Track* track = [arr objectAtIndex:0];
      NSDate* trackDate = [track creationTime];
      NSString* frm = @"%d-%b-%y at %I:%M%p";
      NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
      NSString* dayKey = [trackDate descriptionWithCalendarFormat:frm
                                                         timeZone:tz 
                                                           locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
      NSMutableString* filename = [NSMutableString stringWithString:getTempPath()];
      if (filename != nil)
      {
         NSFileManager* fm = [NSFileManager defaultManager];
         [fm removeItemAtPath:filename 
                        error:&error];
         filename = [[[NSMutableString alloc] initWithString:getTempPath()] autorelease];    
      }
      [filename  appendString:@"/"];
      [filename  appendString:dayKey];
      [filename  appendString:@".kml"];
      NSFileManager* fm = [NSFileManager defaultManager];
      [fm removeItemAtPath:filename 
                     error:&error];
      [tbDocument exportKMLFile:[arr objectAtIndex:0] 
                       fileName:filename];
      BOOL worked = [[NSWorkspace sharedWorkspace] openFile:filename 
                                            withApplication:@"Google Earth"];
      if (worked == NO)
      {
         NSAlert *alert = [[[NSAlert alloc] init] autorelease];
         [alert addButtonWithTitle:@"OK"];
         [alert setMessageText:@"There was a problem completing this request. Have you installed Google Earth?"];
         [alert setInformativeText:@"This feature requires Google Earth to be installed."];
         [alert setAlertStyle:NSAlertStyleInformational];
         [alert runModal];
      }
   }
}


-(void) doExportTextFile:(NSString*)suffix seperator:(char)sep
{
	[self stopAnimations];
	NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
	if ([arr count] != 1)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Please select a single track in the browser for export"];
		//[alert setInformativeText:@"Please purchase a registration key to enable all features."];
		[alert setAlertStyle:NSAlertStyleInformational];
		[alert runModal];
	}
	else
	{
		NSSavePanel *sp;
		int runResult;

		/* create or get the shared instance of NSSavePanel */
		sp = [NSSavePanel savePanel];

		/* set up new attributes */
		//[sp setAccessoryView:newView];
		[sp setRequiredFileType:suffix];

		/* display the NSSavePanel */
		NSString* baseName = [self baseActivityFileName:[arr objectAtIndex:0]
											   fileType:suffix];
		runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport]  
										file:baseName];

		/* if successful, save file under designated name */
		if (runResult == NSModalResponseOK) 
		{
			Track* track = [arr objectAtIndex:0];
			NSString* s = [track buildTextOutput:sep];
			if (![s writeToURL:[sp URL] 
					atomically:YES
					  encoding:NSUTF8StringEncoding
						 error:NULL]) 
			{
				NSLog(@"Could not write document out...");
			}   
		}
	}
}


- (IBAction)exportCSV:(id)sender
{
   [self doExportTextFile:@"csv" seperator:','];
}


- (IBAction)exportTXT:(id)sender
{
   [self doExportTextFile:@"tsv" seperator:'\t'];
}


-(void) doExportSummaryTextFile:(NSString*)suffix seperator:(char)sep
{
	[self stopAnimations];
	NSSavePanel *sp;
	int runResult;
	
	/* create or get the shared instance of NSSavePanel */
	sp = [NSSavePanel savePanel];
	
	/* set up new attributes */
	//[sp setAccessoryView:newView];
	[sp setRequiredFileType:suffix];
	
	/* display the NSSavePanel */
	NSMutableString* baseName = [NSMutableString stringWithString:[tbDocument displayName]];
	[baseName appendString:@"."];
	[baseName appendString:suffix];
	runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport]  
									file:baseName];
	
	/* if successful, save file under designated name */
	if (runResult == NSModalResponseOK) 
	{
		NSString* s = [self buildSummaryTextOutput:sep];
		if (![s writeToURL:[sp URL] 
				atomically:YES
				  encoding:NSUTF8StringEncoding
					 error:NULL]) 
		{
			NSLog(@"Could not write document out...");
		}   
	}
}




- (IBAction)exportSummaryCSV:(id)sender
{
	[self doExportSummaryTextFile:@"csv" seperator:','];
}


- (IBAction)exportSummaryTXT:(id)sender
{
	[self doExportSummaryTextFile:@"tsv" seperator:'\t'];
}



- (IBAction)exportLatLonText:(id)sender
{
   [self stopAnimations];
   NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] != 1)
   {
      NSAlert *alert = [[[NSAlert alloc] init] autorelease];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select a single track in the browser for export"];
      //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
      [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
       NSSavePanel *sp = [NSSavePanel savePanel];

       // Instead of setAllowedFileTypes:
       if (@available(macOS 11.0, *)) {
           // “Plain text” UTI
           [sp setAllowedContentTypes:@[ UTTypePlainText ]];
       } else {
           // Fallback for older macOS
           [sp setAllowedFileTypes:@[@"txt"]];
       }

       [sp setCanCreateDirectories:YES];
       [sp setExtensionHidden:NO];

       // Suggested file name
       NSString *baseName = [self baseActivityFileName:[arr objectAtIndex:0]
                                              fileType:@"txt"];
       [sp setNameFieldStringValue:baseName];

       // Starting directory
       [sp setDirectoryURL:[NSURL fileURLWithPath:[self baseDirectoryForImportExport]
                                      isDirectory:YES]];

       // Show panel
       NSInteger runResult = [sp runModal];
       if (runResult == NSModalResponseOK) {
           NSURL *destURL = [sp URL];
           // use destURL
       }
       
      /* if successful, save file under designated name */
      if (runResult == NSModalResponseOK) 
      {
          NSURL *destURL = [sp URL];
          if (destURL) {
              [tbDocument exportLatLonTextFile:[arr objectAtIndex:0]
                                      fileName:[destURL path]];
          }
      }
   }
   
}



- (int)viewType 
{
   return viewType;
}


- (IBAction)setViewType:(id)sender
{
   [self doSetViewType:(int)[sender indexOfSelectedItem]];
}


- (IBAction)setInfoPopupItem:(id)sender
{
   BOOL changed = NO;
   NSInteger attrID = [(NSView*)sender tag];
   if ([sender indexOfSelectedItem] >= [sender numberOfItems]-1)
   {
      NSString* prevSel = [currentlySelectedTrack attribute:(int)attrID];
      int sts = [Utils editAttributeList:sender
                             attributeID:(int)attrID
                                      wc:self];
      
      changed = (sts == 0);
      if (currentlySelectedTrack == nil)
      {
         [self setEmptyInfoPopup:sender];
      }
      else
      {
         if (changed)
         {
               [Utils buildPopupMenuFromItems:[Utils attrIDToDefaultsKey:(int)attrID]
                                        popup:sender
                             currentSelection:[currentlySelectedTrack attribute:(int)attrID]];
         }
         [sender selectItemWithTitle:prevSel]; 
       }
   }
   else
   {
      NSString *newSel = [attrMap[attrID].editControl titleOfSelectedItem];
      if ((newSel != nil) && (currentlySelectedTrack != nil))
      {
		  [currentlySelectedTrack setAttribute:attrMap[attrID].attributeID usingString:newSel];
		  if (attrID == kActivity)
		  {
			  [currentlySelectedTrack fixupTrack];
		  }
		  changed = YES;
      }
   }
   if (changed)
   {
      [[self window] setDocumentEdited:YES];
      [tbDocument updateChangeCount:NSChangeDone];
      [trackTableView rebuild];
   }
}






- (IBAction)setWeight:(id)sender
{
   if (nil != currentlySelectedTrack)
   { 
		BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		float v = [sender floatValue];
		// always store values in STATUTE units, even if it's a string!
		if (!useStatuteUnits)
		{
		 v = KilogramsToPounds(v);
		}
		[currentlySelectedTrack setWeight:v];
		//[Utils setIntDefault:(int)v forKey:RCBDefaultWeight];
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
	   [self updateCurrentTrackRow];
	   
	}
}


- (IBAction) setFieldLabel:(int)lableID label:(NSString*)label
{
   switch (lableID)
   {
      case kLID_Custom:
         [customTextFieldLabel setStringValue:label];
         break;
         
      case kLID_Keyword1:
         [keyword1PopupLabel setStringValue:label];
         break;
         
      case kLID_Keyword2:
         [keyword2PopupLabel setStringValue:label];
         break;
      
      default:
         break;
   }
}


- (IBAction)setInfoTextField:(id)sender
{
	NSInteger attrID = [(NSView*)sender tag];
	NSString *s = [attrMap[attrID].editControl stringValue];
	if ((s != nil) && (currentlySelectedTrack != nil))
	{
	  [currentlySelectedTrack setAttribute:attrMap[attrID].attributeID usingString:s];
	  [[self window] setDocumentEdited:YES];
	  [tbDocument updateChangeCount:NSChangeDone];
	}
	if ([self calendarViewActive]) 
	{
		[calendarView setNeedsDisplay:YES];
	}
	else
	{
		[self updateCurrentTrackRow];
	}
}


- (void)syncTrackToAttributesAndEditWindow:(Track*)track
{
	if (track != nil)
	{
		int i = 0;
		for (i=0; i<kNumAttributes; i++)
		{
			if (attrMap[i].editControl != nil)
			{
				NSString* s = [track attribute:attrMap[i].attributeID];
				NSString* pt = attrMap[i].placeholderText;
				if (FLAG_IS_SET(attrMap[i].flags, kIsPopup))
				{
					[attrMap[i].editControl selectItemWithTitle:s];
					//[attrMap[i].editControl setTitle:s];
				}
				else if (FLAG_IS_SET(attrMap[i].flags, kIsTextView) != 0)
				{
					TextViewWithPlaceholder* tv = (TextViewWithPlaceholder*)attrMap[i].editControl;
					[tv setString:s];
					[tv scrollRangeToVisible:NSMakeRange(0,1)];
					if (!s || [s isEqualToString:@""])
					{
						tv.placeholderText = attrMap[i].placeholderText;
						tv.showPlaceholder = YES;
					}
					else
					{
						tv.placeholderText = nil;
						tv.showPlaceholder = NO;
					}
					[tv setNeedsDisplay:YES];
				}
				else
				{
					[attrMap[i].editControl setStringValue:s];
					if (pt)
					{
						if (!s || [s isEqualToString:@""])
						{
							[[attrMap[i].editControl cell] setPlaceholderString:pt];
						}
						else
						{
							[[attrMap[i].editControl cell] setPlaceholderString:nil];
						}
					}
				}
			}
		}
		float v = [track weight];
		BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		if (!useStatuteUnits)
		{
			v = PoundsToKilograms(v);
		}
		NSString* s = [NSString stringWithFormat:@"%0.1f", v];
		[editWeightField setStringValue:s];
		[equipmentBox update];

	}
}

	 
	 

-(void) updateCurrentTrackRow
{
	if (currentlySelectedTrack != nil)
	{
		int sr = (int)[trackTableView selectedRow];
		TrackBrowserItem* item = [trackTableView itemAtRow:sr];
		if ([item type] == kTypeLap)
		{
			item = [trackTableView parentForItem:item];
			sr = (int)[trackTableView rowForItem:item];
		}
		if ([item type] == kTypeActivity)
		{
			[trackTableView setNeedsDisplayInRect:[trackTableView rectOfRow:sr]];
		}
	}
}

	 
	 
	 

-(void)updateBrowserFromTextField:(int)attr textField:(NSTextField*)tf
{
	NSString *s = [tf stringValue];
	if ((s != nil) && (currentlySelectedTrack != nil))
	{
		[currentlySelectedTrack setAttribute:attrMap[attr].attributeID usingString:s];
		[[self window] setDocumentEdited:YES];
		[self updateCurrentTrackRow];
	}
}

	 
-(void)updateBrowserFromTextView:(int)attr textView:(NSTextView*)tv
{
	NSString *s = [[tv textStorage] string];
	if ((s != nil) && (currentlySelectedTrack != nil))
	{
		[currentlySelectedTrack setAttribute:attrMap[attr].attributeID usingString:s];
		[[self window] setDocumentEdited:YES];
		[self updateCurrentTrackRow];
	}
}
	 

- (void)textDidChange:(NSNotification *)aNotification
{
	 int attr = kBadAttr;
	 id obj = [aNotification object];
	 if (obj == notesTextView)
		 attr = kNotes;
	if (attr != kBadAttr)
	{
		[self updateBrowserFromTextView:attr
							   textView:obj];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	int attr = kBadAttr;
	id obj = [aNotification object];
	if (obj == editActivityName)
		attr = kName;
	else if (obj == notesTextView)
		attr = kNotes;
	else if (obj == editWeightField)
		attr = kWeight;
	else if (obj == customTextField)
		attr = kCustom1;
	if (attr != kBadAttr)
	{
		[self updateBrowserFromTextField:attr
							   textField:obj];
	}
}

	 
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{
	id obj = [aNotification object];
	if (obj == notesTextView)
	{
		//[obj setAlignment:NSTextAlignmentLeft];
	}
}
	 
	 

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	[tbDocument updateChangeCount:NSChangeDone];
}

//---- TextField delegate methods ----------------------------------------------

	 //- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector 
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector	 
{
	BOOL retval = NO;
	if (aSelector == @selector(insertNewline:)) 
	{
		retval = YES;
		if (aTextView == notesTextView) 
		{
			[aTextView insertNewlineIgnoringFieldEditor:nil];
			//[aTextView validateEditing];
		}
	}
	return retval;
}



-(void)setTimeAtField:(NSTextField*)fld theTimeDelta:(NSTimeInterval)atd
{
	if (atd > 0.0)
	{
		int secs = (int)atd;
		NSString* str = [NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d", secs/3600, (secs % 3600)/60, secs % 60];
		[fld setStringValue:str];
	}
	else
	{
		[fld setStringValue:@""];
	}
}   

- (NSRect) centerStringInFrame:(NSRect)fr text:(NSString*)s
{
   
   NSSize size = [s sizeWithAttributes:activityAttrs];
   float w = fr.size.width;
   float h = fr.size.height;
   float x = fr.origin.x + w/2.0 - size.width/2.0;
   float y = fr.origin.y + h/2.0 - size.height/2.0;
   fr.origin.x = x;
   fr.origin.y = y;
   size.width += 2.0;
   fr.size = size;
   return fr;
}


- (void)clearAttributes
{
	int i = 0;
	for (i=0; i<kNumAttributes; i++)
	{
		if (attrMap[i].editControl != nil)
		{
			if ((attrMap[i].flags & kIsPopup) != 0)
			{
				[attrMap[i].editControl selectItemWithTitle:@""];
			}
			else if ((attrMap[i].flags & kIsTextView) != 0)
			{
				TextViewWithPlaceholder* tv = (TextViewWithPlaceholder*)attrMap[i].editControl;
				[attrMap[i].editControl setString:@""];
				tv.placeholderText = @"";
				tv.showPlaceholder = NO;
				[tv setNeedsDisplay:YES];
			}
			else
			{
				[attrMap[i].editControl setStringValue:@""];
				[[attrMap[i].editControl cell] setPlaceholderString:@""];
			}
		}
	}
}


- (void) enableControlsRequiringASelectedTrack:(BOOL)enable
{
   //[mapDetailButton setEnabled:enable];
   //[activityDetailButton setEnabled:enable];
	[setEquipmentButton setEnabled:enable];
	[editWeightField setEnabled:enable];
	[customTextField setEnabled:enable];
	[keyword1Popup setEnabled:enable];
	[keyword2Popup setEnabled:enable];
	//[equipmentPopup setEnabled:enable];
	[activityPopup setEnabled:enable];
	[effortPopup setEnabled:enable];
	[weatherPopup setEnabled:enable];
	[dispositionPopup setEnabled:enable];
	[eventTypePopup setEnabled:enable];
}


-(void)resetSelectedTrack:(Track*)trk lap:(Lap*)lap
{
	if ((currentlySelectedTrack != trk) ||
	    (currentlySelectedLap != lap))
	{
		if (currentlySelectedTrack != trk)
		{
			[currentlySelectedTrack release];
			currentlySelectedTrack = [trk retain];
		}
		if (currentlySelectedLap != lap)
		{
			[currentlySelectedLap release];
			currentlySelectedLap = [lap retain];
		}
		[[AnimTimer defaultInstance] setAnimTime:0];
		[tbDocument setCurrentlySelectedTrack:trk];
		[tbDocument setSelectedLap:lap];
		[self buildInfoPopupMenus];

		if (currentlySelectedTrack != nil)
		{
			[activityDetailButton setEnabled:YES];
			[detailedMapButton setEnabled:YES];
			[compareActivitiesButton setEnabled:YES];
			[self enableControlsRequiringASelectedTrack:YES];
			BOOL hasPoints = [[trk goodPoints] count] > 1;
			[transparentMapAnimView setHidden:!hasPoints];
			[transparentMiniProfileAnimView setHidden:!hasPoints];
			[mapPathView setSelectedLap:currentlySelectedLap];
			[miniProfileView setSelectedLap:currentlySelectedLap];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LapSelectionChanged" object:currentlySelectedLap];
			[miniProfileView setCurrentTrack:currentlySelectedTrack];
			[mapPathView setCurrentTrack:currentlySelectedTrack];
			[self syncTrackToAttributesAndEditWindow:currentlySelectedTrack];
			[equipmentBox setTrack:trk];
			currentTrackPos = 0;
			currentlySelectedTrack.animTimeBegin = 0.0;
			currentlySelectedTrack.animTimeEnd = currentlySelectedTrack.movingDuration;
		}		
		else
		{
			[activityDetailButton setEnabled:NO];
			[detailedMapButton setEnabled:NO];
			[compareActivitiesButton setEnabled:NO];
			[transparentMapAnimView setHidden:YES];
			[transparentMiniProfileAnimView setHidden:YES];
			[self enableControlsRequiringASelectedTrack:NO];
			[miniProfileView setCurrentTrack:nil];
			[mapPathView setCurrentTrack:nil];
			[mapPathView setSelectedLap:nil];
			[miniProfileView setSelectedLap:nil];
			[self clearAttributes];
		}
		//[tbDocument selectionChanged];
		[[AnimTimer defaultInstance] updateTimerDuration];
		[mapPathView setDefaults];
		[miniProfileView setNeedsDisplay:YES];
		[metricsEventTable reloadData];
		[self rebuildSplitTable];
		[splitsGraphView setSplitArray:splitArray
						   splitsTable:splitsTableView];
		[miniProfileView setSplitArray:splitArray];
		[mapPathView setSplitArray:splitArray];
		if (currentlySelectedLap)
		{
			float start = [currentlySelectedTrack lapActiveTimeDelta:currentlySelectedLap];
			float end = start + [currentlySelectedTrack movingDurationOfLap:currentlySelectedLap] - 1.0;	// end 1 second before next starts
			//printf("SELECT LAP, lap start:%0.1f end:%01.f\n", start, end);
			[splitsGraphView setSelectedLapTimes:start
											 end:end];
		}
		else
		{
			[splitsGraphView setSelectedLapTimes:-42.0
											 end:-43.0];
		}
		[splitsGraphView setGraphItem:[Utils intFromDefaults:RCBDefaultSplitGraphItem]];		
		[splitsTableView reloadData];
	}
}


-(void) doSelChange
{
	[self stopAnimations];
	int row = (int)[trackTableView  selectedRow];
	if (row != -1)
	{
		TrackBrowserItem* bi = [trackTableView  itemAtRow:row];
		[self resetSelectedTrack:[bi track] lap:[bi lap]];
	}
    else
    {
		[self resetSelectedTrack:nil
                             lap:nil];
    }
}







- (IBAction)syncGPS:(id)sender
{
	[self startProgressIndicator:@"Syncing GPS ... this may take a few minutes"];
	[tbDocument syncGPS];
	[self doSelChange];
	[self endProgressIndicator];
	[[self window] setDocumentEdited:YES];
}



- (void)fade:(NSTimer *)theTimer
{
   if ([[self window] alphaValue] > 0.0) {
      // If window is still partially opaque, reduce its opacity.
      [[self window]  setAlphaValue:[[self window]  alphaValue] - 0.2];
   } else {
      // Otherwise, if window is completely transparent, destroy the timer and close the window.
      [fadeTimer invalidate];
      [fadeTimer release];
      fadeTimer = nil;
      
      [[self window]  close];
      
      // Make the window fully opaque again for next time.
      [[self window]  setAlphaValue:1.0];
   }
}



- (BOOL)windowShouldClose:(id)sender
{
   // Set up our timer to periodically call the fade: method.
   ///fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES] retain];
   
   // Don't close just yet.
   ///return NO;
	return YES;
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[self dismissCompareWindow:self];
	[self dismissDetailedMapWindow:self];
	[trackTableView setDelegate:nil];
	[trackTableView setDataSource:nil];
	[mainSplitView setDelegate:nil];
	[leftSplitView  setDelegate:nil];
	[rightSplitView  setDelegate:nil];
	 
	[self stopAnimations];
	[[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
}



- (MapPathView*) mapPathView
{
   return mapPathView;
}


- (void)windowDidResize:(NSNotification *)aNotification
{
   //NSLog(@"window %x resized", [self window]);
   //[[self window] saveFrameUsingName:@"TBWindowFrame"];
   [self repositionTransparentWindows];
   if (currentlySelectedTrack != nil)
   {
      [self syncTrackToAttributesAndEditWindow:currentlySelectedTrack];
   }
   else
   {
      [self clearAttributes];
   }
    BOOL hidden = NO;
    [self syncTransparentViews];
    [transparentMapAnimView setHidden:hidden];
    [transparentMiniProfileAnimView setHidden:hidden];
}


- (void)windowDidMove:(NSNotification *)aNotification
{
   //NSLog(@"window %x moved", [self window]);
   [self repositionTransparentWindows];
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
    if ([self calendarViewActive])
    {
        [self doToggleCalendarAndBrowser:1];
    }
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


- (IBAction) toggleStatsInfo:(id)sender
{
	[infoStatsTabView selectTabViewItemAtIndex:[infoStatsTabView indexOfTabViewItem:[infoStatsTabView selectedTabViewItem]] == 1 ? 0 : 1];
}

       
- (IBAction) toggleMainBrowser:(id)sender
{
	[self doToggleCalendarAndBrowser:(int)[sender selectedSegment]];
}

- (IBAction)syncStravaActivities:(id)sender
{
    NSWindow *host = self.window ?: NSApp.keyWindow ?: NSApp.mainWindow;

    // Helper so we don't duplicate import start logic
    void (^startImportWithToken)(NSString *) = ^(NSString *token) {
        [self startProgressIndicator:@"syncing activities from Strava…"];

        NSDateComponents *dc = [NSDateComponents new];
        dc.year = 2025; dc.month = 4; dc.day = 1;
        NSDate *since = [[NSCalendar currentCalendar] dateFromComponents:dc];
        [dc release];

        StravaImporter *importer = [[StravaImporter alloc] initWithAccessToken:token];

        __block BOOL madeDeterminate = NO;
        [importer importTracksSince:since
                            perPage:200
                           maxPages:4
                           progress:^(NSUInteger pagesFetched, NSUInteger totalSoFar) {
                               // already on main
                               if (!madeDeterminate && totalSoFar > 0) {
                                   madeDeterminate = YES;
                                   [[[SharedProgressBar sharedInstance] controller]
                                       begin:@"syncing Strava activities…"
                                       divisions:(int)totalSoFar];
                               } else {
                                   [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                               }
                           }
                         completion:^(NSArray *tracks, NSError *error) {
                             // main thread
                             if (error) {
                                 NSLog(@"Strava import failed: %@", error);
                             } else {
                                 [self updateProgressIndicator:@"updating browser..."];
                                 [tbDocument addTracks:[tracks mutableCopy]];
                                 // [self buildBrowser:YES];
                             }
                             [importer release];
                             [self endProgressIndicator];
                         }];
    };

    // 1) Try to reuse/refresh token silently.
    [[StravaAPI shared] fetchFreshAccessToken:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (!error && token.length) {
            // We already have a fresh token (either reused or silently refreshed).
            startImportWithToken(token);
            return;
        }

        // 2) If we get 401/“authorization required”, *then* run the browser flow.
        if ([error.domain isEqualToString:@"Strava"] && error.code == 401) {
            [[StravaAPI shared] startAuthorizationFromWindow:host completion:^(NSError * _Nullable authErr) {
                if (authErr) {
                    NSLog(@"Error authorizing with Strava: %@", authErr);
                    return;
                }
                // After browser auth, the API has stored fresh tokens;
                // fetch the token (fast path) and start import.
                [[StravaAPI shared] fetchFreshAccessToken:^(NSString * _Nullable token2, NSError * _Nullable err2) {
                    if (err2 || token2.length == 0) {
                        NSLog(@"Could not obtain token after auth: %@", err2);
                        return;
                    }
                    startImportWithToken(token2);
                }];
            }];
            return;
        }

        // Other error (network, parse, etc.)
        NSLog(@"Token fetch error: %@", error);
    }];
}


- (void)addStravaActivities:(NSArray<NSDictionary*> *) activities
{
#if 0
    NSUInteger numTracks = [activities count];
    for (i=0; i<numTracks; )
    NSDictionary *lastActivity = [activities lastObject];

    for (NSDictionary *activity in activities) {
        NSLog(@"Activity name=%@", [activity objectForKey:@"name"]);
    }

    if (lastActivity) {
        NSNumber *actID = [lastActivity objectForKey:@"id"];
        
        [[StravaAPI shared] fetchActivityStreams:actID
                                           types:@[@"latlng", @"heartrate", @"velocity_smooth", @"time"]
                                      completion:^(NSDictionary<NSString *,NSArray *> * _Nullable streams, NSError * _Nullable error) {
            if (streams) {
                int wtff = 42;
                wtff++;
            }
            // streams[@"latlng"] -> array of [lat,lon]
            // streams[@"heartrate"] -> array of bpm
            // streams[@"velocity_smooth"] -> m/s (convert to mph or km/h)
            // streams[@"time"] -> seconds from start (aligned with the above)
        }];
    }
#endif
}

- (IBAction)showActivityDetail:(id)sender
{
   [[NSNotificationCenter defaultCenter] postNotificationName:@"OpenActivityDetail" object:self];
}


-(IBAction) showCompareWindow:(id) sender
{
	NSArray* arr = [self prepareArrayOfSelectedTracks];
	if (compareWC == nil)
	{
		compareWC = [[CompareWindowController alloc] initWithTracks:arr
															 mainWC:self];
		[compareWC showWindow:self];
	}
	else
	{
		[compareWC resetTracks:arr
						mainWC:self];
		[[compareWC window] makeKeyAndOrderFront:self];
	}
}


-(void)dismissCompareWindow:(id)sender
{
	if (compareWC)
	{
		compareWC.mainWindowController = nil;
		[compareWC autorelease];
		compareWC = nil;
 	}
}


- (IBAction)showMapDetail:(id)sender
{
	if (dmWC  == nil)
	{
        Track* track = [tbDocument currentlySelectedTrack];
        if (nil != track)
        {
            int curDataType = [[self mapPathView] dataType];
            dmWC   = [[DMWindowController alloc] initWithDocument:tbDocument 
                                                  initialDataType:curDataType
                                                           mainWC:self];
            [tbDocument addWindowController:dmWC];
            [dmWC autorelease];
            [dmWC showWindow:self];
            [dmWC setTrack:track];
            if (currentlySelectedLap) [dmWC setSelectedLap:currentlySelectedLap];
            
        }
    }
    else
    {
 		[[dmWC window] makeKeyAndOrderFront:self];
    }
}


-(void)dismissDetailedMapWindow:(id)sender
{
	if (dmWC)
	{
		dmWC.mainWC = nil;
		dmWC = nil;
 	}
}



- (IBAction)showSummaryGraph:(id)sender
{
    [self stopAnimations];
 	if (sgWC == nil)
    {
        sgWC = [[SGWindowController alloc] initWithDocument:tbDocument
                                                     mainWC:self];
        [tbDocument addWindowController:sgWC];
        [sgWC autorelease];
        NSWindow* wind = [sgWC window];
        NSString* title = @"Summary Info";
        [wind setTitle:title];
        [sgWC showWindow:self];
        
    }
    else
    {
 		[[sgWC window] makeKeyAndOrderFront:self];
   }
}


-(void)dismissSummaryGraphWindow:(id)sender
{
	if (sgWC)
	{
		sgWC.mainWC = nil;
		sgWC = nil;
 	}
}



- (IBAction)showDataDetail:(id)sender
{
   [[NSNotificationCenter defaultCenter] postNotificationName:@"OpenDataDetail" object:self];
}



- (IBAction) showGarminSync:(id) sender
{
	//if (![EquipmentListWindowController isPosted])
	{
		[self stopAnimations];
		GarminSyncWindowController* gswc = [[GarminSyncWindowController alloc] initWithDocument:tbDocument];
		
		NSRect fr = [[self window] frame];
		NSRect panelRect = [[gswc window] frame];
		NSPoint origin = fr.origin;
		origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
		origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
		
		[[gswc window] setFrameOrigin:origin];
		
		// NOTE: runModalForWindow does NOT work with WebView!!
		
		NSModalSession session = [NSApp beginModalSessionForWindow:[gswc window]];
        NSModalResponse result = NSModalResponseContinue;
		
		// Loop until some result other than continues:
		while (result == NSModalResponseContinue)
		{
			// Run the window modally until there are no events to process:
			result = [NSApp runModalSession:session];
			
			// Give the main loop some time:
			[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
		}
		
		[NSApp endModalSession:session];
		[[self window] makeKeyAndOrderFront:self];
		[gswc importNewFiles];
		[gswc autorelease];
	}
}


-(IBAction) showEquipmentList:(id) sender
{
	if (equipmentListWC == nil)
	{
		equipmentListWC = [[EquipmentListWindowController alloc] initWithDocument:tbDocument];
	}
	[[equipmentListWC window] makeKeyAndOrderFront:self];
}


-(void)doSelectEquipmentItem:(NSString*)eid
{
    if (equipmentListWC)
    {
        [equipmentListWC selectEquipmentItemWithUniqueID:eid];
    }
}

	 
- (void)equipmentButtonPushedAction:(NSString*)eid
{
	if (equipmentListWC == nil)
	{
		equipmentListWC = [[EquipmentListWindowController alloc] initWithDocument:tbDocument];
		[equipmentListWC showWindow:self];
	}
	[[equipmentListWC window] makeKeyAndOrderFront:self];
    [self performSelector:@selector(doSelectEquipmentItem:)
               withObject:eid
               afterDelay:0.5];
}
	 
	 
	 
-(void)dismissEquipmentList:(id)wc
{
	if (equipmentListWC)
	{
		[equipmentListWC autorelease];
		equipmentListWC = nil;
 	}
}




-(IBAction)showEquipmentSelector:(id)sender
{
	[self stopAnimations];
	EquipmentSelectorWindowController* eswc = [[EquipmentSelectorWindowController alloc] initWithDocument:tbDocument];
	
	NSRect fr = [[self window] frame];
	NSRect panelRect = [[eswc window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
	
	[[eswc window] setFrameOrigin:origin];
	NSModalSession session = [NSApp beginModalSessionForWindow:[eswc window]];
    NSModalResponse result = NSModalResponseContinue;
	
	// Loop until some result other than continues:
	while (result == NSModalResponseContinue)
	{
		// Run the window modally until there are no events to process:
		result = [NSApp runModalSession:session];
		
		// Give the main loop some time:
		[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
	}
	
	[NSApp endModalSession:session];
	[[self window] makeKeyAndOrderFront:self];
	[eswc autorelease];
	[[self window] setDocumentEdited:YES];
	[self updateCurrentTrackRow];
	[self syncTrackToAttributesAndEditWindow:currentlySelectedTrack];
	[currentlySelectedTrack setEquipmentWeight:[[EquipmentLog sharedInstance] equipmentWeightForTrack:currentlySelectedTrack]];
	if ([eswc showEquipmentLogOnExit])
	{
		[self showEquipmentList:self];
	}
	if ([self isSearchUnderway])
	{
		[self buildBrowser:NO];
	}
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" object:currentlySelectedTrack];
}	


- (void) buildBrowser:(BOOL)expandLastItem
{
	//NSLog(@"build browser START");
	BOOL searchUnderway = [self isSearchUnderway];
	NSMutableDictionary* topDict;
	if (searchUnderway)
	{
	  topDict = [self searchItems];
	}
	else
	{
	  topDict = [self yearItems];
	}
    [expandedItems removeAllObjects];
	[topDict removeAllObjects];
	NSCalendar* cal = [NSCalendar currentCalendar];
	NSMutableArray* trackArray = [tbDocument trackArray];
	NSUInteger numTracks = [trackArray count];
	int i;
	NSDate* trackDate;
	NSCalendarDate *caldate;
	NSCalendarDate *firstDayOfWeekDate;
	NSString* dayKey;
	NSString* weekKey;
	NSString* monthKey;
	NSString* yearKey;
	int timeFormat = [Utils intFromDefaults:RCBDefaultTimeFormat];
	NSString* frm;
	NSString* lapFrm;
	NSString* actFrm;
	if (timeFormat == 0)
	{
		frm = [NSString stringWithFormat:@"%@ at %%I:%%M:%%S%%p", [Utils dateFormat]];
		lapFrm = @"%I:%M:%S%p";
		actFrm = @"%A, %B %d, %Y at %I:%M:%S%p";
	}
	else
	{
		frm = [NSString stringWithFormat:@"%@ at %%H:%%M:%%S", [Utils dateFormat]];
		lapFrm = @"%H:%M:%S";
		actFrm = @"%A, %B %d, %Y at %H:%M:%S";
	}
	int weekStartDay = [Utils intFromDefaults:RCBDefaultWeekStartDay];
	++seqno;
	for (i=0; i<numTracks; i++)
	{
		Track* track = [trackArray objectAtIndex:i];
		NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
		if ([self passesSearchCriteria:track])
		{
			trackDate = [track creationTime];
			if (!trackDate) 
			{
				NSLog(@"nil TRACK CREATION DATE MISSING!");
				continue;
			}
			NSDateComponents* comps = [cal components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSWeekCalendarUnit|NSDayCalendarUnit)  fromDate:trackDate];
			if (comps != nil)
			{
				NSInteger year = [comps year];
                NSInteger month = [comps month];
				caldate = [NSCalendarDate dateWithYear:year
												 month:month 
												   day:[comps day] 
												  hour:0 
												minute:0 
												second:0 
											  timeZone:tz];
		   
				// get date of first day in week
				int dayOfWeek = [caldate dayOfWeek];
				if ((weekStartDay == 1) && (dayOfWeek == 0)) dayOfWeek = 7; // finagle for monday start
                NSInteger ws = [comps day] - dayOfWeek + weekStartDay;    // weekStartDay is 0 for sunday
				firstDayOfWeekDate = [NSCalendarDate dateWithYear:[comps year] month:[comps month] day:ws
															 hour:0 minute:0 second:0 timeZone:tz];
				yearKey  = [caldate descriptionWithCalendarFormat:@"%Y Activities"];
				monthKey = [caldate descriptionWithCalendarFormat:@"%B '%y"];
				weekKey  = [firstDayOfWeekDate descriptionWithCalendarFormat:[NSString stringWithFormat:@"Week of %@",[Utils dateFormat]]];
				dayKey = [trackDate descriptionWithCalendarFormat:frm
														 timeZone:tz 
														   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
		   
				NSMutableDictionary* curDict = topDict;
				TrackBrowserItem* yearBI = nil;
				TrackBrowserItem* monthBI = nil;
				TrackBrowserItem* weekBI = nil;
				if ((viewType == kViewTypeCurrent) || (viewType == kViewTypeYears))
				{
					yearBI = [flatBIDict objectForKey:yearKey];
					if (yearBI == nil)
					{
						yearBI = [[[TrackBrowserItem alloc] initWithData:nil 
																	 lap:nil 
																	name:yearKey 
																	date:caldate 
																	type:kTypeYear 
																  parent:nil] autorelease];
						[flatBIDict setObject:yearBI
									   forKey:yearKey];
					}
					else
					{
						[yearBI invalidateCache:NO];
					}
					[curDict setObject:yearBI 
								forKey:yearKey];
					curDict = [yearBI children];
					if (yearBI.seqno != seqno)
					{
						[curDict removeAllObjects];
						yearBI.seqno = seqno;
					}
				}
		   
				if ((viewType == kViewTypeCurrent) || (viewType == kViewTypeYears) || (viewType == kViewTypeMonths))
				{
					// have to include year in key for cached objects since week
					// may span years (in Dec/Jan) and we need two unique entries
					// in this case
					monthBI = [flatBIDict objectForKey:monthKey];
					if (monthBI == nil)
					{
						monthBI = [[[TrackBrowserItem alloc] initWithData:nil 
																	  lap:nil 
																	 name:monthKey 
																	 date:caldate  
																	 type:kTypeMonth 
																   parent:yearBI] autorelease];
						[flatBIDict setObject:monthBI
									   forKey:monthKey];
					}
					else
					{
						[monthBI invalidateCache:NO];
					}
					[curDict setObject:monthBI 
								forKey:monthKey];
					curDict = [monthBI children];
					[monthBI setParentItem:yearBI];
					if (monthBI.seqno != seqno)
					{
						[curDict removeAllObjects];
						monthBI.seqno = seqno;
					}
				}
		   
		   
				if ((viewType == kViewTypeCurrent) || /*(viewType == kViewTypeYears) || (viewType == kViewTypeMonths) || */ (viewType == kViewTypeWeeks)  )
				{
					// have to include year in key for cached objects since week
					// may span years (in Dec/Jan) and we need two unique entries
					// in this case
					NSString* userVisibileWeekName = [[weekKey copy] autorelease];
					if (viewType != kViewTypeWeeks) weekKey = [weekKey stringByAppendingFormat:@"_%d_%d", (int)year, (int)month];
					weekBI = [flatBIDict objectForKey:weekKey];
					if (weekBI == nil)
					{
						weekBI = [[[TrackBrowserItem alloc] initWithData:nil 
																	 lap:nil 
																	name:userVisibileWeekName 
																	date:caldate  
																	type:kTypeWeek 
																  parent:monthBI] autorelease];
						
						[flatBIDict setObject:weekBI
									   forKey:weekKey];
					}
					else
					{
						[weekBI invalidateCache:NO];
					}
					[weekBI setParentItem:monthBI];
					[curDict setObject:weekBI 
								forKey:weekKey];
					curDict = [weekBI children];
					if (weekBI.seqno != seqno)
					{
						[curDict removeAllObjects];
						weekBI.seqno = seqno;
					}
				}
		   
				TrackBrowserItem* activityBI = [flatBIDict objectForKey:dayKey];
				if (activityBI == nil)
				{
					activityBI = [[[TrackBrowserItem alloc] initWithData:track 
																	 lap:nil 
																	name:dayKey 
																	date:trackDate  
																	type:kTypeActivity 
																  parent:weekBI] autorelease];
					[flatBIDict setObject:activityBI
								   forKey:dayKey];
				}
				else
				{
					if (track != [activityBI track])
					{
						[activityBI invalidateCache:NO];
						[activityBI setTrack:track];
						[activityBI setDate:trackDate];
					}
				}
				[activityBI setParentItem:weekBI];
				[curDict setObject:activityBI 
							forKey:dayKey];
				curDict = [activityBI children];
				if (activityBI.seqno != seqno)
				{
					[curDict removeAllObjects];
					activityBI.seqno = seqno;
				}
			
				NSMutableDictionary* lapItems = [activityBI children];
				NSArray* laps = [track laps];
                NSUInteger numLaps = [laps count];
				if (numLaps > 0)
				{
					Lap* lap = [laps objectAtIndex:0];
					float lapEndTime = [lap startingWallClockTimeDelta] + [track durationOfLap:lap];
					if ((numLaps > 1) || (lapEndTime < [track duration]))
					{
						for (int i=0; i<numLaps; i++)
						{
							Lap* lap = [laps objectAtIndex:i];
							NSMutableString* s;
							if (i == (numLaps-1))
							{
								s = [NSMutableString stringWithFormat:@"Finish at "];
							}
							else
							{
								s = [NSMutableString stringWithFormat:@"Lap %d at ", i+1];
							}
							[s appendString:[[track lapEndTime:lap] descriptionWithCalendarFormat:lapFrm
																						 timeZone:tz 
																						   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
							TrackBrowserItem* child = [[[TrackBrowserItem alloc] initWithData:track 
																						  lap:(Lap*)lap 
																						 name:s 
																						 date:[track lapStartTime:lap] 
																						 type:kTypeLap 
																					   parent:activityBI] autorelease];
							[lapItems setObject:child 
										 forKey:s];
							// don't store laps in flatBIdict, never need to be expanded which is what we use the flatDict for
						}
					}
				}
			}
		}
	}
	//NSLog(@"build browser REBUILT");
	[self reloadTable];
	//NSLog(@"build browser table RELOADED");
	[self resetInfoLabels];
	if (expandLastItem == YES) 
	{
		if (reverseSort)
		{
			[self expandFirstItem];
		}
		else
		{
			[self expandLastItem];
		}
	}
}



//--------------------------------


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


-(NSMutableArray*) prepareArrayOfSelectedTracks
{
	NSMutableArray* arr = nil;
	if ([self calendarViewActive])
	{
		if ([calendarView selectedTrack] != nil)
		{
			arr = [NSMutableArray arrayWithArray:[calendarView selectedTrackArray]];
		}
	}
	else
	{
			
		NSIndexSet* selSet = [trackTableView selectedRowIndexes];
		arr = [NSMutableArray arrayWithCapacity:[selSet count]];
		NSInteger idx = [selSet firstIndex];
		while (idx != NSNotFound)
		{
			TrackBrowserItem* bi = [trackTableView itemAtRow:idx];
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
   NSIndexSet* selSet = [trackTableView selectedRowIndexes];
   NSMutableArray* arr = [NSMutableArray arrayWithCapacity:[selSet count]];
   NSInteger idx = [selSet firstIndex];
   while (idx != NSNotFound)
   {
      TrackBrowserItem* bi = [trackTableView itemAtRow:idx];
      if (bi != nil)
      {
         [self addBrowserItemsWithTracks:bi
                                 toArray:arr];
      }
      idx = [selSet indexGreaterThanIndex:idx];
   }
   return arr;
}   



- (IBAction)delete:(id)sender
{
	NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
	if ([arr count] > 0)
	{
		[trackTableView deselectAll:self];
		[tbDocument deleteTracks:arr];
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
	}
}


- (IBAction)copy:(id)sender
{
	NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
	if ([arr count] > 0)
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb declareTypes:[NSArray arrayWithObjects:TrackPBoardType,nil] owner:self];

		[pb setData:[NSArchiver archivedDataWithRootObject:arr]
		  forType:TrackPBoardType];
		//[pb setString:[self buildTextOutput:arr sep:'\t'] 
		//	forType:NSStringPboardType];
		NSString* txt = [self buildSummaryTextOutput:'\t'] ;
		[pb setString:txt
			forType:NSTabularTextPboardType];
		[pb setString:txt 
			  forType:NSStringPboardType];
	}
}



- (IBAction)saveSelectedTracks:(id)sender
{
   NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
   if ([arr count] < 1)
   {
      NSAlert *alert = [[[NSAlert alloc] init] autorelease];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please select one or more tracks in the browser"];
       [alert setAlertStyle:NSAlertStyleInformational];
      [alert runModal];
   }
   else
   {
      NSSavePanel *sp;
      int runResult;
      
      /* create or get the shared instance of NSSavePanel */
      sp = [NSSavePanel savePanel];
      
      /* set up new attributes */
      //[sp setAccessoryView:newView];
      [sp setRequiredFileType:@"tlp"];
      
      /* display the NSSavePanel */
      NSString* fname;
      if ([arr count] == 1)
      {
         Track* firstTrack = [arr objectAtIndex:0];
         fname = [self baseActivityFileName:firstTrack
                                   fileType:@"tlp"];
      }
      else
      {
         fname = @"Selected Activities.tlp";
      }
      
      runResult = [sp runModalForDirectory:[self baseDirectoryForImportExport]  
									  file:fname];
      
      /* if successful, save file under designated name */
      if (runResult == NSModalResponseOK) 
      {
         TrackBrowserDocument* doc = [[[TrackBrowserDocument alloc] init] autorelease];
         [doc setTracks:arr];
         NSError* err;
         NSURL* url = [NSURL fileURLWithPath:[sp filename]];
         
         [doc writeToURL:url
                 ofType:@"tlp"
                   error:&err];
            
      }
   }
}   


- (IBAction)cut:(id)sender
{
   [self copy:sender];
   [self storeExpandedState];
   [self delete:sender];
   [self restoreExpandedState];
   [trackTableView deselectAll:sender];
}


- (IBAction)paste:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSData *data = [pb dataForType:TrackPBoardType];
	if (data)
	{
		NSMutableArray* arr = [NSUnarchiver unarchiveObjectWithData:data];
		int numNew = [arr count];
		int numOld = [[tbDocument trackArray] count];
		if (!([RegController CHECK_REGISTRATION]) && ((numNew + numOld) > kNumUnregisteredTracks))
		{
			[self postNeedRegDialog:@"This feature is not available or could not be completed in an unregistered version of Ascent."];
		}
		else
		{
		  [self storeExpandedState];
		  [tbDocument addTracks:arr];
		  [[self window] setDocumentEdited:YES];
		  [tbDocument updateChangeCount:NSChangeDone];
		  [self restoreExpandedState];
		  [trackTableView deselectAll:sender];
		}
   }
}



- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	BOOL ret = YES;
	SEL action = [anItem action];
	
    NSUInteger numSelectedTracks = [[self prepareArrayOfSelectedTracks] count];
	if (action == @selector(setUploadToMobile:))
	{
		NSMenuItem* mi = (NSMenuItem*)anItem;
		[mi setState:[currentlySelectedTrack uploadToMobile]];
 		return numSelectedTracks == 1;
 	}
	else if ((action == @selector(exportGPX:)) ||
			 (action == @selector(exportTCX:)))
	{
		return numSelectedTracks > 0;
	}
	else if ((action == @selector(exportKML:)) ||
			 (action == @selector(exportCSV:)) ||
			 (action == @selector(exportTXT:)) ||
			 (action == @selector(splitActivity:)) ||
			 (action == @selector(showMapDetail:)) ||
			 (action == @selector(showDataDetail:)) ||
			 (action == @selector(showActivityDetail:)) ||
			 (action == @selector(googleEarthFlyBy:)) ||
			 (action == @selector(editActivity:)))
	{ 
		return numSelectedTracks == 1;
	}
	else if ((action == @selector(copy:)) ||
			 (action == @selector(cut:)) ||
			 (action == @selector(delete:)) ||
			 (action == @selector(getGMTOffset:)) ||
			 (action == @selector(getDistanceMethod:)) ||
			 (action == @selector(mailActivity:)) ||
			 (action == @selector(saveSelectedTracks:)) ||
			 (action == @selector(getAltitudeSmoothing:)))
	{
		if ([self calendarViewActive])
		{
			ret = [calendarView selectedTrack] != nil;
		}
		else
		{
			ret = ([trackTableView numberOfSelectedRows] > 0);
		}
	}
	else if  (action == @selector(paste:))
	{
		return ([[NSPasteboard generalPasteboard] dataForType:TrackPBoardType] != nil);
	}
	else if (action == @selector(combineActivities:))
	{
		if ([self calendarViewActive])
		{
			ret = NO;
		}
		else
		{
			 ret = ([trackTableView numberOfSelectedRows] > 1);
		}
	}
	else if ((action == @selector(deleteLap:))  ||
			 (action == @selector(insertLapMarker:)))
	{
		if ([self calendarViewActive])
		{
			ret = NO;
		}
		else
		{
			ret = (currentlySelectedLap != nil);
		}
	}
	else if ((action == @selector(zoomIn:)) ||
			 (action == @selector(zoomOut:)))
	{
		ret = NO;
	}
	else if (action == @selector(selectAll:))
	{
		ret = ![self calendarViewActive];
	}
	//NSLog(@"validate ui item: %@ : %s", [(NSMenuItem*)anItem title], ret ? "YES" : "NO");
	return ret;
}

- (Track*) animationTrack
{
   return currentlySelectedTrack;
}



#define kScriptName (@"send_activity")
#define kScriptType (@"scpt")
#define kHandlerName (@"send_activity")
#define noScriptErr 0

-(IBAction) mailActivity:(id)sender
{
    NSMutableArray* arr = [self prepareArrayOfSelectedTracks];
    if ([arr count] < 1)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select one or more tracks in the browser"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
    }
    else
    {
        Track* firstTrack = [arr objectAtIndex:0];
        NSString* baseName = [self baseActivityFileName:firstTrack
                                             fileType:@"tlp"];
        NSMutableString* s;
        if ([arr count] > 1)
        {
            s = [NSMutableString stringWithString:@"Ascent activities attached"];
        }
        else
        {
            s = [NSMutableString stringWithString:@"Ascent activity from %d-%b-%y attached"];
        }
        NSDate* date = [firstTrack creationTime];
        NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[firstTrack secondsFromGMTAtSync]];
        NSString* subject = [date descriptionWithCalendarFormat:s
                                                      timeZone:tz 
                                                        locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
      
      
        NSMutableString* filePath = [[[NSMutableString alloc] initWithString:getTempPath()] autorelease];
        if (filePath != nil)
        {
            NSFileManager* fm = [NSFileManager defaultManager];
            NSError* error;
            [fm removeItemAtPath:filePath error:&error];
            filePath = [[[NSMutableString alloc] initWithString:getTempPath()] autorelease];    
        }
        [filePath appendString:@"/"];
        [filePath appendString:baseName];
         
        TrackBrowserDocument* doc = [[[TrackBrowserDocument alloc] init] autorelease];
        [doc setTracks:arr];
        NSURL* url = [NSURL fileURLWithPath:filePath];

        NSError* err;
        [doc writeToURL:url
                 ofType:@"tlp"
                  error:&err];

        NSAppleEventDescriptor *arguments = [[[NSAppleEventDescriptor alloc] initListDescriptor] autorelease];
        [arguments insertDescriptor: [NSAppleEventDescriptor descriptorWithString:filePath] atIndex: 1];
        [arguments insertDescriptor: [NSAppleEventDescriptor descriptorWithString:subject] atIndex: 2];

        NSDictionary *errorInfo = nil;
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource: kScriptName ofType: kScriptType];
        NSURL *scriptURL = [NSURL fileURLWithPath: scriptPath];
        NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:scriptURL error: &errorInfo] autorelease];
      
      /* Call the handler using the method in our special category */
      /*NSAppleEventDescriptor *result = */ [script callHandler: kHandlerName withArguments: arguments errorInfo: &errorInfo];
      
//      int scriptResult = [result int32Value];
//      
//      /* Check for errors in running the handler */
//      if (errorInfo) {
//         [self handleScriptError: errorInfo];
//      }
//      /* Check the handler's return value */
//      else if (scriptResult != noScriptErr) {
//         NSRunAlertPanel(NSLocalizedString(@"Script Failure", @"Title on script failure window."), [NSString stringWithFormat: @"%@ %d", NSLocalizedString(@"The script failed:", @"Message on script failure window."), scriptResult], NSLocalizedString(@"OK", @""), nil, nil);
//      }
    }
}


-(void) contextualMenuAction:(id)sender
{
	switch ([(NSView*)sender tag])
	{
		case kCMAddActivity:
			[self addActivity:self];
			break;
		   
		case kCMEditActivity:
			[self editActivity:self];
			break;
		   
		case kCMSplitActivity:
			[self splitActivity:self];
			break;
			
		case kCMCombineActivities:
			[self combineActivities:self];
			break;
			
		case kCMCompareActivities:
			[self compareActivities:self];
			break;
			
		case kCMRefreshMap:
			[self refreshMap:self];
			break;
			
		case kCMEmailSelected:
			[self mailActivity:self];
			break;
		 
		case kCMSaveSelected:
			[self saveSelectedTracks:self];
			break;
		 
		case kCMGoogleFlyBy:
			[self googleEarthFlyBy:self];
			break;
		 
		case kCMExportGPX:
			[self exportGPX:self];
			break;
		 
		case kCMExportTCX:
			[self exportTCX:self];
			break;
		 
		case kCMExportKML:
			[self exportKML:self];
			break;
		
		case kCMAdjustGMTOffset:
			[self getGMTOffset:self];
			break;
		
		case kCMAltitudeSmoothing:
			[self getAltitudeSmoothing:self];
			break;
		   
		case kCMExportCSV:
			[self exportCSV:self];
			break;
		  
		case kCMExportTXT:
			[self exportTXT:self];
			break;
		 
		case kCMExportSummaryCSV:
			[self exportSummaryCSV:self];
			break;
		  
		case kCMExportSummaryTXT:
			[self exportSummaryTXT:self];
			break;
		  
		case kCMOpenActivityDetail:
			[self showActivityDetail:self];
			break;
		 
		case kCMOpenMapDetail:
			[self showMapDetail:self];
			break;
		 
		case kCMOpenDataDetail:
			[self showDataDetail:self];
			break;
		 
		case kCMCut:
			[self cut:self];
			break;
		 
		case kCMCopy:
			[self copy:self];
			break;
		 
		case kCMPaste:
			[self paste:self];
			break;
	}
   
}

//---- tab view stuff

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
   int idx = (int)[infoStatsTabView indexOfTabViewItem:[infoStatsTabView selectedTabViewItem]];
   [Utils setIntDefault:idx forKey:RCBDefaultBrowserTabView];
}



- (void) doTCXImport:(NSArray*)files showProgress:(BOOL)sp
{
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && (([files count] + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		if (sp) [self startProgressIndicator:@"Importing tracks..."];
        NSUInteger num = [files count];
		Track* lastTrack = nil;
		for (int i=0; i<num; i++)
		{
			NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
			NSString* file = [files objectAtIndex:i];
			if (sp) [self updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
			lastTrack = [tbDocument importTCXFile:file];
			[localPool release];
		}
		if (lastTrack != nil)
		{
			[self buildBrowser:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[[self window] setDocumentEdited:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:tbDocument];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
			[self  selectLastImportedTrack:lastTrack];
		}			
		if (sp) [self endProgressIndicator];
	}
}

- (void) doTCXImportWithoutProgress:(NSArray*)files
{
	[self doTCXImport:files
		 showProgress:NO];
}

- (void) doTCXImportWithProgress:(NSArray*)files
{
	[self doTCXImport:files
		 showProgress:YES];
}


- (void) postActivityImportLimitExeeded
{
	[self postNeedRegDialog:@"Only 10 activities per document are permitted in an unregistered version of Ascent.  "
							 "To test this feature, create a new, empty activity document (CMD-N) and import less than 10 activities."];
}


- (void) processFileDrag:(id < NSDraggingInfo >)info
{
	NSPasteboard* pboard = [info draggingPasteboard];
    //NSData* rowData = [pboard dataForType:MyPrivateTableViewDataType];
    //NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) 
	{
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        // Depending on the dragging source and modifier keys,
        // the file data may be copied or linked
 		[self addDataFromFiles:files];
        
    }
}


-(void)addDataFromFiles:(NSArray*) files
{
    NSUInteger num = [files count];
	NSMutableArray* tcxArray = [NSMutableArray arrayWithCapacity:num];
	NSMutableArray* gpxArray = [NSMutableArray arrayWithCapacity:num];
	NSMutableArray* hrmArray = [NSMutableArray arrayWithCapacity:num];
	NSMutableArray* fitArray = [NSMutableArray arrayWithCapacity:num];
	for (int i=0; i<num; i++)
	{
		NSString* fileName = [files objectAtIndex:i];
		NSString* ext = [[fileName pathExtension] lowercaseString];
		if ([ext isEqualToString:@"tcx"])
		{
			[tcxArray addObject:fileName];
		}
		else if ([ext isEqualToString:@"gpx"])
		{
			[gpxArray addObject:fileName];
		}
		else if ([ext isEqualToString:@"hrm"])
		{
			[hrmArray addObject:fileName];
		}
		else if ([ext isEqualToString:@"fit"])
		{
			[fitArray addObject:fileName];
		}
		else if ([ext isEqualToString:@"tlp"])
		{
		}
	}
	if ([tcxArray count] > 0) [self doTCXImportWithProgress:tcxArray];
	if ([gpxArray count] > 0) [self doGPXImportWithProgress:gpxArray];
	if ([hrmArray count] > 0) [self doHRMImportWithProgress:hrmArray];
	if ([fitArray count] > 0) [self doFITImportWithProgress:fitArray];
}


-(void) startProgressIndicator:(NSString*)text
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	NSRect fr = [[self window] frame];
	NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
	NSPoint origin;
	origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
	origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
	[[[pb controller] window] setFrameOrigin:origin];
	[[pb controller] showWindow:self];
	[[pb controller] begin:@"" 
				 divisions:0];
	[[pb controller] updateMessage:text];
}

- (void) updateProgressIndicator:(NSString*)msg
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	[[pb controller] updateMessage:msg];
}

- (void) endProgressIndicator
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	[[pb controller] end];
	[[[pb controller] window] orderOut:[self window]];
}


-(void) selectLastImportedTrack:(Track*)lastImportedTrack
{
	if (lastImportedTrack && [self calendarViewActive])
	{
		NSCalendarDate* calDate = [[lastImportedTrack creationTime] dateWithCalendarFormat:nil 
																				  timeZone:nil];
		[calendarView setVisibleMonth:calDate];
		[calendarView setSelectedDay:calDate];
	}
}




- (void) doGPXImportWithProgress:(NSArray*)files
{
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && (([files count] + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		[self startProgressIndicator:@"Importing tracks..."];
        NSUInteger num = [files count];
		Track* lastTrack = nil;
		for (int i=0; i<num; i++)
		{
			NSString* file = [files objectAtIndex:i];
			[self updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
			lastTrack = [tbDocument importGPXFile:file];
		}
		if (lastTrack != nil)
		{
			[self buildBrowser:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[[self window] setDocumentEdited:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:tbDocument];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
			[self  selectLastImportedTrack:lastTrack];
		}
		[self endProgressIndicator];
	}
}


- (void) doHRMImportWithProgress:(NSArray*)files
{
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && (([files count] + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		[self startProgressIndicator:@"Importing tracks..."];
        NSUInteger num = [files count];
		Track* lastTrack = nil;
		for (int i=0; i<num; i++)
		{
			NSString* file = [files objectAtIndex:i];
			[self updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
			lastTrack = [tbDocument importHRMFile:file];
		}
		if (lastTrack != nil)
		{
			[self buildBrowser:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[[self window] setDocumentEdited:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:tbDocument];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
			[self  selectLastImportedTrack:lastTrack];
		}
		[self endProgressIndicator];
	}
}


- (void) doFITImportWithProgress:(NSArray*)files
{
    NSUInteger numOld = [[tbDocument trackArray] count];
	if (!([RegController CHECK_REGISTRATION]) && (([files count] + numOld) > kNumUnregisteredTracks))
	{
		[self postActivityImportLimitExeeded];
	}
	else
	{
		[self startProgressIndicator:@"Importing FIT tracks..."];
        NSUInteger num = [files count];
		Track* lastTrack = nil;
		for (int i=0; i<num; i++)
		{
			NSString* file = [files objectAtIndex:i];
			[self updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
			lastTrack = [tbDocument importFITFile:file];
		}
		if (lastTrack != nil)
		{
			[self buildBrowser:YES];
			[tbDocument updateChangeCount:NSChangeDone];
			[[self window] setDocumentEdited:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:tbDocument];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
			[self  selectLastImportedTrack:lastTrack];
		}
		[self endProgressIndicator];
	}
}


- (BOOL)shouldCloseDocument
{
	return YES;
}



-(NSMutableDictionary*) outlineDict
{
	if ([[self searchCriteria] isEqualToString:@""] && ([searchItems count] == 0))
	{
		return yearItems;
	}
	return searchItems;
}

- (BOOL) calendarViewActive
{
	return [calOrBrowControl selectedSegment]  == 0;
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


-(void) reloadTable
{
	self.topSortedKeys = nil;
	[trackTableView reloadData];
	[metricsEventTable reloadData];
	//[totalActvitiesField setStringValue:[NSString stringWithFormat:@"%d activities", [[tbDocument trackArray] count]]];
	//[totalActvitiesField display];
	if ([self calendarViewActive])
	{
		[calendarView invalidateCache];
		[calendarView setNeedsDisplay:YES];
	}
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
			NSString* title = [track attribute:kName];
			NSRange r = [title rangeOfString:searchCriteria options:NSCaseInsensitiveSearch];
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


-(void) refreshMap:(id)sender
{
	[mapPathView refreshMaps];
}

- (NSArray*)trackArray
{
	return [tbDocument trackArray];
}


//------------------------------------------------------------------------------
// NSToolbarDelegate methods

// This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching NSToolbarItem.
// It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
// going to be displayed in a customization palette.
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    // We create and autorelease a new NSToolbarItem, and then go through the process of setting up its
    // attributes from the master toolbar item matching that identifier in our dictionary of items.
    NSToolbarItem *newItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    NSToolbarItem *item=[toolbarItems objectForKey:itemIdentifier];
    
    [newItem setLabel:[item label]];
    [newItem setPaletteLabel:[item paletteLabel]];
    if ([item view]!=NULL)
    {
		[newItem setView:[item view]];
    }
    else
    {
		[newItem setImage:[item image]];
    }
    [newItem setToolTip:[item toolTip]];
    [newItem setTarget:[item target]];
    [newItem setAction:[item action]];
    [newItem setMenuFormRepresentation:[item menuFormRepresentation]];
#if 0
    // If we have a custom view, we *have* to set the min/max size - otherwise, it'll default to 0,0 and the custom
    // view won't show up at all!  This doesn't affect toolbar items with images, however.
    if ([newItem view]!=NULL)
    {
		NSSize sz = [[item view] bounds].size;
		[newItem setMinSize:sz];
		[newItem setMaxSize:sz];
	}
#endif
    return newItem;
}


// This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
// set of toolbar items.  It can also be called by the customization palette to display the default toolbar.    
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:@"BrowOrCal",@"SplitsOptions", @"LeftOptionsCog", NSToolbarSeparatorItemIdentifier,@"SearchBrowser", NSToolbarFlexibleSpaceItemIdentifier, @"CompareActivities", @"ActivityDetail", @"MapDetail", @"Summary", nil];
}

// This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
// toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:@"BrowOrCal",@"SplitsOptions", @"LeftOptionsCog", @"CompareActivities",  @"ActivityDetail", @"MapDetail",  @"Summary", NSToolbarSeparatorItemIdentifier, @"SearchBrowser", NSToolbarSpaceItemIdentifier,NSToolbarFlexibleSpaceItemIdentifier,nil];
}



//------------------------------------------------------------------------------

@end

//---- more toolbar stuff

// All NSToolbarItems have a unique identifer associated with them, used to tell your delegate/controller what 
// toolbar items to initialize and return at various points.  Typically, for a given identifier, you need to 
// generate a copy of your "master" toolbar item, and return it autoreleased.  The function below takes an
// NSMutableDictionary to hold your master NSToolbarItems and a bunch of NSToolbarItem paramenters,
// and it creates a new NSToolbarItem with those parameters, adding it to the dictionary.  Then the dictionary
// can be used from -toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar: to generate a new copy of the 
// requested NSToolbarItem (when the toolbar wants to redraw, for instance) by simply duplicating and returning
// the NSToolbarItem that has the same identifier in the dictionary.  Plus, it's easy to call this function
// repeatedly to generate lots of NSToolbarItems for your toolbar.
// -------
// label, palettelabel, toolTip, action, and menu can all be NULL, depending upon what you want the item to do
static NSToolbarItem* addToolbarItem(NSMutableDictionary *theDict,NSString *identifier,NSString *label,
						   NSString *paletteLabel,NSString *toolTip,id target,SEL settingSelector, 
						   id itemContent,SEL action, NSMenu * menu)
{
    NSMenuItem *mItem;
    // here we create the NSToolbarItem and setup its attributes in line with the parameters
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    [item setLabel:label];
    [item setPaletteLabel:paletteLabel];
    [item setToolTip:toolTip];
    [item setTarget:target];
    // the settingSelector parameter can either be @selector(setView:) or @selector(setImage:).  Pass in the right
    // one depending upon whether your NSToolbarItem will have a custom view or an image, respectively
    // (in the itemContent parameter).  Then this next line will do the right thing automatically.
    [item performSelector:settingSelector withObject:itemContent];
    [item setAction:action];
    // If this NSToolbarItem is supposed to have a menu "form representation" associated with it (for text-only mode),
    // we set it up here.  Actually, you have to hand an NSMenuItem (not a complete NSMenu) to the toolbar item,
    // so we create a dummy NSMenuItem that has our real menu as a submenu.
    if (menu!=NULL)
    {
		// we actually need an NSMenuItem here, so we construct one
		mItem=[[[NSMenuItem alloc] init] autorelease];
		[mItem setSubmenu: menu];
		[mItem setTitle: [menu title]];
		[item setMenuFormRepresentation:mItem];
    }
    // Now that we've setup all the settings for this new toolbar item, we add it to the dictionary.
    // The dictionary retains the toolbar item for us, which is why we could autorelease it when we created
    // it (above).
    [theDict setObject:item forKey:identifier];
    return item;
}


