//
//  CWTransparentMapView.h
//  Ascent
//
//  Created by Rob Boyer on 3/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"
#import "TransparentMapViewProtocol.h"

@class TrackPoint;


@interface CWTransparentMapView : NSView<TransparentMapViewProtocol,CALayerDelegate> 
{
	NSMutableArray*			dotImageInfoArray;
	CALayer*				zoomedRectLayer;
	CGColorRef				whiteColor;
	CGColorRef				redColor;
	NSPoint					startSelectPos;
	NSPoint					endSelectPos;
	NSRect					zoomedInMapRect;
	NSRect					lastZoomedInMapRect;
	BOOL                    useStatuteUnits;
	
}
@property(nonatomic) NSRect zoomedInMapRect;
@property (nonatomic, retain) CALayer* zoomedRectLayer;

-(id)initWithFrame:(NSRect)frame dotColors:(NSArray*)dots;
-(void) prefsChanged;
-(void)setAllDotsHidden;

@end
