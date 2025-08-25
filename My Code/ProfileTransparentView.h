//
//  ProfileTransparentView.h
//  Ascent
//
//  Created by Rob Boyer on 3/5/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackPoint;

@protocol ProfileTransparentView
-(void)setStartSelection:(NSPoint)pt;
-(void)setEndSelection:(NSPoint)pt;
-(void)clearSelection;
-(void)update:(NSPoint)pt trackPoint:(TrackPoint*)tpt nextTrackPoint:(TrackPoint*)npt ratio:(float)ratio needsDisplay:(BOOL)nd;
-(void)setShowCrossHairs:(BOOL)show;
-(BOOL)showCrossHairs;
-(void) prefsChanged;
@end


