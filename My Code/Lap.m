//
//  Lap.mm
//  TLP
//
//  Created by Rob Boyer on 7/31/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "Defs.h"
#import "Lap.h"

static NSDate *sTrackStartTime = nil;

// Private state: C-array and any impl-only bits that cannot be properties.
@interface Lap ()
{
    struct tStatData _statsArray[kST_NumStats];
}
@end


@implementation Lap


- (id)initWithGPSData:(int)idx
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
    if (self) {
        _index = idx;
        self.origStartTime = [NSDate dateWithTimeIntervalSince1970:sts];
        _startTimeDelta = 0.0;
        _totalTime = (tt / 100); // matches legacy units
        _distance = td / 1609.344f; // meters -> miles
        _maxSpeed = (ms * 60.0f * 60.0f) / 1609.344f; // m/s -> mph

        _beginLatitude  = blat;
        _beginLongitude = blon;
        _endLatitude    = elat;
        _endLongitude   = elon;

        _calories          = (int)cals;
        _averageHeartRate  = ahr;
        _maxHeartRate      = mhr;
        _averageCadence    = acd;
        _intensity         = inten;
        _triggerMethod     = tm;

        _statsCalculated   = NO;
        _deviceTotalTime   = 0.0;
    }
    return self;
}


- (id)init
{
    return [self initWithGPSData:0
         startTimeSecsSince1970:0
                      totalTime:0
                  totalDistance:0.0f
                       maxSpeed:0.0f
                       beginLat:180.0f
                       beginLon:180.0f
                         endLat:180.0f
                         endLon:180.0f
                       calories:0
                          avgHR:0
                          maxHR:0
                          avgCD:0
                       intensity:0
                         trigger:0];
}


- (void)dealloc
{
    [_origStartTime release];
    [super dealloc];
}


- (id)doCopy:(NSZone *)zone
{
    Lap *newLap = [[Lap allocWithZone:zone] init];

    newLap.index             = _index;
    newLap.origStartTime     = _origStartTime;     // property copies; MRC-safe
    newLap.startTimeDelta    = _startTimeDelta;
    newLap.totalTime         = _totalTime;
    newLap.deviceTotalTime   = _deviceTotalTime;

    newLap.distance          = _distance;
    newLap.maxSpeed          = _maxSpeed;
    newLap.avgSpeed          = _avgSpeed;

    newLap.beginLatitude     = _beginLatitude;
    newLap.beginLongitude    = _beginLongitude;
    newLap.endLatitude       = _endLatitude;
    newLap.endLongitude      = _endLongitude;

    newLap.averageHeartRate  = _averageHeartRate;
    newLap.maxHeartRate      = _maxHeartRate;
    newLap.averageCadence    = _averageCadence;
    newLap.maxCadence        = _maxCadence;

    newLap.calories          = _calories;
    newLap.intensity         = _intensity;
    newLap.triggerMethod     = _triggerMethod;

    newLap.statsCalculated   = _statsCalculated;
    newLap.selected          = _selected;

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


+ (void)resetStartTime:(NSDate *)startTime
{
    // Matches legacy behavior (no retain/copy). Adjust if you prefer ownership.
    sTrackStartTime = startTime;
}


#define DEBUG_DECODE 0
#define CUR_VERSION  2

- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
    printf("decoding Lap\n");
#endif
    self = [super init];
    if (!self) {
        return nil;
    }

    _statsCalculated = NO;

    int version = 0;
    float spareFloat = 0.0f;
    int spareInt = 0;

    [coder decodeValueOfObjCType:@encode(int) at:&version];

    if (version > CUR_VERSION) {
        NSException *e = [NSException exceptionWithName:ExFutureVersionName
                                                 reason:ExFutureVersionReason
                                               userInfo:nil];
        @throw e;
    }

    self.origStartTime = [coder decodeObject];

    if (version < 2) {
        _startTimeDelta = [_origStartTime timeIntervalSinceDate:sTrackStartTime];
    } else {
        [coder decodeValueOfObjCType:@encode(double) at:&_startTimeDelta];
    }

    [coder decodeValueOfObjCType:@encode(long long) at:&_totalTime];
    [coder decodeValueOfObjCType:@encode(float) at:&_beginLatitude];
    [coder decodeValueOfObjCType:@encode(float) at:&_beginLongitude];
    [coder decodeValueOfObjCType:@encode(float) at:&_endLatitude];
    [coder decodeValueOfObjCType:@encode(float) at:&_endLongitude];
    [coder decodeValueOfObjCType:@encode(float) at:&_distance];
    [coder decodeValueOfObjCType:@encode(float) at:&_maxSpeed];
    [coder decodeValueOfObjCType:@encode(float) at:&_avgSpeed];
    [coder decodeValueOfObjCType:@encode(float) at:&_deviceTotalTime];   // 1.11.5 BETA 9
    [coder decodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder decodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder decodeValueOfObjCType:@encode(int)   at:&_averageHeartRate];
    [coder decodeValueOfObjCType:@encode(int)   at:&_maxHeartRate];
    [coder decodeValueOfObjCType:@encode(int)   at:&_averageCadence];
    [coder decodeValueOfObjCType:@encode(int)   at:&_intensity];
    [coder decodeValueOfObjCType:@encode(int)   at:&_triggerMethod];
    [coder decodeValueOfObjCType:@encode(int)   at:&_calories];
    [coder decodeValueOfObjCType:@encode(int)   at:&_maxCadence];
    [coder decodeValueOfObjCType:@encode(int)   at:&spareInt];
    [coder decodeValueOfObjCType:@encode(int)   at:&spareInt];
    [coder decodeValueOfObjCType:@encode(int)   at:&spareInt];

    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    int version = CUR_VERSION;
    float spareFloat = 0.0f;
    int spareInt = 0;

    [coder encodeValueOfObjCType:@encode(int) at:&version];
    [coder encodeObject:_origStartTime];
    [coder encodeValueOfObjCType:@encode(double)     at:&_startTimeDelta];
    [coder encodeValueOfObjCType:@encode(long long)  at:&_totalTime];
    [coder encodeValueOfObjCType:@encode(float)      at:&_beginLatitude];
    [coder encodeValueOfObjCType:@encode(float)      at:&_beginLongitude];
    [coder encodeValueOfObjCType:@encode(float)      at:&_endLatitude];
    [coder encodeValueOfObjCType:@encode(float)      at:&_endLongitude];
    [coder encodeValueOfObjCType:@encode(float)      at:&_distance];
    [coder encodeValueOfObjCType:@encode(float)      at:&_maxSpeed];
    [coder encodeValueOfObjCType:@encode(float)      at:&_avgSpeed];
    [coder encodeValueOfObjCType:@encode(float)      at:&_deviceTotalTime];    // 1.11.5 BETA 9
    [coder encodeValueOfObjCType:@encode(float)      at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(float)      at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(int)        at:&_averageHeartRate];
    [coder encodeValueOfObjCType:@encode(int)        at:&_maxHeartRate];
    [coder encodeValueOfObjCType:@encode(int)        at:&_averageCadence];
    [coder encodeValueOfObjCType:@encode(int)        at:&_intensity];
    [coder encodeValueOfObjCType:@encode(int)        at:&_triggerMethod];
    [coder encodeValueOfObjCType:@encode(int)        at:&_calories];
    [coder encodeValueOfObjCType:@encode(int)        at:&_maxCadence];
    [coder encodeValueOfObjCType:@encode(int)        at:&spareInt];
    [coder encodeValueOfObjCType:@encode(int)        at:&spareInt];
    [coder encodeValueOfObjCType:@encode(int)        at:&spareInt];
}


- (NSTimeInterval)startingWallClockTimeDelta
{
    return _startTimeDelta;
}


- (void)setStartingWallClockTimeDelta:(NSTimeInterval)std
{
    _startTimeDelta = std;
}


- (NSString *)durationAsString
{
    NSTimeInterval dur = _totalTime;
    int hours = (int)(dur / 3600.0);
    int mins  = (int)(dur / 60.0) % 60;
    int secs  = (int)dur % 60;
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
}


- (NSComparisonResult)compareByOrigStartTime:(Lap *)anotherLap
{
    return [_origStartTime compare:anotherLap.origStartTime];
}


- (NSComparisonResult)reverseCompareByOrigStartTime:(Lap *)anotherLap
{
    return [anotherLap.origStartTime compare:_origStartTime];
}


- (BOOL)isOrigDateDuringLap:(NSDate *)d
{
    NSDate *endDate = [NSDate dateWithTimeInterval:_totalTime sinceDate:_origStartTime];

    BOOL isLessThan = ([d compare:_origStartTime] == NSOrderedAscending);
    BOOL isGreaterThan = ([d compare:endDate] == NSOrderedDescending);

    return ((isLessThan == NO) && (isGreaterThan == NO));
}


- (BOOL)isDeltaTimeDuringLap:(NSTimeInterval)delta
{
    return IS_BETWEEN(_startTimeDelta, delta, (_startTimeDelta + _totalTime));
}


- (int)lapIndex
{
    return _index;
}


- (NSComparisonResult)compare:(id)lap2
{
    NSTimeInterval lap2Delta = [lap2 startingWallClockTimeDelta];

    if (_startTimeDelta < lap2Delta) {
        return NSOrderedAscending;
    } else if (_startTimeDelta == lap2Delta) {
        return NSOrderedSame;
    }

    return NSOrderedDescending;
}


- (struct tStatData *)getStat:(int)type
{
    return &_statsArray[type];
}


- (struct tStatData *)getStatArray
{
    return _statsArray;
}


@end
