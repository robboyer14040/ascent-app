//
//  ActivityStore.m
//  Ascent
//
//  Created by Rob Boyer on 8/20/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "ActivityStore.h"

// Your model headers (public enough for selectors/KVC)
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "PathMarker.h"
#import "OverrideData.h"
#import "ColumnInfo.h"


#import <objc/runtime.h>

@implementation ActivityStore {
    sqlite3 *_db;
    NSURL *_url;
}

- (instancetype)initWithURL:(NSURL *)dbURL {
    if ((self = [super init])) { _url = dbURL; }
    return self;
}

- (BOOL)open:(NSError **)error {
    if (_db) return YES;
    int rc = sqlite3_open(_url.path.UTF8String, &_db);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:rc
            userInfo:@{NSLocalizedDescriptionKey: @(sqlite3_errmsg(_db) ?: "sqlite open failed")}];
        return NO;
    }
    sqlite3_exec(_db, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_exec(_db, "PRAGMA synchronous=NORMAL;", NULL, NULL, NULL);
    sqlite3_exec(_db, "PRAGMA foreign_keys=ON;", NULL, NULL, NULL);
    return YES;
}

- (void)close {
    if (_db) { sqlite3_close(_db); _db = NULL; }
}

#pragma mark - Schema

#if 1


- (BOOL)createSchema:(NSError **)error
{
    // _db is your opened sqlite3 *

    // Helper: run SQL, optionally strict (fail) vs tolerant (ignore errors like "duplicate column")
    BOOL (^run)(const char *sql, BOOL strict) = ^BOOL(const char *sql, BOOL strict) {
        char *errmsg = NULL;
        int rc = sqlite3_exec(_db, sql, NULL, NULL, &errmsg);
        if (rc != SQLITE_OK) {
            if (strict) {
                if (error) {
                    NSString *msg = errmsg ? [NSString stringWithUTF8String:errmsg] : @"SQLite error";
                    *error = [NSError errorWithDomain:@"ActivityStore"
                                                 code:rc
                                             userInfo:@{NSLocalizedDescriptionKey: msg}];
                }
                if (errmsg) { sqlite3_free(errmsg); errmsg = NULL; }
                return NO;
            }
            // tolerant path: swallow errors (e.g., duplicate column/index)
            if (errmsg) { sqlite3_free(errmsg); errmsg = NULL; }
        }
        return YES;
    };

    // Pragmas (safe defaults)
    if (!run("PRAGMA foreign_keys = ON;", YES)) return NO;
    run("PRAGMA journal_mode = WAL;", NO);
    run("PRAGMA synchronous = NORMAL;", NO);

    // ---- Tables -------------------------------------------------------------

    // activities: includes new columns
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
        " seconds_from_gmt_at_sync INTEGER,"   /* NEW */
        " flags INTEGER,"                      /* NEW */
        " device_id INTEGER,"                  /* NEW */
        " firmware_version INTEGER"            /* NEW */
        ");";
    if (!run(createActivities, YES)) return NO;

    // laps
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
    if (!run(createLaps, YES)) return NO;

//    "INSERT INTO points (track_id,seq,wall_clock_delta_s,active_time_delta_s,latitude,longitude,"
//    " orig_altitude_m,heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,"
//    " orig_distance_mi,flags)"
//    " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
    // points
    const char *createPoints =
        "CREATE TABLE IF NOT EXISTS points ("
        " id INTEGER PRIMARY KEY,"
        " track_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,"
        " seq INTEGER,"
        " wall_clock_delta_s REAL,"
        " active_time_delta_s REAL,"
        " latitude REAL,"
        " longitude REAL,"
        " orig_altitude_m REAL,"
        " heartrate_bpm REAL,"
        " cadence_rpm REAL,"
        " temperature_c REAL,"
        " speed_mps REAL,"
        " power_w REAL,"
        " orig_distance_mi REAL,"
        " flags INTEGER"
        ");";
    if (!run(createPoints, YES)) return NO;

    // ---- Indexes ------------------------------------------------------------

    run("CREATE UNIQUE INDEX IF NOT EXISTS idx_activities_uuid ON activities(uuid);", NO);
    run("CREATE INDEX IF NOT EXISTS idx_activities_ct ON activities(creation_time_s);", NO);
    run("CREATE INDEX IF NOT EXISTS idx_laps_track ON laps(track_id, lap_index);", NO);
    run("CREATE INDEX IF NOT EXISTS idx_points_track ON points(track_id, seq);", NO);

    // ---- Tolerant migrations (add columns if the DB was created before) ----

    // JSON columns (older DBs may miss these)
    run("ALTER TABLE activities ADD COLUMN attributes_json TEXT;", NO);
    run("ALTER TABLE activities ADD COLUMN markers_json TEXT;", NO);
    run("ALTER TABLE activities ADD COLUMN override_json TEXT;", NO);

    // device total time (older DBs may miss this too)
    run("ALTER TABLE activities ADD COLUMN device_total_time_s REAL;", NO);

    // NEW scalar columns requested
    run("ALTER TABLE activities ADD COLUMN seconds_from_gmt_at_sync INTEGER;", NO);
    run("ALTER TABLE activities ADD COLUMN flags INTEGER;", NO);
    run("ALTER TABLE activities ADD COLUMN device_id INTEGER;", NO);
    run("ALTER TABLE activities ADD COLUMN firmware_version INTEGER;", NO);

    // --- META: single-row table for DB-wide settings ---
    const char *createMeta =
        "CREATE TABLE IF NOT EXISTS meta ("
        " id INTEGER PRIMARY KEY CHECK(id=1),"
        " uuid_s TEXT,"
        " tableInfo_json TEXT,"
        " splitsTableInfo_json TEXT,"
        " startDate_s INTEGER,"
        " endDate_s INTEGER,"
        " flags INTEGER,"
        " int2 INTEGER,"
        " int3 INTEGER,"
        " int4 INTEGER"
        ");";
    if (!run(createMeta, YES)) return NO;

    // Ensure the singleton row exists
    if (!run("INSERT OR IGNORE INTO meta (id) VALUES (1);", YES)) return NO;

    // Tolerant ALTERs so older DBs migrate (safe to call every launch)
    run("ALTER TABLE meta ADD COLUMN uuid_s TEXT;", NO);
    run("ALTER TABLE meta ADD COLUMN tableInfo_json TEXT;", NO);
    run("ALTER TABLE meta ADD COLUMN splitsTableInfo_json TEXT;", NO);
    run("ALTER TABLE meta ADD COLUMN startDate_s INTEGER;", NO);
    run("ALTER TABLE meta ADD COLUMN endDate_s INTEGER;", NO);
    run("ALTER TABLE meta ADD COLUMN flags INTEGER;", NO);
    run("ALTER TABLE meta ADD COLUMN int2 INTEGER;", NO);
    run("ALTER TABLE meta ADD COLUMN int3 INTEGER;", NO);
    run("ALTER TABLE meta ADD COLUMN int4 INTEGER;", NO);
   return YES;
}

#else


- (BOOL)createSchema:(NSError **)error {
    const char *sql =
    "BEGIN;"

    // Activity row (stores arrays + overrides as JSON TEXT so it's portable)
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
    " attributes_json TEXT,"   // <-- attributes array as JSON
    " markers_json TEXT,"      // <-- PathMarker array as JSON
    " override_json TEXT"      // <-- OverrideData as JSON
    ");"

    // Laps
    "CREATE TABLE IF NOT EXISTS laps ("
    " id INTEGER PRIMARY KEY,"
    " track_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,"
    " lap_index INTEGER NOT NULL,"
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
    ");"
    "CREATE INDEX IF NOT EXISTS idx_laps_track ON laps(track_id, lap_index);"

    // Points (ordered by seq)
    "CREATE TABLE IF NOT EXISTS points ("
    " track_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,"
    " seq INTEGER NOT NULL,"
    " wall_clock_delta_s REAL,"
    " active_time_delta_s REAL,"
    " latitude REAL,"
    " longitude REAL,"
    " altitude_m REAL,"
    " orig_altitude_m REAL,"
    " heartrate_bpm REAL,"
    " cadence_rpm REAL,"
    " temperature_c REAL,"
    " speed_mps REAL,"
    " power_w REAL,"
    " distance_mi REAL,"
    " orig_distance_mi REAL,"
    " gradient REAL,"
    " climb_so_far_m REAL,"
    " descent_so_far_m REAL,"
    " flags INTEGER,"
    " valid_lat_lon INTEGER,"
    " PRIMARY KEY (track_id, seq)"
    ");"
    "CREATE INDEX IF NOT EXISTS idx_points_track ON points(track_id);"

    "COMMIT;";

    int rc = sqlite3_exec(_db, sql, NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:rc
            userInfo:@{NSLocalizedDescriptionKey: @(sqlite3_errmsg(_db) ?: "schema creation failed")}];
        return NO;
    }

    // Tolerant migrations (ignored if already present)
    sqlite3_exec(_db, "ALTER TABLE activities ADD COLUMN attributes_json TEXT;", NULL, NULL, NULL);
    sqlite3_exec(_db, "ALTER TABLE activities ADD COLUMN markers_json TEXT;",    NULL, NULL, NULL);
    sqlite3_exec(_db, "ALTER TABLE activities ADD COLUMN override_json TEXT;",   NULL, NULL, NULL);
    return YES;
}
#endif

#pragma mark - Helpers

static inline int64_t dateToEpoch(NSDate * _Nullable d) {
    return d ? (int64_t)llround(d.timeIntervalSince1970) : 0;
}
static inline NSDate * _Nullable epochToDate(sqlite3_int64 v) {
    return v ? [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)v] : nil;
}
static inline int b(BOOL x) { return x ? 1 : 0; }

// --- JSON helpers ---

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




#pragma mark - Save


- (BOOL)saveMetaWithTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)tableInfoDict
              splitsTableInfo:(NSDictionary<NSString*,ColumnInfo*> *)splitsTableInfoDict
                         uuid:(NSString*)uuid
                    startDate:(NSDate *)startDate
                      endDate:(NSDate *)endDate
                        flags:(NSInteger)flags
                         int2:(NSInteger)i2
                         int3:(NSInteger)i3
                         int4:(NSInteger)i4
                        error:(NSError **)error
{
    const char *sql =
      "UPDATE meta SET "
      " uuid_s=?, tableInfo_json=?, splitsTableInfo_json=?, "
      " startDate_s=?, endDate_s=?, "
      " flags=?, int2=?, int3=?, int4=? "
      " WHERE id=1;";

    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(_db, sql, -1, &st, NULL);
    if (rc != SQLITE_OK) { if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:rc userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db))}]; return NO; }

    NSString *d1 = JSONStringFromColumnInfoDict(tableInfoDict);
    NSString *d2 = JSONStringFromColumnInfoDict(splitsTableInfoDict);

    sqlite3_bind_text(st, 1,  uuid.UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 2,  (d1?:@"").UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 3,  (d2?:@"").UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 4, EpochFromDate(startDate));
    sqlite3_bind_int64(st, 5, EpochFromDate(endDate));
    sqlite3_bind_int  (st, 6, (int)flags);
    sqlite3_bind_int  (st, 7, (int)i2);
    sqlite3_bind_int  (st, 8, (int)i3);
    sqlite3_bind_int  (st, 9, (int)i4);

    rc = sqlite3_step(st);
    BOOL ok = (rc == SQLITE_DONE);
    if (!ok && error) *error = [NSError errorWithDomain:@"ActivityStore" code:rc userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db))}];
    sqlite3_finalize(st);
    return ok;
}


#if 1
- (BOOL)saveTrack:(Track *)track error:(NSError **)error
{
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
    int secondsFromGMTAtSync = [track respondsToSelector:@selector(secondsFromGMTAtSync)]
                                ? [track secondsFromGMTAtSync]
                                : [[track valueForKey:@"secondsFromGMTAtSync"] intValue];
    int flags           = [track respondsToSelector:@selector(flags)] ? [track flags] : [[track valueForKey:@"flags"] intValue];
    int deviceID        = [track respondsToSelector:@selector(deviceID)] ? [track deviceID] : [[track valueForKey:@"deviceID"] intValue];
    int firmwareVersion = [track respondsToSelector:@selector(firmwareVersion)] ? [track firmwareVersion] : [[track valueForKey:@"firmwareVersion"] intValue];

    // Arrays / JSON fields
    NSArray *attrs   = [track respondsToSelector:@selector(attributes)] ? [track attributes] : [track valueForKey:@"attributes"];
    NSArray *markers = [track respondsToSelector:@selector(markers)]    ? [track markers]    : [track valueForKey:@"markers"];
    NSArray *points  = [track respondsToSelector:@selector(points)]     ? [track points]     : [track valueForKey:@"points"];
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
      " seconds_from_gmt_at_sync,flags,device_id,firmware_version)"
      " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
      " ON CONFLICT(uuid) DO UPDATE SET "
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
      " flags=excluded.flags,"
      " device_id=excluded.device_id,"
      " firmware_version=excluded.firmware_version;";

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
    sqlite3_bind_int   (act,15,  secondsFromGMTAtSync);
    sqlite3_bind_int   (act,16,  flags);
    sqlite3_bind_int   (act,17,  deviceID);
    sqlite3_bind_int   (act,18,  firmwareVersion);

    
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

    // Points
    if ([points isKindOfClass:NSArray.class] && points.count) {
        const char *insPt =
          "INSERT INTO points (track_id,seq,wall_clock_delta_s,active_time_delta_s,latitude,longitude,"
          " orig_altitude_m,heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,"
          " orig_distance_mi,flags)"
          " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
        sqlite3_stmt *ptStmt=NULL;
        sqlite3_prepare_v2(_db, insPt, -1, &ptStmt, NULL);
        NSInteger seq = 0;
        for (TrackPoint* p in points) {
            sqlite3_bind_int64 (ptStmt, 1, trackID);
            sqlite3_bind_int   (ptStmt, 2, (int)seq++);
            sqlite3_bind_double(ptStmt, 3,  [p respondsToSelector:@selector(wallClockDelta)] ? [p wallClockDelta] : [[p valueForKey:@"wallClockDelta"] doubleValue]);
            sqlite3_bind_double(ptStmt, 4,  [p respondsToSelector:@selector(activeTimeDelta)] ? [p activeTimeDelta] : [[p valueForKey:@"activeTimeDelta"] doubleValue]);
            sqlite3_bind_double(ptStmt, 5,  [p respondsToSelector:@selector(latitude)] ? [p latitude] : [[p valueForKey:@"latitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 6,  [p respondsToSelector:@selector(longitude)] ? [p longitude] : [[p valueForKey:@"longitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 7,  [p respondsToSelector:@selector(origAltitude)] ? [p origAltitude] : [[p valueForKey:@"origAltitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 8,  [p respondsToSelector:@selector(heartrate)] ? [p heartrate] : [[p valueForKey:@"heartrate"] doubleValue]);
            sqlite3_bind_double(ptStmt, 9,  [p respondsToSelector:@selector(cadence)] ? [p cadence] : [[p valueForKey:@"cadence"] doubleValue]);
            sqlite3_bind_double(ptStmt,10,  [p respondsToSelector:@selector(temperature)] ? [p temperature] : [[p valueForKey:@"temperature"] doubleValue]);
            sqlite3_bind_double(ptStmt,11,  [p respondsToSelector:@selector(speed)] ? [p speed] : [[p valueForKey:@"speed"] doubleValue]);
            sqlite3_bind_double(ptStmt,12,  [p respondsToSelector:@selector(power)] ? [p power] : [[p valueForKey:@"power"] doubleValue]);
                sqlite3_bind_double(ptStmt,13,  [p respondsToSelector:@selector(origDistance)] ? [p origDistance] : [[p valueForKey:@"origDistance"] doubleValue]);
            int pflags = [[p valueForKey:@"flags"] intValue];
            sqlite3_bind_int   (ptStmt,14,  pflags);

            if (sqlite3_step(ptStmt) != SQLITE_DONE) { /* ignore one bad point or handle */ }
            sqlite3_reset(ptStmt);
        }
        sqlite3_finalize(ptStmt);
    }

    sqlite3_exec(_db, "COMMIT;", NULL, NULL, NULL);
    return YES;

fail:
    if (act) sqlite3_finalize(act);
    sqlite3_exec(_db, "ROLLBACK;", NULL, NULL, NULL);
    if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
                                         userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db) ?: "saveTrack failed")}];
    return NO;
}


#else

- (BOOL)saveTrack:(Track *)track error:(NSError **)error {
    // Gather activity fields
    NSString *uuid = [track respondsToSelector:@selector(uuid)] ? [track uuid] : [track valueForKey:@"uuid"];
    if (uuid.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:-1
            userInfo:@{NSLocalizedDescriptionKey:@"Track uuid is required"}];
        return NO;
    }
    NSString *name = [track respondsToSelector:@selector(name)] ? [track name] : [track valueForKey:@"name"];
    NSDate   *ct   = [track respondsToSelector:@selector(creationTime)] ? [track creationTime] : [track valueForKey:@"creationTime"];
    NSDate   *cto  = [track respondsToSelector:@selector(creationTimeOverride)] ? [track creationTimeOverride] : [track valueForKey:@"creationTimeOverride"];
    double    dist = [track respondsToSelector:@selector(distance)] ? [track distance] : [[track valueForKey:@"distance"] doubleValue];
    double    wt   = [track respondsToSelector:@selector(weight)] ? [track weight] : [[track valueForKey:@"weight"] doubleValue];
    double    asf  = [track respondsToSelector:@selector(altitudeSmoothingFactor)] ? [track altitudeSmoothingFactor] : [[track valueForKey:@"altitudeSmoothingFactor"] doubleValue];
    double    eqw  = [track respondsToSelector:@selector(equipmentWeight)] ? [track equipmentWeight] : [[track valueForKey:@"equipmentWeight"] doubleValue];
    double    devT = [track respondsToSelector:@selector(deviceTotalTime)] ? [track deviceTotalTime] : [[track valueForKey:@"deviceTotalTime"] doubleValue];
    BOOL   moving  = [track respondsToSelector:@selector(movingSpeedOnly)] ? [track movingSpeedOnly] : [[track valueForKey:@"movingSpeedOnly"] boolValue];
    BOOL   hasDist = [track respondsToSelector:@selector(hasDistanceData)] ? [track hasDistanceData] : [[track valueForKey:@"hasDistanceData"] boolValue];

    NSArray *attrs   = [track respondsToSelector:@selector(attributes)] ? [track attributes] : [track valueForKey:@"attributes"];
    NSArray *markers = [track respondsToSelector:@selector(markers)]    ? [track markers]    : [track valueForKey:@"markers"];
    NSArray *points  = [track respondsToSelector:@selector(points)]     ? [track points]     : [track valueForKey:@"points"];
    id      od       = nil;
    if ([track respondsToSelector:@selector(overrideData)]) od = [track performSelector:@selector(overrideData)];
    else @try { od = [track valueForKey:@"overrideData"]; } @catch (__unused id e) {}

    NSString *attrsJSON    = AttributesToJSON(attrs);
    NSString *markersJSON  = MarkersToJSON(markers);
    NSString *overrideJSON = OverrideToJSON(od);

    // Upsert activity row
    sqlite3_stmt *act = NULL;
    const char *upsert =
      "INSERT INTO activities ("
      " uuid,name,creation_time_s,creation_time_override_s,"
      " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
      " device_total_time_s,moving_speed_only,has_distance_data,"
      " attributes_json,markers_json,override_json)"
      " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
      " ON CONFLICT(uuid) DO UPDATE SET "
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
      " override_json=excluded.override_json;";

    if (sqlite3_prepare_v2(_db, upsert, -1, &act, NULL) != SQLITE_OK) return NO;

    sqlite3_bind_text  (act, 1,  uuid.UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text  (act, 2,  (name?:@"").UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64 (act, 3,  dateToEpoch(ct));
    sqlite3_bind_int64 (act, 4,  dateToEpoch(cto));
    sqlite3_bind_double(act, 5,  dist);
    sqlite3_bind_double(act, 6,  wt);
    sqlite3_bind_double(act, 7,  asf);
    sqlite3_bind_double(act, 8,  eqw);
    sqlite3_bind_double(act, 9,  devT);
    sqlite3_bind_int   (act,10,  b(moving));
    sqlite3_bind_int   (act,11,  b(hasDist));
    sqlite3_bind_text  (act,12,  (attrsJSON    ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
    sqlite3_bind_text  (act,13,  (markersJSON  ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);
    sqlite3_bind_text  (act,14,  (overrideJSON ?: @"").UTF8String,   -1, SQLITE_TRANSIENT);

    if (sqlite3_step(act) != SQLITE_DONE) return NO;
    sqlite3_finalize(act); act = NULL;

    // Resolve id
    sqlite3_stmt *sel = NULL;
    if (sqlite3_prepare_v2(_db, "SELECT id FROM activities WHERE uuid=?", -1, &sel, NULL) != SQLITE_OK) return NO;
    sqlite3_bind_text(sel, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
    sqlite3_int64 trackID = 0;
    if (sqlite3_step(sel) == SQLITE_ROW) trackID = sqlite3_column_int64(sel, 0);
    sqlite3_finalize(sel); sel = NULL;
    if (!trackID)  return NO;

    // Replace children
    sqlite3_exec(_db, "BEGIN IMMEDIATE;", NULL, NULL, NULL);

    const char *del1="DELETE FROM laps WHERE track_id=?;";
    const char *del2="DELETE FROM points WHERE track_id=?;";
    for (const char *sql : (const char*[]){del1,del2}) {
        sqlite3_stmt *st=NULL; sqlite3_prepare_v2(_db, sql, -1, &st, NULL);
        sqlite3_bind_int64(st, 1, trackID); sqlite3_step(st); sqlite3_finalize(st);
    }

    // Insert laps
    NSArray *laps = [track respondsToSelector:@selector(laps)] ? [track laps] : [track valueForKey:@"laps"];
    if ([laps isKindOfClass:[NSArray class]] && laps.count) {
        const char *insLap =
          "INSERT INTO laps (track_id,lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
          " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,device_total_time_s,"
          " average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated)"
          " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
        sqlite3_stmt *lapStmt = NULL;
        sqlite3_prepare_v2(_db, insLap, -1, &lapStmt, NULL);
        for (Lap* lap in laps) {
            sqlite3_bind_int64 (lapStmt, 1, trackID);
            sqlite3_bind_int   (lapStmt, 2, [lap respondsToSelector:@selector(index)] ? [lap index] : [[lap valueForKey:@"index"] intValue]);
            sqlite3_bind_int64 (lapStmt, 3, dateToEpoch([lap respondsToSelector:@selector(origStartTime)] ? [lap origStartTime] : [lap valueForKey:@"origStartTime"]));
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
            sqlite3_bind_int   (lapStmt,21, [lap respondsToSelector:@selector(selected)] ? [lap selected] : [[lap valueForKey:@"selected"] boolValue]);
            sqlite3_bind_int   (lapStmt,22, [lap respondsToSelector:@selector(statsCalculated)] ? [lap statsCalculated] : [[lap valueForKey:@"statsCalculated"] boolValue]);
            if (sqlite3_step(lapStmt) != SQLITE_DONE) { /* handle or continue */ }
            sqlite3_reset(lapStmt);
        }
        sqlite3_finalize(lapStmt);
    }

    // Insert points (ordered)
    if ([points isKindOfClass:[NSArray class]] && points.count) {
        const char *insPt =
          "INSERT INTO points (track_id,seq,wall_clock_delta_s,active_time_delta_s,latitude,longitude,"
          " altitude_m,orig_altitude_m,heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,"
          " distance_mi,orig_distance_mi,gradient,climb_so_far_m,descent_so_far_m,flags,valid_lat_lon)"
          " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
        sqlite3_stmt *ptStmt = NULL;
        sqlite3_prepare_v2(_db, insPt, -1, &ptStmt, NULL);
        NSInteger seq = 0;
        for (TrackPoint* p in points) {
            sqlite3_bind_int64 (ptStmt, 1, trackID);
            sqlite3_bind_int   (ptStmt, 2, (int)seq++);

            sqlite3_bind_double(ptStmt, 3, [p respondsToSelector:@selector(wallClockDelta)] ? [p wallClockDelta] : [[p valueForKey:@"wallClockDelta"] doubleValue]);
            sqlite3_bind_double(ptStmt, 4, [p respondsToSelector:@selector(activeTimeDelta)] ? [p activeTimeDelta] : [[p valueForKey:@"activeTimeDelta"] doubleValue]);
            sqlite3_bind_double(ptStmt, 5, [p respondsToSelector:@selector(latitude)] ? [p latitude] : [[p valueForKey:@"latitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 6, [p respondsToSelector:@selector(longitude)] ? [p longitude] : [[p valueForKey:@"longitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 7, [p respondsToSelector:@selector(altitude)] ? [p altitude] : [[p valueForKey:@"altitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 8, [p respondsToSelector:@selector(origAltitude)] ? [p origAltitude] : [[p valueForKey:@"origAltitude"] doubleValue]);
            sqlite3_bind_double(ptStmt, 9, [p respondsToSelector:@selector(heartrate)] ? [p heartrate] : [[p valueForKey:@"heartrate"] doubleValue]);
            sqlite3_bind_double(ptStmt,10, [p respondsToSelector:@selector(cadence)] ? [p cadence] : [[p valueForKey:@"cadence"] doubleValue]);
            sqlite3_bind_double(ptStmt,11, [p respondsToSelector:@selector(temperature)] ? [p temperature] : [[p valueForKey:@"temperature"] doubleValue]);
            sqlite3_bind_double(ptStmt,12, [p respondsToSelector:@selector(speed)] ? [p speed] : [[p valueForKey:@"speed"] doubleValue]);
            sqlite3_bind_double(ptStmt,13, [p respondsToSelector:@selector(power)] ? [p power] : [[p valueForKey:@"power"] doubleValue]);
            sqlite3_bind_double(ptStmt,14, [p respondsToSelector:@selector(distance)] ? [p distance] : [[p valueForKey:@"distance"] doubleValue]);
            sqlite3_bind_double(ptStmt,15, [p respondsToSelector:@selector(origDistance)] ? [p origDistance] : [[p valueForKey:@"origDistance"] doubleValue]);
            sqlite3_bind_double(ptStmt,16, [p respondsToSelector:@selector(gradient)] ? [p gradient] : [[p valueForKey:@"gradient"] doubleValue]);
            sqlite3_bind_double(ptStmt,17, [p respondsToSelector:@selector(climbSoFar)] ? [p climbSoFar] : [[p valueForKey:@"climbSoFar"] doubleValue]);
            sqlite3_bind_double(ptStmt,18, [p respondsToSelector:@selector(descentSoFar)] ? [p descentSoFar] : [[p valueForKey:@"descentSoFar"] doubleValue]);
            int flags = [[p valueForKey:@"flags"] intValue];
            sqlite3_bind_int   (ptStmt,19, flags);
            int vll = [p respondsToSelector:@selector(validLatLon)] ? ([p validLatLon] ? 1 : 0) : ([[p valueForKey:@"validLatLon"] boolValue] ? 1 : 0);
            sqlite3_bind_int   (ptStmt,20, vll);

            if (sqlite3_step(ptStmt) != SQLITE_DONE) { /* handle or continue */ }
            sqlite3_reset(ptStmt);
        }
        sqlite3_finalize(ptStmt);
    }

    sqlite3_exec(_db, "COMMIT;", NULL, NULL, NULL);
    return YES;

//fail:
//    if (act) sqlite3_finalize(act);
//    if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
//        userInfo:@{NSLocalizedDescriptionKey: @(sqlite3_errmsg(_db) ?: "saveTrack failed")}];
//    return NO;
}

#endif

- (BOOL)saveAllTracks:(NSArray<Track *> *)tracks error:(NSError **)error {
    if (tracks.count == 0) return YES;

    NSUInteger idx = 0;
    for (Track *t in tracks) {
        NSError *err = nil;
        if (![self saveTrack:t error:&err]) {
            if (error) {
                // Try to surface the uuid to help you pinpoint the failing object.
                NSString *uuid = nil;
                if ([t respondsToSelector:@selector(uuid)]) uuid = [t uuid];
                else @try { uuid = [t valueForKey:@"uuid"]; } @catch (__unused id e) {}

                NSMutableDictionary *info = [err.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                info[@"index"] = @(idx);
                if (uuid) info[@"uuid"] = uuid;

                *error = [NSError errorWithDomain:@"ActivityStore"
                                             code:err.code ?: -1
                                         userInfo:info];
            }
            return NO;
        }
        idx++;
    }
    return YES;
}


#pragma mark - Load

- (BOOL)loadMetaToTableInfo:(NSDictionary<NSString*,ColumnInfo*> * *)outTableInfo
            splitsTableInfo:(NSDictionary<NSString*,ColumnInfo*> * *)outSplitsTableInfo
                       uuid:(NSString* *)outUuid
                  startDate:(NSDate * *)outStartTime
                    endDate:(NSDate * *)outEndTime
                      flags:(NSInteger *)outFlags
                       int2:(NSInteger *)outI2
                       int3:(NSInteger *)outI3
                       int4:(NSInteger *)outI4
                      error:(NSError **)error
{
    // fixme - move to common place
    // Helper: run SQL, optionally strict (fail) vs tolerant (ignore errors like "duplicate column")
    BOOL (^run)(const char *sql, BOOL strict) = ^BOOL(const char *sql, BOOL strict) {
        char *errmsg = NULL;
        int rc = sqlite3_exec(_db, sql, NULL, NULL, &errmsg);
        if (rc != SQLITE_OK) {
            if (strict) {
                if (error) {
                    NSString *msg = errmsg ? [NSString stringWithUTF8String:errmsg] : @"SQLite error";
                    *error = [NSError errorWithDomain:@"ActivityStore"
                                                 code:rc
                                             userInfo:@{NSLocalizedDescriptionKey: msg}];
                }
                if (errmsg) { sqlite3_free(errmsg); errmsg = NULL; }
                return NO;
            }
            // tolerant path: swallow errors (e.g., duplicate column/index)
            if (errmsg) { sqlite3_free(errmsg); errmsg = NULL; }
        }
        return YES;
    };

    const char *sql =
      "SELECT uuid_s, tableInfo_json, splitsTableInfo_json, startTime_s, endTime_s, flags, int2, int3, int4 "
      "FROM meta WHERE id=1;";

    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(_db, sql, -1, &st, NULL);
    if (rc != SQLITE_OK) { if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:rc userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db))}]; return NO; }

    BOOL ok = NO;
    if (sqlite3_step(st) == SQLITE_ROW) {
        if (outUuid) *outUuid = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(st,1)];
        if (outTableInfo) *outTableInfo = ColumnInfoDictFromJSONText(sqlite3_column_text(st, 2));
        if (outSplitsTableInfo) *outSplitsTableInfo = ColumnInfoDictFromJSONText(sqlite3_column_text(st, 3));

        if (outStartTime) *outStartTime = DateFromEpoch(sqlite3_column_int64(st, 4));
        if (outEndTime) *outEndTime = DateFromEpoch(sqlite3_column_int64(st, 5));

        if (outFlags) *outFlags = sqlite3_column_int(st, 6);
        if (outI2) *outI2 = sqlite3_column_int(st, 7);
        if (outI3) *outI3 = sqlite3_column_int(st, 8);
        if (outI4) *outI4 = sqlite3_column_int(st, 9);

        ok = YES;
    } else {
        // Row missing? Ensure it exists and return defaults.
        sqlite3_finalize(st);
        run("INSERT OR IGNORE INTO meta (id) VALUES (1);", NO);
        if (outUuid) *outUuid = nil;
        if (outTableInfo) *outTableInfo = nil;
        if (outSplitsTableInfo) *outSplitsTableInfo = nil;
        if (outStartTime) *outStartTime = nil;
        if (outEndTime) *outEndTime = nil;
        if (outFlags) *outFlags = 0;
        if (outI2) *outI2 = 0;
        if (outI3) *outI3 = 0;
        if (outI4) *outI4 = 0;
        return YES;
    }

    sqlite3_finalize(st);
    return ok;
}



- (NSArray<Track *> *)loadAllTracks:(NSError **)error {
    NSMutableArray *out = [NSMutableArray array];

    const char *selA =
      "SELECT id,uuid,name,creation_time_s,creation_time_override_s,"
      " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
      " device_total_time_s,moving_speed_only,has_distance_data,"
      " attributes_json, markers_json, override_json "
      "FROM activities ORDER BY creation_time_s;";

    sqlite3_stmt *a = NULL;
    if (sqlite3_prepare_v2(_db, selA, -1, &a, NULL) != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
            userInfo:@{NSLocalizedDescriptionKey: @(sqlite3_errmsg(_db) ?: "load prepare failed")}];
        return out;
    }

    while (sqlite3_step(a) == SQLITE_ROW) {
        sqlite3_int64 trackID = sqlite3_column_int64(a, 0);

        Track *t = [Track new];
        NSString *uuid = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(a,1)];
        NSString *name = (sqlite3_column_type(a,2)==SQLITE_NULL)?@"":
                         [NSString stringWithUTF8String:(const char *)sqlite3_column_text(a,2)];
        NSDate *ct  = epochToDate(sqlite3_column_int64(a,3));
        NSDate *cto = epochToDate(sqlite3_column_int64(a,4));
        double dist = sqlite3_column_double(a,5);
        double wt   = sqlite3_column_double(a,6);
        double asf  = sqlite3_column_double(a,7);
        double eqw  = sqlite3_column_double(a,8);
        double devT = sqlite3_column_double(a,9);
        BOOL moving = sqlite3_column_int(a,10)!=0;
        BOOL hasD   = sqlite3_column_int(a,11)!=0;

        if ([t respondsToSelector:@selector(setUuid:)]) [t setUuid:uuid]; else [t setValue:uuid forKey:@"uuid"];
        if ([t respondsToSelector:@selector(setName:)]) [t setName:name]; else [t setValue:name forKey:@"name"];
        if ([t respondsToSelector:@selector(setCreationTime:)]) [t setCreationTime:ct]; else [t setValue:ct forKey:@"creationTime"];
        if ([t respondsToSelector:@selector(setCreationTimeOverride:)]) [t setCreationTimeOverride:cto]; else [t setValue:cto forKey:@"creationTimeOverride"];
        if ([t respondsToSelector:@selector(setDistance:)]) [t setDistance:dist]; else [t setValue:@(dist) forKey:@"distance"];
        if ([t respondsToSelector:@selector(setWeight:)]) [t setWeight:wt]; else [t setValue:@(wt) forKey:@"weight"];
        if ([t respondsToSelector:@selector(setAltitudeSmoothingFactor:)]) [t setAltitudeSmoothingFactor:asf];
        if ([t respondsToSelector:@selector(setEquipmentWeight:)])       [t setEquipmentWeight:eqw];
        if ([t respondsToSelector:@selector(setDeviceTotalTime:)])       [t setDeviceTotalTime:devT];
        [t setValue:@(moving) forKey:@"movingSpeedOnly"];
        [t setValue:@(hasD)   forKey:@"hasDistanceData"];

        // JSON fields
        const unsigned char *attrsTxt   = sqlite3_column_text(a, 12);
        const unsigned char *markersTxt = sqlite3_column_text(a, 13);
        const unsigned char *overrideTxt= sqlite3_column_text(a, 14);

        NSArray<NSString *> *attrs = AttributesFromJSONString(attrsTxt);
        if ([t respondsToSelector:@selector(setAttributes:)]) [t setAttributes:[attrs mutableCopy]]; else [t setValue:[attrs mutableCopy] forKey:@"attributes"];

        NSArray *markers = MarkersFromJSONString(markersTxt);
        if ([t respondsToSelector:@selector(setMarkers:)])    [t setMarkers:[markers mutableCopy] ]; else [t setValue:[markers mutableCopy] forKey:@"markers"];

        OverrideData* od = OverrideFromJSON(overrideTxt);
        if (od) {
            if ([t respondsToSelector:@selector(setOverrideData:)]) {
                [t performSelector:@selector(setOverrideData:) withObject:od];
            } else {
                @try { [t setValue:od forKey:@"overrideData"]; } @catch (__unused id e) {}
            }
        }

        // Laps
        NSMutableArray *laps = [NSMutableArray array];
        sqlite3_stmt *l = NULL;
        if (sqlite3_prepare_v2(_db,
           "SELECT lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
           " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,"
           " device_total_time_s,average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated"
           " FROM laps WHERE track_id=? ORDER BY lap_index;", -1, &l, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(l, 1, trackID);
            while (sqlite3_step(l) == SQLITE_ROW) {
                Lap *lp = [Lap new];
                if ([lp respondsToSelector:@selector(setIndex:)])          [lp setIndex:sqlite3_column_int(l,0)];
                if ([lp respondsToSelector:@selector(setOrigStartTime:)])   [lp setOrigStartTime:epochToDate(sqlite3_column_int64(l,1))];
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
                [laps addObject:lp];
            }
            sqlite3_finalize(l);
        }

        // Points
        NSMutableArray *points = [NSMutableArray array];
        sqlite3_stmt *p = NULL;
        if (sqlite3_prepare_v2(_db,
          "SELECT wall_clock_delta_s,active_time_delta_s,latitude,longitude, orig_altitude_m,"
          " heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,orig_distance_mi,"
          " flags"
          " FROM points WHERE track_id=? ORDER BY seq;", -1, &p, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(p, 1, trackID);
            while (sqlite3_step(p) == SQLITE_ROW) {
                TrackPoint *tp = [TrackPoint new];
                [tp setWallClockDelta:sqlite3_column_double(p,0)];
                [tp setActiveTimeDelta:sqlite3_column_double(p,1)];
                [tp setLatitude:sqlite3_column_double(p,2)];
                [tp setLongitude:sqlite3_column_double(p,3)];
                //[tp setAltitude:sqlite3_column_double(p,4)];
                [tp setOrigAltitude:sqlite3_column_double(p,5)];
                [tp setHeartrate:sqlite3_column_double(p,6)];
                [tp setCadence:sqlite3_column_double(p,7)];
                [tp setTemperature:sqlite3_column_double(p,8)];
                [tp setSpeed:sqlite3_column_double(p,9)];
                [tp setPower:sqlite3_column_double(p,10)];
                //[tp setDistance:sqlite3_column_double(p,11)];
                [tp setOrigDistance:sqlite3_column_double(p,12)];
                //[tp setGradient:sqlite3_column_double(p,13)];
                //[tp setClimbSoFar:sqlite3_column_double(p,14)];
                //[tp setDescentSoFar:sqlite3_column_double(p,15)];
                [tp setValue:@(sqlite3_column_int(p,16)) forKey:@"flags"];
                [tp setValidLatLon:(sqlite3_column_int(p,17)!=0)];
                [points addObject:tp];
            }
            sqlite3_finalize(p);
        }

        [t setValue:laps   forKey:@"laps"];
        [t setValue:points forKey:@"points"];
        [out addObject:t];
    }
    sqlite3_finalize(a);
    return out;
}


#if 1
- (Track *)loadTrackWithUUID:(NSString *)uuid error:(NSError **)error
{
    if (uuid.length == 0) return nil;

    // ---- Load activity row (includes new columns) ----
    const char *sel =
      "SELECT id,uuid,name,creation_time_s,creation_time_override_s,"
      " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
      " device_total_time_s,moving_speed_only,has_distance_data,"
      " attributes_json, markers_json, override_json,"
      " seconds_from_gmt_at_sync, flags, device_id, firmware_version "
      "FROM activities WHERE uuid=?;";

    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, sel, -1, &st, NULL) != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
                                            userInfo:@{NSLocalizedDescriptionKey:@(sqlite3_errmsg(_db) ?: "prepare failed")}];
        return nil;
    }
    sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);

    if (sqlite3_step(st) != SQLITE_ROW) { sqlite3_finalize(st); return nil; }

    sqlite3_int64 trackID = sqlite3_column_int64(st, 0);

    Track *t = [Track new];
    NSString *name = (sqlite3_column_type(st,2)==SQLITE_NULL)?@""
                     : [NSString stringWithUTF8String:(const char *)sqlite3_column_text(st,2)];
    NSDate *ct  = epochToDate(sqlite3_column_int64(st,3));
    NSDate *cto = epochToDate(sqlite3_column_int64(st,4));
    double dist = sqlite3_column_double(st,5);
    double wt   = sqlite3_column_double(st,6);
    double asf  = sqlite3_column_double(st,7);
    double eqw  = sqlite3_column_double(st,8);
    double devT = sqlite3_column_double(st,9);
    BOOL moving = sqlite3_column_int(st,10)!=0;
    BOOL hasD   = sqlite3_column_int(st,11)!=0;

    if ([t respondsToSelector:@selector(setUuid:)]) [t setUuid:uuid]; else [t setValue:uuid forKey:@"uuid"];
    if ([t respondsToSelector:@selector(setName:)]) [t setName:name]; else [t setValue:name forKey:@"name"];
    if ([t respondsToSelector:@selector(setCreationTime:)]) [t setCreationTime:ct]; else [t setValue:ct forKey:@"creationTime"];
    if ([t respondsToSelector:@selector(setCreationTimeOverride:)]) [t setCreationTimeOverride:cto]; else [t setValue:cto forKey:@"creationTimeOverride"];
    if ([t respondsToSelector:@selector(setDistance:)]) [t setDistance:dist]; else [t setValue:@(dist) forKey:@"distance"];
    if ([t respondsToSelector:@selector(setWeight:)]) [t setWeight:wt]; else [t setValue:@(wt) forKey:@"weight"];
    if ([t respondsToSelector:@selector(setAltitudeSmoothingFactor:)]) [t setAltitudeSmoothingFactor:asf];
    if ([t respondsToSelector:@selector(setEquipmentWeight:)])       [t setEquipmentWeight:eqw];
    if ([t respondsToSelector:@selector(setDeviceTotalTime:)])       [t setDeviceTotalTime:devT];
    [t setValue:@(moving) forKey:@"movingSpeedOnly"];
    [t setValue:@(hasD)   forKey:@"hasDistanceData"];

    // JSON fields
    const unsigned char *attrsTxt    = sqlite3_column_text(st, 12);
    const unsigned char *markersTxt  = sqlite3_column_text(st, 13);
    const unsigned char *overrideTxt = sqlite3_column_text(st, 14);

    NSArray<NSString *> *attrs = AttributesFromJSONString(attrsTxt);
    if ([t respondsToSelector:@selector(setAttributes:)]) [t setAttributes:attrs.mutableCopy ?: [NSMutableArray array]];
    else [t setValue:attrs.mutableCopy ?: [NSMutableArray array] forKey:@"attributes"];

    NSArray *markers = MarkersFromJSONString(markersTxt);
    if ([t respondsToSelector:@selector(setMarkers:)])    [t setMarkers:markers.mutableCopy ?: [NSMutableArray array]];
    else [t setValue:markers.mutableCopy ?: [NSMutableArray array] forKey:@"markers"];

    id od = OverrideFromJSON(overrideTxt);
    if (od) {
        if ([t respondsToSelector:@selector(setOverrideData:)]) {
            [t performSelector:@selector(setOverrideData:) withObject:od];
        } else {
            @try { [t setValue:od forKey:@"overrideData"]; } @catch (__unused id e) {}
        }
    }

    // ---- NEW scalar fields from activity row ----
    int secondsFromGMTAtSync = sqlite3_column_int(st, 15);
    int flags                = sqlite3_column_int(st, 16);
    int deviceID             = sqlite3_column_int(st, 17);
    int firmwareVersion      = sqlite3_column_int(st, 18);

    if ([t respondsToSelector:@selector(setSecondsFromGMTAtSync:)])
        [t setSecondsFromGMTAtSync:secondsFromGMTAtSync];
    else
        [t setValue:@(secondsFromGMTAtSync) forKey:@"secondsFromGMTAtSync"];

    if ([t respondsToSelector:@selector(setFlags:)])
        [t setFlags:flags];
    else
        [t setValue:@(flags) forKey:@"flags"];

    if ([t respondsToSelector:@selector(setDeviceID:)])
        [t setDeviceID:deviceID];
    else
        [t setValue:@(deviceID) forKey:@"deviceID"];

    if ([t respondsToSelector:@selector(setFirmwareVersion:)])
        [t setFirmwareVersion:firmwareVersion];
    else
        [t setValue:@(firmwareVersion) forKey:@"firmwareVersion"];

    sqlite3_finalize(st);

    // ---- Laps ----
    NSMutableArray *laps = [NSMutableArray array];
    sqlite3_stmt *l = NULL;
    if (sqlite3_prepare_v2(_db,
       "SELECT lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
       " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,"
       " device_total_time_s,average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated"
       " FROM laps WHERE track_id=? ORDER BY lap_index;", -1, &l, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(l, 1, trackID);
        while (sqlite3_step(l) == SQLITE_ROW) {
            Lap* lp = [NSClassFromString(@"Lap") new];
            if ([lp respondsToSelector:@selector(setIndex:)])          [lp setIndex:sqlite3_column_int(l,0)];
            if ([lp respondsToSelector:@selector(setOrigStartTime:)])   [lp setOrigStartTime:epochToDate(sqlite3_column_int64(l,1))];
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
            [laps addObject:lp];
        }
        sqlite3_finalize(l);
    }

    // ---- Points ----
    NSMutableArray *points = [NSMutableArray array];
    sqlite3_stmt *p = NULL;
    if (sqlite3_prepare_v2(_db,
      "SELECT wall_clock_delta_s,active_time_delta_s,latitude,longitude,altitude_m,orig_altitude_m,"
      " heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,distance_mi,orig_distance_mi,"
      " gradient,climb_so_far_m,descent_so_far_m,flags,valid_lat_lon"
      " FROM points WHERE track_id=? ORDER BY seq;", -1, &p, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(p, 1, trackID);
        while (sqlite3_step(p) == SQLITE_ROW) {
            id tp = [NSClassFromString(@"TrackPoint") new];
            [tp setWallClockDelta:sqlite3_column_double(p,0)];
            [tp setActiveTimeDelta:sqlite3_column_double(p,1)];
            [tp setLatitude:sqlite3_column_double(p,2)];
            [tp setLongitude:sqlite3_column_double(p,3)];
            [tp setAltitude:sqlite3_column_double(p,4)];
            [tp setOrigAltitude:sqlite3_column_double(p,5)];
            [tp setHeartrate:sqlite3_column_double(p,6)];
            [tp setCadence:sqlite3_column_double(p,7)];
            [tp setTemperature:sqlite3_column_double(p,8)];
            [tp setSpeed:sqlite3_column_double(p,9)];
            [tp setPower:sqlite3_column_double(p,10)];
            [tp setDistance:sqlite3_column_double(p,11)];
            [tp setOrigDistance:sqlite3_column_double(p,12)];
            [tp setGradient:sqlite3_column_double(p,13)];
            [tp setClimbSoFar:sqlite3_column_double(p,14)];
            [tp setDescentSoFar:sqlite3_column_double(p,15)];
            [tp setValue:@(sqlite3_column_int(p,16)) forKey:@"flags"];
            [tp setValidLatLon:(sqlite3_column_int(p,17)!=0)];
            [points addObject:tp];
        }
        sqlite3_finalize(p);
    }

    [t setValue:laps   forKey:@"laps"];
    [t setValue:points forKey:@"points"];
    return t;
}


#else

- (Track *)loadTrackWithUUID:(NSString *)uuid error:(NSError **)error {
    if (uuid.length == 0) return nil;

    // Load the activity row first
    const char *sel =
      "SELECT id,uuid,name,creation_time_s,creation_time_override_s,"
      " distance_mi,weight_lb,altitude_smooth_factor,equipment_weight_lb,"
      " device_total_time_s,moving_speed_only,has_distance_data,"
      " attributes_json, markers_json, override_json "
      "FROM activities WHERE uuid=?;";
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, sel, -1, &st, NULL) != SQLITE_OK) {
        if (error) *error = [NSError errorWithDomain:@"ActivityStore" code:sqlite3_errcode(_db)
            userInfo:@{NSLocalizedDescriptionKey: @(sqlite3_errmsg(_db) ?: "prepare failed")}];
        return nil;
    }
    sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
    if (sqlite3_step(st) != SQLITE_ROW) { sqlite3_finalize(st); return nil; }

    sqlite3_int64 trackID = sqlite3_column_int64(st, 0);

    Track *t = [Track new];
    NSString *name = (sqlite3_column_type(st,2)==SQLITE_NULL)?@"":
                     [NSString stringWithUTF8String:(const char *)sqlite3_column_text(st,2)];
    NSDate *ct  = epochToDate(sqlite3_column_int64(st,3));
    NSDate *cto = epochToDate(sqlite3_column_int64(st,4));
    double dist = sqlite3_column_double(st,5);
    double wt   = sqlite3_column_double(st,6);
    double asf  = sqlite3_column_double(st,7);
    double eqw  = sqlite3_column_double(st,8);
    double devT = sqlite3_column_double(st,9);
    BOOL moving = sqlite3_column_int(st,10)!=0;
    BOOL hasD   = sqlite3_column_int(st,11)!=0;

    if ([t respondsToSelector:@selector(setUuid:)]) [t setUuid:uuid]; else [t setValue:uuid forKey:@"uuid"];
    if ([t respondsToSelector:@selector(setName:)]) [t setName:name]; else [t setValue:name forKey:@"name"];
    if ([t respondsToSelector:@selector(setCreationTime:)]) [t setCreationTime:ct]; else [t setValue:ct forKey:@"creationTime"];
    if ([t respondsToSelector:@selector(setCreationTimeOverride:)]) [t setCreationTimeOverride:cto]; else [t setValue:cto forKey:@"creationTimeOverride"];
    if ([t respondsToSelector:@selector(setDistance:)]) [t setDistance:dist]; else [t setValue:@(dist) forKey:@"distance"];
    if ([t respondsToSelector:@selector(setWeight:)]) [t setWeight:wt]; else [t setValue:@(wt) forKey:@"weight"];
    if ([t respondsToSelector:@selector(setAltitudeSmoothingFactor:)]) [t setAltitudeSmoothingFactor:asf];
    if ([t respondsToSelector:@selector(setEquipmentWeight:)])       [t setEquipmentWeight:eqw];
    if ([t respondsToSelector:@selector(setDeviceTotalTime:)])       [t setDeviceTotalTime:devT];
    [t setValue:@(moving) forKey:@"movingSpeedOnly"];
    [t setValue:@(hasD)   forKey:@"hasDistanceData"];

    const unsigned char *attrsTxt   = sqlite3_column_text(st, 12);
    const unsigned char *markersTxt = sqlite3_column_text(st, 13);
    const unsigned char *overrideTxt= sqlite3_column_text(st, 14);

    NSArray<NSString *> *attrs = AttributesFromJSONString(attrsTxt);
    if ([t respondsToSelector:@selector(setAttributes:)]) [t setAttributes:[attrs mutableCopy]]; else [t setValue:[attrs mutableCopy] forKey:@"attributes"];

    NSArray *markers = MarkersFromJSONString(markersTxt);
    if ([t respondsToSelector:@selector(setMarkers:)])    [t setMarkers:[markers mutableCopy]]; else [t setValue:[markers mutableCopy] forKey:@"markers"];

    id od = OverrideFromJSON(overrideTxt);
    if (od) {
        if ([t respondsToSelector:@selector(setOverrideData:)]) {
            [t performSelector:@selector(setOverrideData:) withObject:od];
        } else {
            @try { [t setValue:od forKey:@"overrideData"]; } @catch (__unused id e) {}
        }
    }
    sqlite3_finalize(st);

    // Laps
    NSMutableArray *laps = [NSMutableArray array];
    sqlite3_stmt *l = NULL;
    if (sqlite3_prepare_v2(_db,
       "SELECT lap_index,orig_start_time_s,start_time_delta_s,total_time_s,"
       " distance_mi,max_speed_mph,avg_speed_mph,begin_lat,begin_lon,end_lat,end_lon,"
       " device_total_time_s,average_hr,max_hr,average_cad,max_cad,calories,intensity,trigger_method,selected,stats_calculated"
       " FROM laps WHERE track_id=? ORDER BY lap_index;", -1, &l, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(l, 1, trackID);
        while (sqlite3_step(l) == SQLITE_ROW) {
            Lap *lp = [Lap new];
            if ([lp respondsToSelector:@selector(setIndex:)])           [lp setIndex:sqlite3_column_int(l,0)];
            if ([lp respondsToSelector:@selector(setOrigStartTime:)])   [lp setOrigStartTime:epochToDate(sqlite3_column_int64(l,1))];
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
            [laps addObject:lp];
        }
        sqlite3_finalize(l);
    }

    // Points
    NSMutableArray *points = [NSMutableArray array];
    sqlite3_stmt *p = NULL;
    if (sqlite3_prepare_v2(_db,
      "SELECT wall_clock_delta_s,active_time_delta_s,latitude,longitude,altitude_m,orig_altitude_m,"
      " heartrate_bpm,cadence_rpm,temperature_c,speed_mps,power_w,distance_mi,orig_distance_mi,"
      " gradient,climb_so_far_m,descent_so_far_m,flags,valid_lat_lon"
      " FROM points WHERE track_id=? ORDER BY seq;", -1, &p, NULL) == SQLITE_OK) {
        sqlite3_bind_int64(p, 1, trackID);
        while (sqlite3_step(p) == SQLITE_ROW) {
            TrackPoint *tp = [TrackPoint new];
            [tp setWallClockDelta:sqlite3_column_double(p,0)];
            [tp setActiveTimeDelta:sqlite3_column_double(p,1)];
            [tp setLatitude:sqlite3_column_double(p,2)];
            [tp setLongitude:sqlite3_column_double(p,3)];
            [tp setAltitude:sqlite3_column_double(p,4)];
            [tp setOrigAltitude:sqlite3_column_double(p,5)];
            [tp setHeartrate:sqlite3_column_double(p,6)];
            [tp setCadence:sqlite3_column_double(p,7)];
            [tp setTemperature:sqlite3_column_double(p,8)];
            [tp setSpeed:sqlite3_column_double(p,9)];
            [tp setPower:sqlite3_column_double(p,10)];
            [tp setDistance:sqlite3_column_double(p,11)];
            [tp setOrigDistance:sqlite3_column_double(p,12)];
            [tp setGradient:sqlite3_column_double(p,13)];
            [tp setClimbSoFar:sqlite3_column_double(p,14)];
            [tp setDescentSoFar:sqlite3_column_double(p,15)];
            [tp setValue:@(sqlite3_column_int(p,16)) forKey:@"flags"];
            [tp setValidLatLon:(sqlite3_column_int(p,17)!=0)];
            [points addObject:tp];
        }
        sqlite3_finalize(p);
    }

    [t setValue:laps   forKey:@"laps"];
    [t setValue:points forKey:@"points"];
    return t;
}
#endif

#if 0

- (void) saveSomeTracks:(NSArray*)inTracks
{
    NSURL *dbURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
                    URLByAppendingPathComponent:@"ascent.sqlite"];

    ActivityStore *store = [[ActivityStore alloc] initWithURL:dbURL];
    NSError *err = nil;
    [store open:&err];
    [store createSchema:&err];
    [store saveAllTracks:inTracks error:&err];
    [store close];
//    // Save a track
//    BOOL ok = [store saveTrack:track error:&err];
//
//    // Load everything
//    NSArray<Track *> *all = [store loadAllTracks:&err];
//
//    // Load one
//    Track *one = [store loadTrackWithUUID:someUUID error:&err];
}
#endif

@end

