//
//  AnalysisPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;

@interface AnalysisPaneController : NSViewController
{
@private
    TrackBrowserDocument *_document; // assign
    Selection *_selection;           // retained
    NSViewController *_segmentsVC;
    NSViewController *_intervalsPaneVC;
    NSViewController *_current;
}

@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

// Top bar (NSVisualEffectView) and control
@property(nonatomic, assign) IBOutlet NSVisualEffectView *controlsBar;
@property(nonatomic, assign) IBOutlet NSSegmentedControl *viewModeControl; // 0 = Segments, 1 = Intervals

// Content host below the bar
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

- (IBAction)toggleViewMode:(id)sender;

- (void)injectDependencies;

@end
