//
//  IdentifierStore.m
//  Ascent
//

#import "IdentifierStore.h"
#import "DatabaseManager.h"

static inline NSError *IDError(sqlite3 *db, NSString *msg) {
    int code = sqlite3_errcode(db);
    const char *c = sqlite3_errmsg(db);
    return [NSError errorWithDomain:@"Ascent.DB.Identifiers" code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @"Identifier error",
                                      @"sqlite_message": c ? @(c) : @"" }];
}

@implementation IdentifierStore

- (instancetype)initWithDatabaseManager:(DatabaseManager *)dbm {
    NSParameterAssert(dbm);
    if ((self = [super init])) { _dbm = dbm; }
    return self;
}

- (void)dealloc { _dbm = nil; [super dealloc]; }

- (BOOL)createSchemaIfNeeded:(NSError **)error {
    if (_dbm.readOnly) return YES;  // no-op in read-only sessions
    __block BOOL ok = YES; __block NSError *err = nil;
    [_dbm performRead:^(sqlite3 *db) {
        const char *sql =
        "CREATE TABLE IF NOT EXISTS track_identifiers ("
        "  track_id INTEGER NOT NULL,"
        "  source   TEXT    NOT NULL,"
        "  external_id TEXT NOT NULL,"
        "  inserted_at_s INTEGER NOT NULL,"
        "  UNIQUE(source, external_id)"
        ");"
        "CREATE INDEX IF NOT EXISTS i_ident_by_track ON track_identifiers(track_id);";
        char *errmsg = NULL;
        if (sqlite3_exec(db, sql, NULL, NULL, &errmsg) != SQLITE_OK) {
            ok = NO; err = IDError(db, @"Create identifiers schema failed");
        }
    } completion:^{}];
    if (!ok && error) *error = err;
    return ok;
}

- (BOOL)linkExternalID:(NSString *)externalID
                source:(NSString *)source
             toTrackID:(int64_t)trackID
                 error:(NSError **)error
{
    __block BOOL ok = YES; __block NSError *err = nil;
    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
        sqlite3_stmt *st = NULL;
        const char *sql = "INSERT OR REPLACE INTO track_identifiers(track_id, source, external_id, inserted_at_s) "
                          "VALUES(?1, ?2, ?3, strftime('%s','now'));";
        if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) { fail(IDError(db, @"Prepare link failed")); return; }
        sqlite3_bind_int64(st, 1, trackID);
        sqlite3_bind_text(st, 2, source.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(st, 3, externalID.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(st) != SQLITE_DONE) fail(IDError(db, @"Link failed"));
        sqlite3_finalize(st);
    } completion:^(NSError * _Nullable e) { if (e){ ok = NO; err = e; } }];
    if (!ok && error) *error = err;
    return ok;
}

- (BOOL)lookupTrackIDForSource:(NSString *)source
                    externalID:(NSString *)externalID
                   outTrackID:(int64_t *_Nullable)outTrackID
                         error:(NSError **)error
{
    __block BOOL ok = YES; __block NSError *err = nil; __block int64_t tid = 0; __block BOOL found = NO;
    [_dbm performRead:^(sqlite3 *db) {
        sqlite3_stmt *st = NULL;
        const char *sql = "SELECT track_id FROM track_identifiers WHERE source=?1 AND external_id=?2;";
        if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) == SQLITE_OK) {
            sqlite3_bind_text(st, 1, source.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(st, 2, externalID.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(st) == SQLITE_ROW) { tid = sqlite3_column_int64(st, 0); found = YES; }
        } else { ok = NO; err = IDError(db, @"Prepare lookup failed"); }
        if (st) sqlite3_finalize(st);
    } completion:^{}];
    if (!ok && error) *error = err;
    if (ok && outTrackID) *outTrackID = found ? tid : 0;
    return ok && found;
}

- (BOOL)unlinkExternalID:(NSString *)externalID source:(NSString *)source error:(NSError **)error {
    __block BOOL ok = YES; __block NSError *err = nil;
    [_dbm performWrite:^(sqlite3 *db, DBErrorBlock fail) {
        sqlite3_stmt *st = NULL;
        const char *sql = "DELETE FROM track_identifiers WHERE source=?1 AND external_id=?2;";
        if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) { fail(IDError(db, @"Prepare unlink failed")); return; }
        sqlite3_bind_text(st, 1, source.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(st, 2, externalID.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(st) != SQLITE_DONE) fail(IDError(db, @"Unlink failed"));
        sqlite3_finalize(st);
    } completion:^(NSError * _Nullable e) { if (e){ ok = NO; err = e; } }];
    if (!ok && error) *error = err;
    return ok;
}

- (NSArray<NSDictionary<NSString *,NSString *> *> *)identifiersForTrackID:(int64_t)trackID
                                                                    error:(NSError **)error
{
    __block NSMutableArray *arr = [NSMutableArray array];
    __block NSError *err = nil;
    [_dbm performRead:^(sqlite3 *db) {
        sqlite3_stmt *st = NULL;
        const char *sql = "SELECT source, external_id FROM track_identifiers WHERE track_id=?1 ORDER BY source;";
        if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(st, 1, trackID);
            while (sqlite3_step(st) == SQLITE_ROW) {
                const unsigned char *s = sqlite3_column_text(st, 0);
                const unsigned char *e = sqlite3_column_text(st, 1);
                [arr addObject:@{@"source": s ? @( (const char*)s ) : @"",
                                 @"external_id": e ? @( (const char*)e ) : @""}];
            }
        } else { err = IDError(db, @"Prepare list identifiers failed"); }
        if (st) sqlite3_finalize(st);
    } completion:^{}];
    if (err && error) *error = err;
    return arr;
}

@end
