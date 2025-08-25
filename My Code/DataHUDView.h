//
//  DataHUDView.h
//  Ascent
//
//  Created by Rob Boyer on 4/23/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static const int   kDataHudNumLines   = 8;
static const float kDataHudW          = 97.0;       
static const float kDataHudTH         = 13.0;
static const float kDataHudHRBarH     = 3.0;
static const float kDataHudBottomY    = 4.0;
static const float kDataHudH          = (kDataHudNumLines*kDataHudTH) + kDataHudHRBarH + kDataHudBottomY + 3.0 + 13.0;
static const float kDataHudColorBoxX  = 3.0;
static const float kDataHudColorBoxW  = 9.0;
static const float kDataHudTextX      = kDataHudColorBoxX + kDataHudColorBoxW;
static const float kDataHudTextW      = (kDataHudW - (kDataHudColorBoxW + 6.0));

@class TrackPoint;

@interface DataHUDView : NSView 
{
	TrackPoint* trackPoint;
}
-(void) update:(TrackPoint*)tpt;


@end
