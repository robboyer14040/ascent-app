//
//  NSImage+Tint.m
//  Ascent
//
//  Created by Rob Boyer on 9/8/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import "NSImage+Tint.h"

@implementation NSImage (Tint)

- (NSImage *)imageTintedWithColor:(NSColor *)tintColor {
    if (!tintColor) {
        return self;
    }

    NSImage *result = [[NSImage alloc] initWithSize:self.size];
    [result lockFocus];

    NSRect rect = { .origin = NSZeroPoint, .size = self.size };

    // Fill with the tint color
    [tintColor set];
    NSRectFill(rect);

    // Mask the fill with the alpha of the original image
    [self drawInRect:rect
            fromRect:NSZeroRect
           operation:NSCompositingOperationDestinationIn
            fraction:1.0
      respectFlipped:YES
               hints:nil];

    [result unlockFocus];
    [result setTemplate:NO]; // prevent AppKit from retinting this image

    return [result autorelease];
}

@end
