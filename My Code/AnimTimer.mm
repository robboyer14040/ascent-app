//
//  AnimTimer.mm
//  Ascent
//
//  Created by Rob Boyer on 11/23/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "Defs.h"
#import "AnimTimer.h"
#import "Track.h"
#import "TransportPanelController.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "AscentAnimationTargetProtocol.h"


#define ANIM_UPDATE_TIME      (0.05)
#define DATE_METHOD           activeTimeDelta
#define DURATION_METHOD       movingDuration

NSString* RCBDefaultAnimSpeedFactor = @"AnimSpeedFactor";

@interface AnimTimer ()
{
   NSTimer*                   rideTimer;
   NSMutableArray*            updateList;
   BOOL                       playingInReverse;
   BOOL                       animating;
   float                      speedFactor;
   NSTimeInterval             animTime;
   NSTimeInterval             endingTime;
}
- (void)updateListeners:(BOOL)resetFrame updateTime:(BOOL)ut;
@end


@implementation AnimTimer

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        updateList = [[NSMutableArray alloc] init];
        rideTimer = nil;
        playingInReverse = NO;
        speedFactor = [Utils floatFromDefaults:RCBDefaultAnimSpeedFactor];
        if (speedFactor <= 0.0) speedFactor = 10.0;
        animTime = 0.0;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(locate:)
                                                     name:@"Locate"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(transportStateChange:)
                                                     name:TransportStateChanged
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (rideTimer != nil) {
        [rideTimer invalidate];
        [rideTimer release];
        rideTimer = nil;
    }

    [updateList release];

    [super dealloc];
}


+ (AnimTimer*)defaultInstance
{
    static id sdi = nil;
    if (sdi == nil)
    {
        sdi = [[AnimTimer alloc] init];
    }
    return sdi;
}


- (void)registerForTimerUpdates:(id)obj
{
    if ([updateList indexOfObjectIdenticalTo:obj] == NSNotFound)
    {
        [updateList addObject:obj];
        [self updateTimerDuration];
    }
}


- (void)unregisterForTimerUpdates:(id)obj
{
    if ([updateList indexOfObjectIdenticalTo:obj] != NSNotFound)
    {
        [updateList removeObject:obj];
        [self updateTimerDuration];
        if ([updateList count] == 0)
        {
            [self stop:self];
        }
    }
}


- (void)updateAnimState:(BOOL)start
{
    animating = start;
    NSUInteger num = [updateList count];
    for (NSUInteger i = 0; i < num; i++)
    {
        id <AscentAnimationTarget> target = [updateList objectAtIndex:i];
        if (start)
        {
            [target beginAnimation];
        }
        else
        {
            [target endAnimation];
        }
    }
}


- (void)stopAnimation
{
    [self updateAnimState:NO];
    if (rideTimer != nil)
    {
        [rideTimer invalidate];
        [rideTimer release];
        rideTimer = nil;
    }
    [self postStateChangeNotification:kStop
                               sender:self];
}


- (void)updateTrackAnimData:(Track*)track time:(NSTimeInterval)trackTime
{
    NSInteger trackPos;
    if (trackTime == 0.0)
        trackPos = 0;
    else
        trackPos = [track animIndex];

    NSMutableArray *pts = [track goodPoints];
    NSUInteger numPos = [pts count];

    NSTimeInterval trackOffset = [track animTimeBegin];

    TrackPoint *pt = nil;
    TrackPoint *prevPt;

    if (IS_BETWEEN(0, trackPos, ((NSInteger)numPos - 1)))
    {
        pt = [pts objectAtIndex:(NSUInteger)trackPos];
    }

    NSTimeInterval ti;
    if (pt && ((NSUInteger)trackPos < numPos))
    {
        ti = [pt DATE_METHOD] - trackOffset;
        if (ti > trackTime)
        {
            while (trackPos > 0)
            {
                NSInteger pos = trackPos - 1;
                pt = [pts objectAtIndex:(NSUInteger)pos];
                ti = [pt DATE_METHOD] - trackOffset;
                if (ti >= trackTime) trackPos = pos;
                else break;
            }
        }
        else if (ti < trackTime)
        {
            while ((NSUInteger)trackPos < (numPos - 1))
            {
                NSInteger pos = trackPos + 1;
                pt = [pts objectAtIndex:(NSUInteger)pos];
                ti = [pt DATE_METHOD] - trackOffset;
                if (ti > trackTime) break;
                else
                {
                    trackPos = pos;
                    if (ti == trackTime) break;
                }
                prevPt = pt;
                (void)prevPt; // silence unused if not used elsewhere
            }
        }
    }
    [track setAnimTime:trackTime];
    [track setAnimIndex:(int)trackPos];
}


- (void)forceUpdate
{
    [self updateListeners:NO updateTime:NO];
}


- (void)updateListeners:(BOOL)resetFrame updateTime:(BOOL)ut
{
    if (resetFrame)
    {
        animTime = 0.0;
    }
    else if (ut)
    {
        if (playingInReverse)
        {
            animTime -= (ANIM_UPDATE_TIME * speedFactor);
            if (animTime < 0.0)
            {
                animTime = 0.0;
                [self stop:self];
            }
        }
        else
        {
            animTime += (ANIM_UPDATE_TIME * speedFactor);
            if (animTime >= endingTime)
            {
                animTime = endingTime;
                [self stop:self];
            }
        }
    }

    NSUInteger num = [updateList count];
    for (NSUInteger i = 0; i < num; i++)
    {
        id <AscentAnimationTarget> target = [updateList objectAtIndex:i];
        Track *t = (Track *)[target animationTrack];
        NSTimeInterval trackTime = animTime;
        if (t != nil)
        {
            [self updateTrackAnimData:t time:trackTime];
        }
        [target updatePosition:trackTime
                       reverse:playingInReverse
                     animating:animating];
    }
}


- (void)updateTimerDuration
{
    endingTime = 0.0;

    NSUInteger num = [updateList count];
    for (NSUInteger i = 0; i < num; i++)
    {
        id <AscentAnimationTarget> target = [updateList objectAtIndex:i];
        Track *track = (Track *)[target animationTrack];
        if (track != nil)
        {
            float trackDuration = track.animTimeEnd - track.animTimeBegin;
            if (trackDuration > endingTime)
                endingTime = trackDuration;
        }
    }
    if (animTime > endingTime)
        animTime = endingTime;
}


- (void)timerUpdate:(NSTimer*)timer
{
    [self updateListeners:NO updateTime:YES];
}


- (void)startAnimation
{
    if (rideTimer == nil)
    {
        rideTimer = [[NSTimer scheduledTimerWithTimeInterval:ANIM_UPDATE_TIME
                                                      target:self
                                                    selector:@selector(timerUpdate:)
                                                    userInfo:nil
                                                     repeats:YES] retain];

        // Keep updating while user drags the slider
        [[NSRunLoop currentRunLoop] addTimer:rideTimer
                                     forMode:NSEventTrackingRunLoopMode];
    }
    [self updateAnimState:YES];
}


- (void)postStateChangeNotification:(int)st sender:(id)sndr
{
    [[NSNotificationCenter defaultCenter] postNotificationName:TransportStateChanged
                                                        object:sndr
                                                      userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:st]
                                                                                           forKey:TransportStateChangedInfoKey]];
}


- (void)stop:(id)sender
{
    [self stopAnimation];
    playingInReverse = NO;
    [self postStateChangeNotification:kStop
                               sender:self];
}


- (void)play:(id)sender reverse:(BOOL)inReverse
{
    [self stopAnimation];
    playingInReverse = inReverse;
    [self postStateChangeNotification:(inReverse ? kReverse : kPlay)
                               sender:self];
    [self startAnimation];
}


- (void)fastForward
{
    animTime = endingTime;
    [self updateListeners:NO updateTime:NO];
    [self postStateChangeNotification:kFastForward
                               sender:self];
    [self stopAnimation];
}


- (void)rewind
{
    [self updateListeners:YES updateTime:NO];
    [self postStateChangeNotification:kGoToBeginning
                               sender:self];
    [self stopAnimation];
}


- (void)setSpeedFactor:(float)sf
{
    speedFactor = sf;
    [Utils setFloatDefault:sf forKey:RCBDefaultAnimSpeedFactor];
}


- (float)speedFactor
{
    return speedFactor;
}


- (void)setAnimTime:(NSTimeInterval)at
{
    playingInReverse = (at < animTime);
    animTime = at;
    [self updateListeners:NO updateTime:NO];
}


- (NSTimeInterval)animTime
{
    return animTime;
}


- (NSTimeInterval)endingTime
{
    return endingTime;
}


- (void)locateToPercentage:(float)percent
{
    percent = CLIP(0.0, percent, 100.0);
    NSTimeInterval newAnimTime = percent * endingTime / 100.0;
    playingInReverse = (newAnimTime < animTime);
    animTime = newAnimTime;
    [self updateListeners:NO updateTime:NO];
}


- (void)applyLocateDelta:(float)delta
{
    if (endingTime > 0.0)
    {
        NSTimeInterval percent = animTime * 100.0 / endingTime;
        percent += 1.0 * delta;
        [self locateToPercentage:percent];
    }
}


- (void)locate:(NSNotification *)notification
{
}


- (BOOL)playingInReverse
{
    return playingInReverse;
}


- (BOOL)animating
{
    return animating;
}

- (void)requestTransportStateChange:(int)requestedState;
{
    switch (requestedState)
    {
        default:
        case kStop:
            [self stop:self];
            break;
        case kPlay:
            playingInReverse = NO;
            [self play:self reverse:NO];
            break;
        case kReverse:
            playingInReverse = YES;
            [self play:self reverse:YES];
            break;
        case kGoToBeginning:
            [self rewind];
            break;
        case kGoToEnd:
            [self fastForward];
            break;
        case kFastForward:
            [self fastForward];
            break;
    }
}


- (void)transportStateChange:(NSNotification *)notification
{
    // state changes we've sent
    if (notification.object == self)
        return;
    
}


- (void) togglePlay
{
    int which = kStop;
    if (animating) {
        [self stop:self];
    } else {
        which = kPlay;
        [self play:self reverse:NO];
    }
    NSNumber *num = [NSNumber numberWithInt: (int)which];
    NSDictionary *info = [NSDictionary dictionaryWithObject:num
                                                     forKey:TransportStateChangedInfoKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:TransportStateChanged
                                                        object:self
                                                      userInfo:info];
}


@end

