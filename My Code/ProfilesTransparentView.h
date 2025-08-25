//
//  ProfilesTransparentView.h
//  Ascent
//
//  Created by Rob Boyer on 4/10/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define RULER_HEIGHT		24.0


@interface ProfilesTransparentView : NSView <CALayerDelegate>
{
	float					minDist;
	float					maxDist;
	float					curDist;
	float					focusDistance;
	
	float					startRegionDist;
	float					endRegionDist;
	int						focusAnimID;
	NSMutableDictionary *	tickFontAttrs; 
	NSRect					rulerBounds; 
	CALayer*				animLayer;
	CALayer*				focusLayer;
	CGImageRef				thumbImage;
	CGImageRef				rulerBGImage;
	NSInvocation*           contextualMenuInvocation;
	CGColorRef				animColors[4];		
	BOOL					dragging;
	BOOL					hidePosition;
}
@property (nonatomic, retain) NSInvocation* contextualMenuInvocation;
@property (nonatomic) float minDist;
@property (nonatomic) float maxDist;
@property (nonatomic) float curDist;
@property (nonatomic ) float startRegionDist;
@property (nonatomic) float endRegionDist;
@property (nonatomic) NSRect rulerBounds;
@property (nonatomic) BOOL hidePosition;
-(void)layoutViewSublayers;
-(void)setCompareRegionStart;
-(void)setCompareRegionEnd;
-(void)unselectCompareRegion;
-(void)zoomToSelection;
-(void)zoomOut:(float)min max:(float)max;
-(void)updateAll;
-(void)setFocusDistance:(float)fd animID:(int)aid;
-(void)prefsChanged;

@end
