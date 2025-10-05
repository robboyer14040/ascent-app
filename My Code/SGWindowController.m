//
//  SGWindowController.m
//  TLP
//
//  Created by Rob Boyer on 9/24/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "SGWindowController.h"
#import "TrackBrowserDocument.h"
#import "SGView.h"
#import "VertTicView.h"
#import "ColorBoxView.h"
#import "Utils.h"

@interface NSWindowController ()
-(void)dismissSummaryGraphWindow:(id)sender;
@end


@implementation SGWindowController

@synthesize mainWC;


- (id)initWithDocument:(TrackBrowserDocument*)doc  mainWC:(NSWindowController*)wc
{
    self = [super initWithWindowNibName:@"SummaryWindow"];
 	self.mainWC = wc;
    tbDocument = doc;
   return self;
}


- (void)dealloc
{
#if DEBUG_LEAKS
    NSLog(@"Summary Graph controller dealloc...rc:%d", [self retainCount]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
 	self.mainWC = nil;
}



- (void)prefsChanged:(NSNotification *)notification
{
   [[[self window] contentView] display];
   //[sgView setNeedsDisplay:YES];
}


-(void) awakeFromNib
{
	//NSLog(@"\nsummary window awakening..\n");
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"SMWindowFrame"];
	if (![[self window] setFrameUsingName:@"SMWindowFrame"])
	{
		[[self window] center];
	}
	[sgView setDocument:tbDocument];
	[vertTicViewLeft setSgView:sgView];
	[vertTicViewLeft setIsLeft:YES];
	[vertTicViewRight setSgView:sgView];
	[vertTicViewRight setIsLeft:NO];

	NSArray* subviews = [[[self window] contentView] subviews];
	int num = [subviews count];
	int i;
	for (i=0; i<num; i++)
	{
	  id view = [subviews objectAtIndex:i];
	  int tag = [view tag];
	  if (IS_BETWEEN(1, tag, (kNumPlotTypes-1)))
	  {
		 [view setIntValue:[sgView plotEnabled:tag]];
	  }
	}
	int v = [Utils intFromDefaults:RCBDefaultSummaryGraphGranularity];
	if (v == 0)
	{
	  [unitsMatrix setState:NSControlStateValueOn atRow:0 column:0];
	} 
	else
	{
	  [unitsMatrix setState:NSControlStateValueOn atRow:1 column:0];
	}   
	[sgView setPlotUnits:(v == 0 ? kWeeks : kMonths)];
	[totalDistanceColorBox setTag:kDistance];
	[totalDistanceColorBox setNeedsDisplay:YES];
	[totalDurationColorBox setTag:kDuration];
	[totalMovingDurationColorBox setTag:kMovingDuration];
	[totalClimbColorBox setTag:kAltitude];
	[avgSpeedColorBox setTag:kSpeed];
	[avgMovingSpeedColorBox setTag:kAvgMovingSpeed];
	[avgPaceColorBox setTag:kAvgPace];
	[avgMovingPaceColorBox setTag:kAvgMovingPace];
	[avgHeartrateColorBox setTag:kHeartrate];
	[avgCadenceColorBox setTag:kCadence];
	[avgWeightColorBox setTag:kWeightPlot];
	[caloriesColorBox setTag:kCalories];
	v = [Utils intFromDefaults:RCBDefaultSummaryGraphStyle];
	[sgView setGraphType:v];
	[graphTypePopup selectItemAtIndex:v];

	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(prefsChanged:)
												name:PreferencesChanged
											  object:nil];
}


- (IBAction) enablePlotType:(id)sender
{
   int tag = [sender tag];
   if (IS_BETWEEN(1, tag, (kNumPlotTypes-1)))
   {
      [sgView enablePlotType:tag on:[sender intValue]];
      //[vertTicViewLeft setNeedsDisplay:YES];
      //[vertTicViewRight setNeedsDisplay:YES];
      [[[self window] contentView] display];
   }
}

- (IBAction) changeUnits:(id)sender
{
	BOOL doWeeks = [[sender selectedCell] tag] == 0;
	[Utils setIntDefault:[[sender selectedCell] tag] 
				  forKey:RCBDefaultSummaryGraphGranularity];
	[sgView setPlotUnits:(doWeeks ? kWeeks : kMonths)];
	[vertTicViewLeft setNeedsDisplay:YES];
	[vertTicViewRight setNeedsDisplay:YES];
	[[[self window] contentView] display];
}

- (IBAction) setGraphType:(id)sender
{
	int v = [sender indexOfSelectedItem];
	[Utils setIntDefault:v
				  forKey:RCBDefaultSummaryGraphStyle];
	[sgView setGraphType:v];
	[vertTicViewLeft setNeedsDisplay:YES];
	[vertTicViewRight setNeedsDisplay:YES];
	[[[self window] contentView] display];
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


- (void)windowWillClose:(NSNotification *)notification
{
	if (mainWC && [mainWC respondsToSelector:@selector(dismissSummaryGraphWindow:)])
	{
		[(id)mainWC dismissSummaryGraphWindow:self];
	}
}


- (BOOL)windowShouldClose:(id)sender
{
   //[[self window] saveFrameUsingName:@"SMWindowFrame"];
   // Set up our timer to periodically call the fade: method.
   fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
   
   // Don't close just yet.
   return NO;
}

- (void)windowDidResize:(NSNotification *)aNotification
{
   //[[self window] saveFrameUsingName:@"SMWindowFrame"];
}


- (void)windowWillMove:(NSNotification *)aNotification
{
}


- (void)windowDidMove:(NSNotification *)aNotification
{
   //[[self window] saveFrameUsingName:@"SMWindowFrame"];
}



@end
