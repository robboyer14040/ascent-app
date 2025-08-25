//
//  ProfilesTransparentView.mm
//  Ascent
//
//  Created by Rob Boyer on 4/10/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "ProfilesTransparentView.h"
#import "Utils.h"
#import "DrawingUtilities.h"
#import <QuartzCore/QuartzCore.h>


@interface ProfilesTransparentView ()
@property (nonatomic, retain) NSMutableDictionary* tickFontAttrs;
@property (nonatomic, retain) CALayer* animLayer;
@property (nonatomic, retain) CALayer* focusLayer;
-(BOOL)compareRegionSelected;
- (NSRect)plotBounds;
@end


@implementation ProfilesTransparentView

@synthesize minDist;
@synthesize maxDist;
@synthesize curDist;
@synthesize startRegionDist;
@synthesize endRegionDist;
@synthesize tickFontAttrs;
@synthesize rulerBounds;
@synthesize animLayer;
@synthesize focusLayer;
@synthesize contextualMenuInvocation;
@synthesize hidePosition;

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		focusAnimID = 0;
		focusDistance = -1;
		hidePosition = NO;
		self.contextualMenuInvocation = nil;
		dragging = NO;
		CALayer* l = [[CALayer alloc] init] ;
		l.delegate = self;
		l.name = @"Fixed";
		[self setLayer:l];
 		[self setWantsLayer:YES];
		self.minDist = self.maxDist = self.curDist = 0.0;
		l.hidden = NO;
		
		CALayer* ll = [[CALayer alloc] init];
		ll.name = @"Anim";
		ll.delegate = self;
		ll.hidden = NO;
		ll.opacity = 0.8;
		[l addSublayer:ll];
		ll.anchorPoint = CGPointMake(0.0, 0.0);
		ll.position = CGPointMake(0.0, 0.0);
		self.animLayer = ll;
		self.rulerBounds.origin = NSZeroPoint;
		self.rulerBounds.size = NSZeroSize;
		NSFont* font = [NSFont systemFontOfSize:8];
		self.tickFontAttrs = [[NSMutableDictionary alloc] init];
		[tickFontAttrs setObject:font forKey:NSFontAttributeName];
		
		NSString* path = [[NSBundle mainBundle] pathForResource:@"RulerThumb" 
														 ofType:@"png"];
		thumbImage = CreateCGImage((CFStringRef)path);
		path = [[NSBundle mainBundle] pathForResource:@"RulerBG" 
											   ofType:@"png"];
		rulerBGImage = CreateCGImage((CFStringRef)path);
		
		animColors[0] = CGColorCreateGenericRGB(200.0/255.0, 203.0/255.0,   0.0/255.0, 1.0);	// yellow
		animColors[1] = CGColorCreateGenericRGB(  0.0/255.0, 147.0/255.0, 224.0/255.0, 1.0);	// blue
		animColors[2] = CGColorCreateGenericRGB( 35.0/255.0, 222.0/255.0,   0.0/255.0, 1.0);	// green;
		animColors[3] = CGColorCreateGenericRGB(238.0/255.0,   0.0/255.0, 232.0/255.0, 1.0);	// purple
		
		self.focusLayer = [[CALayer alloc] init];
		focusLayer.name = @"Focus";
		focusLayer.delegate = self;
		focusLayer.hidden = YES;
		focusLayer.opacity = 1.0;
		focusLayer.anchorPoint = CGPointMake(0.0, 0.0);
		focusLayer.position = CGPointMake(0.0, 0.0);
		[l addSublayer:focusLayer];
		
	}
    return self;
}


-(void)dealloc
{
	for (int i=0;i<sizeof(animColors)/sizeof(CGColorRef); i++)
	{
		CGColorRelease(animColors[i]);
	}
	CGImageRelease(rulerBGImage);
	CGImageRelease(thumbImage);
	self.contextualMenuInvocation = nil;
	self.animLayer = nil;
	self.focusLayer = nil;
	self.tickFontAttrs = nil;
}



#define VERT_RULER_HORIZ_SPACING    30

struct tPosInfo
{
	int axis;
	float offset;
} ;


- (struct tPosInfo) getPosInfo:(int)idx
{
	int numPlots = 2;
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
			info.offset = (VERT_RULER_HORIZ_SPACING*(int)((numPlots)/2));
			break;
			
		case 2:
			info.axis = kVerticalLeft;
			info.offset = ((numPlots % 2) == 0) ? VERT_RULER_HORIZ_SPACING*(int)((numPlots-2)/2) : VERT_RULER_HORIZ_SPACING*(int)((numPlots)/2);
			break;
			
		case 3:
			info.axis = kVerticalRight;
			info.offset = (VERT_RULER_HORIZ_SPACING* (int)((numPlots-2)/2));
			break;
			
		case 4:
			info.axis = kVerticalLeft;
			info.offset = ((numPlots % 2) == 0) ? VERT_RULER_HORIZ_SPACING*(int)((numPlots-4)/2) : VERT_RULER_HORIZ_SPACING*(int)((numPlots-2)/2);
			break;
			
		case 5:
			info.axis = kVerticalRight;
			info.offset = (VERT_RULER_HORIZ_SPACING* (int)((numPlots-4)/2));
			break;
	}
	return info;
}


-(NSRect)thumbTrackingRect
{
	NSRect r;
	r.size = NSMakeSize(20.0, 20.0);
	float rx = rulerBounds.origin.x + (rulerBounds.size.width * (curDist - minDist)/(maxDist - minDist));
	float ry = rulerBounds.origin.y - 6.0;
	r.origin = NSMakePoint(rx, ry);
	return r;
}	




-(void)layoutViewSublayers
{
	///CGRect cfr = self.layer.frame;
	///CGRect cbds = self.layer.bounds;
	animLayer.frame = self.layer.frame;
	animLayer.bounds = self.layer.bounds;
#if 0
	// Leopard bug was causing this layer to draw at the wrong position.  some problem related to split views??
	// solution was to call this method after the window was loaded.
	NSLog(@"AnimLayer:layoutViewSublayers:\n  frame:[%0.0f,%0.0f] %0.0fx%0.0f\n  bounds:[%0.0f,%0.0f] %0.0fx%0.0f\n  pos:[%0.0f,%0.0f], anchor:[%0.0f,%0.0f]", 
		  animLayer.frame.origin.x, animLayer.frame.origin.y, 
		  animLayer.frame.size.width, animLayer.frame.size.height,
		  animLayer.bounds.origin.x, animLayer.bounds.origin.y, 
		  animLayer.bounds.size.width, animLayer.bounds.size.height,
		  animLayer.position.x, animLayer.position.y,
		  animLayer.anchorPoint.x, animLayer.anchorPoint.y);
#endif
	self.rulerBounds = [self plotBounds];
	
	[animLayer setNeedsDisplay];
	focusLayer.bounds = self.layer.bounds;
	[focusLayer setNeedsDisplay];
}


-(void)updateAll
{
	[animLayer setNeedsDisplay];
	[self.layer setNeedsDisplay];
}

- (NSRect) drawBounds
{
	return NSInsetRect([self bounds], 4.0, 0.0);
}

- (NSRect)plotBounds
{
	int numPlots = 2;
	float xLeftInset = 0;
	float xRightInset = 0;
	bool showVerticalTicks = YES;
	if (showVerticalTicks && (numPlots > 0))
	{
		struct tPosInfo info = [self getPosInfo:0];
		xLeftInset = info.offset;
		info = [self getPosInfo:1];
		xRightInset = info.offset;
	}
	NSRect plotBounds = NSInsetRect([self drawBounds], 2.0, 0.0);
	plotBounds.origin.x += (xLeftInset);
	plotBounds.origin.y = plotBounds.size.height - RULER_HEIGHT + 4.0;
	plotBounds.size.width -= (xRightInset + xLeftInset);
	plotBounds.size.height = RULER_HEIGHT;
	return plotBounds;
}


-(void)drawRuler:(CALayer*)layer inContext:(CGContextRef)ctx
{
	CGRect cbounds = layer.bounds;
	cbounds.origin.y = cbounds.origin.y + cbounds.size.height - 24.0;
	cbounds.size.height = 24.0;
	CGContextDrawImage(ctx, cbounds, rulerBGImage);
	
	// draw the shaded regions that are NOT going to be compared
	if ([self compareRegionSelected])
	{
		float xl = rulerBounds.origin.x;
		float xr = rulerBounds.origin.x + (rulerBounds.size.width * (self.startRegionDist - minDist)/(maxDist - minDist));
		float y = self.bounds.origin.y;
		float h = self.bounds.size.height - (rulerBounds.size.height);
		CGRect r = CGRectMake(xl, y, (xr-xl), h);
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
		NSColor* clr = [NSColor colorWithCalibratedRed:150.0/255.0
												 green:150.0/255.0
												  blue:150.0/255.0
												 alpha:0.42];
		
		CGContextSetFillColorWithColor(ctx, CGColorCreateFromNSColor(colorSpace, clr)); 
		CGContextFillRect(ctx, r);
		
		xl = rulerBounds.origin.x + (rulerBounds.size.width * (self.endRegionDist - minDist)/(maxDist - minDist));
		xr = rulerBounds.origin.x + rulerBounds.size.width;
		r = CGRectMake(xl, y, (xr-xl), h);
		CGContextFillRect(ctx, r);
	}
	
	
	NSGraphicsContext *nsGraphicsContext;
	nsGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx
																   flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsGraphicsContext];

	NSRect horizTickBounds = [self plotBounds];
	int maxHorizTicks = ((int)(horizTickBounds.size.width/20.0)) & 0xfffffffe;
	[tickFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	float incr = 0.0;
	float tmxd = [Utils convertDistanceValue:maxDist];
	float tmnd = [Utils convertDistanceValue:minDist];
	
	int numHorizTicks = AdjustDistRuler(maxHorizTicks, tmnd, tmxd, &incr);
	self.rulerBounds = horizTickBounds;
#if 0
	if (tmxd > tmnd)
		self.rulerBounds.size.width = (numHorizTicks*incr*self.rulerBounds.size.width)/(tmxd-tmnd);
	else
		self.rulerBounds.size.width = 1.0;
	DUDrawTickMarks(self.rulerBounds, (int)kHorizontal, 0.0, tmnd, tmnd + (numHorizTicks*incr), numHorizTicks, tickFontAttrs, NO, 
					horizTickBounds.origin.x + horizTickBounds.size.width);
#endif
	DUDrawTickMarks(self.rulerBounds, (int)kHorizontal, 0.0, tmnd, tmxd, numHorizTicks, tickFontAttrs, NO, 
					horizTickBounds.origin.x + horizTickBounds.size.width);
	
	[NSGraphicsContext restoreGraphicsState];
	
	
	
}	


-(void)setFocusDistance:(float)fd animID:(int)aid;
{
	focusDistance = fd;
	if (aid != focusAnimID)
	{
		[focusLayer setNeedsDisplay];
		focusAnimID = aid;
	}
	float x = (rulerBounds.size.width * (focusDistance)/(maxDist - minDist));
	float y = focusLayer.position.y;
	focusLayer.position = CGPointMake(x,y);
	focusLayer.hidden = !hidePosition || (focusDistance > (maxDist-minDist));
}


-(void)drawAnimLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
	// make *sure* the frame, bounds, position, etc are what we think they should be
	layer.frame = self.layer.frame;
	layer.bounds = self.layer.bounds;
	layer.position = CGPointMake(0.0, 0.0);
#if 0
	// see comments above about Leopard bug
	NSLog(@"AnimLayer:drawAnimLayer: [%0.1f,%0.1f] %0.1fx%0.1f", 
		  layer.bounds.origin.x, layer.bounds.origin.y, 
		  layer.bounds.size.width, layer.bounds.size.height);
#endif
	if (rulerBounds.origin.y == 0.0) self.rulerBounds = [self plotBounds];
	float rx = rulerBounds.origin.x;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
	CGContextClearRect(ctx,layer.bounds);
#if 0
	// was used to debug layer positioning problems
	CGContextSetStrokeColorWithColor(ctx, CGColorCreateFromNSColor(colorSpace, [NSColor redColor])); 
	CGContextSetLineWidth(ctx,2.0);
	CGContextStrokeRect(ctx, layer.bounds);
	CGContextSetStrokeColorWithColor(ctx, CGColorCreateFromNSColor(colorSpace, [NSColor greenColor])); 
	CGContextStrokeRect(ctx, NSRectToCGRect(self.rulerBounds));
#endif	
	
	CGContextSetLineWidth(ctx,1.0);
	CGContextSetStrokeColorWithColor(ctx, CGColorCreateFromNSColor(colorSpace, [NSColor darkGrayColor])); 
	CGPoint p[2];
	if (maxDist > minDist)
	{
		p[0].x = p[1].x = rx + (rulerBounds.size.width * (curDist - minDist)/(maxDist - minDist));
		p[0].y = 10.0;
		p[1].y = rulerBounds.origin.y;
		if (!hidePosition)
		{
			// draw the vertical line
			CGContextStrokeLineSegments(ctx, p, 2);
		}
		// draw the thumbnail
		CGRect r;
		r.origin.x = p[1].x - 10.0;
		r.origin.y = p[1].y - 4.0;
		r.size = CGSizeMake(20.0, 20.0);
		CGContextDrawImage(ctx, r, thumbImage);
	}
}

-(void)drawFocusLayer:(CGContextRef)ctx
{
	if (focusAnimID >= 0)
	{
		CGPoint p[2];
		float rx = rulerBounds.origin.x;
		p[0].x = p[1].x = rx;
		p[0].y = 4.0;
		p[1].y = rulerBounds.origin.y + 13.0;
		// draw the vertical line
		CGContextSetStrokeColorWithColor(ctx, animColors[focusAnimID]); 
		CGContextSetLineWidth(ctx, 1.0);
		CGContextStrokeLineSegments(ctx, p, 2);
	}
}


- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
	CGContextClearRect(ctx,layer.bounds);
	if ([layer.name isEqualToString:@"Fixed"])
	{
		//printf("f");
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
		CGContextSetStrokeColorWithColor(ctx, CGColorCreateFromNSColor(colorSpace, [NSColor blackColor])); 
		CGContextSetLineWidth(ctx, 1.0);
		CGContextStrokeRect(ctx, layer.bounds);
		[self drawRuler:layer
			  inContext:ctx];
	}
	else if ([layer.name isEqualToString:@"Anim"])
	{
		//printf("a");
		[self drawAnimLayer:layer
				  inContext:ctx];
	}
	else if ([layer.name isEqualToString:@"Focus"])
	{
		[self drawFocusLayer:ctx];
	}
}


-(void)setMinDist:(float)v
{
	minDist = v;
	self.startRegionDist = v;
}

-(void)setMaxDist:(float)v
{
	maxDist = v;
	self.endRegionDist = v;
}


-(void)setCurDist:(float)v
{
	curDist = v;
	[animLayer setNeedsDisplay];
	[self.layer setNeedsDisplay];
}


-(void)setHidePosition:(BOOL)hide
{
	focusLayer.hidden = !hide;
	hidePosition = hide;
	[animLayer setNeedsDisplay];
}


-(void)setCompareRegionStart
{
	if (curDist < self.endRegionDist)
	{
		self.startRegionDist = curDist;
		[self.layer setNeedsDisplay];
	}
}


-(void)setCompareRegionEnd
{
	if (curDist > self.startRegionDist)
	{
		self.endRegionDist = curDist;
		[self.layer setNeedsDisplay];
	}
}


-(void)zoomToSelection
{
	self.minDist = self.startRegionDist;
	self.maxDist = self.endRegionDist;
	self.curDist = self.minDist;
	[self unselectCompareRegion];
	[self updateAll];
}


-(void)zoomOut:(float)min max:(float)max
{
	self.startRegionDist = self.minDist;
	self.endRegionDist = self.maxDist;
	minDist = 0;
	maxDist = max;
	[self updateAll];
}


-(void)unselectCompareRegion
{
	self.startRegionDist = minDist;
	self.endRegionDist = maxDist;
	[self.layer setNeedsDisplay];
}


-(BOOL)compareRegionSelected
{
	return ((self.startRegionDist != minDist) ||
			(self.endRegionDist != maxDist));
}


-(void)prefsChanged
{
	[self updateAll];
}


-(void)processMouseMove:(NSEvent*)ev
{
	NSPoint evLoc = [ev locationInWindow];
	evLoc = [self convertPoint:evLoc fromView:nil];
	float rx = rulerBounds.origin.x;
	float rxmax = rulerBounds.origin.x + rulerBounds.size.width;
	if (evLoc.x < rx) evLoc.x = rx;
	if (evLoc.x > rxmax)evLoc.x = rxmax;
	self.curDist = minDist + ((maxDist - minDist)* (evLoc.x - rx) / rulerBounds.size.width);
}


- (void)mouseDown:(NSEvent*) ev
{
	NSPoint evLoc = [ev locationInWindow];
	evLoc = [self convertPoint:evLoc fromView:nil];
	NSRect r = rulerBounds;
	r.origin.y -= 8.0;
	r.size.height += 8.0;
	if (NSPointInRect(evLoc, r))
	{
		dragging = YES;
		[self processMouseMove:ev];
	}
	else
	{
		[super mouseDown:ev];
	}
}


- (void)mouseDragged:(NSEvent *)ev
{
	if (dragging)
	{
		[self processMouseMove:ev];
	}
	else
	{
		[super mouseDragged:ev];
	}
}


- (void)mouseUp:(NSEvent*) ev
{
	dragging = NO;
	[super mouseUp:ev];
}


- (void)rightMouseDown:(NSEvent*) ev
{
	NSPoint evLoc = [ev locationInWindow];
	evLoc = [self convertPoint:evLoc fromView:nil];
	NSRect r = rulerBounds;
	r.origin.y -= 8.0;
	r.size.height += 8.0;
	if (!NSPointInRect(evLoc, r))
	{
		[self mouseDown:ev];
		[super rightMouseDown:ev];
	}
}



- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	[contextualMenuInvocation invoke];
	NSMenu* menu;
	[contextualMenuInvocation getReturnValue:&menu];
	return menu;
}

@end
