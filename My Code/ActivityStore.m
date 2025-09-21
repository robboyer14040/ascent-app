//
//  ActivityStore.m
//  Ascent
//

#import "ActivityStore.h"

#import "Track.h"
#import "Lap.h"
#import "PathMarker.h"
#import "OverrideData.h"
#import "ColumnInfo.h"
#import "DatabaseManager.h"
#import <sqlite3.h>

#import <objc/runtime.h>



#define SETF(_sel, _idx) do { \
    double _v = (sqlite3_column_type(a, (_idx)) == SQLITE_NULL) ? 0.0 : sqlite3_column_double(a, (_idx)); \
    if ([t respondsToSelector:@selector(_sel:)]) [t _sel:(float)_v]; \
    else @try { [t setValue:@((float)_v) forKey:@#_sel]; } @catch (__unused id e) {} \
} while(0)

#define SETD(_sel, _idx) do { \
    double _v = (sqlite3_column_type(a, (_idx)) == SQLITE_NULL) ? 0.0 : sqlite3_column_double(a, (_idx)); \
    if ([t respondsToSelector:@selector(_sel:)]) [t _sel:_v]; \
    else @try { [t setValue:@(_v) forKey:@#_sel]; } @catch (__unused id e) {} \
} while(0)





#pragma mark - Helpers (unchanged)
// --- JSON helpers ---
// Strings (NSArray<NSString*>) <-> JSON text -------------------------------
static NSString *StringsToJSON(NSArray<NSString *> *arr) {
    if (![arr isKindOfClass:[NSArray class]] || arr.count == 0) return @"[]";
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:arr.count];
    for (id v in arr) {
        [out addObject:[v isKindOfClass:NSString.class] ? v : [v description]];
    }
    NSError *err = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:out options:0 error:&err];
    return d ? [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease] : @"[]";
}

static NSArray<NSString *> *StringsFromJSONString(const unsigned char *txt) {
    if (!txt) return @[];
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    if (![obj isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (id v in (NSArray *)obj) if ([v isKindOfClass:NSString.class]) [out addObject:v];
    return out;
}

static NSData *JSONData(id obj) {
    if (!obj) return nil;
    return [NSJSONSerialization dataWithJSONObject:obj options:0 error:NULL];
}
static NSString *JSONText(id obj) {
    NSData *d = JSONData(obj);
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}
static id JSONParse(NSData *d) {
    if (!d.length) return nil;
    return [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
}

// Attributes (NSArray<NSString *>)
static NSString *AttributesToJSON(NSArray *attrs) {
    if (![attrs isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:attrs.count];
    for (id v in attrs) [out addObject:[v isKindOfClass:NSString.class] ? v : [v description]];
    return JSONText(out);
}
static NSArray<NSString *> *AttributesFromJSONString(const unsigned char *txt) {
    if (!txt) return @[];
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id arr = JSONParse(d);
    if (![arr isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (id v in (NSArray *)arr) if ([v isKindOfClass:NSString.class]) [out addObject:v];
    return out;
}

// PathMarker array
static NSDictionary *MarkerToDict(id pm) {
    NSString *name = nil, *img = nil, *snd = nil;
    double dist = 0.0;
    if ([pm respondsToSelector:@selector(name)])      name = [pm name];
    else @try { name = [pm valueForKey:@"name"]; } @catch (__unused id e) {}
    if ([pm respondsToSelector:@selector(imagePath)]) img  = [pm imagePath];
    else @try { img = [pm valueForKey:@"imagePath"]; } @catch (__unused id e) {}
    if ([pm respondsToSelector:@selector(soundPath)]) snd  = [pm soundPath];
    else @try { snd = [pm valueForKey:@"soundPath"]; } @catch (__unused id e) {}
    if ([pm respondsToSelector:@selector(distance)])  dist = [pm distance];
    else @try { dist = [[pm valueForKey:@"distance"] doubleValue]; } @catch (__unused id e) {}
    return @{
        @"name": name ?: @"",
        @"image_path": img ?: @"",
        @"sound_path": snd ?: @"",
        @"distance": @(dist)
    };
}
static NSString *MarkersToJSON(NSArray *markers) {
    if (![markers isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:markers.count];
    for (id pm in markers) [arr addObject:MarkerToDict(pm)];
    return JSONText(arr);
}
static NSArray *MarkersFromJSONString(const unsigned char *txt) {
    if (!txt) return @[];
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id arr = JSONParse(d);
    if (![arr isKindOfClass:NSArray.class]) return @[];
    Class PM = NSClassFromString(@"PathMarker");
    NSMutableArray *out = [NSMutableArray array];
    for (id e in (NSArray *)arr) {
        if (![e isKindOfClass:NSDictionary.class]) continue;
        PathMarker* pm = PM ? [PM new] : [NSObject new];
        NSString *name = e[@"name"] ?: @"";
        NSString *img  = e[@"image_path"] ?: @"";
        NSString *snd  = e[@"sound_path"] ?: @"";
        double    dist = [e[@"distance"] doubleValue];

        if ([pm respondsToSelector:@selector(setName:)])      [pm setName:name]; else @try { [pm setValue:name forKey:@"name"]; } @catch (__unused id ee) {}
        if ([pm respondsToSelector:@selector(setImagePath:)]) [pm setImagePath:img]; else @try { [pm setValue:img forKey:@"imagePath"]; } @catch (__unused id ee) {}
        if ([pm respondsToSelector:@selector(setSoundPath:)]) [pm setSoundPath:snd]; else @try { [pm setValue:snd forKey:@"soundPath"]; } @catch (__unused id ee) {}
        if ([pm respondsToSelector:@selector(setDistance:)])  [pm setDistance:(float)dist]; else @try { [pm setValue:@(dist) forKey:@"distance"]; } @catch (__unused id ee) {}

        [out addObject:pm];
    }
    return out;
}

// OverrideData -> JSON (portable; uses public API)
// JSON shape: { "numStats":N, "overrideBits":B, "values":{"S":[v0,v1,...], ...} }
static int OD_numStats(id od)      { @try { return [[od valueForKey:@"numStats"] intValue]; } @catch (__unused id e) { return 0; } }
static int OD_overrideBits(id od)  { @try { return [[od valueForKey:@"overrideBits"] intValue]; } @catch (__unused id e) { return 0; } }

static NSString *OverrideToJSON(OverrideData* overrideObj) {
    if (!overrideObj) return nil;
    int numStats = OD_numStats(overrideObj);
    int bits     = OD_overrideBits(overrideObj);
    if (numStats <= 0) return nil;

    NSMutableDictionary *root = [@{@"numStats": @(numStats),
                                   @"overrideBits": @(bits)} mutableCopy];
    NSMutableDictionary *values = [NSMutableDictionary dictionary];

    for (int s = 0; s < numStats; s++) {
        if ((bits & (1<<s)) == 0) continue;
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:(NSUInteger)kNumValsPerOverrideEntry];
        for (NSInteger i = 0; i < kNumValsPerOverrideEntry; i++) {
            float v = 0.f;
            if ([overrideObj respondsToSelector:@selector(value:index:)]) {
                v = (float)[overrideObj value:s index:(int)i];
            } else {
                ///@try { v = (float)[overrideObj performSelector:@selector(value:index:) withObject:@(s) withObject:@(i)]; } @catch (__unused id e) {}
                NSLog(@"FIXME");
            }
            [arr addObject:@(v)];
        }
        values[[NSString stringWithFormat:@"%d", s]] = arr;
    }
    root[@"values"] = values;
    NSData *json = [NSJSONSerialization dataWithJSONObject:root options:0 error:NULL];
    return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : nil;
}

static id OverrideFromJSON(const unsigned char *txt) {
    if (!txt) return nil;
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id root = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    if (![root isKindOfClass:NSDictionary.class]) return nil;

    NSDictionary *dict = (NSDictionary *)root;
    int numStats = [dict[@"numStats"] intValue];
    int bits     = [dict[@"overrideBits"] intValue];
    NSDictionary *values = [dict[@"values"] isKindOfClass:NSDictionary.class] ? dict[@"values"] : @{};
    Class OD = NSClassFromString(@"OverrideData");
    if (!OD) return nil;
    id od = [OD new];

    @try { [od setValue:@(numStats) forKey:@"numStats"]; } @catch (__unused id e) {}
    @try { [od setValue:@(bits)     forKey:@"overrideBits"]; } @catch (__unused id e) {}

    // Replay overrides
    for (NSString *key in values) {
        int s = key.intValue;
        if ((bits & (1<<s)) == 0) continue;
        NSArray *arr = [values[key] isKindOfClass:NSArray.class] ? values[key] : @[];
        for (NSInteger i = 0; i < (NSInteger)arr.count; i++) {
            float v = [arr[i] floatValue];
            if ([od respondsToSelector:@selector(setValue:index:value:)]) {
                [od setValue:s index:(int)i value:v];
            }
        }
    }
    return od;
}


static NSString *JSONStringFromStringIntDict(NSDictionary<NSString*, NSNumber*> *dict) {
    if (!dict) return nil;
    NSError *err = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&err];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}

static NSDictionary<NSString*, NSNumber*> *StringIntDictFromJSONText(const unsigned char *txt) {
    if (!txt) return nil;
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    if ([obj isKindOfClass:[NSDictionary class]]) return obj;
    return nil;
}

static inline sqlite3_int64 EpochFromDate(NSDate *date) { return date ? (sqlite3_int64)llround(date.timeIntervalSince1970) : 0; }
static inline NSDate *DateFromEpoch(sqlite3_int64 s) { return s ? [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)s] : nil; }



// Serialize dictionary <NSString*, ColumnInfo*> to JSON text
static NSString *JSONStringFromColumnInfoDict(NSDictionary<NSString*, ColumnInfo*> *dict) {
    if (!dict) return nil;

    // Convert ColumnInfo objects into plain JSON-safe dictionaries
    NSMutableDictionary *jsonDict = [NSMutableDictionary dictionaryWithCapacity:dict.count];
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, ColumnInfo *info, BOOL *stop) {
        if (info) {
            jsonDict[key] = @{@"width": @(info.width),
                              @"order": @(info.order)};
        }
    }];

    NSError *err = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&err];
    if (!d) return nil;
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}


// Deserialize JSON text back into <NSString*, ColumnInfo*> dictionary
static NSDictionary<NSString*, ColumnInfo*> *ColumnInfoDictFromJSONText(const unsigned char *txt) {
    if (!txt) return nil;
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    if (![obj isKindOfClass:[NSDictionary class]]) return nil;

    NSDictionary *jsonDict = (NSDictionary *)obj;
    NSMutableDictionary<NSString*, ColumnInfo*> *result =
        [NSMutableDictionary dictionaryWithCapacity:jsonDict.count];

    [jsonDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *entry, BOOL *stop) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            NSNumber *width = entry[@"width"];
            NSNumber *order = entry[@"order"];
            if (width && order) {
                ColumnInfo *info = [ColumnInfo new];
                info.width = width.floatValue;
                info.order = order.intValue;
                result[key] = info;
            }
        }
    }];

    return result;
}

static NSString *URLsToJSON(NSArray<NSURL *> *urls) {
    if (![urls isKindOfClass:[NSArray class]] || urls.count == 0) return @"[]";
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:urls.count];
    for (id u in urls) {
        if ([u isKindOfClass:[NSURL class]]) {
            NSString *s = [(NSURL *)u absoluteString];
            if (s) [arr addObject:s];
        } else if ([u isKindOfClass:[NSString class]]) {
            [arr addObject:(NSString *)u]; // tolerate stray strings
        }
    }
    NSError *err = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:arr options:0 error:&err];
    return d ? [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease] : @"[]";
}


static NSArray<NSURL *> *URLsFromJSONString(const unsigned char *txt) {
    if (!txt) return [NSArray array];
    NSData *d = [NSData dataWithBytes:txt length:strlen((const char *)txt)];
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
    if (![obj isKindOfClass:[NSArray class]]) return [NSArray array];

    NSMutableArray<NSURL *> *out = [NSMutableArray array];
    for (id e in (NSArray *)obj) {
        if ([e isKindOfClass:[NSString class]]) {
            NSURL *url = [NSURL URLWithString:(NSString *)e];
            if (url) [out addObject:url];
        }
    }
    return out;
}




// Strict exec (with NSError)
static BOOL ASCExecStrict(sqlite3 *db, const char *sql, NSError **outError) {
    char *errmsg = NULL;
    int rc = sqlite3_exec(db, sql, NULL, NULL, &errmsg);
    if (rc != SQLITE_OK) {
        if (outError) {
            NSString *msg = errmsg ? [NSString stringWithUTF8String:errmsg] : @"SQLite error";
            *outError = [NSError errorWithDomain:@"ActivityStore" code:rc
                                        userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        if (errmsg) sqlite3_free(errmsg);
        return NO;
    }
    return YES;
}

// Ensure column exists (ADD COLUMN if missing)
static BOOL ASCEnsureColumn(sqlite3 *db,
                            const char *table,
                            const char *column,
                            const char *type,
                            NSError **outError)
{
    sqlite3_stmt *st = NULL;
    char sql[256];
    snprintf(sql, sizeof(sql), "PRAGMA table_info(%s);", table);
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) {
        if (outError) *outError = [NSError errorWithDomain:@"ActivityStore"
                                                      code:sqlite3_errcode(db)
                                                  userInfo:@{NSLocalizedDescriptionKey:
                                                                 @(sqlite3_errmsg(db) ?: "PRAGMA table_info failed")}];
        return NO;
    }
    BOOL have = NO;
    while (sqlite3_step(st) == SQLITE_ROW) {
        const unsigned char *name = sqlite3_column_text(st, 1);
        if (name && strcmp((const char *)name, column) == 0) { have = YES; break; }
    }
    sqlite3_finalize(st);
    if (have) return YES;

    char alter[512];
    snprintf(alter, sizeof(alter), "ALTER TABLE %s ADD COLUMN %s %s;", table, column, type);
    char *errmsg = NULL;
    int rc = sqlite3_exec(db, alter, NULL, NULL, &errmsg);
    if (rc != SQLITE_OK) {
        if (outError) *outError = [NSError errorWithDomain:@"ActivityStore" code:rc
                                                  userInfo:@{NSLocalizedDescriptionKey:
                                                                 (errmsg?@(errmsg):@"ALTER TABLE failed")}];
        if (errmsg) sqlite3_free(errmsg);
        return NO;
    }
    return YES;
}



@interface ActivityStore () {
    DatabaseManager *_dbm; // <— NEW: non-owning; nil unless attached
}
@end

@implementation ActivityStore

#pragma mark - Inits

- (instancetype)init {
    return [self initWithDatabaseManager:nil];  // or raise an error if dbm is required
}

- (instancetype)initWithDatabaseManager:(DatabaseManager * _Nullable)dbm
{
    NSParameterAssert(dbm != nil);
    if (!dbm) return nil;

    if ((self = [super init])) {
        _dbm    = dbm;                   // non-owning reference (assign)
        _db     = [dbm rawSQLite];       // cached handle for convenience
        _ownsDB = NO;                    // DatabaseManager owns lifetime
        _url    = nil;                   // not URL-based in this mode
    }
    return self;
}



- (void)dealloc {
    if (_ownsDB && _db) { sqlite3_close(_db); _db = NULL; }
    [_url release];
    [super dealloc];
}

#pragma mark - Open/Close


#pragma mark - Meta save

- (BOOL)saveMetaWithTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)tableInfoDict
              splitsTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)splitsTableInfoDict
                         uuid:(NSString*)uuid
                    startDate:(NSDate *)startDate
                      endDate:(NSDate *)endDate
                 lastSyncTime:(NSDate *)lastSyncTime
                        flags:(NSInteger)flags
                  totalTracks:(NSInteger)i2
                         int3:(NSInteger)i3
                         int4:(NSInteger)i4
                        error:(NSError **)error
{
    __block BOOL ok = YES;
    __block NSError *err = nil;

    void (^work)(sqlite3 *) = ^(sqlite3 *db) {
        const char *sql =
        "UPDATE meta SET "
        " uuid_s=?, tableInfo_json=?, splitsTableInfo_json=?, "
        " startDate_s=?, endDate_s=?, lastSyncTime_s=?, "
        " flags=?, totalTracks=?, int3=?, int4=? "
        " WHERE id=1;";

        sqlite3_stmt *st = NULL;
        int rc = sqlite3_prepare_v2(db, sql, -1, &st, NULL);
        if (rc != SQLITE_OK || st == NULL) {
            ok = NO;
            // RETAIN the error so it survives past the block under MRC
            err = [[NSError alloc] initWithDomain:@"ActivityStore"
                                             code:sqlite3_errcode(db)
                                         userInfo:@{ NSLocalizedDescriptionKey : @(sqlite3_errmsg(db) ?: "prepare failed") }];
            return;
        }

        NSString *d1 = JSONStringFromColumnInfoDict(tableInfoDict);
        NSString *d2 = JSONStringFromColumnInfoDict(splitsTableInfoDict);

        sqlite3_bind_text  (st, 1,  (uuid ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text  (st, 2,  (d1 ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
        sqlite3_bind_text  (st, 3,  (d2 ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64 (st, 4,  EpochFromDate(startDate));
        sqlite3_bind_int64 (st, 5,  EpochFromDate(endDate));
        sqlite3_bind_int64 (st, 6,  EpochFromDate(lastSyncTime));
        sqlite3_bind_int   (st, 7,  (int)flags);
        sqlite3_bind_int   (st, 8,  (int)i2);
        sqlite3_bind_int   (st, 9,  (int)i3);
        sqlite3_bind_int   (st, 10, (int)i4);

        rc = sqlite3_step(st);
        if (rc != SQLITE_DONE) {
            ok = NO;
            // RETAIN again
            err = [[NSError alloc] initWithDomain:@"ActivityStore"
                                             code:sqlite3_errcode(db)
                                         userInfo:@{ NSLocalizedDescriptionKey : @(sqlite3_errmsg(db) ?: "update failed") }];
            NSLog(@"[ActivityStore] meta UPDATE failed: %@", err);
        }

        sqlite3_finalize(st);

        // Optional: if no row existed (changes==0), insert the singleton row and try again.
        if (ok && sqlite3_changes(db) == 0) {
            char *em = NULL;
            if (sqlite3_exec(db, "INSERT OR IGNORE INTO meta(id) VALUES(1);", NULL, NULL, &em) != SQLITE_OK) {
                ok = NO;
                err = [[NSError alloc] initWithDomain:@"ActivityStore"
                                                 code:sqlite3_errcode(db)
                                             userInfo:@{ NSLocalizedDescriptionKey : @(sqlite3_errmsg(db) ?: "insert meta failed") }];
                if (em) sqlite3_free(em);
                return;
            }
            // Re-run once
            ok = NO; // default to failure; will set back to YES if it works
            NSError *retryErr = nil;
            BOOL retryOK = [self saveMetaWithTableInfo:tableInfoDict
                                       splitsTableInfo:splitsTableInfoDict
                                                  uuid:uuid
                                             startDate:startDate
                                               endDate:endDate
                                          lastSyncTime:lastSyncTime
                                                 flags:flags
                                           totalTracks:i2
                                                  int3:i3
                                                  int4:i4
                                                 error:&retryErr];
            if (retryOK) {
                ok = YES;
            } else {
                ok = NO;
                if (retryErr != nil) {
                    err = [retryErr retain];
                }
            }
        }
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
            work(db);
            if (!ok) {
                // pass the same retained error to DBM
                fail(err ?: [NSError errorWithDomain:@"ActivityStore" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"unknown error"}]);
            }
        } completion:^(NSError *e) {
            // If DBM produced an error and we didn't set one, RETAIN it
            if (e != nil && err == nil) {
                err = [e retain];
                ok = NO;
            }
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
    } else {
        work(_db);
    }

    if (!ok) {
        if (error != NULL) {
            // Hand back an autoreleased instance per Cocoa conventions
            *error = [err autorelease];
        } else {
            [err release];
        }
    } else {
        if (err != nil) {
            [err release];
            err = nil;
        }
    }

    return ok;
}

#pragma mark - Save one / many tracks
// (identical to your version, but wrapped in _dbm writes where SQL occurs)


- (BOOL)saveTrack:(Track *)track error:(NSError **)error
{
    __block BOOL ok = YES;
    __block NSError *err = nil;

    BOOL (^work)(sqlite3 *) = ^BOOL(sqlite3 *db) {

        // --------- UUID (required) ----------
        NSString *uuid = [track respondsToSelector:@selector(uuid)] ? [track uuid] : [track valueForKey:@"uuid"];
        if (uuid.length == 0) {
            err = [NSError errorWithDomain:@"ActivityStore"
                                      code:-1
                                  userInfo:@{NSLocalizedDescriptionKey:@"Track uuid is required"}];
            return NO;
        }

        // --------- Dirty flags (default "all dirty" if absent) ----------
        uint32_t dirtyMask = 0xFFFFFFFFu;
        BOOL haveDirty = NO;
        @try {
            dirtyMask = (uint32_t)[[track valueForKey:@"dirtyMask"] unsignedIntValue];
            haveDirty = YES;
        } @catch (__unused id e) {}
        BOOL metaDirty = haveDirty ? ((dirtyMask & (kDirtyMeta)) != 0) : YES;
        BOOL lapsDirty = haveDirty ? ((dirtyMask & (kDirtyLaps)) != 0) : YES;

        // --------- Check if row already exists (and whether points were saved) ----------
        sqlite3_int64 trackID = 0;
        int points_saved = 0;
        {
            sqlite3_stmt *q = NULL;
            int rc = sqlite3_prepare_v2(db,
                "SELECT id, COALESCE(points_saved,0) FROM activities WHERE uuid=?1;", -1, &q, NULL);
            if (rc == SQLITE_OK && q) {
                sqlite3_bind_text(q, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                if (sqlite3_step(q) == SQLITE_ROW) {
                    trackID = sqlite3_column_int64(q, 0);
                    points_saved = sqlite3_column_int(q, 1);
                    ///NSLog(@"[ActStore] points_saved initial = %d for %s", points_saved, [track.name UTF8String]);
                }
            }
            if (q) sqlite3_finalize(q);

            if (trackID == 0) {
                // legacy fallback: infer from points table
                sqlite3_stmt *qp = NULL;
                if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &qp, NULL) == SQLITE_OK) {
                    sqlite3_bind_text(qp, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                    if (sqlite3_step(qp) == SQLITE_ROW) trackID = sqlite3_column_int64(qp, 0);
                }
                if (qp) sqlite3_finalize(qp);

                if (trackID > 0) {
                    sqlite3_stmt *qq = NULL;
                    if (sqlite3_prepare_v2(db, "SELECT 1 FROM points WHERE track_id=?1 LIMIT 1;", -1, &qq, NULL) == SQLITE_OK) {
                        sqlite3_bind_int64(qq, 1, trackID);
                        points_saved = (sqlite3_step(qq) == SQLITE_ROW) ? 1 : 0;
                    }
                    if (qq) sqlite3_finalize(qq);
                }
            }
        }

        // --------- Safe early-out (only if row already exists) ----------
        BOOL pointsEverSaved = NO;
        @try { pointsEverSaved = [[track valueForKey:@"pointsEverSaved"] boolValue]; } @catch (__unused id e) {}

        if (trackID > 0 && !metaDirty && !lapsDirty && (points_saved || pointsEverSaved)) {
            return YES;
        }

        // --------- If meta dirty, UPDATE-then-INSERT (only when missing) ----------
        if (metaDirty) {
            NSString *name = [track respondsToSelector:@selector(name)] ? [track name] : [track valueForKey:@"name"];
            NSDate   *ct   = [track respondsToSelector:@selector(creationTime)] ? [track creationTime] : [track valueForKey:@"creationTime"];
            NSDate   *cto  = [track respondsToSelector:@selector(creationTimeOverride)] ? [track creationTimeOverride] : [track valueForKey:@"creationTimeOverride"];

            double distance = [track respondsToSelector:@selector(distance)] ? [track distance] : [[track valueForKey:@"distance"] doubleValue];
            double weight   = [track respondsToSelector:@selector(weight)] ? [track weight] : [[track valueForKey:@"weight"] doubleValue];
            double asf      = [track respondsToSelector:@selector(altitudeSmoothingFactor)] ? [track altitudeSmoothingFactor] : [[track valueForKey:@"altitudeSmoothingFactor"] doubleValue];
            double eqw      = [track respondsToSelector:@selector(equipmentWeight)] ? [track equipmentWeight] : [[track valueForKey:@"equipmentWeight"] doubleValue];
            double devTime  = [track respondsToSelector:@selector(deviceTotalTime)] ? [track deviceTotalTime] : [[track valueForKey:@"deviceTotalTime"] doubleValue];
            BOOL   moving   = [track respondsToSelector:@selector(movingSpeedOnly)] ? [track movingSpeedOnly] : [[track valueForKey:@"movingSpeedOnly"] boolValue];
            BOOL   hasDist  = [track respondsToSelector:@selector(hasDistanceData)] ? [track hasDistanceData] : [[track valueForKey:@"hasDistanceData"] boolValue];

            int secondsFromGMT = [track respondsToSelector:@selector(secondsFromGMT)] ? [track secondsFromGMT] : [[track valueForKey:@"secondsFromGMT"] intValue];
            int flags           = [track respondsToSelector:@selector(flags)] ? [track flags] : [[track valueForKey:@"flags"] intValue];
            int deviceID        = [track respondsToSelector:@selector(deviceID)] ? [track deviceID] : [[track valueForKey:@"deviceID"] intValue];
            int firmwareVersion = [track respondsToSelector:@selector(firmwareVersion)] ? [track firmwareVersion] : [[track valueForKey:@"firmwareVersion"] intValue];

            NSArray<NSURL *> *photoURLs = nil;
            if ([track respondsToSelector:@selector(photoURLs)]) { photoURLs = [track photoURLs]; }
            else { @try { photoURLs = [track valueForKey:@"photoURLs"]; } @catch (__unused id e) {} }
            NSString *photosJSON = URLsToJSON(photoURLs);

            NSArray<NSString *> *localMedia = nil;
            if ([track respondsToSelector:@selector(localMediaItems)]) { localMedia = [track localMediaItems]; }
            else { @try { localMedia = [track valueForKey:@"localMediaItems"]; } @catch (__unused id e) {} }
            NSString *localMediaJSON = StringsToJSON(localMedia);

            double srcDistance       = [track respondsToSelector:@selector(srcDistance)]       ? [track srcDistance]       : [[track valueForKey:@"srcDistance"] doubleValue];
            double srcMaxSpeed       = [track respondsToSelector:@selector(srcMaxSpeed)]       ? [track srcMaxSpeed]       : [[track valueForKey:@"srcMaxSpeed"] doubleValue];
            double srcAvgHeartrate   = [track respondsToSelector:@selector(srcAvgHeartrate)]   ? [track srcAvgHeartrate]   : [[track valueForKey:@"srcAvgHeartrate"] doubleValue];
            double srcMaxHeartrate   = [track respondsToSelector:@selector(srcMaxHeartrate)]   ? [track srcMaxHeartrate]   : [[track valueForKey:@"srcMaxHeartrate"] doubleValue];
            double srcAvgTemperature = [track respondsToSelector:@selector(srcAvgTemperature)] ? [track srcAvgTemperature] : [[track valueForKey:@"srcAvgTemperature"] doubleValue];
            double srcMaxElevation   = [track respondsToSelector:@selector(srcMaxElevation)]   ? [track srcMaxElevation]   : [[track valueForKey:@"srcMaxElevation"] doubleValue];
            double srcMinElevation   = [track respondsToSelector:@selector(srcMinElevation)]   ? [track srcMinElevation]   : [[track valueForKey:@"srcMinElevation"] doubleValue];
            double srcAvgPower       = [track respondsToSelector:@selector(srcAvgPower)]       ? [track srcAvgPower]       : [[track valueForKey:@"srcAvgPower"] doubleValue];
            double srcMaxPower       = [track respondsToSelector:@selector(srcMaxPower)]       ? [track srcMaxPower]       : [[track valueForKey:@"srcMaxPower"] doubleValue];
            double srcAvgCadence     = [track respondsToSelector:@selector(srcAvgCadence)]     ? [track srcAvgCadence]     : [[track valueForKey:@"srcAvgCadence"] doubleValue];
            double srcTotalClimb     = [track respondsToSelector:@selector(srcTotalClimb)]     ? [track srcTotalClimb]     : [[track valueForKey:@"srcTotalClimb"] doubleValue];
            double srcKilojoules     = [track respondsToSelector:@selector(srcKilojoules)]     ? [track srcKilojoules]     : [[track valueForKey:@"srcKilojoules"] doubleValue];
            double srcElapsedTime    = [track respondsToSelector:@selector(srcElapsedTime)]    ? [track srcElapsedTime]    : [[track valueForKey:@"srcElapsedTime"] doubleValue];
            double srcMovingTime     = [track respondsToSelector:@selector(srcMovingTime)]     ? [track srcMovingTime]     : [[track valueForKey:@"srcMovingTime"] doubleValue];

            NSNumber *stravaActivityID = nil;
            if ([track respondsToSelector:@selector(stravaActivityID)]) stravaActivityID = [track stravaActivityID];
            else { @try { stravaActivityID = [track valueForKey:@"stravaActivityID"]; } @catch (__unused id e) {} }

            NSString *tzName = nil;
            if ([track respondsToSelector:@selector(timeZoneName)]) {
                tzName = [track timeZoneName];
            } else if ([track respondsToSelector:@selector(timeZone)]) {
                id tz = [track timeZoneName];
                if ([tz isKindOfClass:[NSTimeZone class]]) tzName = [(NSTimeZone *)tz name];
                else if ([tz isKindOfClass:[NSString class]]) tzName = (NSString *)tz;
            } else { @try { tzName = [track valueForKey:@"timeZone"]; } @catch (__unused id e) {} }

            NSArray *attrs   = [track respondsToSelector:@selector(attributes)] ? [track attributes] : [track valueForKey:@"attributes"];
            NSArray *markers = [track respondsToSelector:@selector(markers)]    ? [track markers]    : [track valueForKey:@"markers"];
            id       od      = nil;
            if ([track respondsToSelector:@selector(overrideData)]) od = [track performSelector:@selector(overrideData)];
            else { @try { od = [track valueForKey:@"overrideData"]; } @catch (__unused id e) {} }

            NSString *attrsJSON    = AttributesToJSON(attrs);
            NSString *markersJSON  = MarkersToJSON(markers);
            NSString *overrideJSON = OverrideToJSON(od);

            const BOOL rowExists = (trackID > 0);

            // ---- UPDATE by id (never touches points_saved/points_count) ----
            sqlite3_stmt *st = NULL;
            const char *updSQL =
            "UPDATE activities SET "
            " name=?1, creation_time_s=?2, creation_time_override_s=?3,"
            " distance_mi=?4, weight_lb=?5, altitude_smooth_factor=?6, equipment_weight_lb=?7,"
            " device_total_time_s=?8, moving_speed_only=?9, has_distance_data=?10,"
            " attributes_json=?11, markers_json=?12, override_json=?13,"
            " seconds_from_gmt_at_sync=?14, time_zone=?15,"
            " flags=?16, device_id=?17, firmware_version=?18,"
            " photo_urls_json=?19, strava_activity_id=?20,"
            " src_distance=?21, src_max_speed=?22, src_avg_heartrate=?23, src_max_heartrate=?24, src_avg_temperature=?25,"
            " src_max_elevation=?26, src_min_elevation=?27, src_avg_power=?28, src_max_power=?29, src_avg_cadence=?30,"
            " src_total_climb=?31, src_kilojoules=?32, src_elapsed_time_s=?33, src_moving_time_s=?34,"
            " local_media_items_json=?35"
            " WHERE id=?36;";

            int rc = sqlite3_prepare_v2(db, updSQL, -1, &st, NULL);
            if (rc != SQLITE_OK || !st) {
                err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                      userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "prepare UPDATE failed")}];
                return NO;
            }

            sqlite3_bind_text  (st,  1, (name?:@"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64 (st,  2, ct  ? (sqlite3_int64)llround(ct.timeIntervalSince1970)  : 0);
            sqlite3_bind_int64 (st,  3, cto ? (sqlite3_int64)llround(cto.timeIntervalSince1970) : 0);
            sqlite3_bind_double(st,  4, distance);
            sqlite3_bind_double(st,  5, weight);
            sqlite3_bind_double(st,  6, asf);
            sqlite3_bind_double(st,  7, eqw);
            sqlite3_bind_double(st,  8, devTime);
            sqlite3_bind_int   (st,  9, moving ? 1 : 0);
            sqlite3_bind_int   (st, 10, hasDist ? 1 : 0);
            sqlite3_bind_text  (st, 11, (attrsJSON    ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text  (st, 12, (markersJSON  ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text  (st, 13, (overrideJSON ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_int   (st, 14, secondsFromGMT);
            if (tzName.length) sqlite3_bind_text(st, 15, tzName.UTF8String, -1, SQLITE_TRANSIENT);
            else sqlite3_bind_null(st, 15);
            sqlite3_bind_int   (st, 16, flags);
            sqlite3_bind_int   (st, 17, deviceID);
            sqlite3_bind_int   (st, 18, firmwareVersion);
            sqlite3_bind_text  (st, 19, (photosJSON ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            if (stravaActivityID) sqlite3_bind_int64(st, 20, (sqlite3_int64)stravaActivityID.longLongValue);
            else sqlite3_bind_null(st, 20);
            sqlite3_bind_double(st, 21, srcDistance);
            sqlite3_bind_double(st, 22, srcMaxSpeed);
            sqlite3_bind_double(st, 23, srcAvgHeartrate);
            sqlite3_bind_double(st, 24, srcMaxHeartrate);
            sqlite3_bind_double(st, 25, srcAvgTemperature);
            sqlite3_bind_double(st, 26, srcMaxElevation);
            sqlite3_bind_double(st, 27, srcMinElevation);
            sqlite3_bind_double(st, 28, srcAvgPower);
            sqlite3_bind_double(st, 29, srcMaxPower);
            sqlite3_bind_double(st, 30, srcAvgCadence);
            sqlite3_bind_double(st, 31, srcTotalClimb);
            sqlite3_bind_double(st, 32, srcKilojoules);
            sqlite3_bind_double(st, 33, srcElapsedTime);
            sqlite3_bind_double(st, 34, srcMovingTime);
            sqlite3_bind_text  (st, 35, (localMediaJSON ?: @"[]").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64 (st, 36, trackID); // <<< UPDATE by id

            rc = sqlite3_step(st);
            if (rc != SQLITE_DONE) {
                err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                      userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "UPDATE activities failed")}];
                sqlite3_finalize(st);
                return NO;
            }
            sqlite3_finalize(st);

            // Only INSERT if the row truly did not exist.
            if (!rowExists) {
                const char *insSQL =
                "INSERT INTO activities ("
                " uuid,name,creation_time_s,creation_time_override_s,"
                " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
                " device_total_time_s,moving_speed_only,has_distance_data,"
                " attributes_json,markers_json,override_json,"
                " seconds_from_gmt_at_sync,time_zone,"
                " flags,device_id,firmware_version,"
                " photo_urls_json,strava_activity_id,"
                " src_distance,src_max_speed,src_avg_heartrate,src_max_heartrate,src_avg_temperature,"
                " src_max_elevation,src_min_elevation,src_avg_power,src_max_power,src_avg_cadence,"
                " src_total_climb,src_kilojoules,src_elapsed_time_s,src_moving_time_s,"
                " local_media_items_json"
                ") VALUES ("
                " ?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20,"
                " ?21,?22,?23,?24,?25,?26,?27,?28,?29,?30,?31,?32,?33,?34,?35,?36"
                ");";

                sqlite3_stmt *ins = NULL;
                rc = sqlite3_prepare_v2(db, insSQL, -1, &ins, NULL);
                if (rc != SQLITE_OK || !ins) {
                    err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                          userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "prepare INSERT failed")}];
                    return NO;
                }

                sqlite3_bind_text  (ins,  1,  uuid.UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_text  (ins,  2,  (name?:@"").UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_int64 (ins,  3,  ct  ? (sqlite3_int64)llround(ct.timeIntervalSince1970)  : 0);
                sqlite3_bind_int64 (ins,  4,  cto ? (sqlite3_int64)llround(cto.timeIntervalSince1970) : 0);
                sqlite3_bind_double(ins,  5,  distance);
                sqlite3_bind_double(ins,  6,  weight);
                sqlite3_bind_double(ins,  7,  asf);
                sqlite3_bind_double(ins,  8,  eqw);
                sqlite3_bind_double(ins,  9,  devTime);
                sqlite3_bind_int   (ins, 10,  moving ? 1 : 0);
                sqlite3_bind_int   (ins, 11,  hasDist ? 1 : 0);
                sqlite3_bind_text  (ins, 12,  (attrsJSON    ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_text  (ins, 13,  (markersJSON  ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_text  (ins, 14,  (overrideJSON ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_int   (ins, 15,  secondsFromGMT);
                if (tzName.length) sqlite3_bind_text(ins, 16, tzName.UTF8String, -1, SQLITE_TRANSIENT);
                else sqlite3_bind_null(ins, 16);
                sqlite3_bind_int   (ins, 17,  flags);
                sqlite3_bind_int   (ins, 18,  deviceID);
                sqlite3_bind_int   (ins, 19,  firmwareVersion);
                sqlite3_bind_text  (ins, 20, (photosJSON ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
                if (stravaActivityID) sqlite3_bind_int64(ins, 21, (sqlite3_int64)stravaActivityID.longLongValue);
                else sqlite3_bind_null(ins, 21);
                sqlite3_bind_double(ins, 22, srcDistance);
                sqlite3_bind_double(ins, 23, srcMaxSpeed);
                sqlite3_bind_double(ins, 24, srcAvgHeartrate);
                sqlite3_bind_double(ins, 25, srcMaxHeartrate);
                sqlite3_bind_double(ins, 26, srcAvgTemperature);
                sqlite3_bind_double(ins, 27, srcMaxElevation);
                sqlite3_bind_double(ins, 28, srcMinElevation);
                sqlite3_bind_double(ins, 29, srcAvgPower);
                sqlite3_bind_double(ins, 30, srcMaxPower);
                sqlite3_bind_double(ins, 31, srcAvgCadence);
                sqlite3_bind_double(ins, 32, srcTotalClimb);
                sqlite3_bind_double(ins, 33, srcKilojoules);
                sqlite3_bind_double(ins, 34, srcElapsedTime);
                sqlite3_bind_double(ins, 35, srcMovingTime);
                sqlite3_bind_text  (ins, 36, (localMediaJSON ?: @"[]").UTF8String, -1, SQLITE_TRANSIENT);

                rc = sqlite3_step(ins);
                if (rc != SQLITE_DONE) {
                    err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                          userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "INSERT activities failed")}];
                    sqlite3_finalize(ins);
                    return NO;
                }
                sqlite3_finalize(ins);

                // fetch id for laps path
                sqlite3_stmt *sel = NULL;
                if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &sel, NULL) == SQLITE_OK) {
                    sqlite3_bind_text(sel, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                    if (sqlite3_step(sel) == SQLITE_ROW) trackID = sqlite3_column_int64(sel, 0);
                }
                if (sel) sqlite3_finalize(sel);
                if (trackID == 0) {
                    err = [NSError errorWithDomain:@"ActivityStore" code:-2
                                          userInfo:@{NSLocalizedDescriptionKey:@"Failed to resolve activities.id after insert"}];
                    return NO;
                }
            }

            // Clear meta bit
            @try {
                uint32_t newMask = dirtyMask & ~(kDirtyMeta);
                [track setValue:@(newMask) forKey:@"dirtyMask"];
                dirtyMask = newMask;
            } @catch (__unused id e) {}
        }

        // --------- Laps (only when lapsDirty) ----------
        if (lapsDirty) {
            NSArray *laps = [track respondsToSelector:@selector(laps)] ? [track laps] : [track valueForKey:@"laps"];

            (void)sqlite3_exec(db, "SAVEPOINT save_laps", NULL, NULL, NULL);

            // Delete existing laps
            sqlite3_stmt *delL = NULL;
            if (sqlite3_prepare_v2(db, "DELETE FROM laps WHERE track_id=?1;", -1, &delL, NULL) == SQLITE_OK) {
                sqlite3_bind_int64(delL, 1, trackID);
                (void)sqlite3_step(delL);
            }
            sqlite3_finalize(delL);

            // Insert laps
            if ([laps isKindOfClass:NSArray.class] && laps.count) {
                const char *insLap =
                "INSERT INTO laps (track_id,lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
                " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,device_total_time_s,"
                " average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated)"
                " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
                sqlite3_stmt *lapStmt = NULL;
                if (sqlite3_prepare_v2(db, insLap, -1, &lapStmt, NULL) == SQLITE_OK) {
                    for (Lap *lap in laps) {
                        sqlite3_bind_int64 (lapStmt, 1, trackID);
                        sqlite3_bind_int   (lapStmt, 2, [lap respondsToSelector:@selector(index)] ? [lap index] : [[lap valueForKey:@"index"] intValue]);
                        sqlite3_bind_int64 (lapStmt, 3, [lap respondsToSelector:@selector(origStartTime)] ? (sqlite3_int64)llround([[lap origStartTime] timeIntervalSince1970]) : (sqlite3_int64)llround([[lap valueForKey:@"origStartTime"] timeIntervalSince1970]));
                        sqlite3_bind_double(lapStmt, 4, [lap respondsToSelector:@selector(startTimeDelta)] ? [lap startTimeDelta] : [[lap valueForKey:@"startTimeDelta"] doubleValue]);
                        sqlite3_bind_double(lapStmt, 5, [lap respondsToSelector:@selector(totalTime)] ? [lap totalTime] : [[lap valueForKey:@"totalTime"] doubleValue]);
                        sqlite3_bind_double(lapStmt, 6, [lap respondsToSelector:@selector(distance)] ? [lap distance] : [[lap valueForKey:@"distance"] doubleValue]);
                        sqlite3_bind_double(lapStmt, 7, [lap respondsToSelector:@selector(maxSpeed)] ? [lap maxSpeed] : [[lap valueForKey:@"maxSpeed"] doubleValue]);
                        sqlite3_bind_double(lapStmt, 8, [lap respondsToSelector:@selector(avgSpeed)] ? [lap avgSpeed] : [[lap valueForKey:@"avgSpeed"] doubleValue]);
                        sqlite3_bind_double(lapStmt, 9, [lap respondsToSelector:@selector(beginLatitude)] ? [lap beginLatitude] : [[lap valueForKey:@"beginLatitude"] doubleValue]);
                        sqlite3_bind_double(lapStmt,10, [lap respondsToSelector:@selector(beginLongitude)] ? [lap beginLongitude] : [[lap valueForKey:@"beginLongitude"] doubleValue]);
                        sqlite3_bind_double(lapStmt,11, [lap respondsToSelector:@selector(endLatitude)] ? [lap endLatitude] : [[lap valueForKey:@"endLatitude"] doubleValue]);
                        sqlite3_bind_double(lapStmt,12, [lap respondsToSelector:@selector(endLongitude)] ? [lap endLongitude] : [[lap valueForKey:@"endLongitude"] doubleValue]);
                        sqlite3_bind_double(lapStmt,13, [lap respondsToSelector:@selector(deviceTotalTime)] ? [lap deviceTotalTime] : [[lap valueForKey:@"deviceTotalTime"] doubleValue]);
                        sqlite3_bind_int   (lapStmt,14, [lap respondsToSelector:@selector(averageHeartRate)] ? [lap averageHeartRate] : [[lap valueForKey:@"averageHeartRate"] intValue]);
                        sqlite3_bind_int   (lapStmt,15, [lap respondsToSelector:@selector(maxHeartRate)] ? [lap maxHeartRate] : [[lap valueForKey:@"maxHeartRate"] intValue]);
                        sqlite3_bind_int   (lapStmt,16, [lap respondsToSelector:@selector(averageCadence)] ? [lap averageCadence] : [[lap valueForKey:@"averageCadence"] intValue]);
                        sqlite3_bind_int   (lapStmt,17, [lap respondsToSelector:@selector(maxCadence)] ? [lap maxCadence] : [[lap valueForKey:@"maxCadence"] intValue]);
                        sqlite3_bind_int   (lapStmt,18, [lap respondsToSelector:@selector(calories)] ? [lap calories] : [[lap valueForKey:@"calories"] intValue]);
                        sqlite3_bind_int   (lapStmt,19, [lap respondsToSelector:@selector(intensity)] ? [lap intensity] : [[lap valueForKey:@"intensity"] intValue]);
                        sqlite3_bind_int   (lapStmt,20, [lap respondsToSelector:@selector(triggerMethod)] ? [lap triggerMethod] : [[lap valueForKey:@"triggerMethod"] intValue]);
                        sqlite3_bind_int   (lapStmt,21, [lap respondsToSelector:@selector(selected)] ? ([lap selected] ? 1 : 0) : ([[lap valueForKey:@"selected"] boolValue] ? 1 : 0));
                        sqlite3_bind_int   (lapStmt,22, [lap respondsToSelector:@selector(statsCalculated)] ? ([lap statsCalculated] ? 1 : 0) : ([[lap valueForKey:@"statsCalculated"] boolValue] ? 1 : 0));

                        if (sqlite3_step(lapStmt) != SQLITE_DONE) {
                            sqlite3_finalize(lapStmt);
                            sqlite3_exec(db, "ROLLBACK TO save_laps; RELEASE save_laps;", NULL, NULL, NULL);
                            err = [NSError errorWithDomain:@"ActivityStore"
                                                      code:sqlite3_errcode(db)
                                                  userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "insert lap failed")}];
                            return NO;
                        }
                        sqlite3_reset(lapStmt);
                        sqlite3_clear_bindings(lapStmt);
                    }
                    sqlite3_finalize(lapStmt);
                }
            }

            (void)sqlite3_exec(db, "RELEASE save_laps", NULL, NULL, NULL);

            // Clear laps bit
            @try {
                uint32_t newMask = dirtyMask & ~(kDirtyLaps);
                [track setValue:@(newMask) forKey:@"dirtyMask"];
                dirtyMask = newMask;
            } @catch (__unused id e) {}
        }

        // NOTE: Points are immutable and saved elsewhere (first-time only).
        return YES;
    };

    if (_dbm) {
        if ([_dbm respondsToSelector:@selector(isOnWriteQueue)] && [_dbm isOnWriteQueue]) {
            ok = work([_dbm rawSQLite]);
        } else {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail){
                ok = work(db);
                if (!ok && err) { fail(err); }
            } completion:^(__unused NSError *e){
                if (e && !err) { err = [e retain]; }
                dispatch_semaphore_signal(sem);
            }];
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            dispatch_release(sem);
            if (err) { [err autorelease]; }
        }
    } else {
        ok = work(_db);
    }

    if (!ok && error) *error = err;
    return ok;
}


- (BOOL)saveAllTracks:(NSArray *)tracks
                error:(NSError **)error
        progressBlock:(ASProgress)progress
{
    if (tracks.count == 0) return YES;

    NSUInteger numTracks = tracks.count, idx = 0;
    for (Track *t in tracks) {
        if (progress)
            progress(idx, numTracks);

        uint32_t mask = 0;
        BOOL pointsSaved = YES;
        @try {
            mask = (uint32_t)[t dirtyMask];
        } @catch (__unused id e) {}
        @try {
            pointsSaved = [t pointsEverSaved];
        } @catch (__unused id e) {}

        if (mask == 0 && pointsSaved) {
            idx++;
            continue;
        } // fast skip

        NSError *err = nil;
        if (![self saveTrack:t error:&err]) {
            if (error) *error = err;
            return NO;
        }
        idx++;
    }
    return YES;
}



#pragma mark - Load meta (now routed via performRead when available)

static int PermissiveAuth(void *ud, int action, const char *a, const char *b,
                          const char *c, const char *d)
{
    // Uncomment if you want to see what SQLite is checking:
    // fprintf(stderr, "AUTH action=%d a=%s b=%s\n", action, a?a:"", b?b:"");
    return SQLITE_OK;
}

static int LoggingPermissiveAuth(void *ud, int action,
                                 const char *param1, const char *param2,
                                 const char *dbName, const char *trigger)
{
    fprintf(stderr, "AUTH action=%d p1=%s p2=%s db=%s trig=%s\n",
            action, param1?param1:"", param2?param2:"", dbName?dbName:"", trigger?trigger:"");
    return SQLITE_OK;
}



- (BOOL)loadMetaTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable __autoreleasing * _Nullable)outTableInfo
          splitsTableInfo:(NSDictionary<NSString*, ColumnInfo*> * _Nullable __autoreleasing * _Nullable)outSplitsTableInfo
                     uuid:(NSString * _Nullable __autoreleasing * _Nullable)outUuid
                startDate:(NSDate * _Nullable __autoreleasing * _Nullable)outStartTime
                  endDate:(NSDate * _Nullable __autoreleasing * _Nullable)outEndTime
             lastSyncTime:(NSDate * _Nullable __autoreleasing * _Nullable)outLastSyncTime
                    flags:(NSInteger * _Nullable)outFlags
              totalTracks:(NSInteger * _Nullable)outTotalTracks
                     int3:(NSInteger * _Nullable)outI3
                     int4:(NSInteger * _Nullable)outI4
                    error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    __block BOOL ok = NO;
    __block NSError *err = nil;

    // Initialize outputs to safe defaults
    if (outUuid)            *outUuid = nil;
    if (outTableInfo)       *outTableInfo = nil;
    if (outSplitsTableInfo) *outSplitsTableInfo = nil;
    if (outStartTime)       *outStartTime = nil;
    if (outEndTime)         *outEndTime = nil;
    if (outLastSyncTime)    *outLastSyncTime = nil;
    if (outFlags)           *outFlags = 0;
    if (outTotalTracks)     *outTotalTracks = 0;
    if (outI3)              *outI3 = 0;
    if (outI4)              *outI4 = 0;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [_dbm performRead:^(sqlite3 *db) {
        @autoreleasepool {
            sqlite3_stmt *st = NULL;

            do {
                if (!db) {
                    err = [NSError errorWithDomain:@"ActivityStore" code:-1
                                          userInfo:@{NSLocalizedDescriptionKey:@"DB handle is NULL"}];
                    break;
                }

                const char *sql =
                  "SELECT id, uuid_s, tableInfo_json, splitsTableInfo_json, "
                  "       startDate_s, endDate_s, lastSyncTime_s, "
                  "       flags, totalTracks, int3, int4 "
                  "FROM meta WHERE id=1;";

                int rc = sqlite3_prepare_v2(db, sql, -1, &st, NULL);
                if (rc != SQLITE_OK || !st) {
                    const char *msg = sqlite3_errmsg(db);
                    // Treat missing table as “defaults OK” on read-only DBs
                    if (msg && strstr(msg, "no such table")) { ok = YES; break; }
                    err = [NSError errorWithDomain:@"ActivityStore" code:rc
                                          userInfo:@{NSLocalizedDescriptionKey: msg ? @(msg) : @"prepare failed"}];
                    break;
                }

                rc = sqlite3_step(st);
                if (rc == SQLITE_ROW) {
                    if (outUuid) {
                        const unsigned char *uuidTxt = sqlite3_column_text(st, 1);
                        *outUuid = uuidTxt ? [[NSString alloc] initWithUTF8String:(const char *)uuidTxt] : nil;
                    }
                    if (outTableInfo) {
                        NSDictionary *ti = ColumnInfoDictFromJSONText(sqlite3_column_text(st, 2));
                        *outTableInfo = [ti copy];
                    }
                    if (outSplitsTableInfo) {
                        NSDictionary *si = ColumnInfoDictFromJSONText(sqlite3_column_text(st, 3));
                        *outSplitsTableInfo = [si copy];
                    }
                    if (outStartTime)     *outStartTime     = [DateFromEpoch(sqlite3_column_int64(st, 4)) retain];
                    if (outEndTime)       *outEndTime       = [DateFromEpoch(sqlite3_column_int64(st, 5)) retain];
                    if (outLastSyncTime)  *outLastSyncTime  = [DateFromEpoch(sqlite3_column_int64(st, 6)) retain];
                    if (outFlags)         *outFlags         = sqlite3_column_int(st, 7);
                    if (outTotalTracks)   *outTotalTracks   = sqlite3_column_int(st, 8);
                    if (outI3)            *outI3            = sqlite3_column_int(st, 9);
                    if (outI4)            *outI4            = sqlite3_column_int(st,10);

                    ok = YES;
                } else if (rc == SQLITE_DONE) {
                    // No row present; return defaults on RO handle
                    ok = YES;
                } else {
                    err = [NSError errorWithDomain:@"ActivityStore" code:rc
                                          userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db))}];
                }
            } while (0);

            if (st) sqlite3_finalize(st);

            // >>> retain err BEFORE the pool drains so caller can safely use it
            if (err) [err retain];
        }

        // Signal from inside the DB queue (no hop to main → no deadlock)
        dispatch_semaphore_signal(sem);

    } completion:NULL];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = [err autorelease];
    else [err release]; // nil-safe

    return ok;
}


#pragma mark - Load all tracks (routed via performRead when available)


- (NSArray<Track *> *)loadAllTracks:(NSError **)error
                        totalTracks:(NSInteger)tt
                      progressBlock:(ASProgress)progress
{
    __block NSMutableArray *out = [NSMutableArray array];
    __block NSError *err = nil;

    void (^work)(sqlite3 *) = ^(sqlite3 *db){

        // First try with points_saved / points_count (new schema)
        const char *selA_with_flags =
          "SELECT id,uuid,name,creation_time_s,creation_time_override_s,"
          " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
          " device_total_time_s,moving_speed_only,has_distance_data,"
          " attributes_json, markers_json, override_json,"
          " seconds_from_gmt_at_sync, time_zone,"
          " flags, device_id, firmware_version,"
          " photo_urls_json, strava_activity_id,"
          " src_distance,src_max_speed,src_avg_heartrate,src_max_heartrate,src_avg_temperature,"
          " src_max_elevation,src_min_elevation,src_avg_power,src_max_power,src_avg_cadence,"
          " src_total_climb,src_kilojoules,src_elapsed_time_s,src_moving_time_s,"
          " local_media_items_json,"
          " COALESCE(points_saved,0),"
          " COALESCE(points_count,0) "
          "FROM activities ORDER BY creation_time_s;";

        // Fallback (older schema w/o points_saved/points_count)
        const char *selA_legacy =
          "SELECT id,uuid,name,creation_time_s,creation_time_override_s,"
          " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
          " device_total_time_s,moving_speed_only,has_distance_data,"
          " attributes_json, markers_json, override_json,"
          " seconds_from_gmt_at_sync, time_zone,"
          " flags, device_id, firmware_version,"
          " photo_urls_json, strava_activity_id,"
          " src_distance,src_max_speed,src_avg_heartrate,src_max_heartrate,src_avg_temperature,"
          " src_max_elevation,src_min_elevation,src_avg_power,src_max_power,src_avg_cadence,"
          " src_total_climb,src_kilojoules,src_elapsed_time_s,src_moving_time_s,"
          " local_media_items_json "
          "FROM activities ORDER BY creation_time_s;";

        sqlite3_stmt *a = NULL;
        BOOL hasPointsFlags = (sqlite3_prepare_v2(db, selA_with_flags, -1, &a, NULL) == SQLITE_OK);
        if (!hasPointsFlags) {
            if (sqlite3_prepare_v2(db, selA_legacy, -1, &a, NULL) != SQLITE_OK) {
                err = [NSError errorWithDomain:@"ActivityStore"
                                          code:sqlite3_errcode(db)
                                      userInfo:@{NSLocalizedDescriptionKey:
                                                 @(sqlite3_errmsg(db) ?: "load prepare failed")}];
                return;
            }
        }

        NSInteger total = tt;
        int idx = 0;

        while (sqlite3_step(a) == SQLITE_ROW) {
            if (progress) {
                progress(idx, total);
            }
            idx++;

            sqlite3_int64 trackID = sqlite3_column_int64(a, 0);

            Track *t = [Track new];

            // Core fields
            const unsigned char *uuidTxt = sqlite3_column_text(a, 1);
            NSString *uuid = uuidTxt ? [NSString stringWithUTF8String:(const char *)uuidTxt] : @"";

            NSString *name = (sqlite3_column_type(a,2)==SQLITE_NULL) ? @""
                            : [NSString stringWithUTF8String:(const char *)sqlite3_column_text(a,2)];

            NSDate *ct  = DateFromEpoch(sqlite3_column_int64(a,3));
            NSDate *cto = DateFromEpoch(sqlite3_column_int64(a,4));
            double dist = sqlite3_column_double(a,5);
            double wt   = sqlite3_column_double(a,6);
            double asf  = sqlite3_column_double(a,7);
            double eqw  = sqlite3_column_double(a,8);
            double devT = sqlite3_column_double(a,9);
            BOOL moving = sqlite3_column_int(a,10) != 0;
            BOOL hasD   = sqlite3_column_int(a,11) != 0;

            if ([t respondsToSelector:@selector(setUuid:)]) {
                [t setUuid:uuid];
            } else {
                @try { [t setValue:uuid forKey:@"uuid"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setName:)]) {
                [t setName:name];
            } else {
                @try { [t setValue:name forKey:@"name"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setCreationTime:)]) {
                [t setCreationTime:ct];
            } else {
                @try { [t setValue:ct forKey:@"creationTime"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setCreationTimeOverride:)]) {
                [t setCreationTimeOverride:cto];
            } else {
                @try { [t setValue:cto forKey:@"creationTimeOverride"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setDistance:)]) {
                [t setDistance:dist];
            } else {
                @try { [t setValue:@(dist) forKey:@"distance"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setWeight:)]) {
                [t setWeight:wt];
            } else {
                @try { [t setValue:@(wt) forKey:@"weight"]; } @catch (__unused id e) {}
            }
            if ([t respondsToSelector:@selector(setAltitudeSmoothingFactor:)]) {
                [t setAltitudeSmoothingFactor:asf];
            }
            if ([t respondsToSelector:@selector(setEquipmentWeight:)]) {
                [t setEquipmentWeight:eqw];
            }
            if ([t respondsToSelector:@selector(setDeviceTotalTime:)]) {
                [t setDeviceTotalTime:devT];
            }
            @try { [t setValue:@(moving) forKey:@"movingSpeedOnly"]; } @catch (__unused id e) {}
            @try { [t setValue:@(hasD)   forKey:@"hasDistanceData"]; } @catch (__unused id e) {}

            // JSON fields
            const unsigned char *attrsTxt    = sqlite3_column_text(a, 12);
            const unsigned char *markersTxt  = sqlite3_column_text(a, 13);
            const unsigned char *overrideTxt = sqlite3_column_text(a, 14);

            NSArray<NSString *> *attrs = AttributesFromJSONString(attrsTxt);
            NSMutableArray *attrsMut = [[attrs mutableCopy] autorelease];
            if ([t respondsToSelector:@selector(setAttributes:)]) {
                [t setAttributes:attrsMut];
            } else {
                @try { [t setValue:attrsMut forKey:@"attributes"]; } @catch (__unused id e) {}
            }

            NSArray *markers = MarkersFromJSONString(markersTxt);
            NSMutableArray *markersMut = [[markers mutableCopy] autorelease];
            if ([t respondsToSelector:@selector(setMarkers:)]) {
                [t setMarkers:markersMut];
            } else {
                @try { [t setValue:markersMut forKey:@"markers"]; } @catch (__unused id e) {}
            }

            OverrideData *od = OverrideFromJSON(overrideTxt);
            if (od) {
                if ([t respondsToSelector:@selector(setOverrideData:)]) {
                    [t performSelector:@selector(setOverrideData:) withObject:od];
                } else {
                    @try { [t setValue:od forKey:@"overrideData"]; } @catch (__unused id e) {}
                }
            }

            // TZ / flags / device info
            int secsFromGMT = sqlite3_column_int(a, 15);
            NSString *tzNameLoaded = (sqlite3_column_type(a,16) != SQLITE_NULL)
                                     ? [NSString stringWithUTF8String:(const char *)sqlite3_column_text(a, 16)]
                                     : nil;
            int flags = sqlite3_column_int(a, 17);
            int deviceID = sqlite3_column_int(a, 18);
            int firmwareVersion = sqlite3_column_int(a, 19);

            const unsigned char *photosTxt = sqlite3_column_text(a, 20);
            NSArray<NSURL *> *photoURLs = URLsFromJSONString(photosTxt);
            if ([t respondsToSelector:@selector(setPhotoURLs:)]) {
                [t setPhotoURLs:photoURLs];
            } else {
                @try { [t setValue:photoURLs forKey:@"photoURLs"]; } @catch (__unused id e) {}
            }

            NSNumber *sIDNum = (sqlite3_column_type(a, 21) != SQLITE_NULL)
                               ? [NSNumber numberWithLongLong:(long long)sqlite3_column_int64(a,21)]
                               : nil;

            if ([t respondsToSelector:@selector(setSecondsFromGMT:)]) {
                [t setSecondsFromGMT:secsFromGMT];
            }
            if ([t respondsToSelector:@selector(setFlags:)]) {
                [t setFlags:flags];
            }
            if ([t respondsToSelector:@selector(setDeviceID:)]) {
                [t setDeviceID:deviceID];
            }
            if ([t respondsToSelector:@selector(setFirmwareVersion:)]) {
                [t setFirmwareVersion:firmwareVersion];
            }

            if (tzNameLoaded.length) {
                if ([t respondsToSelector:@selector(setTimeZoneName:)]) {
                    [t setTimeZoneName:tzNameLoaded];
                } else {
                    @try { [t setValue:tzNameLoaded forKey:@"timeZone"]; } @catch (__unused id e) {}
                }
            }

            SETF(setSrcDistance,       22);
            SETF(setSrcMaxSpeed,       23);
            SETF(setSrcAvgHeartrate,   24);
            SETF(setSrcMaxHeartrate,   25);
            SETF(setSrcAvgTemperature, 26);
            SETF(setSrcMaxElevation,   27);
            SETF(setSrcMinElevation,   28);
            SETF(setSrcAvgPower,       29);
            SETF(setSrcMaxPower,       30);
            SETF(setSrcAvgCadence,     31);
            SETF(setSrcTotalClimb,     32);
            SETF(setSrcKilojoules,     33);
            SETD(setSrcElapsedTime,    34);
            SETD(setSrcMovingTime,     35);

            if ([t respondsToSelector:@selector(setStravaActivityID:)]) {
                [t setStravaActivityID:sIDNum];
            } else {
                @try { [t setValue:sIDNum forKey:@"stravaActivityID"]; } @catch (__unused id e) {}
            }

            const unsigned char *mediaTxt = sqlite3_column_text(a, 36);
            NSArray<NSString *> *localMediaItems = StringsFromJSONString(mediaTxt);
            if ([t respondsToSelector:@selector(setLocalMediaItems:)]) {
                [t setLocalMediaItems:localMediaItems];
            } else {
                @try { [t setValue:localMediaItems forKey:@"localMediaItems"]; } @catch (__unused id e) {}
            }

            // --- pointsEverSaved / pointsCount ---
            if (hasPointsFlags) {
                int psCol = 37;
                int pcCol = 38;
                BOOL ps = (sqlite3_column_type(a, psCol) == SQLITE_NULL) ? NO : (sqlite3_column_int(a, psCol) != 0);
                int  pc = (sqlite3_column_type(a, pcCol) == SQLITE_NULL) ? 0  : sqlite3_column_int(a, pcCol);

                NSLog(@"[ActStore] points_saved for %s: %s, calling setPointsEverSaved",[t.name UTF8String], (ps ? "YES" : "NO"));
                
                @try {
                    if ([t respondsToSelector:@selector(setPointsEverSaved:)]) {
                        [t setPointsEverSaved:ps];
                    } else {
                        [t setValue:@(ps) forKey:@"pointsEverSaved"];
                    }
                } @catch (__unused id e) {}

                @try {
                    if ([t respondsToSelector:@selector(setPointsCount:)]) {
                        [t setPointsCount:pc];
                    } else {
                        [t setValue:@(pc) forKey:@"pointsCount"];
                    }
                } @catch (__unused id e) {}
            } else {
                // Legacy fallback: set pointsEverSaved if any points exist for this trackID
                BOOL ps = NO;
                sqlite3_stmt *qp = NULL;
                if (sqlite3_prepare_v2(db, "SELECT 1 FROM points WHERE track_id=?1 LIMIT 1;", -1, &qp, NULL) == SQLITE_OK) {
                    sqlite3_bind_int64(qp, 1, trackID);
                    ps = (sqlite3_step(qp) == SQLITE_ROW);
                }
                if (qp) {
                    sqlite3_finalize(qp);
                }
                NSLog(@"[ActStore] no hasPointFlags, points saved for %s: %s, calling setPointsEverSaved",[t.name UTF8String], (ps ? "YES" : "NO"));
                @try {
                    if ([t respondsToSelector:@selector(setPointsEverSaved:)]) {
                        [t setPointsEverSaved:ps];
                    } else {
                        [t setValue:@(ps) forKey:@"pointsEverSaved"];
                    }
                } @catch (__unused id e) {}

                // pointsCount not available without an extra COUNT(*); skip for perf.
            }

            // Laps (no points)
            sqlite3_stmt *l = NULL;
            NSMutableArray *lapsArr = [NSMutableArray array];
            const char *selL =
              "SELECT lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
              " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,"
              " device_total_time_s,average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated"
              " FROM laps WHERE track_id=?1 ORDER BY lap_index;";

            if (sqlite3_prepare_v2(db, selL, -1, &l, NULL) == SQLITE_OK) {
                sqlite3_bind_int64(l, 1, trackID);
                while (sqlite3_step(l) == SQLITE_ROW) {
                    Lap *lp = [Lap new];
                    if ([lp respondsToSelector:@selector(setIndex:)])          { [lp setIndex:sqlite3_column_int(l,0)]; }
                    if ([lp respondsToSelector:@selector(setOrigStartTime:)])   { [lp setOrigStartTime:DateFromEpoch(sqlite3_column_int64(l,1))]; }
                    if ([lp respondsToSelector:@selector(setStartingWallClockTimeDelta:)]) { [lp setStartingWallClockTimeDelta:sqlite3_column_double(l,2)]; }
                    if ([lp respondsToSelector:@selector(setTotalTime:)])       { [lp setTotalTime:sqlite3_column_double(l,3)]; }
                    if ([lp respondsToSelector:@selector(setDistance:)])        { [lp setDistance:sqlite3_column_double(l,4)]; }
                    if ([lp respondsToSelector:@selector(setMaxSpeed:)])        { [lp setMaxSpeed:sqlite3_column_double(l,5)]; }
                    if ([lp respondsToSelector:@selector(setAvgSpeed:)])        { [lp setAvgSpeed:sqlite3_column_double(l,6)]; }
                    if ([lp respondsToSelector:@selector(setBeginLatitude:)])   { [lp setBeginLatitude:sqlite3_column_double(l,7)]; }
                    if ([lp respondsToSelector:@selector(setBeginLongitude:)])  { [lp setBeginLongitude:sqlite3_column_double(l,8)]; }
                    if ([lp respondsToSelector:@selector(setEndLatitude:)])     { [lp setEndLatitude:sqlite3_column_double(l,9)]; }
                    if ([lp respondsToSelector:@selector(setEndLongitude:)])    { [lp setEndLongitude:sqlite3_column_double(l,10)]; }
                    if ([lp respondsToSelector:@selector(setDeviceTotalTime:)]) { [lp setDeviceTotalTime:sqlite3_column_double(l,11)]; }
                    if ([lp respondsToSelector:@selector(setAvgHeartRate:)])    { [lp setAvgHeartRate:sqlite3_column_int(l,12)]; }
                    if ([lp respondsToSelector:@selector(setMaxHeartRate:)])    { [lp setMaxHeartRate:sqlite3_column_int(l,13)]; }
                    if ([lp respondsToSelector:@selector(setAverageCadence:)])  { [lp setAverageCadence:sqlite3_column_int(l,14)]; }
                    if ([lp respondsToSelector:@selector(setMaxCadence:)])      { [lp setMaxCadence:sqlite3_column_int(l,15)]; }
                    if ([lp respondsToSelector:@selector(setCalories:)])        { [lp setCalories:sqlite3_column_int(l,16)]; }
                    if ([lp respondsToSelector:@selector(setIntensity:)])       { [lp setIntensity:sqlite3_column_int(l,17)]; }
                    if ([lp respondsToSelector:@selector(setTriggerMethod:)])   { [lp setTriggerMethod:sqlite3_column_int(l,18)]; }
                    if ([lp respondsToSelector:@selector(setSelected:)])        { [lp setSelected:(sqlite3_column_int(l,19) != 0)]; }
                    if ([lp respondsToSelector:@selector(setStatsCalculated:)]) { [lp setStatsCalculated:(sqlite3_column_int(l,20) != 0)]; }
                    [lapsArr addObject:lp];
                    [lp release];
                }
                sqlite3_finalize(l);
            }
            @try { [t setValue:lapsArr forKey:@"laps"]; } @catch (__unused id e) {}

            [out addObject:t];
            if ([t respondsToSelector:@selector(fixupTrack)]) {
                [t fixupTrack];
            }
            [t release];
        }

        sqlite3_finalize(a);
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performRead:^(sqlite3 *db){ work(db); }
             completion:^{ dispatch_semaphore_signal(sem); }];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
    } else {
        work(_db);
    }

    if (err && error) {
        *error = err;
    }
    return out;
}

#pragma mark - Schema

#if 0
- (BOOL)ensureSchema:(NSError **)error {
    // If we don’t own the DB, don’t try to mutate schema here.
    if (!_ownsDB && !_dbm) return YES;

    __block BOOL ok = NO; __block NSError *err = nil;

    BOOL (^work)(sqlite3 *) = ^(sqlite3 *db){
        if (!ASCExecStrict(db, "PRAGMA foreign_keys=ON;", &err)) { ok = NO; return NO; }
        if (!ASCExecStrict(db, "BEGIN IMMEDIATE;", &err)) { ok = NO; return NO; }
        BOOL innerOK = NO;
        do {

            do {
                // ---- Tables ----
                // CREATE TABLE ... activities (append at the end)
                const char *createActivities =
                    "CREATE TABLE IF NOT EXISTS activities ("
                    " id INTEGER PRIMARY KEY,"
                    " uuid TEXT UNIQUE NOT NULL,"
                    " name TEXT,"
                    " creation_time_s INTEGER,"
                    " creation_time_override_s INTEGER,"
                    " distance_mi REAL,"
                    " weight_lb REAL,"
                    " altitude_smooth_factor REAL,"
                    " equipment_weight_lb REAL,"
                    " device_total_time_s REAL,"
                    " moving_speed_only INTEGER,"
                    " has_distance_data INTEGER,"
                    " attributes_json TEXT,"
                    " markers_json TEXT,"
                    " override_json TEXT,"
                    " seconds_from_gmt_at_sync INTEGER,"
                    " time_zone TEXT,"
                    " flags INTEGER,"
                    " device_id INTEGER,"
                    " firmware_version INTEGER,"
                    " photo_urls_json TEXT,"
                    " strava_activity_id INTEGER,"
                    " src_distance REAL,"
                    " src_max_speed REAL,"
                    " src_avg_heartrate REAL,"
                    " src_max_heartrate REAL,"
                    " src_avg_temperature REAL,"
                    " src_max_elevation REAL,"
                    " src_min_elevation REAL,"
                    " src_avg_power REAL,"
                    " src_max_power REAL,"
                    " src_avg_cadence REAL,"
                    " src_total_climb REAL,"
                    " src_kilojoules REAL,"
                    " src_elapsed_time_s REAL,"
                    " src_moving_time_s REAL,"
                    " local_media_items_json TEXT"          /* <-- NEW */
                    ");";
                if (!ASCExecStrict(_db, createActivities, error)) break;

                if (!ASCEnsureColumn(_db, "activities", "photo_urls_json", "TEXT", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "strava_activity_id", "INTEGER", error)) break;

                /* Ensure NEW columns exist on older DBs */
                if (!ASCEnsureColumn(_db, "activities", "src_distance",        "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_max_speed",       "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_avg_heartrate",   "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_max_heartrate",   "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_avg_temperature", "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_max_elevation",   "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_min_elevation",   "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_avg_power",       "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_max_power",       "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_avg_cadence",     "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_total_climb",     "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_kilojoules",      "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_elapsed_time_s",  "REAL", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "src_moving_time_s",   "REAL", error)) break;
                if (!ASCExecStrict(_db, createActivities, error)) break;
                if (!ASCEnsureColumn(_db, "activities", "photo_urls_json", "TEXT", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "strava_activity_id", "INTEGER", error)) break; // <-- NEW
                if (!ASCEnsureColumn(_db, "activities", "time_zone", "TEXT", error)) break;
                if (!ASCEnsureColumn(_db, "activities", "local_media_items_json", "TEXT", error)) break;
                
               const char *createLaps =
                    "CREATE TABLE IF NOT EXISTS laps ("
                    " id INTEGER PRIMARY KEY,"
                    " track_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,"
                    " lap_index INTEGER,"
                    " orig_start_time_s INTEGER,"
                    " start_time_delta_s REAL,"
                    " total_time_s REAL,"
                    " distance_mi REAL,"
                    " max_speed_mph REAL,"
                    " avg_speed_mph REAL,"
                    " begin_lat REAL,"
                    " begin_lon REAL,"
                    " end_lat REAL,"
                    " end_lon REAL,"
                    " device_total_time_s REAL,"
                    " average_hr INTEGER,"
                    " max_hr INTEGER,"
                    " average_cad INTEGER,"
                    " max_cad INTEGER,"
                    " calories INTEGER,"
                    " intensity INTEGER,"
                    " trigger_method INTEGER,"
                    " selected INTEGER,"
                    " stats_calculated INTEGER"
                    ");";
                if (!ASCExecStrict(_db, createLaps, error)) break;
         
                const char *createMeta =
                    "CREATE TABLE IF NOT EXISTS meta ("
                    " id INTEGER PRIMARY KEY CHECK(id=1),"
                    " uuid_s TEXT,"
                    " tableInfo_json TEXT,"
                    " splitsTableInfo_json TEXT,"
                    " startDate_s INTEGER,"
                    " endDate_s INTEGER,"
                    " lastSyncTime_s INTEGER,"
                    " flags INTEGER,"
                    " totalTracks INTEGER,"
                    " int3 INTEGER,"
                    " int4 INTEGER"
                    ");";
                if (!ASCExecStrict(_db, createMeta, error)) break;
                if (!ASCExecStrict(_db, "INSERT OR IGNORE INTO meta (id) VALUES (1);", error)) break;

                // ---- Indexes ----
                if (!ASCExecStrict(_db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_activities_uuid ON activities(uuid);", error)) break;
                if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_activities_ct ON activities(creation_time_s);", error)) break;
                if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_laps_track ON laps(track_id, lap_index);", error)) break;
                if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_points_track ON points(track_id, seq);", error)) break;

                ok = YES;
            } while (0);

            if (ok) {
                if (!ASCExecStrict(_db, "COMMIT;", error)) {
                    (void)sqlite3_exec(_db, "ROLLBACK;", NULL, NULL, NULL);
                    return NO;
                }
                return YES;
            } else {
                (void)sqlite3_exec(_db, "ROLLBACK;", NULL, NULL, NULL);
                return NO;
            }
            innerOK = YES;
        } while (0);

        if (innerOK) {
            if (!ASCExecStrict(db, "COMMIT;", &err)) { sqlite3_exec(db, "ROLLBACK;", NULL, NULL, NULL); ok = NO; return NO; }
            ok = YES;
        } else {
            sqlite3_exec(db, "ROLLBACK;", NULL, NULL, NULL);
            ok = NO;
        }
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail){ work(db); if (!ok && err) fail(err); }
                 completion:^(__unused NSError *e){ if (e && !err) err = e; dispatch_semaphore_signal(sem);}];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
    } else {
        work(_db);
    }

    if (!ok && error) *error = err;
    return ok;
}
#endif



#pragma mark - Schema

- (BOOL)createSchemaIfNeeded:(NSError **)error
{
    NSAssert(_dbm != nil, @"ActivityStore requires a DatabaseManager");
    if (_dbm.readOnly) return YES; // no-op in read-only sessions

    __block BOOL ok  = YES;
    __block NSError *err = nil;

    // If we're already on the DBM write queue, do it directly.
    if ([_dbm respondsToSelector:@selector(isOnWriteQueue)] && [_dbm isOnWriteQueue]) {
        ok = [self ensureSchemaOnDB:[_dbm rawSQLite] error:&err];
    } else {
        if ([_dbm respondsToSelector:@selector(performSyncOnWriteQueue:)]) {
            // Run synchronously on the write queue (no completion hop to main).
            [_dbm performSyncOnWriteQueue:^{
                ok = [self ensureSchemaOnDB:[_dbm rawSQLite] error:&err];
                if (err) err = [err retain]; // preserve across queue boundary (MRC)
            }];
            if (err) [err autorelease];
        } else {
            // Fallback if performSyncOnWriteQueue isn't available.
            dispatch_sync([_dbm writeQueue], ^{
                ok = [self ensureSchemaOnDB:[_dbm rawSQLite] error:&err];
                if (err) err = [err retain];
            });
            if (err) [err autorelease];
        }
    }
    
    if (!ok && error) *error = err;
    return ok;
}


- (BOOL)ensureSchemaOnDB:(sqlite3 *)db error:(NSError **)error
{
    const char *dbPath = sqlite3_db_filename(db, "main");
    int ro = sqlite3_db_readonly(db, "main");

    // Log current journal_mode so we know what stuck.
    sqlite3_stmt *j = NULL;
    const char *q = "PRAGMA journal_mode;";
    const char *mode = "unknown";
    if (sqlite3_prepare_v2(db, q, -1, &j, NULL) == SQLITE_OK) {
        if (sqlite3_step(j) == SQLITE_ROW) {
            mode = (const char *)sqlite3_column_text(j, 0);
        }
    }
    if (j) sqlite3_finalize(j);

    NSLog(@"[ActivityStore] ensureSchemaOnDB: path=%s readonly=%d journal_mode=%s",
          dbPath ? dbPath : "(null)", ro, mode ? mode : "(null)");

    // Try DEFERRED first (no immediate reserved lock).
    char *em = NULL;
    if (sqlite3_exec(db, "BEGIN DEFERRED;", NULL, NULL, &em) != SQLITE_OK) {
        if (error != NULL) {
            NSString *msg = [NSString stringWithFormat:@"BEGIN DEFERRED failed: %s", sqlite3_errmsg(db)];
            *error = [NSError errorWithDomain:@"ActivityStore"
                                         code:sqlite3_extended_errcode(db)
                                     userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        if (em) sqlite3_free(em);
        return NO;
    }
    if (em) { sqlite3_free(em); em = NULL; }

    BOOL ok = NO;
        do {
            // ---- Tables ----
            // CREATE TABLE ... activities (append at the end)
            const char *createActivities =
                "CREATE TABLE IF NOT EXISTS activities ("
                " id INTEGER PRIMARY KEY,"
                " uuid TEXT UNIQUE NOT NULL,"
                " name TEXT,"
                " creation_time_s INTEGER,"
                " creation_time_override_s INTEGER,"
                " distance_mi REAL,"
                " weight_lb REAL,"
                " altitude_smooth_factor REAL,"
                " equipment_weight_lb REAL,"
                " device_total_time_s REAL,"
                " moving_speed_only INTEGER,"
                " has_distance_data INTEGER,"
                " attributes_json TEXT,"
                " markers_json TEXT,"
                " override_json TEXT,"
                " seconds_from_gmt_at_sync INTEGER,"
                " time_zone TEXT,"
                " flags INTEGER,"
                " device_id INTEGER,"
                " firmware_version INTEGER,"
                " photo_urls_json TEXT,"
                " strava_activity_id INTEGER,"
                " src_distance REAL,"
                " src_max_speed REAL,"
                " src_avg_heartrate REAL,"
                " src_max_heartrate REAL,"
                " src_avg_temperature REAL,"
                " src_max_elevation REAL,"
                " src_min_elevation REAL,"
                " src_avg_power REAL,"
                " src_max_power REAL,"
                " src_avg_cadence REAL,"
                " src_total_climb REAL,"
                " src_kilojoules REAL,"
                " src_elapsed_time_s REAL,"
                " src_moving_time_s REAL,"
                " local_media_items_json TEXT"          /* <-- NEW */
                ");";
            if (!ASCExecStrict(_db, createActivities, error)) break;

            if (!ASCEnsureColumn(_db, "activities", "photo_urls_json", "TEXT", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "strava_activity_id", "INTEGER", error)) break;

            /* Ensure NEW columns exist on older DBs */
            if (!ASCEnsureColumn(_db, "activities", "src_distance",        "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_max_speed",       "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_avg_heartrate",   "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_max_heartrate",   "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_avg_temperature", "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_max_elevation",   "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_min_elevation",   "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_avg_power",       "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_max_power",       "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_avg_cadence",     "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_total_climb",     "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_kilojoules",      "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_elapsed_time_s",  "REAL", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "src_moving_time_s",   "REAL", error)) break;
            if (!ASCExecStrict(_db, createActivities, error)) break;
            if (!ASCEnsureColumn(_db, "activities", "photo_urls_json", "TEXT", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "strava_activity_id", "INTEGER", error)) break; // <-- NEW
            if (!ASCEnsureColumn(_db, "activities", "time_zone", "TEXT", error)) break;
            if (!ASCEnsureColumn(_db, "activities", "local_media_items_json", "TEXT", error)) break;
            
           const char *createLaps =
                "CREATE TABLE IF NOT EXISTS laps ("
                " id INTEGER PRIMARY KEY,"
                " track_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,"
                " lap_index INTEGER,"
                " orig_start_time_s INTEGER,"
                " start_time_delta_s REAL,"
                " total_time_s REAL,"
                " distance_mi REAL,"
                " max_speed_mph REAL,"
                " avg_speed_mph REAL,"
                " begin_lat REAL,"
                " begin_lon REAL,"
                " end_lat REAL,"
                " end_lon REAL,"
                " device_total_time_s REAL,"
                " average_hr INTEGER,"
                " max_hr INTEGER,"
                " average_cad INTEGER,"
                " max_cad INTEGER,"
                " calories INTEGER,"
                " intensity INTEGER,"
                " trigger_method INTEGER,"
                " selected INTEGER,"
                " stats_calculated INTEGER"
                ");";
            if (!ASCExecStrict(_db, createLaps, error)) break;
     
            const char *createMeta =
                "CREATE TABLE IF NOT EXISTS meta ("
                " id INTEGER PRIMARY KEY CHECK(id=1),"
                " uuid_s TEXT,"
                " tableInfo_json TEXT,"
                " splitsTableInfo_json TEXT,"
                " startDate_s INTEGER,"
                " endDate_s INTEGER,"
                " lastSyncTime_s INTEGER,"
                " flags INTEGER,"
                " totalTracks INTEGER,"
                " int3 INTEGER,"
                " int4 INTEGER"
                ");";
            if (!ASCExecStrict(_db, createMeta, error)) break;
            if (!ASCExecStrict(_db, "INSERT OR IGNORE INTO meta (id) VALUES (1);", error))
                break;

            // ---- Indexes ----
            if (!ASCExecStrict(_db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_activities_uuid ON activities(uuid);", error))
                break;
            if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_activities_ct ON activities(creation_time_s);", error))
                break;
            if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_laps_track ON laps(track_id, lap_index);", error))
                break;
            ///wtf if (!ASCExecStrict(_db, "CREATE INDEX IF NOT EXISTS idx_points_track ON points(track_id, seq);", error))
                ///break;

        ok = YES;
    } while (0);

    if (ok) {
        if (!ASCExecStrict(db, "COMMIT;", error)) {
            sqlite3_exec(db, "ROLLBACK;", NULL, NULL, NULL);
            return NO;
        }
        return YES;
    } else {
        sqlite3_exec(db, "ROLLBACK;", NULL, NULL, NULL);
        return NO;
    }
}


- (BOOL)trackIDForTrack:(Track *)track
                  outID:(sqlite3_int64 *)outID
                  error:(NSError **)error
{
    if (!track || !outID) { if (error) *error = [NSError errorWithDomain:@"ActivityStore"
                                                                    code:-1
                                                                userInfo:@{NSLocalizedDescriptionKey:@"Nil args"}]; return NO; }
    NSString *uuid = nil;
    if ([track respondsToSelector:@selector(uuid)]) uuid = [track uuid];
    else @try { uuid = [track valueForKey:@"uuid"]; } @catch (__unused id e) {}
    if (uuid.length == 0) { if (error) *error = [NSError errorWithDomain:@"ActivityStore"
                                                                    code:-2
                                                                userInfo:@{NSLocalizedDescriptionKey:@"Missing track uuid"}]; return NO; }

    __block BOOL ok = NO;
    __block NSError *err = nil;
    __block sqlite3_int64 tid = 0;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [_dbm performRead:^(sqlite3 *db) {
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &st, NULL) == SQLITE_OK) {
            sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(st) == SQLITE_ROW) tid = sqlite3_column_int64(st, 0);
        } else {
            err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                  userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "prepare id lookup failed")}];
        }
        if (st) sqlite3_finalize(st);
        ok = (tid != 0 && err == nil);
    } completion:^{ dispatch_semaphore_signal(sem);}];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = err ?: [NSError errorWithDomain:@"ActivityStore" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"No activities row for uuid"}];
    if (ok) *outID = tid;
    return ok;
}


// ActivityStore.m
- (BOOL)ensureActivityRowForTrack:(Track *)track
                         outTrackID:(int64_t *)outID
                              error:(NSError **)error
{
    if (track == nil || outID == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:@"ActivityStore"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey:@"Nil args"}];
        }
        return NO;
    }

    __block BOOL ok = YES;
    __block NSError *err = nil;
    __block int64_t tid = 0;

    void (^work)(sqlite3 *) = ^(sqlite3 *db) {
        NSString *uuid = [track respondsToSelector:@selector(uuid)] ? [track uuid] : nil;
        if (uuid.length == 0) {
            err = [NSError errorWithDomain:@"ActivityStore" code:-2
                                  userInfo:@{NSLocalizedDescriptionKey:@"Track uuid is required"}];
            ok = NO;
            return;
        }

        // Try to find it
        sqlite3_stmt *q = NULL;
        if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &q, NULL) == SQLITE_OK) {
            sqlite3_bind_text(q, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(q) == SQLITE_ROW) {
                tid = sqlite3_column_int64(q, 0);
            }
        }
        if (q) sqlite3_finalize(q);
        if (tid) {
            return; // already exists
        }

        // Insert a stub row with UUID; prefer RETURNING when available
        sqlite3_stmt *ins = NULL;
        const char *sqlRet =
            "INSERT INTO activities(uuid) VALUES(?1) "
            "ON CONFLICT(uuid) DO NOTHING "
            "RETURNING id;";
        int rc = sqlite3_prepare_v2(db, sqlRet, -1, &ins, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_text(ins, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(ins) == SQLITE_ROW) {
                tid = sqlite3_column_int64(ins, 0);
            }
            sqlite3_finalize(ins);
        }

        if (!tid) {
            sqlite3_stmt *ins2 = NULL;
            if (sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO activities(uuid) VALUES(?1);", -1, &ins2, NULL) != SQLITE_OK) {
                err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                      userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "prepare INSERT uuid failed")}];
                ok = NO;
                return;
            }
            sqlite3_bind_text(ins2, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(ins2) != SQLITE_DONE) {
                err = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(db)
                                      userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db) ?: "step INSERT uuid failed")}];
                sqlite3_finalize(ins2);
                ok = NO;
                return;
            }
            sqlite3_finalize(ins2);

            // re-select id
            sqlite3_stmt *sel = NULL;
            if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &sel, NULL) == SQLITE_OK) {
                sqlite3_bind_text(sel, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                if (sqlite3_step(sel) == SQLITE_ROW) {
                    tid = sqlite3_column_int64(sel, 0);
                }
            }
            if (sel) sqlite3_finalize(sel);
            if (!tid) {
                err = [NSError errorWithDomain:@"ActivityStore" code:-3
                                      userInfo:@{NSLocalizedDescriptionKey:@"Failed to create/find activities row"}];
                ok = NO;
            }
        }
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail){
            work(db);
            if (!ok && err) { fail(err); }
        } completion:^(__unused NSError *e){
            if (e && !err) { err = [e retain]; ok = NO; }
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
        if (err) { [err autorelease]; }
    } else {
        work(_db);
    }

    if (ok) {
        *outID = tid;
    } else if (error) {
        *error = err;
    }
    return ok;
}

@end
