//
//  Lap.h
//  TLP
//
//  Created by Rob Boyer on 7/31/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StatDefs.h"

@interface Lap : NSObject <NSCoding, NSMutableCopying, NSCopying>
{
	struct tStatData	statsArray[kST_NumStats];
	int					index;
	NSDate*				origStartTime;
	NSTimeInterval		startTimeDelta;
	NSTimeInterval		totalTime;          // WALL CLOCK TOTAL TIME OF LAP
	float				distance;         // miles
	float				maxSpeed;         // mph
	float				avgSpeed;         // mph
	float				beginLatitude, beginLongitude;
	float				endLatitude, endLongitude;
    float               deviceTotalTime;    // TIME REPORTED BY DEVICE == ACTIVE TIME
	int					averageHeartRate;
	int					maxHeartRate;
	int					averageCadence;
	int					maxCadence;
	int					calories;
	int					intensity;
	int					triggerMethod;
	BOOL				selected;
	BOOL				statsCalculated;
}


- (id) initWithGPSData:(int)index
startTimeSecsSince1970:(time_t)sts
             totalTime:(unsigned int)tt
         totalDistance:(float)td       // specified in METERS here
              maxSpeed:(float)ms       // specified in METERS/SEC here
              beginLat:(float)blat
              beginLon:(float)blon
                endLat:(float)elat
                endLon:(float)elon
              calories:(unsigned int)cals
                 avgHR:(int)ahr
                 maxHR:(int)mhr
                 avgCD:(int)acd
             intensity:(int)inten
               trigger:(int)tm;

+ (void) resetStartTime:(NSDate*)startTime;			// for use in converting old lap data that had dates instead of delta times

///- (id)copyWithZone:(NSZone *)zone;
- (id)mutableCopyWithZone:(NSZone *)zone;

- (int)lapIndex;
- (int)index;
- (void)setIndex:(int)idx;

- (NSDate*) origStartTime;
- (void) setOrigStartTime:(NSDate*)ost;
- (NSComparisonResult) compareByOrigStartTime:(Lap*)anotherLap;
- (NSComparisonResult) reverseCompareByOrigStartTime:(Lap*)anotherLap;	// to sort laps into DESCENDING order

// startTimeDelta is WALL CLOCK TIME delta
- (NSTimeInterval) startingWallClockTimeDelta;
- (void) setStartingWallClockTimeDelta:(NSTimeInterval)std;

- (NSTimeInterval) totalTime;       // wall-clock seconds in lap
- (NSTimeInterval) deviceTotalTime; // time of lap reported by device, active time
- (void)setDeviceTotalTime:(NSTimeInterval)dtt;
- (void) setTotalTime:(NSTimeInterval)tt;

- (NSString *)durationAsString;

- (float) distance;
- (void) setDistance:(float)d;      // specified in MILES here

- (float) maxSpeed;
- (void) setMaxSpeed:(float)ms;     // specified in MILES/HR here

- (float) avgSpeed;
- (void) setAvgSpeed:(float)ms;     // specified in MILES/HR here

- (float) beginLatitude;
- (void) setBeginLatitude:(float)val;

- (float) beginLongitude;
- (void) setBeginLongitude:(float)val;

- (float) endLatitude;
- (void) setEndLatitude:(float)val;

- (float) endLongitude;
- (void) setEndLongitude:(float)val;

- (int) averageHeartRate;
- (void) setAvgHeartRate:(int)ahr;

- (int) maxHeartRate;
- (void)setMaxHeartRate:(int)mhr;

- (int) averageCadence;
- (void) setAverageCadence:(int)avc;

- (int) maxCadence;
- (void) setMaxCadence:(int)avc;

- (BOOL)isEqual:(id)otherLap;
- (BOOL)isDeltaTimeDuringLap:(NSTimeInterval)delta;

- (int)calories;
- (int)lapCalories;
- (void)setCalories:(int)value;

- (int)intensity;
- (void)setIntensity:(int)value;

- (int)triggerMethod;
- (void)setTriggerMethod:(int)value;

- (BOOL)isOrigDateDuringLap:(NSDate*)d;

- (BOOL)selected;
- (void)setSelected:(BOOL)value;

- (struct tStatData*) getStat:(int)type;
- (struct tStatData*) getStatArray;
- (void) setStatsCalculated:(BOOL)done;
- (BOOL) statsCalculated;

- (NSTimeInterval) startTimeDelta;

@end
