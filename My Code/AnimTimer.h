//
//  AnimTimer.h
//  Ascent
//
//  Created by Rob Boyer on 11/23/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface AnimTimer : NSObject

+ (AnimTimer*) defaultInstance;

- (void) registerForTimerUpdates:(id)obj;
- (void) unregisterForTimerUpdates:(id)obj;
- (void) requestTransportStateChange:(int)requestedState;
- (void) setSpeedFactor:(float)sf;
- (float) speedFactor;
- (void) setAnimTime:(NSTimeInterval)at;
- (NSTimeInterval) animTime;
- (NSTimeInterval) endingTime;
- (void) updateTimerDuration;
- (void) locateToPercentage:(float)percent;
- (void) applyLocateDelta:(float)delta;
- (BOOL) animating;
- (BOOL) playingInReverse;
- (void) forceUpdate;
- (void) togglePlay;

@end
