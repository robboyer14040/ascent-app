//
//  MapController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// MapController.h  (NON-ARC)
#import <Cocoa/Cocoa.h>
#import "DetailedMapWindowController.h"

@class TrackBrowserDocument, Selection;
@class MapPathView;
@class TransparentMapView;

@interface MapController : NSViewController <DetailedMapWindowControllerDelegate>
@property(nonatomic, assign) TrackBrowserDocument   *document; // assign: document owns controllers
@property(nonatomic, retain) Selection              *selection;

@property(nonatomic, assign) IBOutlet MapPathView           *mapPathView;
@property(nonatomic, assign) IBOutlet TransparentMapView    *transparentView;
@property(nonatomic, assign) IBOutlet NSButton              *expandButton;

- (IBAction)expand:(id)sender;

- (void)injectDependencies;
@end
