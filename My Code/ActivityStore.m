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
    
    __block BOOL ok = YES; __block NSError *err = nil;

    void (^work)(sqlite3 *) = ^(sqlite3 *db){
        const char *sql =
          "UPDATE meta SET "
          " uuid_s=?, tableInfo_json=?, splitsTableInfo_json=?, "
          " startDate_s=?, endDate_s=?, lastSyncTime_s=?, "
          " flags=?, totalTracks=?, int3=?, int4=? "
          " WHERE id=1;";
        sqlite3_stmt *st = NULL;
        int rc = sqlite3_prepare_v2(db, sql, -1, &st, NULL);
        if (rc != SQLITE_OK)
        {
            ok = NO;
            err = [NSError errorWithDomain:@"ActivityStore" code:rc userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db))}];
            return;
        }

        NSString *d1 = JSONStringFromColumnInfoDict(tableInfoDict);
        NSString *d2 = JSONStringFromColumnInfoDict(splitsTableInfoDict);

        sqlite3_bind_text (st, 1,  uuid.UTF8String,                 -1, SQLITE_TRANSIENT);
        sqlite3_bind_text (st, 2, (d1?:@"").UTF8String,             -1, SQLITE_TRANSIENT);
        sqlite3_bind_text (st, 3, (d2?:@"").UTF8String,             -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(st, 4,  EpochFromDate(startDate));
        sqlite3_bind_int64(st, 5,  EpochFromDate(endDate));
        sqlite3_bind_int64(st, 6,  EpochFromDate(lastSyncTime));
        sqlite3_bind_int  (st, 7, (int)flags);
        sqlite3_bind_int  (st, 8, (int)i2);
        sqlite3_bind_int  (st, 9, (int)i3);
        sqlite3_bind_int  (st,10, (int)i4);

        rc = sqlite3_step(st);
        if (rc != SQLITE_DONE)
        {
            ok = NO;
            err = [NSError errorWithDomain:@"ActivityStore" code:rc userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db))}];
            NSLog(@"error during sqlite step %s", [[err description] UTF8String]);
        }
        sqlite3_finalize(st);
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail){ work(db); if (!ok) fail(err); }
                 completion:^(__unused NSError *e){ if (e && !err) err = e; dispatch_semaphore_signal(sem);}];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
    } else {
        work(_db);
    }

    if (!ok && error) *error = err;
    return ok;
}

#pragma mark - Save one / many tracks
// (identical to your version, but wrapped in _dbm writes where SQL occurs)

- (BOOL)saveTrack:(Track *)track error:(NSError **)error
{
    __block BOOL ok = YES; __block NSError *err = nil;

    BOOL (^work)(sqlite3 *) = ^(sqlite3 *db){
        // ---- Gather core activity fields ----
        NSString *uuid = [track respondsToSelector:@selector(uuid)] ? [track uuid] : [track valueForKey:@"uuid"];
        if (uuid.length == 0) {
            if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:-1
                                                userInfo:@{NSLocalizedDescriptionKey:@"Track uuid is required"}];
            return NO;
        }
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

        // ---- NEW fields ----
        int secondsFromGMT = [track respondsToSelector:@selector(secondsFromGMT)]
                                    ? [track secondsFromGMT]
                                    : [[track valueForKey:@"secondsFromGMT"] intValue];
        int flags           = [track respondsToSelector:@selector(flags)] ? [track flags] : [[track valueForKey:@"flags"] intValue];
        int deviceID        = [track respondsToSelector:@selector(deviceID)] ? [track deviceID] : [[track valueForKey:@"deviceID"] intValue];
        int firmwareVersion = [track respondsToSelector:@selector(firmwareVersion)] ? [track firmwareVersion] : [[track valueForKey:@"firmwareVersion"] intValue];

        NSArray<NSURL *> *photoURLs = nil;
        if ([track respondsToSelector:@selector(photoURLs)]) photoURLs = [track photoURLs];
        else @try { photoURLs = [track valueForKey:@"photoURLs"]; } @catch (__unused id e) {}
        NSString *photosJSON = URLsToJSON(photoURLs);

        NSArray<NSString *> *localMedia = nil;
        if ([track respondsToSelector:@selector(localMediaItems)]) localMedia = [track localMediaItems];
        else @try { localMedia = [track valueForKey:@"localMediaItems"]; } @catch (__unused id e) {}
        NSString *localMediaJSON = StringsToJSON(localMedia);   // "[]" if nil/empty

        // ---- NEW: source stats on the Track ----
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
        else @try { stravaActivityID = [track valueForKey:@"stravaActivityID"]; } @catch (__unused id e) {}    // Arrays / JSON fields
        
        NSString *tzName = nil;
        if ([track respondsToSelector:@selector(timeZoneName)]) {
            tzName = [track timeZoneName];
        } else if ([track respondsToSelector:@selector(timeZone)]) {
            id tz = [track timeZoneName];
            if ([tz isKindOfClass:[NSTimeZone class]])       tzName = [(NSTimeZone *)tz name];
            else if ([tz isKindOfClass:[NSString class]])     tzName = (NSString *)tz;
        } else {
            @try { tzName = [track valueForKey:@"timeZone"]; } @catch (__unused id e) {}
        }

        NSArray *attrs   = [track respondsToSelector:@selector(attributes)] ? [track attributes] : [track valueForKey:@"attributes"];
        NSArray *markers = [track respondsToSelector:@selector(markers)]    ? [track markers]    : [track valueForKey:@"markers"];
        id       od      = nil;
        if ([track respondsToSelector:@selector(overrideData)]) od = [track performSelector:@selector(overrideData)];
        else @try { od = [track valueForKey:@"overrideData"]; } @catch (__unused id e) {}

        NSString *attrsJSON    = AttributesToJSON(attrs);
        NSString *markersJSON  = MarkersToJSON(markers);
        NSString *overrideJSON = OverrideToJSON(od);

        // ---- Upsert activity row (includes new columns) ----
        sqlite3_stmt *act = NULL;
        
        const char *upsert =
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
        " local_media_items_json"                     /* <-- NEW */
        ") VALUES ("
        " ?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20,"
        " ?21,?22,?23,?24,?25,?26,?27,?28,?29,?30,?31,?32,?33,?34,?35,?36"         /* <-- NEW ?36 */
        ") ON CONFLICT(uuid) DO UPDATE SET "
        " name=excluded.name,"
        " creation_time_s=excluded.creation_time_s,"
        " creation_time_override_s=excluded.creation_time_override_s,"
        " distance_mi=excluded.distance_mi,"
        " weight_lb=excluded.weight_lb,"
        " altitude_smooth_factor=excluded.altitude_smooth_factor,"
        " equipment_weight_lb=excluded.equipment_weight_lb,"
        " device_total_time_s=excluded.device_total_time_s,"
        " moving_speed_only=excluded.moving_speed_only,"
        " has_distance_data=excluded.has_distance_data,"
        " attributes_json=excluded.attributes_json,"
        " markers_json=excluded.markers_json,"
        " override_json=excluded.override_json,"
        " seconds_from_gmt_at_sync=excluded.seconds_from_gmt_at_sync,"
        " time_zone=excluded.time_zone,"
        " flags=excluded.flags,"
        " device_id=excluded.device_id,"
        " firmware_version=excluded.firmware_version,"
        " photo_urls_json=excluded.photo_urls_json,"
        " strava_activity_id=excluded.strava_activity_id,"
        " src_distance=excluded.src_distance,"
        " src_max_speed=excluded.src_max_speed,"
        " src_avg_heartrate=excluded.src_avg_heartrate,"
        " src_max_heartrate=excluded.src_max_heartrate,"
        " src_avg_temperature=excluded.src_avg_temperature,"
        " src_max_elevation=excluded.src_max_elevation,"
        " src_min_elevation=excluded.src_min_elevation,"
        " src_avg_power=excluded.src_avg_power,"
        " src_max_power=excluded.src_max_power,"
        " src_avg_cadence=excluded.src_avg_cadence,"
        " src_total_climb=excluded.src_total_climb,"
        " src_kilojoules=excluded.src_kilojoules,"
        " src_elapsed_time_s=excluded.src_elapsed_time_s,"
        " src_moving_time_s=excluded.src_moving_time_s,"
        " local_media_items_json=excluded.local_media_items_json"; /* <-- NEW */

        NSArray *laps = [track respondsToSelector:@selector(laps)] ? [track laps] : [track valueForKey:@"laps"];
        sqlite3_stmt *sel = NULL;
        sqlite3_int64 trackID = 0;

        if (sqlite3_prepare_v2(_db, upsert, -1, &act, NULL) != SQLITE_OK) goto fail;

        sqlite3_bind_text  (act, 1,  uuid.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text  (act, 2,  (name?:@"").UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64 (act, 3,  ct  ? (sqlite3_int64)llround(ct.timeIntervalSince1970)  : 0);
        sqlite3_bind_int64 (act, 4,  cto ? (sqlite3_int64)llround(cto.timeIntervalSince1970) : 0);
        sqlite3_bind_double(act, 5,  distance);
        sqlite3_bind_double(act, 6,  weight);
        sqlite3_bind_double(act, 7,  asf);
        sqlite3_bind_double(act, 8,  eqw);
        sqlite3_bind_double(act, 9,  devTime);
        sqlite3_bind_int   (act,10,  moving ? 1 : 0);
        sqlite3_bind_int   (act,11,  hasDist ? 1 : 0);
        sqlite3_bind_text  (act,12,  (attrsJSON    ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
        sqlite3_bind_text  (act,13,  (markersJSON  ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
        sqlite3_bind_text  (act,14,  (overrideJSON ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
        sqlite3_bind_int   (act,15,  secondsFromGMT);
        // NEW ?16: time_zone string (nullable)
        if (tzName.length) sqlite3_bind_text(act,16, tzName.UTF8String, -1, SQLITE_TRANSIENT);
        else               sqlite3_bind_null(act,16);

        sqlite3_bind_int   (act,17,  flags);
        sqlite3_bind_int   (act,18,  deviceID);
        sqlite3_bind_int   (act,19,  firmwareVersion);
        sqlite3_bind_text  (act,20, (photosJSON ?: @"").UTF8String, -1, SQLITE_TRANSIENT);

        // strava_activity_id now ?21
        if (stravaActivityID) sqlite3_bind_int64(act,21, (sqlite3_int64)stravaActivityID.longLongValue);
        else                  sqlite3_bind_null (act,21);

        // src* shift by +1: now 22..35
        sqlite3_bind_double(act, 22, srcDistance);
        sqlite3_bind_double(act, 23, srcMaxSpeed);
        sqlite3_bind_double(act, 24, srcAvgHeartrate);
        sqlite3_bind_double(act, 25, srcMaxHeartrate);
        sqlite3_bind_double(act, 26, srcAvgTemperature);
        sqlite3_bind_double(act, 27, srcMaxElevation);
        sqlite3_bind_double(act, 28, srcMinElevation);
        sqlite3_bind_double(act, 29, srcAvgPower);
        sqlite3_bind_double(act, 30, srcMaxPower);
        sqlite3_bind_double(act, 31, srcAvgCadence);
        sqlite3_bind_double(act, 32, srcTotalClimb);
        sqlite3_bind_double(act, 33, srcKilojoules);
        sqlite3_bind_double(act, 34, srcElapsedTime);
        sqlite3_bind_double(act, 35, srcMovingTime);
        sqlite3_bind_text(act, 36, (localMediaJSON ?: @"[]").UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(act) != SQLITE_DONE) goto fail;
        sqlite3_finalize(act); act = NULL;
     
        // ---- Look up track_id from uuid ----
        if (sqlite3_prepare_v2(_db, "SELECT id FROM activities WHERE uuid=?", -1, &sel, NULL) != SQLITE_OK) goto fail;
        sqlite3_bind_text(sel, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sel) == SQLITE_ROW) trackID = sqlite3_column_int64(sel, 0);
        sqlite3_finalize(sel); sel = NULL;
        if (!trackID) goto fail;

        // ---- Replace children (laps/points) in a transaction ----
        sqlite3_exec(_db, "BEGIN IMMEDIATE;", NULL, NULL, NULL);

        for (const char *sqlDel : (const char*[]){"DELETE FROM laps WHERE track_id=?;", "DELETE FROM points WHERE track_id=?;"}) {
            sqlite3_stmt *d=NULL; sqlite3_prepare_v2(_db, sqlDel, -1, &d, NULL);
            sqlite3_bind_int64(d, 1, trackID); sqlite3_step(d); sqlite3_finalize(d);
        }

        // Laps
         if ([laps isKindOfClass:NSArray.class] && laps.count) {
            const char *insLap =
              "INSERT INTO laps (track_id,lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
              " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,device_total_time_s,"
              " average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated)"
              " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
             sqlite3_stmt *lapStmt=NULL;
             sqlite3_prepare_v2(_db, insLap, -1, &lapStmt, NULL);
             for (Lap* lap in laps) {
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
                sqlite3_bind_int   (lapStmt,21, [lap respondsToSelector:@selector(selected)] ? ([lap selected] ? 1:0) : ([[lap valueForKey:@"selected"] boolValue] ? 1:0));
                sqlite3_bind_int   (lapStmt,22, [lap respondsToSelector:@selector(statsCalculated)] ? ([lap statsCalculated] ? 1:0) : ([[lap valueForKey:@"statsCalculated"] boolValue] ? 1:0));
                if (sqlite3_step(lapStmt) != SQLITE_DONE) { /* ignore individual lap failures or handle as needed */ }
                sqlite3_reset(lapStmt);
            }
            sqlite3_finalize(lapStmt);
        }


        sqlite3_exec(_db, "COMMIT;", NULL, NULL, NULL);
        return YES;

    fail:
        if (act) sqlite3_finalize(act);
        sqlite3_exec(_db, "ROLLBACK;", NULL, NULL, NULL);
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
                                             userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db) ?: "saveTrack failed")}];
        return NO;
    };

    if (_dbm) {
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail){ work(db); if (!ok) fail(err); }
                 completion:^(__unused NSError *e){ if (e && !err) err = e; dispatch_semaphore_signal(sem);}];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_release(sem);
    } else {
        work(_db);
    }

    if (!ok && error) *error = err;
    return ok;
}

- (BOOL)saveAllTracks:(NSArray *)tracks
                error:(NSError **)error
        progressBlock:(ASProgress)progress
{
    if (tracks.count == 0) return YES;
    NSUInteger numTracks = tracks.count;
    NSUInteger idx = 0;

    for (Track *t in tracks) {
        if (progress) progress(idx, numTracks);
        NSError *err = nil;
        if (![self saveTrack:t error:&err]) {
            if (error) {
                NSString *uuid = nil;
                if ([t respondsToSelector:@selector(uuid)]) uuid = [t uuid];
                else @try { uuid = [t valueForKey:@"uuid"]; } @catch (__unused id e) {}
                NSMutableDictionary *info = [err.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                info[@"index"] = @(idx);
                if (uuid) info[@"uuid"] = uuid;
                *error = [NSError errorWithDomain:@"ActivityStore"
                                             code:err.code ?: -1
                                         userInfo:info];
                [info release];
            }
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

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [_dbm performRead:^(sqlite3 *db) {
        @autoreleasepool { // ensure any autoreleases are contained

            const char *sql =
              "SELECT id, uuid_s, tableInfo_json, splitsTableInfo_json, "
              "       startDate_s, endDate_s, lastSyncTime_s, "
              "       flags, totalTracks, int3, int4 "
              "FROM meta WHERE id=1;";

            sqlite3_stmt *st = NULL;
            int rc = sqlite3_prepare_v2(db, sql, -1, &st, NULL);
            if (rc != SQLITE_OK) {
                err = [NSError errorWithDomain:@"ActivityStore" code:rc
                                       userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(db))}];
                goto done;
            }

            if (sqlite3_step(st) == SQLITE_ROW) {
                // Build RETAINED/COPIED results
                if (outUuid) {
                    const unsigned char *uuidTxt = sqlite3_column_text(st, 1);
                    *outUuid = uuidTxt ? [[NSString alloc] initWithUTF8String:(const char *)uuidTxt] : nil;
                }
                if (outTableInfo) {
                    NSDictionary *ti = ColumnInfoDictFromJSONText(sqlite3_column_text(st, 2));
                    *outTableInfo = [ti copy]; // immutable copy == retain
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
            } else {
                // Ensure default singleton row exists; return defaults (also retained/copy where needed)
                (void)sqlite3_finalize(st); st = NULL;
                (void)sqlite3_exec(db, "INSERT OR IGNORE INTO meta (id) VALUES (1);", NULL, NULL, NULL);

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

                ok = YES;
            }

        done:
            if (st) sqlite3_finalize(st);
        }
    } completion:^{
        dispatch_semaphore_signal(sem);
    }];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = err;
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
        const char *selA =
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
        if (sqlite3_prepare_v2(db, selA, -1, &a, NULL) != SQLITE_OK) {
            err = [NSError errorWithDomain:@"ActivityStore"
                                      code:sqlite3_errcode(db)
                                  userInfo:@{NSLocalizedDescriptionKey:
                                             @(sqlite3_errmsg(db) ?: "load prepare failed")}];
            return;
        }

        NSInteger total = tt;
        int idx = 0;

        while (sqlite3_step(a) == SQLITE_ROW) {
            if (progress) progress(idx++, total);

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
            BOOL moving = sqlite3_column_int(a,10)!=0;
            BOOL hasD   = sqlite3_column_int(a,11)!=0;

            if ([t respondsToSelector:@selector(setUuid:)]) [t setUuid:uuid]; else @try { [t setValue:uuid forKey:@"uuid"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setName:)]) [t setName:name]; else @try { [t setValue:name forKey:@"name"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setCreationTime:)]) [t setCreationTime:ct]; else @try { [t setValue:ct forKey:@"creationTime"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setCreationTimeOverride:)]) [t setCreationTimeOverride:cto]; else @try { [t setValue:cto forKey:@"creationTimeOverride"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setDistance:)]) [t setDistance:dist]; else @try { [t setValue:@(dist) forKey:@"distance"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setWeight:)]) [t setWeight:wt]; else @try { [t setValue:@(wt) forKey:@"weight"]; } @catch (__unused id e) {}
            if ([t respondsToSelector:@selector(setAltitudeSmoothingFactor:)]) [t setAltitudeSmoothingFactor:asf];
            if ([t respondsToSelector:@selector(setEquipmentWeight:)])       [t setEquipmentWeight:eqw];
            if ([t respondsToSelector:@selector(setDeviceTotalTime:)])       [t setDeviceTotalTime:devT];
            @try { [t setValue:@(moving) forKey:@"movingSpeedOnly"]; } @catch (__unused id e) {}
            @try { [t setValue:@(hasD)   forKey:@"hasDistanceData"]; } @catch (__unused id e) {}

            // JSON fields
            const unsigned char *attrsTxt    = sqlite3_column_text(a, 12);
            const unsigned char *markersTxt  = sqlite3_column_text(a, 13);
            const unsigned char *overrideTxt = sqlite3_column_text(a, 14);

            NSArray<NSString *> *attrs = AttributesFromJSONString(attrsTxt);
            NSMutableArray *attrsMut = [[attrs mutableCopy] autorelease];
            if ([t respondsToSelector:@selector(setAttributes:)]) [t setAttributes:attrsMut]; else @try { [t setValue:attrsMut forKey:@"attributes"]; } @catch (__unused id e) {}

            NSArray *markers = MarkersFromJSONString(markersTxt);
            NSMutableArray *markersMut = [[markers mutableCopy] autorelease];
            if ([t respondsToSelector:@selector(setMarkers:)]) [t setMarkers:markersMut]; else @try { [t setValue:markersMut forKey:@"markers"]; } @catch (__unused id e) {}

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
            if ([t respondsToSelector:@selector(setPhotoURLs:)]) { [t setPhotoURLs:photoURLs]; }
            else @try { [t setValue:photoURLs forKey:@"photoURLs"]; } @catch (__unused id e) {}

            NSNumber *sIDNum = (sqlite3_column_type(a, 21) != SQLITE_NULL)
                               ? [NSNumber numberWithLongLong:(long long)sqlite3_column_int64(a,21)]
                               : nil;

            if ([t respondsToSelector:@selector(setSecondsFromGMT:)]) [t setSecondsFromGMT:secsFromGMT];
            if ([t respondsToSelector:@selector(setFlags:)])          [t setFlags:flags];
            if ([t respondsToSelector:@selector(setDeviceID:)])       [t setDeviceID:deviceID];
            if ([t respondsToSelector:@selector(setFirmwareVersion:)])[t setFirmwareVersion:firmwareVersion];

            if (tzNameLoaded.length) {
                if ([t respondsToSelector:@selector(setTimeZoneName:)]) [t setTimeZoneName:tzNameLoaded];
                else @try { [t setValue:tzNameLoaded forKey:@"timeZone"]; } @catch (__unused id e) {}
            }

            // src* metrics
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

            if ([t respondsToSelector:@selector(setStravaActivityID:)]) [t setStravaActivityID:sIDNum];
            else @try { [t setValue:sIDNum forKey:@"stravaActivityID"]; } @catch (__unused id e) {}

            const unsigned char *mediaTxt = sqlite3_column_text(a, 36);
            NSArray<NSString *> *localMediaItems = StringsFromJSONString(mediaTxt);
            if ([t respondsToSelector:@selector(setLocalMediaItems:)]) {
                [t setLocalMediaItems:localMediaItems];
            } else {
                @try { [t setValue:localMediaItems forKey:@"localMediaItems"]; } @catch (__unused id e) {}
            }

            // Laps (no points) — use the same 'db' (not _db)
            sqlite3_stmt *l = NULL;
            NSMutableArray *lapsArr = [NSMutableArray array];
            const char *selL =
              "SELECT lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
              " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,"
              " device_total_time_s,average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated"
              " FROM laps WHERE track_id=? ORDER BY lap_index;";

            if (sqlite3_prepare_v2(db, selL, -1, &l, NULL) == SQLITE_OK) {
                sqlite3_bind_int64(l, 1, trackID);
                while (sqlite3_step(l) == SQLITE_ROW) {
                    Lap *lp = [Lap new];
                    if ([lp respondsToSelector:@selector(setIndex:)])          [lp setIndex:sqlite3_column_int(l,0)];
                    if ([lp respondsToSelector:@selector(setOrigStartTime:)])   [lp setOrigStartTime:DateFromEpoch(sqlite3_column_int64(l,1))];
                    if ([lp respondsToSelector:@selector(setStartingWallClockTimeDelta:)])  [lp setStartingWallClockTimeDelta:sqlite3_column_double(l,2)];
                    if ([lp respondsToSelector:@selector(setTotalTime:)])       [lp setTotalTime:sqlite3_column_double(l,3)];
                    if ([lp respondsToSelector:@selector(setDistance:)])        [lp setDistance:sqlite3_column_double(l,4)];
                    if ([lp respondsToSelector:@selector(setMaxSpeed:)])        [lp setMaxSpeed:sqlite3_column_double(l,5)];
                    if ([lp respondsToSelector:@selector(setAvgSpeed:)])        [lp setAvgSpeed:sqlite3_column_double(l,6)];
                    if ([lp respondsToSelector:@selector(setBeginLatitude:)])   [lp setBeginLatitude:sqlite3_column_double(l,7)];
                    if ([lp respondsToSelector:@selector(setBeginLongitude:)])  [lp setBeginLongitude:sqlite3_column_double(l,8)];
                    if ([lp respondsToSelector:@selector(setEndLatitude:)])     [lp setEndLatitude:sqlite3_column_double(l,9)];
                    if ([lp respondsToSelector:@selector(setEndLongitude:)])    [lp setEndLongitude:sqlite3_column_double(l,10)];
                    if ([lp respondsToSelector:@selector(setDeviceTotalTime:)]) [lp setDeviceTotalTime:sqlite3_column_double(l,11)];
                    if ([lp respondsToSelector:@selector(setAvgHeartRate:)])    [lp setAvgHeartRate:sqlite3_column_int(l,12)];
                    if ([lp respondsToSelector:@selector(setMaxHeartRate:)])    [lp setMaxHeartRate:sqlite3_column_int(l,13)];
                    if ([lp respondsToSelector:@selector(setAverageCadence:)])  [lp setAverageCadence:sqlite3_column_int(l,14)];
                    if ([lp respondsToSelector:@selector(setMaxCadence:)])      [lp setMaxCadence:sqlite3_column_int(l,15)];
                    if ([lp respondsToSelector:@selector(setCalories:)])        [lp setCalories:sqlite3_column_int(l,16)];
                    if ([lp respondsToSelector:@selector(setIntensity:)])       [lp setIntensity:sqlite3_column_int(l,17)];
                    if ([lp respondsToSelector:@selector(setTriggerMethod:)])   [lp setTriggerMethod:sqlite3_column_int(l,18)];
                    if ([lp respondsToSelector:@selector(setSelected:)])        [lp setSelected:(sqlite3_column_int(l,19)!=0)];
                    if ([lp respondsToSelector:@selector(setStatsCalculated:)]) [lp setStatsCalculated:(sqlite3_column_int(l,20)!=0)];
                    [lapsArr addObject:lp];
                    [lp release];
                }
                sqlite3_finalize(l);
            }
            @try { [t setValue:lapsArr forKey:@"laps"]; } @catch (__unused id e) {}

            [out addObject:t];
            if ([t respondsToSelector:@selector(fixupTrack)]) [t fixupTrack];
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
        // Fallback if you constructed ActivityStore with a raw sqlite3*
        work(_db);
    }

    if (err && error) *error = err;
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

// ActivityStore.m  (MRC)
- (BOOL)createSchemaIfNeeded:(NSError **)error {
    NSAssert(_dbm != nil, @"ActivityStore requires a DatabaseManager");
    if (_dbm.readOnly) return YES;  // no-op in read-only sessions

    __block BOOL ok = YES;
    __block NSError *completedErr = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
        // Do NOT begin/commit here; DatabaseManager already wrapped us in a txn.
        NSError *local = nil;
        if (![self ensureSchemaOnDB:db error:&local]) {
            ok = NO;
            // Tell DBM the write failed (forces ROLLBACK). Pass the concrete error if we have one.
            fail(local ?: [NSError errorWithDomain:@"Ascent.DB.ActivityStore"
                                              code:1
                                          userInfo:@{NSLocalizedDescriptionKey:@"ensureSchemaOnDB failed"}]);
        }
    } completion:^(NSError * _Nullable e) {
        // Capture the transaction error (if any) exactly once.
        if (e && !completedErr) completedErr = [e retain];
        dispatch_semaphore_signal(sem);
    }];

    // Wait for write to finish before returning.
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = [completedErr autorelease];
    else if (completedErr) [completedErr release]; // no out-error requested; clean up

    return ok;
}


- (BOOL)ensureSchemaOnDB:(sqlite3 *)db error:(NSError **)error {

    BOOL ok = NO;
    do {
        // --- activities ---
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
        " local_media_items_json TEXT,"
        " gpx_filename TEXT"
        ");";
        if (!ASCExecStrict(db, createActivities, error)) break;

        // make sure newer columns exist
        if (!ASCEnsureColumn(db, "activities", "photo_urls_json",       "TEXT",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "strava_activity_id",    "INTEGER", error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_distance",          "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_max_speed",         "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_avg_heartrate",     "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_max_heartrate",     "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_avg_temperature",   "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_max_elevation",     "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_min_elevation",     "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_avg_power",         "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_max_power",         "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_avg_cadence",       "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_total_climb",       "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_kilojoules",        "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_elapsed_time_s",    "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "src_moving_time_s",     "REAL",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "time_zone",             "TEXT",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "local_media_items_json","TEXT",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "gpx_filename",          "TEXT",    error)) break;
        if (!ASCEnsureColumn(db, "activities", "seconds_from_gmt_at_sync","INTEGER",error)) break;

        // --- laps ---
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
        if (!ASCExecStrict(db, createLaps, error)) break;

        // --- meta ---
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
        if (!ASCExecStrict(db, createMeta, error)) break;
        if (!ASCExecStrict(db, "INSERT OR IGNORE INTO meta (id) VALUES (1);", error)) break;

        // --- indexes ---
        if (!ASCExecStrict(db, "CREATE UNIQUE INDEX IF NOT EXISTS idx_activities_uuid ON activities(uuid);", error)) break;
        if (!ASCExecStrict(db, "CREATE INDEX IF NOT EXISTS idx_activities_ct ON activities(creation_time_s);", error)) break;
        if (!ASCExecStrict(db, "CREATE INDEX IF NOT EXISTS idx_laps_track ON laps(track_id, lap_index);", error)) break;

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



@end
