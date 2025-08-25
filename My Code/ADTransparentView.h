//
//  ADTransparentView.h
//  Ascent
//
//  Created by Rob Boyer on 11/29/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"
#import "ProfileTransparentView.h"

#define DRAW_ROAD			0

#if DRAW_ROAD
#  define Y_ROAD_ADJUST		3
#else
#  define Y_ROAD_ADJUST		0
#endif

@class TrackPoint;


@interface ADTransparentView : NSView<ProfileTransparentView>
{
	NSImage*                dataRectImage;
	NSImage*                dotImage;
	NSMutableDictionary *   animFontAttrs; 
	NSMutableDictionary *	selectTextAttrs; 
	NSPoint                 pos;
	NSPoint					startSelectPos;
	NSPoint					endSelectPos;
	TrackPoint*             trackPoint;
	BOOL                    showCrossHairs;
	BOOL                    useStatuteUnits;
	BOOL					inSelection;
}

@end
