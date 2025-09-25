//
//  RootSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;
@class LeftSplitController;
@class RightSplitController;

@interface RootSplitController : NSSplitViewController
{
@private
    Selection *_selection;
}

// Dependencies
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

// IB wiring
@property(nonatomic, assign) IBOutlet LeftSplitController *leftSplitController;
@property(nonatomic, assign) IBOutlet RightSplitController *rightSplitController;

// Helper to push deps into children
- (void)injectDependencies;

@end
