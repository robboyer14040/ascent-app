//
//  SplashPanelController.h
//  TLP
//
//  Created by Rob Boyer on 10/1/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SplashPanelView;

@interface SplashPanelController : NSWindowController <NSWindowDelegate>
{
   IBOutlet NSPanel*          splashPanelInNib;
   IBOutlet SplashPanelView*  splashView;
   NSPanel*                   panelToDisplay;
   NSTimer*                   fadeTimer;
   float                      alphaVal;
   BOOL                       canDismiss;
}


+ (SplashPanelController *) sharedInstance;


#pragma mark PUBLIC INSTANCE METHODS

   //	Show the panel, starting the text at the top with the animation going
- (void) showPanel;

   //	Stop scrolling and hide the panel.
- (void) hidePanel;

- (void) updateProgress:(NSString*)msg;
- (void) canDismiss:(BOOL)yessno;
-(void) startFade:(id)dummy;

@end
