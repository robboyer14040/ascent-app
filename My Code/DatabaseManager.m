//
//  DatabaseManager.m
//  Ascent
//
//  Created by Rob Boyer on 9/6/25.
//  Updated: clear authorizer after open and probe with SELECT 1
//

#import "DatabaseManager.h"
#import <sqlite3.h>

#if defined(HAS_CODEC_RESTRICTED) || defined(SQLITE_HAS_CODEC)
// SEE-style activation (present in SEE and many codec forks)
extern void sqlite3_activate_see(const char *info);
// Keying API (SEE, SQLCipher-compatible shims use the same symbol)
extern int sqlite3_key(sqlite3 *db, const void *pKey, int nKey);
#endif



static inline NSError *DBMakeError(sqlite3 *db, NSString *msg) {
    int code = db ? sqlite3_errcode(db) : -1;
    const char *c = db ? sqlite3_errmsg(db) : "no db";
    NSDictionary *info = @{
        NSLocalizedDescriptionKey : (msg ?: @"SQLite error"),
        @"sqlite_message"         : c ? @(c) : @""
    };
    return [NSError errorWithDomain:@"Ascent.DB" code:code userInfo:info];
}

static NSString *URIForFileURL(NSURL *url, BOOL readOnly) {
    // Build a SQLite URI: file:/absolute/path?mode=ro&immutable=1  (or mode=rwc for read-write)
    NSString *path = url.path;
    // Percent-encode path segments safely (older SDKs may lack URLPathAllowedCharacterSet)
    CFStringRef cfEsc = CFURLCreateStringByAddingPercentEscapes(NULL,
                           (CFStringRef)path, NULL, CFSTR(":/?#[]@!$&'()*+,;="), kCFStringEncodingUTF8);
    NSString *escaped = [(__bridge_transfer NSString *)cfEsc autorelease];

    if (readOnly) {
        return [NSString stringWithFormat:@"file:%@?mode=ro&immutable=1", escaped];
    } else {
        return [NSString stringWithFormat:@"file:%@?mode=rwc", escaped];
    }
}


@interface DatabaseManager ()
@end

@implementation DatabaseManager

@synthesize readOnly = _readOnly;

- (instancetype)initWithURL:(NSURL *)dbURL {
    return [self initWithURL:dbURL readOnly:NO];   // default
}

- (instancetype)initWithURL:(NSURL *)dbURL readOnly:(BOOL)readOnly {
    NSParameterAssert(dbURL);
    if ((self = [super init])) {
        _databaseURL = [dbURL retain];
        _readOnly = readOnly;
        _writeQueue = dispatch_queue_create("com.montebellosoftware.Ascent.DBWriteQ",
                       dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
        _db = NULL; _isOpen = NO;
    }
    return self;
}


- (void)dealloc {
    [self close];
    if (_writeQueue) { dispatch_release(_writeQueue); _writeQueue = NULL; }
    [_databaseURL release];
    [super dealloc];
}

- (NSURL *)databaseURL { return _databaseURL; }
- (dispatch_queue_t)writeQueue { return _writeQueue; }
- (sqlite3 *)rawSQLite { return _db; }

static int LoggingPermissiveAuth(void *ud, int action,
                                 const char *param1, const char *param2,
                                 const char *dbName, const char *trigger)
{
    fprintf(stderr, "AUTH action=%d p1=%s p2=%s db=%s trig=%s\n",
            action, param1?param1:"", param2?param2:"", dbName?dbName:"", trigger?trigger:"");
    return SQLITE_OK;
}

static BOOL DirIsWritable(NSURL *dirURL) {
    if (!dirURL) return NO;
    NSNumber *isDir = nil, *writable = nil;
    [dirURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
    [dirURL getResourceValue:&writable forKey:NSURLIsWritableKey error:NULL];
    return (isDir.boolValue && writable.boolValue);
}



- (BOOL)open:(NSError **)error {
    __block BOOL ok = YES; __block NSError *err = nil;
    dispatch_sync(_writeQueue, ^{
        if (_isOpen) return;

        // Make sure directory exists for write-mode; harmless in ro.
        [[NSFileManager defaultManager] createDirectoryAtURL:_databaseURL.URLByDeletingLastPathComponent
                                 withIntermediateDirectories:YES attributes:nil error:NULL];

        int flags = (_readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE))
                    | SQLITE_OPEN_FULLMUTEX
                    | SQLITE_OPEN_URI; // IMPORTANT for ?mode= & immutable

        NSString *uri = URIForFileURL(_databaseURL, _readOnly);
        int rc = sqlite3_open_v2(uri.UTF8String, &_db, flags, NULL);
        if (rc != SQLITE_OK) {
            err = DBMakeError(_db, @"Failed to open database");
            ok = NO;
            if (_db) { sqlite3_close(_db); _db = NULL; }
            return;
        }

        // Extended result codes help debugging
        sqlite3_extended_result_codes(_db, 1);

        if (_readOnly) {
            // No WAL/sync PRAGMAs that might write files
            // Optional: defensive OFF and trusted schema ON are safe either way
            sqlite3_db_config(_db, SQLITE_DBCONFIG_DEFENSIVE, 0, NULL);
            sqlite3_db_config(_db, SQLITE_DBCONFIG_TRUSTED_SCHEMA, 1, NULL);
        } else {
            // Write path: normal performance PRAGMAs
            sqlite3_exec(_db, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
            sqlite3_exec(_db, "PRAGMA synchronous=NORMAL;", NULL, NULL, NULL);
            sqlite3_exec(_db, "PRAGMA foreign_keys=ON;", NULL, NULL, NULL);
            sqlite3_exec(_db, "PRAGMA page_size=8192;", NULL, NULL, NULL);
        }
        NSLog(@"DB OPENED...");

        _isOpen = YES;
    });
    if (!ok && error) *error = err;
    return ok;
}

- (void)close {
    dispatch_sync(_writeQueue, ^{
        if (!_isOpen) return;
        // Best-effort checkpoint
        sqlite3_wal_checkpoint_v2(_db, NULL, SQLITE_CHECKPOINT_TRUNCATE, NULL, NULL);
        sqlite3_close(_db);
        _db = NULL;
        _isOpen = NO;
        NSLog(@"DB CLOSED...");
    });
}

- (void)performSyncOnWriteQueue:(DBVoidBlock)block {
    dispatch_sync(_writeQueue, block ? block : ^{});
}

- (void)performWrite:(void (^)(sqlite3 *db, DBErrorBlock fail))block
          completion:(void (^_Nullable)(NSError * _Nullable error))completion
{
    dispatch_async(_writeQueue, ^{
        @autoreleasepool {
            if (!_isOpen) {
                if (completion) {
                    NSError *tmp = [NSError errorWithDomain:@"Ascent.DB" code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey:@"DB not open"}];
                    // Retain across the queue hop
                    NSError *deliver = [tmp retain];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion([deliver autorelease]);
                    });
                }
                return;
            }

            char *errmsg = NULL;
            __block NSError *err = nil;

            if (sqlite3_exec(_db, "BEGIN IMMEDIATE;", NULL, NULL, &errmsg) != SQLITE_OK) {
                err = DBMakeError(_db, @"BEGIN IMMEDIATE failed"); // autoreleased
            } else {
                __block BOOL failed = NO;
                DBErrorBlock fail = ^(NSError *e){
                    failed = YES;
                    err = e ?: DBMakeError(_db, @"Write block failed"); // autoreleased
                };

                if (block) block(_db, fail);

                if (failed) {
                    sqlite3_exec(_db, "ROLLBACK;", NULL, NULL, &errmsg);
                } else if (sqlite3_exec(_db, "COMMIT;", NULL, NULL, &errmsg) != SQLITE_OK) {
                    err = DBMakeError(_db, @"COMMIT failed"); // autoreleased
                }
            }

            if (completion) {
                // >>> retain before async hop so it survives the pool drain
                NSError *deliver = [err retain]; // err may be nil; retain is fine on nil
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion([deliver autorelease]);
                });
            }
        }
    });
}

- (void)performRead:(void (^)(sqlite3 *db))block
         completion:(void (^_Nullable)(void))completion
{
    // Reads go through the same serial queue => no concurrent access to _db
    dispatch_async(_writeQueue, ^{
        if (block) block(_db);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
        }
    });
}

- (BOOL)checkpointTruncate:(NSError **)error {
    __block BOOL ok = YES;
    __block NSError *err = nil;

    dispatch_sync(_writeQueue, ^{
        if (!_isOpen) return;
        if (sqlite3_wal_checkpoint_v2(_db, NULL, SQLITE_CHECKPOINT_TRUNCATE, NULL, NULL) != SQLITE_OK) {
            ok = NO;
            err = DBMakeError(_db, @"WAL checkpoint failed");
        }
    });

    if (!ok && error) *error = err;
    return ok;
}

- (BOOL)exportSnapshotToURL:(NSURL *)destURL error:(NSError **)error {
    __block BOOL ok = YES;
    __block NSError *err = nil;

    dispatch_sync(_writeQueue, ^{
        if (!_isOpen) {
            ok = NO;
            err = [NSError errorWithDomain:@"Ascent.DB" code:-1
                                  userInfo:@{NSLocalizedDescriptionKey:@"DB not open"}];
            return;
        }

        // Best-effort: shrink WAL before export
        sqlite3_exec(_db, "PRAGMA wal_checkpoint(TRUNCATE);", NULL, NULL, NULL);

        sqlite3_stmt *stmt = NULL;
        const char *sql = "VACUUM INTO ?1;";
        if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, destURL.fileSystemRepresentation, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(stmt) != SQLITE_DONE) {
                ok = NO; err = DBMakeError(_db, @"VACUUM INTO failed");
            }
        } else {
            ok = NO; err = DBMakeError(_db, @"Prepare VACUUM INTO failed");
        }
        if (stmt) sqlite3_finalize(stmt);
    });

    if (!ok && error) *error = err;
    return ok;
}

@end
