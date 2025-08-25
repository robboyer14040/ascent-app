//
//  SplitsGraphView.h
//  Ascent
//
//  Created by Robert Boyer on 9/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SplitsTableStaticColumnInfo;
@class Lap;
@class SplitsTableView;
@class ColumnInfo;
@class ColorBoxView;

@interface SplitsGraphView : NSView 
{
	SplitsTableStaticColumnInfo*	staticColumnInfo;
	NSMutableDictionary*			tickFontAttrs; 
	NSMutableDictionary*			valueFontAttrs; 
	NSMutableDictionary*			textFontAttrs; 
	NSArray*						splitArray;
	NSColor*						valueColor;
	ColorBoxView*					valueColorBox;
	SplitsTableView*				splitsTableView;
	NSTextField*					valueTextField;
	NSString*						columnKey;
	NSTimeInterval					selectedLapStartTime;
	NSTimeInterval					selectedLapEndTime;
	NSTrackingRectTag				trackingRect;
	int								graphItem;
	float							maxDist;
	BOOL							xAxisIsTime;
}
 
- (NSArray *)splitArray;
- (void)setSplitArray:(NSArray *)value splitsTable:(SplitsTableView*)stv;
- (int)graphItem;
- (void)setGraphItem:(int)value;
- (void)setSelectedLapTimes:(float)start end:(float)end;
-(void) resetTrackingRect;
-(void)setColumnKey:(NSString*)key;
-(NSString*)columnKey;


@end
