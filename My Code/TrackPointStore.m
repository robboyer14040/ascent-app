//
//  TrackPointStore.m
//  Ascent
//

#import "TrackPointStore.h"
#import "DatabaseManager.h"
#import "TrackPoint.h"

#pragma mark - Helpers

static inline NSError *TPError(sqlite3 *db, NSString *msg) {
    int code = sqlite3_errcode(db);
    const char *c = sqlite3_errmsg(db);
    return [NSError errorWithDomain:@"Ascent.DB.TrackPoints" code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @"TP error",
                                      @"sqlite_message": c ? @(c) : @"" }];
}


static BOOL TPResolveTrackIDForUUID(sqlite3 *db, NSString *uuid, int64_t *outID) {
    if (!uuid.length || !outID) return NO;
    sqlite3_stmt *st = NULL;
    const char *sql = "SELECT id FROM activities WHERE uuid=?1;";
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) return NO;
    sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);

    BOOL ok = NO;
    if (sqlite3_step(st) == SQLITE_ROW)
    {
        *outID = sqlite3_column_int64(st, 0);
        ok = YES;
    }
    if (st)
        sqlite3_finalize(st);
    return ok;
}


// Convert a TPRow into a TrackPoint (MRC-safe)
static inline TrackPoint *TPMakeTrackPointFromRow(const TPRow *r) {
    const double kE7 = 1e7;
    const double kCM = 100.0;
    const double kM_TO_MI = 0.00062137119223733397;

    TrackPoint *tp = [TrackPoint new];

    if ([tp respondsToSelector:@selector(setWallClockDelta:)])  [tp setWallClockDelta:(double)r->wall_clock_delta_s];
    if ([tp respondsToSelector:@selector(setActiveTimeDelta:)]) [tp setActiveTimeDelta:(double)r->active_time_delta_s];

    double lat = ((double)r->latitude_e7); // / kE7;
    double lon = ((double)r->longitude_e7); // / kE7;
    if ([tp respondsToSelector:@selector(setLatitude:)])  [tp setLatitude:lat];
    if ([tp respondsToSelector:@selector(setLongitude:)]) [tp setLongitude:lon];

    double alt_m = ((double)r->orig_altitude_cm); // / kCM;
    if ([tp respondsToSelector:@selector(setAltitude:)])     [tp setAltitude:alt_m];
    if ([tp respondsToSelector:@selector(setOrigAltitude:)]) [tp setOrigAltitude:alt_m];

    if ([tp respondsToSelector:@selector(setHeartrate:)]) [tp setHeartrate:(double)r->heartrate_bpm];
    if ([tp respondsToSelector:@selector(setCadence:)])   [tp setCadence:(double)r->cadence_rpm];

    // tenths of °C -> °C
    double tempC = ((double)r->temperature_c10); // / 10.0;
    if ([tp respondsToSelector:@selector(setTemperature:)]) [tp setTemperature:tempC];

    if ([tp respondsToSelector:@selector(setSpeed:)]) [tp setSpeed:(double)r->speed_mps];
    if ([tp respondsToSelector:@selector(setPower:)]) [tp setPower:(double)r->power_w];

    double dist_mi = ((double)r->orig_distance_m); // * kM_TO_MI;
    if ([tp respondsToSelector:@selector(setDistance:)])     [tp setDistance:dist_mi];
    if ([tp respondsToSelector:@selector(setOrigDistance:)]) [tp setOrigDistance:dist_mi];

    if ([tp respondsToSelector:@selector(setFlags:)]) [tp setFlags:(int)r->flags];

    return tp; // caller will autorelease
}

#pragma mark - TrackPointStore

@implementation TrackPointStore

- (instancetype)initWithDatabaseManager:(DatabaseManager *)dbm {
    NSParameterAssert(dbm);
    if ((self = [super init])) {
        _dbm = dbm; // assign (non-owning)
    }
    return self;
}

- (void)dealloc { _dbm = nil; [super dealloc]; }

#pragma mark Schema

- (BOOL)createSchemaIfNeeded:(NSError **)error {
    if (_dbm.readOnly) return YES;  // no-op in read-only sessions
    __block BOOL ok = YES; __block NSError *err = nil;

    // Do schema changes under a WRITE
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
        const char *sql =
        // WITHOUT ROWID composite PK: (track_id, wall_clock_delta_s)
        "CREATE TABLE IF NOT EXISTS points ("
        "  track_id            INTEGER NOT NULL,"
        "  wall_clock_delta_s  INTEGER NOT NULL,"
        "  active_time_delta_s INTEGER NOT NULL DEFAULT 0,"
        "  latitude_e7         REAL NOT NULL,"
        "  longitude_e7        REAL NOT NULL,"
        "  orig_altitude_cm    REAL DEFAULT 0,"
        "  heartrate_bpm       REAL DEFAULT 0,"
        "  cadence_rpm         REAL DEFAULT 0,"
        "  temperature_c10     REAL DEFAULT 0,"
        "  speed_mps           REAL    DEFAULT 0,"
        "  power_w             REAL    DEFAULT 0,"
        "  orig_distance_m     REAL    DEFAULT 0,"
        "  flags               INTEGER DEFAULT 0,"
        "  PRIMARY KEY(track_id, wall_clock_delta_s)"
        ") WITHOUT ROWID;"
        // Helpful covering index for typical scans and counts (leftmost prefix is track_id)
        "CREATE INDEX IF NOT EXISTS i_points_track_time "
        "  ON points(track_id, wall_clock_delta_s, active_time_delta_s);";

        char *errmsg = NULL;
        if (sqlite3_exec(db, sql, NULL, NULL, &errmsg) != SQLITE_OK) {
            fail(TPError(db, @"Create points schema failed"));
            if (errmsg) sqlite3_free(errmsg);
        }
    } completion:^(NSError * _Nullable e) {
        if (e) { ok = NO; err = e; }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = err;
    return ok;
}

#pragma mark Loads

- (NSArray<TrackPoint *> *)loadPointsForTrackUUID:(NSString *)uuid error:(NSError **)error
{
    __block NSArray *result = nil;
    __block NSError *err = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [_dbm performRead:^(sqlite3 *db) {
        @autoreleasepool {
            if (!db) { err = TPError(NULL, @"DB handle is NULL"); goto done; }

            sqlite3_extended_result_codes(db, 1);

            // Sanity: log open state and connection identity
            int ro = sqlite3_db_readonly(db, NULL);
            const char *dbfile = sqlite3_db_filename(db, "main");

            // 0) prove there are no stray statements that might be finalized elsewhere
            int stray = 0;
            for (sqlite3_stmt *p = sqlite3_next_stmt(db, NULL); p; p = sqlite3_next_stmt(db, p)) stray++;
            if (stray) NSLog(@"[TP] WARNING: %d statements already active on this connection", stray);

            // 1) resolve track id
            int64_t trackID = 0;
            if (!TPResolveTrackIDForUUID(db, uuid, &trackID)) {
                err = TPError(db, [NSString stringWithFormat:@"No activity row for uuid %@", uuid ?: @"(nil)"]);
                goto done;
            }
            ///NSLog(@"reading points for track %d", (int)trackID);
            // 2) prepare
            const char *sql =
                "SELECT wall_clock_delta_s, active_time_delta_s, latitude_e7, longitude_e7, "
                "       orig_altitude_cm, heartrate_bpm, cadence_rpm, temperature_c10, "
                "       speed_mps, power_w, orig_distance_m, flags "
                "FROM points WHERE track_id=?1 "
                "ORDER BY wall_clock_delta_s ASC, active_time_delta_s ASC;";

            sqlite3_stmt *st = NULL;
            int rc = sqlite3_prepare_v2(db, sql, -1, &st, NULL);
            if (rc != SQLITE_OK || !st) {
                err = TPError(db, [NSString stringWithFormat:@"prepare failed rc=%d xrc=%d: %s",
                                   rc, sqlite3_extended_errcode(db), sqlite3_errmsg(db)]);
                goto done;
            }

            // 2a) prove the stmt belongs to THIS db
            if (sqlite3_db_handle(st) != db) {
                err = TPError(db, @"MISUSE: statement bound to a different sqlite3*");
                sqlite3_finalize(st);
                goto done;
            }

            // 3) bind
            rc = sqlite3_bind_int64(st, 1, trackID);
            if (rc != SQLITE_OK) {
                err = TPError(db, [NSString stringWithFormat:@"bind failed rc=%d xrc=%d: %s",
                                   rc, sqlite3_extended_errcode(db), sqlite3_errmsg(db)]);
                sqlite3_finalize(st);
                goto done;
            }

            // 4) step
            NSMutableArray *accum = [NSMutableArray array];
            rc = sqlite3_step(st);

            if (rc == SQLITE_ROW) {
                // normal path
                do {
                    TPRow r;
                    r.wall_clock_delta_s  = sqlite3_column_int64(st, 0);
                    r.active_time_delta_s = sqlite3_column_int64(st, 1);
                    r.latitude_e7         = (float)sqlite3_column_double(st, 2);
                    r.longitude_e7        = (float)sqlite3_column_double(st, 3);
                    r.orig_altitude_cm    = (float)sqlite3_column_double(st, 4);
                    r.heartrate_bpm       = (float)sqlite3_column_double(st, 5);
                    r.cadence_rpm         = (float)sqlite3_column_double(st, 6);
                    r.temperature_c10     = (float)sqlite3_column_double(st, 7);
                    r.speed_mps           = (float)sqlite3_column_double(st, 8);
                    r.power_w             = (float)sqlite3_column_double(st, 9);
                    r.orig_distance_m     = (float)sqlite3_column_double(st,10);
                    r.flags               = (uint32_t)sqlite3_column_int(st,11);

                    TrackPoint *tp = TPMakeTrackPointFromRow(&r);
                    [accum addObject:tp];
                    [tp release];
                } while ((rc = sqlite3_step(st)) == SQLITE_ROW);

                if (rc != SQLITE_DONE) {
                    err = TPError(db, [NSString stringWithFormat:@"step mid-rows rc=%d xrc=%d: %s",
                                       rc, sqlite3_extended_errcode(db), sqlite3_errmsg(db)]);
                }
            } else if (rc == SQLITE_DONE) {
                // zero rows, OK
            } else {
                // *** THIS IS YOUR 101 CASE ***
                int xrc = sqlite3_extended_errcode(db);
                const char *em = sqlite3_errmsg(db);
                // Dump a little more state to help find misuse source
                int stray2 = 0;
                for (sqlite3_stmt *p = sqlite3_next_stmt(db, NULL); p; p = sqlite3_next_stmt(db, p)) stray2++;
                NSLog(@"[TP] step-first rc=%d xrc=%d msg=%s (active stmts now=%d)", rc, xrc, em?: "", stray2);
                err = TPError(db, [NSString stringWithFormat:@"MISUSE on first step rc=%d xrc=%d: %s", rc, xrc, em]);
            }

            sqlite3_finalize(st);
            if (!err) result = [[accum copy] retain];
        }
    done: ;
    } completion:^{ dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (err && error) *error = err;
    return result;
}

- (NSArray<TrackPoint *> *)loadPointsForTrackID:(int64_t)trackID error:(NSError **)error {
    __block NSArray *result = nil;
    __block NSError *err = nil;

    [_dbm performRead:^(sqlite3 *db) {
        NSMutableArray *arr = [NSMutableArray array];
        const char *sql =
        "SELECT wall_clock_delta_s, active_time_delta_s, latitude_e7, longitude_e7, "
        "       orig_altitude_cm, heartrate_bpm, cadence_rpm, temperature_c10, "
        "       speed_mps, power_w, orig_distance_m, flags "
        "FROM points WHERE track_id=?1 "
        "ORDER BY wall_clock_delta_s ASC, active_time_delta_s ASC;";
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) {
            err = TPError(db, @"Prepare load points (id) failed");
            return;
        }
        sqlite3_bind_int64(st, 1, trackID);

        while (1) {
            int s = sqlite3_step(st);
            if (s == SQLITE_ROW) {
                TPRow row;
                row.wall_clock_delta_s  = sqlite3_column_int64(st, 0);
                row.active_time_delta_s = sqlite3_column_int64(st, 1);
                row.latitude_e7         = (float)sqlite3_column_double(st, 2);
                row.longitude_e7        = (float)sqlite3_column_double(st, 3);
                row.orig_altitude_cm    = (float)sqlite3_column_double(st, 4);
                row.heartrate_bpm       = (float)sqlite3_column_double(st, 5);
                row.cadence_rpm         = (float)sqlite3_column_double(st, 6);
                row.temperature_c10     = (float)sqlite3_column_double(st, 7);
                row.speed_mps           = (float)sqlite3_column_double(st, 8);
                row.power_w             = (float)sqlite3_column_double(st, 9);
                row.orig_distance_m     = (float)sqlite3_column_double(st,10);
                row.flags               = (uint32_t)sqlite3_column_int(st,11);

                TrackPoint *tp = TPMakeTrackPointFromRow(&row);
                [arr addObject:tp];
                [tp release];
            } else if (s == SQLITE_DONE) {
                break;
            } else {
                err = TPError(db, @"Step load points (id) failed");
                break;
            }
        }
        if (st) sqlite3_finalize(st);
        if (!err) result = [[arr copy] autorelease];
    } completion:^{}];

    if (error && err) *error = err;
    return result;
}

#pragma mark Writes

- (BOOL)replacePointsForTrackID:(int64_t)trackID
                       fromRows:(const TPRow *)rows
                          count:(NSUInteger)count
                          error:(NSError **)error
{
    // Defensive copy so caller's buffer may go out of scope
    TPRow *rowsCopy = NULL;
    if (count) {
        size_t bytes = count * sizeof(TPRow);
        rowsCopy = (TPRow *)malloc(bytes);
        if (!rowsCopy) {
            if (error) *error = [NSError errorWithDomain:@"Ascent.DB.TrackPoints"
                                                    code:ENOMEM
                                                userInfo:@{NSLocalizedDescriptionKey:@"Out of memory copying points"}];
            return NO;
        }
        memcpy(rowsCopy, rows, bytes);
    }

    __block BOOL ok = YES;
    __block NSError *err = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {

        // Delete existing points for this track
        sqlite3_stmt *del = NULL;
        if (sqlite3_prepare_v2(db, "DELETE FROM points WHERE track_id=?1;", -1, &del, NULL) != SQLITE_OK) {
            fail(TPError(db, @"Prepare delete points failed"));
            goto done;
        }
        sqlite3_bind_int64(del, 1, trackID);
        if (sqlite3_step(del) != SQLITE_DONE) {
            fail(TPError(db, @"Delete points failed"));
            sqlite3_finalize(del);
            goto done;
        }
        sqlite3_finalize(del);

        // Insert replacements
        const char *insSQL =
        "INSERT INTO points("
        " track_id, wall_clock_delta_s, active_time_delta_s, "
        " latitude_e7, longitude_e7, orig_altitude_cm, heartrate_bpm, cadence_rpm, "
        " temperature_c10, speed_mps, power_w, orig_distance_m, flags)"
        " VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13);";

        sqlite3_stmt *ins = NULL;
        if (sqlite3_prepare_v2(db, insSQL, -1, &ins, NULL) != SQLITE_OK) {
            fail(TPError(db, @"Prepare insert failed"));
            goto done;
        }
        ///NSLog(@"writing %d points for track %d...", (int)count, (int)trackID);
        for (NSUInteger i = 0; i < count; i++) {
            const TPRow *r = &rowsCopy[i];

            sqlite3_bind_int64(ins, 1,  trackID);
            sqlite3_bind_int64(ins, 2,  r->wall_clock_delta_s);
            sqlite3_bind_int64(ins, 3,  r->active_time_delta_s);
            sqlite3_bind_double   (ins, 4,  r->latitude_e7);
            sqlite3_bind_double   (ins, 5,  r->longitude_e7);
            sqlite3_bind_double   (ins, 6,  r->orig_altitude_cm);
            sqlite3_bind_double   (ins, 7,  r->heartrate_bpm);
            sqlite3_bind_double   (ins, 8,  r->cadence_rpm);
            sqlite3_bind_double   (ins, 9,  r->temperature_c10);
            sqlite3_bind_double(ins,10,  r->speed_mps);
            sqlite3_bind_double(ins,11,  r->power_w);
            sqlite3_bind_double(ins,12,  r->orig_distance_m);
            sqlite3_bind_int   (ins,13,  r->flags);

            int rc = sqlite3_step(ins);
            if (rc != SQLITE_DONE) {
                int xrc = sqlite3_extended_errcode(db);
                NSString *msg = [NSString stringWithFormat:@"Insert point failed (rc=%d,xrc=%d): %s",
                                 rc, xrc, sqlite3_errmsg(db)];
                fail(TPError(db, msg));
                sqlite3_reset(ins);
                break;
            }
            sqlite3_reset(ins);
        }

        sqlite3_finalize(ins);

    done: ;
    } completion:^(NSError * _Nullable e) {
        if (e) { ok = NO; err = [e retain]; }
        if (rowsCopy) free(rowsCopy);
        dispatch_semaphore_signal(sem);
    }];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_release(sem);

    if (!ok && error) *error = [err autorelease];
    return ok;
}

- (BOOL)deletePointsForTrackID:(int64_t)trackID error:(NSError **)error {
    __block BOOL ok = YES; __block NSError *err = nil;
    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, "DELETE FROM points WHERE track_id=?1;", -1, &st, NULL) != SQLITE_OK) {
            fail(TPError(db, @"Prepare delete failed"));
        } else {
            sqlite3_bind_int64(st, 1, trackID);
            if (sqlite3_step(st) != SQLITE_DONE) fail(TPError(db, @"Delete failed"));
        }
        if (st) sqlite3_finalize(st);
    } completion:^(NSError * _Nullable e) { if (e){ ok = NO; err = e; } }];
    if (!ok && error) *error = err;
    return ok;
}

- (BOOL)countForTrackID:(int64_t)trackID outCount:(int64_t *)count error:(NSError **)error {
    __block BOOL ok = YES; __block NSError *err = nil; __block int64_t c = 0;
    [_dbm performRead:^(sqlite3 *db) {
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM points WHERE track_id=?1;", -1, &st, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(st, 1, trackID);
            if (sqlite3_step(st) == SQLITE_ROW) c = sqlite3_column_int64(st, 0);
        } else { ok = NO; err = TPError(db, @"Prepare count failed"); }
        if (st) sqlite3_finalize(st);
    } completion:^{}];
    if (ok && count) *count = c;
    if (!ok && error) *error = err;
    return ok;
}

@end
