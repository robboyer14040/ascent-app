//
//  IdentifierStore.h
//  Ascent
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class DatabaseManager;

NS_ASSUME_NONNULL_BEGIN

@interface IdentifierStore : NSObject {
@private
    DatabaseManager *_dbm; // assign
}

- (instancetype)initWithDatabaseManager:(DatabaseManager *)dbm;

// Schema
- (BOOL)createSchemaIfNeeded:(NSError **)error;

// Map external id <-> track
- (BOOL)linkExternalID:(NSString *)externalID
                source:(NSString *)source
             toTrackID:(int64_t)trackID
                 error:(NSError **)error;

- (BOOL)lookupTrackIDForSource:(NSString *)source
                    externalID:(NSString *)externalID
                   outTrackID:(int64_t *_Nullable)outTrackID
                         error:(NSError **)error;

- (BOOL)unlinkExternalID:(NSString *)externalID
                  source:(NSString *)source
                   error:(NSError **)error;

- (NSArray<NSDictionary<NSString*, NSString*>*> *)identifiersForTrackID:(int64_t)trackID
                                                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
