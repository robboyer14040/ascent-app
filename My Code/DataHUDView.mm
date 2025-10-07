//
//  DataHUDView.mm
//  Ascent
//
//  Created by Rob Boyer on 4/23/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "DataHUDView.h"
#import "TrackPoint.h"
#import "Utils.h"

@implementation DataHUDView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) 
	{
    }
    return self;
}


-(void)dealloc
{
    [super dealloc];
}

-(void) update:(TrackPoint*)tpt
{
   if (tpt != trackPoint)
   {
      trackPoint = tpt;
   }
   [self setNeedsDisplay:YES];
}


// draw background (alternating gray rects, 1 per line) and the heart rate zone color.  The 
// rest of the HUD is updated by the ActivityWindowController
- (void)drawRect:(NSRect)rect 
{
   [NSBezierPath setDefaultLineWidth:1.0];
   NSRect bounds = [self bounds];
   for (int i=0; i<kDataHudNumLines; i++)
   {
      NSRect r = bounds;
      r.origin.y =  kDataHudBottomY + (i*kDataHudTH) + 1;
      r.size.height = kDataHudTH;
      if ((i % 2) == 0) 
      {
         [[NSColor colorWithCalibratedRed:(44.0/255.0) green:(44.0/255.0) blue:(44.0/255.0) alpha:0.4] set];
         [NSBezierPath fillRect:r];
      }
   }
   
   NSRect drect;
   NSSize sz = bounds.size;
   drect.origin.x = 3.0;
   drect.origin.y = kDataHudH - 19.0;
   drect.size = sz;
   drect.size.width -= 6.0;
   drect.size.height = kDataHudHRBarH; 
   NSBezierPath* dpath = [NSBezierPath bezierPathWithRect:drect];
   if (trackPoint != nil)
   {
      NSString* colorKey = [Utils getHeartrateColorKey:[trackPoint heartrate]];
      if (colorKey == nil)
      {
         [[NSColor clearColor] set];
      }
      else
      {
         NSColor* zoneClr = [Utils colorFromDefaults:colorKey];
         [[zoneClr colorWithAlphaComponent:.7] set];
      }
      [dpath fill];
   }
}

@end
