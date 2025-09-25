//
//  SegmentsController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;

NS_ASSUME_NONNULL_BEGIN

@interface SegmentsController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;
@end

NS_ASSUME_NONNULL_END
