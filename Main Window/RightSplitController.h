//
//  RightSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class TrackBrowserDocument;
@class Selection;


@interface RightSplitController : NSSplitViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;
@property(nonatomic, retain) NSViewController *mapController;
@property(nonatomic, retain) NSViewController *profileController;
@property(nonatomic, retain) NSViewController *infoPaneController;
@end

NS_ASSUME_NONNULL_END
