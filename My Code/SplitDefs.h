/*
 *  SplitDefs.h
 *  Ascent
 *
 *  Created by Rob Boyer on 9/30/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

// column identifiers for key-value binding to SplitTableItem methods
#define	kSPLC_Distance					"deltaDistance"
#define	kSPLC_DistSoFar					"cumulativeDistance"
#define kSPLC_StartTime					"splitTime"
#define kSPLC_Duration					"splitDuration"
#define kSPLC_AvgSplitSpeed				"avgSpeed"
#define kSPLC_MaxSplitSpeed				"maxSpeed"
#define kSPLC_DeltaSpeedFromLast		"deltaSpeedFromLast"
#define kSPLC_DeltaSpeedFromAvg			"deltaSpeedFromAvg"
#define kSPLC_AvgPace					"avgPace"
#define kSPLC_MinPace					"minPace"
#define kSPLC_DeltaPaceFromLast			"deltaPaceFromLast"
#define kSPLC_DeltaPaceFromAvg			"deltaPaceFromAvg"
#define kSPLC_AvgHeartRate				"avgHeartRate"
#define kSPLC_MaxHeartRate				"maxHeartRate"
#define kSPLC_DeltaHeartRateFromLast	"deltaHeartRateFromLast"
#define kSPLC_DeltaHeartRateFromAvg		"deltaHeartRateFromAvg"
#define kSPLC_AvgCadence				"avgCadence"
#define kSPLC_MaxCadence				"maxCadence"
#define kSPLC_DeltaCadenceFromLast		"deltaCadenceFromLast"
#define kSPLC_DeltaCadenceFromAvg		"deltaCadenceFromAvg"
#define kSPLC_Calories					"calories"
#define kSPLC_DeltaCaloriesFromLast		"deltaCaloriesFromLast"
#define kSPLC_AvgGradient				"avgGradient"
#define kSPLC_MaxGradient				"maxGradient"
#define kSPLC_MinGradient				"minGradient"
#define kSPLC_DeltaGradientFromLast		"deltaGradientFromLast"
#define kSPLC_DeltaGradientFromAvg		"deltaGradientFromAvg"
#define kSPLC_AvgPower					"avgPower"
#define kSPLC_MaxPower					"maxPower"
#define kSPLC_DeltaPowerFromLast		"deltaPowerFromLast"
#define kSPLC_DeltaPowerFromAvg			"deltaPowerFromAvg"
#define kSPLC_Climb						"climb"
#define kSPLC_DeltaClimbFromLast		"deltaClimbFromLast"
#define kSPLC_RateOfClimb				"rateOfClimb"
#define kSPLC_DeltaRateOfClimbFromLast	"deltaRateOfClimbFromLast"
#define kSPLC_RateOfDescent				"rateOfDescent"
#define kSPLC_DeltaRateOfDescentFromLast "deltaRateOfDescentFromLast"




enum tSplitColMenuTags
{
	kSPLM_Distance = kMT_Last,			// can NOT overlap main browser tags!
	kSPLM_DistSoFar,
	kSPLM_StartTime,
	kSPLM_Duration,	
	kSPLM_AvgSplitSpeed,
	kSPLM_MaxSplitSpeed,
	kSPLM_DeltaSpeedFromLast,
	kSPLM_DeltaSpeedFromAvg,
	kSPLM_AvgPace,
	kSPLM_MinPace,
	kSPLM_DeltaPaceFromLast,
	kSPLM_DeltaPaceFromAvg,
	kSPLM_AvgHeartRate,
	kSPLM_MaxHeartRate,
	kSPLM_DeltaHeartRateFromLast,
	kSPLM_DeltaHeartRateFromAvg,
	kSPLM_AvgCadence,
	kSPLM_MaxCadence,
	kSPLM_DeltaCadenceFromLast,
	kSPLM_DeltaCadenceFromAvg,
	kSPLM_Calories,
	kSPLM_DeltaCaloriesFromLast,
	kSPLM_AvgGradient,
	kSPLM_MaxGradient,
	kSPLM_MinGradient,
	kSPLM_DeltaGradientFromLast,
	kSPLM_DeltaGradientFromAvg,
	kSPLM_AvgPower,
	kSPLM_MaxPower,
	kSPLM_DeltaPowerFromLast,
	kSPLM_DeltaPowerFromAvg,
	kSPLM_Climb,
	kSPLM_DeltaClimbFromLast,
	kSPLM_RateOfClimb,
	kSPLM_DeltaRateOfClimbFromLast,
	kSPLM_RateOfDescent,
	kSPLM_DeltaRateOfDescentFromLast,
};
	