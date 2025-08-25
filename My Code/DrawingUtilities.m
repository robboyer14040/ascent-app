//
//  DrawingUtilities.mm
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "DrawingUtilities.h"


NSString*  buildText(float value, float max, BOOL isTime)
{
   NSString* s;
   if (isTime)
   {
      int val  = (int)(value);
      if (max >= 60*60)    // > 1 hour? if so, display hh::mm
      {
         val /= 60;        // display mm:ss
      }
      s = [NSString stringWithFormat:@"%2.2d:%2.2d", val/60, val%60 ];
   }
   else 
   {
      NSString* format;
      int intv = (int)value;
      if (((float)intv) != value)
      {
         format = @"%2.1f";
      }
      else
      {
         format = @"%2.0f";
      }
      s =  [NSString stringWithFormat:format, value];
   }
   return s;
}


void DUDrawTickMarks(NSRect bounds, int axis, float offset, float min, float max, 
                     int numTickPoints, NSMutableDictionary* tickFontAttrs, BOOL isTime,
                     float xClipAfter)
{
   float w = bounds.size.width;
   float h = bounds.size.height;
   float x = bounds.origin.x;
   float y = bounds.origin.y;
   //float dy = h*.05;
   //h -= (dy);
   float diff = max-min;
   if (0.0 != diff)
   {
      [[NSColor  blackColor] set];
      [NSBezierPath setDefaultLineWidth:1.0];
      int i;
      if ((axis == kVerticalLeft) || (axis == kVerticalRight))
      {
         float xpos;
         float toff, soff;
         float ty = y;
         float calt = min;
         if (axis == kVerticalRight)
         {
            xpos = x + w - offset;
            toff = 5;
          }
         else
         {
            xpos = x + offset;
            toff = -5;
         }
         //BOOL mustDrawZero = (min == -max);
         BOOL skipEven = (((numTickPoints-1)/2) % 2) == 0;
         BOOL skip = (numTickPoints >= 10) && skipEven;
          [[tickFontAttrs objectForKey:NSForegroundColorAttributeName] set];
          
          [NSBezierPath strokeLineFromPoint:NSMakePoint(xpos, y)
                                    toPoint:NSMakePoint(xpos, y + h)];
          for (i=0; i<numTickPoints+1; i++)
          {
             NSString* s = buildText(calt, max, isTime);
             NSSize size = [s sizeWithAttributes:tickFontAttrs];
             float hoff = size.height/2.0;
             if (axis == kVerticalRight)
             {
                soff = 0;
             }
             else
             {
                soff = -size.width;
             }
             BOOL drawText = ((skip == NO) || (i==0));
             if (drawText || (i<numTickPoints))
             {
                [NSBezierPath strokeLineFromPoint:NSMakePoint(xpos + toff, ty)
                                          toPoint:NSMakePoint(xpos, ty)];
             }
             if (drawText)
             {
                [s drawAtPoint:NSMakePoint(xpos + soff + toff, ty-hoff+.5)
                withAttributes:tickFontAttrs];
             }
             if (numTickPoints >= 10)  skip = !skip;
             calt += (diff/numTickPoints);
             ty += (h)/numTickPoints;
          }
      }
      else if (axis == kHorizontal)
      {
         float tx = x;
         float ty = y;
         float total = min;
         [[NSColor blackColor] set];
         float lw = x+w;
         if ((x+w) > xClipAfter)
         {
            lw = xClipAfter;
         }
         [NSBezierPath strokeLineFromPoint:NSMakePoint(x, y+14)
                                   toPoint:NSMakePoint(lw, y+14)];
         for (i=0; i<numTickPoints; i++)
         {
            tx += w/numTickPoints;
            if (tx < xClipAfter)
            {
               total += diff/numTickPoints;
               [NSBezierPath strokeLineFromPoint:NSMakePoint(tx, ty+9)
                                         toPoint:NSMakePoint(tx, ty+14)];
               
               
               if ((i%2)!=0)
               {
                  if (i > (numTickPoints-2)) tx -= 8;
                  NSString* s = buildText(total, max, isTime);
                  float addXoff = -5.0;
                  if (isTime) addXoff -= 6.0;
                  [s drawAtPoint:NSMakePoint(tx+addXoff, y)
                  withAttributes:tickFontAttrs];
               }
            }
         }
      }
   }
}


const float sVertIncrs[] = 
{
   0.2,
   0.25,
   0.5,
   1,
   2,
   5,
   10,
   15,
   20,
   25,
   50,
   100,
   200,
   250,
   300,
   400,
   500,
   1000,
   2000,
   5000,
   10000,
   50000,
   100000
};



int AdjustRuler(int maxTicks, float min,  float max, float* incr)
{
   int i = 0;
   float diff = max - min;
   int numPoints = diff/sVertIncrs[i];
   int numVertIncrs = sizeof(sVertIncrs)/sizeof(float);
   while ((numPoints > maxTicks) && (i < numVertIncrs))
   {
      ++i;
      numPoints = diff/sVertIncrs[i];
   }
   numPoints++;
   if (i >= numVertIncrs) i = (numVertIncrs - 1);
//   if ((numPoints & 0x01) == 0)
//   {
//      ++numPoints;
//   }
   *incr = sVertIncrs[i];
   return numPoints;
}


const float sDistIncrs[] = 
{
   0.1,
   0.2,
   0.25,
   0.5,
   1.0,
   2.0,
   3.0,
   4.0,
   5.0,
   6.0,
   8.0,
   10.0,
   20.0,
   25.0,
   30.0,
   40.0,
   50.0,
   100.0,
   150.0,
   200.0,
   500.0
};

int AdjustDistRuler(int maxTicks, float min,  float max, float* incr)
{
   int i = 0;
   float diff = max - min;
   int numPoints = diff/sDistIncrs[i];
   int numDistIncrs = sizeof(sDistIncrs)/sizeof(int);
   while ((numPoints > maxTicks) && (i < numDistIncrs))
   {
      ++i;
      numPoints = diff/sDistIncrs[i];
   }
   numPoints++;
   if (i >= numDistIncrs) i = (numDistIncrs - 1);
   *incr = sDistIncrs[i];
   return numPoints;
}



// for scaling time, in seconds
const int sVertTimeIncrs[] = 
{
   5,
   10,
   30,
   60,
   120,
   240,        // 4 mins
   360,        // 6 mins
   480,        // 8 mins
   600,        // 10 mins
   1200,       // 20 mins
   1800,       // 30 mins
   3600,       // 1 hr
   7200,       // 2 hrs
   14400,      // 4 hours
   28800,      // 8 hours
   (3*28800),  // 24 hours
};



int AdjustTimeRuler(int maxTicks, float min,  float max, float* incr)
{
   int i = 0;
   float diff = max - min;
   int numPoints = diff/sVertTimeIncrs[i];
   int numVertIncrs = sizeof(sVertTimeIncrs)/sizeof(int);
   while ((numPoints > maxTicks) && (i < numVertIncrs))
   {
      ++i;
      numPoints = diff/sVertTimeIncrs[i];
   }
   numPoints++;
   *incr = sVertTimeIncrs[i];
   return numPoints;
}


float TickTextWidth(float value, NSMutableDictionary* tickFontAttrs, BOOL isTime)
{
   NSString* s = buildText(value, value, isTime);
   NSSize size = [s sizeWithAttributes:tickFontAttrs];
   return size.width + 8;
}

