//
//  TrackPointStore.h
//  Ascent
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class DatabaseManager;
@class TrackPoint;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    int64_t  wall_clock_delta_s;
    int64_t  active_time_delta_s;
    float   latitude_e7;
    float   longitude_e7;
    float   orig_altitude_cm;
    float   heartrate_bpm;
    float   cadence_rpm;
    float   temperature_c10;
    float    speed_mps;
    float    power_w;
    float    orig_distance_m;
    uint32_t flags;
} TPRow;

@interface TrackPointStore : NSObject {
@private
    DatabaseManager *_dbm; // assign (non-owning)
}

- (instancetype)initWithDatabaseManager:(DatabaseManager *)dbm;

// Schema
- (BOOL)createSchemaIfNeeded:(NSError **)error;

// CRUD
- (BOOL)replacePointsForTrackID:(int64_t)trackID
                       fromRows:(const TPRow *)rows
                          count:(NSUInteger)count
                          error:(NSError **)error;

- (BOOL)deletePointsForTrackID:(int64_t)trackID
                         error:(NSError **)error;

- (BOOL)countForTrackID:(int64_t)trackID
               outCount:(int64_t *)count
                  error:(NSError **)error;

// Convenience loads
- (NSArray<TrackPoint *> * _Nullable)loadPointsForTrackUUID:(NSString *)uuid
                                                      error:(NSError * _Nullable * _Nullable)error;

- (NSArray<TrackPoint *> * _Nullable)loadPointsForTrackID:(int64_t)trackID
                                                    error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
