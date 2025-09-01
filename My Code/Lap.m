//
//  Lap.mm
//  TLP
//
//  Created by Rob Boyer on 7/31/06.g
//  Copyright 2006 rcb Construction. All rights reserved.
//


#import "Defs.h"
#import "Lap.h"


static NSDate* sTrackStartTime = nil;

@implementation Lap

- (id) initWithGPSData:(int)idx
startTimeSecsSince1970:(time_t)sts
             totalTime:(unsigned int)tt
         totalDistance:(float)td
              maxSpeed:(float)ms
              beginLat:(float)blat
              beginLon:(float)blon
                endLat:(float)elat
                endLon:(float)elon
              calories:(unsigned int)cals
                 avgHR:(int)ahr
                 maxHR:(int)mhr
                 avgCD:(int)acd
             intensity:(int)inten
               trigger:(int)tm
{
    self = [super init];
    index = idx;
    origStartTime = [NSDate dateWithTimeIntervalSince1970:sts];
    startTimeDelta = 0.0;
    totalTime = (tt/100);
    distance = td/1609.344;     // meters to miles
    maxSpeed = (ms*60.0*60.0)/1609.344;    // meters/sec to mph
    beginLatitude = blat; beginLongitude = blon;
    endLatitude = elat; endLongitude = elon;
    calories = cals;
    averageHeartRate = ahr;
    maxHeartRate = mhr;
    averageCadence = acd;
    intensity = inten;
    triggerMethod = tm;
    statsCalculated = NO;
    deviceTotalTime = 0;
    return self;
}


- (id) init
{
   return [self initWithGPSData:0
		 startTimeSecsSince1970:0
                      totalTime:0
                  totalDistance:0.0
                       maxSpeed:0.0
                       beginLat:180.0
                       beginLon:180.0
                         endLat:180.0
                         endLon:180.0
                       calories:0
                          avgHR:0
                          maxHR:0
                          avgCD:0
                      intensity:0
                        trigger:0];
}


- (void)dealloc
{
    [super dealloc];
}


-(id)doCopy:(NSZone *)zone
{
	Lap* newLap = [[Lap allocWithZone:zone] init];
	[newLap setIndex:index];
	[newLap setOrigStartTime:[origStartTime copy]];
	[newLap setStartingWallClockTimeDelta:startTimeDelta];
	[newLap setTotalTime:totalTime];
	[newLap setDistance:distance];
	[newLap setMaxSpeed:maxSpeed];
	[newLap setAvgSpeed:avgSpeed];
	newLap->beginLatitude = beginLatitude;
	newLap->endLatitude = endLatitude;
	newLap->beginLongitude = beginLongitude;
	newLap->endLongitude = endLongitude;
    newLap->deviceTotalTime = deviceTotalTime;
	[newLap setAvgHeartRate:averageHeartRate];
	[newLap setMaxHeartRate:maxHeartRate];
	[newLap setAverageCadence:averageCadence];
	[newLap setMaxCadence:maxCadence];
	[newLap setCalories:calories];
	[newLap setIntensity:intensity];
	[newLap setTriggerMethod:triggerMethod];
	return newLap;
}


- (id)copyWithZone:(NSZone *)zone
{
	return [self doCopy:zone];
}

	
- (id)mutableCopyWithZone:(NSZone *)zone
{
	return [self doCopy:zone];
}


+ (void) resetStartTime:(NSDate*)startTime;			
{
	sTrackStartTime = startTime;
}

#define DEBUG_DECODE	0
#define CUR_VERSION		2
- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
	printf("decoding Lap\n");
#endif
	self = [super init];
	statsCalculated = NO;
	int version;
	float spareFloat;
	int spareInt;
	[coder decodeValueOfObjCType:@encode(int) at:&version];
	if (version > CUR_VERSION)
	{
		NSException *e = [NSException exceptionWithName:ExFutureVersionName
												 reason:ExFutureVersionReason
											   userInfo:nil];			  
		@throw e;
	}
	[self setOrigStartTime:[coder decodeObject]];
	if (version < 2)
	{
		startTimeDelta = [origStartTime timeIntervalSinceDate:sTrackStartTime];
	}
	else
	{
		[coder decodeValueOfObjCType:@encode(double) at:&startTimeDelta];
	}
	[coder decodeValueOfObjCType:@encode(long long) at:&totalTime];
	[coder decodeValueOfObjCType:@encode(float) at:&beginLatitude];
	[coder decodeValueOfObjCType:@encode(float) at:&beginLongitude];
	[coder decodeValueOfObjCType:@encode(float) at:&endLatitude];
	[coder decodeValueOfObjCType:@encode(float) at:&endLongitude];
	[coder decodeValueOfObjCType:@encode(float) at:&distance];
	[coder decodeValueOfObjCType:@encode(float) at:&maxSpeed];
	[coder decodeValueOfObjCType:@encode(float) at:&avgSpeed];
	[coder decodeValueOfObjCType:@encode(float) at:&deviceTotalTime];   // 1.11.5 BETA 9
	[coder decodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder decodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder decodeValueOfObjCType:@encode(int) at:&averageHeartRate];
	[coder decodeValueOfObjCType:@encode(int) at:&maxHeartRate];
	[coder decodeValueOfObjCType:@encode(int) at:&averageCadence];
	[coder decodeValueOfObjCType:@encode(int) at:&intensity];
	[coder decodeValueOfObjCType:@encode(int) at:&triggerMethod];
	[coder decodeValueOfObjCType:@encode(int) at:&calories];
	[coder decodeValueOfObjCType:@encode(int) at:&maxCadence];
	[coder decodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder decodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder decodeValueOfObjCType:@encode(int) at:&spareInt];   
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	int version = CUR_VERSION;
	float spareFloat = 0.0f;
	int spareInt = 0;
	[coder encodeValueOfObjCType:@encode(int) at:&version];
	[coder encodeObject:origStartTime];
	[coder encodeValueOfObjCType:@encode(double) at:&startTimeDelta];
	[coder encodeValueOfObjCType:@encode(long long) at:&totalTime];
	[coder encodeValueOfObjCType:@encode(float) at:&beginLatitude];
	[coder encodeValueOfObjCType:@encode(float) at:&beginLongitude];
	[coder encodeValueOfObjCType:@encode(float) at:&endLatitude];
	[coder encodeValueOfObjCType:@encode(float) at:&endLongitude];
	[coder encodeValueOfObjCType:@encode(float) at:&distance];
	[coder encodeValueOfObjCType:@encode(float) at:&maxSpeed];
	[coder encodeValueOfObjCType:@encode(float) at:&avgSpeed];
	[coder encodeValueOfObjCType:@encode(float) at:&deviceTotalTime];    // 1.11.5 BETA 9
	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(int) at:&averageHeartRate];
	[coder encodeValueOfObjCType:@encode(int) at:&maxHeartRate];
	[coder encodeValueOfObjCType:@encode(int) at:&averageCadence];
	[coder encodeValueOfObjCType:@encode(int) at:&intensity];
	[coder encodeValueOfObjCType:@encode(int) at:&triggerMethod];
	[coder encodeValueOfObjCType:@encode(int) at:&calories];
	[coder encodeValueOfObjCType:@encode(int) at:&maxCadence];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
}

- (NSTimeInterval) startTimeDelta
{
    return startTimeDelta;
}

- (NSTimeInterval) startingWallClockTimeDelta
{
	return startTimeDelta;
}


- (void) setStartingWallClockTimeDelta:(NSTimeInterval)std
{
	startTimeDelta = std;
}


- (NSDate*) origStartTime
{
	return origStartTime;
}


- (void) setOrigStartTime:(NSDate*)ost
{
	if (ost != origStartTime)
	{
		origStartTime = ost;
	}
}

- (NSComparisonResult) compareByOrigStartTime:(Lap*)anotherLap
{
	return [[self origStartTime] compare:[anotherLap origStartTime]];
}

- (NSComparisonResult) reverseCompareByOrigStartTime:(Lap*)anotherLap
{
	return [[anotherLap origStartTime] compare:[self origStartTime]];
}


- (BOOL)isOrigDateDuringLap:(NSDate*)d
{
   NSDate* endDate = [[NSDate alloc] initWithTimeInterval:[self totalTime] sinceDate:origStartTime];
   BOOL isLessThan = [d compare:origStartTime] == NSOrderedAscending;
   BOOL isGreaterThan = [d compare:endDate] == NSOrderedDescending;
   return ((isLessThan == NO) && (isGreaterThan == NO));
}


- (BOOL)isDeltaTimeDuringLap:(NSTimeInterval)delta
{
	return IS_BETWEEN(startTimeDelta, delta, (startTimeDelta + totalTime));
}



- (NSTimeInterval) totalTime
{ 
   return totalTime;
}


- (void) setTotalTime:(NSTimeInterval)tt
{
    totalTime = tt;
}


-(void)setDeviceTotalTime:(NSTimeInterval)dtt
{
    deviceTotalTime = dtt;
}


-(NSTimeInterval) deviceTotalTime
{
    return deviceTotalTime;
}



- (NSString *)durationAsString
{
   NSTimeInterval dur = [self totalTime];
   int hours = (int)dur/3600;
   int mins = (int)(dur/60.0) % 60;
   int secs = (int)dur % 60;
   return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}


- (float) distance
{
   return distance;
}


- (void)setDistance:(float)d
{
   distance = d;
}


- (float) maxSpeed
{ 
   return maxSpeed;
}


- (void)setMaxSpeed:(float)ms
{
   maxSpeed = ms;
}


- (float) avgSpeed
{ 
	return avgSpeed;
}


- (void)setAvgSpeed:(float)as
{
	avgSpeed = as;
}


- (float) beginLatitude
{
   return beginLatitude;
}


- (void) setBeginLatitude:(float)val
{
	beginLatitude = val;
}


- (float) beginLongitude
{
   return beginLongitude;
}


- (void) setBeginLongitude:(float)val
{
	beginLongitude = val;
}


- (float) endLatitude
{
   return endLatitude;
}


- (void) setEndLatitude:(float)val
{
	endLatitude = val;
}


- (float) endLongitude
{
   return endLongitude;
}


- (void) setEndLongitude:(float)val
{
	endLongitude = val;
}


- (int) averageHeartRate
{
   return averageHeartRate;
}


- (void)setAvgHeartRate:(int)mhr
{
   averageHeartRate = mhr;
}


- (int) maxHeartRate
{
   return maxHeartRate;
}


- (void)setMaxHeartRate:(int)mhr
{
   maxHeartRate = mhr;
}


- (int) averageCadence
{
   return averageCadence;
}


- (void)setAverageCadence:(int)avc
{
   averageCadence = avc;
}


- (int) maxCadence
{
	return maxCadence;
}


- (void)setMaxCadence:(int)mc
{
	maxCadence = mc;
}


- (int)calories 
{
   return calories;
}


- (void)setCalories:(int)value 
{
   if (calories != value) 
   {
      calories = value;
   }
}


- (int)intensity 
{
   return intensity;
}


- (void)setIntensity:(int)value 
{
   if (intensity != value) 
   {
      intensity = value;
   }
}


- (int)triggerMethod 
{
   return triggerMethod;
}


- (void)setTriggerMethod:(int)value 
{
   if (triggerMethod != value) 
   {
      triggerMethod = value;
   }
}



- (int) index
{
   return index;
}

- (void)setIndex:(int)idx
{
	index = idx;
}



- (NSComparisonResult) compare:(id)lap2
{
	NSTimeInterval lap2Delta = [lap2 startingWallClockTimeDelta];
 	if (startTimeDelta < lap2Delta)
	{
		return NSOrderedAscending;
	}
	else if (startTimeDelta == lap2Delta)
	{
		return NSOrderedSame;
	}
	return NSOrderedDescending;
}


- (BOOL)isEqual:(id)otherLap
{
   return startTimeDelta == [otherLap startingWallClockTimeDelta];
}


- (BOOL)selected {
   return selected;
}

- (void)setSelected:(BOOL)value {
   if (selected != value) {
      selected = value;
   }
}


- (struct tStatData*) getStat:(int)type
{
   return &statsArray[type];
}


- (struct tStatData*) getStatArray
{
   return statsArray;
}


- (void) setStatsCalculated:(BOOL)done
{
   statsCalculated = done;
}


- (BOOL) statsCalculated
{
   return statsCalculated;
}



@end
