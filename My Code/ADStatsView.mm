//
//  ADStatsView.mm
//  Ascent
//
//  Created by Robert Boyer on 4/17/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "ADStatsView.h"
#import "Defs.h"
#import "Utils.h"
#import "TrackPoint.h"


@implementation ADStatsView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void) dealloc
{
   [zoneTypeKey release];
	[super dealloc];
}

- (NSArray *)points 
{
   return [[points retain] autorelease];
}

- (void)setPlotData:(NSArray *)value minDist:(float)mnd maxDist:(float)mxd minAlt:(float)mna maxAlt:(float)mxa hrz:(float*)zones zoneType:(int)ztype
{
   if (points != value) 
   {
      [points release];
      points = value;
      [points retain];
   }
   minAlt = mna;
   maxAlt = mxa;
   minDist = mnd;
   maxDist = mxd;
   zoneType = ztype;
   totalTime = 0.0;
   for (int i=0; i<=kNumHRZones; i++)     // index 0 is dead time
   {
      totalTime += zones[i];
      zoneTimes[i] = zones[i];
   }
   [self setNeedsDisplay:YES];
}

static const float kPlotHeight = 62.0;


-(void)drawRowBackgroundRects:(NSRect)bounds num:(int)numLines ypos:(float)ypos firstIsDarker:(BOOL)fid
{
	for (int i=0; i<numLines; i++)
	{
		NSRect r = bounds;
		r.origin.y =  ypos + (i*hudTH) + 1;
		r.size.height = hudTH;
		if (fid) 
		{
			[[NSColor colorWithCalibratedRed:(44.0/255.0) green:(44.0/255.0) blue:(44.0/255.0) alpha:0.4] set];
			[NSBezierPath fillRect:r];
		}
		fid = !fid;
	}
}



- (void)drawRect:(NSRect)rect 
{
	NSRect bounds = [self bounds];
	[[NSColor clearColor] set];
	[NSBezierPath fillRect:bounds];

	// draw the altitude profile -----------------------------------------------
    NSUInteger numPts = [points count];
	if (numPts > 0)
	{
		NSRect r = bounds;
		r.size.width -= 20.0;
		r.origin.x += 10.0;
		r.size.height = kPlotHeight;
		r.origin.y = ySED + (kNumSEDLines*hudTH) + 20.0 + 15.0;

		[[NSColor colorWithCalibratedRed:(44.0/255.0) green:(44.0/255.0) blue:(44.0/255.0) alpha:0.4] set];
		[NSBezierPath fillRect:r];
		[[[NSColor blackColor] colorWithAlphaComponent:0.5] set];
		[NSBezierPath setDefaultLineWidth:1.0];
		[NSBezierPath strokeRect:r];

		float altdiff = maxAlt-minAlt;
		float distdiff = maxDist-minDist;
		float ymax = r.origin.y + r.size.height - 2.0;
		float ymin = r.origin.y + 1.0;
		float xmin = r.origin.x + 1.0;
		float xmax = r.origin.x + r.size.width - 2.0;
		if ((altdiff > 0.0) && (distdiff > 0.0))
		{
			NSBezierPath* bezpath = [[[NSBezierPath alloc] init] autorelease];
			[bezpath moveToPoint:NSMakePoint(r.origin.x,r.origin.y)];
			for (int i=0; i<numPts; i++)
			{
				TrackPoint* pt = [points objectAtIndex:i];
				float alt = [pt altitude];
				float dist = [pt distance];
				float y = r.origin.y + 1 + ((alt - minAlt)*(kPlotHeight-2)/(altdiff));
				y = CLIP(ymin, y, ymax);
				float x = r.origin.x + 1 + ((dist - minDist)*(r.size.width-2)/(distdiff));
				x = CLIP(xmin, x, xmax);
				[bezpath lineToPoint:NSMakePoint(x,y)];
			}
			[bezpath setLineWidth:0.4];
			[[NSColor grayColor] set];
			[bezpath stroke];
			[bezpath lineToPoint:NSMakePoint(r.origin.x + r.size.width, r.origin.y)];
			[bezpath closePath];
			[[[Utils colorFromDefaults:RCBDefaultAltitudeColor] colorWithAlphaComponent:0.5] set];
			[bezpath fill];
		}
	}

	// draw section divider lines, try to make them look 3D --------------------
	float x = bounds.origin.x;
	float y = ySED - 4;
	[NSBezierPath setDefaultLineWidth:0.7];
	[[NSColor blackColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y) 
							 toPoint:NSMakePoint(x + bounds.size.width, y)];
	[NSBezierPath setDefaultLineWidth:0.6];
	[[NSColor grayColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y-1) 
							 toPoint:NSMakePoint(x + bounds.size.width, y-1)];

	y = ySED + (kNumSEDLines*hudTH) + 16;

	[NSBezierPath setDefaultLineWidth:0.7];
	[[NSColor blackColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y) 
							 toPoint:NSMakePoint(x + bounds.size.width, y)];
	[NSBezierPath setDefaultLineWidth:0.6];
	[[NSColor grayColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y-1) 
							 toPoint:NSMakePoint(x + bounds.size.width, y-1)];

	y = yAMM - 4;
	[NSBezierPath setDefaultLineWidth:0.7];
	[[NSColor blackColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y) 
							 toPoint:NSMakePoint(x + bounds.size.width, y)];
	[NSBezierPath setDefaultLineWidth:0.6];
	[[NSColor grayColor] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(x,y-1) 
							 toPoint:NSMakePoint(x + bounds.size.width, y-1)];

	// draw alternating striped background rects -------------------------------
	[self drawRowBackgroundRects:bounds
							 num:kNumSEDLines
							ypos:ySED
				   firstIsDarker:YES];
	[self drawRowBackgroundRects:bounds
							 num:kNumAMMLines
							ypos:yAMM
				   firstIsDarker:YES];
	[self drawRowBackgroundRects:bounds
							 num:kNumHRZones+1
							ypos:yHR
				   firstIsDarker:NO];
	

	// draw HR Zone graphs -----------------------------------------------------
	NSColor* colors[kNumHRZones+1];
	colors[0] = [Utils colorForZoneUsingZone:zoneType zone:-1];
	colors[1] = [Utils colorForZoneUsingZone:zoneType zone:0];
	colors[2] = [Utils colorForZoneUsingZone:zoneType zone:1];
	colors[3] = [Utils colorForZoneUsingZone:zoneType zone:2];
	colors[4] = [Utils colorForZoneUsingZone:zoneType zone:3];
	colors[5] = [Utils colorForZoneUsingZone:zoneType zone:4];

	if (totalTime > 0.0)
	{
		float gw = bounds.size.width - (xCOL1 + 60.0 + 62.0);
		for (int i=0; i<=kNumHRZones; i++)
		{
			NSRect r;
			r.origin.x = xCOL1 + 60.0;
			r.origin.y = yHR + (i*hudTH) + 2;
			r.size.width = zoneTimes[i] * gw/totalTime;
			r.size.height = hrzGraphH;
			if (colors[i] != nil)
				[[colors[i] colorWithAlphaComponent:0.8] set];
			else
				[[NSColor colorWithCalibratedRed:(255.0/255.0) green:(255.0/255.0) blue:(255.0/255.0) alpha:0.2] set];
			[NSBezierPath fillRect:r];
		}
	}
}


@end
