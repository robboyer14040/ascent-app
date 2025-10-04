//
//  NSView + spin.m
//  AscentTests
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import "NSView+Spin.h"
#import <QuartzCore/QuartzCore.h>

static inline void ASCEnsureCenteredAnchor(NSView *v) {
    [v setWantsLayer:YES];
    CALayer *layer = v.layer;
    if (!layer) return;

    CGPoint newAnchor = CGPointMake(0.5, 0.5);
    CGPoint oldAnchor = layer.anchorPoint;
    if (fabs(oldAnchor.x - 0.5) < 1e-6 && fabs(oldAnchor.y - 0.5) < 1e-6) {
        return; // already centered
    }

    // Adjust position so the view doesn’t visually move when we change anchorPoint.
    CGFloat w = NSWidth(v.bounds), h = NSHeight(v.bounds);
    CGPoint pos = layer.position;
    pos.x += (newAnchor.x - oldAnchor.x) * w;
    pos.y += (newAnchor.y - oldAnchor.y) * h;

    layer.anchorPoint = newAnchor;
    layer.position    = pos;
}

@implementation NSView (Spin)

- (void)asc_startSpinningWithDuration:(CFTimeInterval)duration {
    if (duration <= 0) duration = 1.0;
    [self setWantsLayer:YES];

    ASCEnsureCenteredAnchor(self); // ⬅️ make the rotation pivot the center

    CALayer *layer = self.layer;
    if ([layer animationForKey:@"asc.spin"]) return;

    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue = @0.0;
    spin.toValue   = @(M_PI * 2.0);
    spin.duration  = duration;
    spin.repeatCount = HUGE_VALF;
    spin.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    spin.removedOnCompletion = NO;
    spin.fillMode = kCAFillModeForwards;

    [layer addAnimation:spin forKey:@"asc.spin"];
}

- (void)asc_stopSpinning {
    [self.layer removeAnimationForKey:@"asc.spin"];
}

- (BOOL)asc_isSpinning {
    return (self.layer && [self.layer animationForKey:@"asc.spin"] != nil);
}

@end

