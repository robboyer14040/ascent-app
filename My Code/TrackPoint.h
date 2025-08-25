//
//  TrackPoint.h
//  TLP
//
//  Created by Rob Boyer on 7/13/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>


enum tImportFlag
{
	kImportFlagMissingCadence,
	kImportFlagMissingHeartRate,
	kImportFlagMissingDistance,
	kImportFlagMissingAltitude,
	kImportFlagMissingLocation,
	kImportFlagMissingSpeed,
	kImportFlagMissingPower,
	kImportFlagDeadZoneMarker,		// entire point was synthesized during import but not in import data
	kImportFlagHasFootpod,	
	// add new items here and adjust kMissingImportFlags mask and DATA_ITEM_TO_FLAG macro if necessary!
};


@interface TrackPoint : NSObject <NSCoding, NSMutableCopying>
{
	NSTimeInterval	wallClockDelta;
	NSTimeInterval	activeTimeDelta;
	float			latitude;
	float			longitude;
	float			altitude;			// may be smoothed, etc
	float			origAltitude;		// as synced from GPS
	float			heartrate;
	float			cadence;
	float			temperature;
	float			speed;
	float			power;				// watts
	float			distance;			// distance being used in calculations.  May be from GPS or calculated from GPS positions (Lat/Lon)
	float			origDistance;		// distance reported from the sync device; may not be the same as calculated with lat/lon
	float			gradient;
	float			climbSoFar;			// not stored
	float			descentSoFar;		// not stored 
	int				flags;
	BOOL			validLatLon;
}

+ (void) resetStartTime:(NSDate*)startTime;			// for use in converting old point data that had dates instead of delta times

- (id)initWithGPSData:(NSTimeInterval)wallClockDelta 
           activeTime:(NSTimeInterval)activeTimeDelta
             latitude:(float)lat
            longitude:(float)lon
             altitude:(float)alt          // in feet
            heartrate:(int)hr
              cadence:(int)cd
          temperature:(float)temp
                speed:(float)speed        // in mph
             distance:(float)distance;    // in miles

- (id)initWithDeadZoneMarker:(NSTimeInterval)wallClockDelta activeTimeDelta:(NSTimeInterval)activeTimeDelta;
- (id)mutableCopyWithZone:(NSZone *)zone;

//- (NSDate *)date;
//- (void)setDate:(NSDate *)d;
//- (NSDate *)activeTime;
//- (void)setActiveTime:(NSDate *)value;
- (NSTimeInterval)wallClockDelta;
- (void)setWallClockDelta:(NSTimeInterval)value;
- (NSTimeInterval)activeTimeDelta;
- (void)setActiveTimeDelta:(NSTimeInterval)value;
- (float)latitude;
- (void)setLatitude:(float)l;
- (float)longitude;
- (void)setLongitude:(float)l;
- (float)origAltitude;
- (void)setOrigAltitude:(float)a;
- (float)altitude;
- (void)setAltitude:(float)a;
- (float)heartrate;
- (void)setHeartrate:(float)h;
- (float)cadence;
- (void)setCadence:(float)c;
- (float)temperature;
- (void)setTemperature:(float)t;
- (float)speed;
- (void)setSpeed:(float)s;
- (float)pace;
- (float)distance;
- (float)power;
- (void)setPower:(float)p;
- (void)setCalculatedPower:(float)p;
- (BOOL)powerIsCalculated;
- (void)setDistance:(float)d;       // set calculated distance
- (float)gradient;
- (void)setGradient:(float)g;
- (BOOL)validLatLon;
- (void)setValidLatLon:(BOOL)v;
- (BOOL)validAltitude;
- (BOOL)validDistance;
- (BOOL)validOrigDistance;
- (BOOL)validHeartrate;
- (BOOL)isDeadZoneMarker;
- (float)climbSoFar;
- (void)setClimbSoFar:(float)value;
- (float)descentSoFar;
- (void)setDescentSoFar:(float)value;
- (BOOL)speedOverridden;
- (void)setSpeedOverriden:(BOOL)set;
- (float)origDistance;
- (void)setOrigDistance:(float)d;      // set distance as reported by device
- (void)setDistanceToOriginal;
- (BOOL)isFirstPointInLap;
- (void)setIsFirstPointInLap:(BOOL)set;
- (NSComparisonResult) compare:(TrackPoint*)anotherPoint;

// accessors that return objects
- (NSNumber*)speedAsNumber;
- (NSNumber*)paceAsNumber;
- (NSNumber*)cadenceAsNumber;
- (NSNumber*)heartrateAsNumber;
- (NSNumber*)powerAsNumber;

-(BOOL)importFlagState:(int)item;
-(void)setImportFlagState:(int)item state:(BOOL)missing;
- (BOOL)beginningOfDeadZone;
- (BOOL)setBeginningOfDeadZone;
- (BOOL)endOfDeadZone;
- (BOOL)setEndOfDeadZone;


@end
