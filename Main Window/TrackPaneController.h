//
//  TrackPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;

NS_ASSUME_NONNULL_BEGIN

@interface TrackPaneController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

// Header UI
@property(nonatomic, assign) IBOutlet NSSegmentedControl *modeToggle;   // 0=Outline,1=Calendar
@property(nonatomic, assign) IBOutlet NSSearchField     *searchField;
@property(nonatomic, assign) IBOutlet NSPopUpButton     *optionsPopup;

// Content host
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

// Children
@property(nonatomic, retain) NSViewController *listVC;     // TrackListController
@property(nonatomic, retain) NSViewController *calendarVC; // TrackCalendarController

- (IBAction)modeChanged:(id)sender;
- (IBAction)searchChanged:(id)sender;
- (IBAction)optionChanged:(id)sender;

- (void)showMode:(NSInteger)segmentIndex; // helper
@end

NS_ASSUME_NONNULL_END
