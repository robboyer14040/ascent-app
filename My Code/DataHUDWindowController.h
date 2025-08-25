//
//  DataHUDWindowController.h
//  pseudo-window "controller" for the HUD showing point data.  Not a *real* window controller
//  Ascent
//
//  Created by Robert Boyer on 9/15/08.
//  Copyright 2008 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DataHUDView;
@class HUDWindow;
@class TrackPoint;

@interface DataHUDWindowController : NSObject
{
	NSSize			size;
	DataHUDView*	dataHUDView;
	HUDWindow*		dataHUDWindow;
	NSString*		altFormat;
	NSString*		speedFormat;
	NSString*		paceFormat;
	NSString*		distanceFormat;
	NSNumberFormatter* numberFormatter;
	BOOL			useStatuteUnits;
}

-(id)initWithSize:(NSSize)sz;
-(NSWindow*)window;
-(void) setFormatsForDataHUD;
-(void) updateDataHUD:(NSPoint)screenLoc trackPoint:(TrackPoint*)tpt altitude:(CGFloat)alt;


@end
