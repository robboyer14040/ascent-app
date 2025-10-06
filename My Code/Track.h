//
//  Track.h
//  TLP
//
//  Created by Rob Boyer on 7/11/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "StatDefs.h"
#import "Defs.h"


enum
{
   kValidSpeedMax = 54,
   kValidHRMax    = 190,      // fixme make this a preference
};

enum
{
    kDirtyNone     = 0,
    kDirtyMeta     = 1 << 0, // activity row (name/notes/flags/etc.)
    kDirtyLaps     = 1 << 1, // laps array changed
    kAllDirty      = 0xffff,
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
@class PathMarker;

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

// properties that should be part of copy/paste, drag/drop, etc
@property(nonatomic, retain) NSString* uuid;
@property(nonatomic, retain) NSString* name;
@property(nonatomic, retain) NSNumber* stravaActivityID;
@property(nonatomic, retain) NSDate* creationTime;
@property(nonatomic, retain) NSMutableArray<TrackPoint*>* points;
@property(nonatomic, retain) NSMutableArray<NSString*>* attributes;
@property(nonatomic, retain) NSMutableArray<PathMarker*>* markers;
@property(nonatomic, retain) NSMutableArray<Lap*>* laps;

@property(nonatomic) NSTimeInterval deviceTotalTime;
@property(nonatomic) int firmwareVersion;
@property(nonatomic) float minGradientDistance;
@property(nonatomic) BOOL movingSpeedOnly;
@property(nonatomic, retain) NSDate* creationTimeOverride;
@property(nonatomic, assign) float weight;
@property(nonatomic, assign) float altitudeSmoothingFactor;
@property(nonatomic, assign) int secondsFromGMT;
@property(nonatomic, assign) int flags;
@property(nonatomic, assign) int deviceID;
@property(nonatomic, retain) NSArray<NSString*> *localMediaItems;  // array of filenames, stored somewhere locally
// items from track source - used if points not available, stored persistently
@property(nonatomic) float srcDistance;
@property(nonatomic) float srcMaxSpeed;
@property(nonatomic) float srcAvgHeartrate;
@property(nonatomic) float srcMaxHeartrate;
@property(nonatomic) float srcAvgTemperature;
@property(nonatomic) float srcMaxElevation;
@property(nonatomic) float srcMinElevation;
@property(nonatomic) float srcAvgPower;
@property(nonatomic) float srcMaxPower;
@property(nonatomic) float srcAvgCadence;
@property(nonatomic) float srcTotalClimb;
@property(nonatomic) float srcKilojoules;
@property(nonatomic) NSTimeInterval srcElapsedTime;
@property(nonatomic) NSTimeInterval srcMovingTime;
@property(nonatomic, retain) NSString* timeZoneName;

// properties we don't care about during copy/paste, drag/drop, etc
@property(nonatomic, retain) OverrideData* overrideData;    // maybe someday
@property(nonatomic, assign) float distance;
@property(nonatomic) BOOL hasDistanceData;
@property(nonatomic, retain) NSArray* equipmentUUIDs;
@property(nonatomic, retain) NSString* mainEquipmentUUID;
@property(nonatomic, retain) NSArray<NSURL *> *photoURLs;  // vestigial?? FIXME
@property(nonatomic, retain) NSMutableArray* lapInfoArray;
@property(nonatomic, assign) BOOL pointsEverSaved;     // mirrors activities.points_saved
@property(nonatomic, assign) int  pointsCount;         // number of points loaded
@property(nonatomic, assign) uint32_t dirtyMask;       // meta bits, laps bits, etc.
@property(nonatomic, assign) NSTimeInterval animTime;
@property(nonatomic, assign) int animIndex;
@property(nonatomic) int animID;
@property(nonatomic) NSTimeInterval animTimeBegin;
@property(nonatomic) NSTimeInterval animTimeEnd;
@property(nonatomic) float equipmentWeight;


- (NSComparisonResult) comparator:(Track*)track;
-(void) doFixupAndCalcGradients;

// use device lap data for lame devices like the 310xt that give ambiguous 
// point data that is difficult to process
-(BOOL)usingDeviceLapData;
-(void)setUseDeviceLapData:(BOOL)use;

- (id)mutableCopyWithZone:(NSZone *)zone;

- (void) setOverrideValue:(tStatType)stat index:(int)idx value:(float)v;
- (float) overrideValue:(tStatType)stat index:(int)idx;
- (void) clearOverride:(tStatType)idx;
- (BOOL) isOverridden:(tStatType)idx;

- (BOOL) hasDevicePower;
- (void) setHasDevicePower:(BOOL)has;
- (BOOL) hasCadence;
- (void) setHasCadence:(BOOL)has;

- (BOOL)hasElevationData;
- (BOOL)hasLocationData;

- (void)clearCreationTimeOverride;

- (int)secondsFromGMT;
- (void)setSecondsFromGMT:(int)value;

- (NSComparisonResult) compareByDate:(Track*)anotherTrack;
- (NSComparisonResult) compareByMovingDuration:(Track*)anotherTrack;

- (float)distance;
- (void)setDistance:(float)d;

- (void) setAttribute:(int)attr usingString:(NSString*)s;
- (NSString*) attribute:(int)attr;

- (void)setPoints:(NSMutableArray<TrackPoint*>*)p;
- (void)setPointsAndAdjustTimeDistance:(NSMutableArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset;

- (void)setLaps:(NSMutableArray<Lap*> *)l;

- (NSTimeInterval)duration;
- (NSString *)durationAsString;
                                
- (NSTimeInterval)movingDuration;
- (NSString *)movingDurationAsString;
- (NSTimeInterval)movingDurationBetweenGoodPoints:(int)sidx end:(int)eidx;

- (BOOL)isDateDuringTrack:(NSDate*)d;

- (void)addLapInFront:(Lap*)lap;

- (Lap*)addLap:(NSTimeInterval)atActiveTimeDelta;
- (BOOL)deleteLap:(Lap*)lap;

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

-(void)calculatePower;
-(void)setEnableCalculationOfPower:(BOOL)en;
-(BOOL)calculationOfPowerEnabled;
-(BOOL)activityIsValidForPowerCalculation;

- (void)calculateTrackStats;
- (void)calculateStats:(struct tStatData*)sArray startIdx:(int)startingGoodIdx endIdx:(int)endingGoodIdx;
- (void)calcGradients;

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

-(BOOL)uploadToMobile;
-(void)setUploadToMobile:(BOOL)up;

-(float)peakForIntervalType:(tPeakDataType)ty intervalIndex:(int)pi peakStartTime:(NSTimeInterval*)pst startingGoodPointIndex:(int*)sgpi;

-(void)setStaleEquipmentAttr:(BOOL)v;
-(BOOL)staleEquipmentAttr;
-(BOOL)hasExplicitDeadZones;
-(void)setHasExplicitDeadZones:(BOOL)has;
-(void)setHasDeviceTime:(BOOL)has;
-(void)loadPoints:(NSURL*)docURL;
@end
