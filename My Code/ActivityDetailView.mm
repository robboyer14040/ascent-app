#import "ActivityDetailView.h"
#import "Track.h"
#import "TrackPoint.h"
#import "DrawingUtilities.h"
#import "Lap.h"
#import "PlotAttributes.h"
#import "Utils.h"
#import "Defs.h"
#import "PathMarker.h"
#import "AnimTimer.h"
//#import "ActivityDetailTransparentView.h"

typedef float (*tAccessor)(id, SEL);

@interface ActivityDetailView ()
-(void) resetPaths;
-(void)doDragMove:(float)dx;
@property(nonatomic) float maxdist;
@property(nonatomic) float mindist;
@end


@implementation ActivityDetailView

@synthesize drawHeader;
@synthesize dragStart;
@synthesize showVerticalTicks;
@synthesize showHorizontalTicks;
@synthesize plotDuration;
@synthesize topAreaHeight;
@synthesize overrideDistance;
@synthesize transparentView;
@synthesize maxdist;
@synthesize mindist;
@synthesize vertPlotYOffset;


#define HEADER_HEIGHT         50

#define DATE_METHOD           activeTimeDelta
#define DURATION_METHOD       movingDurationForGraphs
#define SLOWEST_PACE          1800.0

static const int kBadSpeed = -9999.99;

typedef struct _tPlotInfo
{
   int         type;
   const char* name;
   NSString*   defaultsKey;
   int         colorTag;
   NSPoint     pos;
   float       opacityDefault;
   int         lineStyleDefault;
   int         numPeaksDefault;
   int         peakThresholdDefault;
   BOOL        enabledDefault;
   BOOL        fillEnabledDefault;
   BOOL        showLapsDefault;
   BOOL        showPeaksDefault;
   BOOL        showMarkersDefault;
   int         averageType;
   BOOL        isAverage;
   
} tPlotInfo;

#define     Col1X    228
#define     Col2X    503
#define		Col3X	 776
#define     AltLineY 131
#define     Line1Y   131
#define     Line2Y   108
#define     Line3Y   85
#define     Line4Y   62
#define     Line5Y   39
#define     Line6Y   16

tPlotInfo plotInfoArray[] = 
{
   {  
		kAltitude,
		"Altitude", 
		@"RCBDefaultsPlotAlt",
		kAltitude,
		{ Col3X, AltLineY},
		0.25,
		0,
		3, 
		25,
		YES,
		YES,
		YES,
		NO,
		YES,
		kReserved,
		NO
	},
	{  
		kHeartrate,
		"Heart rate", 
		@"RCBDefaultsPlotHR",
		kHeartrate,
		{ Col1X, Line1Y},
		1.0,
		0,
		3, 
		25,
		YES,
		NO,
		NO,
		NO,
		NO,
		kAvgHeartrate,
		NO
	},
	{  
		kSpeed,
		"Speed", 
		@"RCBDefaultsPlotSpd",
		kSpeed,
		{ Col1X, Line2Y},
		1.0,
		0,
		3, 
		25,
		YES,
		NO,
		NO,
		NO,
		NO,
		kAvgSpeed,
		NO
	},
	{  
		kCadence,
		"Cadence", 
		@"RCBDefaultsPlotCad",
		kCadence,
		{ Col1X, Line3Y},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kAvgCadence,
		NO
	},
	{  
		kPower,
		"Power", 
		@"RCBDefaultsPlotPwr",
		kPower,
		{ Col1X, Line4Y},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kAvgPower,
		NO
	},
	{  
		kTemperature,
		"Temperature", 
		@"RCBDefaultsPlotTmp",
		kTemperature,
		{ Col1X, Line6Y},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kAvgTemperature,
		NO
	},
	{  
		kGradient,
		"Gradient", 
		@"RCBDefaultsPlotGrd",
		kGradient,
		{ Col1X, Line5Y},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kAvgGradient
	},
	{  
		kAvgHeartrate,
		"Heartrate", 
		@"RCBDefaultsPlotAvgHR",
		kHeartrate,
		{ Col2X, Line1Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
	},
	{  
		kAvgSpeed,
		"Speed", 
		@"RCBDefaultsPlotAvgSpd",
		kSpeed,
		{ Col2X, Line2Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
	},
	{  
		kAvgCadence,
		"Cadence", 
		@"RCBDefaultsPlotAvgCad",
		kCadence,
		{ Col2X, Line3Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
	},
	{  
		kAvgPower,
		"Power", 
		@"RCBDefaultsPlotAvgPwr",
		kPower,
		{ Col2X, Line4Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
	},
	{  
		kAvgTemperature,
		"Temperature", 
		@"RCBDefaultsPlotAvgTmp",
		kTemperature,
		{ Col2X, Line6Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
	},
	{  
		kAvgGradient,
		"Gradient", 
		@"RCBDefaultsPlotAvgGrd",
		kGradient,
		{ Col2X, Line5Y},
		1.0,
		1,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		YES
   },
#if 1
   {  
		kReserved,
		"Background", 
		@"RCBDefaultsPlotBck",
		kBackground,
		{ 844, Line1Y},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		NO
	},
#endif
	{  
		kReserved,
		"kReserved", 
		@"RCBDefaultsPlotRsvd",
		kBackground,
		{ 0, 0},
		1.0,
		0,
		3, 
		25,
		NO,
		NO,
		NO,
		NO,
		NO,
		kReserved,
		NO
   }
};



- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
   [mContextualMenuInvocation invoke];
   NSMenu* menu;
   [mContextualMenuInvocation getReturnValue:&menu];
   return menu;
}



-(void) setContextualMenuInvocation:(NSInvocation*)inv
{
   if (inv != mContextualMenuInvocation)
   {
      [mContextualMenuInvocation release];
      mContextualMenuInvocation = inv;
      [mContextualMenuInvocation retain];
   }
}

-(void) setSelectionUpdateInvocation:(NSInvocation*)inv
{
   if (inv != mSelectionUpdateInvocation)
   {
      [mSelectionUpdateInvocation release];
      mSelectionUpdateInvocation = inv;
      [mSelectionUpdateInvocation retain];
   }
}

-(void) setDataHudUpdateInvocation:(NSInvocation*)inv
{
   if (inv != dataHudUpdateInvocation)
   {
      [dataHudUpdateInvocation release];
      dataHudUpdateInvocation = inv;
      [dataHudUpdateInvocation retain];
   }
}


- (NSRect) drawBounds
{
   return NSInsetRect([self bounds], 4.0, 4.0);
}
      

- (instancetype)initWithFrame:(NSRect)r {
    if ((self = [super initWithFrame:r])) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super initWithCoder:c])) [self commonInit];
    return self;
}

- (void)commonInit
{
    track = nil;
    lap = nil;
    vertPlotYOffset = 14.0;
    dragStart = NO;
    drawHeader = YES;
    showVerticalTicks= YES;
    showHorizontalTicks= YES;
    overrideDistance = NO;
    topAreaHeight = ACTIVITY_VIEW_TOP_AREA_HEIGHT;
    NSFont* font = [NSFont systemFontOfSize:8];
    tickFontAttrs = [[NSMutableDictionary alloc] init];
    [tickFontAttrs setObject:font forKey:NSFontAttributeName];
    font = [NSFont systemFontOfSize:9];
    animFontAttrs = [[NSMutableDictionary alloc] init];
    [animFontAttrs setObject:font forKey:NSFontAttributeName];
    font = [NSFont systemFontOfSize:12];
    headerFontAttrs = [[NSMutableDictionary alloc] init];
    [headerFontAttrs setObject:font forKey:NSFontAttributeName];
    font = [NSFont systemFontOfSize:24];
    textFontAttrs = [[NSMutableDictionary alloc] init];
    [textFontAttrs setObject:font forKey:NSFontAttributeName];
    [textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
    
    [self _updatePlotAttributes];
    

    animRectColor = [[NSColor colorWithCalibratedRed:(217.0/255.0)
                                               green:(217.0/255.0)
                                                blue:(217.0/255.0)
                                               alpha:0.65] retain];

    currentTrackPos = 0;
    posOffsetIndex = 0;
    markerRightPadding = -1.0;
    lastdist = 0.0;
    firstAnim = NO;
    bypassAnim = NO;
    animating = NO;
    trackHasPoints = NO;
    selectRegionInProgress = NO;
    xAxisIsTime = NO;
    lastXAxisIsTime = xAxisIsTime;
    NSString* path = [[NSBundle mainBundle] pathForResource:@"AltitudeSign" ofType:@"png"];
    altSignImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"LapMarker" ofType:@"png"];
    lapMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"StartMarker" ofType:@"png"];
    startMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"FinishMarker" ofType:@"png"];
    finishMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"PeakMarker" ofType:@"png"];
    peakImage = [[NSImage alloc] initWithContentsOfFile:path];
    peakType = [Utils intFromDefaults:RCBDefaultPeakItem];
    dataRectType = [Utils intFromDefaults:RCBDefaultAnimationFollows];;
    numPeaks = [Utils intFromDefaults:RCBDefaultNumPeaks];
    numAvgPoints = [Utils intFromDefaults:RCBDefaultNumPointsToAverage];
    if (numAvgPoints <= 0) numAvgPoints = 10;
    peakThreshold = [Utils intFromDefaults:RCBDefaultPeakThreshold];
    showPeaks = [Utils boolFromDefaults:RCBDefaultShowPeaks];
    showLaps = [Utils boolFromDefaults:RCBDefaultShowLaps];
    showMarkers = [Utils boolFromDefaults:RCBDefaultShowMarkers];
    showPowerPeakIntervals = [Utils boolFromDefaults:RCBDefaultShowPowerPeakIntervals];
    showCrossHairs = [Utils boolFromDefaults:RCBDefaultShowCrosshairs];
    showHRZones = [Utils boolFromDefaults:RCBDefaultShowHRZones];
    showPace = [Utils boolFromDefaults:RCBDefaultDisplayPace];
    zonesOpacity = [Utils floatFromDefaults:RCBDefaultZonesTransparency];
    numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [numberFormatter setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
    [numberFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
    [numberFormatter setLocale:[NSLocale currentLocale]];
#endif
}


- (void) dealloc
{
	[numberFormatter release];
	[self resetPaths];
	[mContextualMenuInvocation release];
	[mSelectionUpdateInvocation release];
	[dataHudUpdateInvocation release];
	[track release];
	[lap release];
	[plotAttributesArray release];
	[animRectColor release];
	[textFontAttrs release];
	[tickFontAttrs release];
	[animFontAttrs release];
	[headerFontAttrs release];
	[lapMarkerImage release];
	[startMarkerImage release];
	[finishMarkerImage release];
	[peakImage release];
	[altSignImage release];
	[super dealloc];
}

-(void) _updatePlotAttributes
{
    if (!plotAttributesArray) {
        plotAttributesArray = [[NSMutableArray arrayWithCapacity:kNumPlotTypes] retain];
    } else {
        [plotAttributesArray removeAllObjects];
    }
    
    int i;
    int numPlotTypes = sizeof(plotInfoArray)/sizeof(tPlotInfo);
    for (i=0; i<kNumPlotTypes; i++)
    {
        [plotAttributesArray addObject:[[[PlotAttributes alloc] init] autorelease]];
    }

    for (i=0; i<numPlotTypes; i++)
    {
        tPlotInfo* pinfo = &plotInfoArray[i];
        BOOL plotEnabled = pinfo->enabledDefault;
        int lineStyle = pinfo->lineStyleDefault;
        float opacity = pinfo->opacityDefault;

        NSString* s = pinfo->defaultsKey;

        NSMutableString* key = [NSMutableString stringWithString:s];
        [key appendString:@"Opacity"];
        float defaultsOpac = [Utils floatFromDefaults:key];
        // if opacity is found, then assume other keys are present...
        if (defaultsOpac > 0.0)
        {
            opacity = defaultsOpac;

            key = [NSMutableString stringWithString:s];
            [key appendString:@"Enabled"];
            plotEnabled = [Utils boolFromDefaults:key];

            key = [NSMutableString stringWithString:s];
            [key appendString:@"LineStyle"];
            lineStyle = [Utils intFromDefaults:key];
        }
        else
        {
            [Utils setFloatDefault:opacity
                            forKey:key];

            key = [NSMutableString stringWithString:s];
            [key appendString:@"Enabled"];
            [Utils setBoolDefault:plotEnabled
                           forKey:key];

            key = [NSMutableString stringWithString:s];
            [key appendString:@"LineStyle"];
            [Utils setIntDefault:lineStyle
                          forKey:key];
        }


        PlotAttributes* pa = [[PlotAttributes alloc] initWithAttributes:[NSString stringWithFormat:@"%s", pinfo->name]
                                                            defaultsKey:pinfo->defaultsKey
                                                                  color:[Utils colorFromDefaults:[Utils defaultColorKey:pinfo->colorTag]]
                                                                opacity:opacity
                                                              lineStyle:lineStyle
                                                             enabled:plotEnabled
                                                            fillEnabled:pinfo->fillEnabledDefault
                                                               showLaps:pinfo->showLapsDefault
                                                            showMarkers:pinfo->showMarkersDefault
                                                              showPeaks:pinfo->showPeaksDefault
                                                               numPeaks:pinfo->numPeaksDefault
                                                          peakThreshold:pinfo->peakThresholdDefault
                                                            averageType:pinfo->averageType
                                                              isAverage:pinfo->isAverage];


        [plotAttributesArray replaceObjectAtIndex:pinfo->type withObject:pa];
        [pa autorelease];

    }
}


- (void)awakeFromNib
{
   [self updateAnimation:[[AnimTimer defaultInstance] animTime] reverse:NO];
   lastBounds.origin = NSZeroPoint;
   lastBounds.size.width = 0.0;
   lastBounds.size.height = 0.0;
}


- (NSArray*) ptsForPlot
{
	if (lap != nil)
	{
		return [track lapPoints:lap];
	}
	else
	{
		return [track goodPoints];
	}
}


- (BOOL)acceptsFirstResponder
{
   return YES;
}


- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}


- (BOOL)resignFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}



- (BOOL)needsPanelToBecomeKey
{
   return YES;
}


- (int)numPlotTypes
{
   return sizeof(plotInfoArray)/sizeof(tPlotInfo);
}


- (int)plotType:(int)idx
{
   return plotInfoArray[idx].type;
}

- (NSPoint)plotControlPosition:(int)idx
{
   return plotInfoArray[idx].pos;
}

- (void)setPlotEnabled:(tPlotType)type enabled:(BOOL)enabled updateDefaults:(BOOL)upd
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
   [pa setEnabled:enabled];
   [self setNeedsDisplay:YES];
   NSMutableString* key = [NSMutableString stringWithString:[pa defaultsKey]];
   [key appendString:@"Enabled"];
   if (upd) [Utils setBoolDefault:enabled
						   forKey:key];
   lastTrack = nil;     // force update
}

- (BOOL)plotEnabled:(tPlotType)type
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
   return [pa enabled];
}


- (void)setPlotColor:(tPlotType)type color:(NSColor*) color
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
   [pa setColor:color];
   [self setNeedsDisplay:YES];
}

- (NSColor*)plotColor:(tPlotType)type
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
    NSColor* color = pa.color;
    return color;
}


- (void)setPlotOpacity:(tPlotType)type opacity:(float) opac
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
   [pa setOpacity:opac];
   [self setNeedsDisplay:YES];
   NSMutableString* key = [NSMutableString stringWithString:[pa defaultsKey]];
   [key appendString:@"Opacity"];
   [Utils setFloatDefault:opac
                   forKey:key];
}


- (float)plotOpacity:(tPlotType)type;
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:type];
   return [pa opacity];
}


- (NSMutableArray*)plotAttributesArray
{
   return plotAttributesArray;
}

- (void) setShowHeartrateZones:(BOOL)on
{
   showHRZones = on;
   [self setNeedsDisplay:YES];
}


- (BOOL) showHeartrateZones
{
   return showHRZones;
}


- (void) setShowVerticalTicks:(BOOL)show
{
	showVerticalTicks = show;
	[self setNeedsDisplay:YES];
}


- (void) setPeakType:(int)type
{
   peakType = type;
}

- (int) peakType
{
   return peakType;
}


- (void) setShowPeaks:(BOOL)sp
{
   showPeaks = sp;
}


- (BOOL) showPeaks
{
   return showPeaks;
}


- (void) setNumPeaks:(int)np
{
   numPeaks = np;
}

- (void) setNumAvgPoints:(int)np
{
   numAvgPoints = np;
}


- (int) numAvgPoints
{
   return numAvgPoints;
}


- (int) numPeaks
{
   return numPeaks;
}


- (void) setPeakThreshold:(int)pt
{
   peakThreshold = pt;
}


- (int) peakThreshold
{
   return peakThreshold;
}

- (void) setShowPace:(BOOL)show
{ 
   [Utils setBoolDefault:show forKey:RCBDefaultDisplayPace];
   lastTrack = nil; // force update
   showPace = show;
}


- (BOOL) showPace
{
   return showPace;
}



- (void) setShowLaps:(BOOL)sl
{
   showLaps = sl;
}

- (BOOL) showLaps
{
   return showLaps;
}

- (void) setShowMarkers:(BOOL)sm
{
   showMarkers = sm;
}


- (BOOL) showMarkers
{
   return showMarkers;
}

- (void) setShowPowerPeakIntervals:(BOOL)spp
{
	showPowerPeakIntervals = spp;
}


- (BOOL) showPowerPeakIntervals
{
	return showPowerPeakIntervals;
}



- (void) setDataRectType:(int)type
{
   dataRectType = type;
}


- (int) dataRectType
{
   return dataRectType;
}


- (void) setShowCrossHairs:(BOOL)show
{
   showCrossHairs = show;
   [transparentView setShowCrossHairs:show];
}


- (BOOL) showCrossHairs
{
   return showCrossHairs;
}

-(void) setZonesOpacity:(float)v
{
   zonesOpacity = v;
   [self setNeedsDisplay:YES];
}


-(void)setTopAreaHeight:(float)th
{
	topAreaHeight = th;
	[self setNeedsDisplay:YES];
}

- (int) currentPointIndex
{
   return currentTrackPos;
}



- (float) getAverage:(NSArray*)pts idx:(int)idx ysel:(tAccessor)ysel illegalVal:(float)iv
{
	float retv;
	int numLeft = numAvgPoints;
	int i = idx - (numAvgPoints/2);
    NSUInteger count = [pts count];
	int numToSum = 0;
	float sum = 0.0;
	while ((numLeft > 0) && (i<count))
	{
		if (i >= 0)
		{
			float v = ysel([pts objectAtIndex:i], nil);
			if (v != iv)
			{
				--numLeft;
				sum += v;
				++numToSum;
			}
		}
		++i;
	}
	if (numToSum > 0)
		retv = sum/(float)numToSum;
	else
		retv = 0.0;
	return retv;
}


-(float)calcXPointForPlot:(TrackPoint*)pt leftX:(float)leftX xmax:(float)xmax xmin:(float)xmin width:(float)w startTimeDelta:(float)std
{
	float x;
	if (xAxisIsTime)
	{
		if ((xmax - xmin) > 0.0) 
		{
			NSTimeInterval t = [pt DATE_METHOD] - std;
			x = leftX + (w*t/(xmax - xmin));
		}
		else
			x = leftX;
	}
	else
	{
		if ((xmax - xmin) == 0)
		{
			x = leftX;
		}
		else
		{
			float dist = [pt distance] - mindist;
			x = leftX + ((w*dist)/(xmax-xmin));
		}
	}
	return x;
}


-(float)calcYPointForPlot:(TrackPoint*)pt bottomY:(float)bottomY ymax:(float)ymax ymin:(float)ymin height:(float)h ycur:(float)ycur
{
	float y;
	float ydiff = ymax-ymin;
	if (ydiff != 0)
	{
		if (ycur > ymax) ycur = ymax;
		y = bottomY + ((ycur - ymin) * h)/ydiff;
	}
	else
	{
		y = bottomY;
	}
	return y;
}


- (NSBezierPath*)plotPathFromPoints:(NSArray*)pts 
                             bounds:(NSRect)bounds 
                               ysel:(tAccessor)ysel 
                          lineWidth:(float)lineWidth
                               ymin:(float)ymin ymax:(float)ymax
                               xmin:(float)xmin xmax:(float)xmax
                          doAverage:(BOOL)doAverage
                       illegalValue:(float)iv
                    drawImmediately:(BOOL)immed 

{
	prevPt.x = -1;
	float w = bounds.size.width;
	float h = bounds.size.height;
	float x = bounds.origin.x;
	float y = bounds.origin.y;
    NSUInteger numPts = [pts count];
	NSBezierPath* bezpath = [[NSBezierPath alloc] init];
	if ((numPts > 0) /*&& (xmax > 0.0)*/)
	{
		if (!immed)
		{
			[bezpath setLineWidth:lineWidth];
			[bezpath setLineJoinStyle:NSLineJoinStyleRound];
		} 
#if 0
		TrackPoint* pt = [pts objectAtIndex:0];
		p.x = [self calcXPointForPlot:pt
								leftX:x
								 xmax:xmax
								 xmin:xmin
								width:w];
		///float ycur = ysel(pt, nil);
		float ycur;
		p.y = y;
		if (!immed) [bezpath moveToPoint:p];
#endif
		float ycur;
		BOOL first = YES;
		int i = 0;
		NSPoint p;
		TrackPoint* pt = [pts objectAtIndex:0];
		NSTimeInterval std = [pt DATE_METHOD];
		while (i<numPts)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			
			float newy = ysel(pt, nil);
            ycur = newy;
			if (ycur > ymax) ycur = ymax;
			if (newy == iv) 
			{
				++i;
				continue;
			}
			if (doAverage == YES) 
			{
				ycur = [self getAverage:pts
									idx:i
								   ysel:ysel
							 illegalVal:iv];
			}
			else
			{
				ycur = newy;
				// find the max value at this distance.  The GPS seems to provide many points at exactly the same distance. 
				// we *could* take the average of them...but for new we display the max.
			}
			p.x = [self calcXPointForPlot:pt
									leftX:x
									 xmax:xmax
									 xmin:xmin
									width:w
						   startTimeDelta:std];
			p.y = [self calcYPointForPlot:pt
								  bottomY:y
									 ymax:ymax
									 ymin:ymin
								   height:h
									 ycur:ycur];
			if ((p.x >= x) && (p.x <= (x + w)))
			{
				if (immed)
				{
					if (!first)
					{
						[NSBezierPath strokeLineFromPoint:prevPt 
												  toPoint:p];
					}
					first = NO;
					prevPt = p;
				}
				else
				{
					if (first)
					{
						float ysave = p.y;
						p.y = y;
						[bezpath moveToPoint:p];
						p.y = ysave;
						first = NO;
					}
					[bezpath lineToPoint:p];
				}
			}
			++i;
		}
	}
	return bezpath;
}


- (int) getNumPlots
{ 
   int i;
   int count = 0;
    NSUInteger numPlotTypes = [plotAttributesArray count];
   for (i = 0; i<numPlotTypes; i++)
   {
      PlotAttributes* attrs = [plotAttributesArray objectAtIndex:i];
      if (![attrs isAverage])
      {
         int avgType = [attrs averageType];
         if ([attrs enabled]) 
         {
            ++count;
         }
         else if (avgType != kReserved)
         {
            attrs = [plotAttributesArray objectAtIndex:avgType];
            if ([attrs enabled]) ++count;
         }
      }
   }
   return count;
}


#define VERT_RULER_HORIZ_SPACING    32

struct tPosInfo
{
   int axis;
   float offset;
} ;


- (struct tPosInfo) getPosInfo:(int)idx
                     markerPad:(float)mpad
{
   int numPlots = [self getNumPlots];
   struct tPosInfo info;
   switch (idx)
   {
      case 0:
      default:
         info.axis = kVerticalLeft;
         info.offset = ((numPlots % 2) == 0) ? VERT_RULER_HORIZ_SPACING*(numPlots)/2 : VERT_RULER_HORIZ_SPACING*(int)((numPlots+2)/2);
         break;

      case 1:
         info.axis = kVerticalRight;
         info.offset = (VERT_RULER_HORIZ_SPACING*(int)((numPlots)/2)) + mpad;
         break;
         
      case 2:
         info.axis = kVerticalLeft;
         info.offset = ((numPlots % 2) == 0) ? VERT_RULER_HORIZ_SPACING*(int)((numPlots-2)/2) : VERT_RULER_HORIZ_SPACING*(int)((numPlots)/2);
         break;
         
      case 3:
         info.axis = kVerticalRight;
         info.offset = (VERT_RULER_HORIZ_SPACING* (int)((numPlots-2)/2)) + mpad;
         break;

      case 4:
         info.axis = kVerticalLeft;
         info.offset = ((numPlots % 2) == 0) ? VERT_RULER_HORIZ_SPACING*(int)((numPlots-4)/2) : VERT_RULER_HORIZ_SPACING*(int)((numPlots-2)/2);
         break;
         
      case 5:
         info.axis = kVerticalRight;
         info.offset = (VERT_RULER_HORIZ_SPACING* (int)((numPlots-4)/2)) + mpad;
         break;
   }
   return info;
}


// return horiz padding required to fit the legend text under the vertical axes
-(float) getXPad
{
	if (dragStart) return 0.0;	// don't bother when using in Compare Window
	return showPace ? 5.0 : 2.0;
}


- (NSRect) getPlotBounds:(BOOL)includePad
{
	int numPlots = [self getNumPlots];
	float xLeftInset = 0;
	float xRightInset = 0;
	float mpad = (includePad && showMarkers) ? [self markerRightPad] : 0.0;
	if (showVerticalTicks && (numPlots > 0))
	{
		struct tPosInfo info = [self getPosInfo:0
									  markerPad:0.0];
		xLeftInset = info.offset;
		info = [self getPosInfo:1
					  markerPad:mpad];
		xRightInset = info.offset;
	}
	NSRect plotBounds = NSInsetRect([self drawBounds], [self getXPad], vertPlotYOffset);
	plotBounds.origin.x += (xLeftInset);
	plotBounds.size.width -= (xRightInset + xLeftInset);
	plotBounds.size.height -= topAreaHeight;
	return plotBounds;
}


#define MARKER_PAD       120.0

- (float) markerRightPad
{
   if (markerRightPadding < 0.0)
   {
      markerRightPadding = 0.0;
      NSMutableArray* markers = [track markers];
      if (markers != nil)
      {
         NSRect drawBounds = [self drawBounds];
         NSRect plotBounds = [self getPlotBounds:NO];
         NSArray* pts = [self ptsForPlot];
          NSUInteger npts = [pts count];
         if (npts > 0)
         {
            PathMarker* pm = [markers lastObject];
            float markerDist = [pm distance];
            float startDistance = [[pts objectAtIndex:0] distance];
            float endDistance = [[pts lastObject] distance];
            if (IS_BETWEEN(startDistance, markerDist, endDistance))
            {
               float markerPadPixels = MARKER_PAD - ((drawBounds.size.width - plotBounds.size.width)/2.0);
               float maxMarkerLoc = plotBounds.size.width - markerPadPixels;
               if (markerPadPixels > 0.0)
               {
                  if (xAxisIsTime)
                  {
                     //NSDate* startDate = [[pts objectAtIndex:0] activeTime];
                     //NSDate* endDate = [[pts lastObject] activeTime];
                     NSTimeInterval startTimeDelta = [[pts objectAtIndex:0] activeTimeDelta];
					 NSTimeInterval endTimeDelta = [[pts lastObject] activeTimeDelta];
                     TrackPoint* tpt = [track closestPointToDistance:markerDist];
                     if (tpt != nil)
                     {
                        //NSTimeInterval totalTime = [endDate timeIntervalSinceDate:startDate];
						 NSTimeInterval totalTime = endTimeDelta - startTimeDelta;
                        float timePerPixel = totalTime/plotBounds.size.width;
                        if (timePerPixel > 0.0)
                        {
                           //NSDate* markerDate = [tpt activeTime];
                           //float lastMarkerLoc = [markerDate timeIntervalSinceDate:startDate]/timePerPixel;
                           float lastMarkerLoc = ([tpt activeTimeDelta] - startTimeDelta)/timePerPixel;
                           float pad = lastMarkerLoc - maxMarkerLoc;
                           if (pad > 0.0) markerRightPadding = pad;
                        }
                     }
                  }
                  else
                  {
                     float distPerPixel = (endDistance - startDistance)/plotBounds.size.width;
                     if (distPerPixel > 0.0)
                     {
                        float lastMarkerLoc = (markerDist - startDistance)/distPerPixel;
                        float pad = lastMarkerLoc - maxMarkerLoc;
                        if (pad > 0.0) markerRightPadding = pad;
                     }
                  }
               }
            }
         }
      }
   }
   return markerRightPadding;
}




- (NSPoint) findPointOnPathAtOrGreaterThanDistanceOrTimeDelta:(float)distanceOrTime path:(NSBezierPath*)path
{
   NSPoint p = NSZeroPoint;
   NSRect bounds = [self getPlotBounds:YES];
   int x = 0.0;
   if (xAxisIsTime)
   {
      float dur = maxDurationForPlotting;
      if (dur > 0.0) x = bounds.origin.x + ((bounds.size.width*distanceOrTime)/dur);
      else x = 0.0;
   }
   else
   {
      if (maxdist > mindist)
      {
         x = bounds.origin.x + ((bounds.size.width*distanceOrTime)/(maxdist-mindist));
      }
   }
    NSInteger numElems = [path elementCount];
   int i;
   for (i=0; i<numElems; i++)
   {
      NSBezierPathElement ele = [path elementAtIndex:i associatedPoints:&p];
      if (ele == NSBezierPathElementLineTo)
      {
         if (p.x >= x) break;
      }
   }
   return p;
}

- (NSPoint) findNearestPointToWallClockDelta:(NSTimeInterval)delta path:(NSBezierPath*)path
{
	NSArray* pts = [self ptsForPlot];
    NSUInteger num = [pts count];
	int i = 0;
	TrackPoint* pt = nil;
	for (i=0; i<num; i++)
	{
		pt = [pts objectAtIndex:i];
		//NSComparisonResult res = [[pt date] compare:theTime];
		//if ((res == NSOrderedDescending) || (res == NSOrderedSame))
		if ([pt wallClockDelta] >= delta)
		{
			break;
		}
	}
	NSPoint p = NSZeroPoint;
	if (pt != nil)
	{
		float val;
		if (xAxisIsTime)
		{
			//val = [[pt DATE_METHOD] timeIntervalSinceDate:[track creationTime]];
			val = [pt DATE_METHOD];
		}
		else
		{
			val = [pt distance] - mindist;
		}
		p = [self findPointOnPathAtOrGreaterThanDistanceOrTimeDelta:val path:path];
	}
	return p;
}

   


- (void)drawStringAtAngle:(NSString*)s angle:(float)angle atPoint:(NSPoint)pt attrs:(NSMutableDictionary*)attr
{
   
   NSAffineTransform *transform = [NSAffineTransform transform];
   NSGraphicsContext *context = [NSGraphicsContext currentContext];
   [context saveGraphicsState];
   
   [transform translateXBy:pt.x yBy:pt.y];
   [transform rotateByDegrees:angle];
   [transform concat];
   
   [(NSString *)[NSString stringWithString:s] drawAtPoint:NSMakePoint(0,0) 
                                           withAttributes:attr];
   [context restoreGraphicsState];
}


- (void)drawMarkers:(NSBezierPath*)altitudePath
{
	//if (!xAxisIsTime)
	{
		NSRect bounds = [self drawBounds];
		float y = bounds.size.height - ACTIVITY_VIEW_TOP_AREA_HEIGHT;
		NSFont* font = [NSFont systemFontOfSize:12];
		NSMutableDictionary *attr = [NSMutableDictionary dictionary];
		[attr setObject:font forKey:NSFontAttributeName];

		NSRect dbounds = bounds;
		dbounds.origin.y = y;
		dbounds.size.height = ACTIVITY_VIEW_TOP_AREA_HEIGHT - HEADER_HEIGHT;
		NSBezierPath* cp = [NSBezierPath bezierPathWithRect:dbounds];

		NSMutableArray* markers = [track markers];
		if (markers != nil)
		{
            NSUInteger num = [markers count];
			int i;
			float startDistance = 0.0;
			float endDistance = 0.0;
			//NSDate* startDate = nil;
			NSTimeInterval startTimeDelta = 0.0;
			NSArray* pts = [self ptsForPlot];
            NSUInteger npts = [pts count];
			if (npts > 0)
			{
				startDistance = [[pts objectAtIndex:0] distance];
				endDistance = [[pts objectAtIndex:npts-1] distance];
				//startDate = [[pts objectAtIndex:0] activeTime];
				startTimeDelta = [[pts objectAtIndex:0] activeTimeDelta];
			}
			for (i=0; i<num; i++)
			{
				PathMarker* pm = [markers objectAtIndex:i];
				float markerDist = [pm distance];
				BOOL haveGoodPoint = NO;
				if (IS_BETWEEN(startDistance, markerDist, endDistance))
				{
					NSPoint pt = NSZeroPoint;
					if (xAxisIsTime)
					{
						TrackPoint* tpt = [track closestPointToDistance:markerDist];
						//if ((tpt != nil) && (startDate != nil))
						if (tpt)
						{
							//pt = [self findPointOnPathAtOrGreaterThanDistanceOrTimeDelta:[[tpt activeTime] timeIntervalSinceDate:startDate]
							//															path:altitudePath];
							pt = [self findPointOnPathAtOrGreaterThanDistanceOrTimeDelta:[tpt activeTimeDelta] - startTimeDelta
																					path:altitudePath];
							haveGoodPoint = YES;
						}
					}
					else
					{
						pt = [self findPointOnPathAtOrGreaterThanDistanceOrTimeDelta:(markerDist - startDistance)
																				path:altitudePath];
						haveGoodPoint = YES;
					}
					if (haveGoodPoint)
					{
						[NSGraphicsContext saveGraphicsState];
						[cp setClip];
						[self drawStringAtAngle:[pm name]
										  angle:45
										atPoint:NSMakePoint(pt.x+10,y)
										  attrs:attr];
						[NSGraphicsContext restoreGraphicsState];
						[[NSColor colorNamed:@"TextPrimary"] set];
						NSPoint topOLine = NSMakePoint(pt.x, y-2);
						[NSBezierPath strokeLineFromPoint:pt toPoint:topOLine];
						[NSBezierPath strokeLineFromPoint:topOLine toPoint:NSMakePoint(pt.x + 5, y-2+5)];
					}
				}
			}
		}
   }
}


-(NSPoint)putImage:(NSImage*)img atWallTime:(float)wt usingPath:(NSBezierPath*)path
{
	NSPoint p = [self findNearestPointToWallClockDelta:wt path:path];
	NSRect r, imageRect;
	imageRect.origin = NSZeroPoint;
	imageRect.size = [img size];
	r.size = imageRect.size;
	r.origin.x = (int)(p.x - (r.size.width)/2.0) + 2;
	r.origin.y = (int)p.y - 4;
	
	[img drawAtPoint:r.origin
			fromRect:NSZeroRect
		   operation:NSCompositingOperationSourceOver
			fraction:1.0];
	return p;
}


- (void)drawLaps:(NSBezierPath*)altitudePath
{
	NSFont* font = [NSFont boldSystemFontOfSize:8];
	NSMutableDictionary *fontAttrs = [NSMutableDictionary dictionary];
	[fontAttrs setObject:font forKey:NSFontAttributeName];
	NSMutableArray* laps = [track laps];
    int numLaps = (int)[laps count];
	int i;
	// don't show first or last lap end marker
	for (i=numLaps-2; i>=0; i--)
	{
		Lap* lp = [laps objectAtIndex:i];
		float lapEndTime = [lp startingWallClockTimeDelta] + [track durationOfLap:lp];
		NSTimeInterval lapEndMovingTime = [track lapActiveTimeDelta:lp] + [track movingDurationOfLap:lp];
		
		if ((IS_BETWEEN(track.animTimeBegin, lapEndMovingTime, track.animTimeEnd)))
		{
			NSPoint p = [self putImage:lapMarkerImage
							atWallTime:lapEndTime
							 usingPath:altitudePath];
			
			NSRect r, imageRect;
			imageRect.origin = NSZeroPoint;
			imageRect.size = [lapMarkerImage size];
			r.size = imageRect.size;
			r.origin.x = (int)(p.x - (r.size.width)/2.0) + 2;
			r.origin.y = (int)p.y - 4;
//			[lapMarkerImage drawAtPoint:r.origin
//							 fromRect:NSZeroRect
//							operation:NSCompositingOperationSourceOver
//							 fraction:1.0];
			NSString* s = [NSString stringWithFormat:@"%d", i+1];
			NSSize size = [s sizeWithAttributes:fontAttrs];
			float lxoff = ((r.size.width - size.width)/2.0)-1;
			float lyoff = 11.0;
			[fontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
			[s drawAtPoint:NSMakePoint((int)(r.origin.x + lxoff), (int)(r.origin.y + lyoff + 1.0)) withAttributes:fontAttrs];
		}
	}
#if 0
	[self putImage:startMarkerImage
		atWallTime:0
		 usingPath:altitudePath];
	
	float endTime = [track durationAsFloat];
	[self putImage:finishMarkerImage
		atWallTime:endTime
		 usingPath:altitudePath];
#endif
}


- (void)drawHRZones:(int)mxhr
{
	NSRect plotBounds = [self getPlotBounds:YES];
	float scalerY = 1.0;
    float mn = 0.0;
    float mx = 0.0;
	float zn = 0.0;
	NSRect zoneBounds;
	int znType = [Utils intFromDefaults:RCBDefaultZoneInActivityDetailViewItem];
	BOOL rev = NO;
	if (znType == kUseHRZColorsForPath)
	{
		mn = minhrGR;
		mx  = maxhrGR; 
	}
	else if (znType == kUseSpeedZonesForPath)
	{
		mn = 0;
		mx = maxspGR; 
	}
	else if (znType == kUsePaceZonesForPath)
	{
		rev = YES;
		mn = 0;
		mx = maxspGR; 
	}
	else if (znType == kUseGradientZonesForPath)
	{
		mn  = mingrGR;
		mx  = maxgrGR; 
	}
	else if (znType == kUseCadenceZonesForPath)
	{
		mn = mincdGR;
		mx  = maxcdGR; 
	}
	else if (znType == kUsePowerZonesForPath)
	{
		mn = 0;
		mx  = maxpwrGR; 
	}
	else if (znType == kUseAltitudeZonesForPath)
	{
		mn = minalt;
		mx  = maxalt; 
	}
	if ((mx - mn) > 0)
	{
		scalerY= plotBounds.size.height/(mx-mn);
	}

	int curZone;
	if (rev == NO)
	{
		for (curZone = 4; curZone >= 0; curZone--)     // everything *except* pace, draw top to bottom, skip below zone, looks bad
		{
		 zn = [Utils thresholdForZoneUsingZone:znType
										  zone:curZone];
		 zoneBounds.size.height = (mx-zn)*scalerY;
		 zoneBounds.origin.y = plotBounds.origin.y + (zn-mn)*scalerY;
		 zoneBounds.size.width = plotBounds.size.width-2;
		 zoneBounds.origin.x = plotBounds.origin.x+1;
		 NSColor* clr = [Utils colorForZoneUsingZone:znType 
												zone:curZone];
		 [[clr colorWithAlphaComponent:zonesOpacity] set];
		 [NSBezierPath fillRect:zoneBounds];

		 mx = zn;
		}
	}
	else
	{
		for (curZone =  0; curZone < 5; curZone++)     // draw top to bottom, don't draw "above zone 5", looks bad
		{
			if (curZone == 0)
			{
				mx = [Utils thresholdForZoneUsingZone:znType
												 zone:curZone];
			}
			if (curZone == 4)
			{
				zoneBounds.size.height = (mx)*scalerY;
				zoneBounds.origin.y = plotBounds.origin.y + (0-mn)*scalerY;
			}
			else
			{
				zn = [Utils thresholdForZoneUsingZone:znType
												 zone:curZone+1];
				zoneBounds.size.height = (mx-zn)*scalerY;
				zoneBounds.origin.y = plotBounds.origin.y + (zn-mn)*scalerY;
			}
			zoneBounds.size.width = plotBounds.size.width-2;
			zoneBounds.origin.x = plotBounds.origin.x+1;
			NSColor* clr = [Utils colorForZoneUsingZone:znType 
												   zone:curZone];
			[[clr colorWithAlphaComponent:zonesOpacity] set];
			[NSBezierPath fillRect:zoneBounds];

			mx = zn;
		}
	}
}


// @@FIXME@@ this doesn't really work -- need to figure out how to find localized peaks
// returns the index within the 'n' peaks that this value is greater than, -1 if none
int checkMax(float* arr, float val, int num)
{
   int idx = -1;
   int i;
   float min = 9999999.0;
   for (i=0; i<num; i++)
   {
      if (arr[i] < min)
      {
         min = arr[i];
         idx = i;
      }
   }
   if ((idx != -1) && (val > min))
   {
      return idx;
   }
   return -1;
}


BOOL mightBeAMax(NSArray* pts, int num, int idx, int thresh, tAccessor ysel)
{
   BOOL answer = YES;
   int lastToCheck = idx + thresh + 1;
   if (lastToCheck >= num)
   {
      lastToCheck = num-1;
   }
   float val = ysel([pts objectAtIndex:idx],nil);
   int i;
   // look ahead, see if any within threshold going forwads are greater
   for (i = idx+1; i<lastToCheck; i++)
   {
      if (ysel([pts objectAtIndex:i], nil) > val)
      {
         return NO;
      }
   }
   // look behind, do the same check
   lastToCheck = idx - (1 + thresh);
   if (lastToCheck<0) lastToCheck = 0;
   for (i = idx-1; i>=lastToCheck; --i)
   {
      if (ysel([pts objectAtIndex:i],nil) >= val)
      {
         return NO;
      }
   }
   return answer;
}


-(float)getAltitude:(int)startingGoodIdx
{
	float alt = 0.0;
	NSArray* pts = [self ptsForPlot];
    NSUInteger num = [pts count];
	if (startingGoodIdx < num)
	{
		for (int i=startingGoodIdx; i<num; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			if ([pt validAltitude])
			{
				//alt = [pt altitude];
				alt = [pt altitude];
				break;
			}
		}
	}
	return alt;
}



- (void)drawPeaks:(NSBezierPath*)altitudePath type:(int)ptype numPeaks:(int)n threshold:(int)thresh  ysel:(tAccessor)ysel colorKey:(NSString*)colorKey format:(NSString*)fm
{
	NSArray* pts = [self ptsForPlot];
	int num = (int)[pts count];
	float maxValues[n];
	int   maxIndices[n];
	int i;
	for (i=0; i<n; i++) 
	{  
		maxValues[i] = -9999999.0;
		maxIndices[i] = -1;
	}
	for (i=0; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if (((ptype == kAltitude) && ![pt validAltitude]) ||
            ((ptype == kSpeed) && ![pt validDistance]))
		{
			continue;
		}
		else
		{
			BOOL couldBe = mightBeAMax(pts, num, i, thresh, ysel);
			if (couldBe)
			{
				float val = ysel(pt, nil);
				int maxIndex;
				if ((maxIndex = checkMax(maxValues, val, n)) != -1)
				{
					// this point is one of the 'n' max's, so store it's value and index
					maxValues[maxIndex] = val;
					maxIndices[maxIndex] = i;
				}
			}
		}
	} 
   
	//NSDate* startTime = [[pts objectAtIndex:0] DATE_METHOD];
	NSTimeInterval startTimeDelta = [[pts objectAtIndex:0] DATE_METHOD];
    // always show black; drawing on top of white peak icon
    NSColor* textColor = [NSColor blackColor];
	[tickFontAttrs setObject:textColor forKey:NSForegroundColorAttributeName];
   
	for (i=0; i<n; i++)
	{
		int pointIndex = maxIndices[i];
		if (pointIndex >= 0)
		{
			TrackPoint* pt = [pts objectAtIndex:pointIndex];
			NSPoint p;
			NSRect plotBounds = [self getPlotBounds:YES];
         
			if (xAxisIsTime)
			{
				//NSTimeInterval t = [[pt DATE_METHOD] timeIntervalSinceDate:startTime];
				NSTimeInterval t = [pt DATE_METHOD] - startTimeDelta;
				float dur = maxDurationForPlotting;
				if (dur)
					p.x = plotBounds.origin.x + ((plotBounds.size.width*t)/(dur)) - 20;
				else
					p.x = plotBounds.origin.x - 20;
			}
			else
			{
				float dist = [pt distance] - mindist;
				if (maxdist > mindist)
				{
					p.x = plotBounds.origin.x + ((plotBounds.size.width*dist)/(maxdist-mindist)) - 20;
				}
				else
				{
					p.x = plotBounds.origin.x - 20;
				}
			}
			p.y = plotBounds.origin.y + ((([pt altitude] - minalt) * plotBounds.size.height)/(maxalt-minalt)) - 1;
			NSRect imageRect;
			imageRect.origin = NSZeroPoint;
			imageRect.size = [altSignImage size];
			[peakImage drawAtPoint:p
						  fromRect:NSZeroRect
						 operation:NSCompositingOperationSourceOver
						  fraction:1.0];
			float val = maxValues[i];
			switch (ptype)
			{
				default:
					break;
				case kAltitude:
					val = [Utils convertClimbValue:val];
					break;
				case kSpeed:
					val = [Utils convertSpeedValue:val];
					break;
			}
			NSString* s;
			if (showPace && ptype == kSpeed)
			{
				if (val > 1.0)
				{
					val = 3600.0/val;
					s = [NSString stringWithFormat:@"%02.2d:%02.2d", ((int)val) / 60 , ((int)val) % 60];
				}
				else
				{
					s = [NSString stringWithFormat:@"--:--"];
				}
			}
			else
			{
				s = [NSString stringWithFormat:fm, val];
			}
			NSSize size = [s sizeWithAttributes:tickFontAttrs];
			float xoff = (40 - size.width)/2.0;
			float yoff = (15 - size.height)/2.0;
			[s drawAtPoint:NSMakePoint((int)(p.x + xoff), (int)(p.y + 11 + yoff + 1.0)) withAttributes:tickFontAttrs];
		}
	}
}


- (void) setDefaultLineAttributes:(tPlotType)type
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:(int)type];
   int v = [pa lineStyle];
   switch (v)
   {
      default:
      case 0:
      {
         [NSBezierPath setDefaultLineWidth:1.0];
         break;
      }
      case 1:
      {
         [NSBezierPath setDefaultLineWidth:2.0];
         break;
      }
         
      case 2:
      {
         [NSBezierPath setDefaultLineWidth:3.0];
         break;
      }
   }
}



- (void) setLineAttributes:(NSBezierPath*)path type:(tPlotType)type
{
   PlotAttributes* pa = [plotAttributesArray objectAtIndex:(int)type];
   int v = [pa lineStyle];
   switch (v)
   {
      default:
      case 0:
      {
         CGFloat arr[2];
         arr[0] =1.0; arr[1] = 0.0;
         [path setLineWidth:2.0];
         [path setLineDash:arr count:0 phase:0.0];
         break;
      }
      case 1:
      {
         CGFloat arr[2] = { 5.0, 2.0 };
         [path setLineWidth:2.0];
         [path setLineDash:arr count:2 phase:0.0];
         break;
      }
         
      case 2:
      {
         CGFloat arr[2] = { 1.0, 1.0 };
         [path setLineWidth:2.0];
         [path setLineDash:arr count:2 phase:0.0];
         break;
      }
   }
}
         

- (void)drawHeader:(NSRect)plotBounds
{
    NSRect bounds = [self drawBounds];

    // Resolve the text color from assets (fallback to dynamic system label color)
    NSColor *textColor = [NSColor colorNamed:@"TextPrimary"] ?: [NSColor labelColor];

    // Build the alternate start time (if the plot starts after creation time)
    NSDate *startTime = [track creationTime];
    NSArray *pts = [self ptsForPlot];
    if ([pts count] > 0) {
        NSTimeInterval firstDelta = [pts[0] activeTimeDelta];
        startTime = [startTime dateByAddingTimeInterval:firstDelta];
    }

    // Human-readable date/title for the activity header line
    NSString *dateTitle = [Utils activityNameFromDate:track alternateStartTime:startTime];

    // Shared attributes dict for text (we'll only mutate the font size)
    NSMutableDictionary *fontAttrs = [NSMutableDictionary dictionary];
    fontAttrs[NSForegroundColorAttributeName] = textColor;

    CGFloat x = 0.0;
    CGFloat y = bounds.size.height - 14.0;
    NSSize size;

    // ----- Title line (activity name + optional lap suffix) -----
    NSString *title = [track attribute:kName];
    if (title.length > 0) {
        NSMutableString *mutableTitle = [NSMutableString stringWithString:title];

        if (lap != nil) {
            NSInteger lapIdx = [track findLapIndex:lap];
            if (lapIdx == ([[track laps] count] - 1)) {
                [mutableTitle appendFormat:@" - End of Lap %ld to Finish", (long)lapIdx];
            } else {
                [mutableTitle appendFormat:@" - Lap %ld", (long)(lapIdx + 1)];
            }
        }

        fontAttrs[NSFontAttributeName] = [NSFont systemFontOfSize:15.0];
        size = [mutableTitle sizeWithAttributes:fontAttrs];
        x = bounds.origin.x + bounds.size.width/2.0 - size.width/2.0;
        [mutableTitle drawAtPoint:NSMakePoint(x, y) withAttributes:fontAttrs];
        y -= 18.0;
    }

    // ----- Subtitle line (activity type, duration, date, event type) -----
    fontAttrs[NSFontAttributeName] = [NSFont systemFontOfSize:13.0];

    NSString *activity = [track attribute:kActivity] ?: @"";
    NSString *durationPart = [NSString stringWithFormat:@" for %02.2d:%02.2d:%02.2d on ",
                              (int)(plotDuration/3600.0),
                              (int)(((int)plotDuration/60) % 60),
                              ((int)plotDuration) % 60];

    NSMutableString *subtitle = [NSMutableString stringWithFormat:@"%@%@%@", activity, durationPart, dateTitle];

    NSString *eventType = [track attribute:kEventType];
    if (eventType.length > 0) {
        [subtitle appendFormat:@" (%@)", eventType];
    }

    size = [subtitle sizeWithAttributes:fontAttrs];
    x = bounds.origin.x + bounds.size.width/2.0 - size.width/2.0;
    [subtitle drawAtPoint:NSMakePoint(x, y) withAttributes:fontAttrs];
    y -= 16.0;

    // ----- Stats line (distance, climb, speed, pace, optional avg power) -----
    BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
    NSString *format = useStatuteUnits
                       ? @"%@ miles, total climb: %@ft, average (moving) speed: %@mph, pace: %@ min/mile"
                       : @"%@km, total climb: %@m, average (moving) speed: %@km/h, pace: %@ min/km";

    float avgPower = [track avgPower];
    float avgSpd   = [track avgMovingSpeed];
    float dist     = [track distance];
    float climb    = [track totalClimb];

    if (lap != nil) {
        avgPower = [track avgPowerForLap:lap];
        avgSpd   = [track movingSpeedForLap:lap];
        dist     = [track distanceOfLap:lap];
        climb    = [track lapClimb:lap];
    }

    float pace = [track avgMovingPace];
    if (lap != nil && avgSpd > 0.0f) {
        // hours/mile * 60 = min/mile (Utils convertPaceValueToString: expects seconds or min? keep original behavior)
        pace = (60.0f * 60.0f) / avgSpd;
    }

    // numberFormatter is assumed to be an ivar as in your original code
    [numberFormatter setMaximumFractionDigits:0];

    if (avgPower > 0.0f) {
        NSString *powerString = [numberFormatter stringFromNumber:@(avgPower)];
        format = [NSString stringWithFormat:@"%@, average power: %@ watts", format, powerString];
    }

    NSString *climbString = [numberFormatter stringFromNumber:@([Utils convertClimbValue:climb])];

    [numberFormatter setMaximumFractionDigits:1];
    NSString *distString  = [numberFormatter stringFromNumber:@([Utils convertDistanceValue:dist])];
    NSString *speedString = [numberFormatter stringFromNumber:@([Utils convertSpeedValue:avgSpd])];

    NSString *stats = [NSString stringWithFormat:format,
                       distString,
                       climbString,
                       speedString,
                       [Utils convertPaceValueToString:pace]];

    size = [stats sizeWithAttributes:fontAttrs];
    x = bounds.origin.x + bounds.size.width/2.0 - size.width/2.0;
    [stats drawAtPoint:NSMakePoint(x, y) withAttributes:fontAttrs];
}


- (NSPoint) calcTransparentViewPos:(int)pi
{
	NSArray* pts = [self ptsForPlot];
	TrackPoint* tpt = [pts objectAtIndex:pi];
	NSRect bounds = [self getPlotBounds:YES];
	float w = bounds.size.width;
	float h = bounds.size.height;
	NSPoint pt;
    float offset = 0.0;        // 10.0?
	if (xAxisIsTime)
	{
		
		NSTimeInterval t = 0.0;
		if ([pts count] > 0)
			//t = [[tpt DATE_METHOD] timeIntervalSinceDate:[[pts objectAtIndex:0] DATE_METHOD]];
			t = [tpt DATE_METHOD] - [[pts objectAtIndex:0] DATE_METHOD];
		float dur = maxDurationForPlotting;
		if (dur > 0.0)
			pt.x = bounds.origin.x + ((t * w)/dur) - 10.0;
		else
			pt.x = bounds.origin.x - 10.0;
	}
	else
	 {
		if (maxdist > mindist)
		{
			pt.x = bounds.origin.x + ((([tpt distance]-mindist) * w)/(maxdist-mindist)) - offset;
		}
		else
		{
			pt.x = bounds.origin.x - offset;
		}
	}
	pt.y = bounds.origin.y;
	switch (dataRectType)
	{
		default:
		case kAltitude:
		{
			if ((maxalt-minalt) != 0.0)
				//pt.y = bounds.origin.y + ((([tpt altitude] - minalt) * h)/(maxalt-minalt));
				pt.y = bounds.origin.y + ((([self getAltitude:pi] - minalt) * h)/(maxalt-minalt));
			else
				pt.y = bounds.origin.y;
			break;
		}
		 
		case kHeartrate:
		{
			if (maxhrGR != 0.0)
				pt.y = bounds.origin.y + ((([tpt heartrate] - minhrGR) * h)/(maxhrGR-minhrGR));
			break;
		}
		 
		case kSpeed:
		{
			if (showPace)
			{
				float v = [tpt pace];
				if (v > SLOWEST_PACE) v = SLOWEST_PACE;
				if (maxspGR != 0.0)
					pt.y = bounds.origin.y + ((v * h)/(maxspGR));
			}
			else
			{
				if (maxspGR != 0.0)
					pt.y = bounds.origin.y + ((([tpt speed]) * h)/(maxspGR));
			}
			break;
		}
		 
		case kCadence:
		{
			if (maxcdGR != 0.0)
				pt.y = bounds.origin.y + ((([tpt cadence] - mincdGR) * h)/(maxcdGR-mincdGR));
			break;
		}
		 
		case kPower:
		{
			if (maxpwrGR != 0.0)
				pt.y = bounds.origin.y + ((([tpt power]) * h)/(maxpwrGR));
			break;
		}
			
		case kGradient:
		{
			if ((maxgrGR-mingrGR) != 0.0)
				pt.y = bounds.origin.y + ((([tpt gradient] - mingrGR) * h)/(maxgrGR-mingrGR));
			break;
		}
		   
		case kTemperature:
		{
			if ((maxtempGR-mintempGR) != 0.0)
				pt.y = bounds.origin.y + ((([tpt temperature] - mintempGR) * h)/(maxtempGR-mintempGR));
			break;
		}
	}
	pt.y -= offset;
	return pt;
}   


static NSPoint interpPoints(NSPoint p1, NSPoint p2, float ratio)
{
	NSPoint p;
	p.x = p1.x + (ratio*(p2.x - p1.x));
	p.y = p1.y + (ratio*(p2.y - p1.y));
	return p;
}

- (void) drawAnimatingParts:(int)gi animTime:(NSTimeInterval)animTime updateDisplay:(BOOL)doUpdate
{
	if (trackHasPoints)
	{
		NSArray* pts = [self ptsForPlot];
		TrackPoint* tpt = [pts objectAtIndex:gi];
		NSPoint p = [self calcTransparentViewPos:gi];
		TrackPoint* npt = nil;
		float ratio = 0.0;
		if (gi < ([pts count]-1))
		{
			NSPoint np = [self calcTransparentViewPos:gi+1];
			npt = [pts objectAtIndex:gi+1];
			float curTime = animTime + track.animTimeBegin;
			float thisTime = [tpt activeTimeDelta];
			float nextTime = [npt activeTimeDelta];
			if (thisTime != nextTime)
			{
				ratio = (curTime - thisTime)/(nextTime - thisTime);
				p = interpPoints(p, np, ratio);
			}
		}
		[transparentView update:p 
					 trackPoint:tpt
				 nextTrackPoint:npt
						  ratio:ratio
				   needsDisplay:doUpdate];
		if (doUpdate)
		{
			CGFloat alt = [self getAltitude:gi];
			[dataHudUpdateInvocation setArgument:&tpt
										 atIndex:2];
			[dataHudUpdateInvocation setArgument:&p.x 
										 atIndex:3];
			[dataHudUpdateInvocation setArgument:&p.y 
										 atIndex:4];
			[dataHudUpdateInvocation setArgument:&alt 
										 atIndex:5];
			[dataHudUpdateInvocation invoke];
		}
	}
}


#define RANGE_INDICATOR_WIDTH 10.0

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
	[[[self plotColor:(tPlotType)type] colorWithAlphaComponent:0.2] set];
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


-(void) drawTheTickMarks:(int)type bounds:(NSRect)vTickBounds max:(float)mxv min:(float)mnv axis:(int)axis numTicks:(int)nt offset:(float)offset legend:(NSString*)leg isTime:(BOOL)isTime
{
	[tickFontAttrs setObject:[[self plotColor:(tPlotType)type] colorWithAlphaComponent:1.0] forKey:NSForegroundColorAttributeName];
	DUDrawTickMarks(vTickBounds, axis, offset, mnv, mxv, nt, tickFontAttrs, isTime, 99999999999.0);
	NSSize sz = [leg sizeWithAttributes:tickFontAttrs];
	if (!dragStart)
	{
		if (kVerticalLeft == axis)
		{
			[leg drawAtPoint:NSMakePoint(vTickBounds.origin.x + offset - sz.width, vertTickBounds.origin.y - 12.0) withAttributes:tickFontAttrs];
		}
		else
		{
			[leg drawAtPoint:NSMakePoint(vTickBounds.origin.x + vertTickBounds.size.width - offset + 1.0, vertTickBounds.origin.y - 12.0) withAttributes:tickFontAttrs];
		}
	}
}

- (void) setXAxisIsTime:(BOOL)isTime
{
   xAxisIsTime = isTime;
   lastTrack = nil; // force update
}


- (BOOL) xAxisIsTime
{
   return xAxisIsTime;
}

- (void) resetPaths
{
	[altPath autorelease];
	altPath = nil;
	[dpath autorelease];
	dpath = nil;
	[hpath autorelease];
	hpath = nil;
	[spath autorelease];
	spath = nil;
}


- (void) markersChanged
{
   markerRightPadding = -1.0;
   [self setNeedsDisplay:YES];
}


-(int) drawHeartRate:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	float incr;
	int numVertTickPoints;
	BOOL zonesDrawn = NO;
	maxhr = [[pts valueForKeyPath:@"@max.heartrate"] floatValue];
	float minhr;
#if 0
	if (lap == nil)
	{
		minhr = [track minHeartrate:nil];
	}
	else
	{
		minhr = [track minHeartrateForLap:lap
						atActiveTimeDelta:nil];
	}
#else
    // looks better to keep range the same throught the track (4/17/2011)
    minhr = [track minHeartrate:nil];
#endif
	[hpath autorelease];
	hpath = nil;
	if ([[plotAttributesArray objectAtIndex:kHeartrate] enabled])
	{
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgHeartrate] enabled] == NO) ++posidx;
		minhrGR = (float)(((int)((int)minhr)/10) * 10);
		numVertTickPoints = AdjustRuler(maxVertTicks, minhrGR, maxhr, &incr);
		maxhrGR = minhrGR + (numVertTickPoints*incr);
		if (showHRZones && (znType == kUseHRZColorsForPath)) [self drawHRZones:(numVertTickPoints*incr)];
		[self setDefaultLineAttributes:kHeartrate];
		[[[Utils colorFromDefaults:RCBDefaultHeartrateColor] colorWithAlphaComponent:[self plotOpacity:kHeartrate]] set];
		hpath = [[self plotPathFromPoints:pts 
								  bounds:plotBounds
									ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(heartrate)]
							   lineWidth:2.0
									ymin:minhrGR
									ymax:maxhrGR
									xmin:minx
									xmax:maxx
							   doAverage:NO
							illegalValue:0.0
						 drawImmediately:YES] retain];
		
		[self drawRangeIndicator:kHeartrate
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxhrGR
						  yminGR:minhrGR
							ymax:maxhr
							ymin:minhr];
		
		if (showVerticalTicks)
			[self drawTheTickMarks:kHeartrate
							bounds:vertTickBounds
							   max:maxhrGR
							   min:minhrGR
							  axis:(int)posInfo.axis
						  numTicks:numVertTickPoints
							offset:posInfo.offset
							legend:@"(bpm)"
							isTime:NO];
	}
	
	if ([[plotAttributesArray objectAtIndex:kAvgHeartrate] enabled])
	{
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
		minhrGR = (float)(((int)((int)minhr)/10) * 10);
		numVertTickPoints = AdjustRuler(maxVertTicks, minhrGR, maxhr, &incr);
		maxhrGR = minhrGR + (numVertTickPoints*incr);
			if (!zonesDrawn && showHRZones && (znType == kUseHRZColorsForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultHeartrateColor] colorWithAlphaComponent:[self plotOpacity:kAvgHeartrate]] set];
		[self setDefaultLineAttributes:kAvgHeartrate];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(heartrate)]
						lineWidth:2.0
							 ymin:minhrGR
							 ymax:maxhrGR
							 xmin:minx
							 xmax:maxx
						doAverage:YES
					 illegalValue:0.0
				  drawImmediately:YES] autorelease];
			
		if (![[plotAttributesArray objectAtIndex:kHeartrate] enabled])
		{
			[self drawRangeIndicator:kHeartrate
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxhrGR
							  yminGR:minhrGR
								ymax:maxhr
								ymin:minhr];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kHeartrate
								bounds:vertTickBounds
								   max:maxhrGR
								   min:minhrGR
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints
								offset:posInfo.offset
								legend:@"(bpm)"
								isTime:NO];
		}
	}
	return posidx;
}


-(int) drawSpeedOrPace:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	maxsp = [Utils convertSpeedValue:[[pts valueForKeyPath:@"@max.speed"] floatValue]];
	float minsp = [Utils convertSpeedValue:[[pts valueForKeyPath:@"@min.speed"] floatValue]];
	if (!isStatute) maxsp = KilometersToMiles(maxsp);     // maxsp is always in miles
	[spath autorelease];
	spath = nil;
	if ([[plotAttributesArray objectAtIndex:kSpeed] enabled])
	{
		SEL sel;
		struct tPosInfo posInfo;
		float incr;
		int numVertTickPoints;
		BOOL zonesDrawn = NO;
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgSpeed] enabled] == NO) ++posidx;
		if (showPace)  
		{
			maxsp = SLOWEST_PACE;
			float tmxsp = isStatute ? maxsp : maxsp/MilesToKilometers(1.0);
			sel = @selector(pace);
			numVertTickPoints = AdjustTimeRuler(maxVertTicks, 0.0, tmxsp, &incr);
		}
		else
		{
			float tmxsp = isStatute ? maxsp : MilesToKilometers(maxsp);
			sel = @selector(speed);
			numVertTickPoints = AdjustRuler(maxVertTicks, 0.0, tmxsp, &incr);
		}
		maxspGR = numVertTickPoints*incr;
		if (!isStatute) maxspGR = showPace ?  maxspGR*MilesToKilometers(1.0) : KilometersToMiles(maxspGR);
		if (showHRZones && (((!showPace) && (znType == kUseSpeedZonesForPath)) || (showPace && (znType == kUsePaceZonesForPath)))) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultSpeedColor] colorWithAlphaComponent:[self plotOpacity:kSpeed]] set];
		[self setDefaultLineAttributes:kSpeed];
		spath = [[self plotPathFromPoints:pts 
								  bounds:plotBounds
									ysel:(tAccessor)[TrackPoint instanceMethodForSelector:sel]
							   lineWidth:2.0
									ymin:0.0
									ymax:maxspGR
									xmin:minx
									xmax:maxx
							   doAverage:NO
							illegalValue:-9999999.0
						 drawImmediately:YES] retain];
		
		 [self drawRangeIndicator:kSpeed
						   bounds:vertTickBounds
						  xoffset:posInfo.offset
							 axis:(int)posInfo.axis
						   ymaxGR:maxspGR
						   yminGR:0.0
							 ymax:maxsp
							 ymin:minsp];
		 if (showVerticalTicks)
			 [self drawTheTickMarks:kSpeed
							 bounds:vertTickBounds
								max:numVertTickPoints*incr
								min:0.0
							   axis:(int)posInfo.axis
						   numTicks:numVertTickPoints
							 offset:posInfo.offset
							 legend:showPace ? (isStatute ? @"(min/m)" : @"(min/km)") : (isStatute ? @"(mph)" : @"(km/h)")
							 isTime:showPace];
	}

	if ([[plotAttributesArray objectAtIndex:kAvgSpeed] enabled])
	{
		SEL sel;
		struct tPosInfo posInfo;
		float incr;
		int numVertTickPoints;
		BOOL zonesDrawn = NO;
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
		if (showPace)  
		{
			maxsp = SLOWEST_PACE;
			float tmxsp = isStatute ? maxsp : maxsp/MilesToKilometers(1.0);
			sel = @selector(pace);
			numVertTickPoints = AdjustTimeRuler(maxVertTicks, 0.0, tmxsp, &incr);
		}
		else
		{
			float tmxsp = isStatute ? maxsp : MilesToKilometers(maxsp);
			sel = @selector(speed);
			numVertTickPoints = AdjustRuler(maxVertTicks, 0.0, tmxsp, &incr);
		}
		maxspGR = numVertTickPoints*incr;
		if (!isStatute) maxspGR = showPace ?  maxspGR*MilesToKilometers(1.0) : KilometersToMiles(maxspGR);
		if (!zonesDrawn && showHRZones && (((!showPace) && (znType == kUseSpeedZonesForPath)) || (showPace && (znType == kUsePaceZonesForPath)))) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultSpeedColor] colorWithAlphaComponent:[self plotOpacity:kAvgSpeed]] set];
		[self setDefaultLineAttributes:kAvgSpeed];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:sel]
						lineWidth:2.0
							 ymin:0.0
							 ymax:maxspGR
							 xmin:minx
							 xmax:maxx
						doAverage:YES 
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		if (![[plotAttributesArray objectAtIndex:kSpeed] enabled])
		{
			[self drawRangeIndicator:kSpeed
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxspGR
							  yminGR:0.0
								ymax:maxsp
								ymin:minsp];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kSpeed
								bounds:vertTickBounds
								   max:numVertTickPoints*incr
								   min:0.0
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints
								offset:posInfo.offset
								legend:showPace ? (isStatute ? @"(min/m)" : @"(min/km)") : (isStatute ? @"(mph)" : @"(km/h)")
								isTime:showPace];
		}
	}
	return posidx;
}	

	
-(int) drawCadence:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	float incr;
	int numVertTickPoints;
	BOOL zonesDrawn = NO;
	maxcd = [[pts valueForKeyPath:@"@max.cadence"] floatValue];
	float mincd = [[pts valueForKeyPath:@"@min.cadence"] floatValue];
	if ([[plotAttributesArray objectAtIndex:kCadence] enabled])
	{
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgCadence] enabled] == NO) ++posidx;
		mincdGR = (float)((((int)mincd)/10) * 10);
		numVertTickPoints = AdjustRuler(maxVertTicks, mincdGR, maxcd, &incr);
		maxcdGR = mincdGR + (numVertTickPoints*incr);
		if (showHRZones && (znType == kUseCadenceZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultCadenceColor] colorWithAlphaComponent:[self plotOpacity:kCadence]] set];
		[self setDefaultLineAttributes:kCadence];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(cadence)]
						lineWidth:1.0
							 ymin:mincdGR
							 ymax:maxcdGR
							 xmin:minx
							 xmax:maxx
						doAverage:NO     
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		[self drawRangeIndicator:kCadence
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxcdGR
						  yminGR:mincdGR
							ymax:maxcd
							ymin:mincd];
		
		if (showVerticalTicks)
			[self drawTheTickMarks:kCadence
							bounds:vertTickBounds
							   max:maxcdGR
							   min:mincdGR
							  axis:(int)posInfo.axis
						  numTicks:numVertTickPoints
							offset:posInfo.offset
							legend:@"(rpm)"
							isTime:NO];
		
 	} 
	
	if ([[plotAttributesArray objectAtIndex:kAvgCadence] enabled])
	{
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
		mincdGR = (float)((((int)mincd)/10) * 10);
		numVertTickPoints = AdjustRuler(maxVertTicks, mincdGR, maxcd, &incr);
		maxcdGR = (numVertTickPoints)*incr;
		if (!zonesDrawn && showHRZones && (znType == kUseCadenceZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultCadenceColor] colorWithAlphaComponent:[self plotOpacity:kAvgCadence]] set];
		[self setDefaultLineAttributes:kAvgCadence];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(cadence)]
						lineWidth:1.0
							 ymin:mincdGR
							 ymax:maxcdGR
							 xmin:minx
							 xmax:maxx
						doAverage:YES
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		if (![[plotAttributesArray objectAtIndex:kCadence] enabled])
		{
			[self drawRangeIndicator:kCadence
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxcdGR
							  yminGR:mincdGR
								ymax:maxcd
								ymin:mincd];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kCadence
								bounds:vertTickBounds
								   max:maxcdGR
								   min:mincdGR
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints
								offset:posInfo.offset
								legend:@"(rpm)"
								isTime:NO];
		}
	}   
	return posidx;
}

-(int) drawPower:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	float incr;
	int numVertTickPoints;
	BOOL zonesDrawn = NO;
	maxpwr = [[pts valueForKeyPath:@"@max.power"] floatValue];
	float minpwr = [[pts valueForKeyPath:@"@min.power"] floatValue];
	if ([[plotAttributesArray objectAtIndex:kPower] enabled])
	{
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgCadence] enabled] == NO) ++posidx;
		numVertTickPoints = AdjustRuler(maxVertTicks, 0.0, maxpwr, &incr);
		maxpwrGR = (numVertTickPoints)*incr;
		if (showHRZones && (znType == kUsePowerZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultPowerColor] colorWithAlphaComponent:[self plotOpacity:kPower]] set];
		[self setDefaultLineAttributes:kPower];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(power)]
						lineWidth:1.0
							 ymin:0.0
							 ymax:maxpwrGR
							 xmin:minx
							 xmax:maxx
						doAverage:NO     
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		[self drawRangeIndicator:kPower
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxpwrGR
						  yminGR:0.0
							ymax:maxpwr
							ymin:minpwr];
		
		if (showVerticalTicks)
			[self drawTheTickMarks:kPower
							bounds:vertTickBounds
							   max:maxpwrGR
							   min:0.0
							  axis:(int)posInfo.axis
						  numTicks:numVertTickPoints
							offset:posInfo.offset
							legend:@"(watts)"
							isTime:NO];
		
 	} 
	
	if ([[plotAttributesArray objectAtIndex:kAvgPower] enabled])
	{
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
		numVertTickPoints = AdjustRuler(maxVertTicks, 0.0, maxpwr, &incr);
		maxpwrGR = (numVertTickPoints)*incr;
		if (!zonesDrawn && showHRZones && (znType == kUsePowerZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultPowerColor] colorWithAlphaComponent:[self plotOpacity:kAvgPower]] set];
		[self setDefaultLineAttributes:kAvgPower];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(power)]
						lineWidth:1.0
							 ymin:0.0
							 ymax:maxpwrGR
							 xmin:minx
							 xmax:maxx
						doAverage:YES
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		if (![[plotAttributesArray objectAtIndex:kPower] enabled])
		{
			[self drawRangeIndicator:kPower
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxpwrGR
							  yminGR:0.0
								ymax:maxpwr
								ymin:minpwr];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kPower
								bounds:vertTickBounds
								   max:maxpwrGR
								   min:0.0
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints
								offset:posInfo.offset
								legend:@"(watts)"
								isTime:NO];
		}
	}   
	return posidx;
}


#define INVALID_TEMP 1000.0

-(float)findMinTemperature:(NSArray*)ipts
{
	float minTemp = INVALID_TEMP;
    NSUInteger num = [ipts count];
	for (int i=0; i<num; i++)
	{
		float temp = [[ipts objectAtIndex:i] temperature];
		if ((temp > 0.0) && (temp < minTemp)) minTemp = temp;
	}
	if (minTemp == INVALID_TEMP) minTemp = 32.0;
	return minTemp;
}
	

-(int) drawTemperature:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	float incr;
	//BOOL zonesDrawn = NO;
	NSNumber* numMaxTemp = [pts valueForKeyPath:@"@max.temperature"];		// fahrenheit!
	float maxTempNative =  [Utils convertTemperatureValue:[numMaxTemp floatValue]];		// fahrenheit or celsius
	float mint = [self findMinTemperature:pts];		// fahrenheit!
	float minTempNative =  [Utils convertTemperatureValue:mint];		// fahrenheit or celsius
	maxTempNative = (float)((((int)maxTempNative+9)/10)*10);
	minTempNative = (float)((((int)minTempNative)/10)*10);
	
	int numVertTickPoints = AdjustRuler(maxVertTicks, minTempNative, maxTempNative, &incr);
	minTempNative = maxTempNative - (numVertTickPoints*incr);
	float maxtemp;
	float mintemp;
	bool isCentigrade = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
	if (!isCentigrade)
	{
		mintemp = minTempNative;
		maxtemp = maxTempNative;
	}
	else
	{
		mintemp = CelsiusToFahrenheight(minTempNative);
		maxtemp = CelsiusToFahrenheight(maxTempNative);
	}
	mintempGR = mintemp;	// used by the animation, if following the temperature graph
	maxtempGR = maxtemp;	// used by the animation, if following the temperature graph
	if ([[plotAttributesArray objectAtIndex:kTemperature] enabled])
	{
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgTemperature] enabled] == NO) ++posidx;
#if 0
		if (showHRZones && (znType == kUseCadenceZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
#endif
		[self setDefaultLineAttributes:kTemperature];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(temperature)]
						lineWidth:1.0
							 ymin:mintemp
							 ymax:maxtemp
							 xmin:minx
							 xmax:maxx
						doAverage:NO     
					 illegalValue:0.0
				  drawImmediately:YES] autorelease];
		
		[self drawRangeIndicator:kTemperature
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxtemp
						  yminGR:mintemp
							ymax:[numMaxTemp floatValue]
							ymin:mint];
		
		NSString* leg = isCentigrade ? [NSString stringWithUTF8String:"(\xC2\xB0""C)"] : 
									   [NSString stringWithUTF8String:"(\xC2\xB0""F)"];
		if (showVerticalTicks)
			[self drawTheTickMarks:kTemperature
							bounds:vertTickBounds
							   max:maxTempNative
							   min:minTempNative
							  axis:(int)posInfo.axis
						  numTicks:numVertTickPoints
							offset:posInfo.offset
							legend:leg
							isTime:NO];
		
 	} 
	
	if ([[plotAttributesArray objectAtIndex:kAvgTemperature] enabled])
	{
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
#if 0
		if (!zonesDrawn && showHRZones && (znType == kUseTemperatureZonesForPath)) 
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
#endif
		[[[Utils colorFromDefaults:RCBDefaultTemperatureColor] colorWithAlphaComponent:[self plotOpacity:kAvgTemperature]] set];
		[self setDefaultLineAttributes:kAvgTemperature];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(temperature)]
						lineWidth:1.0
							 ymin:mintemp
							 ymax:maxtemp
							 xmin:minx
							 xmax:maxx
						doAverage:YES
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		if (![[plotAttributesArray objectAtIndex:kTemperature] enabled])
		{
			[self drawRangeIndicator:kTemperature
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxtemp
							  yminGR:mintemp
								ymax:[numMaxTemp floatValue]
								ymin:mint];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kTemperature
								bounds:vertTickBounds
								   max:maxTempNative
								   min:minTempNative
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints
								offset:posInfo.offset
								legend:isCentigrade ? [NSString stringWithUTF8String:"(\xC2\xB0""C)"] : 
                                                      [NSString stringWithUTF8String:"(\xC2\xB0""F)"]
								isTime:NO];
		}
	}   
	return posidx;
}



-(int) drawGradient:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	float incr;
	int numVertTickPoints;
	BOOL zonesDrawn = NO;
	maxgr = [[pts valueForKeyPath:@"@max.gradient"] floatValue];
	mingr = [[pts valueForKeyPath:@"@min.gradient"] floatValue];
	if ((mingr < 0.0) && (-mingr > maxgr))
	{
		maxgr = -mingr;
	}
	else
	{
		mingr = -maxgr;
	}
	if ([[plotAttributesArray objectAtIndex:kGradient] enabled])
	{
		posInfo = [self getPosInfo:posidx markerPad:markerRightPadding];
		if ( [[plotAttributesArray objectAtIndex:kAvgGradient] enabled] == NO) ++posidx;
		numVertTickPoints = AdjustRuler(maxVertTicks/2, 0, maxgr, &incr);
		if (mingr < 0)
		{
			maxgrGR = (numVertTickPoints)*incr;
			mingrGR = -maxgrGR;
		}
		else
		{
			maxgrGR = (numVertTickPoints)*incr;
			mingrGR = 0.0;
		}
		if (showHRZones && (znType == kUseGradientZonesForPath))
		{
			zonesDrawn = YES;
			[self drawHRZones:(numVertTickPoints*incr)];
		}
		[[[Utils colorFromDefaults:RCBDefaultGradientColor] colorWithAlphaComponent:[self plotOpacity:kGradient]] set];
		[self setDefaultLineAttributes:kGradient];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(gradient)]
						lineWidth:1.0
							 ymin:mingrGR
							 ymax:maxgrGR
							 xmin:minx
							 xmax:maxx
						doAverage:NO
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
		
		[self drawRangeIndicator:kGradient
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxgrGR
						  yminGR:mingrGR
							ymax:maxgr
							ymin:mingr];
		
		if (showVerticalTicks)
			[self drawTheTickMarks:kGradient
							bounds:vertTickBounds
							   max:maxgrGR
							   min:mingrGR
							  axis:(int)posInfo.axis
						  numTicks:(numVertTickPoints*2)
							offset:posInfo.offset
							legend:@"(%)"
							isTime:NO];
	}      
	
	if ([[plotAttributesArray objectAtIndex:kAvgGradient] enabled])
	{
		posInfo = [self getPosInfo:posidx++ markerPad:markerRightPadding];
		numVertTickPoints = AdjustRuler(maxVertTicks/2, 0, maxgr, &incr);
		if (mingr < 0)
		{
			maxgrGR = (numVertTickPoints)*incr;
			mingrGR = -maxgrGR;
		}
		else
		{
			maxgrGR = (numVertTickPoints)*incr;
			mingrGR = 0.0;
		}
		if (!zonesDrawn && showHRZones && (znType == kUseGradientZonesForPath)) 
		{
			[self drawHRZones:(numVertTickPoints*incr)];
			zonesDrawn = YES;
		}
		[[[Utils colorFromDefaults:RCBDefaultGradientColor] colorWithAlphaComponent:[self plotOpacity:kAvgGradient]] set];
		[self setDefaultLineAttributes:kAvgGradient];
		[[self plotPathFromPoints:pts 
						   bounds:plotBounds
							 ysel:(tAccessor)[TrackPoint instanceMethodForSelector:@selector(gradient)]
						lineWidth:1.0
							 ymin:mingrGR
							 ymax:maxgrGR
							 xmin:minx
							 xmax:maxx
						doAverage:YES
					 illegalValue:-9999999.0
				  drawImmediately:YES] autorelease];
			
		if (![[plotAttributesArray objectAtIndex:kGradient] enabled])
		{
			[self drawRangeIndicator:kGradient
							  bounds:vertTickBounds
							 xoffset:posInfo.offset
								axis:(int)posInfo.axis
							  ymaxGR:maxgrGR
							  yminGR:mingrGR
								ymax:maxgr
								ymin:mingr];
			
			if (showVerticalTicks)
				[self drawTheTickMarks:kGradient
								bounds:vertTickBounds
								   max:maxgrGR
								   min:mingrGR
								  axis:(int)posInfo.axis
							  numTicks:numVertTickPoints*2
								offset:posInfo.offset
								legend:@"(%)"
								isTime:NO];
		}
	}      
	return posidx;
}


// the following determine the angular perspective of the "road" graphic above the altitude plot
#define X_ROAD_OFF				-2.0
#define Y_ROAD_OFF				7.0     
#define DRAW_DOTTED_ROAD_LINE	1

-(void) drawRoad:(NSBezierPath*)altitudePath bounds:(NSRect)plotBounds
{
	[NSGraphicsContext saveGraphicsState];
	plotBounds.size.height += 4;
	NSBezierPath* cp = [NSBezierPath bezierPathWithRect:plotBounds];
	[cp addClip];
	NSBezierPath* roadPath = [altitudePath copy];
	NSPoint p = [roadPath currentPoint];
	p.x -= X_ROAD_OFF;
	p.y += Y_ROAD_OFF;
	[roadPath lineToPoint:p];
	NSBezierPath *bezierPath = [altitudePath bezierPathByReversingPath];
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:-X_ROAD_OFF
						yBy: Y_ROAD_OFF];
	[bezierPath transformUsingAffineTransform: transform];
	[roadPath appendBezierPath:bezierPath];
	p = [roadPath currentPoint];
	p.x = plotBounds.origin.x;
	[roadPath lineToPoint:p];
	p.y -= Y_ROAD_OFF;
	[roadPath lineToPoint:p];
	//[roadPath closePath];
	[[NSColor blackColor] set];
	[roadPath setLineWidth:0.5];
	[roadPath setLineJoinStyle:NSLineJoinStyleRound];
	[roadPath stroke];
	[[[NSColor blackColor] colorWithAlphaComponent:0.5] setFill];
	[roadPath fill];
	[roadPath release];
#if DRAW_DOTTED_ROAD_LINE
	NSBezierPath* path = [altitudePath copy];
	transform = [NSAffineTransform transform];
	[transform translateXBy:-X_ROAD_OFF/2.0 
						yBy: Y_ROAD_OFF/1.5];
	[path transformUsingAffineTransform: transform];
	[[[NSColor whiteColor] colorWithAlphaComponent:0.8] set];
	CGFloat arr[2] = { 1.0, 3.0 };
	[path setLineWidth:1.0];
	[path setLineDash:arr count:2 phase:0.0];
	[path setLineJoinStyle:NSLineJoinStyleRound];
	[path stroke];
	[path release];
#endif
	[NSGraphicsContext restoreGraphicsState];
}


-(int) drawAltitude:(int)posidx points:(NSArray*)pts bounds:(NSRect)plotBounds minx:(float)minx maxx:(float)maxx znType:(int)znType
{
	struct tPosInfo posInfo;
	///NSNumber* numMaxAlt = [pts valueForKeyPath:@"@max.altitude"];		// in FEET
	NSNumber *mxn, *mnn;
	[Utils maxMinAlt:pts
				max:&mxn
				min:&mnn];
	
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
	
	float rulerIncr;
	numAltitudeVertTickPoints = AdjustRuler(maxVertTicks, minAltNative, maxAltNative, &rulerIncr);
	float altDifNative = (numAltitudeVertTickPoints)*rulerIncr;
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

	if (showHRZones && (znType == kUseAltitudeZonesForPath)) 
	{
		[self drawHRZones:(numAltitudeVertTickPoints*rulerIncr)];
	}
	
	[altPath autorelease];
	[dpath autorelease];
	altPath = dpath = nil;
	if ([[plotAttributesArray objectAtIndex:kAltitude] enabled] )
	{
		posInfo = [self getPosInfo:posidx++
						 markerPad:markerRightPadding];
		altPath = [[self plotPathFromPoints:pts 
									bounds:plotBounds
									  ysel:(tAccessor)[TrackPoint   instanceMethodForSelector:@selector(altitude)]
								 lineWidth:3.0
									  ymin:minalt			// in FEET
									  ymax:maxalt			// in FEET
									  xmin:minx
									  xmax:maxx
								 doAverage:NO
							  illegalValue:-9999999.0
						   drawImmediately:NO] retain];
		
		[self drawRangeIndicator:kAltitude
						  bounds:vertTickBounds
						 xoffset:posInfo.offset
							axis:(int)posInfo.axis
						  ymaxGR:maxalt						// in FEET
						  yminGR:minalt						// in FEET
							ymax:[mxn floatValue]		// in FEET
							ymin:[mnn floatValue]];	// in FEET
		 
		[self drawTheTickMarks:kAltitude
						bounds:vertTickBounds
						   max:[Utils convertClimbValue:maxalt]
						   min:[Utils convertClimbValue:minalt]
						  axis:(int)posInfo.axis
					  numTicks:numAltitudeVertTickPoints
						offset:posInfo.offset
						legend:isStatute ? @"(ft)" : @"(m)"
						isTime:NO];
		
		if (![altPath isEmpty]) 
		{
			if ([[plotAttributesArray objectAtIndex:kAltitude] fillEnabled])
			{
#if DRAW_ROAD
				[self drawRoad:altPath
						bounds:plotBounds];
#endif
				[[NSColor colorNamed:@"TextPrimary"] set];
				[altPath setLineWidth:1.0];
				[altPath setLineJoinStyle:NSLineJoinStyleRound];
				[altPath stroke];
				[[[Utils colorFromDefaults:RCBDefaultAltitudeColor] colorWithAlphaComponent:[self plotOpacity:kAltitude]] set];
				dpath = [altPath copy];
				NSPoint p = [altPath currentPoint];
				p.y = plotBounds.origin.y;
				[dpath lineToPoint:p];
				p.x = plotBounds.origin.x;
				[dpath lineToPoint:p];
				[dpath closePath];
				[dpath fill];
			}
			else
			{
				[[self plotColor:kAltitude] set];
				[self setLineAttributes:altPath type:kAltitude];
				[altPath stroke];
			}
		}
	}    
	return posidx;
}


-(void)setupAndDrawPeaks
{
	NSString* ck = RCBDefaultAltitudeColor;
	tAccessor ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(altitude)];
	NSString* fm = @"";
	switch (peakType)
	{
		default:
		case kAltitude:
            if (![altPath isEmpty])
            {
				ck = RCBDefaultAltitudeColor;
				ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(altitude)];
				fm = isStatute ? @"%4.0f ft" : @"%4.0f m"; 
            }
            break;
		case kHeartrate:
			ck = RCBDefaultHeartrateColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(heartrate)];
			fm = @"%3.0f";
			break;
		case kSpeed:
			ck = RCBDefaultSpeedColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(speed)];
			fm = @"%3.1f";  
			break;
		case kCadence:
			ck = RCBDefaultCadenceColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(cadence)];
			fm = @"%3.0f";
			break;
		case kPower:
			ck = RCBDefaultPowerColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(power)];
			fm = @"%3.0f";
			break;
		case kGradient:
			ck = RCBDefaultGradientColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(gradient)];
			fm = @"%3.1f%%%";
			break;
		case kTemperature:
			ck = RCBDefaultTemperatureColor;
			ys = (tAccessor)[TrackPoint instanceMethodForSelector:@selector(temperature)];
			fm = @"%0.1f";   
			break;
	}
	[self drawPeaks:altPath 
			   type:peakType
		   numPeaks:numPeaks 
		  threshold:peakThreshold
			   ysel:ys 
		   colorKey:ck
			 format:fm];
}


-(int) findAvailableSpaceOnLine:(NSMutableArray*)lineArray text:(NSString*)s withAttributes:(NSDictionary*)attrs xpos:(float*)xposPtr
{
	int line = 0;
    NSUInteger num = [lineArray count];
	NSSize sz = [s sizeWithAttributes:attrs];
	float left = *xposPtr;
	float width = sz.width;
	for (int i=0; i<num; i++)
	{
		NSMutableArray* larr = [lineArray objectAtIndex:i];
		if (larr)
		{
            NSUInteger numOnLine = [larr count];
			BOOL intersects = NO;
			for (int j=0; j<numOnLine; j++)
			{
				NSNumber* number = [larr objectAtIndex:j];
				int n = [number intValue];
				float x = n & 0x0000ffff;
				float w = (n & 0xffff0000) >> 16;
				if (((left >= x) && (left <= (x+w))) ||
					((x >= left) && (x <= (left + width))))
				{
					intersects = YES;	// can't do it on this line
					break;
				}
			}
			if (intersects) continue;
			else 
			{
				line = i;
				NSNumber* number = [NSNumber numberWithInt:((int)left | ((int)width << 16))];
				[larr addObject:number];
				break;
			}
		}
	}
	return line;
}


-(void)drawPowerPeakIntervals
{
	if (!showPowerPeakIntervals)
		return;
	if (![track activityIsValidForPowerCalculation])
		return;
	NSTimeInterval pst;
	NSArray* gpts = [track goodPoints];
	NSArray* plottedPoints = [self ptsForPlot];
	if ([plottedPoints count] < 2) return;
	TrackPoint* startingPlotPoint = [plottedPoints objectAtIndex:0];
	TrackPoint* endingPlotPoint = [plottedPoints lastObject];
	
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
    
    NSArray *keys = dict.allKeys;
    keys = [keys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        // Numeric / natural sort: "2" < "10"
        return [a compare:b options:NSNumericSearch];
    }];
    
    NSUInteger num = [dict count];
	NSMutableArray* lineInfoArr = [NSMutableArray arrayWithCapacity:num];
	for (int i = 0; i<num; i++)
	{
		[lineInfoArr addObject:[NSMutableArray array]];
		NSString* k = [keys objectAtIndex:i];
		NSNumber* enabledNum = [dict objectForKey:k];
		BOOL enabled = [enabledNum boolValue];
		if (!enabled) continue;
		int sidx;
		float pk = [track peakForIntervalType:kPDT_Power
								intervalIndex:i
								peakStartTime:&pst
					   startingGoodPointIndex:&sidx];
		float intervalDuration = [Utils nthPeakInterval:i];
		
		
		NSRect plotBounds = [self getPlotBounds:YES];
		float x = plotBounds.origin.x;
		float y = plotBounds.origin.y;
		float w = plotBounds.size.width;
		float h = plotBounds.size.height;
		int eidx = [track findFirstGoodPointAtOrAfterActiveDelta:pst + intervalDuration
														 startAt:sidx];
		if (eidx == -1) eidx = sidx;
		//NSLog(@"INTERVAL: %d, peak:%0.1f watts for interval %0.1f seconds at time %0.1f seconds, [%d,%d]", i, pk, intervalDuration, pst, sidx, eidx);
		
		NSRect peakBounds;
		peakBounds.origin.y = y;
		peakBounds.size.height = h;
		float pw = 0.0;
		if (xAxisIsTime)
		{
			float dur = [track movingDuration]; // fixme, ELAPSED DURATION
			float startTime = 0.0;
			float endTime = dur;
			float peakEndTime = pst + intervalDuration;
			if (lap) 
			{
				startTime = [track lapActiveTimeDelta:lap];
				dur = [track movingDurationOfLap:lap];
				endTime = startTime + dur;
			}
			if (dur > 0.0) 
			{
				if (peakEndTime < startTime) continue;
				if (pst > endTime) continue;
				if (pst < startTime)pst = startTime;
				if (peakEndTime > endTime) peakEndTime = endTime;
				x += (w * (pst-startTime))/dur;
				pw = (w * intervalDuration)/dur;
			}
		}
		else
		{
			TrackPoint* startPoint = (TrackPoint*)[gpts objectAtIndex:sidx];
			TrackPoint* endPoint = (TrackPoint*)[gpts objectAtIndex:eidx];
			float startDist = [startPoint distance];
			float endDist = [endPoint distance];
			float plotStartDist = [startingPlotPoint distance];
			float plotEndDist = [endingPlotPoint distance];
			if (endDist < plotStartDist) continue;
			if (startDist > plotEndDist) continue;
			if (startDist < plotStartDist)
				startDist = plotStartDist;
			if (endDist > plotEndDist)
				endDist = plotEndDist;
			float distOfPlot = plotEndDist - plotStartDist;
			if (distOfPlot > 0.0)
			{
				x += (w * (startDist-plotStartDist))/distOfPlot;
				pw = (w * (endDist - startDist))/distOfPlot;
			}
		}
		peakBounds.origin.x = x;
		peakBounds.size.width = pw;

		[[[Utils colorFromDefaults:RCBDefaultPowerColor] colorWithAlphaComponent:0.5] set];
		[NSBezierPath fillRect:peakBounds];

		NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
		NSFont* font = [NSFont systemFontOfSize:10];
		[attrs setObject:font forKey:NSFontAttributeName];
		NSColor* clr = [[Utils colorFromDefaults:RCBDefaultPowerColor] colorWithAlphaComponent:0.9];
		[attrs setObject:clr
			  forKey:NSForegroundColorAttributeName];
		[numberFormatter setMaximumFractionDigits:0];
		NSString* powerString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:pk]];
		[numberFormatter setMaximumFractionDigits:1];
		NSString* s = [NSString stringWithFormat:@"Peak %@ (%@ watts)", [Utils friendlyIntervalAsString:intervalDuration], powerString];
		y += (h + 3.0);
		int line = [self findAvailableSpaceOnLine:lineInfoArr
											 text:s
								   withAttributes:attrs
											 xpos:&x];
		[s drawAtPoint:NSMakePoint(x, y + (12.0*line)) 
		withAttributes:attrs];
	}
}


-(NSTimeInterval)interpolateTime:(TrackPoint*)ptBefore pointAfter:(TrackPoint*)ptAfter distanceTarget:(float)dist
{
	float pt1Dist = ptBefore ?  ptBefore.distance : 0.0;
	float pt2Dist = ptAfter ? ptAfter.distance : pt1Dist;
	if (pt2Dist != pt1Dist)
	{
		return (ptBefore.activeTimeDelta) + (((dist - pt1Dist)/(pt2Dist - pt1Dist))*(ptAfter.activeTimeDelta-ptBefore.activeTimeDelta));
	}
	else
	{
		return ptBefore.activeTimeDelta;
	}
}


-(void)setDistanceOverride:(float)minDist max:(float)maxDist
{
	NSArray* gpts = [track goodPoints];
	overrideDistance = YES;
	mindist = minDist;
	maxdist = maxDist;
	int idx = [track findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:minDist  
																   startAt:0];
	if (idx >= 0)
	{
		TrackPoint* pt = [gpts objectAtIndex:idx];
		TrackPoint* ptb = (idx > 0) ? [gpts objectAtIndex:(idx-1)] : nil;
		NSTimeInterval toff = [self interpolateTime:ptb
										 pointAfter:pt
									 distanceTarget:minDist];
		[track setAnimTimeBegin:toff];
	}
	
	
	idx = [track findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:maxDist  
															   startAt:idx];
	if (idx >= 0)
	{
		TrackPoint* pt = [gpts objectAtIndex:idx];
		TrackPoint* ptb = (idx > 0) ? [gpts objectAtIndex:(idx-1)] : nil;
		NSTimeInterval toff = [self interpolateTime:ptb
										 pointAfter:pt
									 distanceTarget:maxDist];
		[track setAnimTimeEnd:toff];
	}
	[self setNeedsDisplay:YES];
}


- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self drawBounds];
	BOOL dimChange = NO;
	if ((bounds.size.width != lastBounds.size.width) ||
	    (bounds.size.height != lastBounds.size.height) ||
	    (xAxisIsTime != lastXAxisIsTime) || 
	    (track != lastTrack) ||
	    (markerRightPadding < 0.0))
	{
		dimChange = YES;
		lastTrack = track;
		lastBounds = bounds;
		[self resetPaths];
		lastXAxisIsTime = xAxisIsTime;
	}
	
	// update the shadow, fill the background ----------------------------------
	NSShadow *dropShadow = [[[NSShadow alloc] init] autorelease];
	[dropShadow setShadowColor:[NSColor blackColor]];
	[dropShadow setShadowBlurRadius:3];
	[dropShadow setShadowOffset:NSMakeSize(+2.0,-2.0)];
	[NSGraphicsContext saveGraphicsState];
	[dropShadow set];
	///[[Utils colorFromDefaults:RCBDefaultBackgroundColor] set];
    [[NSColor colorNamed:@"BackgroundPrimary"] set];
	[NSBezierPath fillRect:bounds];
	[NSGraphicsContext restoreGraphicsState];

	
	if (dragStart && [[self window] firstResponder] == self)
	{
		[[NSColor colorWithCalibratedRed:0.0
								   green:0.0 
									blue:1.0 
								   alpha:0.66] set];
		[NSBezierPath setDefaultLineWidth:2.5];
		[NSBezierPath strokeRect:bounds];
	}	
	
	if (track == nil) return;

	NSArray* pts = [self ptsForPlot];
    NSUInteger numPoints = [pts count];
	NSRect plotBounds = [self getPlotBounds:YES];
	
	[[NSColor blackColor] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	NSPoint p1, p2;
	p1 = NSMakePoint(plotBounds.origin.x, plotBounds.origin.y);
	p2 = NSMakePoint(plotBounds.origin.x + plotBounds.size.width, plotBounds.origin.y);
	[NSBezierPath strokeLineFromPoint:p1
							  toPoint:p2];

	
	if (numPoints < 1)
	{
		NSString* s = @"No Data Points";
		NSSize size = [s sizeWithAttributes:textFontAttrs];
		float x = bounds.origin.x + bounds.size.width/2.0 - size.width/2.0;
		float y = (bounds.size.height/2.0) - (size.height/2.0);
		[textFontAttrs setObject:[[NSColor blackColor] colorWithAlphaComponent:0.25] forKey:NSForegroundColorAttributeName];
		[s drawAtPoint:NSMakePoint(x,y) 
		withAttributes:textFontAttrs];
	}
	else
	{
		isStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];

		// set bounds for axises ---------------------------------------------------
		if (dimChange)
		{
			if (!overrideDistance)
			{
				if (numPoints > 0)
				{ 
					maxdist = [[pts lastObject] distance];
					mindist = [[pts objectAtIndex:0] distance];
				}
				else
				{
					maxdist = mindist = 0.0;
				}
			}
			float xpad = [self getXPad];
			vertTickBounds = NSInsetRect(bounds, xpad, vertPlotYOffset);
			vertTickBounds.size.height -= topAreaHeight;
			horizTickBounds = NSInsetRect(bounds, xpad, 0);
			horizTickBounds.origin.x = plotBounds.origin.x;
			horizTickBounds.size.width = plotBounds.size.width;
			maxHorizTicks = ((int)(horizTickBounds.size.width/20.0)) & 0xfffffffe;
			maxVertTicks = ((int)(vertTickBounds.size.height/20.0)) & 0xfffffffe;
		}

		// draw horizontal axis and tick marks ------------------------------------- 
		[tickFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
		float minx = 0.0;
		float maxx = 0.0;
		float incr = 0.0;
		if (xAxisIsTime == YES)
		{
			if (showHorizontalTicks)
			{
				int numHorizTicks = AdjustTimeRuler(maxHorizTicks, 0.0, plotDuration, &incr);
				NSRect tbounds = horizTickBounds;
				float graphDur = numHorizTicks*incr;
				tbounds.size.width = (graphDur*tbounds.size.width)/plotDuration;
				DUDrawTickMarks(tbounds, (int)kHorizontal, -6.0, 0.0, graphDur, numHorizTicks, tickFontAttrs, YES, 
								horizTickBounds.origin.x + horizTickBounds.size.width);
			}
			minx = 0.0;
			maxDurationForPlotting = maxx = plotDuration;
		}
		else
		{
			if (showHorizontalTicks)
			{
				float tmxd = [Utils convertDistanceValue:maxdist];
				float tmnd = [Utils convertDistanceValue:mindist];
				int numHorizTicks = AdjustDistRuler(maxHorizTicks, 0.0, tmxd-tmnd, &incr);
				NSRect tbounds = horizTickBounds;
				if (tmxd > tmnd)
					tbounds.size.width = (numHorizTicks*incr*tbounds.size.width)/(tmxd-tmnd);
				else
					tbounds.size.width = 1.0;
				DUDrawTickMarks(tbounds, (int)kHorizontal, 0.0, 0.0, numHorizTicks*incr, numHorizTicks, tickFontAttrs, NO, 
								horizTickBounds.origin.x + horizTickBounds.size.width);
			}
			minx = mindist;
			maxx = maxdist;
		}
		
		// plot power peaks first, so they're in the background
		[self drawPowerPeakIntervals];
	
		// do the plotting --------------------------------------------------------- 
		int znType = [Utils intFromDefaults:RCBDefaultZoneInActivityDetailViewItem];
		int posidx = 0;
	   
		if ([track hasElevationData])
		{
			posidx = [self drawAltitude:posidx 
								 points:pts
								 bounds:plotBounds
								   minx:minx 
								   maxx:maxx 
								 znType:znType];
		}
		posidx = [self drawHeartRate:posidx 
							  points:pts
							  bounds:plotBounds
								minx:minx 
								maxx:maxx 
							  znType:znType];
		
		posidx = [self drawSpeedOrPace:posidx 
								points:pts
								bounds:plotBounds
								  minx:minx 
								  maxx:maxx 
								znType:znType];
		
		posidx = [self drawCadence:posidx 
							points:pts
							bounds:plotBounds
							  minx:minx 
							  maxx:maxx 
							znType:znType];
		
		posidx = [self drawPower:posidx 
							points:pts
							bounds:plotBounds
							  minx:minx 
							  maxx:maxx 
							znType:znType];
		
		posidx = [self drawGradient:posidx 
							 points:pts
							 bounds:plotBounds
							   minx:minx 
							   maxx:maxx 
							 znType:znType];
		
		posidx = [self drawTemperature:posidx 
								points:pts
								bounds:plotBounds
								  minx:minx 
								  maxx:maxx 
								znType:znType];
		
		// draw markers, peaks, etc ------------------------------------------------
		if (![altPath isEmpty])
		{
			if (showMarkers) [self drawMarkers:altPath];
			if ((lap == nil) && showLaps) [self drawLaps:altPath];
			if (showPeaks) [self setupAndDrawPeaks];
		}
		
		// update the animation (yellow ball) --------------------------------------
		int pos = currentTrackPos - posOffsetIndex;
		if ((numPoints > 0) && (pos < numPoints) && (pos>=0))
		{
			//TrackPoint* tpt = [pts objectAtIndex:pos];
			[self drawAnimatingParts:pos
							animTime:track.animTime
					   updateDisplay:YES];
		}
		if (selectRegionInProgress)
		{
			[transparentView setStartSelection:[self calcTransparentViewPos:selectionStartIdx]];
			[transparentView   setEndSelection:[self calcTransparentViewPos:selectionEndIdx]];
		}
	}
	if (drawHeader) [self drawHeader:plotBounds];
}


- (Lap *)lap 
{
    return [[lap retain] autorelease];
}

-(void)setPlotDurationOverride:(NSTimeInterval)pd
{
	plotDuration = pd;
	[self setNeedsDisplay:YES];
}


- (void)setPlotDuration:(NSArray*) pts isTrack:(BOOL)isTrack
{
    NSUInteger num = [pts count];
	if (num > 0)
	{
		// need to make sure that active times NEVER exceed duration used in this graph
		TrackPoint* lastPt = [pts objectAtIndex:(num-1)];
		TrackPoint* firstPt = [pts objectAtIndex:0];
		//NSDate* lastDate = [lastPt DATE_METHOD];
		//NSDate* firstDate = [firstPt DATE_METHOD];
		//NSTimeInterval timeInterval = [lastDate timeIntervalSinceDate:firstDate];
		NSTimeInterval timeInterval = [lastPt DATE_METHOD] - [firstPt DATE_METHOD];
		if (isTrack)
		{
			float dur = [track DURATION_METHOD];
			if (timeInterval > dur)
			{
				plotDuration = [track duration];
			}
			else
			{
				plotDuration = [track DURATION_METHOD];
			}
		}
		else 
		{
			plotDuration = [track movingDurationOfLap:lap];
		}
	}
	else
	{
		plotDuration = 0.0;
	}
}


- (void)setLap:(Lap *)value 
{
	if (lap != value) 
	{
		[lap release];
		lap =  value;
		[lap retain];
		if (lap == nil)
		{
			[self setTrack:track
			   forceUpdate:YES];
		}
		else
		{
			[self setPlotDuration:[track lapPoints:lap] isTrack:NO];
			posOffsetIndex = [track lapStartingIndex:lap];	// this is a "GOOD POINTS" index
			NSArray* pts = [self ptsForPlot];
			NSTimeInterval dt = 0.0;
			if ([pts count] > 0)
			{
				dt = [[pts objectAtIndex:0] DATE_METHOD];
			}
			//[[AnimTimer defaultInstance] setAnimTime:[dt timeIntervalSinceDate:[track creationTime]]];
			[[AnimTimer defaultInstance] setAnimTime:dt];
		}
	}
	lastTrack = nil;
	[self resetPaths];
	[self setNeedsDisplay:YES];
	selectionStartIdx = selectionEndIdx = 0;
	selectRegionInProgress = NO;
	[transparentView clearSelection];
}


- (void)setTrack:(Track*)t forceUpdate:(BOOL)force
{
	if (t != track)
	{
		[track release];
		track = t;
		[track retain];
	}
	posOffsetIndex = 0;
	if (track != nil) [self setPlotDuration:[track goodPoints] isTrack:YES];
	if (force) [[AnimTimer defaultInstance] setAnimTime:[[AnimTimer defaultInstance] animTime]];	// force update
	if (t != lastTrack) 
	{
		lap = nil;
		[self resetPaths];
		selectionStartIdx = selectionEndIdx = 0;
		selectRegionInProgress = NO;
		[transparentView clearSelection];
	}
	else
	{
		[self setLap:lap];
	}
	trackHasPoints = [[track goodPoints] count] > 0;
	lastTrack = nil;     // force re-draw of everything
	t.animTimeBegin = 0.0;
	t.animTimeEnd = t.movingDuration;
}


- (NSBezierPath*)bezierPathWithRoundRect:(NSRect)inRect xRadius: 
                (float)inRadiusX yRadius:(float)inRadiusY
{
   const float kEllipseFactor = 0.55228474983079;
   
   float theMaxRadiusX = NSWidth(inRect) / 2.0;
   float theMaxRadiusY = NSHeight(inRect) / 2.0;
   float theRadiusX = (inRadiusX < theMaxRadiusX) ? inRadiusX :  
      theMaxRadiusX;
   float theRadiusY = (inRadiusY < theMaxRadiusY) ? inRadiusY :  
      theMaxRadiusY;
   float theControlX = theRadiusX * kEllipseFactor;
   float theControlY = theRadiusY * kEllipseFactor;
   NSRect theEdges = NSInsetRect(inRect, theRadiusX, theRadiusY);
   NSBezierPath* theResult = [NSBezierPath bezierPath];
   
   //    Lower edge and lower-right corner
   [theResult moveToPoint:NSMakePoint(theEdges.origin.x,  
                                      inRect.origin.y)];
   [theResult lineToPoint:NSMakePoint(NSMaxX(theEdges),  
                                      inRect.origin.y)];
   [theResult curveToPoint:NSMakePoint(NSMaxX(inRect),  
                                       theEdges.origin.y)
             controlPoint1:NSMakePoint(NSMaxX(theEdges) +  
                                       theControlX, inRect.origin.y)
             controlPoint2:NSMakePoint(NSMaxX(inRect),  
                                       theEdges.origin.y - theControlY)];
   
   //    Right edge and upper-right corner
   [theResult lineToPoint:NSMakePoint(NSMaxX(inRect), NSMaxY 
                                      (theEdges))];
   [theResult curveToPoint:NSMakePoint(NSMaxX(theEdges), NSMaxY 
                                       (inRect))
             controlPoint1:NSMakePoint(NSMaxX(inRect), NSMaxY 
                                       (theEdges) + theControlY)
             controlPoint2:NSMakePoint(NSMaxX(theEdges) +  
                                       theControlX, NSMaxY(inRect))];
   
   //    Top edge and upper-left corner
   [theResult lineToPoint:NSMakePoint(theEdges.origin.x, NSMaxY 
                                      (inRect))];
   [theResult curveToPoint:NSMakePoint(inRect.origin.x, NSMaxY 
                                       (theEdges))
             controlPoint1:NSMakePoint(theEdges.origin.x -  
                                       theControlX, NSMaxY(inRect))
             controlPoint2:NSMakePoint(inRect.origin.x, NSMaxY 
                                       (theEdges) + theControlY)];
   
   //    Left edge and lower-left corner
   [theResult lineToPoint:NSMakePoint(inRect.origin.x,  
                                      theEdges.origin.y)];
   [theResult curveToPoint:NSMakePoint(theEdges.origin.x,  
                                       inRect.origin.y)
             controlPoint1:NSMakePoint(inRect.origin.x,  
                                       theEdges.origin.y - theControlY)
             controlPoint2:NSMakePoint(theEdges.origin.x -  
                                       theControlX, inRect.origin.y)];
   
   
   //    Finish up and return
   [theResult closePath];
   return theResult;
}




-(void) updateAnimation:(NSTimeInterval)trackTime reverse:(BOOL)rev;
{
	if (bypassAnim == NO)
	{
		animating = YES;
		NSArray* pts = [self ptsForPlot];
		//NSDate* startTime;
		NSTimeInterval startTimeDelta = 0.0;
        NSUInteger count = [pts count];
		if (count > 0)
			startTimeDelta = [[pts objectAtIndex:0] DATE_METHOD];
			//startTime = [[pts objectAtIndex:0] DATE_METHOD];
		currentTrackPos = [track animIndex];
		int pos = currentTrackPos - posOffsetIndex;
		if ((pos >= 0) && (pos < count))
		{
			[self drawAnimatingParts:pos
							animTime:trackTime
					   updateDisplay:YES];
		}
		else
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"ADAnimationEnded" object:self];
		}
	}
}


- (void) setAnimPos:(int) pos
{
   currentTrackPos = pos;
   lastdist = 0.0;
}


- (void) stopAnim
{
   animating = NO;
}


- (NSArray*)selectedPoints
{
   NSArray* spts = nil;
   if (selectRegionInProgress)
   {
      if (selectionStartIdx <= selectionEndIdx)
      {
         NSMutableArray* npts = [NSMutableArray arrayWithCapacity:(selectionEndIdx-selectionStartIdx+1)];
         NSArray* pts = [self ptsForPlot];
          NSUInteger count = [pts count];
         int i = selectionStartIdx;
         while ((i<count) && (i<=selectionEndIdx))
         {
            [npts addObject:[pts objectAtIndex:i]];
            i++;
         }
         spts = npts;
      }
   }
   else if (lap && track)
   {
      spts = [track lapPoints:lap];
   }
   else if (track)
   {
      spts = [track goodPoints];
   }
   return spts;
}


static BOOL dragging = NO;

- (void) processMouseMove:(NSEvent*) ev
{
	NSArray* pts = [self ptsForPlot];		// operate on points currently plotted
    NSUInteger count = [pts count];
	float max;
	if (xAxisIsTime)
	{
		max = maxDurationForPlotting;
	}
	else
	{
		max = maxdist-mindist;
	}
	if ((count > 0) && (max > 0.0))
	{
		NSPoint evLoc = [ev locationInWindow];
		evLoc = [self convertPoint:evLoc fromView:nil];
		NSRect bounds = [self getPlotBounds:YES];
		float w = bounds.size.width;
		NSPoint pt;
		TrackPoint* tpt = [pts objectAtIndex:0];
		NSTimeInterval startTimeDelta = [tpt DATE_METHOD];
		float startingDistance = [tpt distance];
		int i = 0;
		while (i < count)
		{
			// find first point with an x position that is greater than or equal to where the
			// mouse was clicked...
			tpt = [pts objectAtIndex:i];
			float cv;
			if (xAxisIsTime)
			{
				cv = [tpt DATE_METHOD] - startTimeDelta;
			}
			else
			{ 
				cv = [tpt distance] - startingDistance;
			}
			pt.x = bounds.origin.x + ((cv * w)/max);
			if (evLoc.x <= pt.x) 
			{
				lastdist = [tpt distance] - mindist;
				currentTrackPos = i + posOffsetIndex;	// this is a "GOOD POINTS" index within the track goodPoints array!!!
				if (!selectRegionInProgress)
				{
					// start select region here if left mouse down and 'option' key held
					selectRegionInProgress = (([ev type] == NSEventTypeLeftMouseDown) && ([ev modifierFlags] & NSEventModifierFlagOption));
					if (selectRegionInProgress) 
					{
						[transparentView setStartSelection:[self calcTransparentViewPos:i]];
						[transparentView   setEndSelection:[self calcTransparentViewPos:i]];
						selectionStartIdx = selectionEndIdx = currentTrackPos;
					}
				}
				if (selectRegionInProgress)
				{
					if (i < selectionStartIdx)
					{
						// extend selection to the left of where the drag started.  
						// swap previous start to be the new end, and set the start
						// to the mouse xloc
						selectionStartIdx = i;
						selectionEndIdx = selectionStartIdx;
						[transparentView setStartSelection:[self calcTransparentViewPos:i]];
					}
					// if dragging to the right, update the ending index
					if (i > selectionStartIdx) selectionEndIdx = i;
					[transparentView   setEndSelection:[self calcTransparentViewPos:i]];
					// invoke the controller method with the new track position (index in goodPoints)
					[mSelectionUpdateInvocation setArgument:&currentTrackPos 
													atIndex:2];
					[mSelectionUpdateInvocation invoke];
				}
				[self drawAnimatingParts:i
								animTime:[tpt DATE_METHOD]
						   updateDisplay:YES];
				break;
			}
			++i;
		}
		[[AnimTimer defaultInstance] setAnimTime:[tpt DATE_METHOD]];
	}      
}

 
- (int)selectionPosIdxOffset
{
   return posOffsetIndex;
}


static ActivityDetailView* lastDown = nil;

- (void)mouseDown:(NSEvent*) ev
{
	dragging = YES;
	if (dragStart)
	{
		lastDown = self;
		[[self window] makeFirstResponder:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ActivityWindowFocusChanged" object:self];
	}
	else
	{
		bypassAnim = YES;
		if (selectRegionInProgress) 
		{
			selectRegionInProgress = NO;
			[transparentView clearSelection];
			selectionStartIdx = selectionEndIdx = 0;
		}
		[self processMouseMove:ev];
		if (!selectRegionInProgress)
		{
			int end = -1;
			[mSelectionUpdateInvocation setArgument:&end 
											atIndex:2];
			[mSelectionUpdateInvocation invoke];
		}
	}
}


- (void)mouseDragged:(NSEvent*) ev
{
   if (dragging == YES)
   {
	   if (dragStart)
	   {
		   float dx = [ev deltaX];
		   if (dx != 0.0) [self doDragMove:dx];
	   }
	   else
	   {
		   [self processMouseMove:ev];
	   }
   }
}


- (void)mouseUp:(NSEvent*) ev
{
   dragging = NO;
   bypassAnim = NO;
}



- (int)selectionStartIdx 
{
   if (selectRegionInProgress)
   {
      return selectionStartIdx;
   }
   else if (lap && track)
   {
      return 0;
   }
   else if (track)
   {
      return 0;
   }
   return 0;
}


- (int)selectionEndIdx 
{
   if (selectRegionInProgress)
   {
      return selectionEndIdx;
   }
   else if (lap && track)
   {
      return (int) [[track lapPoints:lap] count] - 1;
   }
   else if (track)
   {
      return (int) [[track goodPoints] count] - 1;
   }
   return 0;
}




- (void) doMove:(NSEvent*)ev delta:(int)delta
{
	NSArray* pts = [self ptsForPlot];
    int count = (int)[pts count];
	TrackPoint* tpt  = nil;
	if (selectRegionInProgress)
	{
		BOOL adjustStart = NO;
		BOOL adjustEnd = NO;
		if ([ev modifierFlags] & NSEventModifierFlagOption) // operate on start point
		{
			selectionStartIdx += delta;
			selectionStartIdx = CLIP(0, selectionStartIdx, (count-1));
			if (selectionStartIdx > selectionEndIdx)
			{
				selectionStartIdx = selectionEndIdx;
			}
			currentTrackPos = selectionStartIdx;
			adjustStart = YES;
		}
		else
		{
			selectionEndIdx += delta;
			selectionEndIdx = CLIP(0, selectionEndIdx, (count-1));
			if (selectionEndIdx < selectionStartIdx)
			{
				selectionStartIdx = selectionEndIdx;
			}
			currentTrackPos = selectionEndIdx;
			adjustEnd = YES;
		}
		if (adjustStart || adjustEnd)
		{
			[transparentView setStartSelection:[self calcTransparentViewPos:selectionStartIdx]];
			[transparentView   setEndSelection:[self calcTransparentViewPos:selectionEndIdx]];
			if (adjustStart)
			{
				tpt = [pts objectAtIndex:selectionStartIdx];
				[self drawAnimatingParts:selectionStartIdx
								animTime:track.animTime
						   updateDisplay:YES];
			}
			else
			{
				tpt = [pts objectAtIndex:selectionEndIdx];
				[self drawAnimatingParts:selectionEndIdx
								animTime:track.animTime
						   updateDisplay:YES];
			}
			[mSelectionUpdateInvocation setArgument:&currentTrackPos 
											atIndex:2];
			[mSelectionUpdateInvocation invoke];
		}
	}
	else
	{
		if (delta != 0)
		{
			int i = currentTrackPos + delta - posOffsetIndex;
			if ((i > 0) && (i < (count-1)))
			{
				tpt = [pts objectAtIndex:i];
				[self drawAnimatingParts:i
								animTime:track.animTime
						   updateDisplay:YES];
				currentTrackPos = i + posOffsetIndex;
			}
		}
	}
	if (tpt != nil)
	{
		[[AnimTimer defaultInstance] setAnimTime:[tpt DATE_METHOD]];
	}
}


-(void)doDragMove:(float)dx
{
	NSRect bounds = [self drawBounds];
	float milesPerPixel = (maxdist-mindist)/bounds.size.width;
	float incr = milesPerPixel * dx;
	[self setDistanceOverride:mindist-incr
						  max:maxdist-incr];
	[[AnimTimer defaultInstance] forceUpdate];
}



- (void)keyDown:(NSEvent *)theEvent
{
	int kc = [theEvent keyCode];
	if (kc == 49)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
	}
	else
	{
		NSPoint evLoc = [theEvent locationInWindow];
		evLoc = [[self superview] convertPoint:evLoc fromView:nil];
		///NSRect r = [self frame];
		evLoc.y -= 60.0;
		if ((kc == 124) || (kc == 123))
		{
			if (dragStart)
			{
				if (kc == 124)
				{
					[self doDragMove:1];
				}
				else if (kc == 123)
				{
					[self doDragMove:-1];
				}
			}
			else
			{
				if (kc == 124)
				{
				  [self doMove:theEvent
						 delta:1];
				}
				else if (kc == 123)
				{
				  [self doMove:theEvent
						 delta:-1];
				}
			}
		}
		else
		{
			[super keyDown:theEvent];
		}
	}
}



- (void)scrollWheel:(NSEvent *)theEvent
{
   float dy = [theEvent deltaY]; // @@? seems to feel good at this level
   if (dy < 0)
   {
      dy -= 1.0;
   }
   else if (dy > 0)
   {
      dy += 1.0;
   }
   [self doMove:theEvent
          delta:(int)dy];
}


-(void)prefsChanged
{
    [self _updatePlotAttributes];
    [self setNeedsDisplay:YES];
}


@end
