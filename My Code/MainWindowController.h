//
//  MainWindowController.h
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;

@class NSSplitViewController;
@class LeftSplitController;
@class RightSplitController;
@class TrackPaneController;
@class AnalysisPaneController;
@class InfoPaneController;

@interface MainWindowController : NSWindowController
{
@private
    Selection *_selection; // shared per document
}

// Split controllers
@property(nonatomic, assign) IBOutlet NSSplitViewController *rootSplitController;

// Shared selection (retained here, injected into children)
@property(nonatomic, retain) Selection *selection;

@end

