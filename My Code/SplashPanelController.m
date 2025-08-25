//
//  SplashPanelController.m
//  TLP
//
//  Created by Rob Boyer on 10/1/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "SplashPanelController.h"
#import "SplashPanel.h"
#import "SplashPanelView.h"

@implementation SplashPanelController



+ (SplashPanelController *) sharedInstance
{
   static SplashPanelController	*sharedInstance = nil;
   
   if (sharedInstance == nil)
   {
      sharedInstance = [[self alloc] init];
      [NSBundle loadNibNamed: @"SplashPanel.nib"  owner: sharedInstance];
   }
   
   return sharedInstance;
}

//	Watch for notifications that the application is no longer active, or that
//	another window has replaced the About panel as the main window, and hide
//	on either of these notifications.
- (void) watchForNotificationsWhichShouldHidePanel
{
#if 0
	//	This works better than just making the panel hide when the app
   //	deactivates (setHidesOnDeactivate:YES), because if we use that
   //	then the panel will return when the app reactivates.
   [[NSNotificationCenter defaultCenter] addObserver: self
                                            selector: @selector(hidePanel)
                                                name: NSApplicationWillResignActiveNotification
                                              object: nil];
   
   //	If the panel is no longer main, hide it.
   //	(We could also use the delegate notification for this.)
   [[NSNotificationCenter defaultCenter] addObserver: self
                                            selector: @selector(hidePanel)
                                                name: NSWindowDidResignMainNotification
                                              object: panelToDisplay];
#endif
}


-(void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"Splash Panel controller dealloc...rc:%d", [self retainCount]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) createPanelToDisplay
{
   //	Programmatically create the new panel
   panelToDisplay = [[SplashPanel alloc]
        initWithContentRect: [[splashPanelInNib contentView] frame]
                  styleMask: NSBorderlessWindowMask
                    backing: [splashPanelInNib backingType]
                      defer: NO];
   
   //	Tweak esthetics, making it all white and with a shadow
   [panelToDisplay setBackgroundColor: [NSColor whiteColor]];
   [panelToDisplay setHasShadow: YES];
   
   [panelToDisplay setBecomesKeyOnlyIfNeeded: NO];
   
   //	We want to know if the window is no longer key/main
   [panelToDisplay setDelegate: self];
   
   //	Move the guts of the nib-based panel to the programmatically-created one
   {
      NSView		*content;
      
      content = [splashPanelInNib contentView];
      [content removeFromSuperview];
      [panelToDisplay setContentView: content];
   }
   //	Make it the key window so it can watch for keystrokes
}


- (void)updateFade:(NSTimer*)timer
{
   alphaVal -= 0.05;
   if (alphaVal <= 1.0)
   {
      [panelToDisplay setAlphaValue:alphaVal];
   }
   if (alphaVal <= 0.0)
   {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"AfterSplashPanelDone" object:self];
      [fadeTimer invalidate];
      fadeTimer = nil;
   }
}


#pragma mark PUBLIC INSTANCE METHODS -- NSNibAwaking INFORMAL PROTOCOL

//	Show the panel
- (void) showPanel
{
   [SplashPanelController sharedInstance];
   canDismiss = NO;
    //	Make it the key window so it can watch for keystrokes
   [panelToDisplay makeKeyAndOrderFront: nil];
}


-(void) startFade:(id)dummy
{
	alphaVal = 1.5;
	fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
												  target:self
												selector:@selector(updateFade:)
												userInfo:nil
												 repeats:YES];
}


- (void) canDismiss:(BOOL)yessno
{
   canDismiss = yessno;
}


- (void) updateProgress:(NSString*)msg;
{
   [splashView updateProgress:msg];
   //[progressText setStringValue:msg];
}


//	Hide the panel. 
- (void) hidePanel
{
   [panelToDisplay orderOut: nil];
}


- (void) awakeFromNib
{
   //	Create 'panelToDisplay', a borderless window, using the guts of the more vanilla 'panelInNib'.
   [self createPanelToDisplay];
   
   //	Fill in text fields
   //[self displayVersionInfo];
   
   
   //	Make things look nice
   [panelToDisplay center];
   
   //	Make lots of other things dismiss the panel
   [self watchForNotificationsWhichShouldHidePanel];
}


#pragma mark PUBLIC INSTANCE METHODS -- NSFancyPanel DELEGATE

- (BOOL) handlesKeyDown: (NSEvent *) keyDown
               inWindow: (NSWindow *) window
{
   //	Close the panel on any keystroke.
   //	We could also check for the Escape key by testing
   //		[[keyDown characters] isEqualToString: @"\033"]
   if (canDismiss)
   {
      alphaVal = 0.0;
      [self hidePanel];
      return YES;
   }
   return NO;
}

- (BOOL) handlesMouseDown: (NSEvent *) mouseDown
                 inWindow: (NSWindow *) window
{
   //	Close the panel on any click
   if (canDismiss)
   {
      alphaVal = 0.0;
      [self hidePanel];
      return YES;
   }
   return NO;
}

@end
