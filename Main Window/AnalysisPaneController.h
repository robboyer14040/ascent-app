//
//  AnalysisPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;

@interface AnalysisPaneController : NSViewController<NSPopoverDelegate>
{
@private
    TrackBrowserDocument    *_document;     // assign
    Selection               *_selection;    // retained
    NSViewController        *_segmentsVC;
    NSViewController        *_intervalsPaneVC;
    NSViewController        *_current;
}

@property(nonatomic, assign) TrackBrowserDocument   *document;
@property(nonatomic, retain) Selection              *selection;
@property(nonatomic, retain) NSSplitViewController  *parentSplitVC;

@property(nonatomic, assign) IBOutlet NSVisualEffectView    *controlsBar;
@property(nonatomic, assign) IBOutlet NSSegmentedControl    *viewModeControl;       // 0 = Segments, 1 = Intervals
@property(nonatomic, assign) IBOutlet NSSegmentedControl    *graphOrTextControl;    // splits: graphical or textual
@property(nonatomic, assign) IBOutlet NSSearchField         *searchField;           // only for segments
@property(nonatomic, assign) IBOutlet NSView                *contentContainer;

@property(nonatomic, assign) NSButton   *avgVariantButton;
@property(nonatomic, assign) NSButton   *minVariantButton;
@property(nonatomic, assign) NSButton   *maxVariantButton;
@property(nonatomic, assign) NSButton   *deltaFromAvgVariantButton;


- (IBAction)showIntervalSettings:(id)sender;
- (IBAction)toggleViewMode:(id)sender;
- (IBAction)toggleSplitMode:(id)sender;
- (IBAction)setSearchOptions:(id)sender;
- (IBAction)setSearchCriteria:(id)sender;

- (void)injectDependencies;
- (void)setSplitItem:(id)sender;
- (void)setSplitVariant:(id)sender;
- (void)setSplitLength:(id)sender;
- (void)setSplitCustomLength:(id)sender;

@end
