//
//  AnalysisPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "AnalysisPaneController.h"
#import "SegmentsController.h"
#import "IntervalsPaneController.h"

@implementation AnalysisPaneController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize controlsBar = _controlsBar;
@synthesize viewModeControl = _viewModeControl;
@synthesize contentContainer = _contentContainer;
@synthesize parentSplitVC = _parentSplitVC;

- (void)awakeFromNib
{
    [super awakeFromNib];

    if (_controlsBar != nil) {
        _controlsBar.material = NSVisualEffectMaterialHeaderView;
        _controlsBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        _controlsBar.state = NSVisualEffectStateFollowsWindowActiveState;
    }

    SegmentsController *segments = [[SegmentsController alloc] initWithNibName:@"SegmentsController" bundle:nil];
    _segmentsVC = segments;

    IntervalsPaneController *intervals =[[IntervalsPaneController alloc] init];
    _intervalsPaneVC = intervals;

    [self injectDependencies];

    // Default until Segments is fully implemented
    [self showIntervals];

    if (_viewModeControl != nil) {
        [_viewModeControl setTarget:self];
        [_viewModeControl setAction:@selector(toggleViewMode:)];
    }
}


- (void)dealloc
{
    if (_selection != nil) {
        [_parentSplitVC release];
        [_selection release];
        [_segmentsVC release];
        [_intervalsPaneVC release];
    }
    [super dealloc];
}


- (IBAction)toggleViewMode:(id)sender
{
    NSInteger seg = 0;
    if ([sender respondsToSelector:@selector(selectedSegment)]) {
        seg = [(NSSegmentedControl *)sender selectedSegment];
    }

    if (seg == 0) {
        [self showSegments];
    } else {
        [self showIntervals];
    }
}

- (void)showSegments
{
    [self swapTo:_segmentsVC];
}

- (void)showIntervals
{
    [self swapTo:_intervalsPaneVC];
}

- (void)swapTo:(NSViewController *)target
{
    if (_current == target) {
        return;
    }

    if (_current != nil) {
        [[_current view] removeFromSuperview];
        [_current removeFromParentViewController];
    }

    _current = target;

    if (_current == nil) {
        return;
    }

    [self addChildViewController:_current];

    NSView *v = _current.view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentContainer addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:_contentContainer.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:_contentContainer.bottomAnchor]
    ]];
}

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    [self injectDependencies];
}

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];
    [self injectDependencies];
}

- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _segmentsVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _intervalsPaneVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
}

@end
