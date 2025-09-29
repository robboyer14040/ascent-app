//
//  RightSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
//  RightSplitController.m
//  Ascent
//
//  NON-ARC (MRC)
//

#import "RightSplitController.h"
#import "MapController.h"
#import "ProfileController.h"
#import "InfoPaneController.h"

@implementation RightSplitController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize mapController = _mapController;
@synthesize profileController = _profileController;
@synthesize infoPaneController = _infoPaneController;

- (void)dealloc
{
    [_selection release];
    [_mapController release];
    [_profileController release];
    [_infoPaneController release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Horizontal split with THREE stacked sections: top (Map), middle (Profile), bottom (InfoPane)
    NSSplitView *sv = self.splitView;      // created by super
    sv.vertical = NO; // top/bottom stack
    sv.dividerStyle = NSSplitViewDividerStyleThin;
    self.view = sv;
    
    // Child controllers are XIB-backed
    MapController      *map   = [[[MapController      alloc] initWithNibName:@"MapController"      bundle:nil] autorelease];
    ProfileController  *prof  = [[[ProfileController  alloc] initWithNibName:@"ProfileController"  bundle:nil] autorelease];
    InfoPaneController *info  = [[[InfoPaneController alloc] initWithNibName:@"InfoPaneController" bundle:nil] autorelease];
    // TEMP: if you still want color proof, uncomment:
   /// map.view.wantsLayer = YES; map.view.layer.backgroundColor = [NSColor systemRedColor].CGColor;
//    prof.view.wantsLayer  = YES; prof.view.layer.backgroundColor  = [NSColor systemBrownColor].CGColor;
//    info.view.wantsLayer  = YES; info.view.layer.backgroundColor  = [NSColor systemPinkColor].CGColor;

    self.mapController      = map;
    self.profileController  = prof;
    self.infoPaneController = info;
    
    // Push deps before attaching items
    [self injectDependencies];
    
    // Assemble three split items with priorities/thickness tuned for your layout
    NSSplitViewItem *i1 = [NSSplitViewItem splitViewItemWithViewController:map];   // Map (top)
    NSSplitViewItem *i2 = [NSSplitViewItem splitViewItemWithViewController:prof];  // Profile (middle)
    NSSplitViewItem *i3 = [NSSplitViewItem splitViewItemWithViewController:info];  // Info (bottom)
    
    i1.holdingPriority  = 260;  i1.minimumThickness = 180.0;
    i2.holdingPriority  = 255;  i2.minimumThickness = 160.0;
    i3.holdingPriority  = 250;  i3.minimumThickness = 180.0;
    
    [self addSplitViewItem:i1];
    [self addSplitViewItem:i2];
    [self addSplitViewItem:i3];
    
    sv.autosaveName = @"RightSplitView";
}

#pragma mark - Dependency propagation

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document; // assign
    if (self.isViewLoaded) {
        [self injectDependencies];
    }
}

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) return;
    [_selection release];
    _selection = [selection retain];
    if (self.isViewLoaded) {
        [self injectDependencies];
    }
}

- (void)injectDependencies
{
    for (NSViewController *vc in @[(id)_mapController      ?: (id)NSNull.null,
                                   (id)_profileController  ?: (id)NSNull.null,
                                   (id)_infoPaneController ?: (id)NSNull.null]) {
        if ((id)vc == (id)NSNull.null) continue;

        @try { [vc setValue:_document  forKey:@"document"]; } @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; } @catch (__unused NSException *ex) {}

        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
}



@end
