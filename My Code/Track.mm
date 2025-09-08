//
//  Track.m
//  TLP
//
//  Created by Rob Boyer on 7/11/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "Defs.h"
#import "Track.h"
#import "TrackPoint.h"
#import "Lap.h"
#import "Utils.h"
#import "ProgressBarController.h"
#import "OverrideDefs.h"
#import "PathMarker.h"
#import "StringAdditions.h"
#import "OverrideData.h"


//------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------

@implementation LapInfo

- (id) initWithData:(Lap*)lp startIdx:(int)sp numPoints:(int)np
{
   lap = lp;
   startingPointIdx = sp;
   numPoints = np;
   return [super init];
}


- (id) init
{
   return [self initWithData:nil startIdx:0 numPoints:0];
}


- (void) dealloc
{
    [super dealloc];
}

- (Lap*) lap
{
   return lap;
}


- (int) numPoints
{
   return numPoints;
}

- (int) startingPointIndex
{
   return startingPointIdx;
}

- (NSTimeInterval) activeTimeDelta
{
    return activeTimeDelta;
}

- (void) setActiveTimeDelta:(NSTimeInterval) atd
{
    activeTimeDelta = atd;
}

@end


//------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------


//------------------------------------------------------------------------------------------

@interface Track ()


-(void)calcPeaks;
- (float)realDurationOfLap:(Lap*)lap;
- (void) checkPowerData;
- (void)fixLapDurations;

@end

@implementation Track
@synthesize photoURLs = _photoURLs;
@synthesize localMediaItems = _localMediaItems;

@synthesize stravaActivityID = _stravaActivityID;
@synthesize timeZoneName = _timeZoneName;
@synthesize equipmentUUIDs;
@synthesize mainEquipmentUUID;
@synthesize equipmentWeight;
@synthesize firmwareVersion;
@synthesize animID;
@synthesize minGradientDistance;
@synthesize animTimeBegin;
@synthesize animTimeEnd;
@synthesize laps;
@synthesize deviceTotalTime;

// items from track source - used if points not available, stored persistently
@synthesize srcDistance;
@synthesize srcMaxSpeed;
@synthesize srcAvgHeartrate;
@synthesize srcMaxHeartrate;
@synthesize srcAvgTemperature;
@synthesize srcMaxElevation;
@synthesize srcMinElevation;
@synthesize srcAvgPower;
@synthesize srcMaxPower;
@synthesize srcAvgCadence;
@synthesize srcTotalClimb;
@synthesize srcKilojoules;
@synthesize srcElapsedTime;
@synthesize srcMovingTime;
@synthesize gpxFileName;


- (id)init
{
    self = [super init];
    _stravaActivityID = 0;
    attributes = [[NSMutableArray alloc] initWithCapacity:kNumAttributes];
    int i;
    for (i=0; i<kNumAttributes; i++) [attributes addObject:@""];

    // set default attributes
    NSString* activity;
    NSString* eventType;
    activity = [Utils stringFromDefaults:RCBDefaultActivity];
    if ((activity==nil) || [activity isEqualToString:@""])
        activity = @kCycling;
    eventType = [Utils stringFromDefaults:RCBDefaultEventType];
    if ((eventType==nil) || [eventType isEqualToString:@""])
        eventType = @kTraining;
    
    [self setUuid:[NSString uniqueString]];
    [attributes replaceObjectAtIndex:kActivity withObject:activity];
    [attributes replaceObjectAtIndex:kEffort withObject:@kMedium];
    [attributes replaceObjectAtIndex:kDisposition withObject:@kOK];
    [attributes replaceObjectAtIndex:kEventType withObject:eventType];
    [attributes replaceObjectAtIndex:kWeather withObject:@kSunny];
    // ALWAYS store values in STATUTE units!!!
    //[attributes replaceObjectAtIndex:kWeight withObject:[self getStatuteDefaultWeightAsString]];
    weight = [Utils floatFromDefaults:RCBDefaultWeight];

    points = [[NSMutableArray alloc] init];
    laps = [[NSMutableArray alloc] init];
    lapInfoArray = [[NSMutableArray alloc] init];
    markers = [[NSMutableArray alloc] init];
    goodPoints = [[NSMutableArray alloc] init];
    name = @"";
    creationTime = nil;
    creationTimeOverride = nil;
    deviceTotalTime = 0.0;
    distance = 0.0;
    animTime = 0.0;
    animIndex = 0;
    peakIntervalData = 0;
    deviceID = -1;
    firmwareVersion = 0;
    NSTimeZone* tz = [NSTimeZone localTimeZone];
    secondsFromGMT = (int)[tz secondsFromGMTForDate:[NSDate date]];
    [self initNonPersistantData];
    hrzCacheStart = hrzCacheEnd = -42;
    flags = 0;
    equipmentWeight = kDefaultEquipmentWeight;
    if ([Utils boolFromDefaults:RCBDefaultUseDistanceDataEnabled])
    {
        SET_FLAG(flags, kUseOrigDistance);
    }
    overrideData = [[OverrideData alloc] init];
    ///BOOL calcPower = [Utils boolFromDefaults:RCBDefaultCalculatePowerIfAbsent];
    [self setEnableCalculationOfPower:YES];
    altitudeSmoothingFactor = [Utils floatFromDefaults:RCBDefaultAltitudeSmoothingPercentage];
    
    srcDistance = 0.0;
    srcMaxSpeed = 0.0;
    srcAvgHeartrate = 0.0;
    srcMaxHeartrate = 0.0;
    srcAvgTemperature = 0.0;
    srcMaxElevation = 0.0;
    srcMinElevation = 0.0;
    srcAvgPower = 0.0;
    srcMaxPower = 0.0;
    srcAvgCadence = 0.0;
    srcTotalClimb = 0.0;
    srcKilojoules = 0.0;
    srcElapsedTime = 0.0;
    srcMovingTime = 0.0;

    
    return self;
}


- (void)dealloc
{
#if 0&&DEBUG_LEAKS
    NSLog(@"  TRACK dealloc'd... ");
#endif
    [attributes release];
    [laps release];
    [points release];
    [markers release];
    [equipmentUUIDs release];
    [gpxFileName release];
    [overrideData release];
     free(peakIntervalData);
    [_photoURLs release];
    [_localMediaItems release];
    [_stravaActivityID release];
    [_timeZoneName release];
    [super dealloc];
}


-(NSString*) uuid
{
    return uuid;
}


-(void) setUuid:(NSString*)s
{
    if (uuid != s)
    {
        uuid = [s retain];      // added retain, FIXME
    }
}



-(void)initNonPersistantData
{
    for (int i=0; i<kST_NumStats; i++)
    {
        for (int j=0; j<kNumValsPerStat; j++)
        {
            statsArray[i].vals[j] = 0.0;
        }
        statsArray[i].atActiveTimeDelta[kMin] = statsArray[i].atActiveTimeDelta[kMax] = 0.0;
    }
    
    statsCalculated = NO;
    self.movingSpeedOnly = YES;
    minGradientDistance = 175.0;      // feet, tweaky adjustment
    peakIntervalData = 0;
    self.equipmentUUIDs = nil;
    animTimeBegin = 0.0;
    animTimeEnd = 0.0;
    self.mainEquipmentUUID = nil;
    distance = 0.0;
}


-(void)setOverrideData:(OverrideData*)od
{
	if (od != overrideData)
	{
		overrideData = [od retain];
	}
}

// not sure why mutableCopyWithZone for a NSMutableArray doesn't do this...
-(NSMutableArray*)deepCopyOfMutableArray:(NSArray*)arr zone:(NSZone*)zn
{
    NSUInteger num = [arr count];
	NSMutableArray* outArr = [NSMutableArray arrayWithCapacity:num];
	for (int i=0; i<num; i++)
	{
		[outArr addObject:[[arr objectAtIndex:i] mutableCopyWithZone:zn]];
	}
	return outArr;
}


-(id)mutableCopyWithZone:(NSZone *)zone
{
	Track* newTrack = [[Track allocWithZone:zone] init];
	[newTrack setCreationTime:[creationTime copy]];
	[newTrack setCreationTimeOverride:[creationTimeOverride copy]];
	[newTrack setName:[name copy]];
	[newTrack setAttributes:[self deepCopyOfMutableArray:attributes zone:zone]];
	[newTrack setLaps:[self deepCopyOfMutableArray:laps zone:zone]];
	[newTrack setPoints:[self deepCopyOfMutableArray:points zone:zone]];
	[newTrack setMarkers:[self deepCopyOfMutableArray:markers zone:zone]];
    // equipmentUUIDs is a property and doesn't need to be retained
	[newTrack setEquipmentUUIDs:[self deepCopyOfMutableArray:equipmentUUIDs zone:zone]];
	[newTrack setMainEquipmentUUID:[self mainEquipmentUUID]];
	[newTrack setSecondsFromGMT:secondsFromGMT];
	[newTrack setDistance:distance];
	[newTrack setWeight:weight];
	[newTrack setOverrideData:[overrideData mutableCopyWithZone:zone]];
	[newTrack setSecondsFromGMT:secondsFromGMT];
	[newTrack setDeviceID:deviceID];
	[newTrack setAltitudeSmoothingFactor:altitudeSmoothingFactor];
	[newTrack setDeviceTotalTime:deviceTotalTime];
	newTrack->flags = flags;
	return newTrack;
}

-(int)deviceID
{
	return deviceID;
}


-(void)setDeviceID:(int)devID
{
	static int sDevID = 0;
	deviceID = devID;
	if (sDevID == 0)
	{
#if _DEBUG
		NSLog(@"set device ID to %d", devID);
#endif
		sDevID = devID;
	}
	switch( devID )
	{
		case kGarminEdgeDeviceID:
			altitudeSmoothingFactor = 25.0;
			break;
			
		case kGarminForerunnerDeviceID:
			altitudeSmoothingFactor = 80.0;
			break;
		
		default:
			break;
	}
}


-(void)setAltitudeSmoothingFactor:(float)v
{
	altitudeSmoothingFactor = v;
}


-(float)altitudeSmoothingFactor
{
	return altitudeSmoothingFactor;
}


- (NSString*) getStatuteDefaultWeightAsString
{
   float v = [Utils floatFromDefaults:RCBDefaultWeight];
   return  [NSString stringWithFormat:@"%0.1f", v];
}   




#define TRACK_CUR_VERSION		9

// make *sure* that there are no duplicate laps, and that the
// array is mutable.  An earlier screw-up may have caused some lap
// arrays to be stored as immutable.
- (NSMutableArray*) checkLaps:(NSArray*)inLaps
{
	NSMutableArray* olaps = [[NSMutableArray alloc] init];
    NSUInteger num = [inLaps count];
	for (int i=0; i<num; i++)
	{
		Lap* lap = [inLaps objectAtIndex:i];
		if ([olaps indexOfObjectIdenticalTo:lap] == NSNotFound)
		{
			[olaps addObject:lap];
		}
		else
		{
			NSLog(@"removed DUPLICATE LAP!");
		}
	}
	return olaps;
}


#define DEBUG_DECODE		0

- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
	static int count = 0;
	printf("decoding track %d\n", ++count);
	if (count == 56)
	{
		printf("wtf!\n");
	}
#endif
	self = [super init];
	int version;
	[coder decodeValueOfObjCType:@encode(int) at:&version];
	if (version > TRACK_CUR_VERSION)
	{
		NSException *e = [NSException exceptionWithName:ExFutureVersionName
												 reason:ExFutureVersionReason
											   userInfo:nil];			  
		@throw e;
	}
	points = [[NSMutableArray alloc] init];
	lapInfoArray = [[NSMutableArray alloc] init];
	[self setLaps:nil];
	[self setMarkers:nil];
	NSMutableArray* inMarkers = nil;
	float fval;
	float fWeight;
	//int ival;
	statsCalculated = NO;
	NSTimeZone* tz = [NSTimeZone localTimeZone];
	secondsFromGMT = (int)[tz secondsFromGMTForDate:[NSDate date]];
	[self setName:[coder decodeObject]];
	[self setCreationTime:[coder decodeObject]];
	[TrackPoint resetStartTime:[self creationTime]];	// needed to convert earlier point data
	[self setPoints:[coder decodeObject]];
	[self setAttributes:[coder decodeObject]];
	[Lap resetStartTime:[self creationTime]];			// needed to convert earlier lap data
	NSArray* inLaps = [coder decodeObject];
	NSMutableArray* outLaps = [self checkLaps:inLaps];
	[coder decodeValueOfObjCType:@encode(float) at:&fval];
	if ((distance > 10000.0) || (distance < 0.01))
	{
		distance = 0.0;
	}
	[self setDistance:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fWeight];   // added in v4   
	[coder decodeValueOfObjCType:@encode(float) at:&altitudeSmoothingFactor];      // added in v8
	[coder decodeValueOfObjCType:@encode(float) at:&equipmentWeight];			// changed in v9 from spare (did not incr version)
	[coder decodeValueOfObjCType:@encode(float) at:&deviceTotalTime];      // changed in v9 from spare (did not incr version)

	int secsFromGMT;
	[coder decodeValueOfObjCType:@encode(int) at:&secsFromGMT];   // spare only valid in V3 or up
	//NSLog(@"track offset from GMT: %02.2d:%02.2d:%02.2d", secsFromGMT/(3600), (secsFromGMT/60) % 60, secsFromGMT % 60);

	[coder decodeValueOfObjCType:@encode(int) at:&flags];       // added in v5

	[coder decodeValueOfObjCType:@encode(int) at:&deviceID];    // added in v8

	[coder decodeValueOfObjCType:@encode(int) at:&firmwareVersion];   // changed from spare during v9

	if (version > 1)
	{
		[self setMarkers:[coder decodeObject]];
	}
	
	if (version > 2)
	{
		[self setSecondsFromGMT:secsFromGMT];
	}
	
	if (version > 3)
	{
		weight = fWeight;
	}
	else
	{
		NSString* s = [self attribute:kWeight];
		float w = [s floatValue];
		if (w == 0.0)
		{
			w = [Utils floatFromDefaults:RCBDefaultWeight];
		}
		weight = w;
	}
	
	if (version > 5)
	{
		[self setOverrideData:[coder decodeObject]];
	}
	if (version > 6)
	{
		[self setCreationTimeOverride:[coder decodeObject]]; 
	}
	else
	{
		overrideData = [[OverrideData alloc] init];
		CLEAR_FLAG(flags, kOverrideCreationTime);		// make SURE this flag isn't set
	}
	if (FLAG_IS_SET(flags, kOverrideCreationTime) && (creationTimeOverride == nil))
	{
		CLEAR_FLAG(flags, kOverrideCreationTime);		// make SURE this flag isn't set
	}	
	
	if (version > 8)
	{
		[self setUuid:[coder decodeObject]];
	}
	else
	{
		[self setUuid:[NSString uniqueString]];
	}
	if (outLaps == nil) 
		outLaps = [NSMutableArray array];
	if (inMarkers == nil)
		inMarkers = [NSMutableArray array];
	goodPoints = [[NSMutableArray alloc] init];

	[self initNonPersistantData];
	[self setLaps:outLaps];
	[self fixupTrack];
	[self setMarkers:inMarkers];
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	ProgressBarController* pbc = [pb controller];
	[pbc incrementDiv];
	int total = [pbc totalDivs];
	int current = [pbc currentDivs];
	if ((total < 10) ||
		((current % 10) == 0) ||
		(current >= total))
	{
		[pbc updateMessage:[NSString stringWithFormat:@"writing activity %d of %d", current, [pbc totalDivs]]];
	}
	//[[pb controller] updateMessage:s];
	int version = TRACK_CUR_VERSION;
	//int spareInt = 0;
	[coder encodeValueOfObjCType:@encode(int) at:&version];
	[coder encodeObject:name];
	[coder encodeObject:creationTime];
	[coder encodeObject:points];
	[coder encodeObject:attributes];
	[coder encodeObject:laps];
	[coder encodeValueOfObjCType:@encode(float) at:&distance];
	[coder encodeValueOfObjCType:@encode(float) at:&weight];                // added in v4
	[coder encodeValueOfObjCType:@encode(float) at:&altitudeSmoothingFactor];	// added in v8
	[coder encodeValueOfObjCType:@encode(float) at:&equipmentWeight];       // changed in v9 from spare (did not incr version)
	[coder encodeValueOfObjCType:@encode(float) at:&deviceTotalTime];       // changed in v9 from spare (did not incr version)
	[coder encodeValueOfObjCType:@encode(int) at:&secondsFromGMT];    // only valid in v3 or higher
	[coder encodeValueOfObjCType:@encode(int) at:&flags];                   // added in v5
	[coder encodeValueOfObjCType:@encode(int) at:&deviceID];				// added in v8
	[coder encodeValueOfObjCType:@encode(int) at:&firmwareVersion];			// changed from spare during v9
	[coder encodeObject:markers];				// added in v2
	[coder encodeObject:overrideData];			// added in v6
	[coder encodeObject:creationTimeOverride];	// added in v7
	[coder encodeObject:uuid];					// added in v9
}




- (NSMutableArray*) goodPoints
{
   if ([goodPoints count] == 0)
   {
       NSUInteger num = [points count];
      int i;
      for (i=0; i<num; i++)
      {
         TrackPoint* pt = [points objectAtIndex:i];
         if ([pt isDeadZoneMarker]) continue;
         [goodPoints addObject:pt];
      }
   }
   return goodPoints;
}



-(int) findNextGoodAltIdx:(int)startIdx
{
   int i = startIdx;
   NSUInteger num = [points count];
   while (i < num)
   {
      TrackPoint* pt = [points objectAtIndex:i];
       if ([pt validAltitude])
      {
         return i;
      }
      ++i;
   }
   return -1;
}


-(TrackPoint*) nextValidGoodDistancePoint:(int)start
{
	TrackPoint* pt = nil;
	NSArray* pts = [self goodPoints];
    NSUInteger count = [pts count];
	int i = start+1;
	while (i < count)
	{
		TrackPoint* tpt = [pts objectAtIndex:i];
		if ([tpt validDistance])
		{
			pt = tpt;
			break;
		}
		++i;
	}
	return pt;
}


- (float) movingSpeedThreshold
{
   return [Utils floatFromDefaults:RCBDefaultMinSpeed];
}


- (float) movingDistanceThreshold
{
   return [Utils floatFromDefaults:RCBDefaultMinDistance]/5280.0;
}




//-------------------------------------------------------------------------------------------------------------
//---- LAP-RELATED METHODS ------------------------------------------------------------------------------------

// NOTE: all track point indices stored in the lapInfo structure are from the
// goodPoints array  (dead zone markers are excluded)

- (int) findLapIndex:(Lap*)lap
{
    NSUInteger numLaps = [laps count];
	int ret = -1;
	int idx;
	for (idx=0; idx<numLaps; idx++)
	{
		if (lap == [laps objectAtIndex:idx])
		{
			ret = idx;
			break;
		}
	}
	return ret;
}


- (NSArray*) lapPoints:(Lap*)lap
{
	NSMutableArray* arr = nil;
	LapInfo* li = [self getLapInfo:lap];
	if (li != nil)
	{
		int sp = [li startingPointIndex];
		int np = [li numPoints];
		int i;
		NSArray* pts = [self goodPoints];
		arr = [NSMutableArray arrayWithCapacity:np];
		for (i=sp; i<sp+np; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			if (![pt isDeadZoneMarker])
			{
				[arr addObject:pt];
			}
		}
	}
	else
	{
		arr = [NSMutableArray arrayWithCapacity:1];
	}
	return arr;
}


- (int) lapStartingIndex:(Lap*)lap
{
	int sp = 0;
	LapInfo* li = [self getLapInfo:lap];
	if (li != nil)
	{
		sp = [li startingPointIndex];
	}
	return sp;
}


- (void) updateLapInfoArray
{
	[lapInfoArray removeAllObjects];
    NSUInteger numLaps = [laps count];
	int last = 0;
	int i;
	NSArray* pts = [self goodPoints];
    int count = (int)[pts count];
	NSTimeInterval activeTimeDelta = 0.0;
	for (i=0; i<numLaps; i++)
	{
		Lap* lap = [laps objectAtIndex:i];
		float std = [lap startingWallClockTimeDelta];
		int sp = [self findFirstGoodPointAtOrAfterDelta:std startAt:last];
		int np = 0;
		if (sp < 0)
		{
			sp = count-1;
			np = 1;
		}
		else
		{
			if (i < (numLaps-1))
			{
				Lap* nextLap = [laps objectAtIndex:i+1];
				float nstd = [nextLap startingWallClockTimeDelta];
				int endi = [self findFirstGoodPointAtOrAfterDelta:nstd startAt:sp];
				if (endi == -1) endi = count - 1;		// if fell off the end, set to last point
				np = endi - sp;
			}
			else
			{
				np = count - sp;
			}
		}
		if (np < 0) np = 0;
		if (sp < 0) sp = 0;
		last = sp + np - 1;
		if (last < 0) last = 0;
		LapInfo* li = [[LapInfo alloc] initWithData:lap startIdx:sp numPoints:np];
		[lapInfoArray addObject:li];
		//printf("lap %d active time delta %0.1f\n", activeTimeDelta);
		[li setActiveTimeDelta:activeTimeDelta];
		activeTimeDelta += [self movingDurationOfLap:lap];
	}
}


- (void) invalidateAllLapStats
{
    NSUInteger num = [laps count];
	int i;
	for (i=0; i<num; i++)
	{
		Lap* lap = [laps objectAtIndex:i];
		[lap setStatsCalculated:NO];
	}
}


- (LapInfo*) getLapInfo:(Lap*)lap
{
	LapInfo* li = nil;
	int idx = [self findLapIndex:lap];
	if (idx >= 0)
	{
		li = [lapInfoArray objectAtIndex:idx];
	}
	return li;
}


- (NSTimeInterval) lapActiveTimeDelta:(Lap*)lap
{
	NSTimeInterval answer = 0.0;
	LapInfo* li = [self getLapInfo:lap];
	if (li != nil)
	{
#if 0
		int sp = [li startingPointIndex];
		if (lap && laps && (lap != [laps objectAtIndex:0]))	// starting lap is assumed to start at time 0
			answer = [[goodPoints objectAtIndex:sp] activeTimeDelta];
#endif
		answer = [li activeTimeDelta];
	}
	return answer;
}


- (void) calculateLapStats:(Lap*)lap
{
	BOOL done = [lap statsCalculated];
	if (!done)
	{
		[lap setStatsCalculated:YES];
		LapInfo* li = [self getLapInfo:lap];
		if (li != nil)
		{
			int sp = [li startingPointIndex];
			//printf("lap start:%d num:%d total:%d\n", sp, [li numPoints], [[self goodPoints] count]);
			if ([li numPoints] > 1)
			{
				[self calculateStats:[lap getStatArray] startIdx:sp endIdx:(sp + [li numPoints] - 1)];
			}
			else
			{
				// no points for lap, so just use lap data if it exists
				struct tStatData* statData = [lap getStatArray];
				float totalDistance = [lap distance];
				statData[kST_Distance].vals[kVal] = totalDistance;
				statData[kST_Heartrate].vals[kMax] = [lap maxHeartRate];
				statData[kST_Heartrate].vals[kAvg] = [lap averageHeartRate];
				statData[kST_Cadence].vals[kAvg] = [lap averageCadence];
				//statData[kST_Power].vals[kAvg] = [lap averagePower];
				statData[kST_Calories].vals[kVal] = [lap calories];
				statData[kST_Durations].vals[kElapsed] = [lap totalTime];
				statData[kST_Durations].vals[kMoving] = [lap deviceTotalTime];
				statData[kST_Speed].vals[kMax] = statData[kST_MovingSpeed].vals[kMax] = [lap maxSpeed];
				float dur = [lap deviceTotalTime];
				if (dur > 0.0)
				{
					statData[kST_Speed].vals[kAvg] = statData[kST_MovingSpeed].vals[kAvg] = totalDistance/(60.0*60.0*dur);
				}
			}
		}
	}
}

- (float)statForLap:(Lap*)lap statType:(tStatType)stat index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atTime 
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:stat];
	if (atTime != nil) *atTime = data->atActiveTimeDelta[idx];
	return data->vals[idx];
}	


- (float)maxCadenceForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	float answer = 0.0;
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Cadence];
	if (t != nil) *t = data->atActiveTimeDelta[kMax];
	if ([self usingDeviceLapData])
	{
		answer = (float)[lap maxCadence];
	}
	else
	{
		answer = data->vals[kMax];
	}
	return answer;
}


- (float)avgCadenceForLap:(Lap*)lap
{
	float answer = 0.0;
	if ([self usingDeviceLapData] && ([lap averageCadence] > 0))
	{
		answer = (float)[lap averageCadence];
	}
	else
	{
		[self calculateLapStats:lap];
		struct tStatData* data = [lap getStat:kST_Cadence];
		answer = data->vals[kAvg];
	}
	return answer;
}


- (float)maxPowerForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self checkPowerData];
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Power];
	if (t != nil) *t = data->atActiveTimeDelta[kMax];
	return data->vals[kMax];
}


- (float)avgPowerForLap:(Lap*)lap
{
	[self checkPowerData];
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Power];
	return data->vals[kAvg];
}


- (float)workForLap:(Lap*)lap
{
	return PowerDurationToWork([self avgPowerForLap:lap], 
							   [self movingDurationOfLap:lap]);
}


- (float)maxHeartrateForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	float answer = 0.0;
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Heartrate];
	if ([self usingDeviceLapData])
	{
		answer = (float)[lap maxHeartRate];
	}
	if (![self usingDeviceLapData] || (answer <= 0.0))
	{
		answer = data->vals[kMax];
	}
	if (t != nil) *t = data->atActiveTimeDelta[kMax];
	return answer;
}


- (float)minHeartrateForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Heartrate];
	if (t != nil) *t = data->atActiveTimeDelta[kMin];
	return data->vals[kMin];
}


- (float)avgHeartrateForLap:(Lap*)lap
{
	float answer = 0.0;
	if ([self usingDeviceLapData])
	{
		answer = (float)[lap averageHeartRate];
	}
	else
	{
		[self calculateLapStats:lap];
		struct tStatData* data = [lap getStat:kST_Heartrate];
		answer = data->vals[kAvg];
	}
	return answer;
}


- (float)maxAltitudeForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Altitude];
	if (t != nil) *t = data->atActiveTimeDelta[kMax];
	return data->vals[kMax];
}


- (float)minAltitudeForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Altitude];
	if (t != nil) *t = data->atActiveTimeDelta[kMin];
	return data->vals[kMin];
}


- (float)avgAltitudeForLap:(Lap*)lap
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Altitude];
	return data->vals[kAvg];
}


- (float)maxSpeedForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	float answer = 0.0;
	if ([self usingDeviceLapData])
	{
		answer = [lap maxSpeed];
	}
	else
	{
		[self calculateLapStats:lap];
		struct tStatData* data = [lap getStat:kST_Speed];
		if (t != nil) *t = data->atActiveTimeDelta[kMax];
		answer = data->vals[kMax];
	}
	return answer;
}


- (float)avgGradientForLap:(Lap*)lap
{
   [self calculateLapStats:lap];
   struct tStatData* data = [lap getStat:kST_Gradient];
   return data->vals[kAvg];
}


- (float)maxGradientForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
   [self calculateLapStats:lap];
   struct tStatData* data = [lap getStat:kST_Gradient];
   if (t != nil) *t = data->atActiveTimeDelta[kMax];
   return data->vals[kMax];
}


- (float)minGradientForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
   [self calculateLapStats:lap];
   struct tStatData* data = [lap getStat:kST_Gradient];
   if (t != nil) *t = data->atActiveTimeDelta[kMin];
   return data->vals[kMin];
}


- (float)avgTemperatureForLap:(Lap*)lap
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Temperature];
	return data->vals[kAvg];
}


- (float)maxTemperatureForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Temperature];
	if (t != nil) *t = data->atActiveTimeDelta[kMax];
	return data->vals[kMax];
}


- (float)minTemperatureForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t
{
	[self calculateLapStats:lap];
	struct tStatData* data = [lap getStat:kST_Temperature];
	if (t != nil) *t = data->atActiveTimeDelta[kMin];
	return data->vals[kMin];
}


-(NSDate*) lapStartTime:(Lap*)lap 
{
	return [[self creationTime] dateByAddingTimeInterval:[lap startingWallClockTimeDelta]];
}


-(NSDate*) lapEndTime:(Lap*)lap 
{
	return [[self lapStartTime:lap] dateByAddingTimeInterval:[self durationOfLap:lap]];
}


-(int)lapIndexOfPoint:(TrackPoint*)pt
{
	float ptTime = [pt wallClockDelta];
    int numLaps = (int)[laps count];
	for (int i=numLaps-1; i>=0; i--)
	{
		Lap* lap = [laps objectAtIndex:i];
		if (ptTime >= [lap startingWallClockTimeDelta])
		{
			return i;
		}
	}
	return 0;	
}
	

- (float)realDurationOfLap:(Lap*)lap
{
	NSTimeInterval totalInterval = 0.0;
	NSDate* startTime = [self lapStartTime:lap];
	if (lap != nil)
	{
		NSDate* leTime = nil;
        NSUInteger numLaps = [laps count];
		int idx = [self findLapIndex:lap];
		if ((idx >= 0) && (idx < numLaps))
		{
			if (idx < (numLaps-1))
			{
				Lap* nextLap = [laps objectAtIndex:idx+1];
				leTime = [self lapStartTime:nextLap];
			}
			else
			{
				NSArray* gpts = [self goodPoints];
                NSUInteger numPts = [gpts count];
				if (numPts > 0)
				{
					//leTime = [[gpts objectAtIndex:(numPts-1)] date];
					leTime = [[self creationTime] dateByAddingTimeInterval:[[gpts objectAtIndex:(numPts-1)] wallClockDelta]];
				}
				else
				{
					// no points, just use lap values
					leTime = [[lap origStartTime] dateByAddingTimeInterval:[lap totalTime]];
				}
			}
			if (leTime)
				totalInterval = [leTime timeIntervalSinceDate:startTime];
		}
	}
	if (totalInterval < 0.0) totalInterval = 0.0;
	return totalInterval;
}


					  
- (float)durationOfLap:(Lap*)lap
{
	NSTimeInterval totalInterval = [self realDurationOfLap:lap];
	// wall clock duration MUST be >= moving duration!
	float movingDur = [self movingDurationOfLap:lap];
	if (totalInterval < movingDur) totalInterval = movingDur;
	if (totalInterval < 0.0) totalInterval = 0.0;
	return totalInterval;
}


- (void)addLapInFront:(Lap*)lap
{
	if ([laps containsObject:lap] == NO)
	{
	   if ([laps count] > 0)
	   {
		   NSTimeInterval std = [lap startingWallClockTimeDelta];
		   Lap* firstLap = [laps objectAtIndex:0];
		   if ([firstLap startingWallClockTimeDelta] == std)
		   {
			   [firstLap setStartingWallClockTimeDelta:std +[lap totalTime]];
		   }
	   }
	   [laps addObject:lap];
		[laps sortUsingSelector:@selector(compare:)];
		//NSLog(@"added lap %d to %@, total: %d\n", [lap index], name, [laps count]);
	}
	else
	{
		//NSLog(@"skipped lap %d %@ (already there), total: %d\n", [lap index], name, [laps count]);
	}
	[self updateLapInfoArray];
}


- (Lap*)addLap:(NSTimeInterval)atActiveTimeDelta
{
	Lap* lap = nil;
	int idx = [self findIndexOfFirstPointAtOrAfterActiveTimeDelta:atActiveTimeDelta];
	if (idx > 0)
	{ 
		TrackPoint* firstPoint = [points objectAtIndex:idx];
		NSTimeInterval lapStartWallClockDelta = [firstPoint wallClockDelta];
        NSTimeInterval lapStartActiveTimeDelta = [firstPoint activeTimeDelta];
		// laps can only be inserted 10 seconds after track start or 10 seconds before the end
		if (IS_BETWEEN(10.0, lapStartWallClockDelta, [self duration] - 10.0))
		{
			NSDate* startDate = [[self creationTime] dateByAddingTimeInterval:lapStartWallClockDelta];
			
			int numLaps = (int)[laps count];
			int insertBeforeIndex = numLaps;
			for (int i = 0; i<numLaps; i++)
			{
				Lap* lap = [laps objectAtIndex:i];
				if ([lap startingWallClockTimeDelta] > lapStartWallClockDelta)
				{
					insertBeforeIndex = i;
					break;
				}
			}
			Lap* nextLap = nil;
			Lap* prevLap = nil;
			float nextLapActiveTimeDelta = nextLap ? [self lapActiveTimeDelta:nextLap] : 0.0;
            float prevLapActiveTimeDelta = prevLap ? [self lapActiveTimeDelta:prevLap] : 0.0;
            if (insertBeforeIndex < numLaps)
			{
				nextLap = [laps objectAtIndex:insertBeforeIndex];
                
			}
			if (insertBeforeIndex > 0)
			{
				prevLap = [laps objectAtIndex:insertBeforeIndex-1];
			}
			lap = [[Lap alloc] initWithGPSData:insertBeforeIndex
						startTimeSecsSince1970:(time_t)[startDate timeIntervalSince1970]
									 totalTime:(nextLap ? [nextLap startingWallClockTimeDelta] - lapStartWallClockDelta : 0.0)*100
								 totalDistance:0.0		// currently calculated
									  maxSpeed:0.0		// currently calculated
									  beginLat:[firstPoint latitude]
									  beginLon:[firstPoint longitude]
										endLat:nextLap ? [nextLap beginLatitude] : 0.0
										endLon:nextLap ? [nextLap beginLongitude] : 0.0
									  calories:0		// currently calculated
										 avgHR:0.0		// currently calculated
										 maxHR:0.0		// currently calculated
										 avgCD:0.0		// currently calculated
									 intensity:prevLap ? [prevLap intensity] : 0
									   trigger:prevLap ? [prevLap triggerMethod] : 0];
			
			[lap setStartingWallClockTimeDelta:lapStartWallClockDelta];
			if (prevLap)
			{
				[prevLap setEndLatitude:[lap beginLatitude]];
				[prevLap setEndLongitude:[lap beginLongitude]];
				[prevLap setTotalTime:lapStartWallClockDelta - [prevLap startingWallClockTimeDelta]];
                [prevLap setDeviceTotalTime:lapStartActiveTimeDelta - prevLapActiveTimeDelta];
			}
            if (nextLap)
            {
                [lap setTotalTime:[nextLap startingWallClockTimeDelta] - lapStartWallClockDelta];
                [lap setDeviceTotalTime:nextLapActiveTimeDelta - lapStartActiveTimeDelta];
            }
            else
            {
                [lap setTotalTime:[self duration] - lapStartWallClockDelta];
                [lap setDeviceTotalTime:[self movingDuration] - lapStartActiveTimeDelta];
            }
			for (int i = insertBeforeIndex; i<numLaps; i++)
			{
				[(Lap*)[laps objectAtIndex:i] setIndex:i+1];
			}
			[laps addObject:lap];
			[laps sortUsingSelector:@selector(compare:)];
			[self setUseDeviceLapData:NO];	// this will cause issues with the 310xt
			[self updateLapInfoArray];
			[self invalidateAllLapStats];
		}
	}
	return lap;
}


- (BOOL)deleteLap:(Lap*)lap
{
	BOOL ret = NO;
	if (([laps containsObject:lap] == YES) && ([laps count] > 1))
	{
		int numLaps = (int)[laps count];
		int lapIndex = (int)[laps indexOfObject:lap];
		Lap* prevLap = nil;
		Lap* nextLap = nil;
		if (lapIndex > 0)
		{
			prevLap = [laps objectAtIndex:lapIndex-1];
		}
		if (lapIndex < (numLaps-1))
		{
			nextLap = [laps objectAtIndex:lapIndex+1];
		}
		[laps removeObject:lap];
		if (prevLap)
		{
			// previous lap is now extended to contain lap being deleted
			[prevLap setEndLatitude:[lap endLatitude]];
			[prevLap setEndLongitude:[lap endLongitude]];
			[prevLap setTotalTime:[prevLap totalTime] + [lap totalTime]];
			[prevLap setDeviceTotalTime:[prevLap deviceTotalTime] + [lap deviceTotalTime]];
			[prevLap setCalories:[prevLap calories] + [lap calories]];
		}
		else if (nextLap)
		{
			// no prev lap, but there is a next lap (deleting first lap)
			[nextLap setBeginLatitude:[lap beginLatitude]];
			[nextLap setBeginLongitude:[lap beginLongitude]];
			[nextLap setTotalTime:[nextLap totalTime] + [lap totalTime]];
			[nextLap setDeviceTotalTime:[nextLap deviceTotalTime] + [lap deviceTotalTime]];
			[nextLap setCalories:[nextLap calories] + [lap calories]];
			[nextLap setOrigStartTime:[lap origStartTime]];
			// NOTE: this case MUST RESET STARTING WALL TIME DELTA!  Other cases simply
			// extend the LENGTH of the previous lap instead.
			[nextLap setStartingWallClockTimeDelta:[lap startingWallClockTimeDelta]];
		}
		[self updateLapInfoArray];
		[self invalidateAllLapStats];
		ret = YES;
	}
	return ret;
}


- (float)avgLapSpeed:(Lap*)lap
{
	float answer = 0.0;
    if (lap != nil)
	{
		float totalDist = [self distanceOfLap:lap];
		NSTimeInterval totalInterval = [self durationOfLap:lap];
		if (totalInterval > 0.0)
		   answer = totalDist/(totalInterval/(60.0*60.0));
   }
   return answer;
}


- (float)lapClimb:(Lap*)lap
{
   [self calculateLapStats:lap];
   struct tStatData* data = [lap getStat:kST_ClimbDescent];
   return data->vals[kMax];
}


- (float)lapDescent:(Lap*)lap
{
   [self calculateLapStats:lap];
   struct tStatData* data = [lap getStat:kST_ClimbDescent];
   return data->vals[kMin];
}


- (float) caloriesForLap:(Lap*)lap
{
	float answer = 0.0;
	if ([self usingDeviceLapData])
	{
		answer = [lap calories];
	}
	else
	{
		[self calculateLapStats:lap];
		struct tStatData* data = [lap getStat:kST_Calories];
		answer = data->vals[kVal];
	}
	return answer;
}


- (BOOL) isTimeOfDayInLap:(Lap*)l tod:(NSDate*)tod
{
    NSUInteger num = [laps count];
   int i;
   NSDate* endTime = [NSDate distantFuture];
  // NSDate* startTime = [l startTime];
   NSDate* startTime = [self lapStartTime:l];
   for (i=0; i<num; i++)
   {
      if ([laps objectAtIndex:i] == l)
      {
         if (i < (num-1))
         {
            //endTime = [[laps objectAtIndex:i+1] startTime];
			 endTime = [self lapStartTime:[laps objectAtIndex:i+1]];
         }
         break;
      }
   }
   BOOL isLessThan = [tod compare:startTime] == NSOrderedAscending;
   BOOL isGreaterThan = [tod compare:endTime] == NSOrderedDescending;
   return ((isLessThan == NO) && (isGreaterThan == NO));
   
}


- (float)interpolateDistance:(int)pt1idx secsFromStart:(float)secsFromTrackStart
{
	float d = 0.0;
	NSArray* pts = [self goodPoints];
	int count = (int)[pts count];
	if (IS_BETWEEN(0, pt1idx, (count-1)))
	{
		TrackPoint* pt1 = [pts objectAtIndex:pt1idx];
		// back up in point array until we hit the first point whose time is
		// less than or equal to the target time
		while (([pt1 wallClockDelta] > secsFromTrackStart) && (pt1idx > 0))
		{
			--pt1idx;
			pt1 = [pts objectAtIndex:pt1idx];
		}
		float d1 = [pt1 distance];
		d = d1;
		// now find the next point with a valid distance
		TrackPoint* pt2 = [self nextValidGoodDistancePoint:pt1idx];
		if (pt2 != nil)
		{
			//NSTimeInterval dt = [[pt2 date] timeIntervalSinceDate:[pt1 date]];
			NSTimeInterval dt = [pt2 wallClockDelta] - [pt1 wallClockDelta]; 
			if (dt > 0.0)
			{
				float d2 = [pt2 distance];
				//NSTimeInterval pt1Secs = [[pt1 date] timeIntervalSinceDate:[self creationTime]];
				NSTimeInterval pt1Secs = [pt1 wallClockDelta];
				// pt1 time should be less than target time
				float dtp1 = secsFromTrackStart - pt1Secs;
				d = dtp1 > 0.0 ? (d1 + ((d2-d1)*dtp1/dt)) : d1; 
			}
		}
	}
	return d;
}


- (float)distanceOfLap:(Lap*)lap
{
	float answer = 0.0;
	if ([self usingDeviceLapData])
	{
		answer = [lap distance];			
	}
	else
	{
		LapInfo* li = [self getLapInfo:lap];
		if (li != nil)
		{
			int sp = [li startingPointIndex];
			int np = [li numPoints];
			NSArray* pts = [self goodPoints];
			int totalPts = (int)[pts count];
			if (np > 1)
			{
				int firstOfNextLap = sp+np;
				if (firstOfNextLap < 0) firstOfNextLap = 0;
				if (firstOfNextLap >= totalPts) firstOfNextLap = totalPts-1;
				int atIdx;
				float sd = [self lastValidDistanceUsingGoodPoints:sp atIdx:&atIdx];
				//NSTimeInterval lapStartSecs = [[lap startTime] timeIntervalSinceDate:[self creationTime]];
				NSTimeInterval lapStartSecs = [lap startingWallClockTimeDelta];
				if (atIdx != -1)
				{
					sd = [self interpolateDistance:atIdx secsFromStart:lapStartSecs];      
				}            
				float ed = [self lastValidDistanceUsingGoodPoints:firstOfNextLap atIdx:&atIdx];
				if (atIdx != -1)
				{
					ed = [self interpolateDistance:atIdx secsFromStart:(lapStartSecs + [self durationOfLap:lap])];      
				}            
				answer = ed - sd;
			}
			else
			{
				answer = [lap distance];			// no points, use lap data
			}
		}
	}
	return answer;
}


- (NSString *)movingDurationForLapAsString:(Lap*)lap
{
	NSTimeInterval dur = [self movingDurationOfLap:lap];
	int hours = (int)dur/3600;
	int mins = (int)(dur/60.0) % 60;
	int secs = (int)dur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}



- (NSString *)durationOfLapAsString:(Lap*)lap
{
	NSTimeInterval dur = [self durationOfLap:lap];
	int hours = (int)dur/3600;
	int mins = (int)(dur/60.0) % 60;
	int secs = (int)dur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}



//--------------------------------------------------------------------------------------
//---- FIXUP TRACK METHODS -------------------------------------------------------------
//--------------------------------------------------------------------------------------

#define DEBUG_DEADZONES          0
#define PRINT_DEADZONE_SUMMARY   0
#define NUM_TO_CHECK             2

enum
{
   kLeaveDeadZone = 0,
   kEnterDeadZone,
   kStayInDeadZone,
   kStayOutOfDeadZone
};


BOOL allTheSame(BOOL* arr, int num, BOOL v)
{
   int i;
   for (i=0; i<num; i++) 
      if (arr[i] != v) return NO;
   return YES;
}

BOOL atLeastOneTheSame(BOOL* arr, int num, BOOL v)
{
   int i;
   for (i=0; i<num; i++) 
      if (arr[i] == v) return YES;
   return NO;
}


// state during fixup
static float			sSpeedThresh            = 0.0;
static float			sDistanceThresh         = 0.0;
static float			sLastGoodAlt            = 0.0;
//static float			sDeltaDist              = 0.0;
static float			sDeltaTime              = 0.0;
static float			sTimeToIgnore           = 0.0;
static float			sDistToIgnore           = 0.0;
static int				sNumMarkedDeadZones     = 0;
static int				sLastValidLatLonIdx     = -1;
static int				sNumDeadZones           = 0;
static TrackPoint*		sLastGPSPoint           = nil;
static int				sLastGoodAltIdx         = 0;


- (BOOL) checkDeadZones:(NSArray*)pts start:(int)s state:(BOOL)idz deltaTime:(float)deltaTime
{
    if ([self hasExplicitDeadZones]) return NO;
    
	float ptDeltaTime = deltaTime;
	float ptSpeed = 0.0;
	int state;
	int end = s + NUM_TO_CHECK - 1;
	int max = (int)[pts count] - 1;
	if (end > max) end = max;
	BOOL dz[NUM_TO_CHECK];
	int num = end - s + 1;
	for (int i=s; i<=end; i++)
	{
		float speed = [(TrackPoint*)[pts objectAtIndex:i] speed];
		dz[i-s] = (speed < sSpeedThresh);
		if (i==s)ptSpeed = speed;
	}
	if (allTheSame(dz, num, YES) || ((ptSpeed < sSpeedThresh) && (ptDeltaTime >= 10.0)))
	{
		state = kEnterDeadZone;
		sTimeToIgnore += sDeltaTime;
		sDeltaTime = 0.0;
		++sNumDeadZones;
	}
	else
	{
		state = kStayOutOfDeadZone;
	}
	return (state == kEnterDeadZone) || (state == kStayInDeadZone);
}


-(void) smoothAltitudes:(NSArray*)pts
{
	int count = (int)[pts count];
	float smoothingFactor = 0.0;
	if (IS_BETWEEN(1.0, altitudeSmoothingFactor, 100.0))
	{
		smoothingFactor = altitudeSmoothingFactor;
	}
	else
	{
		smoothingFactor = [Utils floatFromDefaults:RCBDefaultAltitudeSmoothingPercentage];
	}
	if (!IS_BETWEEN(0.0, smoothingFactor, 100.0)) smoothingFactor = 0.0;
	smoothingFactor = (1.0 - smoothingFactor/100.0);
	if (smoothingFactor < .02) smoothingFactor = .02;
	float s = 0.0;
	BOOL first = YES;
	for (int i=0; i<count; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validAltitude])
		{	
			float alt = [pt origAltitude];
			if (first)
			{
				first = NO;
				s = alt;
			}
			else
			{
				s = s + (smoothingFactor * (alt - s));
			}
			[pt setAltitude:s];
		}
	}
}


-(void)initLastGoodAltitude:(NSArray*)pts
{
	// set statics to first good altitude found, which may
	// not be the first point.  
	sLastGoodAltIdx = 0;
	sLastGoodAlt = 0.0;
	int nextGoodAltIdx = [self findNextGoodAltIdx:0];
	if (nextGoodAltIdx >= 0)
	{
		TrackPoint* npt = [pts objectAtIndex:nextGoodAltIdx];
		sLastGoodAlt = [npt altitude];
		sLastGoodAltIdx = nextGoodAltIdx;
	}
}


-(void) checkAltitudes:(NSArray*)pts start:(int)sidx
{
	TrackPoint* pt = [pts objectAtIndex:sidx];
	if (![pt isDeadZoneMarker])
	{
		float alt = [pt altitude];
		if ((alt == 0.0) || (alt > 60000.0))
		{
			alt = sLastGoodAlt;
			int nextGoodAltIdx = [self findNextGoodAltIdx:sidx+1];
			if (nextGoodAltIdx > sLastGoodAltIdx)
			{
				// poor-man's ramp to the next good altitude. If we haven't had
				// a good altitude yet, then sLastGoodAltIdx will actually be 
				// in a future point, so just use that value here and don't do any
				// ramping to it (see initLastGoodAltitude)
				if (sidx > sLastGoodAltIdx)
				{
					TrackPoint* npt = [pts objectAtIndex:nextGoodAltIdx];
					float incr = ([npt altitude] - sLastGoodAlt)/(nextGoodAltIdx - sLastGoodAltIdx);
					incr *= (sidx - sLastGoodAltIdx);
					alt += incr;
				}
			}
			[pt setAltitude:alt];
		}
		sLastGoodAlt = alt;
		sLastGoodAltIdx = sidx;
	}
}   

enum
{
	kNotInMarkedDeadZone, 
	kInMarkedDeadZone,
	kLastPointExitedDeadZone
};


// updates sDeltaTime, sTimeToIgnore,  sNumMarkedDeadZones
// sDeltaTime should be set to 0.0 if the time interval for the point is
// being added to the "ignore" time
-(int) checkForDeadZoneMarker:(TrackPoint*)pt curDZState:(int)cdzState
{
	int ret = kNotInMarkedDeadZone;
#if DEBUG_DEADZONES
	NSDate* dt = [[NSDate alloc] initWithTimeInterval:[pt wallClockDelta]
											sinceDate:creationTime];
#endif   
	
	switch (cdzState)
	{
		case kNotInMarkedDeadZone:
		{
			if ([pt beginningOfDeadZone])
			{
#if DEBUG_DEADZONES
				NSLog(@"%@ ===> ENTERING MARKED ZONE, ignoreTime:%9.3f\n", dt, sTimeToIgnore);
#endif      
				++sNumMarkedDeadZones;
				ret = kInMarkedDeadZone;
			}
		}
		break;
			
		case kInMarkedDeadZone:
		{
			if ([pt endOfDeadZone])
			{
				sTimeToIgnore += sDeltaTime;
#if DEBUG_DEADZONES
				NSLog(@"%@ ===> EXITING MARKED ZONE,  dt:%9.3f  ignoreTime:%9.3f\n", dt, sDeltaTime, sTimeToIgnore);
#endif      
				sDeltaTime = 0.0;
				ret = kLastPointExitedDeadZone;
			}
			else
			{
				sTimeToIgnore += sDeltaTime;
#if DEBUG_DEADZONES
				NSLog(@"%@ ===> ACCUM1 MARKED ZONE TIME, dt:%9.3f, ignoreTime:%9.3f\n", dt, sDeltaTime, sTimeToIgnore);
#endif      
				sDeltaTime = 0.0;
				ret = kInMarkedDeadZone;
			}
		}
		break;
			
	}
#if DEBUG_DEADZONES
	[dt autorelease];
#endif
	return ret;
}


- (void) checkFirstAltitude:(NSArray*)pts idx:(int)cidx
{
   TrackPoint* pt = [pts objectAtIndex:cidx];
   if ([pt validLatLon] && (sLastValidLatLonIdx == -1))
   {
      if (cidx > 0)
      {
         float lat = [pt latitude];
         float lon = [pt longitude];
         TrackPoint *opt = [pts objectAtIndex:0];
         [opt setLatitude:lat]; 
         [opt setLongitude:lon];
      }
      sLastValidLatLonIdx = cidx;
   }
}


- (float) findDeltaDistance:(TrackPoint*)pt lastDistance:(float)ld distToIgnore:(float)distToIgnore
{
	float deltaDist = 0.0;
	float tentativeDistSoFar = [pt distance] - distToIgnore;
	// if distance is unreasonable, don't use it.
	if ((tentativeDistSoFar < 0) || (tentativeDistSoFar > 8000.0) || (tentativeDistSoFar < ld))
	{
		tentativeDistSoFar = ld; 
	}
	deltaDist = tentativeDistSoFar - ld;
#if 0
	if ((lastPoint != nil) && ![lastPoint isDeadZoneMarker])
	{
		// if deltaDistance or deltaTime is too high, ignore this interval
		if ((deltaDist > 2.0) || (deltaDist > 3000.0) || (deltaDist < -1.0))
		{
			*distToIgnorePtr += deltaDist;
			deltaDist = 0.0;
			*timeToIgnorePtr += sDeltaTime;
			sDeltaTime = 0.0;
			idz = YES;
		}
	}
#endif
	return deltaDist;
}

static const int kMaxConsecutiveSpikePoints = 2;
static int sSpikeCount = 0;

- (BOOL) isSpike:(float)spd lastSpeed:(float)lgs
{
	BOOL spike = NO;
	if (sSpikeCount < kMaxConsecutiveSpikePoints)
	{
		// look for obvious high speed or increase of more than 30% from previous speed
		spike = (spd > 160) || ((spd > 25.0) && (spd > (lgs * 1.3)));
	}
	// if there are more than kMaxConsecutiveSpikePoints, then we
	// assume this isn't a spike, and let the averaging code kick in.
	if (spike) 
		++sSpikeCount;
	else
		sSpikeCount = 0;
		
	return spike;
}


-(float) filterFactor:(float)spd
{
	if (spd > 30.0) return 1.20;
	else if (spd > 20.0) return 1.30;
	else if (spd > 10.0) return 1.50;
	else return 2.2;
}


- (BOOL) needsFilter:(float)spd lastSpeed:(float)lgs
{
	float ff = [self filterFactor:spd];
	return ((lgs <= 0.0) && (spd > 10.0)) ||
		   ((lgs >  0.0) && (spd > (lgs * ff)));
}


#define BAD_SPEED       -42.0

- (float) nextGoodSpeed:(int)sidx
{
	float ptSpd  = BAD_SPEED;
	int ct = (int)[points count];
	int i = sidx;
	while (i < ct)
	{
		TrackPoint* pt = [points objectAtIndex:i];
		if (![pt isDeadZoneMarker])
		{
			ptSpd = [pt speed];
			break;
		}
		++i;
	}
	return ptSpd;
}

#if 0
- (float) filterSpeed:(float)spd lastSpeed:(float)lgs idx:(int)idx
{
	float filteredSpeed = lgs;
	if (![self isSpike:spd 
			 lastSpeed:lgs])             // remove obvious outliers
	{
		if ([self needsFilter:spd
					lastSpeed:lgs])
		{
			if (lgs > 1.0)
			{
				float nextSpeed = [self nextGoodSpeed:idx+1];
				filteredSpeed = lgs * [self filterFactor:lgs];
				if ((filteredSpeed > lgs) && (nextSpeed != BAD_SPEED) && (nextSpeed < filteredSpeed))
				{
					filteredSpeed = (lgs + nextSpeed)/2.0;
					printf(" ======> raw:%0.1f lgs:%0.1f next:%0.1f filtered:%0.1f\n", spd, lgs, nextSpeed, filteredSpeed);
				}
			}
			else 
			{
				filteredSpeed = spd/3.0;	// pretty lame filter, could do something a lot better here
			}
		}
		else
		{
			filteredSpeed = spd;
		}
	}
	return filteredSpeed;
}
#else
- (float) filterSpeed:(float)spd lastSpeed:(float)lgs idx:(int)idx
{
	float filteredSpeed = lgs;
	if (spd < lgs)
	{
		filteredSpeed = spd;
	}
	else if (![self isSpike:spd 
				  lastSpeed:lgs])             // remove obvious outliers
	{
		filteredSpeed = lgs + (0.5 * (spd - lgs));
	}
	///const char* foo = (filteredSpeed > 32 ? "********" : "");
	///printf("%d lgs: %0.1f spd:%0.1f filtered:%0.1f spikes:%d %s\n", idx, lgs, spd, filteredSpeed, sSpikeCount, foo);
	return filteredSpeed;
}
#endif

- (TrackPoint*) findNextValidGPSGoodPoint:(int)startIdx
{
   NSArray* gpts = [self goodPoints];
   int count = (int)[gpts count];
   int i = startIdx+1;
   TrackPoint* pt = nil;
   while (i < count)
   {
      TrackPoint* tpt = [gpts objectAtIndex:i];
      if ([tpt validLatLon])
      {
         pt = tpt;
         break;
      }
      ++i;
   }
   return pt;
}


- (BOOL) fixDistance
{
	NSArray* gpts = [self goodPoints];
	//NSArray* gpts = [self points];
	TrackPoint*   lastRealGPSPoint           = nil;
	TrackPoint*   nextRealGPSPoint           = nil;
	TrackPoint*   lastPointWithGPS           = nil;
	float speed = 0.0;
	int num = (int)[gpts count];
	float distanceSoFar = 0.0;
	BOOL hasLatLon = NO;
	if (num > 0)
	{
		for (int i=0; i<num; i++)
		{
			TrackPoint* pt = [gpts objectAtIndex:i];
			float deltaDist = 0.0;
			float lat = [pt latitude];
			float lon = [pt longitude];
			if ([pt validLatLon])
			{
				hasLatLon = YES;
				if (lastPointWithGPS != nil)
				{
					deltaDist = [Utils latLonToDistanceInMiles:[lastPointWithGPS latitude]
														  lon1:[lastPointWithGPS longitude]
														  lat2:lat
														  lon2:lon];
					//NSTimeInterval deltaGPSTime = [[pt date]  timeIntervalSinceDate:[lastPointWithGPS date]];
					NSTimeInterval deltaGPSTime = [pt wallClockDelta]  - [lastPointWithGPS wallClockDelta];
					if (deltaGPSTime > 0.0) speed = (deltaDist * 3600.0)/deltaGPSTime;
				}
				lastRealGPSPoint = lastPointWithGPS = pt;
			}
			else
			{
				nextRealGPSPoint = [self findNextValidGPSGoodPoint:i];
				if ((lastRealGPSPoint != nil) && (nextRealGPSPoint != nil))
				{
					//NSTimeInterval deltaGPSTime = [[nextRealGPSPoint date]  timeIntervalSinceDate:[lastRealGPSPoint date]];
					NSTimeInterval deltaGPSTime = [nextRealGPSPoint wallClockDelta] - [lastRealGPSPoint wallClockDelta];
					if (deltaGPSTime > 0.0)
					{
						//float t1 = [[pt date]  timeIntervalSinceDate:[lastRealGPSPoint date]];
						float t1 = [pt wallClockDelta] -[lastRealGPSPoint wallClockDelta];
						float d = [Utils latLonToDistanceInMiles:[lastRealGPSPoint latitude]
															lon1:[lastRealGPSPoint longitude]
															lat2:[nextRealGPSPoint latitude]
															lon2:[nextRealGPSPoint longitude]];
						float factor = (t1/deltaGPSTime);
						deltaDist = (d * factor)-([lastPointWithGPS distance] - [lastRealGPSPoint distance]);     // sheesh
						lat = [lastRealGPSPoint latitude ] + (factor * ([nextRealGPSPoint latitude ] - [lastRealGPSPoint latitude ]));
						lon = [lastRealGPSPoint longitude] + (factor * ([nextRealGPSPoint longitude] - [lastRealGPSPoint longitude]));
						//printf("adjusting point: last:[%0.5f,%0.5f] next:[%0.5f,%0.5f] this:[%0.5f,%0.5f] factor:%0.2f  dist:%0.2f  dd:%0.2f\n",
						//       [lastRealGPSPoint latitude ], [lastRealGPSPoint longitude ], [nextRealGPSPoint latitude ], [nextRealGPSPoint longitude], lat, lon, factor, d, deltaDist);
						[pt setLatitude:lat];
						[pt setLongitude:lon];
						//float dt =  [[pt date]  timeIntervalSinceDate:[lastRealGPSPoint date]];
						float dt =  [pt wallClockDelta] - [lastRealGPSPoint wallClockDelta];
						if (dt > 0.0) speed = (deltaDist * 3600.0)/dt;
						lastPointWithGPS = pt;
					}
				}
			}
			if (hasLatLon)
			{
				distanceSoFar += deltaDist;
				if (![pt speedOverridden]) [pt setSpeed:speed];
				[pt setDistance:distanceSoFar];
			}
		}
	}
	return hasLatLon; 
}


-(void) copyOrigDistance
{
	float distSoFar = 0.0;
    NSUInteger num = [points count];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [points objectAtIndex:i];
		float origDistance = [pt origDistance];
		if (origDistance == BAD_DISTANCE)
		{
			[pt setDistance:BAD_DISTANCE];
		}
		else 
		{
			if (origDistance > distSoFar)
			{
				distSoFar = origDistance;
			}
			[pt setDistance:distSoFar];
		}
	}
}


-(BOOL) hasDistance
{
	return self.hasDistanceData;
}




-(void) setDistanceAndSpeed:(BOOL)doFiltering
{
	NSTimeInterval mostRecentDelta = 0.0;
	float distToIgnore = 0.0;
	TrackPoint* lastPoint= nil;
	float lastDistance = 0.0;
	float lastGoodSpeed = 0.0;
	NSMutableArray* pts = [self points];
	int num = (int)[pts count];
	int lapIndex = 0;
	int numLaps = (int)[laps count];
	NSTimeInterval nextLapWallTimeStart = (laps && (numLaps > 0)) ? [[laps objectAtIndex:0] startingWallClockTimeDelta] : 0.0;
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];	
		// find the first point in the lap; it's used below to filter out bad readings from the 705 at lap markers 
		// (it always reports speed as zero at the point right at the lap marker).
		if (([pt wallClockDelta] >=  nextLapWallTimeStart) && laps && (numLaps > lapIndex))
		{
			[pt setIsFirstPointInLap:YES];
			++lapIndex;
			if (lapIndex < numLaps)
			{
				Lap* lap = [laps objectAtIndex:lapIndex];
				nextLapWallTimeStart = [lap startingWallClockTimeDelta];
			}
		}
		else
		{
			[pt setIsFirstPointInLap:NO];
		}
		float deltaDist = 0.0;
		float deltaTime = [pt wallClockDelta]  - mostRecentDelta;
		if (deltaTime > 0.0)  mostRecentDelta = [pt wallClockDelta];
		float speed = 0.0;
		if (![pt isDeadZoneMarker] && (deltaTime > 0))
		{
			deltaDist = [self findDeltaDistance:pt 
								   lastDistance:lastDistance 
								   distToIgnore:distToIgnore];
			if ((lastPoint != nil) && 
				![lastPoint isDeadZoneMarker] &&
				((deltaDist > 2.0) || (deltaDist < 0.0)))
			{
				distToIgnore += deltaDist;
				deltaDist = 0.0;
			}
			else
			{
				if (![pt speedOverridden])
				{
					if ((deltaDist == 0.0) && [pt isFirstPointInLap])	// part of fix for 705 bug; see comments above
						speed = lastGoodSpeed;
					else
						speed = deltaDist * 60.0 * 60.0 / deltaTime;
					if (doFiltering) speed = [self filterSpeed:speed lastSpeed:lastGoodSpeed idx:i];
					[pt setSpeed:speed];
				}
				else
				{
					speed = [pt speed];
				}
				lastGoodSpeed = speed;
			}
		}
		lastDistance += deltaDist;
		BOOL idz =[pt isDeadZoneMarker];
		if (!idz) 
		{
			[pt setDistance:lastDistance];
		}
		//printf("set pt distance, speed to %0.3f, %0.1f, OVERRIDE:%s, ignoring:%0.1f, delta:%0.1f\n", 
		//	   lastDistance, speed, [pt speedOverridden] ? "YES" : "NO", distToIgnore, deltaDist);
		lastPoint = pt;
	}
}
				
					
					
- (void) fixupTrack
{
	BOOL hasDevicePower = NO;
	BOOL hasCadence = NO;
	BOOL hasLocationData = NO;
	CLEAR_FLAG(flags, kPowerDataCalculatedOrZeroed);
	NSMutableArray* pts = [self points];
	int num = (int)[pts count];
	if (num > 0)
	{
		sSpeedThresh = [self movingSpeedThreshold];
		sDistanceThresh = [self movingDistanceThreshold];
		sNumMarkedDeadZones = 0;
		sNumDeadZones = 0;
		sLastValidLatLonIdx = -1;
		sDeltaTime =  0.0;
		sLastGPSPoint = nil;
		sTimeToIgnore = 0.0;
		sDistToIgnore = 0.0;
		sSpikeCount = 0;
		float lastGoodSpeed = 0.0;
		float lastDistance = 0.0;
		float firstDistance = 0.0;
		BOOL inDeadZone = NO;
		NSMutableArray* gpts = [self goodPoints];
		BOOL hasDistance = NO;	// locally used
		self.hasDistanceData = NO;	// stored for external use
		[self initLastGoodAltitude:pts];
		if ([gpts count] > 0)
		{
			BOOL useDistanceIfAvail = [self useOrigDistance];
			if (useDistanceIfAvail)
			{
				[self copyOrigDistance];
				float d = [self lastValidDistanceUsingGoodPoints:(int)[gpts count]-1 atIdx:0];
				hasDistance = self.hasDistanceData = (d != BAD_DISTANCE) && (d > 0.05);
				
			}
			if (!hasDistance)
			{
				hasDistance = [self fixDistance];		// also sets speed
				[gpts removeAllObjects];
				gpts = [self goodPoints]; 
			}
			float d = [self lastValidDistanceUsingGoodPoints:(int)[gpts count]-1 atIdx:0];
			hasDistance = self.hasDistanceData = (d != BAD_DISTANCE) && (d > 0.05);
		}
		
		// this isn't great, but I can't see a clear way to do this without looping through all points here 
		// and then we loop through them again, below, while calculating active time.  ugh.
		// the problem is the current speed filtering scheme needs to look at speeds for later points, so
		// the raw speeds need to be calculated first in their entirety; *then* the filtering can be done in the loop below.
		
		[self setDistanceAndSpeed:NO];		// +10/22/07
		if ([gpts count] > 0) firstDistance = lastDistance = [[gpts objectAtIndex:0] distance];       // track may start at non-zero distance
		
		//---- now smooth altitudes, if the pref to do so is enabled
		[self smoothAltitudes:pts];

		TrackPoint* pt = [pts objectAtIndex:0];
		TrackPoint* lastPoint = nil;
		NSDate*  startTime = [[self creationTime] dateByAddingTimeInterval:[pt wallClockDelta]];
		NSDate* lastActiveTime = startTime;
		NSTimeInterval mostRecentDelta = 0.0;
		int markedDZState = kNotInMarkedDeadZone;
		for (int i=0; i<num; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			sDeltaTime = [pt wallClockDelta]  - mostRecentDelta;
			if (sDeltaTime > 0.0)  mostRecentDelta = [pt wallClockDelta];
#if DEBUG_DEADZONES
			float odt = sDeltaTime;
#endif
			//---- dead zone marker check - accumulate marked (via auto-pause) stopped time
			markedDZState = [self checkForDeadZoneMarker:pt
											  curDZState:markedDZState];
      
			float deltaDist = 0.0;
			float speed = [pt speed];
			if (/*![pt isDeadZoneMarker] && */((i==0) || (sDeltaTime >= 0)))
			{
				//---- first altitude value check
				[self checkFirstAltitude:pts 
									 idx:i];

				//---- now fix bad altitudes.  sometimes they are missing
				[self checkAltitudes:pts 
							   start:i];

				
				//---- find delta distance, maybe update delta time as well if using GPS delta dist
				if ([pt validLatLon]) 
				{
					sLastGPSPoint = pt;
					hasLocationData = YES;
				}
				deltaDist = [self findDeltaDistance:pt 
									   lastDistance:lastDistance 
									   distToIgnore:sDistToIgnore];


				if ((lastPoint != nil) && 
					![lastPoint isDeadZoneMarker] &&
					((deltaDist > 2.0)  || (deltaDist < 0.0) || (sDeltaTime > 3000) || (sDeltaTime < -1.0)))
				{
					// if deltaDistance or deltaTime is too high, ignore this interval
					deltaDist = 0.0;
					sDeltaTime = 0.0;
					sDistToIgnore += deltaDist;
					sTimeToIgnore += sDeltaTime;
					inDeadZone = YES;
				}
				else
				{
					inDeadZone = NO;
				}
				if ((sDeltaTime > 0.0) && hasDistance)
				{
					// filter speed here; wasn't done the first time filterSpeed was called
					if ((deltaDist == 0.0) && [pt isFirstPointInLap])	// workaround for 705 bug, see comments above
						speed = lastGoodSpeed;
					else
						speed = deltaDist * 60.0 * 60.0 / sDeltaTime;
					speed = [self filterSpeed:speed lastSpeed:lastGoodSpeed idx:i];
					//---- check for dead zone areas (accumulate non-marked stopped time)

					inDeadZone =[self checkDeadZones:pts 
											   start:i
										   state:inDeadZone
										   deltaTime:sDeltaTime];

#if DEBUG_DEADZONES
					NSDate* ddt = [[NSDate alloc] initWithTimeInterval:[pt wallClockDelta]
															 sinceDate:creationTime];
					NSLog(@"%@ %0.1f delta dist:%9.6f delta time:%5.3f speed: %6.3f lastGoodSpeed:%0.1f %d dz:%s", ddt, [pt activeTimeDelta],  deltaDist, odt, speed, lastGoodSpeed, sNumDeadZones+1, inDeadZone ? "YES ************" : "NO");
					[ddt autorelease];
#endif
				}
				if (deltaDist > 0.0) lastDistance += deltaDist;
			}
			else     // pt is deadzone marker, or ...
			{
				if (![pt isDeadZoneMarker]) [pt setAltitude:sLastGoodAlt];
			}
			lastPoint = pt;
			if (sDeltaTime >= 0.0) lastActiveTime = [lastActiveTime dateByAddingTimeInterval:sDeltaTime];
			//
			if (![pt isDeadZoneMarker]) [pt setDistance:(lastDistance-firstDistance)];
			if (!hasDevicePower) hasDevicePower = (![pt powerIsCalculated] && ([pt power] > 0.0)); 
			if (!hasCadence) hasCadence = (IS_BETWEEN(0.0, [pt cadence], 254.0));
			lastGoodSpeed = speed;
			if (![pt speedOverridden])[pt setSpeed:speed];
			[pt setActiveTimeDelta:[lastActiveTime timeIntervalSinceDate:startTime]];
			[self setDistance:(lastDistance-firstDistance)];
		}
	}
#if PRINT_DEADZONE_SUMMARY
	printf("numpts:%d, dt:%5.3f, st:%5.3f, numdz: %d, numMarkeddz:%d, stopped time: %02.2d:%02.2d:%02.2d\n", 
		   num, sDistanceThresh, sSpeedThresh, sNumDeadZones, sNumMarkedDeadZones, (int)sTimeToIgnore/3600, (((int)sTimeToIgnore)/60)%60, ((int)sTimeToIgnore) %60);
#endif
	NSMutableArray* gpts = [self goodPoints];
	num = (int)[gpts count];
	if (num > 0)
	{
		TrackPoint* firstPoint = [gpts objectAtIndex:0];
		[firstPoint setLatitude:[self firstValidLatitude]];
		[firstPoint setLongitude:[self firstValidLongitude]];
		//[self setCreationTime:[firstPoint date]];
	}
	if (peakIntervalData)
	{
		free(peakIntervalData);
		peakIntervalData = 0;
	}
	[self invalidateStats];
	[self calcGradients];
	[self setHasDevicePower:hasDevicePower];
	[self setHasCadence:hasCadence];
	[self fixLapDurations];	// work around for 310XT-related changes
	if (hasLocationData) SET_FLAG(flags, kHasLocationData);
}


-(void)fixLapDurations
{
	BOOL hasDeviceTime = FLAG_IS_SET(flags, kHasDeviceTime);
	for (Lap* lap in laps)
	{
		float wallTotalTime = [lap totalTime];
		float deviceTime = [lap deviceTotalTime];
		if (!hasDeviceTime && deviceTime == 0 && wallTotalTime != 0)
		{
			[lap setDeviceTotalTime:wallTotalTime];
			SET_FLAG(flags, kHasDeviceTime);
		}
	}
}


-(void) doFixupAndCalcGradients
{
	[self fixupTrack];
}


- (int) findFirstPointAtOrAfterDelta:(NSTimeInterval)delta startAt:(int)idx
{
	int num = (int)[points count];
	int i;
	if (idx < 0) idx = 0;
	if (idx < num)
	{
		for (i=idx; i<num; i++)
		{
			TrackPoint* pt = [points objectAtIndex:i];
			//if ([[pt date] compare:time] != NSOrderedAscending)
			if ([pt wallClockDelta] >= delta)
			{
				return i;
			}
		}
	}
	return -1;
}


- (int) findFirstGoodPointAtOrAfterDelta:(NSTimeInterval)delta startAt:(int)idx
{
	NSArray* pts = [self goodPoints];
	int num = (int)[pts count];
	int i;
	if (idx < 0) idx = 0;
	if (idx < num)
	{
		for (i=idx; i<num; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			if ([pt wallClockDelta] >= delta)
			{
				return i;
			}
		}
	}
	return -1;
}

- (int) findFirstGoodPointAtOrAfterActiveDelta:(NSTimeInterval)delta startAt:(int)idx
{
	NSArray* pts = [self goodPoints];
	int num = (int)[pts count];
	int i;
	if (idx < 0) idx = 0;
	if (idx < num)
	{
		for (i=idx; i<num; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			if ([pt activeTimeDelta] >= delta)
			{
				return i;
			}
		}
	}
	return -1;
}


- (int) findIndexOfFirstPointAtOrAfterActiveTimeDelta:(NSTimeInterval)atd
{
	int num = (int)[points count];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [points objectAtIndex:i];
		if ([pt activeTimeDelta] >= atd)
		{
			return i;
		}
	}
	return -1;
}


- (int)findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:(float)dist startAt:(int)startIdx
{
	NSArray* pts = [self goodPoints];
	int num = (int)[pts count];
	for (int i=startIdx; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt distance] >= dist)
		{
			return i;
		}
	}
	return -1;
}

- (struct tStatData*)statsArray
{
	return statsArray;
}


- (BOOL) isEqual:(id) t
{
   return ([[self creationTime] isEqualToDate:[t creationTime]]);
}

- (NSComparisonResult) comparator:(Track*) t
{
	return [[self creationTime] compare:[t creationTime]];
}


- (NSDate *)creationTime
{
	if (FLAG_IS_SET(flags, kOverrideCreationTime))
	{
		return creationTimeOverride;
	}
	else
	{
		return creationTime;
	}
}

- (void)setCreationTime:(NSDate *)d
{
   d = [d copy];
   creationTime = d;
}


- (NSDate *)creationTimeOverride
{
	return creationTimeOverride;
}


- (void)setCreationTimeOverride:(NSDate *)d
{
	d = [d copy];
	creationTimeOverride = d;
	if (d)
	{
		SET_FLAG(flags, kOverrideCreationTime);
	}
	else
	{
		CLEAR_FLAG(flags, kOverrideCreationTime);
	}
}


- (void)clearCreationTimeOverride
{
	CLEAR_FLAG(flags, kOverrideCreationTime);
	creationTimeOverride = nil;
}




- (int)secondsFromGMT 
{
   return secondsFromGMT;
}

- (void)setSecondsFromGMT:(int)value 
{
   if (secondsFromGMT != value) {
      secondsFromGMT = value;
   }
}



- (NSComparisonResult) compareByDate:(Track*)anotherTrack
{
   return [[self creationTime] compare:[anotherTrack creationTime]];
}

- (NSComparisonResult) compareByMovingDuration:(Track*)anotherTrack
{
	float t1d = [self movingDuration];
	float t2d = [anotherTrack movingDuration];
	if (t1d < t2d) 
		return NSOrderedAscending;
	else if (t1d > t2d)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}



- (NSString *)name
{
   return name;
   
}

- (void)setName:(NSString *)n
{
   n = [n copy];
   name = n;
}

- (void) setAttributes:(NSMutableArray*)arr
{
	if (attributes != arr)
	{
		attributes = arr;
	}
    [attributes retain];    
}


- (int)flags
{
    return flags;
}


- (void)setFlags:(int)f
{
    flags = f;
}


- (NSMutableArray*) attributes
{
   return attributes;
}



- (void)setDistance:(float)d
{
	distance = d;
}


- (void) setAttribute:(int)attr usingString:(NSString*)s
{
	if ((attr < [attributes count]) && (s != nil))
	{
		[attributes replaceObjectAtIndex:attr withObject:[s copy]];
	   [[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
	}
}


- (NSString*) attribute:(int)attr
{
   if (attr < [attributes count])
   {
      return [attributes objectAtIndex:attr];
   }
   else
   {
      return @"";
   }
}


- (NSMutableArray*)points
{
   return points;
}



-(void) setPointsAndAdjustTimeDistance:(NSMutableArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset
{
	
	NSTimeInterval timeDelta = [nst timeIntervalSinceDate:[self creationTime]];	// positive delta if starting LATER
	NSMutableArray* pointsToUpdate;
	if (timeDelta >= 0.0)
	{
		pointsToUpdate = points;		// removing points from beginning, update time/distance of EXISTING points
										// new points ('pts') are assumed to be a SUBSET of the existing set
	}
	else
	{
		pointsToUpdate = pts;			// adding points to be beginning, adjust time/distance of all NEW points
										// new points ('pts') are assumed to be a SUPERSET of the existing set
	}
	int count = (int)[pointsToUpdate count];
	if (count > 0)
	{
		BOOL timeChange = timeDelta != 0.0;
		if (timeChange)
		{
			[self setCreationTime:nst];
			for (int i=0; i<count; i++)
			{
				TrackPoint* pt = [pointsToUpdate objectAtIndex:i];
				NSTimeInterval d = [pt wallClockDelta];
				[pt setWallClockDelta:(d-timeDelta)];
				d = [pt activeTimeDelta];
				[pt setActiveTimeDelta:(d-timeDelta)];
				if ([pt validDistance])
				{
					[pt setDistance:[pt distance] - distOffset];
				}
				if ([pt validOrigDistance])
				{
					[pt setOrigDistance:[pt origDistance] - distOffset];
				}
			}
			[self invalidateStats];
			if (laps)
			{
				count = (int)[laps count];
				for (int i=0; i<count; i++)
				{
					Lap* lap = [laps objectAtIndex:i];
					[lap setStartingWallClockTimeDelta:[lap startingWallClockTimeDelta] - timeDelta];
				}
				[self updateLapInfoArray];
			}
			if (markers && distOffset != 0.0)
			{
				count = (int)[markers count];
				for (int i=0; i<count; i++)
				{
					PathMarker* mrkr = [markers objectAtIndex:i];
					float newd = [mrkr distance] - distOffset;
					[mrkr setDistance:newd];
				}
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" object:self];
		}
	}
	[self setPoints:pts];
}


- (void)setPoints:(NSMutableArray*)p
{
    if (p == nil)
    {
        NSLog(@"wtf");
    }
    else
    {
        if (points != p)
        {
            points = [p retain];
        }
    }
	[goodPoints removeAllObjects];      // force re-retrieval
	[self updateLapInfoArray];
	[self invalidateAllLapStats];
}


- (NSMutableArray*)laps
{
   return laps;
}


- (void)setLaps:(NSMutableArray*)l
{
	if (l != laps)
	{
		laps = [l retain];
	}
	[self updateLapInfoArray];
	[self invalidateAllLapStats];
}


- (NSMutableArray*)markers
{
   return markers;
}


- (void)setMarkers:(NSMutableArray*)ms
{
	if (ms != markers)
	{
		markers = [ms retain];
	}
    //NSLog(@"track:setMarkers %x %d", markers, [markers retainCount]);
}


- (float)lastValidDistanceUsingGoodPoints:(int)startIdx atIdx:(int*)atIdxPtr
{
	int idx = startIdx;
	NSArray* pts = [self goodPoints];
	while (idx >= 0)
	{
		TrackPoint* pt = [pts objectAtIndex:idx];
		if ([pt validDistance])
		{
			if (atIdxPtr != 0) *atIdxPtr = idx;
			return [pt distance];
		}
		--idx;
	}
	if (atIdxPtr != 0) *atIdxPtr = 0;
	return 0.0;
}


- (NSTimeInterval)duration
{
    if (points.count == 0)
    {
        return srcElapsedTime;
    }
    
	float val = 0.0;
	if ([overrideData isOverridden:kST_Durations])
	{
		val = [overrideData value:kST_Durations index:kElapsed];
	}
	else
	{

		if ([self usingDeviceLapData])
		{
            int numLaps = (int)[laps count];
			if (numLaps > 0)
			{
                float lapDur = 0.0;
                if (numLaps > 0)
                {
                    for (int i=0; i<numLaps; i++)
                    {
                        Lap* lap = [laps objectAtIndex:i];
                        lapDur += [self durationOfLap:lap];
                    }
                }
			}
			else
			{
				val = [self stat:kST_Durations
						   index:kElapsed
			   atActiveTimeDelta:0];
			}
		}
		else
		{
			val = [self stat:kST_Durations
					   index:kElapsed
		   atActiveTimeDelta:0];
            if (distance == 0 && deviceTotalTime > val)
                val = deviceTotalTime;
		}
		float movingDuration = [self movingDuration];
		if (val < movingDuration)
		{
			// wall clock duration can never be *less* than 
			// moving duration.  This can happen due to the way ascent
			// calculates wall clock duration (difference between last and 
			// first points), and the way moving time may be used from the
			// device itself, as with the 310xt (or other tcx files?)
			val = movingDuration;
		}
	}
	if (val < 0.0) val = 0.0;
	return val;
}	


- (NSTimeInterval)movingDurationBetweenGoodPoints:(int)sidx end:(int)eidx
{
	NSTimeInterval answer = 0.0;
	NSArray* pts = [self goodPoints];
	unsigned numPts = (unsigned)[pts count];
	if (numPts > 1)
	{
		//      NSDate* fd = [[pts objectAtIndex:sidx] activeTime];
		//      NSDate* ld = [[pts objectAtIndex:eidx] activeTime];
		//      answer = [ld timeIntervalSinceDate:fd];
		answer = [[pts objectAtIndex:eidx] activeTimeDelta] -  [[pts objectAtIndex:sidx] activeTimeDelta];
	}
	return answer;
}


- (NSTimeInterval)movingDurationForGraphs
{
	return [self movingDurationBetweenGoodPoints:0
											 end:((int)[[self goodPoints] count] - 1)];
}


- (NSTimeInterval)movingDuration
{
    if (points.count == 0.0)
    {
        return srcMovingTime;
    }
    
	float val = 0.0;
	if ([overrideData isOverridden:kST_Durations])
	{
		val = [overrideData value:kST_Durations index:kMoving];
	}
	else
	{
		int numLaps = (int)[laps count];
        // if distance is 0, then we by definition have no difference between "moving" and "active" time
        // so add moving duration of laps (which will use "device total time")
		if ((distance <= 0.0) || ([self usingDeviceLapData] && (numLaps > 0) && (![overrideData isOverridden:kST_Durations])))
		{
			for (int i=0; i<numLaps; i++)
			{
				Lap* lap = [laps objectAtIndex:i];
				val += [self movingDurationOfLap:lap];
			}
		}
		else
		{
			val = [self stat:kST_Durations
					   index:kMoving
		   atActiveTimeDelta:0];
		}
	}
	return val;
}


- (NSTimeInterval)movingDurationOfLap:(Lap*)lap
{
	NSTimeInterval answer = 0.0;

	if ([self usingDeviceLapData] || (distance <= 0.0))
	{
        if (FLAG_IS_SET(flags, kHasDeviceTime))
        {
            answer = [lap deviceTotalTime];
        }
        else
        {
            answer = [lap totalTime];
        }
	}
	else

	{
		LapInfo* li = [self getLapInfo:lap];
		if (li != nil)
		{
			int sp = [li startingPointIndex];
			int np = [li numPoints];
			NSArray* pts = [self goodPoints];
			int totalPts = (int)[pts count];
			if (np > 1)
			{
				float off = 0.0;
				int end = sp+np;
				if (end >= totalPts) end = totalPts-1;
				TrackPoint* pt = [pts objectAtIndex:sp];
				NSTimeInterval firstActiveTimeDelta = [pt activeTimeDelta];
				// add distance between actual start time and lap start time (start point is the first point at or after
				// the start time.
				if (sp > 0)
				{
					TrackPoint* prevpt = [pts objectAtIndex:sp-1];
					NSTimeInterval activeTimeDeltaTime = [prevpt activeTimeDelta] - firstActiveTimeDelta;
					NSTimeInterval wallTimeDeltaTime = [prevpt wallClockDelta] - [pt wallClockDelta];
					if (([prevpt activeTimeDelta] != firstActiveTimeDelta) && (activeTimeDeltaTime == wallTimeDeltaTime))			// only correct mid-point lap moving time start times if active during interval
					{
						NSTimeInterval dt = [pt wallClockDelta] - [lap startingWallClockTimeDelta];
						off += dt;
					}
				}
				 
				pt = [pts objectAtIndex:end];
				NSTimeInterval lastActiveTimeDelta = [pt activeTimeDelta];
				float lapDur = [self realDurationOfLap:lap];
				if (end > 0)
				{
					TrackPoint* prevpt = [pts objectAtIndex:end-1];
					NSTimeInterval activeTimeDeltaTime = [prevpt activeTimeDelta] - lastActiveTimeDelta;
					NSTimeInterval wallTimeDeltaTime = [prevpt wallClockDelta] - [pt wallClockDelta];
					if ( ([prevpt activeTimeDelta] != lastActiveTimeDelta) && (activeTimeDeltaTime == wallTimeDeltaTime))			// only correct mid-point lap moving time end times if active during interval
					{
						// subtract time between end point and end lap time (end point is first point *after* the end time);
						NSTimeInterval dt = [pt wallClockDelta] - ([lap startingWallClockTimeDelta] + lapDur);
						off -= dt;
					}
				}
				answer = (lastActiveTimeDelta - firstActiveTimeDelta) + off;
				//NSLog(@"Lap fd: %@  ld: %@  off: %0.1f dur: %0.1f", fdwt, ldwt, off, answer);
			}
			else
			{
				answer = [lap totalTime];
			}
		}
	}
	return answer;
}


- (float) movingSpeedForLap:(Lap*)lap
{
	float answer = 0.0;
	float totalDist = [self distanceOfLap:lap];
	NSTimeInterval totalInterval = [self movingDurationOfLap:lap];
	if (totalInterval > 0.0)
		answer = totalDist/(totalInterval/(60.0*60.0));
	return answer;
}   



- (NSString *)movingDurationAsString
{
	NSTimeInterval dur = [self movingDuration];
	int hours = (int)dur/3600;
	int mins = (int)(dur/60.0) % 60;
	int secs = (int)dur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}



- (float)durationAsFloat
{
	return (float)[self duration];
}


- (void)calcTimeInNonHRZones:(int)type startIdx:(int)sidx endIdx:(int)eidx
{
	if ((nhrzCacheStart[type] != sidx) || (nhrzCacheEnd[type] != eidx))
	{
		for (int zn = 0; zn<kNumNonHRZones; zn++)
		{
			cachedNonHRZoneTime[type][zn] = 0.0;
		}
		nhrzCacheStart[type] = sidx; nhrzCacheEnd[type] = eidx;
		NSArray* pts = [self goodPoints];
		float min[kNumNonHRZones];
		NSString* key;
		switch (type)
		{
			case kSpeedDefaults:
				key = RCBDefaultSpeedZones;
				break;
			case kPaceDefaults:
				key = RCBDefaultPaceZones;
				break;
			case kGradientDefaults:
				key = RCBDefaultGradientZones;
				break;
			case kCadenceDefaults:
				key = RCBDefaultCadenceZones;
				break;
			case kPowerDefaults:
				key = RCBDefaultPowerZones;
				break;
			case kAltitudeDefaults:
				key = RCBDefaultAltitudeZones;
				break;
			default:
				return;
		}
      
		NSDictionary* dict = [Utils dictFromDefaults:key];
		if (dict)
		{
			min[4] = [[dict objectForKey:RCBDefaultZone5Threshold] floatValue];
			min[3] = [[dict objectForKey:RCBDefaultZone4Threshold] floatValue];
			min[2] = [[dict objectForKey:RCBDefaultZone3Threshold] floatValue];
			min[1] = [[dict objectForKey:RCBDefaultZone2Threshold] floatValue];
			min[0] = [[dict objectForKey:RCBDefaultZone1Threshold] floatValue];

			for (int i=sidx; i<eidx; i++)
			{
				TrackPoint* pt = [pts objectAtIndex:i];
				TrackPoint* nextPt = [pts objectAtIndex:i+1];
				float v = 0.0;
				switch (type)
				{
				   case kSpeedDefaults:
						v = [pt speed];
						break;
				   case kPaceDefaults:
						v = [pt pace];
						break;
				   case kGradientDefaults:
						v = [pt gradient];
						break;
				   case kCadenceDefaults:
						v = [pt cadence];
						break;
					case kPowerDefaults:
						v = [pt power];
						break;
					case kAltitudeDefaults:
						v = [pt altitude];
						break;
				}
				for (int zn = kNumNonHRZones-1; zn>=0; zn--)
				{
					if (((type == kPaceDefaults) && (v <= min[zn])) ||
						((type != kPaceDefaults) && (v >= min[zn])))
					{
						//cachedNonHRZoneTime[type][zn] += [[nextPt activeTime] timeIntervalSinceDate:[pt activeTime]];
						cachedNonHRZoneTime[type][zn] += [nextPt activeTimeDelta] - [pt activeTimeDelta];
						break;
					}
				}
			}
			for (int zn = 0; zn<kNumNonHRZones; zn++)
			{
				if (cachedNonHRZoneTime[type][zn] < 0.0) cachedNonHRZoneTime[type][zn] = 0.0;
			}
		}
	}
}


- (void)calcTimeInHRZones:(int)sidx endIdx:(int)eidx
{
	if ((hrzCacheStart != sidx) || (hrzCacheEnd != eidx))
	{
		hrzCacheStart = sidx; hrzCacheEnd = eidx;
		NSArray* pts = [self goodPoints];
		int min[kNumHRZones];
		min[4] = [Utils intFromDefaults:RCBDefaultZone5Threshold];
		min[3] = [Utils intFromDefaults:RCBDefaultZone4Threshold];
		min[2] = [Utils intFromDefaults:RCBDefaultZone3Threshold];
		min[1] = [Utils intFromDefaults:RCBDefaultZone2Threshold];
		min[0] = [Utils intFromDefaults:RCBDefaultZone1Threshold];

		for (int zn = 0; zn<kNumHRZones; zn++)
		{
			cachedHRZoneTime[zn] = 0.0;
		}
		for (int i=sidx; i<eidx; i++)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			TrackPoint* nextPt = [pts objectAtIndex:i+1];
			int hr = [pt heartrate];
			for (int zn = kNumHRZones-1; zn>=0; zn--)
			{
				if (hr >= min[zn])
				{
					//cachedHRZoneTime[zn] += [[nextPt activeTime] timeIntervalSinceDate:[pt activeTime]];
					cachedHRZoneTime[zn] += ([nextPt activeTimeDelta] - [pt activeTimeDelta]);
					break;
				}
			}
		}
		for (int zn = 0; zn<kNumHRZones; zn++)
		{
			if (cachedHRZoneTime[zn] < 0.0) cachedHRZoneTime[zn] = 0.0;
		}
	}
}


- (NSTimeInterval)timeInHRZone:(int)zone
{
    NSArray* pts = [self goodPoints];
   [self calcTimeInHRZones:0 endIdx:(int)[pts count]-1];
   return cachedHRZoneTime[zone];
}


- (NSTimeInterval)timeInNonHRZone:(int)type zone:(int)zone
{
	NSArray* pts = [self goodPoints];
	[self calcTimeInNonHRZones:type startIdx:0 endIdx:(int)[pts count]-1];
	return cachedNonHRZoneTime[type][zone];
}


   
- (NSString*)timeInHRZoneAsString:(int)zone
{
	NSTimeInterval dur = [self timeInHRZone:zone];
	int hours = (int)dur/3600;
	int mins = (int)(dur/60.0) % 60;
	int secs = (int)dur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}

- (NSString*)timeInNonHRZoneAsString:(int)type zone:(int)zone
{
	NSTimeInterval dur = [self timeInNonHRZone:type zone:zone];
	int hours = (int)dur/3600;
	int mins = (int)(dur/60.0) % 60;
	int secs = (int)dur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}


- (NSTimeInterval)timeInHRZoneForInterval:(int)zone start:(int)sidx end:(int)eidx;
{
	[self calcTimeInHRZones:sidx endIdx:eidx];
	return cachedHRZoneTime[zone];
}


- (NSTimeInterval)timeInNonHRZoneForInterval:(int)type zone:(int)zone start:(int)sidx end:(int)eidx
{
	[self calcTimeInNonHRZones:type startIdx:sidx endIdx:eidx];
	return cachedNonHRZoneTime[type][zone];
}

- (NSTimeInterval)timeLapInHRZone:(int)zone lap:(Lap*)lap
{
	float ret = 0.0;
	int num = (int)[lapInfoArray count];
	int i;
	for (i=0; i<num; i++)
	{
		LapInfo* li = [lapInfoArray objectAtIndex:i];
		if ([li lap] == lap)
		{
			int sp = [li startingPointIndex];
			[self calcTimeInHRZones:sp endIdx:sp + [li numPoints]-1];
			ret = cachedHRZoneTime[zone];
		}
	}
	return ret;
}

- (NSTimeInterval)timeLapInNonHRZone:(int)type zone:(int)zone lap:(Lap*)lap
{
	float ret = 0.0;
	int num = (int)[lapInfoArray count];
	int i;
	for (i=0; i<num; i++)
	{
		LapInfo* li = [lapInfoArray objectAtIndex:i];
		if ([li lap] == lap)
		{
			int sp = [li startingPointIndex];
			[self calcTimeInNonHRZones:type startIdx:sp endIdx:sp + [li numPoints]-1];
			ret = cachedNonHRZoneTime[type][zone];
		}
	}
	return ret;
}




- (float)weight
{
   //NSString* s = [self attribute:kWeight];
   //return [s floatValue];
   return weight;
}


- (void)setWeight:(float)w
{
   weight = w;
}


- (tLatLonBounds) getLatLonBounds
{
	tLatLonBounds bds;
	bds.minLat = kMaxPossibleLatitude;
	bds.maxLat = kMinPossibleLatitude;
	bds.minLon = kMaxPossibleLongitude;
	bds.maxLon = kMinPossibleLongitude;
	int num = (int)[points count];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [points objectAtIndex:i];
		if ([pt validLatLon])
		{
			float lat = [pt latitude];
			float lon = [pt longitude];
			if (lat < bds.minLat) bds.minLat = lat;
			if (lat > bds.maxLat) bds.maxLat = lat;
			if (lon < bds.minLon) bds.minLon = lon;
			if (lon > bds.maxLon) bds.maxLon = lon;
		}
	}
	return bds;
}


- (float) minLatitude
{
   int num = (int)[points count];
   int i;
   float min = kMaxPossibleLatitude;
   
   for (i=0; i<num; i++)
   {
      TrackPoint* pt = [points objectAtIndex:i];
      float lat = [pt latitude];
      if ([pt validLatLon] && (lat < min)) min = lat;
   }
   return min;
}


- (float) minLongitude
{
   int num = (int)[points count];
   int i;
   float min = kMaxPossibleLongitude;
   
   for (i=0; i<num; i++)
   {
      TrackPoint* pt = [points objectAtIndex:i];
      float lon = [pt longitude];
      if ([pt validLatLon] && (lon < min)) min = lon;
   }
   return min;
}


- (float) maxLatitude
{
   int num = (int)[points count];
   int i;
   float max = kMinPossibleLatitude;
   
   for (i=0; i<num; i++)
   {
      TrackPoint* pt = [points objectAtIndex:i];
      float lat = [pt latitude];
      if ([pt validLatLon] && (lat > max)) max = lat;
   }
   return max;
}

- (float) maxLongitude
{
   int num = (int)[points count];
   int i;
   float max = kMinPossibleLongitude;
   
   for (i=0; i<num; i++)
   {
      TrackPoint* pt = [points objectAtIndex:i];
      float lon = [pt longitude];
      if ([pt validLatLon] && (lon > max)) max = lon;
   }
   return max;
}


- (NSString *)durationAsString
{
   NSTimeInterval dur = [self duration];
   int hours = (int)dur/3600;
   int mins = (int)(dur/60.0) % 60;
   int secs = (int)dur % 60;
   return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}



- (void)storeMinMaxAvgStat:(struct tStatData*)data value:(float)val nextValue:(float)nv deltaTime:(float)dt atActiveTimeDelta:(NSTimeInterval)atd atDistance:(float)dist
{
   if (data->vals[kMax] < val) 
   { 
      data->vals[kMax] = val; 
	  data->atActiveTimeDelta[kMax] = atd;
      data->vals[kDistanceAtMax] = dist;
   } 
   if (data->vals[kMin] > val)
   { 
      data->vals[kMin] = val; 
	  data->atActiveTimeDelta[kMin] = atd;
   }
   data->vals[kAvg] += (val * dt);
}


- (void)calcGradients
{
   //NSArray *pts = [self goodPoints];
	NSArray *pts = [self points];
	int count = (int)[pts count];
	if (count > 1)
	{
		TrackPoint* pt = [pts objectAtIndex:0];
		float lastDist = [self firstValidDistance:0] * 5280.0;
		float lastAlt = [self firstValidAltitude:0];
		float lastGradient = 0.0;
		[pt setGradient:0.0];
		int i;
		BOOL hasElevationData = NO;
		for (i=1; i<count; i++)
		{
			pt = [pts objectAtIndex:i];
			if (![pt isDeadZoneMarker] && (lastAlt != BAD_ALTITUDE))
			{
				hasElevationData = YES;
				float alt = [pt altitude];
				float dist = [pt distance];
				dist = dist * 5280.0;   // calculate in feet
				float deltaDist = (dist - lastDist);
				if ((deltaDist > 0.0) && (deltaDist >= minGradientDistance) && [pt validAltitude])
				{
				   float gradient = ((alt-lastAlt)/deltaDist) * 100.0;    // tangent calculation
				   lastDist = dist;
				   lastAlt = alt;
				   if (IS_BETWEEN(-45.0, gradient, +45.0))lastGradient = gradient;
				}
				///printf("alt:%0f lastAlt:%0f dist:%0f deltaDist:%0f grad:%0.1f\n",
				///	   alt, lastAlt, dist, deltaDist, lastGradient);
			}
			[pt setGradient:lastGradient];
		}
		if (hasElevationData) SET_FLAG(flags, kHasElevationData);
		
	}
}


static float sLastAlt;

- (BOOL) accumAltitude:(TrackPoint*)pt filter:(float)altFilter 
				  altData:(struct tStatData*)altData
				climbData:(struct tStatData*)climbData
{
	if ([pt validAltitude])
	{
		float alt = [pt altitude];
		if (alt > (sLastAlt + altFilter))
		{
			climbData->vals[kMax]  += (alt - sLastAlt);
			sLastAlt = alt;
		}
		else if (alt < (sLastAlt - altFilter))
		{
			climbData->vals[kMin]  += (sLastAlt - alt);
			sLastAlt = alt;
		}
		return YES;
	}
	return NO;
}


- (float) calcElapsedTime:(int)startingGoodPoint end:(int)endingGoodPoint
{
	float val;
	NSArray* gpts = [self goodPoints];
	unsigned numPts = (unsigned)[gpts count];
	if (numPts > 1)
	{
		//TrackPoint* pt = [gpts objectAtIndex:endingGoodPoint];
		//NSDate* last =  [pt date];
		//val = [last timeIntervalSinceDate:[[gpts objectAtIndex:startingGoodPoint] date]];
		val = [[gpts objectAtIndex:endingGoodPoint] wallClockDelta] - [[gpts objectAtIndex:startingGoodPoint] wallClockDelta];
	}
	else
	{
		val = 0.0;
	}
	if (val < 0.0) val = 0.0;
	return val;
}

enum
{
	kFemaleGender,
	kMaleGender
};


- (float) calcCalories:(struct tStatData*) statData hrTime:(float)hrTime
{
	float answer = 0.0;
	float avgHR = statData[kST_Heartrate].vals[kAvg];
	if (avgHR > 0.0)
	{
		//struct tStatData* durData = &statData[kST_Durations];
		//float minutes = durData->vals[kElapsed]/60.0;
		float minutes = hrTime/60.0;
		int gender = [Utils intFromDefaults:RCBDefaultGender];
		float vO2Max = [Utils floatFromDefaults:RCBDefaultVO2Max];
		float age = [Utils floatFromDefaults:RCBDefaultAge];
		float wt = PoundsToKilograms([self weight]);
		// if have vO2Max
		if (vO2Max > 0.0)
		{
			if (gender == kMaleGender)
			{
				answer = ((-59.3954 + (-36.3781 + 0.271 * age + 0.394 * wt + 0.404 * vO2Max + 0.634 * avgHR))/4.184) * minutes;
			}
			else
			{
				answer = ((-59.3954 + (0.274 * age + 0.103 * wt + 0.380 * vO2Max + 0.450 * avgHR)) / 4.184) * minutes;
			}
		}
		else
		{
			// otherwise
			if (gender == kMaleGender)
			{
				answer = ((-55.0969 + 0.6309 * avgHR + 0.1988 * wt + 0.2017 * age)  / 4.184) * minutes;
			}
			else
			{
				answer = ((-20.4022 + 0.4472 * avgHR - 0.1263* wt + 0.074 * age) / 4.184) * minutes;
			}
		}
	}
	else
	{
		float wt = [self weight];
		NSString* activity = [self attribute:kActivity];
		NSRange range = [activity rangeOfString:@"cycling"
										options:NSCaseInsensitiveSearch];
		BOOL isCycling = range.location != NSNotFound;
		if (!isCycling)
		{
			range = [activity rangeOfString:@"biking"
									options:NSCaseInsensitiveSearch];
			isCycling = range.location != NSNotFound;
		}
		float factor = isCycling ? .28 : .63;
		answer = (factor * wt) * statData[kST_Distance].vals[kVal];
	}
	return answer;
}


#define MIN_HR             10.0
#define MAX_HR_DELTA_SECS  90.0

- (void)calculateStats:(struct tStatData*)sArray startIdx:(int)startingGoodIdx endIdx:(int)endingGoodIdx
{
	NSArray* goodPts = [self goodPoints];
	NSArray* pts = [self points];
	
    int numPoints = (int)[pts count];
    int numGoodPoints = (int)[goodPoints count];
	if (!(IS_BETWEEN(0, startingGoodIdx, numGoodPoints)) ||
		!(IS_BETWEEN(0, endingGoodIdx, numGoodPoints))) return;		// nothing to do here;
	
	// must see "dead interval" markers to calculate things correctly...so convert from "good point array" indices to
	// normal "point array" indices
	int sidx = (startingGoodIdx == 0) ? 0 : (int)[pts indexOfObjectIdenticalTo:[goodPts objectAtIndex:startingGoodIdx]];
	int eidx = (endingGoodIdx >= (numGoodPoints - 1)) ? (numPoints - 1) : (int)[pts indexOfObjectIdenticalTo:[goodPts objectAtIndex:endingGoodIdx]];
	if ((numPoints > 1) && (sidx <= eidx) && (sidx >= 0) && (eidx < numPoints))
	{
		int i;

		TrackPoint* pt = [pts objectAtIndex:sidx];
		sLastAlt = [self firstValidAltitudeUsingGoodPoints:startingGoodIdx];
		//float lastGradientAlt = lastAlt;
		struct tStatData* altData = &sArray[kST_Altitude];
		struct tStatData* climbData = &sArray[kST_ClimbDescent];
		struct tStatData* hrData = &sArray[kST_Heartrate];
		struct tStatData* spdData = &sArray[kST_Speed];
		struct tStatData* movSpdData = &sArray[kST_MovingSpeed];
		struct tStatData* cadData = &sArray[kST_Cadence];
		struct tStatData* pwrData = &sArray[kST_Power];
		struct tStatData* grdData = &sArray[kST_Gradient];
		struct tStatData* temperatureData = &sArray[kST_Temperature];
		altData->vals[kAvg] = altData->vals[kMax] = 0.0;
		altData->vals[kMin] = 9999999.9;
		climbData->vals[kMin] = 0.0;
		climbData->vals[kMax] = 0.0;
		temperatureData->vals[kMin] = 9999999.9;
		grdData->vals[kMin] = 9999999.9;
		cadData->vals[kMin] = 9999999.9;
		pwrData->vals[kMin] = 9999999.9;
		spdData->vals[kMin] = 999999.0;
		hrData->vals[kMin] = 999999.0;
		hrData->vals[kAvg] = hrData->vals[kMax] = 0.0;
		grdData->vals[kAvg] = grdData->vals[kMax] = 0.0;
		temperatureData->vals[kAvg] = 0.0;
		temperatureData->vals[kMax] = -999999.0;
		temperatureData->vals[kMin] =  999999.0;
		cadData->vals[kAvg] = cadData->vals[kMax] = 0.0;
		pwrData->vals[kAvg] = pwrData->vals[kMax] = 0.0;
		spdData->vals[kAvg] = spdData->vals[kMax] = 0.0;
		movSpdData->vals[kAvg] = movSpdData->vals[kMin] = movSpdData->vals[kMax] = 0.0;
		altData->atActiveTimeDelta[kMax] = altData->atActiveTimeDelta[kMin] = hrData->atActiveTimeDelta[kMax] = 
			cadData->atActiveTimeDelta[kMax] = pwrData->atActiveTimeDelta[kMax] = spdData->atActiveTimeDelta[kMax] = 
			grdData->atActiveTimeDelta[kMax] = grdData->atActiveTimeDelta[kMin] = 0.0;
		float spdTime = 0;
		float cadTime = 0;
		float pwrTime = 0;
		float hrTime = 0;
		float temperatureTime = 0;
		float totalTime = 0.0;
		float totalActiveTime = 0.0;
		float speedThreshold = [self movingSpeedThreshold];
		float altFilter = [Utils floatFromDefaults:RCBDefaultAltitudeFilter];
		NSTimeInterval nextTime, nextActiveTime;
		//NSTimeInterval lastTime = [[pt date] timeIntervalSince1970];
		// NSTimeInterval lastActiveTime = [[pt activeTime] timeIntervalSince1970];
		NSTimeInterval lastTime = [pt wallClockDelta];
		NSTimeInterval lastActiveTime = [pt activeTimeDelta];
		BOOL lastPointWasDeadMarker = NO;
		TrackPoint* nxtpt;
		BOOL entireTrack = (sidx == 0) && (eidx == (numPoints-1));
		float startClimb = 0.0;
		float startDescent = 0.0;
		float endClimb = 0.0;
		float endDescent = 0.0;
		BOOL haveStartedAlt = NO;
		BOOL hasCadence = NO;
		BOOL hasPower = NO;
		BOOL hasTemperature = NO;
		for (i=sidx; i<=eidx; i++)
		{
			nxtpt = [pts objectAtIndex:i];
			BOOL nextPointIsDeadZoneMarker = [nxtpt isDeadZoneMarker];
			//nextTime = [[nxtpt date] timeIntervalSince1970];
			//nextActiveTime = [[nxtpt activeTime] timeIntervalSince1970];
			nextTime = [nxtpt wallClockDelta];
			nextActiveTime = [nxtpt activeTimeDelta];
			if ([pt isDeadZoneMarker])
			{
				lastPointWasDeadMarker = YES;
			}
			else
			{
				float dt = nextTime - lastTime;
				float deltaActiveTime = nextActiveTime - lastActiveTime;
				totalTime += dt;
				totalActiveTime += deltaActiveTime;
				//NSDate* g = [pt activeTime];
				//NSDate* ptDate = [[self creationTime] addTimeInterval:[pt activeTimeDelta]];
				// calculate total climb + descent
				float alt = [pt altitude];
				if (entireTrack) 
				{
					if ([self accumAltitude:pt 
									 filter:altFilter 
									altData:altData
								  climbData:climbData])
					{
					}
					[pt setClimbSoFar:climbData->vals[kMax] ];		// set even on deadzone markers
					[pt setDescentSoFar:climbData->vals[kMin]];
				}
				if ((i >= sidx) && !haveStartedAlt) 
				{
				   haveStartedAlt = YES;
				   startClimb = [pt climbSoFar];
				   startDescent = [pt descentSoFar];
				}
				endClimb = [pt climbSoFar];
				endDescent = [pt descentSoFar];
            
				// check for max/min altitude
				if ([pt validAltitude])
				{
					[self storeMinMaxAvgStat:altData 
									   value:alt 
								   nextValue:(nextPointIsDeadZoneMarker ? alt : [nxtpt altitude])
								   deltaTime:dt
						   atActiveTimeDelta:[pt activeTimeDelta]
								  atDistance:[pt distance]];
				}

				// gradient
				float gradient = [pt gradient];
				[self storeMinMaxAvgStat:grdData 
								   value:gradient 
							   nextValue:(nextPointIsDeadZoneMarker ? gradient : [nxtpt gradient])
							   deltaTime:deltaActiveTime              // uses ACTIVE time
					   atActiveTimeDelta:[pt activeTimeDelta]
							  atDistance:[pt distance]];
            
				// heartrate
				float hr = [pt heartrate];
				if ((hr > MIN_HR) && (dt < MAX_HR_DELTA_SECS))
				{
					[self storeMinMaxAvgStat:hrData 
									  value:hr 
								  nextValue:(nextPointIsDeadZoneMarker ? hr : [nxtpt heartrate])
								  deltaTime:dt
						  atActiveTimeDelta:[pt activeTimeDelta]
								 atDistance:[pt distance]];
				   hrTime += dt;
				}
				// speed
				float speed = [pt speed];
				[self storeMinMaxAvgStat:spdData 
								   value:speed 
							   nextValue:(nextPointIsDeadZoneMarker ? speed : [nxtpt speed])
							   deltaTime:dt
					   atActiveTimeDelta:[pt activeTimeDelta]
							  atDistance:[pt distance]];

				if (speed > speedThreshold)
				{
				   [self storeMinMaxAvgStat:movSpdData 
									  value:speed 
								  nextValue:(nextPointIsDeadZoneMarker ? speed : [nxtpt speed])
								  deltaTime:dt
						  atActiveTimeDelta:[pt activeTimeDelta]
								 atDistance:[pt distance]];
				   spdTime += dt;
				}
				// cadence
				float cad = [pt cadence];
				if ((cad > 1.0) && (cad < 254.50))  // 255 is no value
				{
				   [self storeMinMaxAvgStat:cadData 
									  value:cad 
								  nextValue:(nextPointIsDeadZoneMarker ? cad : [nxtpt cadence])
								  deltaTime:deltaActiveTime         // uses ACTIVE time
						  atActiveTimeDelta:[pt activeTimeDelta]
								 atDistance:[pt distance]];
				   cadTime += deltaActiveTime;
				   hasCadence = YES;
				}
				//power
				float power = [pt power];
				if (power >= 0.0)  // neg is no value
				{
					[self storeMinMaxAvgStat:pwrData 
									   value:power 
								   nextValue:(nextPointIsDeadZoneMarker ? power : [nxtpt power])
								   deltaTime:deltaActiveTime         // uses ACTIVE time
						   atActiveTimeDelta:[pt activeTimeDelta]
								  atDistance:[pt distance]];
					pwrTime += deltaActiveTime;
					hasPower = YES;
				}
				// temperature
				float temperature = [pt temperature];
				if (temperature != 0.0)  
				{
					[self storeMinMaxAvgStat:temperatureData 
									   value:temperature 
								   nextValue:(nextPointIsDeadZoneMarker ? cad : [nxtpt temperature])
								   deltaTime:deltaActiveTime         // uses ACTIVE time
						   atActiveTimeDelta:[pt activeTimeDelta]
								  atDistance:[pt distance]];
					temperatureTime += deltaActiveTime;
					hasTemperature = YES;
				}
			}
 			pt = nxtpt;
			lastTime = nextTime;
			lastActiveTime = nextActiveTime;
		}
		i = eidx+1;
		while (i < (numPoints-1))
		{
		 TrackPoint* pt = [pts objectAtIndex:i];
		 if (/*[pt validAltitude]*/ ![pt isDeadZoneMarker])
		 {
			endClimb = [pt climbSoFar];
			endDescent = [pt descentSoFar];
			break;
		 }
		 ++i;
		}
		climbData->vals[kMax] = endClimb - startClimb;
		climbData->vals[kMin] = endDescent - startDescent;
		if (totalTime > 0.0) altData->vals[kAvg] /= totalTime;
		if (hrTime > 0.0) hrData->vals[kAvg] /= hrTime;  else hrData->vals[kAvg] = hrData->vals[kMin] = 0.0;
		// calculate average gradient using start and end points, rather than the normal
		// 'moving' average calculated above.  This was a bug report.
		//TrackPoint* spt = [pts objectAtIndex:sidx];
		//TrackPoint* ept = [pts objectAtIndex:eidx];
		//float sdist = [spt distance] * 5280;	// miles to feet
		//float edist = [ept distance] * 5280;
		if (cadTime > 0.0) cadData->vals[kAvg] /= cadTime; else cadData->vals[kAvg] = cadData->vals[kMin] = 0.0;
		if (pwrTime > 0.0) pwrData->vals[kAvg] /= pwrTime; else pwrData->vals[kAvg] = pwrData->vals[kMin] = 0.0;
		if (temperatureTime > 0.0) temperatureData->vals[kAvg] /= temperatureTime; 
		else temperatureData->vals[kMin] = temperatureData->vals[kMax] = temperatureData->vals[kAvg] = 0.0;
		if (totalTime > 0.0) spdData->vals[kAvg] /= totalTime;
		struct tStatData* durData = &sArray[kST_Durations];
		durData->vals[kElapsed] = [self calcElapsedTime:startingGoodIdx
											  end:endingGoodIdx];
		durData->vals[kMoving] = [self movingDurationBetweenGoodPoints:startingGoodIdx
															 end:endingGoodIdx];
		float sdist = [self firstValidDistance:sidx];	
		float edist = [self lastValidDistance:eidx];
		float startAlt = [self firstValidAltitude:sidx];
		float endAlt = [self lastValidAltitude:eidx];
		struct tStatData* distData = &sArray[kST_Distance];
		if (edist > sdist)
		{
			// need to convert miles to feet
			float dist = (edist - sdist);
			float distInFeet = (dist*5280.0);
			if (distInFeet >= minGradientDistance)
			{
				grdData->vals[kAvg] = ((endAlt - startAlt)/(dist*5280.0)) * 100.0;
			}
			else
			{
				grdData->vals[kAvg] = 0.0;
			}
			float md = durData->vals[kMoving];
			if (md > 0.0)
			{
				movSpdData->vals[kAvg] = (dist/(md/(60.0*60.0)));		// FIXME!
			}
			else
			{
				movSpdData->vals[kAvg] = 0.0;
			}
			distData->vals[kVal] = dist;
		}
		else
		{
			distData->vals[kVal] = 0.0;
		}
		//if (spdTime > 0.0) movSpdData->vals[kAvg] /= spdTime;
		struct tStatData* calData = &sArray[kST_Calories];
		calData->vals[kVal] = [self calcCalories:sArray hrTime:hrTime];
		//struct tStatData* movSpdData = &sArray[kST_MovingSpeed];
		//float md = [self movingDuration];
	}
}

-(float)getTotalDistanceUsingLaps
{
	float td = 0.0;
	if (laps && [laps count] > 0)
	{
		NSNumber* num = [laps valueForKeyPath:@"@sum.distance"];
		td = [num floatValue];
	}
	return td;
}

- (void) calculateTrackStats
{
	if (statsCalculated == NO)
	{
		statsCalculated = YES;
		if ([[self goodPoints] count] > 0)
		{
			[self calculateStats:statsArray startIdx:0 endIdx:(int)[[self goodPoints] count]-1];
			// fill in other stats not
			struct tStatData* distData = &statsArray[kST_Distance];
			if (distance <= 0.0)
				distance = [self getTotalDistanceUsingLaps];
			distData->vals[kVal] = distance;
			// override the normal 'average' calculation for moving speed, and just 
			// divide distance by moving duration
			// plug in calorie data, for now we get it from laps (Garmin calculation) @@FIXME@@
			//struct tStatData* calData = &statsArray[kST_Calories];
			//NSNumber* num = [laps valueForKeyPath:@"@sum.calories"];
			//calData->vals[kVal] = [num floatValue];
		}
		else
		{
			// no points; fill in what we can from laps, if they exists
			if (laps && [laps count] > 0)
			{
				float totalDistance = [self getTotalDistanceUsingLaps];
				statsArray[kST_Distance].vals[kVal] = totalDistance;
				statsArray[kST_Heartrate].vals[kMax] = [[laps valueForKeyPath:@"@max.maxHeartRate"] floatValue];
				statsArray[kST_Heartrate].vals[kAvg] = [[laps valueForKeyPath:@"@avg.averageHeartRate"] floatValue];	// @@FIMXE@@ (incorporate time)
				statsArray[kST_Cadence].vals[kAvg] = [[laps valueForKeyPath:@"@avg.averageCadence"] floatValue];	// @@FIMXE@@ (incorporate time)
				statsArray[kST_Speed].vals[kMax] = statsArray[kST_MovingSpeed].vals[kMax] = [[laps valueForKeyPath:@"@max.maxSpeed"] floatValue];	
				statsArray[kST_Calories].vals[kVal] = [[laps valueForKeyPath:@"@sum.calories"] floatValue];
				float totalTime = [[laps  valueForKeyPath:@"@sum.totalTime"] floatValue];
				statsArray[kST_Durations].vals[kElapsed] = statsArray[kST_Durations].vals[kMoving] = totalTime;
				if (totalTime > 0.0)
				{
					statsArray[kST_Speed].vals[kAvg] = statsArray[kST_MovingSpeed].vals[kAvg] = totalDistance/totalTime;
				}
			}
            else
            {
                // no points data yet, use anything stored in track
                float totalDistance = [self distance];
                statsArray[kST_Distance].vals[kVal] = totalDistance;
                statsArray[kST_Heartrate].vals[kMax] = [self maxHeartrate:nil];
                statsArray[kST_Heartrate].vals[kAvg] = [self avgHeartrate];
                statsArray[kST_Cadence].vals[kAvg] = [self avgCadence];
                statsArray[kST_Power].vals[kAvg] = [self avgPower];
                statsArray[kST_Power].vals[kMax] = [self maxPower:nil];
                statsArray[kST_Speed].vals[kMax] = [self avgSpeed];
                statsArray[kST_MovingSpeed].vals[kMax] = [self maxSpeed:nil];
                ///statsArray[kST_Calories].vals[kVal] = [[laps valueForKeyPath:@"@sum.calories"] floatValue];
                statsArray[kST_Durations].vals[kElapsed] = [self duration];
                statsArray[kST_Durations].vals[kMoving] = [self movingDuration];
            }
		}
	}
}


- (void)invalidateStats
{
   hrzCacheStart = hrzCacheEnd = -42;
   for (int i=0; i <= kMaxZoneType; i++)
   {
      nhrzCacheStart[i] = nhrzCacheEnd[i] = -42;
   }
   statsCalculated = NO;
   [self invalidateAllLapStats];
}


- (struct tStatData*) getStat:(int)type
{
	[self calculateTrackStats];
	return &statsArray[type];
}


- (float)stat:(tStatType)stat index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atTime 
{
	float val;
	if ([overrideData isOverridden:stat])
	{
		val = [overrideData value:stat index:idx];
	}
	else
	{
		[self calculateTrackStats];
		val = statsArray[stat].vals[idx];
		if ((nil != atTime) && (idx <= kMin))
		{
			*atTime = statsArray[stat].atActiveTimeDelta[idx];
		}
	}
	return val;
}	


-(float)statOrOverride:(tStatType)stype index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atTime
{
	float val;
	if ([overrideData isOverridden:stype])
	{
		val = [overrideData value:stype 
							index:idx];
		///if (atTime) *atTime = nil;
	}
	else
	{
		val = [self stat:stype
				   index:idx
				  atActiveTimeDelta:atTime];
	}
	return val;
}


- (float)distance
{
	float val = 0.0;
    NSUInteger numLaps = laps ? [laps count] : 0;
	if ([self usingDeviceLapData] && (numLaps > 0) && (![overrideData isOverridden:kST_Distance]))
	{
		for (int i=0; i<numLaps; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			val += [self distanceOfLap:lap];
		}
	}
	else if ([points count] == 0)
    {
        return distance;
    }
    else
	{
		val = [self statOrOverride:kST_Distance
							 index:kVal
				 atActiveTimeDelta:0];
	}
	return val;
}


- (float)maxSpeed
{
	float val = 0.0;
    NSUInteger numLaps = laps ? [laps count] : 0;
	if ([self usingDeviceLapData] && (numLaps > 0) && (![overrideData isOverridden:kST_Distance]))
	{
		for (int i=0; i<numLaps; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			float ms = [lap maxSpeed];
			if (ms > val) val = ms;
		}
	}
	else
	{
		val = [self statOrOverride:kST_MovingSpeed
							 index:kMax
				 atActiveTimeDelta:0];
	}
	return val;
}


- (float)maxSpeed:(NSTimeInterval*)atTime
{
    if (points.count == 0)
    {
        return srcMaxSpeed;
    }
	return [self statOrOverride:kST_MovingSpeed
						  index:kMax
						 atActiveTimeDelta:atTime];
}


- (float)avgSpeed
{
    if (points.count == 0)
    {
        return srcElapsedTime ? srcDistance/(srcElapsedTime/3600.0) : 0.0;
    }
   NSTimeInterval dur = [self duration];
   if (dur != 0.0)
   {
      float dist = [self distance];
      return dist/(((float)dur)/3600.);
   }
   return 0.0;
}


- (float)avgMovingSpeed
{
    if (points.count == 0)
    {
        return srcMovingTime ? srcDistance/(srcMovingTime/3600.0) : 0.0;
    }
	float val;
	if ([overrideData isOverridden:kST_MovingSpeed])
	{
		val = [overrideData value:kST_MovingSpeed 
							index:kAvg];
	}
	else
	{
		val = 0.0;
		NSTimeInterval dur = [self movingDuration];
		if (dur != 0.0)
		{
			float dist = [self distance];
			val = dist/(((float)dur)/3600.);
		}
	}
	return val;
}


- (float)minPace:(NSTimeInterval*)atTime
{
	float val = [self statOrOverride:kST_MovingSpeed
							   index:kMax
							  atActiveTimeDelta:atTime];
	if (val != 0.0)
	{
		// hours/mile * mins/hour = mins/mile; 
		val = (1.0*60.0)/val;
	}
	return val;
}


- (float)avgPace
{
	//float val = [self statOrOverride:kST_Speed
	//						   index:kAvg
	//						  atActiveTimeDelta:0];
	float val = [self avgSpeed];
	if (val != 0.0)
	{
	  // hours/mile * mins/hour = mins/mile; 
	  val = (1.0*60.0)/val;
	}
	return val;
}


- (float)avgMovingPace
{
	//float val = [self statOrOverride:kST_MovingSpeed
	//						   index:kAvg
	//						  atActiveTimeDelta:0];
	float val = [self avgMovingSpeed];
	if (val != 0.0)
	{
		// hours/mile * mins/hour = mins/mile; 
		val = (1.0*60.0)/val;
	}
	return val;
}


- (float)calories
{
	float answer = 0.0;
	int numLaps = laps ? (int)[laps count] : 0;
	if ([self usingDeviceLapData] && (numLaps > 0) && (![overrideData isOverridden:kST_Distance]))
	{
		for (int i=0; i<numLaps; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			answer += [self caloriesForLap:lap];
		}
	}
	else
	{
		answer = [self statOrOverride:kST_Calories
								index:kVal
					atActiveTimeDelta:0];
	}
	return answer;
}



- (float)maxAltitude:(NSTimeInterval*)atTime
{
    if (points.count ==0)
    {
        return srcMaxElevation;
    }
	return [self statOrOverride:kST_Altitude
						  index:kMax
						 atActiveTimeDelta:atTime];
}


- (float)minAltitude:(NSTimeInterval*)atTime
{
    if (points.count ==0)
    {
        return srcMinElevation;
    }
	return [self statOrOverride:kST_Altitude
						  index:kMin
						 atActiveTimeDelta:atTime];
}

- (float)avgAltitude
{
	return [self statOrOverride:kST_Altitude
						  index:kAvg
			  atActiveTimeDelta:0];
}


- (float)maxHeartrate:(NSTimeInterval*)atTime
{
    if (points.count == 0)
    {
        return srcMaxHeartrate;
    }
    
	float val = 0.0;
	int numLaps = laps ? (int)[laps count] : 0;
	BOOL useLapData = ([self usingDeviceLapData] && (numLaps > 0) && (![overrideData isOverridden:kST_Heartrate]));
	if (useLapData)
	{
		for (int i=0; i<numLaps; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			float max = [lap maxHeartRate];
			if (max > val) val = max;
		}
	}
	if (!useLapData || (val <= 0.0))
	{
		val = [self statOrOverride:kST_Heartrate
                             index:kMax
                 atActiveTimeDelta:atTime];
	}
	return val;
}


- (float)minHeartrate:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Heartrate
						  index:kMin
			  atActiveTimeDelta:atTime];
}


- (float)avgHeartrate
{
    if (points.count == 0)
    {
        return srcAvgHeartrate;
    }

    return [self statOrOverride:kST_Heartrate
						  index:kAvg
						 atActiveTimeDelta:0];
}


- (float)maxGradient:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Gradient
						  index:kMax
						 atActiveTimeDelta:atTime];
}


- (float)minGradient:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Gradient
						  index:kMin
						 atActiveTimeDelta:atTime];
}



- (float)maxTemperature:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Temperature
						  index:kMax
			  atActiveTimeDelta:atTime];
}


- (float)minTemperature:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Temperature
						  index:kMin
			  atActiveTimeDelta:atTime];
}



- (float)avgGradient
{
	return [self statOrOverride:kST_Gradient
						  index:kAvg
						 atActiveTimeDelta:0];
}


- (float)avgTemperature
{
    if (points.count == 0)
    {
        return srcAvgTemperature;
    }
	return [self statOrOverride:kST_Temperature
						  index:kAvg
			  atActiveTimeDelta:0];
}


- (float)maxCadence:(NSTimeInterval*)atTime
{
	return [self statOrOverride:kST_Cadence
						  index:kMax
			  atActiveTimeDelta:atTime];
}


- (float)avgCadence
{
    if (points.count == 0)
    {
        return srcAvgCadence;
    }
	return [self statOrOverride:kST_Cadence
						  index:kAvg
						 atActiveTimeDelta:0];
}


-(void)setEnableCalculationOfPower:(BOOL)en
{
	if (en)
	{
		CLEAR_FLAG(flags, kDontCalculatePower);
	}
	else
	{
		SET_FLAG(flags, kDontCalculatePower);
	}
}


-(BOOL)calculationOfPowerEnabled
{
	return FLAG_IS_SET(flags, kDontCalculatePower);
}

-(BOOL)activityIsValidForPowerCalculation
{
	NSString* act = [self attribute:kActivity];
	NSArray* powerActs = [Utils objectFromDefaults:RCBDefaultCalculatePowerActivities];
	return [self hasDevicePower] || (powerActs && [powerActs containsObject:act]);
}


-(void)calculatePower
{
	if (![self hasDevicePower])
	{
		NSArray* pts = [self goodPoints];
		int num = (int)[pts count];
		BOOL hasCadence = [self hasCadence];
		float gravConst = 9.8;
		float rollingResistance = 0.0053;
		float drag = 0.185;
		float bikeWeight = PoundsToKilograms(equipmentWeight);
#if ASCENT_DBG
		///printf("equipment weight for power calculations: %0.1f kg\n", bikeWeight); 
#endif
		BOOL calcPower = [self activityIsValidForPowerCalculation];
		for (int i=0; i<num; i++)
		{
			float p = 0.0;
			TrackPoint* pt = [pts objectAtIndex:i];
			///if ([self calculationOfPowerEnabled] && [self activityIsValidForPowerCalculation])
			if (calcPower)
			{
				float cadence = [pt cadence];
				if (!hasCadence || (IS_BETWEEN(0.0, cadence, 254.0)))
				{
					float spd = MilesToKilometers([pt speed]) * (10.0/36.0);	// convert to m/sec
					float wt = PoundsToKilograms([self weight]) + bikeWeight;
					p = (gravConst * wt * spd * (rollingResistance + ([pt gradient]/100.0))) + (drag*spd*spd*spd);
				}
			}
			[pt setCalculatedPower:p];
		}
		SET_FLAG(flags, kPowerDataCalculatedOrZeroed);
		if (!calcPower && peakIntervalData) 
		{
			free(peakIntervalData);
			peakIntervalData = 0;
		}
		statsCalculated = NO;
		[self calculateTrackStats];
	}
}


-(void)setEquipmentWeight:(float)iw
{
	equipmentWeight = iw;
	CLEAR_FLAG(flags, kPowerDataCalculatedOrZeroed);
}

-(void)setStaleEquipmentAttr:(BOOL)v
{
	if (v)
	{
		SET_FLAG(flags, kEquipmentAttrStale);
	}
	else
	{
		CLEAR_FLAG(flags, kEquipmentAttrStale);
	}
}


-(BOOL)staleEquipmentAttr
{
	return FLAG_IS_SET(flags, kEquipmentAttrStale);
}


-(void)checkPowerData
{
	if (![self hasDevicePower] && (!FLAG_IS_SET(flags, kPowerDataCalculatedOrZeroed)))
	{
		[self calculatePower];
	}
}

- (float)maxPower:(NSTimeInterval*)atTime
{
    if (points.count == 0)
    {
        return srcMaxPower;
    }
	[self checkPowerData];
	return [self statOrOverride:kST_Power
						  index:kMax
			  atActiveTimeDelta:atTime];
}


- (float)avgPower
{
    if (points.count == 0)
    {
        return srcAvgPower;
    }
	[self checkPowerData];
	return [self statOrOverride:kST_Power
						  index:kAvg
			  atActiveTimeDelta:0];
}



- (float)work
{
    if (points.count == 0)
    {
        return srcKilojoules;
    }
	float val = 0.0;
	if ([overrideData isOverridden:kST_Power])
	{
		val = [overrideData value:kST_Power 
							index:kWork];
	}
	else
	{
		val = PowerDurationToWork([self avgPower], [self movingDuration]);
	}
	return val;
}


- (float)totalClimb
{
    if (points.count == 0)
    {
        return srcTotalClimb;
    }
    return [self statOrOverride:kST_ClimbDescent
                                index:kMax
                    atActiveTimeDelta:0];
}


- (float)totalDescent
{
	return [self statOrOverride:kST_ClimbDescent
						  index:kMin
						 atActiveTimeDelta:0];
}


- (BOOL)isDateDuringTrack:(NSDate*)d
{
	NSDate* cdt = [self creationTime];
	NSDate* endDate = [[NSDate alloc] initWithTimeInterval:[self duration] sinceDate:cdt];
	BOOL isLessThan = [d compare:cdt] == NSOrderedAscending;
	BOOL isGreaterThan = [d compare:endDate] == NSOrderedDescending;
	return ((isLessThan == NO) && (isGreaterThan == NO));
}


-(float) firstValidLatitude
{
	NSMutableArray* pts = [self goodPoints];
	int i;
	for (i=0; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validLatLon])
		{
			return [pt latitude];
		}
	}
	return BAD_LATLON;
}


-(float) firstValidLongitude
{
	NSMutableArray* pts = [self goodPoints];
	int i;
	for (i=0; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validLatLon])
		{
            return [pt longitude];
		}
	}
	return BAD_LATLON;
}


-(float) firstValidAltitude:(int)sidx
{
	NSMutableArray* pts = [self points];
	int i;
	for (i=sidx; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validAltitude])
		{
			return [pt altitude];
		}
	}
	return BAD_ALTITUDE;
}


-(float) lastValidAltitude:(int)eidx
{
	NSMutableArray* pts = [self points];
	int i;
	for (i=eidx; i>=0; i--)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validAltitude])
		{
			return [pt altitude];
		}
	}
	return BAD_ALTITUDE;
}


-(float) firstValidDistance:(int)sidx
{
	NSMutableArray* pts = [self points];
	int i;
	for (i=sidx; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validDistance])
		{
			return [pt distance];
		}
	}
	return BAD_DISTANCE;
}


-(float) firstValidOrigDistance:(int)sidx
{
	NSMutableArray* pts = [self points];
	int i;
	for (i=sidx; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validOrigDistance])
		{
			return [pt origDistance];
		}
	}
	return BAD_DISTANCE;
}


-(float) lastValidDistance:(int)eidx
{
	NSMutableArray* pts = [self points];
	int i;
	for (i=eidx; i>=0; i--)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validDistance])
		{
			return [pt distance];
		}
	}
	return BAD_DISTANCE;
}


-(float) firstValidAltitudeUsingGoodPoints:(int)sidx
{
	NSArray* pts = [self goodPoints];
	int i;
	for (i=sidx; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validAltitude])
		{
			return [pt altitude];
		}
	}
	return BAD_ALTITUDE;
}


-(TrackPoint*) closestPointToDistance:(float)d
{
	NSMutableArray* pts = [self goodPoints];
	int i;
	for (i=0; i<[pts count]; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if (([pt validLatLon]) && ([pt distance] >= d))
		{
			return pt;
		}
	}
	return nil;
}


- (void) setUseOrigDistance:(BOOL)yn
{
	if (yn) 
	{
		SET_FLAG(flags, kUseOrigDistance);
	}
	else
	{
		CLEAR_FLAG(flags, kUseOrigDistance);
	}
}


- (BOOL) useOrigDistance
{
	return FLAG_IS_SET(flags, kUseOrigDistance);
}


-(BOOL)usingDeviceLapData
{
	return FLAG_IS_SET(flags, kUseDeviceLapData);
}


-(void)setUseDeviceLapData:(BOOL)use
{
	if (use) 
	{
		SET_FLAG(flags, kUseDeviceLapData);
	}
	else
	{
		CLEAR_FLAG(flags, kUseDeviceLapData);
	}
}


-(void)setHasDeviceTime:(BOOL)has
{
	if (has) 
	{
		SET_FLAG(flags, kHasDeviceTime);
	}
	else
	{
		CLEAR_FLAG(flags, kHasDeviceTime);
	}
}


-(void)setHasCadence:(BOOL)has
{
	if (has)
	{
		SET_FLAG(flags, kHasCadenceData);
	}
	else
	{
		CLEAR_FLAG(flags, kHasCadenceData);
	}
}


-(BOOL)hasCadence
{
	return FLAG_IS_SET(flags, kHasCadenceData);
}


-(BOOL)hasExplicitDeadZones
{
    return FLAG_IS_SET(flags, kHasExplicitDeadZones);
}


-(void)setHasExplicitDeadZones:(BOOL)has
{
    if (has)
    {
        SET_FLAG(flags, kHasExplicitDeadZones);
    }
    else
    {
        CLEAR_FLAG(flags, kHasExplicitDeadZones);
    }
}



//---- Power-related -----------------------------------------------------------

-(void)setHasDevicePower:(BOOL)has
{
	if (has)
	{
		SET_FLAG(flags, kHasDevicePowerData);
	}
	else
	{
		CLEAR_FLAG(flags, kHasDevicePowerData);
	}
}


-(BOOL)hasDevicePower
{
	return FLAG_IS_SET(flags, kHasDevicePowerData);
}


-(BOOL)hasElevationData
{
	return FLAG_IS_SET(flags, kHasElevationData);
}


-(BOOL)hasLocationData
{
	return FLAG_IS_SET(flags, kHasLocationData);
}




typedef float (*tAccessor)(id, SEL);

struct tInterpData
{
	float	mData;
	int		mGoodPointIdx;
};

-(tInterpData*) createInterpolatedData:(SEL)ptSel
{ 
	NSArray* gpts = [self goodPoints];
	int count = (int)[gpts count];
	if (count < 1) return nil;
	
	int limit = (int)[self movingDuration];
	tInterpData* data = (tInterpData*)malloc(sizeof(tInterpData)*(limit + 1));
	NSEnumerator* enumer = [goodPoints objectEnumerator];
	TrackPoint* pt = [gpts objectAtIndex:0];
	float currentTime = [pt activeTimeDelta];
	tAccessor ysel = (tAccessor)[TrackPoint instanceMethodForSelector:ptSel];
	int ptIndex = 0;
	TrackPoint* nextPt = [enumer nextObject];
    NSTimeInterval nextPtTime =  pt ? [pt activeTimeDelta] : 0;
	for (int i=0; i<=limit; i++)
	{
        nextPtTime = nextPt ? [nextPt activeTimeDelta] : nextPtTime;
		while ((currentTime >= nextPtTime) && nextPt)
		{
			pt = nextPt;
			++ptIndex;
			nextPt = [enumer nextObject];
			nextPtTime = [nextPt activeTimeDelta];
		}
		NSTimeInterval curPtTime = [pt activeTimeDelta];
		float val = ysel(pt, nil);
		float nextPtVal = val;
		if (nextPtTime > curPtTime)
		{
			nextPtVal = ysel(nextPt, nil);
			val += ((currentTime - curPtTime)*(nextPtVal-val)/(nextPtTime - curPtTime));
		}
		//printf("i:%d [%x] pt:%0.1f [%x] nt:%0.1f ptv:%0.1f nxtv:%01.f   val:%01.f\n", i, pt, curPtTime, nextPt, nextPtTime, ysel(pt, nil), nextPtVal, val);
		data[i].mData = val;
		data[i].mGoodPointIdx = ptIndex;
		currentTime += 1.0;
	}
	return data;
}


-(tPeakIntervalData*) getPID:(tPeakDataType)ty intervalIndex:(int)pi
{
	int np = [Utils numPeakIntervals];
	tPeakIntervalData* pid = (tPeakIntervalData*)&peakIntervalData[(ty * np) + pi];
	return pid;
}


-(void)setPeakForIntervalType:(tPeakDataType)ty intervalIndex:(int)pi value:(float)v atActiveTime:(NSTimeInterval)at
{
	tPeakIntervalData* pid = [self getPID:ty
							intervalIndex:pi];
	pid->value = v;
	pid->activeTime = at;
}


-(float)peakForIntervalType:(tPeakDataType)ty intervalIndex:(int)pi peakStartTime:(NSTimeInterval*)pst startingGoodPointIndex:(int*)sgpi
{
	[self calcPeaks];
	tPeakIntervalData* pid = [self getPID:ty
							intervalIndex:pi];
	if (pst) *pst = pid->activeTime;
	if (sgpi)*sgpi = pid->startingGoodPointIndex;
	return pid->value;
}


-(void)updatePeakForInterval:(tPeakDataType)ty intervalIndex:(int)pi value:(float)v atActiveTime:(NSTimeInterval)at startingGoodPoint:(int)gpidx
{
	tPeakIntervalData* pid = [self getPID:ty
							intervalIndex:pi];
	if (pid->value < v)
	{
		//printf("update pid [%0x] with v:%0.1f  at time:%0.1f\n", pid, v, at);
		pid->value = v;
		pid->activeTime = at;
		pid->startingGoodPointIndex = gpidx;
	}
}


-(void)calcPeaksForType:(tPeakDataType)pdt dataSel:(SEL)dsel
{
	int dur = [self movingDuration];
	tInterpData* interpPwrData = [self createInterpolatedData:dsel];
	if (interpPwrData)
	{
		int np = [Utils numPeakIntervals];
		for (int pi=0; pi<np; pi++)
		{
			int intervalSeconds = [Utils nthPeakInterval:pi];
			for (int n=0; n<(dur-intervalSeconds); n++)
			{
				float sum = 0.0;
				for (int i=0; i<intervalSeconds; i++)
				{
					sum += interpPwrData[n+i].mData;
				}
				[self updatePeakForInterval:pdt
							  intervalIndex:pi
									  value:sum/intervalSeconds
							   atActiveTime:n
						  startingGoodPoint:interpPwrData[n].mGoodPointIdx];
			}
		}
		free(interpPwrData);
	}
}


-(void)calcPeaks
{
	if (!peakIntervalData)
	{
		int numIntervals = [Utils numPeakIntervals];
		int numPeakDataTypes = [Utils numPeakDataTypes];
		peakIntervalData = (tPeakIntervalData*)calloc(numIntervals * numPeakDataTypes, sizeof(tPeakIntervalData));
		if (peakIntervalData)
		{
			for (int dt=0; dt<numPeakDataTypes; dt++)
			{
				if ((dt == kPDT_Power) && ([self hasDevicePower] || (FLAG_IS_SET(flags, kPowerDataCalculatedOrZeroed)))) 
					[self calcPeaksForType:kPDT_Power
								   dataSel:@selector(power)];
			}
		}
	}
}


//------------------------------------------------------------------------------

static tAttribute sAttributesInCSVHeader[] = 
{
	kDisposition,
	kEffort,
	kEventType,
	kWeather,
	kEquipment,
	kWeight,
	kKeyword1,
	kKeyword2,
};   


-(NSString*) formatDeltaIntervalAsString:(NSTimeInterval)delta
{
	int hours = (int)delta/3600;
	int mins = (int)(delta/60.0) % 60;
	int secs = (int)delta % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
}




-(NSString*) buildTextOutput:(char)sep
{
	NSMutableString* s = [NSMutableString stringWithCapacity:4000];
	int timeFormat = [Utils intFromDefaults:RCBDefaultTimeFormat];
	NSString* dt;
	NSDate* startTime = [self creationTime];
	NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[self secondsFromGMT]];
	if (timeFormat == 0)
    {
#if 0
        dt = [startTime
              descriptionWithCalendarFormat:@"%A, %B %d, %Y at %I:%M%p"
              timeZone:tz
              locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
#else
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.timeZone = tz;
        fmt.locale   = [NSLocale currentLocale];
        [fmt setLocalizedDateFormatFromTemplate:@"EEEE MMMM dd yyyy hhmm a"];
        dt = [fmt stringFromDate:startTime];
#endif
        
	}
	else
	{
#if 0
        dt = [startTime
	descriptionWithCalendarFormat:@"%A, %B %d, %Y at %H:%M"
						 timeZone:tz 
						   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
#else
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.timeZone = tz;
        fmt.locale   = [NSLocale currentLocale];
        [fmt setLocalizedDateFormatFromTemplate:@"EEEE MMMM dd yyyy hhmm a"];
        dt = [fmt stringFromDate:startTime];
#endif
	}
	[s appendString:[NSString stringWithFormat:@"REPORT:%cAscent Activity Data\n", sep]];
	[s appendString:[NSString stringWithFormat:@"ACTIVITY DATE:%c%@\n", sep, dt]];
	int numAttrs = sizeof(sAttributesInCSVHeader)/sizeof(tAttribute);
	for (int a=0; a<numAttrs; a++)
	{
		NSString* as = [Utils attributeName:sAttributesInCSVHeader[a]];
		[s appendString:[NSString stringWithFormat:@"%@:%c%@\n", [as uppercaseString], sep, [self attribute:sAttributesInCSVHeader[a]]]];
	}
	
	NSArray* pts = [self goodPoints];
	int numPts = (int)[pts count];
	[s appendString:[NSString stringWithFormat:@"Elapsed Time%cMovingTime%cDistance%cSpeed%cAltitude%cHeart Rate%cCadence%cPower%cGradient%cLatitude%cLongitude\n",
		sep, sep, sep, sep, sep, sep, sep, sep, sep, sep]];
	for (int p=0; p<numPts; p++)
	{
		TrackPoint* point = [pts objectAtIndex:p];
		if (point != nil)
		{
			//[s appendString:[self formatDateIntervalAsString:[point date] startDate:[track creationTime]]];
			[s appendString:[self formatDeltaIntervalAsString:[point wallClockDelta]]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			//[s appendString:[self formatDateIntervalAsString:[point activeTime] startDate:[track creationTime]]];
			[s appendString:[self formatDeltaIntervalAsString:[point activeTimeDelta]]]      ;
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.2f",[Utils convertDistanceValue:[point distance]]]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.1f",[Utils convertSpeedValue:[point speed]]]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.1f",[Utils convertClimbValue:[point altitude]]]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.0f", [point heartrate] ]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.0f", [point cadence] ]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.0f", [point power] ]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.1f", [point gradient] ]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.4f", [point latitude] ]];
			[s appendString:[NSString stringWithFormat:@"%c", sep]];
			[s appendString:[NSString stringWithFormat:@"%1.4f", [point longitude] ]];
			[s appendString:@"\n"];
		}
	}
	return s;
}


-(BOOL)uploadToMobile
{
	return FLAG_IS_SET(flags, kUploadToMobile);
}


-(void)setUploadToMobile:(BOOL)up
{
	if (up)
	{
		SET_FLAG(flags, kUploadToMobile);
	}
	else
	{
		CLEAR_FLAG(flags, kUploadToMobile);
	}
}



//--------------------------------------------------------------------------------
//---- OverrideData methods

- (void) setOverrideValue:(tStatType)stat index:(int)idx value:(float)v
{
	[overrideData setValue:stat
					 index:idx
					 value:v];
}


- (float) overrideValue:(tStatType)stat index:(int)idx
{
    return [overrideData value:stat index:idx];
}


- (void) clearOverride:(tStatType)stat
{
	return [overrideData clearOverride:stat];
}


- (BOOL) isOverridden:(tStatType)stat
{
	return [overrideData isOverridden:stat];
}

- (OverrideData*) overrideData
{
    return overrideData;
}


//--------------------------------------------------------------------------------

//--------------------------------------------------------------------------------
//----- Animation control --------------------------------

- (void) setAnimTime:(NSTimeInterval)at
{
   animTime = at;
}


- (NSTimeInterval) animTime
{
   return animTime;
}

- (void) setAnimIndex:(int)idx
{
   animIndex = idx;
}


- (int) animIndex
{
   return animIndex;
}


@end
