//
//  VertTicView.mm
//  Ascent
//
//  Created by Rob Boyer on 3/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "VertTicView.h"
#import "Defs.h"
#import "Utils.h"
#import "DrawingUtilities.h"
#import "SGView.h"
#import "TypeInfo.h"

@implementation VertTicView

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
    {
       sgView = nil;
       
       NSFont* font = [NSFont systemFontOfSize:10];
       textAttrs = [[NSMutableDictionary alloc] init];
       [textAttrs setObject:font forKey:NSFontAttributeName];
       
       font = [NSFont systemFontOfSize:8];
       tickFontAttrs = [[NSMutableDictionary alloc] init];
       [tickFontAttrs setObject:font forKey:NSFontAttributeName];
       
       isLeft = YES;
    }
    return self;
}


- (void) dealloc
{
   [tickFontAttrs release];
   [textAttrs release];
   [sgView release];
   [super dealloc];
}



-(float) vtDrawTickMarks:(TypeInfo*) ti type:(int)type bounds:(NSRect)tickBounds xOffset:(float)offset
{
   float tempMax;
   NSString* legend;
   BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
   switch (type)
   {
      case kAltitude:
         tempMax = [Utils convertClimbValue:[ti maxTickValue]];
         legend = useStatuteUnits ? @"ft" : @"m";
         break;
      case kSpeed:
      case kAvgSpeed:
      case kAvgMovingSpeed:
         tempMax = [Utils convertSpeedValue:[ti maxTickValue]];
         legend = useStatuteUnits ? @"mph" : @"kph";
         break;
      case kAvgPace:
      case kAvgMovingPace:
         tempMax = [ti maxTickValue];
         legend = useStatuteUnits ? @"min/mile" : @"min/km";
         break;
      case kDistance:
         tempMax = [Utils convertDistanceValue:[ti maxTickValue]];
         legend = useStatuteUnits ? @"miles" : @"km";
         break;
      case kAvgHeartrate:
         tempMax = [ti maxTickValue];
         legend = @"bpm";
         break;
      case kAvgCadence:
         tempMax = [ti maxTickValue];
         legend = @"rpm";
         break;
      case kMovingDuration:
      case kDuration:
         tempMax = [ti maxTickValue];
         legend = @"time";
         break;
      case kWeightPlot:
         tempMax = [Utils convertWeightValue:[ti maxTickValue]];
         legend =  useStatuteUnits ? @"lbs" : @"kg";
         break;
      case kCalories:
         tempMax = [ti maxTickValue];
         legend =   @"cals";
         break;
      default:
         tempMax = [ti maxTickValue];
         legend = @"";
         break;
   }
   NSColor* clr = [Utils colorFromDefaults:[ti colorKey]];
   [tickFontAttrs setObject:clr forKey:NSForegroundColorAttributeName];
   DUDrawTickMarks(tickBounds, isLeft ? kVerticalLeft : kVerticalRight, offset, 0.0,  tempMax, 
                   [ti numTicks], tickFontAttrs, [ti isTimeValue], 99999999999.0);
   float x;
   NSSize sz = [legend sizeWithAttributes:tickFontAttrs];
   if (isLeft)
   {
      x = tickBounds.origin.x + offset - sz.width;
   }
   else
   {
      x = tickBounds.origin.x + tickBounds.size.width - offset;
   }
   [legend drawAtPoint:NSMakePoint(x, tickBounds.origin.y - 16.0) withAttributes:tickFontAttrs];
   offset -= ([ti maxValueTextWidth]+2);
   return offset;
}



- (void)drawRect:(NSRect)rect 
{
   if ((sgView != nil) && [sgView haveData])
   {
      float lw = [sgView leftTickViewWidth];
      float rw = [sgView rightTickViewWidth];
      float w = (isLeft ? lw : rw);
      if (w <= 0.0) w = 1.0;
      NSScrollView* sv = [sgView enclosingScrollView];
      NSRect scrollFrame = [sv frame];
      float xPad;
      float offset = 0.0;
      NSRect bounds = [self frame];
      if (isLeft)
      {
         bounds.origin.x = 20.0;
         bounds.size.width = w+4;
         [self setFrame:bounds];
         xPad = w;
         offset = w;
      }
      else
      {
         bounds.origin.x = scrollFrame.origin.x + scrollFrame.size.width;
         bounds.size.width = w+4;
         [self setFrame:bounds];
         xPad = 10.0;
         offset = w;
      }
      bounds = [self bounds];
      bounds.size.width = w+4;
      
      NSColor* backgroundColor = [[self window] backgroundColor];
      [backgroundColor set];
      [NSBezierPath fillRect:bounds];
      
      float yPad = 30.0;     
      NSRect tickBounds = [self bounds];
      tickBounds.origin.y += (yPad + 11);
      NSRect sgBounds = [sgView bounds];
      tickBounds.size.height = sgBounds.size.height - (2*yPad);
      NSArray* typeInfoArray = [sgView typeInfoArray]; 
      int j; 
      int ctr = 0;
      for (j=0; j < kNumPlotTypes; j++)
      {
         TypeInfo* ti = [typeInfoArray objectAtIndex:j];
         if ([ti enabled])
         {
            BOOL skip = NO;
            tPlotType shared = [ti sharedRulerPlot];
            if (shared != kReserved)
            {
               TypeInfo* sti = [typeInfoArray objectAtIndex:shared];
               if ((sti != nil) && ([sti enabled]))
               {
                  skip = YES;
               }
            }
            if (skip == NO)
            {
               if (( isLeft && ((ctr % 2) == 0)) ||
                   (!isLeft && ((ctr % 2) != 0)))
               {
                  offset = [self vtDrawTickMarks:ti
                                            type:j
                                          bounds:tickBounds
                                         xOffset:offset];
               }
               ++ctr;
            }
         }
      }
   }
   else
   {
   }
}

- (SGView *)sgView {
   return [[sgView retain] autorelease];
}

- (void)setSgView:(SGView *)value {
   if (sgView != value) {
      [sgView release];
      sgView = value;
      [sgView retain];
   }
}


- (BOOL)isLeft {
   return isLeft;
}

- (void)setIsLeft:(BOOL)value {
   if (isLeft != value) {
      isLeft = value;
   }
}


@end
