//
//  DrawingUtilities.h
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum tAxis
{
   kVerticalLeft,
   kVerticalRight,
   kHorizontal
};

void DUDrawTickMarks(NSRect bounds, int axis, float xoffset, float min, float max, 
                     int numTickPoints, NSMutableDictionary* tickFontAttrs,
                     BOOL isTime, float xClipAfter);

                   
int AdjustRuler(int maxTicks, float min,  float max, float* incr);
int AdjustTimeRuler(int maxTicks, float min,  float max, float* incr);
int AdjustDistRuler(int maxTicks, float min,  float max, float* incr);
float TickTextWidth(float value, NSMutableDictionary* tickFontAttrs, BOOL isTime);

CGImageRef CreateCGImage(CFStringRef path);
CGColorRef CGColorCreateFromNSColor (CGColorSpaceRef
									 colorSpace, NSColor *color);

CGSize GetCGTextSize(CGContextRef context, NSString* s);
