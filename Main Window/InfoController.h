//
//  InfoController.h
//  Ascent
//
//  Created by Rob Boyer on 9/30/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Selection, TrackBrowserDocument;

NS_ASSUME_NONNULL_BEGIN

@interface InfoController : NSViewController<NSGestureRecognizerDelegate> 
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

@property(nonatomic, assign) IBOutlet NSView                *infoContainer;
@property(nonatomic, assign) IBOutlet NSTextView            *notes;
@property(nonatomic, assign) IBOutlet NSImageView           *picture;
@property(nonatomic, assign) IBOutlet NSTextView            *weather;
@property(nonatomic, assign) IBOutlet NSTextView            *location;

@end

NS_ASSUME_NONNULL_END
