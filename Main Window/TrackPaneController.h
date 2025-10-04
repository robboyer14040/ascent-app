//
//  TrackPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TrackListHandling.h"

@class TrackBrowserDocument, Selection;
@class TrackListController, TrackCalendarController;
@class SplitDragHandleView;
@class LeftSplitController;

@interface TrackPaneController : NSViewController <NSUserInterfaceValidations, NSPopoverDelegate>
{
@private
    TrackBrowserDocument    *_document; // assign
    Selection               *_selection;           // retained
    BOOL                    _calendarMode;
    TrackListController     *_outlineVC;
    TrackCalendarController *_calendarVC;
    NSViewController<TrackListHandling> *_current;
}

@property(nonatomic, assign) TrackBrowserDocument   *document;
@property(nonatomic, retain) Selection              *selection;
@property(nonatomic, retain) LeftSplitController    *parentSplitVC;


// Configurable constraints
@property(nonatomic, assign) CGFloat minUpperHeight;   // e.g. 160.0
@property(nonatomic, assign) CGFloat minLowerHeight;   // e.g. 0.0 allows true collapse

@property(nonatomic, assign) IBOutlet NSVisualEffectView    *controlsBar;
@property(nonatomic, assign) IBOutlet NSSegmentedControl    *viewModeControl;   // Outline / Calendar
@property(nonatomic, assign) IBOutlet NSSearchField         *searchField;
@property(nonatomic, assign) IBOutlet NSPopUpButton         *outlineOptionsMenu;
@property(nonatomic, assign) IBOutlet NSButton              *toggleLowerSplitButton;
@property(nonatomic, assign) IBOutlet NSVisualEffectView    *bottomControlsBar;    // the bar that holds buttons + blank space
@property(nonatomic, assign) IBOutlet SplitDragHandleView   *dragHandle;        // the blank area grip

- (IBAction)toggleLowerSplit:(id)sender;

- (IBAction)importTCX:(id)sender;
- (IBAction)importFIT:(id)sender;
- (IBAction)importHRM:(id)sender;
- (IBAction)importGPX:(id)sender;
- (IBAction)exportGPX:(id)sender;
- (IBAction)googleEarthFlyBy:(id)sender;
- (IBAction)exportKML:(id)sender;
- (IBAction)exportTCX:(id)sender;
- (IBAction)exportCSV:(id)sender;
- (IBAction)exportTXT:(id)sender;
- (IBAction)exportSummaryCSV:(id)sender;
- (IBAction)exportSummaryTXT:(id)sender;
- (IBAction)exportLatLonText:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)syncStravaActivities:(id)sender;
- (IBAction)toggleViewMode:(id)sender;
- (IBAction)setBrowserViewMode:(id)sender;
- (IBAction)setSearchOptions:(id)sender;
- (IBAction)setSearchCriteria:(id)sender;
- (IBAction)mailActivity:(id)sender;
- (IBAction)saveSelectedTracks:(id)sender;
- (IBAction)enrichSelectedTracks:(id)sender;
- (IBAction)addActivity:(id)sender;
- (IBAction)splitActivity:(id)sender;
- (IBAction)compareActivities:(id)sender;
- (IBAction)combineActivities:(id)sender;
- (IBAction)showActivityDetail:(id)sender;
- (IBAction)showMapDetail:(id)sender;
- (IBAction)showOutlineSettings:(id)sender;


// Content host below the bar
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

@property(nonatomic, assign) BOOL calendarMode;

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
- (void)injectDependencies;

@end
