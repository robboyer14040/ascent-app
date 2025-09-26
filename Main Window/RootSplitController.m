//
//  RootSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// RootSplitController.m  (MRC)
#import "RootSplitController.h"
#import "LeftSplitController.h"
#import "RightSplitController.h"
#import "TrackBrowserDocument.h"
#import "Selection.h"

@implementation RootSplitController {
    LeftSplitController  *_leftSplitController;
    RightSplitController *_rightSplitController;
}

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize leftSplitController  = _leftSplitController;
@synthesize rightSplitController = _rightSplitController;

- (void)dealloc {
    [_selection release];
    [_leftSplitController release];
    [_rightSplitController release];
    [super dealloc];
}

#pragma mark - Lifecycle

// ❗️Do NOT override -loadView. Let super create the NSSplitView.
// If you had a -loadView before, delete it entirely.

- (void)viewDidLoad {
    [super viewDidLoad];

    // Configure the split that super created
    NSSplitView *sv = self.splitView;
    sv.vertical     = YES; // left/right
    sv.dividerStyle = NSSplitViewDividerStyleThin;
    sv.autosaveName = @"RootSplitView";

    // Create children (code-only controllers), retain in MRC
    if (!_leftSplitController)  _leftSplitController  = [[LeftSplitController alloc] init];
    if (!_rightSplitController) _rightSplitController = [[RightSplitController alloc] init];

    // TEMP colors to prove visibility (comment out once you see it)
     _leftSplitController.view.wantsLayer = YES;
    _leftSplitController.view.layer.backgroundColor = [NSColor systemYellowColor].CGColor;
    _rightSplitController.view.wantsLayer = YES;
    _rightSplitController.view.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;

    // Add items
    NSSplitViewItem *li = [NSSplitViewItem splitViewItemWithViewController:_leftSplitController];
    li.holdingPriority = 260; li.minimumThickness = 320.0;

    NSSplitViewItem *ri = [NSSplitViewItem splitViewItemWithViewController:_rightSplitController];
    ri.holdingPriority = 250; ri.minimumThickness = 480.0;

    [self addSplitViewItem:li];
    [self addSplitViewItem:ri];

    // Push deps now that children exist
    [self injectDependencies];

    // Debug: confirm arranged subviews exist and have frames
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"RootSplit items=%lu arrangedSubviews=%lu",
              (unsigned long)self.splitViewItems.count,
              (unsigned long)sv.arrangedSubviews.count);
        for (NSView *sub in sv.arrangedSubviews) {
            NSLog(@"  sub=%@ frame=%@", sub, NSStringFromRect(sub.frame));
        }
    });
}

#pragma mark - Dependency injection

- (void)setDocument:(TrackBrowserDocument *)doc {
    _document = doc; // assign on purpose
    if (self.isViewLoaded) [self injectDependencies];
}

- (void)setSelection:(Selection *)sel {
    if (_selection == sel) return;
    [_selection release];
    _selection = [sel retain];
    if (self.isViewLoaded) [self injectDependencies];
}

- (void)injectDependencies {
    if (_leftSplitController) {
        @try { [_leftSplitController setValue:_document  forKey:@"document"]; } @catch(__unused NSException *_) {}
        @try { [_leftSplitController setValue:_selection forKey:@"selection"]; } @catch(__unused NSException *_) {}
        if ([_leftSplitController respondsToSelector:@selector(injectDependencies)]) {
            [_leftSplitController performSelector:@selector(injectDependencies)];
        }
    }
    if (_rightSplitController) {
        @try { [_rightSplitController setValue:_document  forKey:@"document"]; } @catch(__unused NSException *_) {}
        @try { [_rightSplitController setValue:_selection forKey:@"selection"]; } @catch(__unused NSException *_) {}
        if ([_rightSplitController respondsToSelector:@selector(injectDependencies)]) {
            [_rightSplitController performSelector:@selector(injectDependencies)];
        }
    }
}

@end
