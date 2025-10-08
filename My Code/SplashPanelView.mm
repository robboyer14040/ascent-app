//
//  SplashPanelView.mm
//  Ascent
//
//  Created by Rob Boyer on 1/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "SplashPanelView.h"
#import "Defs.h"

@implementation SplashPanelView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) 
    {
       progressText = @"initializing...";
        // Initialization code here.
       NSString* path = [[NSBundle mainBundle] pathForResource:@"Splash" ofType:@"png"];
       backgroundImage = [[NSImage alloc] initWithContentsOfFile:path];
       {
		   userName = [[NSMutableString stringWithString:@"** UNREGISTERED **"] retain];
		   regCode =  [[NSMutableString stringWithString:@""] retain];
		   email =  [[NSMutableString stringWithString:@""] retain];
       }
    }
    return self;
}


-(void)dealloc
{
	[userName release];
	[regCode release];
	[email release];
	[backgroundImage release];
	[super dealloc];
}


#define LEFT_TEXT_X     30
#define REG_INFO_Y      90

- (void)drawRect:(NSRect)rect 
{
    // Drawing code here.
   NSRect bounds = [self bounds];
   [backgroundImage setSize:bounds.size];
   [backgroundImage drawAtPoint:NSMakePoint(0,0)
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                    fraction:1.0];
   NSString* s = @"Ascent: GPS-Enabled Training";
   NSFont* font = [NSFont boldSystemFontOfSize:18];
   NSMutableDictionary* fontAttrs = [[[NSMutableDictionary alloc] init] autorelease];
   NSColor* clr = [NSColor whiteColor];   
   [clr set];
   [fontAttrs setObject:font forKey:NSFontAttributeName];
   [fontAttrs setObject:clr forKey:NSForegroundColorAttributeName];
   [s drawAtPoint:NSMakePoint(LEFT_TEXT_X, 172) withAttributes:fontAttrs];
   font = [NSFont boldSystemFontOfSize:12]; 
   [fontAttrs setObject:font forKey:NSFontAttributeName];
   s = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
   if (s != nil)
   {  
      s = [@"Version " stringByAppendingString : s];
      //[longVersionText setStringValue: value];
      [s drawAtPoint:NSMakePoint(LEFT_TEXT_X, 154) withAttributes:fontAttrs];
   }
   
   if ([regCode compare:@""] != NSOrderedSame)
   {
      font = [NSFont boldSystemFontOfSize:10]; 
      [fontAttrs setObject:font forKey:NSFontAttributeName];
      [@"Registered to:" drawAtPoint:NSMakePoint(LEFT_TEXT_X, REG_INFO_Y) withAttributes:fontAttrs];
   }
   font = [NSFont boldSystemFontOfSize:11]; 
   [fontAttrs setObject:font forKey:NSFontAttributeName];
   [userName drawAtPoint:NSMakePoint(LEFT_TEXT_X, REG_INFO_Y - 14) withAttributes:fontAttrs];
   [regCode drawAtPoint:NSMakePoint(LEFT_TEXT_X, REG_INFO_Y - 27) withAttributes:fontAttrs];

   float x = bounds.size.width/2.0;
   NSSize size = [progressText sizeWithAttributes:fontAttrs];
   x -= (size.width/2.0);
   [progressText drawAtPoint:NSMakePoint(x, 10) withAttributes:fontAttrs];
}


- (void) updateProgress:(NSString*)msg
{
	if (msg != progressText)
	{
		[progressText release];
		progressText = [msg retain];
	}
	[self setNeedsDisplay:YES];
}
@end
