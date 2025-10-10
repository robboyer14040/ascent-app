//
//  CWTransparentMapView.mm
//  Ascent
//
//  Created by Rob Boyer on 3/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "CWTransparentMapView.h"
#import "Utils.h"
#import "DrawingUtilities.h"
#import <QuartzCore/QuartzCore.h>

@interface DotImageInfo : NSObject
{
	CGImage*		cgimage;
	CALayer*		layer;
	NSPoint			pos;
}
@property (nonatomic, retain) CALayer* layer;
@property (nonatomic) NSPoint pos;
-(id)initWithCGImage:(CGImage*)img layer:(CALayer*)ll;
@end


@implementation DotImageInfo
@synthesize layer;
@synthesize pos;
-(id)initWithCGImage:(CGImage*)img layer:(CALayer*)ll
{
	if (self = [super init])
	{
		cgimage = img;
		self.layer = ll;
	}
	return self;
}


-(void)dealloc
{
	self.layer = nil;
	CFRelease(cgimage);
    [super dealloc];
}

@end


#define DOT_DIAM		16.0
@implementation CWTransparentMapView

@synthesize zoomedInMapRect;
@synthesize zoomedRectLayer;

- (id)initWithFrame:(NSRect)frame dotColors:(NSArray*)dots
{
	self = [super initWithFrame:frame];
	if (self) 
	{
		CALayer* l = [[[CALayer alloc] init] autorelease];
		[l setDelegate:self];
		[self setWantsLayer:YES];
		[self setLayer:l];
		[l setDelegate:self];
		[l setNeedsDisplay];
		startSelectPos = NSZeroPoint;
		dotImageInfoArray = [[NSMutableArray arrayWithCapacity:[dots count]] retain];   /// fixme added retain
		NSRect fr;
		fr.origin = NSZeroPoint;
		for (NSString* dotColor in dots)
		{
				NSString* path = [[NSBundle mainBundle] pathForResource:dotColor 
															 ofType:@"png"];
			CGRect crect = CGRectMake(0.0, 0.0, DOT_DIAM, DOT_DIAM);
			CGImageRef img = CreateCGImage((CFStringRef)path);
			CALayer* ll = [[[CALayer alloc] init] autorelease];
			ll.contents = (id)img;
			ll.bounds = crect;
			ll.delegate = self;
			ll.name = dotColor;
			[l addSublayer:ll];
			ll.hidden = YES;
			ll.opacity = 0.80;
			DotImageInfo* info = [[DotImageInfo alloc] initWithCGImage:img
																  layer:ll];
			[dotImageInfoArray addObject:info];
		}
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB ();
		whiteColor = CGColorCreateFromNSColor(colorSpace, [NSColor whiteColor]);
		redColor = CGColorCreateFromNSColor(colorSpace, [NSColor redColor]);
		CGColorSpaceRelease (colorSpace);
		
		self.zoomedRectLayer = [[CALayer alloc] init];
		self.zoomedRectLayer.name = @"ZRect";
		self.zoomedRectLayer.delegate = self;
		self.zoomedRectLayer.bounds = l.bounds;
		self.zoomedRectLayer.hidden = NO;
		self.zoomedRectLayer.position = CGPointMake(0.0, 0.0);
		[l addSublayer:self.zoomedRectLayer];
		[self.zoomedRectLayer setNeedsDisplay];
		[self prefsChanged];
	}
    return self;
}


-(void) awakeFromNib
{
}


-(void) prefsChanged
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
}



- (void) dealloc
{
	CGColorRelease(whiteColor);
	CGColorRelease(redColor);
	self.zoomedRectLayer = nil;
    [super dealloc];
}

	
-(void)drawZoomRect:(CGContextRef)ctx layer:(CALayer*)l
{
	if (zoomedInMapRect.size.width > 0.0)
	{
		float x = 0;
		float y = 0;
		CGRect cr = CGRectMake(x+0.0, y+0.0, zoomedInMapRect.size.width-0.0, zoomedInMapRect.size.height-0.0); 
		//CGRect bounds = zoomedInMapRect;
		CGContextClearRect(ctx, cr);
		CGContextSetLineWidth(ctx, 2.0);
		CGContextSetStrokeColorWithColor(ctx, whiteColor); 
		CGContextStrokeRect(ctx, cr);
	}
}



- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
	if (!layer.name || [layer.name isEqualToString:@""])
	{
		CGRect bounds = [layer bounds];
		CGContextClearRect(ctx,bounds);
	}
	else if (layer == self.zoomedRectLayer)
	{
		[self drawZoomRect:ctx
					 layer:layer];
	}
}


	
- (void)viewDidEndLiveResize
{
	[self.layer setNeedsDisplay];
}


-(void)setZoomedInMapRect:(NSRect)zr
{
	self.zoomedRectLayer.bounds = CGRectMake(-2.0, -2.0, zr.size.width+4.0, zr.size.height+4.0);
	
	zoomedInMapRect = zr;
	///CGRect mfr = zoomedRectLayer.frame;
	///CGPoint mpt = zoomedRectLayer.position;
	///CGPoint apt = zoomedRectLayer.anchorPoint;
	// calc midpoint of rect
	float x = zr.origin.x + (zr.size.width/2.0);
	float y = zr.origin.y + (zr.size.height/2.0);
	zoomedRectLayer.position = CGPointMake(x,y);
	if (!NSEqualRects(lastZoomedInMapRect, zoomedInMapRect))
	{
		[zoomedRectLayer setNeedsDisplay];
		lastZoomedInMapRect = zoomedInMapRect;
	}
}


-(void)update:(NSPoint)pt trackPoint:(TrackPoint*)tpt animID:(int)aid
{
	if (aid < [dotImageInfoArray count])
	{
		DotImageInfo* info = [dotImageInfoArray objectAtIndex:aid];
		CGRect bounds = [self.layer bounds];
		bounds = CGRectInset(bounds, 6.0 + (DOT_DIAM/2.0), 6.0 + (DOT_DIAM/2.0));
		CGPoint cpt = CGPointMake(pt.x, pt.y);
		if (CGRectContainsPoint(bounds, cpt))
		{
			///CGRect cfr = info.layer.frame;
			[CATransaction setValue:[NSNumber numberWithFloat:0.05f]
							 forKey:kCATransactionAnimationDuration];
			info.layer.position = cpt;
			if (info.layer.hidden) 
			{
				info.layer.hidden = NO;
			}
		}
		else
		{
			info.layer.hidden = YES;
		}
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


-(void)setAllDotsHidden
{
	for (DotImageInfo* info in dotImageInfoArray)
	{
		info.layer.hidden = YES;
		info.layer.position = CGPointMake(-10000.0, -10000.0);
	}
}


@end
