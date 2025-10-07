//
//  ActivityDetailTransparentView.mm
//  Ascent
//
//  Created by Rob Boyer on 11/29/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "ActivityDetailTransparentView.h"
#import "Defs.h"
#import "Utils.h"
#import "TrackPoint.h"



NSString*      altFormat;
NSString*      speedFormat;

@implementation ActivityDetailTransparentView

- (id)initWithFrame:(NSRect)frame 
{
	self = [super initWithFrame:frame];
	if (self) 
	{
		// Initialization code here.
		startSelectPos = NSZeroPoint;
		NSString* path = [[NSBundle mainBundle] pathForResource:@"AHud" ofType:@"png"];
		dataRectImage = [[NSImage alloc] initWithContentsOfFile:path];
		path = [[NSBundle mainBundle] pathForResource:@"Dot" ofType:@"png"];
		dotImage = [[NSImage alloc] initWithContentsOfFile:path];
		//[self setHidden:YES];
		NSFont* font;;
		font = [NSFont boldSystemFontOfSize:9];
		animFontAttrs = [[NSMutableDictionary alloc] init];
		[animFontAttrs setObject:font forKey:NSFontAttributeName];
		font = [NSFont boldSystemFontOfSize:12];
		selectTextAttrs = [[NSMutableDictionary alloc] init];
		[selectTextAttrs setObject:font forKey:NSFontAttributeName];
		[selectTextAttrs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		showCrossHairs = NO;
		[self prefsChanged];
	}
    return self;
}


-(void) awakeFromNib
{
   //[self setHidden:YES];
}


-(void) prefsChanged
{
   useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
#if 0
	if (useStatuteUnits)
   {
      altFormat = @"%1.0fft";
      speedFormat = @"%1.1fmph";
   }
   else
   {
      altFormat = @"%1.0fm";
      speedFormat = @"%1.1fkm/h";
   }
#endif
}



- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"AD Transparent View dealloc'd...view retain: %d window: %d", [self retainCount], [[self window] retainCount]);
#endif
	[selectTextAttrs release];
	[animFontAttrs release];
	[dotImage release];
	[dataRectImage release];
	[super dealloc];
}


- (void)drawRect:(NSRect)rect 
{
	NSRect imageRect;
	imageRect.origin = NSZeroPoint;
	NSPoint pt;
	NSRect bounds = [self bounds];

	if (showCrossHairs)
	{
		[[NSColor colorNamed:@"TextPrimary"] set];
		[NSBezierPath setDefaultLineWidth:0.4];
		NSPoint pt1, pt2;

		pt1.x = (int)bounds.origin.x;
		pt1.y = (int)(pos.y);
		pt2.x = (int)(bounds.origin.x + bounds.size.width);
		pt2.y = pt1.y;
		[NSBezierPath strokeLineFromPoint:pt1 toPoint:pt2];

		pt1.x = (int)(pos.x);
		pt1.y = (int)bounds.origin.y;
		pt2.x = pt1.x;
		//pt2.y = (int)(pos.y);
		pt2.y = (int)(bounds.origin.y + bounds.size.height) - (ACTIVITY_VIEW_TOP_AREA_HEIGHT+14);
		[NSBezierPath strokeLineFromPoint:pt1 toPoint:pt2];
	}

	imageRect.size = [dotImage size];
	pt.x = pos.x - imageRect.size.width/2.0;
	pt.y =  pos.y  + Y_ROAD_ADJUST - imageRect.size.height/2.0;
	NSRect drect;
	drect.origin = pt;
	drect.size = imageRect.size;
	[dotImage drawInRect:drect
				fromRect:imageRect
			   operation:NSCompositingOperationSourceOver
				fraction:1.0];
	
	if (inSelection)
	{
		NSRect selRect;
		selRect.origin.x = startSelectPos.x;
		selRect.origin.y = 0;
		selRect.size.width = endSelectPos.x - startSelectPos.x;
		selRect.size.height = bounds.size.height; 
		NSColor* clr = [NSColor grayColor];
		clr = [clr colorWithAlphaComponent:.35];
		[clr set];
		[NSBezierPath fillRect:selRect];
	}

    [self.window displayIfNeeded];                 // window-wide
    [self.window.contentView displayIfNeeded];     // specific subtree
}


-(void)update:(NSPoint)pt trackPoint:(TrackPoint*)tpt nextTrackPoint:(TrackPoint*)npt ratio:(float)ratio needsDisplay:(BOOL)nd;
{
   pos = pt;
   pos.x = pos.x;
   pos.y = pos.y;
   trackPoint = tpt;
  /// NSRect bounds = [self bounds];
   [self setNeedsDisplay:nd];
}


-(void)setShowCrossHairs:(BOOL)show
{
   showCrossHairs = show;
   [self setNeedsDisplay:YES];
}


-(BOOL)showCrossHairs
{
   return showCrossHairs;
}


-(void)clearSelection
{
	inSelection = NO;
	startSelectPos = NSZeroPoint;
}

-(void)setStartSelection:(NSPoint)pt
{
	inSelection = ((endSelectPos.x != 0.0) || (endSelectPos.y != 0.0));
	startSelectPos = pt;
}


-(void)setEndSelection:(NSPoint)pt
{
	inSelection = ((startSelectPos.x != 0.0) || (startSelectPos.y != 0.0));
	endSelectPos = pt;
}

@end


