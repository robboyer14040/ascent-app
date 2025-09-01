//
//  Track.h
//  TLP
//
//  Created by Rob Boyer on 7/11/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//
///#warning USING Track.h from here


#import <Cocoa/Cocoa.h>
#import "StatDefs.h"
#import "Defs.h"
#import <objc/runtime.h>

enum
{
   kValidSpeedMax = 54,
   kValidHRMax    = 190,      // fixme make this a preference
};


struct tZoneData
{
   int            sidx, eidx;
   NSTimeInterval zoneTime;
};


struct tLatLonBounds
{
	float	minLat, minLon, maxLat, maxLon;
};

@class Lap;
@class TrackPoint;
@class OverrideData;

@interface LapInfo : NSObject
{
   Lap*				lap;
   int				startingPointIdx;
   int				numPoints;
   NSTimeInterval	activeTimeDelta;
}
- (id) initWithData:(Lap*)lap startIdx:(int)sp numPoints:(int)np;
- (int) numPoints;
- (int) startingPointIndex;
- (NSTimeInterval) activeTimeDelta;
@end


// flag definitions for Track 'flags' field
enum
{
	kUseOrigDistance			= 0x00000001,
	kOverrideCreationTime		= 0x00000002,
	kOverrideAltitudeSmoothing  = 0x00000004,
	kUploadToMobile				= 0x00000008,
	kHasDevicePowerData			= 0x00000010,	// has raw power data from a power meter, etc
	kUseDeviceLapData			= 0x00000020,	// 310xt, ...
    kHasDeviceTime				= 0x00000040,
	kPowerDataCalculatedOrZeroed= 0x00000100,	// no raw power data, but power has been calculated or zeroed
	kHasCadenceData				= 0x00000200,
	kEquipmentAttrStale			= 0x00000400,	// equipment attribute needs update from DB
	kDontCalculatePower			= 0x00000800,	// don't calculate power for this track when no device power
	kHasElevationData			= 0x00001000,	// track points have valid elevation data
	kHasLocationData			= 0x00002000,	// track points have valid location data
    kHasExplicitDeadZones       = 0x00100000,   // don't look for zero-speed zones, track uses dead zone markers
};


struct tPeakIntervalData
{
	float			value;
	NSTimeInterval	activeTime;
	int				startingGoodPointIndex;
};


@interface Track : NSObject <NSCoding, NSMutableCopying> 
{
	// fields that are stored persistently
	NSString*			uuid;
	NSDate*				creationTime;
	NSDate*				creationTimeOverride;		// if user has over-ridden original creationtime
	NSString*			name;
	NSMutableArray*		points;
	NSMutableArray*		attributes;
	///NSMutableArray*		laps;
	NSMutableArray*		markers;
	NSMutableArray*		goodPoints;
	float				distance;
	float				weight;
	float				altitudeSmoothingFactor;	
	float				equipmentWeight;
    ///NSTimeInterval      deviceTotalTime;                // for use when no data points; does NOT include stops
	int					secondsFromGMTAtSync;           // must be int!!!
	OverrideData*		overrideData;                   // only present if one or more data items have been overridden
	int					flags;
	int					deviceID;					
	///int					firmwareVersion;
	// temporary values, not stored persistently ------------------------
	tPeakIntervalData*	peakIntervalData;			// dimensioned numPeakDataTypes * numPeakIntervals (5sec, 10sec, 30sec, etc)
	NSArray*			equipmentUUIDs;	
	NSString*			mainEquipmentUUID;
	NSMutableArray*		lapInfoArray;
	struct tStatData	statsArray[kST_NumStats];
	///float				minGradientDistance;
	NSTimeInterval		animTime;
	///NSTimeInterval		animTimeBegin;
	///NSTimeInterval		animTimeEnd;
	int					animIndex;
	int					hrzCacheStart, hrzCacheEnd;
	int					nhrzCacheStart[kMaxZoneType+1], nhrzCacheEnd[kMaxZoneType+1];
	NSTimeInterval		cachedHRZoneTime[kNumHRZones];
	NSTimeInterval		cachedNonHRZoneTime[kMaxZoneType+1][kNumNonHRZones];
	///int					animID;
	BOOL				statsCalculated;
	///BOOL				movingSpeedOnly;
	///BOOL				hasDistanceData;
}

@property(nonatomic, retain) NSArray* equipmentUUIDs;
@property(nonatomic, retain) NSString* mainEquipmentUUID;
@property(nonatomic) float equipmentWeight;
@property(nonatomic) NSTimeInterval deviceTotalTime;
@property(nonatomic) int firmwareVersion;
@property(nonatomic) int animID;
@property(nonatomic) float minGradientDistance;
@property(nonatomic) NSTimeInterval animTimeBegin;
@property(nonatomic) NSTimeInterval animTimeEnd;
@property(nonatomic, retain) NSMutableArray* laps;
@property(nonatomic) BOOL movingSpeedOnly;
@property(nonatomic) BOOL hasDistanceData;

- (NSComparisonResult) comparator:(Track*)track;
-(void) doFixupAndCalcGradients;

-(int)deviceID;
-(void)setDeviceID:(int)devID;
-(float)altitudeSmoothingFactor;
-(void)setAltitudeSmoothingFactor:(float)v;

// use device lap data for lame devices like the 310xt that give ambiguous 
// point data that is difficult to process
-(BOOL)usingDeviceLapData;
-(void)setUseDeviceLapData:(BOOL)use;

- (id)mutableCopyWithZone:(NSZone *)zone;

- (OverrideData*) overrideData;
- (void) setOverrideValue:(tStatType)stat index:(int)idx value:(float)v;
- (float) overrideValue:(tStatType)stat index:(int)idx;
- (void) clearOverride:(tStatType)idx;
- (BOOL) isOverridden:(tStatType)idx;
- (void)setOverrideData:(OverrideData*)od;

- (BOOL) hasDevicePower;
- (void) setHasDevicePower:(BOOL)has;
- (BOOL) hasCadence;
- (void) setHasCadence:(BOOL)has;

- (BOOL)hasElevationData;
- (BOOL)hasLocationData;

- (NSDate *)creationTime;
- (void)setCreationTime:(NSDate *)t;

- (NSDate *)creationTimeOverride;
- (void)setCreationTimeOverride:(NSDate *)d;
- (void)clearCreationTimeOverride;

- (int)secondsFromGMTAtSync;
- (void)setSecondsFromGMTAtSync:(int)value;

- (NSComparisonResult) compareByDate:(Track*)anotherTrack;
- (NSComparisonResult) compareByMovingDuration:(Track*)anotherTrack;

- (NSString *)name;
- (void)setName:(NSString *)n;

- (int)flags;
- (void)setFlags:(int)f;

- (float)distance;
- (void)setDistance:(float)d;

- (void) setAttribute:(int)attr usingString:(NSString*)s;
- (NSString*) attribute:(int)attr;
- (void) setAttributes:(NSMutableArray *)arr;
- (NSMutableArray*) attributes;

- (NSMutableArray*)points;
- (void)setPoints:(NSMutableArray*)p;
-(void) setPointsAndAdjustTimeDistance:(NSMutableArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset;

- (NSMutableArray*)laps;
- (void)setLaps:(NSMutableArray*)l;

- (NSMutableArray*)markers;
- (void)setMarkers:(NSMutableArray*)m;

- (NSTimeInterval)duration;
- (NSString *)durationAsString;
                                
- (NSTimeInterval)movingDuration;
- (NSString *)movingDurationAsString;
- (NSTimeInterval)movingDurationBetweenGoodPoints:(int)sidx end:(int)eidx;

- (BOOL)isDateDuringTrack:(NSDate*)d;

- (void)addLapInFront:(Lap*)lap;

- (Lap*)addLap:(NSTimeInterval)atActiveTimeDelta;
- (BOOL)deleteLap:(Lap*)lap;

- (LapInfo*) getLapInfo:(Lap*)l;

// 'stat' returns calculated value from track points
- (float)stat:(tStatType)stat index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atd;		
- (float)statForLap:(Lap*)lap statType:(tStatType)stat index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atTime;
// 'statOrOverride' returns calculated value from track points, or override value if user has edited...
- (float)statOrOverride:(tStatType)stype index:(int)idx atActiveTimeDelta:(NSTimeInterval*)atd;
- (struct tStatData*)statsArray;
- (struct tStatData*) getStat:(int)type;

 
- (float)avgSpeed;
- (float)avgPace;
- (float)avgMovingPace;
- (float)avgMovingSpeed;
- (float)avgHeartrate;
- (float)avgHeartrateForLap:(Lap*)lap;
- (float)avgCadence;
- (float)avgCadenceForLap:(Lap*)lap;
- (float)avgPower;
- (float)avgPowerForLap:(Lap*)lap;
- (float)work;
- (float)workForLap:(Lap*)lap;
- (float)avgTemperature;
- (float)avgTemperatureForLap:(Lap*)lap;
- (float)avgGradient;
- (float)avgGradientForLap:(Lap*)lap;
- (float)maxSpeed;
- (float)maxSpeedForLap:(Lap*)lap  atActiveTimeDelta:(NSTimeInterval*)t;
- (float)maxSpeed:(NSTimeInterval*)atActiveTimeDelta;
- (float)minPace:(NSTimeInterval*)atActiveTimeDelta;
- (float)totalClimb;
- (float)totalDescent;
- (float)maxAltitude:(NSTimeInterval*)atActiveTimeDelta;
- (float)minAltitude:(NSTimeInterval*)atActiveTimeDelta;
- (float)avgAltitude;
- (float)maxAltitudeForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)minAltitudeForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)avgAltitudeForLap:(Lap*)lap;
- (float)maxHeartrate:(NSTimeInterval*)atActiveTimeDelta;
- (float)minHeartrate:(NSTimeInterval*)atActiveTimeDelta;
- (float)maxHeartrateForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)minHeartrateForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)maxGradient:(NSTimeInterval*)atActiveTimeDelta;
- (float)maxGradientForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)minGradient:(NSTimeInterval*)atActiveTimeDelta;
- (float)minGradientForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)maxTemperature:(NSTimeInterval*)atActiveTimeDelta;
- (float)maxTemperatureForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)minTemperature:(NSTimeInterval*)atActiveTimeDelta;
- (float)minTemperatureForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)maxCadence:(NSTimeInterval*)atActiveTimeDelta;
- (float)maxCadenceForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)maxPower:(NSTimeInterval*)atActiveTimeDelta;
- (float)maxPowerForLap:(Lap*)lap atActiveTimeDelta:(NSTimeInterval*)t;
- (float)calories;
- (float) minLatitude;
- (float) minLongitude;
- (float) maxLatitude;
- (float) maxLongitude;
- (tLatLonBounds) getLatLonBounds;

// other lap-related accessors
- (NSTimeInterval)lapActiveTimeDelta:(Lap*)lap;
- (float)durationAsFloat;							// wall-time
- (float)durationOfLap:(Lap*)lap;					// wall-time
- (NSString *)durationOfLapAsString:(Lap*)lap;		// wall-time
- (float)distanceOfLap:(Lap*)lap;
- (NSTimeInterval)movingDurationOfLap:(Lap*)lap;
- (NSString *)movingDurationForLapAsString:(Lap*)lap;
- (float)movingSpeedForLap:(Lap*)lap;
- (float)avgLapSpeed:(Lap*)lap;
- (float)caloriesForLap:(Lap*)lap;
- (NSDate*)lapStartTime:(Lap*)lap;		// this is in WALL CLOCK time
- (NSDate*)lapEndTime:(Lap*)lap;		// this is in WALL CLOCK time
- (int)lapIndexOfPoint:(TrackPoint*)pt;
- (BOOL)isTimeOfDayInLap:(Lap*)l tod:(NSDate*)tod;
- (float)lapClimb:(Lap*)lap;
- (float)lapDescent:(Lap*)lap;
- (int)findLapIndex:(Lap*)lap;
- (NSArray*)lapPoints:(Lap*)lap;
- (int)lapStartingIndex:(Lap*)lap;		// returns index in GOOD POINTS array!
- (void)calculateLapStats:(Lap*)lap;
-(void) copyOrigDistance;
-(BOOL) hasDistance;

- (float)weight;
- (void)setWeight:(float)w;

-(void)calculatePower;
-(void)setEnableCalculationOfPower:(BOOL)en;
-(BOOL)calculationOfPowerEnabled;
-(BOOL)activityIsValidForPowerCalculation;

- (void)calculateTrackStats;
- (void)calculateStats:(struct tStatData*)sArray startIdx:(int)startingGoodIdx endIdx:(int)endingGoodIdx;
- (void)calcGradients;

- (void) setAnimTime:(NSTimeInterval)at;
- (NSTimeInterval) animTime;
- (void) setAnimIndex:(int)idx;
- (int) animIndex;

- (NSTimeInterval)timeInHRZone:(int)zone;
- (NSTimeInterval)timeInHRZoneForInterval:(int)zone start:(int)sidx end:(int)eidx;
- (NSTimeInterval)timeLapInHRZone:(int)zone lap:(Lap*)lap;
- (NSTimeInterval)timeInNonHRZone:(int)type zone:(int)zone;
- (NSTimeInterval)timeInNonHRZoneForInterval:(int)type zone:(int)zone start:(int)sidx end:(int)eidx;
- (NSTimeInterval)timeLapInNonHRZone:(int)type zone:(int)zone lap:(Lap*)lap;
- (NSString*)timeInHRZoneAsString:(int)zone;
- (NSString*)timeInNonHRZoneAsString:(int)type zone:(int)zone;
- (void) fixupTrack;
- (NSMutableArray*) goodPoints;
- (int) findFirstGoodPointAtOrAfterDelta:(NSTimeInterval)time startAt:(int)idx;			// uses WALL time
- (int) findFirstGoodPointAtOrAfterActiveDelta:(NSTimeInterval)time startAt:(int)idx;	// uses MOVING time
- (int) findFirstPointAtOrAfterDelta:(NSTimeInterval)time startAt:(int)idx;   // does NOT use good points

- (int)findIndexOfFirstPointAtOrAfterActiveTimeDelta:(NSTimeInterval)atd;   // does NOT use good points

- (int)findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:(float)dist  startAt:(int)startIdx;	// DOES use good points


-(float) firstValidLatitude;
-(float) firstValidLongitude;
-(float) firstValidAltitude:(int)sidx;
-(float) lastValidAltitude:(int)eidx;
-(float) firstValidAltitudeUsingGoodPoints:(int)sidx;
-(float) firstValidDistance:(int)sidx;
-(float) lastValidDistance:(int)eidx;
- (float)lastValidDistanceUsingGoodPoints:(int)startIdx atIdx:(int*)atIdxPtr;
-(float) firstValidOrigDistance:(int)sidx;
-(TrackPoint*) closestPointToDistance:(float)distance;
- (NSTimeInterval)movingDurationForGraphs;
- (void)invalidateStats;

- (void) setUseOrigDistance:(BOOL)yn;
- (BOOL) useOrigDistance;

-(NSString*) buildTextOutput:(char)sep;
-(NSString*) uuid;
-(void) setUuid:(NSString*)uid;

-(BOOL)uploadToMobile;
-(void)setUploadToMobile:(BOOL)up;

-(float)peakForIntervalType:(tPeakDataType)ty intervalIndex:(int)pi peakStartTime:(NSTimeInterval*)pst startingGoodPointIndex:(int*)sgpi;

-(void)setStaleEquipmentAttr:(BOOL)v;
-(BOOL)staleEquipmentAttr;
-(BOOL)hasExplicitDeadZones;
-(void)setHasExplicitDeadZones:(BOOL)has;
-(void)setHasDeviceTime:(BOOL)has;

@end
