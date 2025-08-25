//
//  CWTransparentView.h
//  Ascent
//
//  Created by Rob Boyer on 3/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"
#import "ProfileTransparentView.h"

@class TrackPoint;
@class Track;

@interface CWTransparentView : NSView<ProfileTransparentView,CALayerDelegate>
{
	CALayer*				highlightLayer;
	CGColorRef				backgroundColor;
	CGColorRef				blackColor;
	CGFontRef				lcdFontRef;
	CALayer*				dotLayer;
	NSMutableDictionary *   animFontAttrs; 
	NSPoint                 pos;
	NSPoint					startSelectPos;
	NSPoint					endSelectPos;
	Track*					track;
	TrackPoint*             trackPoint;
	TrackPoint*             nextTrackPoint;
	NSMutableArray*			dataInfoArray;
	float					fastestDistance;
	float					startingOffset;
	float					ratio;
	BOOL                    useStatuteUnits;
	BOOL					isHighlighted;
	BOOL					wasHighlighted;
	BOOL					showingPace;
}
@property (nonatomic, retain) TrackPoint* trackPoint;
@property (nonatomic, retain) TrackPoint* nextTrackPoint;
@property (nonatomic, retain) Track* track;
@property (nonatomic, retain) NSMutableArray* dataInfoArray;
@property (nonatomic, retain) CALayer* highlightLayer;
@property (nonatomic) float ratio;
@property (nonatomic) BOOL isHighlighted;
@property (nonatomic) BOOL showingPace;

-(id)initWithFrame:(NSRect)frame iconFile:(NSString*)iconFile track:(Track*)track;
-(void)setFastestDistance:(float)fd startingOffset:(float)sd;
-(void)prefsChanged;

@end
