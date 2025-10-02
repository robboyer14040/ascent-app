//
//  RootSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;
@class LeftSplitController, RightSplitController;

@interface RootSplitController : NSSplitViewController<NSSplitViewDelegate>
{
@private
    TrackBrowserDocument *_document; // assign semantics
    Selection *_selection;           // retained
}

/// Dependencies
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

/// Children
@property(nonatomic, retain) LeftSplitController  *leftSplitController;
@property(nonatomic, retain) RightSplitController *rightSplitController;

/// Push current dependencies into the subtree (idempotent/safe)
- (void)injectDependencies;
- (void)toggleCols;
@end
