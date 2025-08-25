//
//  TransparentMapView.h
//  Ascent
//
//  Created by Rob Boyer on 11/27/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TransparentMapViewProtocol.h"
#import "Defs.h"

@class TrackPoint;

@interface TransparentMapView : NSView<TransparentMapViewProtocol>
{
   NSPoint              position;
   NSImage*             dotImage;
   NSImage*             dataGraphImage;
   TrackPoint*          trackPoint;
   NSMutableDictionary* animFontAttrs;
   NSMutableDictionary* lcdFontAttrs;
   float                maxValueArray[kNumPlotTypes];
   float                minValueArray[kNumPlotTypes];
   float                hudOpacity;
   BOOL                 showDataRect;
   BOOL                 useStatuteUnits;
   BOOL                 hasHUD;
}

- (id)initWithFrame:(NSRect)frame hasHUD:(BOOL)hh;
-(void) setShowHud:(BOOL)show;
-(BOOL) showHud;
-(void) setHudOpacity:(float)op;
-(float) hudOpacity;
-(void) setMaxMinValueArrays:(float*)maxarr min:(float*)minarr;

@end
