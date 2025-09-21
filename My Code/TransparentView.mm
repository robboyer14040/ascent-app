//
//  TransparentView.mm
//  Ascent
//
//  Created by Rob Boyer on 4/2/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "TransparentView.h"


@implementation TransparentView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		NSFont* font = [NSFont systemFontOfSize:14];
		textFontAttrs = [[NSMutableDictionary alloc] init];
		[textFontAttrs setObject:font forKey:NSFontAttributeName];
		[textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
		centeredText = nil;
    }
    return self;
}

-(void) dealloc
{
}


-(void) awakeFromNib
{
 
}

-(void) setCenteredText:(NSString*)s
{
	if (s != centeredText)
	{
		centeredText = s;
		[self setNeedsDisplay:YES];
	}
}



- (void)drawRect:(NSRect)rect 
{
	if (centeredText)
	{
		NSRect dbounds = [self bounds];
		NSSize size = [centeredText sizeWithAttributes:textFontAttrs];
		float x = dbounds.origin.x + dbounds.size.width/2.0 - size.width/2.0;
		float y = (dbounds.size.height/2.0) - (size.height/2.0);
		[textFontAttrs setObject:[[NSColor colorNamed:@"TextPrimary"] colorWithAlphaComponent:0.50] forKey:NSForegroundColorAttributeName];
		[centeredText drawAtPoint:NSMakePoint(x,y) 
		withAttributes:textFontAttrs];
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
   if (mMouseDownInvocation != nil)
   {
      [mMouseDownInvocation invoke];
   }
}


-(void) setMouseDownInvocation:(NSInvocation*)inv
{
   if (inv != mMouseDownInvocation)
   {
      mMouseDownInvocation = inv;
   }
}


@end
