//
//  NSImage+Tint.h
//  Ascent
//
//  Created by Rob Boyer on 9/8/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Tint)

/// Returns a copy of the image with the given color applied to all non-transparent pixels.
/// The alpha channel of the original image is preserved.
- (NSImage *)imageTintedWithColor:(NSColor *)tintColor;

@end
