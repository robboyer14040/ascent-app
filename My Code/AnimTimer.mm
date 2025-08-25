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

#define ANIM_UPDATE_TIME      (0.05)
#define DATE_METHOD           activeTimeDelta
#define DURATION_METHOD       movingDuration

NSString* RCBDefaultAnimSpeedFactor	=	@"AnimSpeedFactor";

@interface AnimTimer ()
- (void) updateListeners:(BOOL)resetFrame updateTime:(BOOL)ut;
@end


@implementation AnimTimer

- (id) init 
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
		transportPanelController = nil;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(locate:)
													 name:@"Locate"
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(togglePlay:)
													 name:@"TogglePlay"
												   object:nil];
	}
	return self;
}


- (void) dealloc 
{
   [[NSNotificationCenter defaultCenter] removeObserver:self];
}


+ (AnimTimer*) defaultInstance
{
   static id sdi = nil;
   if (sdi == nil)
   {
      sdi = [[AnimTimer alloc] init];
   }
   return sdi;
}



- (void) registerForTimerUpdates:(id)obj
{
   if ([updateList indexOfObjectIdenticalTo:obj] == NSNotFound)
   {
      [updateList addObject:obj];
      [self updateTimerDuration];
   }
}


- (void) unregisterForTimerUpdates:(id)obj
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


- (void) updateAnimState:(BOOL)start
{
   animating = start;
   int num = [updateList count];
   for (int i=0; i<num; i++)
   {
      id <AnimationTarget> target = [updateList objectAtIndex:i];
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
      rideTimer = nil;
   }
}

- (void) updateTrackAnimData:(Track*)track time:(NSTimeInterval)trackTime
{
	int trackPos;
	if (trackTime == 0.0) 
		trackPos = 0;
	else
		trackPos = [track animIndex];
	NSMutableArray* pts = [track goodPoints];
	int numPos = [pts count];
	
	NSTimeInterval trackOffset = [track animTimeBegin];
	
	TrackPoint* pt = nil;
	TrackPoint* prevPt;
	if (IS_BETWEEN(0, trackPos, (numPos-1)))
	{
		pt = [pts objectAtIndex:trackPos];
	}
	NSTimeInterval ti;
	if (pt && (trackPos < numPos))
	{
		//NSDate* trackStartTime = [track creationTime];
		ti = [pt DATE_METHOD] - trackOffset;
		if (ti > trackTime)
		{
			while (trackPos > 0)
			{
				int pos = trackPos - 1;
				pt = [pts objectAtIndex:pos];
				//NSTimeInterval ti = [[pt DATE_METHOD] timeIntervalSinceDate:trackStartTime];
				ti = [pt DATE_METHOD]  - trackOffset;
				if (ti >= trackTime) trackPos = pos;
				else break;
			}
		}
		else if (ti < trackTime)
		{
			while (trackPos < (numPos - 1))
			{
				int pos = trackPos + 1;
				pt = [pts objectAtIndex:pos];
				ti = [pt DATE_METHOD] - trackOffset;
				//NSTimeInterval ti = [[pt DATE_METHOD] timeIntervalSinceDate:trackStartTime];
				if (ti > trackTime) break;
				else
				{
					trackPos = pos;
					if (ti == trackTime)break;
				}
				prevPt = pt;
			}
		}
	}
	[track setAnimTime:trackTime];
	[track setAnimIndex:trackPos];
}


-(void)forceUpdate
{
	[self updateListeners:NO
			   updateTime:NO];
}


- (void) updateListeners:(BOOL)resetFrame updateTime:(BOOL)ut
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
	int num = [updateList count];
	for (int i=0; i<num; i++)
	{
		id <AnimationTarget> target = [updateList objectAtIndex:i];
		Track* t = (Track*) [target animationTrack];
		NSTimeInterval trackTime = animTime;
		if (t != nil)
		{
			///trackTime = CLIP(0.0, animTime, [t duration]);
			[self updateTrackAnimData:t time:trackTime];
		}
	   [target updatePosition:trackTime
					  reverse:playingInReverse
					animating:animating];
   }
}


- (void) updateTimerDuration
{
	endingTime = 0.0;
	int num = [updateList count];
	for (int i=0; i<num; i++)
	{
		id <AnimationTarget> target = [updateList objectAtIndex:i];
		Track* track = (Track*) [target animationTrack];
		if (track != nil)
		{
#if 0
			NSArray* pts = [track goodPoints];
			int numPts = [pts count];
			float trackDuration = 0.0;
			if (numPts > 0)
			{
				TrackPoint* lastPt = [pts objectAtIndex:(numPts-1)];
				//trackDuration =  [[lastPt DATE_METHOD] timeIntervalSinceDate:[track creationTime]];
				trackDuration =  [lastPt DATE_METHOD];
				

				
			}
#endif
			float trackDuration = track.animTimeEnd - track.animTimeBegin;
			if (trackDuration > endingTime)
				endingTime = trackDuration;
		}
	}
	if (animTime > endingTime)
		animTime = endingTime;
	//[self updateListeners:NO updateTime:NO];
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
      // We need the following line so that the view updates continue
      // when the user is dragging the slider
      [[NSRunLoop currentRunLoop] addTimer:rideTimer
                                   forMode:NSEventTrackingRunLoopMode];
   }
   [self updateAnimState:YES];
}


-(void)postStateChangeNotification:(NSString*)st sender:(id)sndr
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TransportStateChange" 
														object:sndr
													  userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithString:st] 
																						   forKey:@"state"]];
}


- (void) stop:(id)sender
{
	[self stopAnimation];
	playingInReverse = NO;
	[self postStateChangeNotification:@"stop"
							   sender:sender];
}


- (void) play:(id)sender reverse:(BOOL)inReverse
{
	[self stopAnimation];
	playingInReverse = inReverse;
	[self postStateChangeNotification:@"play"
							   sender:sender];
	[self startAnimation];
}


- (void) fastForward
{
	animTime = endingTime;
	[self updateListeners:NO 
			   updateTime:NO];
}


- (void) rewind
{
   //[self stopAnimation];
	[self updateListeners:YES 
			   updateTime:NO];
}


- (void) setSpeedFactor:(float)sf
{
	speedFactor = sf;
	[Utils setFloatDefault:sf
					forKey:RCBDefaultAnimSpeedFactor];
}


- (float) speedFactor
{
	return speedFactor;
}

- (void) setAnimTime:(NSTimeInterval)at
{
   playingInReverse = (at < animTime);
   animTime = at;
   [self updateListeners:NO updateTime:NO];
}

- (NSTimeInterval) animTime
{
   return animTime;
}

- (NSTimeInterval) endingTime
{
   return endingTime;
}

- (void) setTransportPanelController:(TransportPanelController*)tpc
{
   if (transportPanelController != tpc)
   {
      [transportPanelController release];
      transportPanelController = tpc;
      [transportPanelController retain];
   }
}

- (void) locateToPercentage:(float)percent
{
	percent = CLIP(0.0, percent, 100.0);
	NSTimeInterval newAnimTime = percent * endingTime/100.0;
	playingInReverse = (newAnimTime < animTime);
	animTime = newAnimTime;
	[self updateListeners:NO 
			   updateTime:NO];
}


- (void) applyLocateDelta:(float)delta
{
	if (endingTime > 0.0)
	{
		NSTimeInterval percent = animTime*100.0/endingTime;
		percent += 1.0 * delta;
		[self locateToPercentage:percent];
	}
}


- (void)locate:(NSNotification *)notification
{
}

- (BOOL) playingInReverse
{
   return playingInReverse;
}

- (BOOL) animating
{
   return animating;
}


- (void)togglePlay:(NSNotification *)notification
{
    BOOL rev = [self playingInReverse];
   if ([self animating])
   {
      [self stop:self];
   }
   else
   {
      [self play:self reverse:rev];
   }
}




@end
