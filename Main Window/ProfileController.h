//
//  ProfileController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentAnimationTargetProtocol.h"
#import "ActivityWindowController.h"

@class TrackBrowserDocument, Selection;
@class MiniProfileView;
@class TransparentMapView;


@interface ProfileController : NSViewController  <AscentAnimationTarget, ActivityWindowControllerDelegate>
@property(nonatomic, assign) TrackBrowserDocument   *document;
@property(nonatomic, retain) Selection              *selection;

@property(nonatomic, assign) IBOutlet MiniProfileView       *profileView;
@property(nonatomic, assign) IBOutlet TransparentMapView    *transparentView;
@property(nonatomic, assign) IBOutlet NSButton              *expandButton;

- (IBAction)expand:(id)sender;


- (void)injectDependencies;
@end
