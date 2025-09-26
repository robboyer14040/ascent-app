//
//  TrackPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;

@interface TrackPaneController : NSViewController
{
@private
    TrackBrowserDocument *_document; // assign
    Selection *_selection;           // retained
    BOOL _calendarMode;
    NSViewController *_outlineVC;
    NSViewController *_calendarVC;
    NSViewController *_current;
}

@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

// Top bar (NSVisualEffectView) with controls
@property(nonatomic, assign) IBOutlet NSVisualEffectView *controlsBar;
@property(nonatomic, assign) IBOutlet NSSegmentedControl *viewModeControl;   // Outline / Calendar
@property(nonatomic, assign) IBOutlet NSSearchField *searchField;
@property(nonatomic, assign) IBOutlet NSPopUpButton *outlineOptionsMenu;

// Content host below the bar
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

@property(nonatomic, assign) BOOL calendarMode;

- (IBAction)toggleViewMode:(id)sender;

- (void)injectDependencies;

@end
