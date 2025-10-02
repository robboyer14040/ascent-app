//
//  LeftSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
//
#import <Cocoa/Cocoa.h>
#import "SplitDragHandleView.h"

@class TrackBrowserDocument, Selection;
@class TrackPaneController, AnalysisPaneController;


@interface LeftSplitController : NSSplitViewController<SplitDragHandleViewDelegate>
{
@private
    TrackBrowserDocument *_document;          // assign
    Selection *_selection;                    // retained
    TrackPaneController *_trackPaneController;
    AnalysisPaneController *_analysisPaneController;
}

@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

@property(nonatomic, retain) TrackPaneController     *trackPaneController;      // top
@property(nonatomic, retain) AnalysisPaneController  *analysisPaneController;   // bottom


- (void)injectDependencies;
- (void)toggleLowerSplit;

@end
