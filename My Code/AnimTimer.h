//
//  AnimTimer.h
//  Ascent
//
//  Created by Rob Boyer on 11/23/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class TransportPanelController;

@protocol AnimationTarget

-(Track*) animationTrack;
-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim;
-(void) beginAnimation;
-(void) endAnimation;
@end


@interface AnimTimer : NSObject 
{
   NSTimer*                   rideTimer;
   NSMutableArray*            updateList;
   TransportPanelController*  transportPanelController;
   BOOL                       playingInReverse;
   BOOL                       animating;
   float                      speedFactor;
   NSTimeInterval             animTime;
   NSTimeInterval             endingTime;
}

+ (AnimTimer*) defaultInstance;

- (void) registerForTimerUpdates:(id)obj;
- (void) unregisterForTimerUpdates:(id)obj;
- (void) stop:(id)sender;
- (void) play:(id)sender reverse:(BOOL)inReverse;
- (void) fastForward;
- (void) rewind;
- (void) setSpeedFactor:(float)sf;
- (float) speedFactor;
- (void) setAnimTime:(NSTimeInterval)at;
- (NSTimeInterval) animTime;
- (NSTimeInterval) endingTime;
- (void) setTransportPanelController:(TransportPanelController*)tpc;
- (void) updateTimerDuration;
- (void) locateToPercentage:(float)percent;
- (void) applyLocateDelta:(float)delta;
- (BOOL) animating;
- (BOOL) playingInReverse;
- (void)togglePlay:(NSNotification *)notification;
-(void)forceUpdate;

@end
