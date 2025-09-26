//
//  MainWindowController.h
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//
//
//  MainWindowController.h
//  Ascent  (NON-ARC)
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection, RootSplitController;

@interface MainWindowController : NSWindowController
{
@private
    Selection *_selection;     // yours
    RootSplitController *_root;
}


// Refine type only; keep attributes compatible with NSWindowController
@property(assign) TrackBrowserDocument *document;

@property(nonatomic, retain) Selection *selection;

// IB outlets
@property(nonatomic, assign) IBOutlet NSVisualEffectView *reservedTopArea;
@property(nonatomic, assign) IBOutlet NSView *contentContainer;

// Access to embedded root split
@property(nonatomic, retain) RootSplitController *rootSplitController;

@end
