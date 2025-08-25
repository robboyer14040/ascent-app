//
//  TrackPoint.m
//  TLP
//
//  Created by Rob Boyer on 7/13/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "Defs.h"
#import "TrackPoint.h"
#import "Utils.h"

// flags for the 'flags' field, stored persistently
enum
{
	kSpeedOverriden					= 0x00000001,
	kIsFirstPointInLap				= 0x00010000,
	kPowerDataCalculated			= 0x00000020,
    kStartDeadZoneMarker            = 0x00000100,
    kEndDeadZoneMarker              = 0x00000200,
	// import-related
	kImportFlags					= 0xfff00000,

};


#define DATA_ITEM_TO_FLAG(di)		(1 << ((int)di + 20))


@implementation TrackPoint
- (id)initWithGPSData:(NSTimeInterval)wcd 
           activeTime:(NSTimeInterval)atd
             latitude:(float)lat
            longitude:(float)lon
             altitude:(float)alt
            heartrate:(int)hr
              cadence:(int)cd
          temperature:(float)temp
                speed:(float)sp
             distance:(float)d
{
  // NSTimeInterval ti = (NSTimeInterval) creationTime;
  // date = [NSDate dateWithTimeIntervalSince1970:ti];
   //[date retain];
  // activeTime = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval) at];
  // [activeTime retain];
	wallClockDelta = wcd;
	activeTimeDelta = atd;
	latitude = lat;
	longitude = lon;
	validLatLon = [Utils validateLatitude:lat longitude:lon];
	heartrate = (float)hr;
	origAltitude = altitude = alt;
	power = 0;
	if (cd >= 255)
	{
		cadence = 0.0;
	}
	else
	{
		cadence = (float)cd;
	}
	temperature = temp;
	speed = sp;
	origDistance = distance = d;
	gradient = 0.0;
	climbSoFar = 0.0;
	descentSoFar = 0.0;
	flags = 0;
	return self;
}


-(id)init
{
   self = [self initWithGPSData:0
                     activeTime:0
                       latitude:BAD_LATLON     // must be bad value
                      longitude:BAD_LATLON     // must be bad value
                       altitude:BAD_ALTITUDE     // must be bad value
                      heartrate:0
                        cadence:0
                    temperature:0
                          speed:0.0
                    distance:BAD_DISTANCE];
	//date = [NSDate dateWithTimeIntervalSince1970:0];
	//[date retain];
	//activeTime = [NSDate dateWithTimeIntervalSince1970:0];
	//[activeTime retain];
	wallClockDelta = activeTimeDelta = 0.0;
	validLatLon = NO;
	return self;
}


-(void)dealloc
{
}


- (id)mutableCopyWithZone:(NSZone *)zone
{
	TrackPoint* newPoint = [[TrackPoint allocWithZone:zone] init];
	[newPoint setWallClockDelta:wallClockDelta];
	[newPoint setActiveTimeDelta:activeTimeDelta];
	[newPoint setAltitude:altitude];
	[newPoint setOrigAltitude:origAltitude];
	[newPoint setLatitude:latitude];
	[newPoint setLongitude:longitude];
	[newPoint setHeartrate:heartrate];
	[newPoint setCadence:cadence];
	[newPoint setTemperature:temperature];
	[newPoint setSpeed:speed];
	[newPoint setDistance:distance];
	[newPoint setGradient:gradient];
	[newPoint setOrigDistance:origDistance];
	[newPoint setValidLatLon:validLatLon];
	[newPoint setClimbSoFar:climbSoFar];
	[newPoint setDescentSoFar:descentSoFar];
	[newPoint setPower:power];
	newPoint->flags = flags;
	return newPoint;
}


- (id)initWithDeadZoneMarker:(NSTimeInterval)wcd activeTimeDelta:(NSTimeInterval)atd
{
	wallClockDelta = wcd;
	activeTimeDelta = atd;
	latitude = longitude = BAD_LATLON;
	heartrate = 0.0;
	cadence = 0.0;
	altitude = BAD_ALTITUDE;
	origDistance = distance = BAD_DISTANCE;
	gradient = 0.0;
	speed = 0.0;
	climbSoFar = 0.0;
	descentSoFar = 0.0;
	flags = 0;
	return self;
}


// old school, hackish way of marking dead zones use methods below
- (BOOL) isDeadZoneMarker
{
   return /*(altitude == BAD_ALTITUDE) &&*/  (origDistance == BAD_DISTANCE) && (latitude == BAD_LATLON) && (longitude == BAD_LATLON);
}


- (BOOL)beginningOfDeadZone
{
    return FLAG_IS_SET(flags, kStartDeadZoneMarker);
}


- (BOOL)setBeginningOfDeadZone
{
    return SET_FLAG(flags, kStartDeadZoneMarker);
}


- (BOOL)endOfDeadZone
{
    return FLAG_IS_SET(flags, kEndDeadZoneMarker);
}


- (BOOL)setEndOfDeadZone
{
    return SET_FLAG(flags, kEndDeadZoneMarker);
}



static NSDate* sStartTime = nil;

+ (void) resetStartTime:(NSDate*)startTime;			// for use in converting old point data that had dates instead of delta times
{
	if (startTime != sStartTime)
	{
	}
}


#define CUR_VERSION		5
#define DEBUG_DECODE_POINT		0


- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE_POINT
	printf("  decoding TrackPoint\n");
#endif
	self = [super init];
	int version;
	float fval;
	int ival;
	[coder decodeValueOfObjCType:@encode(int) at:&version];
#if DEBUG_DECODE_POINT
	printf("    version\n");
#endif
	if (version > CUR_VERSION)
	{
		NSException *e = [NSException exceptionWithName:ExFutureVersionName
												 reason:ExFutureVersionReason
											   userInfo:nil];			  
		@throw e;
	}
	
	NSDate* wallDate = nil;
	NSDate* activeTimeDate = nil;
	if (version < 4)
	{
		wallDate = [coder decodeObject];
#if DEBUG_DECODE_POINT
	printf("    wall date\n");
#endif
		activeTimeDate = wallDate;

		assert(sStartTime);
		wallClockDelta = activeTimeDelta = [wallDate timeIntervalSinceDate:sStartTime];
	}
	else
	{
		[coder decodeValueOfObjCType:@encode(double) at:&wallClockDelta];
#if DEBUG_DECODE_POINT
	printf("    wall clock delta\n");
#endif
		[coder decodeValueOfObjCType:@encode(double) at:&activeTimeDelta];
#if DEBUG_DECODE_POINT
	printf("    active time delta\n");
#endif
	}
	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    active distance\n");
#endif
	[self setDistance:fval];
	origDistance = fval;

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    latitude\n");
#endif
	[self setLatitude:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    longitude\n");
#endif
	[self setLongitude:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    altitude\n");
#endif
	[self setAltitude:fval];
	origAltitude = fval;

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    speed\n");
#endif
	[self setSpeed:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    temperature\n");
#endif
	[self setTemperature:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];		// added in v5 
#if DEBUG_DECODE_POINT
	printf("    power\n");
#endif
	[self setPower:fval];										// added in v5 

	[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
#if DEBUG_DECODE_POINT
	printf("    fspare\n");
#endif

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    heartrate\n");
#endif
	[self setHeartrate:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
#if DEBUG_DECODE_POINT
	printf("    cadence\n");
#endif
	if (fval >= 254.5) fval = 0.0;     // illegal cadence value, not present
	[self setCadence:fval];

	[coder decodeValueOfObjCType:@encode(int) at:&flags];      // added in v3
#if DEBUG_DECODE_POINT
	printf("    flags\n");
#endif

	[coder decodeValueOfObjCType:@encode(int) at:&ival];        // spare
#if DEBUG_DECODE_POINT
	printf("    spare\n");
#endif

	if ((version < 4) && (version > 1))
	{
		activeTimeDate = [coder decodeObject];            // added in v2
#if DEBUG_DECODE_POINT
		printf("    active time date\n");
#endif
		activeTimeDelta = [activeTimeDate timeIntervalSinceDate:sStartTime];
	}
	validLatLon = [Utils validateLatitude:latitude longitude:longitude];
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	int version = CUR_VERSION;
	float spareFloat = 0.0f;
	int spareInt = 0;
	[coder encodeValueOfObjCType:@encode(int) at:&version];
	[coder encodeValueOfObjCType:@encode(double) at:&wallClockDelta];
	[coder encodeValueOfObjCType:@encode(double) at:&activeTimeDelta];
	[coder encodeValueOfObjCType:@encode(float) at:&origDistance];	// 'distance' field is always calculated in Track::fixDistance
	[coder encodeValueOfObjCType:@encode(float) at:&latitude];
	[coder encodeValueOfObjCType:@encode(float) at:&longitude];
	[coder encodeValueOfObjCType:@encode(float) at:&origAltitude];	// 'altitude' field may be re-calculated in Track::fixupTrack
	[coder encodeValueOfObjCType:@encode(float) at:&speed];
	[coder encodeValueOfObjCType:@encode(float) at:&temperature];
	float p = (!(FLAG_IS_SET(flags, kPowerDataCalculated)) ? power : 0.0);
	[coder encodeValueOfObjCType:@encode(float) at:&p];			// added in v5
	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(float) at:&heartrate];
	[coder encodeValueOfObjCType:@encode(float) at:&cadence];
	[coder encodeValueOfObjCType:@encode(int) at:&flags];			// added in v3
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
}


- (void)setValidLatLon:(BOOL)v
{
	validLatLon = v;
}


- (BOOL)validLatLon
{
   return validLatLon;
}

- (BOOL)validAltitude 
{
	// if altitude is *exactly* 0.0 assume it is a bad value.  BAD_ALTITUDE values may have
	// been overriden at the beginning of activities due to a bug in 1.8.x, but they will always be 0.
	return (origAltitude != 0.0) && (VALID_ALTITUDE(origAltitude));
}


- (BOOL)validDistance 
{
   return VALID_DISTANCE(distance);
}


- (BOOL)validOrigDistance 
{
	return VALID_DISTANCE(origDistance);
}



- (BOOL)validHeartrate {
   return heartrate > 0;
}


- (NSTimeInterval)wallClockDelta 
{
    return wallClockDelta;
}

- (void)setWallClockDelta:(NSTimeInterval)value 
{
    wallClockDelta = value;
}

- (NSTimeInterval)activeTimeDelta {
    return activeTimeDelta;
}

- (void)setActiveTimeDelta:(NSTimeInterval)value 
{
      activeTimeDelta = value;
}


#if 0
- (NSDate *)date
{
   return date;
}


- (void)setDate:(NSDate *)d
{
   d = [d copy];
   [date release];
   date = d;
}


- (NSDate *)activeTime {
   return [[activeTime retain] autorelease];
}

- (void)setActiveTime:(NSDate *)value {
   if (activeTime != value) {
      [activeTime release];
      activeTime = [value copy];
   }
}
#endif



- (float)latitude
{
   return latitude;
}


- (void)setLatitude:(float)l
{
   latitude = l;
   validLatLon = [Utils validateLatitude:latitude longitude:longitude];
}


- (float)longitude
{
   return longitude;
}


- (void)setLongitude:(float)l
{
   longitude = l;
   validLatLon = [Utils validateLatitude:latitude longitude:longitude];
}


typedef float (*tAcc)(id, SEL);


- (float)origAltitude
{
	return origAltitude;
}


- (void)setOrigAltitude:(float)a
{
	origAltitude = a;
}


- (float)altitude
{
   return altitude;
}

- (void)setAltitude:(float)a
{
   altitude = a;
}

- (float)heartrate
{
   return heartrate;
}


- (void)setHeartrate:(float)h
{
   heartrate = h;
}


- (float)cadence
{
   return cadence;
}


- (void)setCadence:(float)c
{
   cadence = c;
}


- (float)temperature
{
   return temperature;
}


- (void)setTemperature:(float)t
{
   temperature = t;
}


- (float)speed
{
   return speed;
}


- (float)pace
{
   if (speed > 0.0)
   {
      return 3600.0/speed;       // seconds/mile
   }
   else
   {
      return 3600.0;
   }
}


- (void)setSpeed:(float)s
{
   speed = s;
}

- (float)power
{
	return power;
}



- (void)setPower:(float)p
{
	if (p < MAX_REASONABLE_POWER)
	{
		power = p;
		if (p > 0.0) CLEAR_FLAG(flags, kPowerDataCalculated);
	}
#if _DEBUG
	else
	{
		printf("power = %0.1f, wtf?\n", p);
	}
#endif
}


- (void)setCalculatedPower:(float)p
{
	if (IS_BETWEEN(0.0, p, MAX_REASONABLE_POWER))
	{
		power = p;
		SET_FLAG(flags, kPowerDataCalculated);
	}
#if _DEBUG
	else
	{
		///printf("calc power = %0.1f, wtf?\n", p);
	}
#endif
}


-(BOOL)powerIsCalculated
{
	return FLAG_IS_SET(flags, kPowerDataCalculated);
}


-(void)setImportFlagState:(int)item state:(BOOL)st
{
	int flag = DATA_ITEM_TO_FLAG(item);
	if (st)
	{
		SET_FLAG(flags, flag);
	}
	else
	{
		CLEAR_FLAG(flags, flag);
	}
}


-(BOOL)importFlagState:(int)item
{
	int flag = DATA_ITEM_TO_FLAG(item);
	return FLAG_IS_SET(flags, flag);
}


- (float)distance
{
   return distance;
}


- (void)setDistance:(float)d
{
   distance = d;
}


- (float)gradient
{
   return gradient;
}


- (void)setGradient:(float)g
{
   gradient = g;
}


- (float)climbSoFar {
   return climbSoFar;
}


- (void)setClimbSoFar:(float)value {
   if (climbSoFar != value) {
      climbSoFar = value;
   }
}


- (float)descentSoFar {
   return descentSoFar;
}


- (void)setDescentSoFar:(float)value {
   if (descentSoFar != value) {
      descentSoFar = value;
   }
}


- (BOOL)speedOverridden
{
   return FLAG_IS_SET(flags, kSpeedOverriden);
}


- (void)setSpeedOverriden:(BOOL)set
{
   if (set)
   {
      SET_FLAG(flags, kSpeedOverriden);
   }
   else
   {
      CLEAR_FLAG(flags, kSpeedOverriden);
   }
}


- (BOOL)isFirstPointInLap
{
	return FLAG_IS_SET(flags, kIsFirstPointInLap);
}


- (void)setIsFirstPointInLap:(BOOL)set
{
	if (set)
	{
		SET_FLAG(flags, kIsFirstPointInLap);
	}
	else
	{
		CLEAR_FLAG(flags, kIsFirstPointInLap);
	}
}


- (void)setDistanceToOriginal
{
   distance = origDistance;
}


- (float)origDistance
{
	return origDistance;
}


-(void)setOrigDistance:(float)d
{
   origDistance = d;
}

- (NSNumber*)speedAsNumber
{
	return [NSNumber numberWithFloat:self.speed];
}


- (NSNumber*)paceAsNumber
{
	return [NSNumber numberWithFloat:self.pace];
}

- (NSNumber*)cadenceAsNumber
{
	return [NSNumber numberWithFloat:self.cadence];
}

- (NSNumber*)heartrateAsNumber
{
	return [NSNumber numberWithFloat:self.heartrate];
}

- (NSNumber*)powerAsNumber
{
	return [NSNumber numberWithFloat:self.power];
}


- (NSComparisonResult) compare:(TrackPoint*)anotherPoint
{
	NSTimeInterval otherPointWCD = [anotherPoint wallClockDelta];
	if  (wallClockDelta < otherPointWCD)
		return NSOrderedAscending;
	else if (wallClockDelta > otherPointWCD)
		return NSOrderedDescending;
	else 
		return NSOrderedSame;
}

@end
