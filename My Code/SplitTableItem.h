//
//  SplitTableItem.h
//  Ascent
//
//  Created by Rob Boyer on 9/27/07.
//  Copyright 2007 MontebelloSoftware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StatDefs.h"

struct tSplitData
{
	float	splitAvg;			// average for split
	float	deltaFromLast;		// difference from previous split
	float   auxDeltaFromLast;	// when another delta is needed
	float	deltaFromAvg;		// difference from overall average
	float	minOrValue;			// min during split, value for 'distance' 
	float	max;				// max during split, cumulative distance for 'distance'
	float   paceDeltaFromLast;	// for pace only
	float	paceDeltaFromAvg;	// for pace only
};

@interface SplitTableItem : NSObject 
{
	tSplitData		splitData[kST_NumStats];
	NSRect	trackingRect;		// for graphic view
	NSTrackingRectTag trackingRectTag; 
	BOOL			selected;
}

- (id) initWithData:(NSTimeInterval)st
		   distance:(float)dist			// cumulative
		  splitData:(struct tStatData*)data
	   activityData:(struct tStatData*)data
		  prevSplit:(SplitTableItem*)prevSplitItem;

- (NSTimeInterval)splitTime;        // in active time
- (NSTimeInterval)splitDuration;


- (float)deltaDistance;
- (float)cumulativeDistance;
- (float)deltaDistanceInMiles;
- (float)cumulativeDistanceInMiles;


- (float)climb;
- (float)deltaClimbFromLast;

- (float)rateOfClimb;
- (float)deltaRateOfClimbFromLast;
- (float)rateOfDescent;
- (float)deltaRateOfDescentFromLast;

- (float)avgSpeed;
- (float)maxSpeed;
- (float)deltaSpeedFromLast;
- (float)deltaSpeedFromAvg;

- (float)avgPace;
- (float)minPace;
- (float)deltaPaceFromLast;
- (float)deltaPaceFromAvg;

- (float)avgHeartRate;
- (float)maxHeartRate;
- (float)deltaHeartRateFromLast;
- (float)deltaHeartRateFromAvg;

- (float)avgCadence;
- (float)maxCadence;
- (float)deltaCadenceFromLast;
- (float)deltaCadenceFromAvg;

- (float)calories;
- (float)deltaCaloriesFromLast;

- (float)avgGradient;
- (float)maxGradient;
- (float)minGradient;
- (float)deltaGradientFromLast;
- (float)deltaGradientFromAvg;

- (float)avgPower;
- (float)maxPower;
- (float)deltaPowerFromLast;
- (float)deltaPowerFromAvg;

-(void)select;
-(void)deselect;
-(BOOL)selected;

- (NSRect)trackingRect;
- (void)setTrackingRect:(NSRect)value;

- (NSTrackingRectTag)trackingRectTag;
- (void)setTrackingRectTag:(NSTrackingRectTag)value;


@end
