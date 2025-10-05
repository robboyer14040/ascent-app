//
//  MainWindowController.h
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//
//
//

#import <Cocoa/Cocoa.h>
#import "AscentAnimationTargetProtocol.h"

@class TrackBrowserDocument, Selection, RootSplitController;

@interface MainWindowController : NSWindowController<NSUserInterfaceValidations, AscentAnimationTarget>
{
@private
    Selection *_selection;
    RootSplitController *_root;
}


// Refine type only; keep attributes compatible with NSWindowController
@property(assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

@property(nonatomic, assign) IBOutlet NSButton *rightColsButton;

-(IBAction)showMapDetail:(id)sender;
-(IBAction)showActivityDetail:(id)sender;
-(IBAction)toggleRightColumns:(id)sender;
-(IBAction)syncActivities:(id)sender;
-(IBAction)transportButtonPushed:(id)sender;

// IB outlets
@property(nonatomic, assign) IBOutlet NSVisualEffectView    *reservedTopArea;
@property(nonatomic, assign) IBOutlet NSView                *contentContainer;
@property(nonatomic, assign) IBOutlet NSButton              *syncButton;
@property(nonatomic, assign) IBOutlet NSSegmentedControl    *transportControl;
@property(nonatomic, assign) IBOutlet NSTextField           *timecodeText;

// Access to embedded root split
@property(nonatomic, retain) RootSplitController *rootSplitController;

@end
