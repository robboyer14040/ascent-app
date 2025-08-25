//
//  TransparentMapView.mm
//  Ascent
//
//  Created by Rob Boyer on 11/27/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "TransparentMapView.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "Defs.h"
#import "AnimTimer.h"


@implementation TransparentMapView

- (id)initWithFrame:(NSRect)frame hasHUD:(BOOL)hh
{
    self = [super initWithFrame:frame];
    if (self) {
        hasHUD = hh;
        // Initialization code here.
        NSString* path = [[NSBundle mainBundle] pathForResource:@"Dot" ofType:@"png"];
        dotImage = [[NSImage alloc] initWithContentsOfFile:path];
        path = [[NSBundle mainBundle] pathForResource:@"DataGraph" ofType:@"png"];
        dataGraphImage = [[NSImage alloc] initWithContentsOfFile:path];
        showDataRect = [Utils boolFromDefaults:RCBDefaultShowMDHUD] && hasHUD;
        if (hasHUD)
            hudOpacity = [Utils floatFromDefaults:RCBDefaultMDHUDTransparency];
        else
            hudOpacity = 0.0;
        //NSFont* font = [NSFont systemFontOfSize:8];
        NSFont* font = [NSFont boldSystemFontOfSize:8];
        animFontAttrs = [[NSMutableDictionary alloc] init];
        [animFontAttrs setObject:font forKey:NSFontAttributeName];
        ///font = [NSFont fontWithName:@"LCDMono2 Normal" size:10];
        font = [NSFont systemFontOfSize:10];
        if (font) {
            lcdFontAttrs = [[NSMutableDictionary alloc] init];
            [lcdFontAttrs setObject:font forKey:NSFontAttributeName];
            [lcdFontAttrs setObject:[NSColor whiteColor]  forKey:NSForegroundColorAttributeName];
        }
        position = NSZeroPoint;
        [self prefsChanged];
    }
    return self;
}


-(void) awakeFromNib
{
}


- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"Transparent MAP view dealloc...rc:%d", [self retainCount]);
#endif
}


#define ANIM_RECT_SIZE        12.0
#define DATA_RECT_WIDTH       70
#define DATA_RECT_HEIGHT      50
#define DATA_RECT_Y_SPACING   12
#define DATA_RECT_GRAPH_XOFF  35
#define COL2                  43
#define ROW1                  56
#define ROW2                  35
#define ROW3                  14
#define HORIZ_ROW_MID         76
#define ALT_MID               17
#define GRAD_MID              38
#define ALTGRAD_Y             9
#define HORIZ_METER_X         51
#define ROW1_METER_Y          65
#define METER_WIDTH           50
#define METER_HEIGHT          8

#define VERT_METER1_X         12
#define VERT_METER_Y          14
#define VERT_METER2_X         33
#define VERT_METER_HEIGHT     59
#define VERT_METER_WIDTH      8


- (void) updateBarGraph:(float)val displayValue:(NSString*)ds max:(float)max colorKey:(NSString*)ck pos:(NSPoint)pt textYOffset:(float)yoff isHR:(BOOL)isHR
{
   NSColor* clr = [Utils colorFromDefaults:ck];
   //[animFontAttrs setObject:[clr  colorWithAlphaComponent:hudOpacity]  forKey:NSForegroundColorAttributeName];
   NSSize sz = [ds sizeWithAttributes:animFontAttrs];
   [ds drawAtPoint:NSMakePoint(pt.x + HORIZ_ROW_MID - sz.width/2.0, pt.y + yoff - 1)
   withAttributes:animFontAttrs];
   if (max > 0)
   {
      NSRect drect;
      drect.origin.x = pt.x + HORIZ_METER_X;
      drect.origin.y = pt.y + yoff + 9;
      drect.size.height = METER_HEIGHT;
      drect.size.width = val * METER_WIDTH/max;
      NSBezierPath* dpath = [NSBezierPath bezierPathWithRect:drect];
      if (isHR == YES)
      {
         NSColor* zoneClr = [Utils colorFromDefaults:[Utils getHeartrateColorKey:[trackPoint heartrate]]] ;
         [[zoneClr colorWithAlphaComponent:hudOpacity] set];
         [dpath fill];
         [[clr colorWithAlphaComponent:hudOpacity] set];
		 [NSBezierPath setDefaultLineWidth:1.0];
         [dpath stroke];
      }
      else
      {
         [[clr colorWithAlphaComponent:hudOpacity] set];
         [dpath fill];
      }
   }
}   


#define DEBUG_FRAME

- (void)drawRect:(NSRect)rect 
{
 #if defined(DEBUG_FRAME) && defined(ASCENT_DBG)
   [[NSColor clearColor] set];
   NSRectFill([self bounds]);
   [[NSColor redColor] set];
   [NSBezierPath setDefaultLineWidth:1.0];
   [NSBezierPath strokeRect:[self bounds]];
#endif
   
   NSRect imageRect;
   imageRect.origin = NSZeroPoint;
   imageRect.size = [dotImage size];
   NSRect dataRect = imageRect;
   dataRect.origin = position;
   dataRect = NSOffsetRect(dataRect, -ANIM_RECT_SIZE/2.0, -ANIM_RECT_SIZE/2.0);
   [dotImage drawInRect:dataRect
               fromRect:imageRect
              operation:NSCompositeSourceOver
               fraction:1.0];

   [[self window] flushWindow];
}


-(void) prefsChanged
{
   useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
   if (useStatuteUnits)
   {
      //altFormat = @"%1.0fft";
      //speedFormat = @"%1.0fmph";
   }
   else
   {
      //altFormat = @"%1.0fm";
      //speedFormat = @"%1.0fkm/h";
   }
}


-(void) update:(NSPoint)pos trackPoint:(TrackPoint*)tpt animID:(int)aid
{
   position = pos;
   pos.x = (int)(pos.x + .5);
   pos.y = (int)(pos.y + .5);
   trackPoint = tpt;
   [self setNeedsDisplay:YES];
}


-(void) setShowHud:(BOOL)show
{
   showDataRect = show;
   [self setNeedsDisplay:YES];
   if (hasHUD) [Utils setBoolDefault:show
                              forKey:RCBDefaultShowMDHUD];
}


-(BOOL) showHud
{
   return showDataRect;
}


-(void) setMaxMinValueArrays:(float*)maxarr min:(float*)minarr;
{
   for (int i=0; i<kNumPlotTypes; i++)
   {
      maxValueArray[i] = maxarr[i];
      minValueArray[i] = minarr[i];
   }
}

-(void) setHudOpacity:(float)op
{
   hudOpacity = op;
   [self setNeedsDisplay:YES];
   [Utils setFloatDefault:op
                   forKey:RCBDefaultMDHUDTransparency];
}

-(float) hudOpacity
{
   return hudOpacity;
}


@end
