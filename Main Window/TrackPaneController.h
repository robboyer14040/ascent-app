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

@interface TrackPaneController : NSViewController <NSUserInterfaceValidations>
{
@private
    TrackBrowserDocument *_document; // assign
    Selection *_selection;           // retained
    BOOL _calendarMode;
    TrackListController *_outlineVC;
    TrackCalendarController *_calendarVC;
    NSViewController<TrackListHandling> *_current;
}

@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

// Top bar (NSVisualEffectView) with controls
@property(nonatomic, assign) IBOutlet NSVisualEffectView *controlsBar;
@property(nonatomic, assign) IBOutlet NSSegmentedControl *viewModeControl;   // Outline / Calendar
@property(nonatomic, assign) IBOutlet NSSearchField *searchField;
@property(nonatomic, assign) IBOutlet NSPopUpButton *outlineOptionsMenu;


- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)syncStravaActivities:(id)sender;
- (IBAction)toggleViewMode:(id)sender;
- (IBAction)setSearchOptions:(id)sender;
- (IBAction)setSearchCriteria:(id)sender;



// Content host below the bar
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

@property(nonatomic, assign) BOOL calendarMode;

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
- (void)injectDependencies;

@end
