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
@property(nonatomic, assign) BOOL hasHUD;

-(void) setShowHud:(BOOL)show;
-(BOOL) showHud;
-(void) setHudOpacity:(float)op;
-(float) hudOpacity;
-(void) setMaxMinValueArrays:(float*)maxarr min:(float*)minarr;

@end
