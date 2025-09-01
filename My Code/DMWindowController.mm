//
//  DMWindowController.mm
//  TLP
//
//  Created by Rob Boyer on 10/14/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "DMWindowController.h"
#import "Track.h"
#import "Lap.h"
#import "TrackBrowserDocument.h"
#import "MapPathView.h"
#import "Utils.h"
#import "Defs.h"
#import "AnimTimer.h"
#import "TransparentMapView.h"
#import "TransparentMapWindow.h"
#import "DataHUDWindowController.h"


#define ANIM_UPDATE_TIME      (0.05)

enum
{
	kCM_ShowHUD = 3000,
	kCM_ShowLaps,
	kCM_ShowPath,
	kCM_ZoomIn,
	kCM_ZoomOut,
	kCM_ShowEntirePath,
	kCM_CenterAtPoint,
	kCM_RefreshMap,
	kCM_ShowIntervalMarkers,
};


@interface NSWindowController ()
-(void)dismissDetailedMapWindow:(id)sender;
@end

@interface DMWindowController (Private)

-(void) trackArrayChanged:(NSNotification *)notification;
-(void) rebuildActivitySelectorPopup;
- (void)startProgress:(NSNotification *)notification;
- (void)endProgress:(NSNotification *)notification;
- (void)mapPrefChange:(NSNotification *)notification;
- (void)zoomChanged:(NSNotification *)notification;
- (void)endAnimation:(NSNotification *)notification;
- (void)trackEdited:(NSNotification *)notification;
- (void)lapSelectionChange:(NSNotification *)notification;

@end


//----- PUBLIC INTERFACE --------------------------------------------------------------------------------

@implementation DMWindowController
@synthesize mainWC;

- (void)scaleChanged:(NSNotification *)notification
{
   [self setDataType:[mapView dataType]];
}


- (id)initWithDocument:(TrackBrowserDocument*)doc initialDataType:(int)dt  mainWC:(NSWindowController*)wc
{
    self = [super initWithWindowNibName:@"DetailedMapWindow"];
    self.mainWC = wc;
    track = nil;
    tbDocument = doc;
    dataType = dt;
    activitySelectorPopup = nil;
    [[AnimTimer defaultInstance] registerForTimerUpdates:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scaleChanged:)
                                                 name:@"MapScaleChanged"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startProgress:)
                                                 name:@"StartMapRetrieval"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(endProgress:)
                                                 name:@"EndMapRetrieval"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(endAnimation:)
                                                 name:@"AnimationEnded"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mapPrefChange:)
                                                 name:@"PreferencesChanged"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lapSelectionChange:)
                                                 name:@"LapSelectionChanged"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(trackEdited:)
                                                 name:@"TrackEdited"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(trackArrayChanged:)
                                                 name:@"TrackArrayChanged"
                                               object:nil];
    NSRect dummy;   
    dummy.size.width = 10;
    dummy.size.height = 10;
    dummy.origin.x = 0;
    dummy.origin.y = 0;
    transparentMapWindow = [[TransparentMapWindow alloc] initWithContentRect:dummy 
                                                                   styleMask:NSWindowStyleMaskBorderless 
                                                                     backing:NSBackingStoreBuffered 
                                                                       defer:NO];
    [transparentMapWindow setDelegate:self];
    transparentMapAnimView = [[TransparentMapView alloc] initWithFrame:dummy
                                                               hasHUD:YES];
    [transparentMapWindow setContentView:transparentMapAnimView];
    return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mapView prepareToDie];
	[mapView killAnimThread];
	[[self window] removeChildWindow:transparentMapWindow];
	[transparentMapWindow close];		// default is to RELEASE window on close! (see setReleasedWhenClosed)
	self.mainWC = nil;
#if DEBUG_LEAKS
	NSLog(@"dmc exiting, mapView retain count:%d %d", [mapView retainCount], [zoomSlider retainCount]);
#endif
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
      
      // Make the window fully opaque again for next time.
      [[self window]  setAlphaValue:1.0];
   }
}



- (BOOL)windowShouldClose:(id)sender
{
   // Set up our timer to periodically call the fade: method.
   fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
   
   // Don't close just yet.
   return NO;
}




- (void)windowWillClose:(NSNotification *)aNotification
{
	[[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
	if ([aNotification object] == transparentMapWindow)
	{
		transparentMapWindow = nil;	// since transparent window is RELEASED when closed, set to nil here so that 'close' call during dealloc is not invoked on freed object
	}
	if (mainWC && [mainWC respondsToSelector:@selector(dismissDetailedMapWindow:)])
	{
		[(id)mainWC dismissDetailedMapWindow:self];
	}
}

-(void) positionEverything
{
   NSRect fr = [mapView frame];
   //fr = NSInsetRect(fr, 10, 10);
   NSRect cfr = fr;
   cfr.origin = [[self window] convertBaseToScreen:fr.origin];
   [transparentMapWindow setFrame:cfr display:NO];
   fr.origin = NSZeroPoint;
   [transparentMapAnimView setFrame:fr];
   [transparentMapAnimView setBounds:fr];
   [transparentMapAnimView setNeedsDisplayInRect:fr];
   [transparentMapAnimView  setHidden:[[track goodPoints] count] <= 1];
}   


NSEvent* sMouseEv = nil;

-(void)contextualMenuAction:(id)sender
{
	int tag = [sender tag];
	switch (tag)
	{
		case kCM_ShowHUD:
			[sender setState:![transparentMapAnimView showHud]];
			[self setShowHud:sender];
			[showHudButton setIntValue:[transparentMapAnimView showHud]];
			break;
		 
		case kCM_ShowLaps:
			[sender setState:![mapView showLaps]];
			[self setShowLaps:sender];
			[showLapsButton setIntValue:[mapView showLaps] == YES ? 1 : 0];
			break;

		case kCM_ShowIntervalMarkers:
			[sender setState:![mapView showIntervalMarkers]];
			[self setShowIntervalMarkers:sender];
			[showIntervalMarkersButton setIntValue:[mapView showIntervalMarkers] == YES ? 1 : 0];
			break;
		   
		case kCM_ShowPath:
			[sender setState:![mapView showPath]];
			[self setShowPath:sender];
			[showPathButton setIntValue:[mapView showPath] == YES ? 1 : 0];
			break;

		case kCM_ZoomIn:
			[self zoomIn:sender];
			break;

		case kCM_ZoomOut:
			[self zoomOut:sender];
			break;

		case kCM_ShowEntirePath:
			[self centerOnPath:sender];
			break;

		case kCM_CenterAtPoint:
			[mapView centerOnMousePoint:sMouseEv];
			break;
		   
		case kCM_RefreshMap:
			[mapView refreshMaps];
			break;
   }
}




- (NSMenu*) buildContextualMenu:(NSEvent*)ev
{
   NSMenu* cm = [[NSMenu alloc] init];
   NSString* s;
   sMouseEv = ev;
   //----
   //----
   s = @"Center on Click Point";
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_CenterAtPoint];
   
   //----
   if ([transparentMapAnimView showHud])
   {
      s = @"Hide HUD";
   }
   else
   {
      s = @"Show HUD";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowHUD];
   
   //----
   if ([mapView showLaps])
   {
      s = @"Hide Laps";
   }
   else
   {
      s = @"Show Laps";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowLaps];
	//----
	if ([mapView showIntervalMarkers])
	{
		s = @"Hide Interval Markers";
	}
	else
	{
		s = @"Show Interval Markers";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kCM_ShowIntervalMarkers];
	
   //----
   if ([mapView showPath])
   {
      s = @"Hide Path";
   }
   else
   {
      s = @"Show Path";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowPath];
   

   //----
   s = @"Zoom In";
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ZoomIn];
   
   //----
   s = @"Zoom Out";
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ZoomOut];
   
   //----
   s = @"Display Entire Path";
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowEntirePath];
   
	s = @"Refresh Map";
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kCM_RefreshMap];
	
	//----
   //[cm addItem:[NSMenuItem separatorItem]];
   
   return cm;
}



-(void) buildLapPopUp
{
	[selectedLapPopup removeAllItems];
	if (track != nil)
	{
		NSArray* laps = [track laps];
		int nl = [laps count];
		[selectedLapPopup addItemWithTitle:@"All laps"];
		if (nl > 0) 
		{
			Lap* lap = [laps objectAtIndex:0];
			float lapEndTime = [lap startingWallClockTimeDelta] + [track durationOfLap:lap];
			if (lapEndTime < [track duration])
			{
				for (int i=0; i<nl; i++)
				{
					NSString* s;
					if (i == (nl-1))
					{
						s = [NSString stringWithFormat:@"End of lap %d to finish", i];
					}
					else
					{
						s = [NSString stringWithFormat:@"Lap %d", i+1];
					}
					[selectedLapPopup addItemWithTitle:s];
				}
				Lap* selectedLap = [tbDocument selectedLap];
				NSUInteger idx = [laps indexOfObjectIdenticalTo:selectedLap];
				if (idx != NSNotFound)
				{
					[selectedLapPopup selectItemAtIndex:(idx+1)];
				}
			}
		}
	}
}


-(void) awakeFromNib
{
	[settingsDrawer setDelegate:self];
   //NSLog(@"detailed map window awakening..mapView retain count: %d\n", [mapView retainCount]);
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"DMWindowFrame"];
	if (![[self window] setFrameUsingName:@"DMWindowFrame"])
	{
		[[self window] center];
	}
	[mapView setIsDetailedMap:YES];
	[mapView setCurrentTrack:track];
	[mapView setSelectedLap:[tbDocument selectedLap]];
	[mapView setMoveMapDuringAnimation:YES];


	[self setDataType:dataType];
	[Utils buildDataTypePopup:mapDataTypePopup isPullDown:NO];
	int val = [Utils dataTypeToIndex:dataType];
	[mapDataTypePopup selectItemAtIndex:val];
	int cpz = [Utils intFromDefaults:RCBDefaultColorPathUsingZone];
	[colorPathPopup selectItemWithTag:cpz];
	[self buildLapPopUp];
	[showHudButton setIntValue:[transparentMapAnimView showHud]];
	

	float opac = [Utils floatFromDefaults:RCBDefaultMDMapTransparency];
	[mapView setMapOpacity:opac];
	opac = [Utils floatFromDefaults:RCBDefaultMDPathTransparency];
	[mapView setPathOpacity:opac];


	[[self window] makeFirstResponder:mapView];

	[mapView setTransparentView:transparentMapAnimView];
	[transparentMapWindow setContentView:transparentMapAnimView];

	[self positionEverything];
	[[self window]  addChildWindow:(NSWindow*)transparentMapWindow ordered:NSWindowAbove];
	[transparentMapWindow setHasShadow:NO];
	//[transparentMapAnimView setShowHud:YES];


	SEL sel = @selector(buildContextualMenu:);
	NSMethodSignature* sig = [DMWindowController instanceMethodSignatureForSelector:sel];
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[mapView setContextualMenuInvocation:inv];
	
	dataHUDWC = [[DataHUDWindowController alloc] initWithSize:NSMakeSize(0.0,0.0)];
	sel = @selector(updateDataHUD:x:y:altitude:);
	sig = [DMWindowController instanceMethodSignatureForSelector:sel];
	inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[mapView setDataHudUpdateInvocation:inv];

	float v = [Utils floatFromDefaults:RCBDefaultMDHUDTransparency];
	[hudOpacitySlider  setFloatValue:v];
	[[dataHUDWC window] setAlphaValue:v];

	[self rebuildActivitySelectorPopup];
}


// update the Data HUD during animation or as the user drags the HUD over the view
-(void) updateDataHUD:(TrackPoint*)tpt x:(CGFloat)x y:(CGFloat)y altitude:(CGFloat)alt
{
	NSPoint p = NSMakePoint(x,y);
	NSPoint cp = [mapView convertPoint:p toView:nil];      // to window coords
	cp.y += 15.0;
	[dataHUDWC updateDataHUD:[[mapView window] convertBaseToScreen:cp]
				  trackPoint:tpt
					altitude:alt];
}


- (BOOL)drawerShouldOpen:(NSDrawer *)sender
{
	windowFrameBeforeOpeningDrawer = [[self window] frame];
	NSRect fr = windowFrameBeforeOpeningDrawer;
	NSRect screenFr = [[[self window] screen] visibleFrame];
	NSSize drawerSize = [settingsDrawer contentSize];
	drawerSize.width += 10.0;
	float freeWidth = (screenFr.size.width - fr.size.width);
	if (freeWidth < drawerSize.width)
	{
		fr.origin.x = drawerSize.width;
		fr.size.width = (screenFr.size.width - drawerSize.width);
		[[self window] setFrame:fr
						display:YES];
	}
	return YES;
}


- (void)drawerDidClose:(NSNotification *)notification
{
	if (!NSEqualRects(windowFrameBeforeOpeningDrawer, [[self window] frame]))
	{
		[[self window] setFrame:windowFrameBeforeOpeningDrawer
						display:YES];
	}
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
   [transparentMapAnimView  setHidden:YES];
   return proposedFrameSize;
}


- (void)windowDidLoad
{
	BOOL show = [Utils boolFromDefaults:RCBDefaultShowMDHUD];
	if (show)
	{
		[[self window] addChildWindow:(NSWindow*)[dataHUDWC window] ordered:NSWindowAbove];
	}
	else
	{
		[[dataHUDWC window] orderOut:self];
	}
	[showHudButton setState:show];
}



- (void)windowDidMove:(NSNotification *)aNotification
{
   //NSLog(@"DM did move...");
   [self positionEverything];
}


- (void)windowDidResize:(NSNotification *)aNotification
{
   //NSLog(@"DM did resize...");
   [self positionEverything];
}


- (IBAction)selectActivity:(id)sender
{
   //[[AnimTimer defaultInstance] stop];
  [[AnimTimer defaultInstance] updateTimerDuration];
  [self setTrack:[[tbDocument trackArray] objectAtIndex:[sender indexOfSelectedItem]]]; 
}


- (Track*)track
{
   return track;
}


- (void)setTrack:(Track*)t
{
	if (t != track)
	{
		track = t;
		[mapView setCurrentTrack:track];
		if ((activitySelectorPopup != nil) && (track != nil))
		{
            [activitySelectorPopup setTitle:[Utils buildTrackDisplayedName:track prePend:@""]]; 
            [[self window] setTitle:[Utils buildTrackDisplayedName:track prePend:@"Map Detail - "]];
		}
		[self buildLapPopUp];
		[self selectLap:nil];
	}
}

- (void)setInitialDataType:(int)dt
{
   dataType = dt;
}


- (IBAction)setMapDataType:(id)sender
{
   if (mapView != nil)
   {
 	  int dt = [Utils mapIndexToType:[mapDataTypePopup indexOfSelectedItem]];    
      [self setDataType:dt];
   }
}


- (void)setDataType:(int)dt
{
   dataType = dt;
   if (mapView != nil)
   {
      switch (dt)
      {
         case 1:
            // USGS DOQ aerial - range is [10,19]
            [zoomSlider setMinValue:10.0];
            [zoomSlider setNumberOfTickMarks:10];
            if ([mapView scale] < 10)
            {
               [mapView setScale:10];
            }
            break;
         case 2:
            // USGS DRG Topo, range is [11,19]
            [zoomSlider setMinValue:11.0];
            [zoomSlider setNumberOfTickMarks:9];
            if ([mapView scale] < 11)
            {
               [mapView setScale:11];
            }
            break;
         case 4:
            // USGS Urban area, range is [8,19]
            [zoomSlider setMinValue:8.0];
            [zoomSlider setNumberOfTickMarks:12];
            break;
         default:
            // VE, range is [1,19]
            [zoomSlider setMinValue:1.0];
            [zoomSlider setNumberOfTickMarks:19];
            break;
      }
      [mapView setDataType:dt];
      int min = [zoomSlider minValue];
      int max = [zoomSlider maxValue];
      [zoomSlider setIntValue:min + max - [mapView scale]];
      [zoomSlider display];
   }
}


- (IBAction)setShowPath:(id)sender
{
   int state = [sender state];
   BOOL on = (state == NSControlStateValueOn) ? YES : NO;
   [mapView setShowPath:on];
}


- (IBAction)setShowLaps:(id)sender
{
   int state = [sender state];
   BOOL on = (state == NSControlStateValueOn) ? YES : NO;
   [mapView setShowLaps:on];
}


- (IBAction)setShowIntervalMarkers:(id)sender
{
	int state = [sender state];
	BOOL on = (state == NSControlStateValueOn) ? YES : NO;
	[mapView setShowIntervalMarkers:on];
	[Utils setBoolDefault:on 
				   forKey:RCBDefaultShowIntervalMarkers];
	[intervalIncrementTextField setEnabled:on];
	[intervalIncrementStepper setEnabled:on];
	[intervalIncrementUnitsLabel setEnabled:on];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


- (IBAction)setIntervalIncrement:(id)sender
{
	float v = 0.0;
	v = [sender floatValue];
	v = CLIP(1.0, v, MAX_MARKER_INCREMENT);
	[intervalIncrementStepper setFloatValue:v];
	[intervalIncrementTextField setFloatValue:v];
	[mapView setIntervalIncrement:v];
	[Utils setFloatDefault:v
					forKey:RCBDefaultIntervalMarkerIncrement];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


- (IBAction) setShowHud:(id) sender
{
	BOOL on = [sender state] == NSControlStateValueOn;
	if (on)
	{
		[[self window] addChildWindow:(NSWindow*)[dataHUDWC window] ordered:NSWindowAbove];
	}
	else
	{
		[[self window] removeChildWindow:[dataHUDWC window] ];
		[[dataHUDWC window]  orderOut:self];
	}
	[Utils setBoolDefault:on 
				   forKey:RCBDefaultShowMDHUD];
}


- (IBAction)setHudOpacity:(id)sender
{
   //[transparentMapAnimView setHudOpacity:[sender floatValue]];
	float v = [sender floatValue];
	[[dataHUDWC window] setAlphaValue:v];
	[[dataHUDWC window] display];
	[Utils setFloatDefault:v forKey:RCBDefaultMDHUDTransparency];
}



- (IBAction)selectLap:(id)sender
{
   Lap* lap = nil;
   int idx = [sender indexOfSelectedItem];
   if ((idx > 0) && (track != nil))
   {
      NSArray* laps = [track laps];
      int nl = [laps count];
      if (IS_BETWEEN(0, (idx-1), (nl-1)))
      {
         lap = [laps objectAtIndex:idx-1];
      }
   }
   [mapView setSelectedLap:lap];
}


-(void)setSelectedLap:(Lap*)lap
{
    [mapView setSelectedLap:lap];  
}


- (IBAction)setColorPath:(id)sender
{
	int cpz = [[sender selectedItem] tag];		// menu item tag must contain enum to zone type
	[Utils setIntDefault:cpz forKey:RCBDefaultColorPathUsingZone];
	[mapView forceRedisplay];   
}


- (IBAction)moveLeft:(id)sender
{
   [mapView moveHoriz:+1];
}


- (IBAction)moveRight:(id)sender
{
   [mapView moveHoriz:-1];
}


- (IBAction)moveUp:(id)sender
{
   [mapView moveVert:-1];
}


- (IBAction)moveDown:(id)sender
{
   [mapView moveVert:+1];
}

- (IBAction)zoom:(id)sender
{
   int min = [sender minValue];
   int max = [sender maxValue];
   [mapView setScale:min + (max - [sender intValue])];
}

- (IBAction)centerOnPath:(id)sender
{
   [self applyDefaults:sender];
}

- (IBAction)zoomIn:(id)sender
{
   [mapView setScale:[mapView scale]-1];
}

- (IBAction)zoomOut:(id)sender
{
   [mapView setScale:[mapView scale]+1];
}


- (IBAction)applyDefaults:(id)sender
{
   [mapView setDefaults];
}


- (IBAction)centerAtEnd:(id)sender
{
   [mapView centerAtEnd];
}


- (IBAction)centerAtStart:(id)sender
{
   [mapView centerAtStart];
}


-(void) beginAnimation
{
   [mapView beginAnimation];
}


-(void) endAnimation
{
   [mapView cancelAnimation];
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim
{
   [mapView updateDetailedPosition:trackTime reverse:rev animating:anim];
}




- (IBAction)setMapTransparency:(id)sender
{
   [mapView setMapOpacity:[sender floatValue]];
}

- (IBAction)setPathTransparency:(id)sender
{
   [mapView setPathOpacity:[sender floatValue]];
}

- (Track*) animationTrack
{
   return track;
}


- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
   if (([menuItem action] == @selector(zoomIn:)) ||
       ([menuItem action] == @selector(zoomOut:)))
   {
      return YES;
   }
   return YES;
}



- (IBAction) openDrawer:(id) sender
{
	[settingsDrawer toggle:self];
}


- (IBAction) closeDrawer:(id) sender
{
	[settingsDrawer toggle:self];
}


@end


//------ PRIVATE SECTION ------------------------------------------------------------------------------------

@implementation DMWindowController (Private)

-(void) rebuildActivitySelectorPopup
{
	NSArray* ta = [tbDocument trackArray];
	[activitySelectorPopup removeAllItems];
	int count = [ta count];
	for (int i=0; i<count; i++)
	{
		// NOTE: can't use NSPopupButton methods here to add items, because it checks for duplicates and this causes
		// problems if we manufacture 2 or more track names that are the same.
		[[activitySelectorPopup menu] addItemWithTitle:[Utils buildTrackDisplayedName:[ta objectAtIndex:i] prePend:@""]
												action:0
										 keyEquivalent:@""];
	}
	if (track != nil) [[self window] setTitle:[Utils buildTrackDisplayedName:track prePend:@"Map Detail - "]];
}


-(void) trackArrayChanged:(NSNotification *)notification
{
	[self rebuildActivitySelectorPopup];
	NSArray* arr = [tbDocument trackArray];
	if (track != nil)
	{
		if ([arr indexOfObjectIdenticalTo:track] == NSNotFound)
		{
			NSUInteger idx = [arr indexOfObject:track];
			if (idx != NSNotFound)
			{
				[self setTrack:[arr objectAtIndex:idx]];
			}
		}
	}
}


- (void)startProgress:(NSNotification *)notification
{
	[progressIndicator setUsesThreadedAnimation:YES];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator startAnimation:self];
	[progressIndicator setHidden:NO];
	[progressText setHidden:NO];
	[progressText display];
	[[progressIndicator window] flushWindow];
}


- (void)endProgress:(NSNotification *)notification
{
	[progressIndicator stopAnimation:self];
	[progressIndicator setHidden:YES];
	[progressText setHidden:YES];
	[progressText display];
}


- (void)endAnimation:(NSNotification *)notification
{
}


- (void)zoomChanged:(NSNotification *)notification
{
	[self setDataType:[mapView dataType]];
}


- (void)mapPrefChange:(NSNotification *)notification
{
	float v = [Utils floatFromDefaults:RCBDefaultMapTransparency];
	[mapView setMapOpacity:v];
	[mapTransparencySlider setFloatValue:v];
	v = [Utils floatFromDefaults:RCBDefaultPathTransparency];
	[mapView setPathOpacity:v];
	[pathTransparencySlider setFloatValue:v];
	int idx = [Utils intFromDefaults:RCBDefaultMapType];
	[mapDataTypePopup selectItemAtIndex:idx];
	[mapView setDataType:[Utils mapIndexToType:idx]];
	[mapView setIntervalIncrement:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	BOOL on = [Utils boolFromDefaults:RCBDefaultShowIntervalMarkers];
	[showIntervalMarkersButton setState:on ? NSControlStateValueOn : NSControlStateValueOff];
	[intervalIncrementTextField setEnabled:on];
	v = [Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement];
	[intervalIncrementStepper setFloatValue:v];
	[intervalIncrementTextField setFloatValue:v];
	[intervalIncrementTextField setEnabled:on];
	[intervalIncrementStepper setEnabled:on];
	[intervalIncrementUnitsLabel setEnabled:on];
	[mapView setShowIntervalMarkers:on];
	[mapView setNeedsDisplay:YES];
	[mapView setScrollWheelSensitivity:[Utils floatFromDefaults:RCBDefaultScrollWheelSensitivty]];
	
	[transparentMapAnimView prefsChanged];
}


- (void)lapSelectionChange:(NSNotification *)notification
{
	[mapView setSelectedLap:[notification object]];
}


- (void)trackEdited:(NSNotification *)notification
{
	[mapView setCurrentTrack:track];
}



//----- DRAWER-RELATED -----------------------------------------------------------------------------------------------

// tags in the drawer
enum
{
	kDMC_MapOpacitySlider = 2000,
	kDMC_ShowLapsButton,
	kDMC_ShowPathButton,
	kDMC_PathOpacitySlider,
	kDMC_MoveUpButton,
	kDMC_MoveDownButton,
	kDMC_MoveLeftButton,
	kDMC_MoveRightButton,
	kDMC_ZoomSlider,
	kDMC_CenterPathButton,
	kDMC_CenterAtStart,
	kDMC_CenterAtEnd,
};



- (void)drawerWillOpen:(NSNotification *)notification
{
	// update controls in the drawer
	NSView* contentView = [settingsDrawer contentView];
	mapTransparencySlider = [contentView viewWithTag:kDMC_MapOpacitySlider];
	showLapsButton = [contentView viewWithTag:kDMC_ShowLapsButton];
	showPathButton = [contentView viewWithTag:kDMC_ShowPathButton];
	pathTransparencySlider = [contentView viewWithTag:kDMC_PathOpacitySlider];
	zoomSlider = [contentView viewWithTag:kDMC_ZoomSlider];
}


- (void)drawerDidOpen:(NSNotification *)notification
{
	
	[showPathButton setIntValue:[mapView showPath] == YES ? 1 : 0];
	[showLapsButton setIntValue:[mapView showLaps] == YES ? 1 : 0];
	[showIntervalMarkersButton setIntValue:[Utils boolFromDefaults:RCBDefaultShowIntervalMarkers] ? 1 : 0];
	[intervalIncrementTextField setFloatValue:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	[intervalIncrementStepper setFloatValue:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	[intervalIncrementUnitsLabel setStringValue:[Utils usingStatute] ? @"mi" : @"km"];
	int min = [zoomSlider minValue];
	int max = [zoomSlider maxValue];
	[zoomSlider setIntValue:min + (max-[mapView scale])];
	float opac = [Utils floatFromDefaults:RCBDefaultMDMapTransparency];
	[mapTransparencySlider setFloatValue:opac];
	opac = [Utils floatFromDefaults:RCBDefaultMDPathTransparency];
	[pathTransparencySlider setFloatValue:opac];
	[self setDataType:dataType];
	
}



@end

