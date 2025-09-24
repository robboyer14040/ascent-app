//
//  SplitTableItem.mm
//  Ascent
//
//  Created by Rob Boyer on 9/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SplitTableItem.h"
#import "Utils.h"

@implementation SplitTableItem

- (id) initWithData:(NSTimeInterval)st
		   distance:(float)dist			// cumulative
		  splitData:(struct tStatData*)spData
	   activityData:(struct tStatData*)actData
		  prevSplit:(SplitTableItem*)prevSplitItem
{
	self = [super init];
	selected = NO;
	for (int i=0; i<kST_NumStats; i++)
	{
		tSplitData* splitDataItem = &splitData[i];
		tSplitData* prevSplitDataItem = prevSplitItem ? &prevSplitItem->splitData[i] : nil;
		switch (i)
		{
			case kST_Distance:
				splitDataItem->minOrValue = spData[i].vals[kVal];
				splitDataItem->max =  prevSplitDataItem ? prevSplitDataItem->minOrValue + prevSplitDataItem->max : 0.0; 		// cumulative
				splitDataItem->deltaFromLast = prevSplitDataItem ? (splitDataItem->minOrValue - prevSplitDataItem->minOrValue) : 0.0;
				break;
			
			case kST_Durations:
				splitDataItem->minOrValue = spData[i].vals[kMoving];
				splitDataItem->max = st;		// cumulative
 				break;
			
			case kST_Calories:
				splitDataItem->minOrValue = spData[i].vals[kVal];
				splitDataItem->deltaFromLast = prevSplitDataItem ? (splitDataItem->minOrValue - prevSplitDataItem->minOrValue) : 0.0;
				break;
			
			case kST_ClimbDescent:
				splitDataItem->max = spData[i].vals[kMax];				// climb
				splitDataItem->minOrValue = spData[i].vals[kMin];		// descent
				splitDataItem->deltaFromLast = prevSplitDataItem ? (splitDataItem->max - prevSplitDataItem->max) : 0.0;
				splitDataItem->auxDeltaFromLast = prevSplitDataItem ? (splitDataItem->minOrValue - prevSplitDataItem->minOrValue) : 0.0;
				break;
				
			case kST_MovingSpeed:
				splitDataItem->splitAvg = spData[i].vals[kAvg];
				splitDataItem->max = spData[i].vals[kMax];
				splitDataItem->minOrValue = spData[i].vals[kMin];
				splitDataItem->deltaFromLast = prevSplitDataItem ? (splitDataItem->splitAvg - prevSplitDataItem->splitAvg) : 0.0;
				splitDataItem->deltaFromAvg = actData ? splitDataItem->splitAvg - actData[i].vals[kAvg] : 0.0;
				splitDataItem->paceDeltaFromLast = prevSplitDataItem ? SpeedToPace(splitDataItem->splitAvg) - SpeedToPace(prevSplitDataItem->splitAvg) : 0.0;
				splitDataItem->paceDeltaFromAvg = actData ? SpeedToPace(splitDataItem->splitAvg) - SpeedToPace(actData[i].vals[kAvg]) : 0.0;
				break;
				
			default:
				splitDataItem->splitAvg = spData[i].vals[kAvg];
				splitDataItem->max = spData[i].vals[kMax];
				splitDataItem->minOrValue = spData[i].vals[kMin];
				splitDataItem->deltaFromLast = prevSplitDataItem ? (splitDataItem->splitAvg - prevSplitDataItem->splitAvg) : 0.0;
				splitDataItem->deltaFromAvg = actData ? splitDataItem->splitAvg - actData[i].vals[kAvg] : 0.0;
				break;
		}
	}
	return self;
}


- (void) dealloc
{
    [super dealloc];
}




//---- Time and Duration ------------------------------------------------------------
- (NSTimeInterval)splitTime
{
	return splitData[kST_Durations].max;
}


- (NSTimeInterval)splitDuration
{
	return splitData[kST_Durations].minOrValue;
}




//---- Distance ---------------------------------------------------------------------
- (float)deltaDistance
{
	return [Utils convertDistanceValue:splitData[kST_Distance].minOrValue];
}


- (float)cumulativeDistance
{
	return [Utils convertDistanceValue:splitData[kST_Distance].max];
}

- (float)deltaDistanceInMiles
{
	return splitData[kST_Distance].minOrValue;
}


- (float)cumulativeDistanceInMiles
{
	return splitData[kST_Distance].max;
}


//---- Climb/Descent ----------------------------------------------------------------
- (float)climb
{
	return  [Utils convertClimbValue:splitData[kST_ClimbDescent].max];
}

- (float)descent
{
	return  [Utils convertClimbValue:splitData[kST_ClimbDescent].minOrValue];
}


- (float)deltaClimbFromLast
{
	return [Utils convertClimbValue:splitData[kST_ClimbDescent].deltaFromLast];
}

- (float)deltaDescentFromLast
{
	return [Utils convertClimbValue:splitData[kST_ClimbDescent].auxDeltaFromLast];
}

//---- Rate Of Climb (VAM)  --------------------------------------------------------

- (float)rateOfClimb
{
	// note: unit conversion already handled by deltaDistance and climb methods
	float answer = 0.0;
	float dur = [self splitDuration]/3600.0;	// convert from seconds to hours
	if (dur > 0.0) answer = [self climb]/dur;
	return answer;
}


- (float)deltaRateOfClimbFromLast
{
	float answer = 0.0;
	float dur = [self splitDuration]/3600.0;	// convert from seconds to hours
	if (dur > 0.0) answer = [self deltaClimbFromLast]/dur;
	return answer;
}


//---- Rate Of Descent (VAM)  --------------------------------------------------------

- (float)rateOfDescent
{
	// note: unit conversion already handled by deltaDistance and climb methods
	float answer = 0.0;
	float dur = [self splitDuration]/3600.0;	// convert from seconds to hours
	if (dur > 0.0) answer = [self descent]/dur;
	return answer;
}


- (float)deltaRateOfDescentFromLast
{
	float answer = 0.0;
	float dur = [self splitDuration]/3600.0;	// convert from seconds to hours
	if (dur > 0.0) answer = [self deltaDescentFromLast]/dur;
	return answer;
}


//---- Speed -----------------------------------------------------------------------
- (float)avgSpeed
{
	return [Utils convertSpeedValue:splitData[kST_MovingSpeed].splitAvg];
}


- (float)maxSpeed
{
	return [Utils convertSpeedValue:splitData[kST_MovingSpeed].max];
}


- (float)deltaSpeedFromLast
{
	return [Utils convertSpeedValue:splitData[kST_MovingSpeed].deltaFromLast];
}


- (float)deltaSpeedFromAvg
{
	return [Utils convertSpeedValue:splitData[kST_MovingSpeed].deltaFromAvg];
}


//---- Pace -----------------------------------------------------------------------
- (float)avgPace
{
	return SpeedToPace([self avgSpeed]);		// already converted to metric if necessary
}


- (float)minPace
{
	return SpeedToPace([self maxSpeed]);			// already converted to metric if necessary
}


- (float)deltaPaceFromLast
{
	return [Utils convertPaceValue:splitData[kST_MovingSpeed].paceDeltaFromLast];
}


- (float)deltaPaceFromAvg
{
	return [Utils convertPaceValue:splitData[kST_MovingSpeed].paceDeltaFromAvg];
}


//---- Heart Rate ------------------------------------------------------------------
- (float)avgHeartRate
{
	return splitData[kST_Heartrate].splitAvg;
}


- (float)maxHeartRate
{
	return splitData[kST_Heartrate].max;
}


- (float)deltaHeartRateFromLast
{
	return splitData[kST_Heartrate].deltaFromLast;
}


- (float)deltaHeartRateFromAvg
{
	return splitData[kST_Heartrate].deltaFromAvg;
}


//---- Cadence --------------------------------------------------------------------
- (float)avgCadence
{
	return splitData[kST_Cadence].splitAvg;
}


- (float)maxCadence
{
	return splitData[kST_Cadence].max;
}


- (float)deltaCadenceFromLast
{
	return splitData[kST_Cadence].deltaFromLast;
}


- (float)deltaCadenceFromAvg
{
	return splitData[kST_Cadence].deltaFromAvg;
}



//---- Calories -------------------------------------------------------------------
- (float)calories
{
	return splitData[kST_Calories].minOrValue;
}


- (float)deltaCaloriesFromLast
{
	return splitData[kST_Calories].deltaFromLast;
}



//---- Grade ----------------------------------------------------------------------
- (float)avgGradient
{
	return splitData[kST_Gradient].splitAvg;
}


- (float)maxGradient
{
	return splitData[kST_Gradient].max;
}


- (float)minGradient
{
	return splitData[kST_Gradient].minOrValue;
}


- (float)deltaGradientFromLast
{
	return splitData[kST_Gradient].deltaFromLast;
}


- (float)deltaGradientFromAvg
{
	return splitData[kST_Gradient].deltaFromAvg;
}



//---- Power ----------------------------------------------------------------------
- (float)avgPower
{
	return splitData[kST_Power].splitAvg;
}


- (float)maxPower
{
	return splitData[kST_Power].max;
}


- (float)deltaPowerFromLast
{
	return splitData[kST_Power].deltaFromLast;
}


- (float)deltaPowerFromAvg
{
	return splitData[kST_Power].deltaFromAvg;
}


//----------------------------------------------------------------------------------

-(void)select
{
	selected = YES;
}


-(void)deselect
{
	selected = NO;
}


-(BOOL)selected
{
	return selected;
}


//----------------------------------------------------------------------------------

- (NSRect)trackingRect 
{
    return trackingRect;
}

- (void)setTrackingRect:(NSRect)value 
{
    trackingRect = value;
}

- (NSTrackingRectTag)trackingRectTag 
{
    return trackingRectTag;
}

- (void)setTrackingRectTag:(NSTrackingRectTag)value 
{
	trackingRectTag = value;
}



@end
