//
//  DatabaseManager.h
//  Ascent
//
//  Created by Rob Boyer on 9/6/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DBErrorBlock)(NSError *error);
typedef void (^DBVoidBlock)(void);



@interface DatabaseManager : NSObject {
@private
    NSURL *_databaseURL;
    sqlite3 *_db;
    dispatch_queue_t _writeQueue;
    BOOL _isOpen;
}

// Designated initializer
- (instancetype)initWithURL:(NSURL *)dbURL;
- (instancetype)initWithURL:(NSURL *)dbURL readOnly:(BOOL)ro;

// Open/close (open sets WAL, synchronous, foreign_keys)
- (BOOL)open:(NSError **)error;
- (void)close;

// Accessors
@property (nonatomic, readonly) NSURL *databaseURL;
@property (nonatomic, readonly) dispatch_queue_t writeQueue;
@property (nonatomic, readonly) dispatch_queue_t readQueue;   // NEW
@property(nonatomic, readonly) BOOL readOnly;


- (sqlite3 *)rawSQLite; // use only on writeQueue
- (BOOL)isOnWriteQueue;

// Queue helpers
- (void)performSyncOnWriteQueue:(DBVoidBlock)block;
- (void)performWrite:(void (^)(sqlite3 *db, DBErrorBlock fail))block
          completion:(void (^_Nullable)(NSError *_Nullable error))completion;
- (void)performRead:(void (^)(sqlite3 *db))block
         completion:(void (^_Nullable)(void))completion;
- (void)performReadSync:(void (^)(sqlite3 *db))block;

// Maintenance
- (BOOL)checkpointTruncate:(NSError **)error;
- (BOOL)exportSnapshotToURL:(NSURL *)destURL error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
