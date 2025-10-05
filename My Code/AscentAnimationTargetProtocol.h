//
//  AscentAnimationTargetProtocol.h
//  Ascent
//
//  Created by Rob Boyer on 10/5/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@protocol AscentAnimationTarget
-(Track*) animationTrack;
-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim;
-(void) beginAnimation;
-(void) endAnimation;
@end
