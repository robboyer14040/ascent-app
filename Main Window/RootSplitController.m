//
//  RootSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// RootSplitController.m (NON-ARC / MRC)
#import "RootSplitController.h"
#import "LeftSplitController.h"
#import "RightSplitController.h"
#import "TrackBrowserDocument.h"
#import "Selection.h"

@implementation RootSplitController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize leftSplitController = _leftSplitController;
@synthesize rightSplitController = _rightSplitController;

- (void)dealloc
{
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    // Make divider remember positions automatically
    // (Set this even if you don’t expose splitView as an outlet; you can also do
    //  self.splitView.autosaveName in 10.13+.)
    if (self.splitView != nil) {
        [self.splitView setAutosaveName:@"RootSplit"];
        [self.splitView setDividerStyle:NSSplitViewDividerStyleThin];
    }

    // If injectDependencies was called before nib finished, push now
    [self injectDependencies];
}

#pragma mark - Dependency injection

- (void)setSelection:(Selection *)sel
{
    if (_selection == sel) {
        return;
    }
    [_selection release];
    _selection = [sel retain];
    // If nib is loaded, cascade now
    if ([self isViewLoaded]) {
        [self injectDependencies];
    }
}

- (void)injectDependencies
{
    if (![self isViewLoaded]) {
        return;
    }
    // Left branch
    if ([self.leftSplitController respondsToSelector:@selector(setDocument:)]) {
        [(id)self.leftSplitController setDocument:self.document];
    }
    if ([self.leftSplitController respondsToSelector:@selector(setSelection:)]) {
        [(id)self.leftSplitController setSelection:self.selection];
    }

    // Right branch
    if ([self.rightSplitController respondsToSelector:@selector(setDocument:)]) {
        [(id)self.rightSplitController setDocument:self.document];
    }
    if ([self.rightSplitController respondsToSelector:@selector(setSelection:)]) {
        [(id)self.rightSplitController setSelection:self.selection];
    }
}


- (void)loadView
{
    // Build the Split View for this controller
    NSSplitView *sv = [[[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 900, 600)] autorelease];
    sv.vertical = YES; // left/right
    sv.dividerStyle = NSSplitViewDividerStyleThin;
    sv.autosaveName = @"RootSplitView";
    self.view = sv;

    // Ensure child controllers exist
    LeftSplitController *left  = self.leftSplitController ?: [[[LeftSplitController alloc] initWithNibName:@"LeftSplitController" bundle:nil] autorelease];
    RightSplitController *right = self.rightSplitController ?: [[[RightSplitController alloc] initWithNibName:@"RightSplitController"  bundle:nil] autorelease];

    // If we created fallbacks, assign them so injectDependencies can see them
    if (!self.leftSplitController)  self.leftSplitController  = left;
    if (!self.rightSplitController) self.rightSplitController = right;

    // Create split items and add
    NSSplitViewItem *leftItem  = [NSSplitViewItem splitViewItemWithViewController:left];
    NSSplitViewItem *rightItem = [NSSplitViewItem splitViewItemWithViewController:right];

    // Slight bias so left can be narrower
    leftItem.holdingPriority  = 260;
    rightItem.holdingPriority = 250;

    [self addSplitViewItem:leftItem];
    [self addSplitViewItem:rightItem];
}


#pragma mark - Actions


@end
