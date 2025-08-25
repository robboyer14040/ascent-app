//
//  TypeInfo.mm
//  Ascent
//
//  Created by Rob Boyer on 3/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "TypeInfo.h"

@implementation TypeInfo

- (id) init
{
   id me = [super init];
   enabled = NO;
   isAverage = NO;
   isTimeValue = NO;
   isMovingTimeValue = NO;
   maxValue = 0.0;
   scaleFactor = 0.0;
   maxValueTextWidth = 0.0;
   maxTickValue = 0.0;
   sharedRulerPlot = kReserved;
   path = nil;
   return me;
}


- (void) dealloc
{
}



- (float)maxValue {
   return maxValue;
}

- (void)setMaxValue:(float)value {
   if (maxValue != value) {
      maxValue = value;
   }
}

- (float)maxTickValue {
   return maxTickValue;
}

- (void)setMaxTickValue:(float)value {
   if (maxTickValue != value) {
      maxTickValue = value;
   }
}

- (float)scaleFactor {
   return scaleFactor;
}

- (void)setScaleFactor:(float)value {
   if (scaleFactor != value) {
      scaleFactor = value;
   }
}

- (float)maxValueTextWidth {
   return maxValueTextWidth;
}

- (void)setMaxValueTextWidth:(float)value {
   if (maxValueTextWidth != value) {
      maxValueTextWidth = value;
   }
}

- (int)numTicks {
   return numTicks;
}

- (void)setNumTicks:(int)value {
   if (numTicks != value) {
      numTicks = value;
   }
}

- (NSString *)colorKey {
    return colorKey;
}

- (void)setColorKey:(NSString *)value {
   if (colorKey != value) {
      colorKey = [value copy];
   }
}

- (NSBezierPath *)path {
   return path;
}

- (void)setPath:(NSBezierPath *)value {
   if (path != value) {
      path = [value copy];
   }
}

- (BOOL)enabled {
   return enabled;
}

- (void)setEnabled:(BOOL)value {
   if (enabled != value) {
      enabled = value;
   }
}

- (BOOL)isAverage {
   return isAverage;
}

- (void)setIsAverage:(BOOL)value {
   if (isAverage != value) {
      isAverage = value;
   }
}

- (BOOL)isTimeValue {
   return isTimeValue;
}

- (void)setIsTimeValue:(BOOL)value {
   if (isTimeValue != value) {
      isTimeValue = value;
   }
}

- (BOOL)isMovingTimeValue {
   return isMovingTimeValue;
}

- (void)setIsMovingTimeValue:(BOOL)value {
   if (isMovingTimeValue != value) {
      isMovingTimeValue = value;
   }
}

- (tPlotType)sharedRulerPlot 
{
   return sharedRulerPlot;
}

- (void)setSharedRulerPlot:(tPlotType)value 
{
   sharedRulerPlot = value;
}




@end
