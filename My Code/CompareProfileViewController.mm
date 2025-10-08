//
//  CompareProfileViewController.mm
//  Ascent
//
//  Created by Rob Boyer on 3/5/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "CompareProfileViewController.h"
#import "ActivityDetailView.h"
#import "CWTransparentView.h"

@implementation CompareProfileViewController
@synthesize adView;
@synthesize transparentView;
@synthesize track;
@synthesize lapOffset;

-(id)initWithTrack:(Track*)t profileView:(ActivityDetailView*)av transparentView:(CWTransparentView*)tv
{
	if (self = [super init])
	{
		self.track = t;
		self.transparentView = tv;
		self.adView = av;
		self.lapOffset = 0;
	}
	return self;
}

-(void)dealloc
{
	self.track = nil;
	self.transparentView = nil;
	self.adView = nil;
    [super dealloc];
}


-(void)setTrack:(Track*)t
{
	if (t != track)
	{
		track = t;
	}
	[self.adView setTrack:track
			  forceUpdate:NO];
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim
{
	[adView updateAnimation:trackTime reverse:rev];
	
}


-(void) beginAnimation
{
}


-(void) endAnimation
{
}

- (Track*) animationTrack
{
	return track;
}


-(BOOL)isFocused
{
	return self.adView == [[self.adView window] firstResponder];
}


@end
