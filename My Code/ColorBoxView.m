//
//  ColorBoxView.m
//  TLP
//
//  Created by Rob Boyer on 10/1/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "ColorBoxView.h"
#import "Utils.h"

@implementation ColorBoxView


- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		alpha = 1.0;
		color = nil;
		// Add initialization code here
	}
   return self;
}

- (void) dealloc
{
}


-(void)setColor:(NSColor*)c
{
	if (color != c)
	{
	}
}


- (void)drawRect:(NSRect)rect
{
	NSColor* clr = color;
	if (!clr)
	{
		NSString* colorKey = [Utils defaultColorKey:tag];
		if (colorKey != nil)
		{
			clr = [Utils colorFromDefaults:colorKey];
		}
	}
	if (clr)
	{
		NSRect r = [self bounds];
		clr = [clr colorWithAlphaComponent:alpha];
		[clr set];
		[clr setFill];
		[NSBezierPath setDefaultLineWidth:1.0];
		[[NSBezierPath bezierPathWithRect:r] fill];
		[[NSColor blackColor] set];
		[NSBezierPath strokeRect:r];
	}
}

- (BOOL) isOpaque
{
   return NO;
}


-(void)setTag:(NSInteger)t
{
   tag = t;
}

-(NSInteger)tag
{
   return tag;
}


-(void)setAlpha:(float)a
{
   alpha = a;
   [self setNeedsDisplay:YES];
}

-(int)alpha
{
   return alpha;
}


@end
