//
//  SplashPanel.m
//  TLP
//
//  Created by Rob Boyer on 10/1/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "SplashPanel.h"

@interface NSObject (DelegateMethods)
- (BOOL) handlesKeyDown: (NSEvent *) keyDown
               inWindow: (NSWindow *) window;
- (BOOL) handlesMouseDown: (NSEvent *) mouseDown
                 inWindow: (NSWindow *) window;
@end



@implementation SplashPanel
//	PUBLIC INSTANCE METHODS -- OVERRIDES FROM NSWindow

//	NSWindow will refuse to become the main window unless it has a title bar.
//	Overriding lets us become the main window anyway.
- (BOOL) canBecomeMainWindow
{
   return YES;
}

//	Much like above method.
- (BOOL) canBecomeKeyWindow
{
   return YES;
}

//	Ask our delegate if it wants to handle keystroke or mouse events before we route them.
- (void) sendEvent:(NSEvent *) theEvent
{
#if 0
    // rcb 5/1/2011 - not using delegate on the Panel, and this was causing 
    // compiler warnings
    
   //	Offer key-down events to the delegats
   if ([theEvent type] == NSKeyDown)
      if ([[self delegate] respondsToSelector: @selector(handlesKeyDown:inWindow:)])
         if ([[self delegate] handlesKeyDown: theEvent  inWindow: self])
            return;
   
   //	Offer mouse-down events (lefty or righty) to the delegate
   if ( ([theEvent type] == NSEventTypeLeftMouseDown) || ([theEvent type] == NSEventTypeRightMouseDown) )
      if ([[self delegate] respondsToSelector: @selector(handlesMouseDown:inWindow:)])
         if ([[self delegate] handlesMouseDown: theEvent  inWindow: self])
            return;
#endif 
   //	Delegate wasn’t interested, so do the usual routing.
   [super sendEvent: theEvent];
}




@end
