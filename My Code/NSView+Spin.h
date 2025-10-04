//
//  NSView + spin.h
//  AscentTests
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView (Spin)
- (void)asc_startSpinningWithDuration:(CFTimeInterval)duration; // e.g. 0.9
- (void)asc_stopSpinning;
- (BOOL)asc_isSpinning;
@end
