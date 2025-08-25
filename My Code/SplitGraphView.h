//
//  SplitGraphView.h
//  Ascent
//
//  Created by Robert Boyer on 9/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SplitsTableStaticColumnInfo;
@class Lap;


@interface SplitGraphView : NSView 
{
	SplitsTableStaticColumnInfo*	staticColumnInfo;
	NSMutableDictionary*			tickFontAttrs; 
	NSArray*						splitArray;
	NSTimeInterval					selectedLapStartTime;
	NSTimeInterval					selectedLapEndTime;
	int								graphItem;
	float							maxDist;
	BOOL							xAxisIsTime;
}
- (NSArray *)splitArray;
- (void)setSplitArray:(NSArray *)value;
- (int)graphItem;
- (void)setGraphItem:(int)value;
- (void)setSelectedLapTimes:(float)start end:(float)end;




@end
