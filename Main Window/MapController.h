//
//  MapController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// MapController.h  (NON-ARC)
#import <Cocoa/Cocoa.h>
@class TrackBrowserDocument, Selection;

@interface MapController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document; // assign: document owns controllers
@property(nonatomic, retain) Selection *selection;

- (void)injectDependencies;
@end
