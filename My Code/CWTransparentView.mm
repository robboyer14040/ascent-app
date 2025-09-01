//
//  CWTransparentView.mm
//  Ascent
//
//  Created by Rob Boyer on 3/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "CWTransparentView.h"
#import "Utils.h"
#import "DrawingUtilities.h"
#import "Track.h"
#import "TrackPoint.h"
#import <QuartzCore/QuartzCore.h>


#define DOT_DIAM		16.0


@interface DataInfo : NSObject
{
	SEL			accessor;
	SEL			formatter;
	NSString*	label;
	CGColorRef	color;
}
@property(nonatomic, retain, readonly) NSString* label;
@property(nonatomic, readonly) SEL formatter;
@property(nonatomic, assign, readonly) CGColorRef color;
@property(nonatomic, readonly) SEL accessor;

-(id)initWithLabel:(NSString*)label accessor:(SEL)acc formatter:(SEL)frm color:(CGColorRef)clr;

@end;

@implementation DataInfo

@synthesize label;
@synthesize formatter;
@synthesize accessor;
@synthesize color;

-(id)initWithLabel:(NSString*)lbl accessor:(SEL)acc formatter:(SEL)frm color:(CGColorRef)clr
{
	if (self = [super init])
	{
		label = lbl;
		formatter = frm;
		accessor = acc;
		color = clr;
	}
	return self;
}

-(void)dealloc
{
	CGColorRelease(color);
    [super dealloc];
}

@end

@interface CWTransparentView ()
-(NSString*)titleString;
-(NSString*)infoString;
@end


@implementation CWTransparentView

@synthesize track;
@synthesize trackPoint;
@synthesize nextTrackPoint;
@synthesize dataInfoArray;
@synthesize isHighlighted;
@synthesize highlightLayer;
@synthesize showingPace;
@synthesize ratio;


- (id)initWithFrame:(NSRect)frame iconFile:(NSString*)iconFile track:(Track*)tr
{
	self = [super initWithFrame:frame];
	if (self) 
	{
		ratio = 0.0;
		self.trackPoint = nil;
		self.nextTrackPoint = nil;
		showingPace = NO;
		useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		startingOffset = fastestDistance = 0.0;
		self.isHighlighted = NO;
		wasHighlighted = NO;
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
		backgroundColor = CGColorCreateGenericRGB(0.2, 0.2, 0.2, 1.0);
		blackColor = CGColorCreateFromNSColor(colorSpace, [NSColor blackColor]);
		CALayer* l = [[CALayer alloc] init];
		[l setDelegate:self];
		[self setWantsLayer:YES];
		[self setLayer:l];
		
		self.highlightLayer = [[CALayer alloc] init];
		[l addSublayer:self.highlightLayer];
		self.highlightLayer.hidden = NO;
		self.highlightLayer.delegate = self;
		[self.highlightLayer setNeedsDisplay];
	
		self.track = tr;
		CGRect crect = CGRectMake(0.0, 0.0, DOT_DIAM, DOT_DIAM);
		NSString* path = [[NSBundle mainBundle] pathForResource:iconFile ofType:@"png"];
		CGImageRef img = CreateCGImage((CFStringRef)path);
        CALayer* ll = [[CALayer alloc] init];
		ll.contents = (id)img;
		ll.bounds = crect;
		ll.delegate = self;
		ll.name = iconFile;
		ll.hidden = YES;
		ll.opacity = 0.80;
		dotLayer = ll;
		[l insertSublayer:ll
					above:self.highlightLayer];
		startSelectPos = NSZeroPoint;
		///NSFont* font = [NSFont boldSystemFontOfSize:9];
		///animFontAttrs = [[NSMutableDictionary alloc] init];
		///[animFontAttrs setObject:font forKey:NSFontAttributeName];
		///[self prefsChanged];
		// Do stuff with cgColor
		self.dataInfoArray = [NSMutableArray arrayWithObjects:
							  [[DataInfo alloc] initWithLabel:@"Speed"
													  accessor:@selector(speedAsNumber)
													 formatter:@selector(stringsForSpeedValue:)
														 color:CGColorCreateFromNSColor(colorSpace, [Utils colorFromDefaults:RCBDefaultSpeedColor])],
							  [[DataInfo alloc] initWithLabel:@"Heart rate"
																  accessor:@selector(heartrateAsNumber)
																 formatter:@selector(stringsForHeartrateValue:)
																	color:CGColorCreateFromNSColor(colorSpace, [Utils colorFromDefaults:RCBDefaultHeartrateColor])],
                              [[DataInfo alloc] initWithLabel:@"Cadence"
                                                      accessor:@selector(cadenceAsNumber)
                                                     formatter:@selector(stringsForCadenceValue:)
                                                         color:CGColorCreateFromNSColor(colorSpace, [Utils colorFromDefaults:RCBDefaultCadenceColor])] ,
                              [[DataInfo alloc] initWithLabel:@"Power"
                                                      accessor:@selector(powerAsNumber)
                                                     formatter:@selector(stringsForPowerValue:)
                                                         color:CGColorCreateFromNSColor(colorSpace, [Utils colorFromDefaults:RCBDefaultPowerColor])],
										nil];
										 
		CGColorSpaceRelease (colorSpace);
							  
	}
    return self;
}

							  
							  
- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"CW Transparent View dealloc'd...view retain: %d window: %d", [self retainCount], [[self window] retainCount]);
#endif
	self.track = nil;
	self.trackPoint = nil;
	self.nextTrackPoint = nil;
	self.dataInfoArray = nil;
	self.highlightLayer = nil;
	CGColorRelease(backgroundColor);
	CGColorRelease(blackColor);
    [super dealloc];
}
							  
							  

-(void) awakeFromNib
{
}


-(void) prefsChanged
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
}


-(void)setFastestDistance:(float)fd startingOffset:(float)sd
{
	fastestDistance = fd;
	startingOffset = sd;
}



#define TITLE_FONT_SIZE		12.0
#define LEFT_X				4.0


-(void)drawTitles:(CGContextRef)context
{
	CGContextSetFillColorWithColor(context, blackColor); 
	CGRect bounds = self.layer.bounds;
	NSPoint p;
	p.x = LEFT_X;
	p.y = bounds.size.height - (TITLE_FONT_SIZE + 4);
	CGContextSetTextDrawingMode(context, kCGTextFill);
	NSString* s = [self titleString];
	float fontSize = TITLE_FONT_SIZE;
	if (s && ![s isEqualToString:@""])
	{
		CGContextSelectFont (context,
							 "Lucida Grande Bold",
							 fontSize,
							 kCGEncodingMacRoman);
		CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
		p.y -= (TITLE_FONT_SIZE + 1.0);
	}
	CGContextSelectFont (context,
						 "Lucida Grande",
						 fontSize - 2.0,
						 kCGEncodingMacRoman);
	s = [self infoString];
	CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
	
}
	

#define IMPOSSIBLE_TIME		0x7fffffff
#define UNITS_FONT			"Helvetica Bold Oblique"

#define STATUTE_FT_CUTOFF_MILES		(0.1)
#define METRIC_M_CUTOFF_KM			(1.0)

-(NSString*)getUnitsString:(float)dx
{
	NSString* u;
	float cdx = (dx < 0.0) ? -1.0 * dx : dx;
	if (useStatuteUnits) 
	{
		u = (cdx < STATUTE_FT_CUTOFF_MILES) ? @"ft" : @"mi";
	}
	else
	{
		u = (cdx < METRIC_M_CUTOFF_KM) ? @"m" : @"km";
	}
	return u;
}
	

-(NSString*)getDeltaDistanceValueString:(float)dx
{
	float d;
	NSString* fmt;
	float cdx = (dx < 0.0) ? -1.0 * dx : dx;
	if (useStatuteUnits) 
	{
		if (cdx < STATUTE_FT_CUTOFF_MILES) 
		{
			d = dx * 5280.0;
			fmt = @"%3.0f";
		}
		else
		{
			d = dx;
			fmt = @"%0.2f";
		}
	}
	else
	{
		if (cdx < METRIC_M_CUTOFF_KM) 
		{
			d = dx*1000.0;
			fmt = @"%3.0f";
		}
		else
		{
			d = dx;
			fmt = @"%0.2f";
		}
	}
	NSString* s = [NSString stringWithFormat:fmt, d];
	return s;
}

	
-(float)interpolatedDistance
{
	float d = trackPoint.distance;
	if (nextTrackPoint)
	{
		d = trackPoint.distance + (self.ratio * (nextTrackPoint.distance - trackPoint.distance));
	}
	d -= startingOffset;
	return d;
}


-(void)drawCatchupStats:(CGContextRef)context
{
	float d = [self interpolatedDistance];
	float dx = d - fastestDistance;		// should be negative
	d = [Utils convertDistanceValue:d];
	dx = [Utils convertDistanceValue:dx];
	if (dx > -0.001) dx = 0.0;		// about 1.6 meters
	
	float spd = [trackPoint speed];
	NSTimeInterval tx = IMPOSSIBLE_TIME;
	if (spd > 0.0) tx = (-dx*3600.0)/spd;		// to seconds

	// draw UNITS
	CGContextSelectFont (context,
						 UNITS_FONT,
						 10.0,
						 kCGEncodingMacRoman);
	CGContextSetFillColorWithColor(context, blackColor);
	CGContextSetTextDrawingMode(context, kCGTextFill);
	CGRect bounds = self.layer.bounds;
	NSPoint p;
	NSString* units = [self getUnitsString:d];
	CGSize unitsSize = GetCGTextSize(context, units);
	float x = bounds.origin.x + bounds.size.width - 4.0;
	float y = bounds.size.height - 19.0;
	p.x = x - unitsSize.width;
	p.y = y;
	CGContextShowTextAtPoint(context, p.x, p.y, [units UTF8String], [units length]);
	CGSize unitsSizeDX;
	if (dx < 0.0)
	{
		NSString* unitsDX = [self getUnitsString:dx];
		unitsSizeDX = GetCGTextSize(context, units);
		p.x = x - unitsSizeDX.width;
		p.y = y - 16.0;
		CGContextShowTextAtPoint(context, p.x, p.y, [unitsDX UTF8String], [unitsDX length]);
	}
	
	CGContextSelectFont (context,
						 "LCDMono Ultra",
						 14.0,
						 kCGEncodingMacRoman);
	
	// draw CURRENT DISTANCE
	NSString* s = [self getDeltaDistanceValueString:d];
	CGSize size = GetCGTextSize(context, s);
	p.x = x - (unitsSize.width + size.width);
	p.y = y;
	CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
		
	if (dx < 0.0)
	{
		CGContextSelectFont (context,
							 "LCDMono Ultra",
							 13.0,
							 kCGEncodingMacRoman);
		// draw DISTANCE behind
		s = [self getDeltaDistanceValueString:dx];
		size = GetCGTextSize(context, s);
		p.x = x - (unitsSizeDX.width + size.width);
		p.y -= 16.0;
		CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
		
		// draw TIME behind
		if (tx != IMPOSSIBLE_TIME)
		{
			s = [NSString stringWithFormat:@"-%02.2d:%02.2d:%02.2d", (int)(tx/(60*60)), (int)((tx/60))%60, ((int)tx)%60];
			size = GetCGTextSize(context, s);
			p.x = x - size.width;
			p.y -= 14.0;
			CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
		}
	}
}



#define FONT_HEIGHT		20.0

-(float)drawValue:(CGContextRef)context strings:(NSArray*)ss at:(NSPoint)p
{
	CGContextSelectFont (context,
						 "LCDMono Ultra",
						 FONT_HEIGHT,
						 kCGEncodingMacRoman);
	NSString* s = [ss objectAtIndex:0];
	CGSize size = GetCGTextSize(context, s);
	size.height = FONT_HEIGHT;
	float w = size.width;
	CGContextSetTextDrawingMode(context, kCGTextFill);
	CGContextShowTextAtPoint(context, p.x-w, p.y, [s UTF8String], [s length]);
	CGContextSelectFont (context,
						 UNITS_FONT,
						 10.0,
						 kCGEncodingMacRoman);
	s = [ss objectAtIndex:1];
	CGContextShowTextAtPoint(context, p.x, p.y, [s UTF8String], [s length]);
	size = GetCGTextSize(context, s);
	return w + size.width;
}	


-(void)drawData:(CGContextRef)ctx
{
	CGRect bounds = self.layer.bounds;
	NSPoint p;
	p.x = LEFT_X + 62.0;
	p.y = bounds.size.height - 49.0;
	for (DataInfo* dataInfo in dataInfoArray)
	{
		NSNumber* num = [trackPoint performSelector:dataInfo.accessor];
		NSArray* ss = [self performSelector:dataInfo.formatter
									withObject:num];
		CGContextSetFillColorWithColor(ctx, dataInfo.color);
		[self drawValue:ctx
				strings:ss
					 at:p];
		p.x += 76.0;
	}
}


- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
	CGRect bounds = [layer bounds];
	if (layer == self.highlightLayer)
	{
	}
	else if (!layer.name || [layer.name isEqualToString:@""])
	{
		self.highlightLayer.position = CGPointMake(bounds.size.width/2.0, bounds.size.height/2.0);
		self.highlightLayer.bounds = layer.bounds;
		CGContextClearRect(ctx, bounds);
		if (track)
		{
			[self drawTitles:ctx];
			[self drawData:ctx];
			[self drawCatchupStats:ctx];
		}
	}
	else
	{
	}
}


-(void)setShowingPace:(BOOL)en
{
	showingPace = en;
	[self.layer setNeedsDisplay];
}


// (32.0 + 2.0 for vertical ruler width)
#define VERT_RULER_WIDTH		(34.0)

-(void)update:(NSPoint)pt trackPoint:(TrackPoint*)tpt nextTrackPoint:(TrackPoint*)npt ratio:(float)rat needsDisplay:(BOOL)nd;
{
	CGRect bounds = [self.layer bounds];
	NSPoint p = pt;
	BOOL hidden = !self.trackPoint || (p.x < (VERT_RULER_WIDTH-(DOT_DIAM/2.0)));	
	if (!hidden) hidden = (p.x > (bounds.size.width-(VERT_RULER_WIDTH - (DOT_DIAM/2.0))));
	CGPoint cpt = CGPointMake(p.x, p.y);
	///printf("[%0.1f, %0.1f]\n", p.x, p.y);
	[CATransaction setValue:[NSNumber numberWithFloat:0.05f]
					 forKey:kCATransactionAnimationDuration];
	if (hidden != dotLayer.hidden) dotLayer.hidden = hidden;
	dotLayer.position = cpt;
	self.nextTrackPoint = npt;
	self.ratio = rat;
	if (tpt != self.trackPoint)
	{
		self.trackPoint = tpt;
	}
	[self.layer setNeedsDisplay];
}


-(void)setTrack:(Track*)tr
{
	if (track != tr)
	{
		if (tr == nil)
		{
			self.trackPoint = nil;
			dotLayer.hidden = YES;
			track = nil;
		}
		else
			track = tr;
		[self.layer setNeedsDisplay];
	}
}


-(void)setStartSelection:(NSPoint)pt
{
}


-(void)setEndSelection:(NSPoint)pt
{
}


-(void)clearSelection
{
}


-(void)setShowCrossHairs:(BOOL)show
{
}


-(BOOL)showCrossHairs
{
	return FALSE;
}


-(NSArray*)stringsForHeartrateValue:(NSNumber*)nv
{
	return [NSArray arrayWithObjects:[NSString stringWithFormat:@"%0.0f", [nv floatValue]], 
									 @"bpm", nil];
}


-(NSArray*)stringsForPowerValue:(NSNumber*)nv
{
	return [NSArray arrayWithObjects:[NSString stringWithFormat:@"%0.0f", [nv floatValue]], 
			@"watts", nil];
}


-(NSArray*)stringsForCadenceValue:(NSNumber*)nv
{
	return [NSArray arrayWithObjects:[NSString stringWithFormat:@"%0.0f", [nv floatValue]], 
			@"rpm", nil];
}


-(NSArray*)stringsForSpeedValue:(NSNumber*)nv
{
	float v = [nv floatValue];
	if (showingPace)
	{
		NSString* units = @"min/mi";
		if (![Utils usingStatute]) units = @"min/km";
		v = [Utils convertPaceValue:v];
		return [NSArray arrayWithObjects:[Utils convertPaceValueToString:v], 
				units, nil];
	}
	else
	{
		NSString* units = @"mph";
		if (![Utils usingStatute]) units = @"km/h";
		v = [Utils convertSpeedValue:v];
		return [NSArray arrayWithObjects:[NSString stringWithFormat:@"%0.1f", v], 
				units, nil];
	}
}

-(NSString*)titleString
{
	return [track attribute:kName];
}

-(NSString*)infoString
{
	NSDate* startTime = [track creationTime];
	NSString* dt = [Utils activityNameFromDate:track alternateStartTime:startTime];
	NSString* s = [track attribute:kActivity];
	float plotDuration = [track movingDuration];
	s = [s stringByAppendingString:[NSString stringWithFormat:@" for %02.2d:%02.2d:%02.2d on ",
									(int)(plotDuration/3600.0), (int)(((int)plotDuration/60)%60), ((int)plotDuration)%60]];
	s = [s stringByAppendingString:dt];
	NSString* eventType = [track attribute:kEventType];
	if ((eventType != nil) && (![eventType isEqualToString:@""]))
	{
		s = [s stringByAppendingString:@" ("];
		s = [s stringByAppendingString:eventType];
		s = [s stringByAppendingString:@")"];
	}
	return s;
}


@end
