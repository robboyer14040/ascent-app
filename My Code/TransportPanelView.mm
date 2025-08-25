//
//  TransportPanelView.mm
//  Ascent
//
//  Created by Rob Boyer on 12/2/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "TransportPanelView.h"
#import "AnimTimer.h"

@implementation TransportPanelView

const NSString* LocationEventKey = @"LocationEventKey";

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void) dealloc
{
}


- (BOOL)canBecomeKeyView
{
   return YES;
}

- (BOOL)acceptsFirstResponder
{
   return YES;
}


- (void)drawRect:(NSRect)rect {
    // Drawing code here.
}


- (void)scrollWheel:(NSEvent *)theEvent
{
   [[AnimTimer defaultInstance] applyLocateDelta:-[theEvent deltaY]];
}


- (void)keyDown:(NSEvent *)theEvent
{
   float dx = 0.0;
   float dy = 0.0;
   int kc = [theEvent keyCode];
   switch (kc)
   {
      case 126:
         dy = 1.0;
         break;
      case 125:
         dy = -1.0;
         break; 
      case 124:
         dx = 1.0;
         break;
      case 123:
         dx = -1.0;
         break;
      case 49:        // SPACE
         [[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
         return;
   }
   [[AnimTimer defaultInstance] applyLocateDelta:dx];
}

@end
