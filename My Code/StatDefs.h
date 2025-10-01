/*
 *  StatDefs.h
 *  Ascent
 *
 *  Created by Rob Boyer on 3/4/07.
 *  Copyright 2007 Montebello Software. All rights reserved.
 *
 */


// indices used in the 'vals' array of tStatData vals array...
enum
{
	kMax						= 0,
	kVal						= 0,		// when just a single value (kST_Distance)
	kElapsed					= 0,		// for kST_Duration
	kMoving						= 1,		// for kST_Duration
	kWork						= 1,		// for kST_PowerWork,
	kMin						= 1,
	kAvg						= 2,
	kDistanceAtMax				= 3,
	kNumValsPerStat				= 4
};


struct tStatData 
{
	float			vals[kNumValsPerStat];
	NSTimeInterval	atActiveTimeDelta[2];		// activeTime deltas, use index kMax for time at max, kMin for time at min
};

typedef NS_ENUM(NSInteger, tStatType) 
{
	kST_Distance,		// 0 uses val only
	kST_Durations,		// 1 max = elapsed, min = moving
	kST_Heartrate,		// 2 uses avg and max
	kST_Speed,			// 3 uses avg and max
	kST_MovingSpeed,	// 4 uses avg and max
	kST_Gradient,		// 5 uses avg, min, and max
	kST_Altitude,		// 6 uses avg, min, and max
	kST_ClimbDescent,	// 7 max = climb, min = descent, avg is not used
	kST_Temperature,	// 8 uses avg, min, and max
	kST_Cadence,		// 9 uses avg and max
	kST_Calories,		// 10 uses max
	kST_Power,			// 11 uses avg and max for power, min for work(kj)
	kST_NumStats
};

