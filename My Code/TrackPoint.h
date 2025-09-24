//
//  TrackPoint.h
//  TLP
//
//  Created by Rob Boyer on 7/13/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Foundation/Foundation.h>
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
    kImportFlagDeadZoneMarker,      // entire point was synthesized during import but not in import data
    kImportFlagHasFootpod,
    // add new items here and adjust kMissingImportFlags mask and DATA_ITEM_TO_FLAG macro if necessary!
};


NS_ASSUME_NONNULL_BEGIN

@interface TrackPoint : NSObject <NSSecureCoding, NSCopying, NSMutableCopying>

@property (nonatomic) NSTimeInterval wallClockDelta;
@property (nonatomic) NSTimeInterval activeTimeDelta;
@property (nonatomic) float latitude;
@property (nonatomic) float longitude;
@property (nonatomic) float altitude;
@property (nonatomic) float origAltitude;
@property (nonatomic) float heartrate;
@property (nonatomic) float cadence;
@property (nonatomic) float temperature;
@property (nonatomic) float speed;
@property (nonatomic) float power;
@property (nonatomic) float origDistance;
@property (nonatomic) float distance;
@property (nonatomic) float gradient;
@property (nonatomic) float climbSoFar;
@property (nonatomic) float descentSoFar;
@property (nonatomic) int flags;
@property (nonatomic) BOOL validLatLon;

+ (void) resetStartTime:(NSDate*)startTime;         // for use in converting old point data that had dates instead of delta times

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

- (id)initWithDeadZoneMarker:(NSTimeInterval)wallClockDelta     activeTimeDelta:(NSTimeInterval)activeTimeDelta;
- (id)mutableCopyWithZone:(NSZone * _Nullable)zone;

- (void)setLatitude:(float)l;
- (void)setLongitude:(float)l;
- (float)pace;
- (float)power;
- (void)setPower:(float)p;
- (void)setCalculatedPower:(float)p;
- (BOOL)powerIsCalculated;
- (void)setDistance:(float)d;       // set calculated distance
- (BOOL)validAltitude;
- (BOOL)validDistance;
- (BOOL)validOrigDistance;
- (BOOL)validHeartrate;
- (BOOL)isDeadZoneMarker;
- (BOOL)speedOverridden;
- (void)setSpeedOverriden:(BOOL)set;
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

- (BOOL)importFlagState:(int)item;
- (void)setImportFlagState:(int)item state:(BOOL)missing;
- (BOOL)beginningOfDeadZone;
- (BOOL)setBeginningOfDeadZone;
- (BOOL)endOfDeadZone;
- (BOOL)setEndOfDeadZone;

@end

NS_ASSUME_NONNULL_END
