//
//  TransportPanelController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/26/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "TransportPanelController.h"
#import "AnimTimer.h"
#import "Utils.h"
#import "Defs.h"

@implementation TransportPanelController


- (id) init
{
   self = [super initWithWindowNibName:@"TransportPanel"];
   return self;
}

- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"TransportPanel begin destroyed...");
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
}


- (void) updateSpeedFactorText
{
   [speedFactorText setStringValue:[NSString stringWithFormat:@"%2.0fx",[[AnimTimer defaultInstance] speedFactor]]];
}

- (void)stateChanged:(NSNotification *)notification
{
	id sender = [notification object];
	if (sender != self)
	{
		NSString* st = [[notification userInfo] objectForKey:@"state"];
		if ([st isEqualToString:@"stop"])
		{
			///printf("@stopping...\n");
			[playButton setState:NSOffState];
			[reverseButton setState:NSOffState];
		}
		else if ([st isEqualToString:@"play"])
		{
			///printf("@playing...\n");
			if ([[AnimTimer defaultInstance] playingInReverse])
			{
				[reverseButton setState:NSOnState];
				[playButton setState:NSOffState];
			}
			else
			{
				[playButton setState:NSOnState];
				[reverseButton setState:NSOffState];
			}
		}
	}					
}


-(void) awakeFromNib
{
   //NSLog(@"transport panel NIB awakening...");
   
   
   NSString* path = [[NSBundle mainBundle] pathForResource:@"play_off" ofType:@"png"];
   NSImage*  image = [[NSImage alloc] initWithContentsOfFile:path];
   [playButton setImage:image];
   path = [[NSBundle mainBundle] pathForResource:@"play_on" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [playButton setAlternateImage:image];
   [playButton setNextResponder:theView];
   
   path = [[NSBundle mainBundle] pathForResource:@"reverse_off" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [reverseButton setImage:image];
   path = [[NSBundle mainBundle] pathForResource:@"reverse_on" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [reverseButton setAlternateImage:image];
   [reverseButton setNextResponder:theView];
   
   path = [[NSBundle mainBundle] pathForResource:@"stop_off" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [stopButton setImage:image];
   [stopButton setNextResponder:theView];
   path = [[NSBundle mainBundle] pathForResource:@"rtz_off" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [rtzButton setImage:image];
   [rtzButton setNextResponder:theView];
   path = [[NSBundle mainBundle] pathForResource:@"ff_off" ofType:@"png"];
   image = [[NSImage alloc] initWithContentsOfFile:path];
   [rteButton setImage:image];
   [rteButton setNextResponder:theView];
   
   //NSFont* font = [NSFont systemFontOfSize:44];
   NSFont* font = [NSFont fontWithName:@"LCDMono Ultra" size:44];
   [timecodeText setFont:font];
   [timecodeText setTextColor:[NSColor blackColor]];
   [timecodeText setStringValue:@"00:00:00"];
   [timecodeText setNextResponder:theView];

   AnimTimer * at = [AnimTimer defaultInstance];
   [speedFactorSlider setFloatValue:[at speedFactor]];
   [self updateSpeedFactorText];
   [speedFactorSlider setNextResponder:theView];
   [speedFactorText setNextResponder:theView];

   float endTime = [at endingTime];
   if (endTime > 0.0)
   {
      [locationSlider setFloatValue:[at animTime]*100.0/endTime];
   }
   [locationSlider setNextResponder:theView];
   [thePanel setFloatingPanel:YES];

   panelOpacity = [Utils floatFromDefaults:RCBDefaultAnimPanelTransparency];
   if (panelOpacity < 0.3) panelOpacity = 0.3;
   [opacitySlider setFloatValue:panelOpacity];
   [thePanel setAlphaValue:panelOpacity];
   [opacitySlider setNextResponder:theView];
   
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(stateChanged:)
												 name:@"TransportStateChange"
											   object:nil];
	//[[self window] setNextResponder:theView];
}   

- (void) connectToTimer
{
   [[AnimTimer defaultInstance] registerForTimerUpdates:self];
   [[AnimTimer defaultInstance] setTransportPanelController:self];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
   [[AnimTimer defaultInstance] setTransportPanelController:nil];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"TransportPanelClosed" object:self];
}

- (void)fade:(NSTimer *)theTimer
{
   if ([[self window] alphaValue] > 0.0) {
      // If window is still partially opaque, reduce its opacity.
      [[self window]  setAlphaValue:[[self window]  alphaValue] - 0.2];
   } else {
      // Otherwise, if window is completely transparent, destroy the timer and close the window.
      [fadeTimer invalidate];
      fadeTimer = nil;
      
      [[self window]  close];
      
      [[self window]  setAlphaValue:panelOpacity];
   }
}



- (BOOL)windowShouldClose:(id)sender
{
   // Set up our timer to periodically call the fade: method.
   fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
   
   [Utils setBoolDefault:NO
                  forKey:RCBDefaultShowTransportPanel];
   // Don't close just yet.
   return NO;
}



- (IBAction)play:(id)sender
{
   AnimTimer* at = [AnimTimer defaultInstance];
   if ([sender intValue] == NSOnState)
   {
      [at stop:self];
      [at play:self reverse:NO];
      [reverseButton setIntValue:0];
   }
   else
   {
      [at stop:self];
   }
}


- (IBAction)reverse:(id)sender
{
   AnimTimer* at = [AnimTimer defaultInstance];
   if ([sender intValue] == NSOnState)
   {
      [at stop:self];
      [at play:self reverse:YES];
      [playButton setIntValue:0];
   }
   else
   {
      [at stop:self];
   }
}

- (IBAction)rtz:(id)sender
{
   [[AnimTimer defaultInstance] rewind];
   [reverseButton setIntValue:0];
}


- (IBAction)rte:(id)sender
{
   [[AnimTimer defaultInstance] fastForward];
   [playButton setIntValue:0];
   [reverseButton setIntValue:0];
}



- (IBAction)stop:(id)sender
{
   AnimTimer* at = [AnimTimer defaultInstance];
   [at stop:self];
   [playButton setIntValue:0];
   [reverseButton setIntValue:0];
}

- (NSButton*) playButton
{
   return playButton;
}


- (NSButton*) reverseButton
{
   return reverseButton;
}


- (IBAction)setSpeedFactor:(id)sender
{
   [[AnimTimer defaultInstance] setSpeedFactor:[sender floatValue]];
   [self updateSpeedFactorText];
}

- (IBAction)setLocation:(id)sender
{
   [[AnimTimer defaultInstance] locateToPercentage:[sender floatValue]];
}


-(void) beginAnimation
{
}


-(void) endAnimation
{
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev  animating:(BOOL)anim
{
   NSString* s = [[NSString alloc] initWithFormat:@"%02.2d:%02.2d:%02.2d", (int)(trackTime/(60*60)), (int)((trackTime/60))%60, ((int)trackTime)%60];
   [timecodeText setStringValue:s];
   AnimTimer * at = [AnimTimer defaultInstance];
   float endTime = [at endingTime];
   if (endTime > 0.0)
   {
      [locationSlider setFloatValue:[at animTime]*100.0/endTime];
   }
   if (([playButton intValue] != 0) && [at playingInReverse])
   {
      [playButton setIntValue:0];
      [reverseButton setIntValue:1];
   }
   else if (([reverseButton intValue] != 0) && ![at playingInReverse])
   {
      [playButton setIntValue:1];
      [reverseButton setIntValue:0];
   }
}

-(Track*) animationTrack
{
   return nil;
}

- (IBAction) setPanelOpacity:(id)sender
{
   panelOpacity = [sender floatValue];
   [[self window] setAlphaValue:panelOpacity];
   [Utils setFloatDefault:panelOpacity forKey:RCBDefaultAnimPanelTransparency];
}


-(float)panelOpacity
{
   return panelOpacity;
}

@end
