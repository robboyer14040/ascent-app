//
//  ActivityStore.h
//  Ascent
//
//  Created by Rob Boyer on 8/20/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class Track;
@class ColumnInfo;

NS_ASSUME_NONNULL_BEGIN

@interface ActivityStore : NSObject
- (instancetype)initWithURL:(NSURL *)dbURL;
- (BOOL)open:(NSError **)error;
- (void)close;

/// Create/upgrade schema. Safe to call every launch.
- (BOOL)createSchema:(NSError **)error;

/// Upsert a Track (replaces laps/points for that uuid). Also stores Track.attributes / Track.markers / Track.overrideData as JSON in the track row.
- (BOOL)saveTrack:(Track *)track error:(NSError **)error;

- (BOOL)saveAllTracks:(NSArray<Track *> *)tracks error:(NSError **)error;

- (BOOL)saveMetaWithTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)tableInfoDict
              splitsTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)splitsTableInfoDict
                         uuid:(NSString*)uuid
                    startDate:(NSDate *)startTime
                      endDate:(NSDate *)endTime
                        flags:(NSInteger)flags
                         int2:(NSInteger)i2
                         int3:(NSInteger)i3
                         int4:(NSInteger)i4
                        error:(NSError **)error;


- (BOOL)loadMetaTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable __autoreleasing * _Nullable)outTableInfo
          splitsTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable __autoreleasing * _Nullable)outSplitsTableInfo
                     uuid:(NSString * _Nullable __autoreleasing * _Nullable)outUuid
                startDate:(NSDate * _Nullable __autoreleasing * _Nullable)outStartTime
                  endDate:(NSDate * _Nullable __autoreleasing * _Nullable)outEndTime
                    flags:(NSInteger * _Nullable)outFlags
                     int2:(NSInteger * _Nullable)outI2
                     int3:(NSInteger * _Nullable)outI3
                     int4:(NSInteger * _Nullable)outI4
                    error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/// Load all tracks, each with laps, points, attributes, markers, overrideData
- (NSArray<Track *> *)loadAllTracks:(NSError **)error;

/// Load a single track by UUID (faster than loadAll)
- (nullable Track *)loadTrackWithUUID:(NSString *)uuid error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
