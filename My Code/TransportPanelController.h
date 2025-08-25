//
//  TransportPanelController.h
//  Ascent
//
//  Created by Rob Boyer on 11/26/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface TransportPanelController : NSWindowController 
{
   IBOutlet NSPanel*             thePanel;
   IBOutlet NSButton*            playButton;
   IBOutlet NSButton*            stopButton;
   IBOutlet NSButton*            reverseButton;
   IBOutlet NSButton*            rtzButton;
   IBOutlet NSButton*            rteButton;
   IBOutlet NSTextField*         speedFactorText;
   IBOutlet NSSlider*            speedFactorSlider;
   IBOutlet NSSlider*            locationSlider;
   IBOutlet NSTextField*         timecodeText;
   IBOutlet NSSlider*            opacitySlider;
   IBOutlet NSView*              theView;
   NSTimer*                      fadeTimer;
   float                      panelOpacity;
}

- (IBAction)play:(id)sender;
- (IBAction)reverse:(id)sender;
- (IBAction)rtz:(id)sender;
- (IBAction)rte:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)setSpeedFactor:(id)sender;
- (IBAction)setLocation:(id)sender;
- (IBAction) setPanelOpacity:(id)sender;

- (void) connectToTimer;

- (NSButton*) playButton;
- (NSButton*) reverseButton;

-(Track*) animationTrack;
-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim;
-(void) beginAnimation;
-(void) endAnimation;
-(float)panelOpacity;
@end
