//
//  LeftSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
//  LeftSplitController.m
//  Ascent  (NON-ARC / MRC)
//

#import "LeftSplitController.h"
#import "TrackPaneController.h"
#import "AnalysisPaneController.h"

@implementation LeftSplitController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize trackPaneController = _trackPaneController;
@synthesize analysisPaneController = _analysisPaneController;

- (void)dealloc
{
    if (_selection != nil) {
        [_selection release];
    }
    if (_trackPaneController != nil) {
        [_trackPaneController release];
    }
    if (_analysisPaneController != nil) {
        [_analysisPaneController release];
    }
    [super dealloc];
}

- (void)loadView
{
    NSSplitView *sv = [[[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 600, 800)] autorelease];
    sv.vertical = NO;
    sv.dividerStyle = NSSplitViewDividerStyleThin;
    sv.autosaveName = @"LeftSplitView";
    self.view = sv;

    TrackPaneController *topVC = [[[TrackPaneController alloc] initWithNibName:@"TrackPaneController" bundle:nil] autorelease];
    AnalysisPaneController *botVC = [[[AnalysisPaneController alloc] initWithNibName:@"AnalysisPaneController" bundle:nil] autorelease];

    self.trackPaneController = topVC;
    self.analysisPaneController = botVC;

    [self injectDependencies];

    NSSplitViewItem *top = [NSSplitViewItem splitViewItemWithViewController:topVC];
    NSSplitViewItem *bot = [NSSplitViewItem splitViewItemWithViewController:botVC];

    top.holdingPriority = 260;
    bot.holdingPriority = 250;
    top.minimumThickness = 220.0;
    bot.minimumThickness = 220.0;

    [self addSplitViewItem:top];
    [self addSplitViewItem:bot];
}

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    if (self.isViewLoaded) {
        [self injectDependencies];
    }
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
    if (self.isViewLoaded) {
        [self injectDependencies];
    }
}

- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _trackPaneController;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _analysisPaneController;
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
