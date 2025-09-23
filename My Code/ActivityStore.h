//
//  ActivityStore.h
//  Ascent
//

#import "DatabaseDefs.h"
#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class Track;
@class ColumnInfo;
@class DatabaseManager;   // <-- NEW (forward-declare; no hard import)

NS_ASSUME_NONNULL_BEGIN

@interface ActivityStore : NSObject {
@private
    // implementation details are in .m
    sqlite3 *_db;
    NSURL    *_url;
    BOOL      _ownsDB;
}

- (instancetype)initWithDatabaseManager:(DatabaseManager * _Nullable)dbm;

- (BOOL)createSchemaIfNeeded:(NSError **)error;

// MARK: - Meta
- (BOOL)saveMetaWithTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable)tableInfoDict
              splitsTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable)splitsTableInfoDict
                         uuid:(NSString * _Nullable)uuid
                    startDate:(NSDate   * _Nullable)startDate
                      endDate:(NSDate   * _Nullable)endDate
                 lastSyncTime:(NSDate   * _Nullable)lastSyncTime
                        flags:(NSInteger)flags
                  totalTracks:(NSInteger)totalTracks
                         int3:(NSInteger)i3
                         int4:(NSInteger)i4
                        error:(NSError * _Nullable * _Nullable)error;

- (BOOL)loadMetaTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable * _Nullable)outTableInfo
          splitsTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable * _Nullable)outSplitsTableInfo
                     uuid:(NSString * _Nullable * _Nullable)outUuid
                startDate:(NSDate * _Nullable * _Nullable)outStartTime
                  endDate:(NSDate * _Nullable * _Nullable)outEndTime
             lastSyncTime:(NSDate * _Nullable * _Nullable)outLastSyncTime
                    flags:(NSInteger * _Nullable)outFlags
              totalTracks:(NSInteger * _Nullable)outTotalTracks
                     int3:(NSInteger * _Nullable)outI3
                     int4:(NSInteger * _Nullable)outI4
                    error:(NSError * _Nullable * _Nullable)error;

// MARK: - Tracks
- (BOOL)saveTrack:(Track *)track error:(NSError * _Nullable * _Nullable)error;

- (BOOL)saveAllTracks:(NSArray<Track *> *)tracks
                error:(NSError * _Nullable * _Nullable)error
        progressBlock:(ASProgress _Nullable)progress;

- (NSArray<Track *> *)loadAllTracks:(NSError * _Nullable * _Nullable)error
                       totalTracks:(NSInteger)tt
                    progressBlock:(ASProgress _Nullable)progress;

- (BOOL)trackIDForTrack:(Track *)track
                  outID:(sqlite3_int64 *)outID
                  error:(NSError **)error;

- (BOOL)ensureActivityRowForTrack:(Track *)track
                         outTrackID:(int64_t *)outID
                              error:(NSError **)error;

- (BOOL)deleteTracks:(NSArray<Track *> *)tracks
               error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
