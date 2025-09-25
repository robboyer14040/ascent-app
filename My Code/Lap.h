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

/// Storage as properties (replaces public ivars)
@property (nonatomic, assign) int             index;
@property (nonatomic, copy)   NSDate         *origStartTime;
@property (nonatomic, assign) NSTimeInterval  startTimeDelta;      // wall-clock delta from track start
@property (nonatomic, assign) NSTimeInterval  totalTime;           // wall-clock seconds in lap
@property (nonatomic, assign) NSTimeInterval  deviceTotalTime;     // device-reported active time

@property (nonatomic, assign) float           distance;            // miles
@property (nonatomic, assign) float           maxSpeed;            // mph
@property (nonatomic, assign) float           avgSpeed;            // mph

@property (nonatomic, assign) float           beginLatitude;
@property (nonatomic, assign) float           beginLongitude;
@property (nonatomic, assign) float           endLatitude;
@property (nonatomic, assign) float           endLongitude;

@property (nonatomic, assign) int             averageHeartRate;
@property (nonatomic, assign) int             maxHeartRate;
@property (nonatomic, assign) int             averageCadence;
@property (nonatomic, assign) int             maxCadence;

@property (nonatomic, assign) int             calories;
@property (nonatomic, assign) int             intensity;
@property (nonatomic, assign) int             triggerMethod;

// don't care about during copy/paste, drag/drop, etc
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign) BOOL            statsCalculated;     // computation complete flag


// MARK: – Designated initializer
- (id)initWithGPSData:(int)index
startTimeSecsSince1970:(time_t)sts
             totalTime:(unsigned int)tt
         totalDistance:(float)td       // METERS in
              maxSpeed:(float)ms       // METERS/SEC in
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

// Used during decode of legacy data
+ (void)resetStartTime:(NSDate *)startTime;

// Copying
- (id)mutableCopyWithZone:(NSZone *)zone;
- (id)copyWithZone:(NSZone *)zone;

// Convenience & utilities (public API preserved)
- (int)lapIndex;
- (NSComparisonResult)compareByOrigStartTime:(Lap *)anotherLap;
- (NSComparisonResult)reverseCompareByOrigStartTime:(Lap *)anotherLap; // DESC order
- (NSTimeInterval)startingWallClockTimeDelta;  // kept for source compatibility
- (void)setStartingWallClockTimeDelta:(NSTimeInterval)std;
- (NSString *)durationAsString;
- (BOOL)isDeltaTimeDuringLap:(NSTimeInterval)delta;
- (BOOL)isOrigDateDuringLap:(NSDate *)d;

// Stats access (C-array remains method-based)
- (struct tStatData *)getStat:(int)type;
- (struct tStatData *)getStatArray;

@end
