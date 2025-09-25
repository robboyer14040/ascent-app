//
//  AnalysisPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;


NS_ASSUME_NONNULL_BEGIN

@interface AnalysisPaneController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

@property(nonatomic, assign) IBOutlet NSSegmentedControl *modeToggle;   // 0=Segments,1=Intervals
@property(nonatomic, assign) IBOutlet NSPopUpButton     *optionsPopup;
@property(nonatomic, assign) IBOutlet NSView            *contentContainer;

@property(nonatomic, retain) NSViewController           *segmentsVC;    // SegmentsController
@property(nonatomic, retain) NSSplitViewController      *intervalsVC;   // IntervalsPaneController

- (IBAction)modeChanged:(id)sender;
- (IBAction)optionChanged:(id)sender;
- (void)showMode:(NSInteger)segmentIndex;
@end

NS_ASSUME_NONNULL_END
