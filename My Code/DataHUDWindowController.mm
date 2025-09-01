//
//  DataHUDWindowController.mm
//  Ascent
//
//  Created by Robert Boyer on 9/15/08.
//  Copyright 2008 Montebello Software, LLC. All rights reserved.
//

#import "DataHUDWindowController.h"
#import "DataHUDView.h"
#import "ColorBoxView.h"
#import "HUDWindow.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "Defs.h"

@interface DataHUDWindowController (Private)
-(void) createDataHUD;
@end

@implementation DataHUDWindowController


-(id)initWithSize:(NSSize)sz
{
	if (self = [super init])
	{
		size = sz;
		dataHUDView = nil;
		dataHUDWindow = nil;
		useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		[self createDataHUD];
		[self setFormatsForDataHUD];
		numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		[numberFormatter setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
		[numberFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
		[numberFormatter setLocale:[NSLocale currentLocale]];
#endif
	}
	return self;
}


-(void)dealloc
{
    [super dealloc];
}


#define MENU_BAR_HEIGHT			64

-(void) createDataHUD
{
	NSFont* font = [NSFont systemFontOfSize:9];
	// Make a rect to position the window at the top-right of the screen.
	NSSize windowSize = NSMakeSize(kDataHudW, kDataHudH);
	NSSize screenSize = [[NSScreen mainScreen] frame].size;
	NSRect windowFrame = NSMakeRect(screenSize.width - windowSize.width - 10.0, 
									screenSize.height - windowSize.height - MENU_BAR_HEIGHT - 10.0, 
									windowSize.width, windowSize.height);
	
	// Create a HUDWindow.
	// Note: the styleMask is ignored; NSWindowStyleMaskBorderless is always used.
	dataHUDWindow = [[HUDWindow alloc] initWithContentRect:windowFrame 
												 styleMask:NSWindowStyleMaskBorderless 
												   backing:NSBackingStoreBuffered 
													 defer:NO];
	
	NSRect dataViewFrame = windowFrame;
	dataViewFrame.origin = NSMakePoint(0,0);
	dataHUDView = [[DataHUDView alloc] initWithFrame:dataViewFrame];
	[dataHUDWindow setContentView:dataHUDView];
	[dataHUDWindow setAlphaValue:[Utils floatFromDefaults:RCBDefaultDataHUDTransparency]];
	//[dataHUDWindow addCloseWidget];
	
	
	int ctags[9];
	ctags[7] = kHeartrate;
	ctags[6] = kAltitude;
	ctags[5] = kSpeed;
	ctags[4] = kAvgPace;
	ctags[3] = kCadence;
	ctags[2] = kPower;
	ctags[1] = kGradient;
	ctags[0] = kDistance;
	
	// add empty text fields for avg/max/min data
	for (int row=0; row<kDataHudNumLines; row++)
	{
		if (row > 0)
		{
			NSRect r;
			r.size.width = kDataHudColorBoxW;
			r.size.height = kDataHudColorBoxW;
			r.origin = NSMakePoint(kDataHudColorBoxX, kDataHudBottomY +(row*kDataHudTH) + 3.0);
			ColorBoxView* cb = [[ColorBoxView alloc] initWithFrame:r];
			r.origin.x = r.origin.y = 0.0;
			[cb setBounds:r];
			int tag = ctags[row];
			if (tag == kAvgPace) tag = kSpeed;
			[cb setTag:tag];
			[cb setAlpha:0.5];
			[[dataHUDWindow contentView] addSubview:cb];
			[cb setNeedsDisplay:YES];
		}
		
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(kDataHudTextX, kDataHudBottomY+(row*kDataHudTH), 
																				kDataHudTextW, kDataHudTH)];
		[[dataHUDWindow contentView] addSubview:textField];
		[textField setEditable:NO];
		[textField setTextColor:[NSColor whiteColor]];
		[textField setDrawsBackground:NO];
		[textField setBordered:NO];
		[textField setAlignment:NSTextAlignmentCenter];
		[textField setStringValue:@"136bpm"];
		[textField setTag:ctags[row]+100];
		[textField setFont:font];
	}
	
	// Set the window's title and display it.
	[dataHUDWindow setMovableByWindowBackground:NO];
	[dataHUDWindow setIgnoresMouseEvents:YES];
	//[dataHUDWindow setTitle:@"Data HUD"];
	[dataHUDWindow setHidesOnDeactivate:NO];
	[[self window] setHidesOnDeactivate:NO];
}


-(void) setFormatsForDataHUD
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	if (useStatuteUnits)
	{
		altFormat = @"%@ft";
		distanceFormat = @"%@mi";
		speedFormat = @"%@mph";
		paceFormat = @"%02d:%02d/mi";
	}
	else
	{
		altFormat = @"%@m";
		distanceFormat = @"%@km";
		speedFormat = @"%@km/h";
		paceFormat = @"%02d:%02d/km";
	}
}


// update the Data HUD during animation or as the user drags the HUD over the view
-(void) updateDataHUD:(NSPoint)screenLoc trackPoint:(TrackPoint*)tpt altitude:(CGFloat)alt;
{
	int x = (int)(screenLoc.x - (kDataHudW/2.0));
	int y = screenLoc.y;
	NSRect windowFrame = NSMakeRect((float)x, (float)y, 
									kDataHudW, kDataHudH);
	[dataHUDWindow setFrame:windowFrame
					display:YES];
	
	// draw background and heart rate zone color par for point
	[dataHUDView update:tpt];
	
	// update heart rate
	NSTextField* tf = [dataHUDView viewWithTag:100+kHeartrate];
	float v = [tpt heartrate];
	if (tf && (v != 0))
	{
		[tf setStringValue:[NSString stringWithFormat:@"%1.0fbpm", v]];
	}
	else
	{
		[tf setStringValue:@"---"];
	}
	
	// update altitude
	tf = [dataHUDView viewWithTag:100+kAltitude];
	//v = useStatuteUnits ? [tpt altitude] : FeetToMeters([tpt altitude]);
	v = useStatuteUnits ? alt : FeetToMeters(alt);
	[numberFormatter setMaximumFractionDigits:0];
	NSString* dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
	if (tf) [tf setStringValue:[NSString stringWithFormat:altFormat, dispString]];
	
	// update speed
	tf = [dataHUDView viewWithTag:100+kSpeed];
	v = [tpt speed];
	if (!useStatuteUnits) v = MilesToKilometers(v);
	[numberFormatter setMaximumFractionDigits:1];
	dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
	if (tf) [tf setStringValue:[NSString stringWithFormat:speedFormat, dispString]];
	
	// update pace
	tf = [dataHUDView viewWithTag:100+kAvgPace];
	if (tf && (v != 0))
	{
		v = (60.0*60.0)/v;
		[tf setStringValue:[NSString stringWithFormat:paceFormat, ((int)(v/60)) % 60, ((int)v)%60]];
	}
	else
	{
		[tf setStringValue:@"---"];
	}
	
	// update cadence
	tf = [dataHUDView viewWithTag:100+kCadence];
	v = [tpt cadence];
	if (tf && (v != 0) && (v < 254)) 
	{
		[numberFormatter setMaximumFractionDigits:0];
		dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
		[tf setStringValue:[NSString stringWithFormat:@"%@rpm", dispString]];
	}
	else
	{
		[tf setStringValue:@"---"];
	}
	
	// update power
	tf = [dataHUDView viewWithTag:100+kPower];
	v = [tpt power];
	if (tf && (v != 0)) 
	{
		[numberFormatter setMaximumFractionDigits:0];
		dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
		[tf setStringValue:[NSString stringWithFormat:@"%@watts", dispString]];
	}
	else
	{
		[tf setStringValue:@"---"];
	}
	
	
	// update gradient
	tf = [dataHUDView viewWithTag:100+kGradient];
	v = [tpt gradient];
	[numberFormatter setMaximumFractionDigits:1];
	dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
	if (tf) [tf setStringValue:[NSString stringWithFormat:@"%@%%", dispString]];
	
	// update distance so far
	tf = [dataHUDView viewWithTag:100+kDistance];
	v = [tpt distance];
	if (!useStatuteUnits) v = MilesToKilometers(v);
	dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
	if (tf) [tf setStringValue:[NSString stringWithFormat:distanceFormat, dispString]];
	
	int atd = (int)[tpt activeTimeDelta];
	NSString* s = [NSString stringWithFormat:@"%0.02d:%0.02d:%0.02d", (atd/3600), ((atd/60) % 60), atd % 60];
	[dataHUDWindow setTitle:s];
	
	
}


-(NSWindow*)window
{
	return dataHUDWindow;
}



@end
