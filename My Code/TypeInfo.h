//
//  TypeInfo.h
//  Ascent
//
//  Created by Rob Boyer on 3/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"

@interface TypeInfo : NSObject 
{
   float       maxValue;
   float       maxTickValue;  // maxValue rounded up to closest tick mark
   float       scaleFactor;
   float       maxValueTextWidth;
   int         numTicks;
   NSString*   colorKey;
   NSBezierPath*  path;    // for line drawing only
   tPlotType   sharedRulerPlot;
   BOOL        enabled;
   BOOL        isAverage;
   BOOL        isTimeValue;
   BOOL        isMovingTimeValue;
}

- (float)maxValue;
- (void)setMaxValue:(float)value;

- (float)maxTickValue;
- (void)setMaxTickValue:(float)value;

- (float)scaleFactor;
- (void)setScaleFactor:(float)value;

- (float)maxValueTextWidth;
- (void)setMaxValueTextWidth:(float)value;

- (int)numTicks;
- (void)setNumTicks:(int)value;

- (NSString *)colorKey;
- (void)setColorKey:(NSString *)value;

- (NSBezierPath *)path;
- (void)setPath:(NSBezierPath *)value;

- (BOOL)enabled;
- (void)setEnabled:(BOOL)value;

- (BOOL)isAverage;
- (void)setIsAverage:(BOOL)value;

- (BOOL)isTimeValue;
- (void)setIsTimeValue:(BOOL)value;

- (BOOL)isMovingTimeValue;
- (void)setIsMovingTimeValue:(BOOL)value;

- (tPlotType)sharedRulerPlot;
- (void)setSharedRulerPlot:(tPlotType)value;




@end
