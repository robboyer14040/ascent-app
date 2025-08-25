#import "MiniProfileView.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "MapPoint.h"
#import "DrawingUtilities.h"
#import "Utils.h"
#import "Defs.h"
#import "TransparentMapView.h"
#import "SplitTableItem.h"


#define DATE_METHOD           activeTimeDelta
#define DURATION_METHOD       movingDuration


@implementation MiniProfileView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
		currentTrack = lastTrack = nil;
		dpath = [[NSBezierPath alloc] init];
		lpath = [[NSBezierPath alloc] init];
		plottedPoints = [[NSMutableArray alloc] init];
		NSFont* font = [NSFont systemFontOfSize:6];
		tickFontAttrs = [[NSMutableDictionary alloc] init];
		[tickFontAttrs setObject:font forKey:NSFontAttributeName];
		splitsArray = nil;
		font = [NSFont systemFontOfSize:18];
		textFontAttrs = [[NSMutableDictionary alloc] init];
		[textFontAttrs setObject:font forKey:NSFontAttributeName];
		[textFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	}
	return self;
}


- (void)dealloc
{
#if DEBUG_LEAKS
	NSLog(@"destroying mini profile view ...");
#endif
}


-(void) awakeFromNib
{
   lastAnimPoint = NSZeroPoint;
   currentTrackPos = 0;
}



- (NSRect) drawBounds
{
	NSRect db = NSInsetRect([self bounds], 2.0, 2.0);
	db.size.height -= 4.0;
	db.size.width -= 4.0;
	return db;
}


-(void) setTransparentView:(TransparentMapView*)v
{
   transparentView = v;
}


#define RANGE_INDICATOR_WIDTH 6.0

static float calcY(float ymin, float ymax, float h, float v)
{
	float y = 0.0;
	float ydiff = ymax-ymin;
	if (ydiff != 0)
	{
		if (v > ymax) v = ymax;
		y = ((v-ymin) * h)/ydiff;
	}
	return y;
}


-(void) drawRangeIndicator:(int)type bounds:(NSRect)vTickBounds xoffset:(float)xoffset axis:(int)axis
					ymaxGR:(float)ymaxGR yminGR:(float)yminGR
					  ymax:(float)ymax ymin:(float)ymin
{
	[[[Utils colorFromDefaults:RCBDefaultAltitudeColor] colorWithAlphaComponent:.2] set];
	float h = vTickBounds.size.height;
	NSRect r;
	if (kVerticalLeft == axis)
	{
		r.origin.x = vTickBounds.origin.x + xoffset - RANGE_INDICATOR_WIDTH;
	}
	else
	{
		r.origin.x = vTickBounds.origin.x + vTickBounds.size.width - xoffset;
	}
	r.origin.y = vTickBounds.origin.y + calcY(yminGR, ymaxGR, h, ymin);
	r.size.width = RANGE_INDICATOR_WIDTH;
	r.size.height = vTickBounds.origin.y + calcY(yminGR, ymaxGR, h, ymax) - r.origin.y;
	[NSBezierPath fillRect:r];
}




#define numHorizTickPoints    20

- (NSRect) drawTickMarks:(int)numVertPoints
{
   NSRect bounds = [self drawBounds];
   bounds.origin.x += 25;
   bounds.size.width -= 25;
   
   [tickFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];

   
   float incr;
   NSRect tbounds;
   if (xAxisIsTime)
   {
		tbounds = bounds;
		int numHorizTicks = AdjustTimeRuler(numHorizTickPoints, 0.0, [currentTrack DURATION_METHOD], &incr);
		float graphDur = numHorizTicks*incr;
		tbounds.size.width = (graphDur*tbounds.size.width)/[currentTrack DURATION_METHOD];
		DUDrawTickMarks(tbounds, (int)kHorizontal, 0.0, 0.0, [currentTrack DURATION_METHOD], numHorizTicks, tickFontAttrs, YES, 
						tbounds.origin.x + bounds.size.width);
   }
   else
   {
		float tmxd = [Utils convertDistanceValue:maxdist];
		float tmnd = 0.0;
		int numHorizTicks = AdjustDistRuler(numHorizTickPoints, 0.0, tmxd-tmnd, &incr);
		tbounds = bounds;
		tbounds.size.width = (((float)numHorizTicks)*incr*tbounds.size.width)/(tmxd-tmnd);
		DUDrawTickMarks(tbounds, (int)kHorizontal, 0.0, 0.0, numHorizTicks*incr, numHorizTicks, tickFontAttrs, NO, 
					   tbounds.origin.x + bounds.size.width);	// clip to original bounds
	   
	   
	   //DUDrawTickMarks(bounds, (int)kHorizontal, 0.0, 0.0, [Utils convertDistanceValue:maxdist], numHorizTickPoints, tickFontAttrs, NO, 99999999999.0);
   }

    
   bounds.origin.y += 14;
   bounds.size.height -= 14;
   [tickFontAttrs setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
   DUDrawTickMarks(bounds, (int)kVerticalLeft, 0.0, [Utils convertClimbValue:minalt], 
				   [Utils convertClimbValue:minalt+altdif], numVertPoints, tickFontAttrs, NO, 99999999999.0);

   return bounds;
}

- (NSRect) getPlotBounds
{
   NSRect bounds = [self drawBounds];
   bounds.origin.x += 25;
   bounds.origin.y += 14;
   bounds.size.width -= 23;
   bounds.size.height -= 14;
   return bounds;
}



#define ANIM_RECT_SIZE 12.0

- (void) drawAnimationBitmap
{
   if ([plottedPoints count] > currentTrackPos)
   {
      MapPoint* mpt;
      mpt = [plottedPoints objectAtIndex:currentTrackPos];
      NSPoint pt = [mpt point];
      //pt.x -= 10.0;
      //pt.y -= 10.0;
      if ((lastAnimPoint.x != pt.x) ||
          (lastAnimPoint.y != pt.y))
      {
		if (currentTrackPos < [[currentTrack goodPoints] count])
		{
			[transparentView update:pt 
						 trackPoint:[[currentTrack goodPoints] objectAtIndex:currentTrackPos]
							 animID:0];
			//NSLog(@"D: [%1.0f,%1.0f]", r.origin.x, r.origin.y);
			lastAnimPoint = pt;
		}
		
      }
   }
}       



- (void) drawSelectedRegion:(NSTimeInterval)wcStartTime endTime:(NSTimeInterval)wcEndTime color:(NSString*)clrString
{
	int sidx = [currentTrack findFirstGoodPointAtOrAfterDelta:wcStartTime
														startAt:0];
	int eidx = [currentTrack findFirstGoodPointAtOrAfterDelta:wcEndTime
														startAt:sidx];
	if ((sidx != -1) && (eidx == -1)) eidx = [[currentTrack goodPoints] count] - 1;
	int np = eidx-sidx+1;
	[lpath removeAllPoints];
	if ((np > 0) && (maxdist > 0.0))
	{
		NSMutableArray* pts = [currentTrack goodPoints];
		[lpath setLineWidth:1.0];
		NSPoint p;
		NSPoint firstP;
		if ((sidx < 0) || (sidx >= [pts count]))
		{
#if defined(ASCENT_DBG) 			
			printf("wtf? -- there's a probem in MiniProfileView - FIXME!\n");
#endif
		}
		else
		{
			
			TrackPoint* pt = [pts objectAtIndex:sidx];
			NSRect plotBounds = [self getPlotBounds];
			float x = plotBounds.origin.x;
			float y = plotBounds.origin.y;
			float w = plotBounds.size.width;
			float h = plotBounds.size.height;
			p.x = x + ((w*[pt distance])/(maxdist));
			p.y = y + (([pt altitude]-minalt) * h)/altdif;
			firstP = p;
			[lpath moveToPoint:p];
			int i = 1;
			float lastdist = 0;
			while (i < np)
			{
				pt = [pts objectAtIndex:sidx+i];
				if ([pt isDeadZoneMarker]) continue;
				float alt = [pt altitude];
				float dist = [pt distance];
				if (dist < lastdist) dist = lastdist;
				lastdist = dist;
	#if 0
				if (xAxisIsTime)
				{
					NSTimeInterval t = [[pt DATE_METHOD] timeIntervalSinceDate:[currentTrack creationTime]];
					if (dur > 0.0) 
						p.x = x + ((w*t)/(dur));
					else
						p.x = x;
				}
				else
	#endif
				{
					p.x = x + ((w*dist)/(maxdist));
				}
				p.y = y + (((alt-minalt) * h)/altdif);
				[lpath lineToPoint:p];
				++i;
			}
			if ((np > 0) && ![lpath isEmpty])
			{
				[[NSColor blackColor] set];
				[lpath setLineWidth:0.5];
				[lpath stroke];
				[[[Utils colorFromDefaults:clrString] colorWithAlphaComponent:.5] set];
				NSPoint p = [lpath currentPoint];
				p.y = plotBounds.origin.y;
				[lpath lineToPoint:p];
				p.x = firstP.x;
				[lpath lineToPoint:p];
				[lpath closePath];
				[lpath fill];
			}
		}
	}
}


- (void)updateTrackAnimation:(int)pos
{
   currentTrackPos = pos;
   [self drawAnimationBitmap];
}

- (void) drawSelectedLap
{
   if (selectedLap)
   {
	   ///NSTimeInterval startTimeDelta = [currentTrack lapActiveTimeDelta:selectedLap];
	   ///NSTimeInterval lapTime = [currentTrack movingDurationOfLap:selectedLap];
	   NSTimeInterval startTimeDelta = [selectedLap startingWallClockTimeDelta];
	   //NSTimeInterval lapTime = [selectedLap totalTime];
       NSTimeInterval lapTime = [currentTrack durationOfLap:selectedLap];
	   [self drawSelectedRegion:startTimeDelta
						endTime:startTimeDelta + lapTime
						  color:RCBDefaultLapColor];
	}
}


- (void) drawSelectedSplits
{
	if (splitsArray)
	{
		int num = [splitsArray count];
		for (int i=0; i<num; i++)
		{
			SplitTableItem* sti = [splitsArray objectAtIndex:i];
			if (sti && [sti selected])
			{
				NSTimeInterval start = [sti splitTime];
                int idx = [currentTrack findIndexOfFirstPointAtOrAfterActiveTimeDelta:start];
                NSArray* pts = [currentTrack points];
                if (pts && [pts count] > idx)
                {
                    int np = [pts count];
                    float d = [sti splitDuration];
                    TrackPoint* spt = [pts objectAtIndex:idx];
                    TrackPoint* lpt = nil;
                    while (idx < np)
                    {
                        lpt = [pts objectAtIndex:idx];
                        if ([lpt activeTimeDelta] >= (start + d)) break;
                        ++idx;
                    }
                    [self drawSelectedRegion:[spt wallClockDelta]
                                     endTime:lpt ? [lpt wallClockDelta] : [spt wallClockDelta]
                                       color:RCBDefaultSplitColor];
                }
			}
		}
	}
}



- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSRect drawBounds = [self drawBounds];

	//NSShadow *dropShadow = [[[NSShadow alloc] init] autorelease];
	//[dropShadow setShadowColor:[NSColor blackColor]];
	//[dropShadow setShadowBlurRadius:5];
	//[dropShadow setShadowOffset:NSMakeSize(0,-3)];

	// save graphics state
	[NSGraphicsContext saveGraphicsState];

	//[dropShadow set];

	// fill the desired area
	[[Utils colorFromDefaults:RCBDefaultBackgroundColor] set];
	[NSBezierPath fillRect:bounds];
	[[[NSColor blackColor] colorWithAlphaComponent:0.6] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:[self drawBounds]];
   
	// restore state
	[NSGraphicsContext restoreGraphicsState];

	if ((currentTrack != nil) && [currentTrack hasElevationData] && ([[currentTrack goodPoints] count] > 1))
	{
		BOOL isStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		NSRect plotBounds = [self getPlotBounds];
		lastTrack = currentTrack;
		NSMutableArray* pts = [currentTrack goodPoints];
		NSNumber *mxn, *mnn;
		[Utils maxMinAlt:pts
					 max:&mxn
					 min:&mnn];
		
		///NSNumber* numMaxAlt = [pts valueForKeyPath:@"@max.altitude"];		// in FEET
		float maxAltNative = [Utils convertClimbValue:[mxn floatValue]];
		float dmNative = [Utils convertClimbValue:[Utils floatFromDefaults:RCBDefaultMaxAltitude]];
		if ((dmNative > 0) && (maxAltNative < dmNative))
		{
			maxAltNative = dmNative;
		}
		if (isStatute)
			maxAltNative = (float)((((int)maxAltNative+99)/100)*100);
		else
			maxAltNative = (float)((((int)maxAltNative+19)/20)*20);
		
		///NSNumber* numMinAlt = [pts valueForKeyPath:@"@min.altitude"];		// in FEET
		float minAltNative = [Utils convertClimbValue:[mnn floatValue]];
		if (isStatute)
			minAltNative = (float)((((int)minAltNative-199)/100)*100); 
		else
			minAltNative = (float)((((int)minAltNative-39)/20)*20);

		NSNumber* num = [pts valueForKeyPath:@"@max.distance"];
		maxdist = [num floatValue];
		float incr;
		numVertTickPoints = AdjustRuler(10, minAltNative, maxAltNative, &incr);
		float altDifNative = (numVertTickPoints)*incr;
		//maxalt = minalt + altdif;
		minAltNative = maxAltNative - altDifNative;
		if (isStatute)
		{
			maxalt = maxAltNative;
			minalt = minAltNative;
			altdif = altDifNative;
		}
		else
		{
			maxalt = MetersToFeet(maxAltNative);
			minalt = MetersToFeet(minAltNative);
			altdif = MetersToFeet(altDifNative);
		}
		
		[dpath removeAllPoints];
		float w = plotBounds.size.width;
		float h = plotBounds.size.height;
		float x = plotBounds.origin.x;
		float y = plotBounds.origin.y;
		//float dy = h*.05;
		//h -= (dy*2);
		numPts = [pts count];
		[plottedPoints removeAllObjects];
		float dur = 0.0;
		if (numPts > 0)
		{
			TrackPoint* lastPt = [pts objectAtIndex:(numPts-1)];
			//if ([[lastPt DATE_METHOD] timeIntervalSinceDate:[currentTrack creationTime]] > [currentTrack DURATION_METHOD])
			if ([lastPt DATE_METHOD] > [currentTrack DURATION_METHOD])
			{
				dur = [currentTrack duration];
			}
			else
			{
				dur = [currentTrack DURATION_METHOD];
			}
		}
		if ((numPts > 0) && (maxdist > 0.0))
		{
			// y += dy; 
			[dpath setLineWidth:1.0];
			//[dpath setLineJoinStyle:NSRoundLineJoinStyle];
			NSPoint p;
			TrackPoint* pt = [pts objectAtIndex:0];
			p.x = x;
			float alt = [currentTrack firstValidAltitudeUsingGoodPoints:0];
			if (alt == BAD_ALTITUDE) alt = 0.0;
			p.y = y + ((alt-minalt) * h)/altdif;
			MapPoint* mpt = [[MapPoint alloc] initWithPoint:p time:[pt DATE_METHOD] speed:[pt speed]];
			[plottedPoints addObject:mpt];
			[dpath moveToPoint:p];
			int i = 1;
			float lastdist = 0;
			while (i < numPts)
			{
				pt = [pts objectAtIndex:i];
				//float alt = [pt altitude];
				alt = [currentTrack firstValidAltitudeUsingGoodPoints:i];
				if (alt == BAD_ALTITUDE) alt = 0.0;
				float dist = [pt distance];
				if (dist < lastdist) dist = lastdist;
				lastdist = dist;
				if (xAxisIsTime)
				{
					//NSTimeInterval t = [[pt DATE_METHOD] timeIntervalSinceDate:[currentTrack creationTime]];
					NSTimeInterval t = [pt DATE_METHOD];
					if (dur > 0.0) 
						p.x = x + ((w*t)/(dur));
					else
						p.x = x;
				}
				else
				{
					p.x = x + ((w*dist)/(maxdist));
				}
				p.y = y + (((alt-minalt) * h)/altdif);
				//NSLog(@"[%1.0f,%1.0f]", p.x, p.y);
				MapPoint* mpt = [[MapPoint alloc] initWithPoint:p time:[pt DATE_METHOD] speed:[pt speed]];
				[plottedPoints addObject:mpt];
				[dpath lineToPoint:p];
				++i;
			}
		}
		
		
		[[NSColor colorWithCalibratedRed:(217.0/255.0) green:(217.0/255.0) blue:(217.0/255.0) alpha:1.0] set];
		[NSBezierPath fillRect:bounds];
		NSRect tbounds = [self drawTickMarks:numVertTickPoints];

		[self drawRangeIndicator:kAltitude
						  bounds:tbounds
						 xoffset:0
							axis:0
						  ymaxGR:maxalt						// in FEET
						  yminGR:minalt						// in FEET
							ymax:[mxn floatValue]		// in FEET
							ymin:[mnn floatValue]];	// in FEET
		
		if ((numPts > 0) && ![dpath isEmpty])
		{
			[[NSColor blackColor] set];
			[dpath setLineWidth:0.5];
			[dpath stroke];
			[[[Utils colorFromDefaults:RCBDefaultAltitudeColor] colorWithAlphaComponent:.3] set];
			NSPoint p = [dpath currentPoint];
			p.y = plotBounds.origin.y;
			[dpath lineToPoint:p];
			p.x = plotBounds.origin.x;
			[dpath lineToPoint:p];
			[dpath closePath];
			[dpath fill];
		}
	  
		[self drawAnimationBitmap];
		//[[NSColor blackColor] set];
		//[NSBezierPath strokeRect:[self drawBounds]];
		[self drawSelectedLap];
		[self drawSelectedSplits];

		[[NSColor blackColor] set];
		[NSBezierPath setDefaultLineWidth:0.4];
		[NSBezierPath strokeRect:NSInsetRect(bounds, -0.4, 0.4)];
	}
	else
	{
		//[[NSColor colorWithCalibratedRed:(217.0/255.0) green:(217.0/255.0) blue:(217.0/255.0) alpha:1.0] set];
		//[NSBezierPath fillRect:drawBounds];
		NSString* s = currentTrack ? @"No Altitude Data" : @"No Activity Selected";
		NSSize size = [s sizeWithAttributes:textFontAttrs];
		float x = drawBounds.origin.x + drawBounds.size.width/2.0 - size.width/2.0;
		float y = (drawBounds.size.height/2.0) - (size.height/2.0);
		[textFontAttrs setObject:[[NSColor blackColor] colorWithAlphaComponent:0.20] forKey:NSForegroundColorAttributeName];
		[s drawAtPoint:NSMakePoint(x,y) 
		withAttributes:textFontAttrs];
	}
}


-(void) setCurrentTrack:(Track*) tr
{
	if (currentTrack != tr)
	{
		currentTrack = tr;
	}
	xAxisIsTime = [Utils intFromDefaults:RCBDefaultXAxisType] > 0 ? YES : NO;
	[transparentView setHidden:(currentTrack == nil)||([[currentTrack goodPoints] count] <= 1)];
	lastAnimPoint.x = -42.0;
	lastAnimPoint.y = -42.0;
	[self setNeedsDisplay:YES];
}


- (Lap *)selectedLap {
   return selectedLap;
}

- (void)setSelectedLap:(Lap *)value 
{
   if (selectedLap != value) 
   {
       selectedLap = value;
      [self setNeedsDisplay:YES];
   }
}


- (void)setSplitArray:(NSArray *)value
{
	if (splitsArray != value)
	{
		splitsArray = value;
	}
	[self setNeedsDisplay:YES];
}

-(void)mouseDown:(NSEvent *)event
{
	int i = [event clickCount];
	if(2==i)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"OpenActivityDetail" object:self];
	}
}


@end
