//
//  LeftSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
// LeftSplitController.m  (MRC)
#import "LeftSplitController.h"
#import "TrackPaneController.h"     // top (outline/calendar)
#import "AnalysisPaneController.h"      // bottom (segments/intervals)

@implementation LeftSplitController
{
}
@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_selection release];
    [_trackPaneController release];
    [_analysisPaneController release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSSplitView *sv = self.splitView;      // created by super
    sv.vertical     = NO;                  // top/bottom
    sv.dividerStyle = NSSplitViewDividerStyleThin;
 
    // Create children (XIB-backed)
    if (!_trackPaneController)
        _trackPaneController = [[TrackPaneController alloc] initWithNibName:@"TrackPaneController" bundle:nil];
    if (!_analysisPaneController)
        _analysisPaneController  = [[AnalysisPaneController  alloc] initWithNibName:@"AnalysisPaneController"  bundle:nil];

    // TEMP: if you still want color proof, uncomment:
    _trackPaneController.view.wantsLayer = YES; _trackPaneController.view.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
    _analysisPaneController.view.wantsLayer  = YES; _analysisPaneController.view.layer.backgroundColor  = [NSColor systemBlueColor].CGColor;

    NSSplitViewItem *top = [NSSplitViewItem splitViewItemWithViewController:_trackPaneController];
    top.minimumThickness = 220.0; top.holdingPriority = 260;

    NSSplitViewItem *bot = [NSSplitViewItem splitViewItemWithViewController:_analysisPaneController];
    bot.minimumThickness = 220.0; bot.holdingPriority = 250;

    [self addSplitViewItem:top];
    [self addSplitViewItem:bot];

    sv.autosaveName = @"LeftSplitView";

    [self injectDependencies];
}

- (void)setDocument:(TrackBrowserDocument *)doc { _document = doc; if (self.isViewLoaded) [self injectDependencies]; }
- (void)setSelection:(Selection *)sel { if (sel==_selection) return; [_selection release]; _selection=[sel retain]; if (self.isViewLoaded) [self injectDependencies]; }

- (void)injectDependencies {
    for (NSViewController *vc in @[(id)_trackPaneController ?: (id)NSNull.null, (id)_analysisPaneController ?: (id)NSNull.null]) {
        if ((id)vc == (id)NSNull.null) continue;
        @try { [vc setValue:_document  forKey:@"document"]; } @catch(...) {}
        @try { [vc setValue:_selection forKey:@"selection"]; } @catch(...) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) [vc performSelector:@selector(injectDependencies)];
    }
}
@end
