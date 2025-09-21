//
//  AscentExporter.m
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import "AscentExporter.h"
#import "DatabaseManager.h"
#import "ActivityStore.h"
#import "TrackPointStore.h"
#import "IdentifierStore.h"
#import "Track.h"
#import "TrackPoint.h"
#import "DocumentMetaData.h"


@implementation AscentExporter {
    NSURL *_url;
}

- (instancetype)initWithURL:(NSURL *)dbURL {
    NSParameterAssert(dbURL);
    if ((self = [super init])) {
        _url = [dbURL copy];
    }
    return self;
}

- (void)dealloc {
    [_url release];
    [super dealloc];
}


- (NSURL *)exportDocumentToTemporaryURLWithProgress:(ASProgress)progress
                                           metaData:(DocumentMetaData *)docMeta
                                              error:(NSError **)outError
{
    if (outError != NULL) {
        *outError = nil;
    }

    NSLog(@"[EXPORTER] FULL SAVE COMMENCING");

    NSURL *tmpDir = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *tmpURL = [tmpDir URLByAppendingPathComponent:
                     [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"ascentdb"]];

    // IMPORTANT: capture the first error here, retained, so it survives any inner @autoreleasepool.
    NSError *firstError = nil;

    // 1) Open a brand-new DB for the temp export.
    DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:tmpURL];
    {
        NSError *openErr = nil;
        if (![dbm open:&openErr]) {
            if (openErr != nil) {
                firstError = [openErr retain];
            }
            [dbm release];
            if (outError != NULL) {
                *outError = [firstError autorelease];
            }
            return nil;
        }
    }

    sqlite3 *db = [dbm rawSQLite];
    const char *dbfile = sqlite3_db_filename(db, "main");
    NSLog(@"[Diag] db handle=%p file=%s", db, dbfile ? dbfile : "(null)");

    // 2) Stores on top of that connection
    ActivityStore   *actStore   = [[ActivityStore alloc] initWithDatabaseManager:dbm];
    TrackPointStore *tpStore    = [[TrackPointStore alloc] initWithDatabaseManager:dbm];
    IdentifierStore *identStore = [[IdentifierStore alloc] initWithDatabaseManager:dbm];

    // 3) Ensure schema on each store
    {
        NSError *schemaErr = nil;
        BOOL okI = NO;
        BOOL okA = NO;
        
        BOOL okT = [tpStore createSchemaIfNeeded:&schemaErr];
        if (okT) {
            okA = [actStore createSchemaIfNeeded:&schemaErr];
        }

        if (okA && okT) {
            okI = [identStore createSchemaIfNeeded:&schemaErr];
        }

        if (!(okA && okT && okI)) {
            if (schemaErr != nil && firstError == nil) {
                firstError = [schemaErr retain];
            }
            [actStore release];
            [tpStore release];
            [identStore release];
            [dbm close];
            [dbm release];
            if (outError != NULL) {
                *outError = [firstError autorelease];
            }
            return nil;
        }
    }

    // 4) Save document meta
    {
        NSError *metaErr = nil;
        BOOL metaOK = [actStore saveMetaWithTableInfo:docMeta.tableInfoDict
                                      splitsTableInfo:docMeta.splitsTableInfoDict
                                                 uuid:docMeta.uuid
                                            startDate:(docMeta.startEndDateArray.count > 0 ? docMeta.startEndDateArray[0] : nil)
                                              endDate:(docMeta.startEndDateArray.count > 1 ? docMeta.startEndDateArray[1] : nil)
                                         lastSyncTime:docMeta.lastSyncTime
                                                flags:docMeta.flags
                                          totalTracks:(NSInteger)docMeta.trackArray.count
                                                 int3:0
                                                 int4:0
                                                error:&metaErr];
        if (!metaOK) {
            if (metaErr != nil && firstError == nil) {
                firstError = [metaErr retain];
            }
            [actStore release];
            [tpStore release];
            [identStore release];
            [dbm close];
            [dbm release];
            if (outError != NULL) {
                *outError = [firstError autorelease];
            }
            return nil;
        }
    }

    NSArray *tracks = docMeta.trackArray;
    NSUInteger total = tracks.count;
    NSUInteger idx = 0;

    // Initial progress tick (main queue)
    if (progress != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(0, total);
        });
    }

    for (Track *t in tracks) {
        @autoreleasepool {
            // Progress tick for this index (main queue)
            if (progress != nil) {
                NSUInteger current = idx;
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(current, total);
                });
            }

            // 5a) Upsert activity + laps
            t.dirtyMask = (kDirtyMeta | kDirtyLaps);

            NSError *saveErr = nil;
            if (![actStore saveTrack:t error:&saveErr]) {
                if (saveErr != nil && firstError == nil) {
                    firstError = [saveErr retain];   // <-- retain across pool
                }
                // Break *after* retaining the error so it survives draining.
                break;
            }

            // 5b) Optional external identifiers
            if ([t respondsToSelector:@selector(stravaActivityID)]) {
                NSNumber *sid = [t stravaActivityID];
                if (sid != nil) {
                    NSString *uuid = [t respondsToSelector:@selector(uuid)] ? [t uuid] : nil;
                    if (uuid.length > 0) {
                        sqlite3_stmt *st = NULL;
                        int rc = sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &st, NULL);
                        if (rc == SQLITE_OK && st != NULL) {
                            sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                            if (sqlite3_step(st) == SQLITE_ROW) {
                                int64_t trackID = sqlite3_column_int64(st, 0);
                                NSError *linkErr = nil;
                                BOOL linked = [identStore linkExternalID:sid.stringValue
                                                                  source:@"strava"
                                                               toTrackID:trackID
                                                                   error:&linkErr];
                                if (!linked && linkErr != nil && firstError == nil) {
                                    // Non-fatal per your policy; keep as warning only.
                                    // If you want to abort on this, retain as firstError and break.
                                }
                            }
                        }
                        if (st != NULL) {
                            sqlite3_finalize(st);
                        }
                    }
                }
            }
        } // autoreleasepool for this track

        // Resolve trackID for points
        NSString *uuid = [t uuid];
        int64_t trackID = 0;
        {
            sqlite3_stmt *st = NULL;
            if (sqlite3_prepare_v2(db, "SELECT id FROM activities WHERE uuid=?1;", -1, &st, NULL) == SQLITE_OK) {
                sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                if (sqlite3_step(st) == SQLITE_ROW) {
                    trackID = sqlite3_column_int64(st, 0);
                }
            }
            if (st != NULL) {
                sqlite3_finalize(st);
            }
        }

        // 5c) Save points exactly once per track
        NSArray *pts = [t respondsToSelector:@selector(points)] ? [t points] : nil;
        NSUInteger n = pts.count;

        // Always save points during full export to tmp file
        t.pointsEverSaved = NO;

        if (uuid.length > 0 && n > 0) {
            NSLog(@"[Exporter] saving %lu points for %s", (unsigned long)n, [t.name UTF8String]);

            TPRow *rows = (TPRow *)calloc(n, sizeof(TPRow));
            if (rows == NULL) {
                if (firstError == nil) {
                    NSError *oom = [NSError errorWithDomain:@"AscentExporter"
                                                       code:ENOMEM
                                                   userInfo:@{NSLocalizedDescriptionKey : @"Out of memory building TrackPoint rows"}];
                    firstError = [oom retain];
                }
                break;
            }

            for (NSUInteger i = 0; i < n; i++) {
                TrackPoint *p = (TrackPoint *)pts[i];
                rows[i].wall_clock_delta_s  = [p wallClockDelta];
                rows[i].active_time_delta_s = [p activeTimeDelta];
                rows[i].latitude_e7         = [p latitude];
                rows[i].longitude_e7        = [p longitude];
                rows[i].orig_altitude_cm    = [p origAltitude];
                rows[i].orig_distance_m     = [p origDistance];
                rows[i].heartrate_bpm       = [p heartrate];
                rows[i].cadence_rpm         = [p cadence];
                rows[i].temperature_c10     = [p temperature]; // verify units if needed
                rows[i].speed_mps           = [p speed];
                rows[i].power_w             = [p power];
                rows[i].flags               = [p flags];
            }

            NSError *pointsErr = nil;
            BOOL okPts = [tpStore replacePointsForTrack:t
                                               fromRows:rows
                                                  count:n
                                                  error:&pointsErr];
            free(rows);

            if (!okPts) {
                if (pointsErr != nil && firstError == nil) {
                    firstError = [pointsErr retain]; // survive pool
                }
                break;
            }

            // quick sanity probe
            const char *dbfileAgain = sqlite3_db_filename(db, "main");
            NSLog(@"[Diag] db handle=%p file=%s", db, dbfileAgain ? dbfileAgain : "(null)");
            [dbm performRead:^(sqlite3 *rdb) {
                sqlite3_stmt *s = NULL;
                if (sqlite3_prepare_v2(rdb, "SELECT COUNT(*) FROM points;", -1, &s, NULL) == SQLITE_OK) {
                    if (sqlite3_step(s) == SQLITE_ROW) {
                        NSLog(@"[Diag] points count now = %d", sqlite3_column_int(s, 0));
                    }
                }
                if (s) {
                    sqlite3_finalize(s);
                }
            } completion:nil];
        }

        if (firstError != nil) {
            break;
        }

        idx++;
    } // tracks loop

    // Final progress tick (main queue)
    if (progress != nil) {
        NSUInteger finalIdx = MIN(idx, total);
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(finalIdx, total);
        });
    }

    // 6) Close and return
    [actStore release];
    [tpStore release];
    [identStore release];

    [dbm close];
    [dbm release];

    if (firstError != nil) {
        if (outError != NULL) {
            *outError = [firstError autorelease]; // hand back autoreleased
        } else {
            [firstError release];
        }
        return nil;
    }

    return tmpURL;
}


- (BOOL)performIncrementalExportWithMetaData:(DocumentMetaData *)docMeta
                            databaseManager:(DatabaseManager *)dbm
                              activityStore:(ActivityStore *)actStore
                           trackPointStore:(TrackPointStore *)tpStore
                          identifierStore:(IdentifierStore *)identStore
                                     error:(NSError **)outError
{
    if (docMeta == nil || dbm == nil || actStore == nil || tpStore == nil || identStore == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"AscentExporter"
                                            code:-1
                                        userInfo:@{ NSLocalizedDescriptionKey : @"Nil argument(s) to performIncrementalExportWithMetaData" }];
        }
        return NO;
    }
    NSLog(@"[EXPORTER] INCREMENTAL SAVE COMMENCING");
    NSError *err = nil;

    // ---- 1) Save META (table/splits info, dates, flags, counts) ----
    BOOL metaOK = [actStore saveMetaWithTableInfo:docMeta.tableInfoDict
                                   splitsTableInfo:docMeta.splitsTableInfoDict
                                              uuid:docMeta.uuid
                                         startDate:docMeta.startEndDateArray.count > 0 ? docMeta.startEndDateArray[0] : nil
                                           endDate:docMeta.startEndDateArray.count > 1 ? docMeta.startEndDateArray[1] : nil
                                      lastSyncTime:docMeta.lastSyncTime
                                             flags:docMeta.flags
                                       totalTracks:(NSInteger)docMeta.trackArray.count
                                              int3:0
                                              int4:0
                                             error:&err];
    if (!metaOK) {
        if (outError) {
            *outError = err ?: [NSError errorWithDomain:@"AscentExporter"
                                                   code:-2
                                               userInfo:@{ NSLocalizedDescriptionKey : @"Failed to save document metadata" }];
        }
        return NO;
    }

    // ---- 2) Save each track's activity/laps; link identifiers; save points (first time only) ----
    sqlite3 *rawDB = [dbm rawSQLite];

    for (Track *t in docMeta.trackArray) {
        @autoreleasepool {
            // 2a) Upsert the activity + laps using ActivityStore (respects dirty bits)
            BOOL saved = [actStore saveTrack:t error:&err];
            if (!saved) {
                if (outError) {
                    *outError = err ?: [NSError errorWithDomain:@"AscentExporter"
                                                           code:-3
                                                       userInfo:@{ NSLocalizedDescriptionKey : @"saveTrack failed" }];
                }
                return NO;
            }

            // 2b) Resolve activities.id via uuid (needed for identifiers and debug)
            NSString *uuid = nil;
            if ([t respondsToSelector:@selector(uuid)]) {
                uuid = [t uuid];
            } else {
                @try { uuid = [t valueForKey:@"uuid"]; } @catch (__unused id e) {}
            }

            if (uuid.length == 0) {
                if (outError) {
                    *outError = [NSError errorWithDomain:@"AscentExporter"
                                                    code:-4
                                                userInfo:@{ NSLocalizedDescriptionKey : @"Track missing uuid during incremental export" }];
                }
                return NO;
            }

            sqlite3_int64 trackID = 0;
            {
                sqlite3_stmt *st = NULL;
                int prc = sqlite3_prepare_v2(rawDB, "SELECT id FROM activities WHERE uuid=?1;", -1, &st, NULL);
                if (prc == SQLITE_OK) {
                    sqlite3_bind_text(st, 1, uuid.UTF8String, -1, SQLITE_TRANSIENT);
                    if (sqlite3_step(st) == SQLITE_ROW) {
                        trackID = sqlite3_column_int64(st, 0);
                    }
                }
                if (st != NULL) {
                    sqlite3_finalize(st);
                }
            }

            if (trackID == 0) {
                if (outError) {
                    *outError = [NSError errorWithDomain:@"AscentExporter"
                                                    code:-5
                                                userInfo:@{ NSLocalizedDescriptionKey : @"Failed to resolve activities.id for uuid" }];
                }
                return NO;
            }

            // 2c) Optional: link identifier(s), e.g. Strava activity id
            if ([t respondsToSelector:@selector(stravaActivityID)]) {
                NSNumber *sid = [t stravaActivityID];
                if (sid != nil) {
                    BOOL linked = [identStore linkExternalID:sid.stringValue
                                                      source:@"strava"
                                                   toTrackID:trackID
                                                       error:&err];
                    if (!linked) {
                        // Non-fatal by policy; warn if needed
                        // NSLog(@"[AscentExporter] Warning: linkExternalID failed for uuid %@: %@", uuid, err);
                        err = nil;
                    }
                }
            }

            // 2d) Points are immutable: only insert if this is the first time (pointsEverSaved == NO)
            BOOL shouldSavePoints = NO;
            if ([t respondsToSelector:@selector(pointsEverSaved)]) {
                shouldSavePoints = ![t pointsEverSaved];
            } else {
                // If the Track doesn’t expose pointsEverSaved yet, fall back to checking DB column via ActivityStore if you prefer.
                shouldSavePoints = NO;
            }

            if (shouldSavePoints) {
                
                NSLog(@"[EXPORTER] is saving points");
                
                NSArray *pts = nil;
                if ([t respondsToSelector:@selector(points)]) {
                    pts = [t points];
                } else {
                    @try { pts = [t valueForKey:@"points"]; } @catch (__unused id e) {}
                }

                NSUInteger n = pts.count;
                if (n > 0) {
                    TPRow *rows = (TPRow *)calloc(n, sizeof(TPRow));
                    if (rows == NULL) {
                        if (outError) {
                            *outError = [NSError errorWithDomain:@"AscentExporter"
                                                            code:ENOMEM
                                                        userInfo:@{ NSLocalizedDescriptionKey : @"Out of memory building TPRow buffer" }];
                        }
                        return NO;
                    }

                    for (NSUInteger i = 0; i < n; i++) {
                        TrackPoint *p = (TrackPoint *)pts[i];

                        rows[i].wall_clock_delta_s  = [p wallClockDelta];
                        rows[i].active_time_delta_s = [p activeTimeDelta];
                        rows[i].latitude_e7         = [p latitude];
                        rows[i].longitude_e7        = [p longitude];
                        rows[i].orig_altitude_cm    = [p origAltitude];
                        rows[i].orig_distance_m     = [p origDistance];
                        rows[i].heartrate_bpm       = [p heartrate];
                        rows[i].cadence_rpm         = [p cadence];
                        rows[i].temperature_c10     = [p temperature];  // if you store C*10, ensure value matches schema
                        rows[i].speed_mps           = [p speed];
                        rows[i].power_w             = [p power];
                        rows[i].flags               = [p flags];
                    }

                    BOOL okPts = [tpStore replacePointsForTrack:t
                                                       fromRows:rows
                                                          count:n
                                                          error:&err];
                    free(rows);

                    if (!okPts) {
                        if (outError) {
                            *outError = err ?: [NSError errorWithDomain:@"AscentExporter"
                                                                   code:-6
                                                               userInfo:@{ NSLocalizedDescriptionKey : @"replacePointsForTrack failed" }];
                        }
                        return NO;
                    }

                    // Mark as saved in-memory (so subsequent passes can skip)
                    NSLog(@"[Exporter] setting pointsEverSaved for %s to YES", [t.name UTF8String]);
                   if ([t respondsToSelector:@selector(setPointsEverSaved:)]) {
                        [t setPointsEverSaved:YES];
                    } else {
                        @try {
                            [t setValue:@(YES)
                                 forKey:@"pointsEverSaved"];
                        }
                        @catch (__unused id e) {}
                    }
                }
            }
        } // @autoreleasepool
    }     // for each track

    return YES;
}


@end
