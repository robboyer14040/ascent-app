//
//  LibraryController.m
//  Ascent
//

#import "LibraryController.h"
#import "DatabaseManager.h"
#import "ActivityStore.h"
#import "TrackPointStore.h"
#import "IdentifierStore.h"

NSNotificationName const AscentLibraryControllerActiveLibraryDidChangeNotification = @"AscentLibraryControllerActiveLibraryDidChangeNotification";
NSNotificationName const AscentLibraryControllerLibrariesDidChangeNotification      = @"AscentLibraryControllerLibrariesDidChangeNotification";
NSErrorDomain const AscentLibraryControllerErrorDomain = @"Ascent.LibraryController";

@implementation AscentLibrary

- (void)dealloc {
#if TARGET_OS_OSX
    if (_hasSecurityScope && _fileURL) { [_fileURL stopAccessingSecurityScopedResource]; }
#endif
    [_fileURL release];
    [_bookmarkData release];
    [_displayName release];
    [_db release];
    [_activities release];
    [_points release];
    [_identifiers release];
    [super dealloc];
}

- (NSURL *)fileURL { return _fileURL; }
- (NSData *)bookmarkData { return _bookmarkData; }
- (NSString *)displayName { return _displayName; }
- (DatabaseManager *)db { return _db; }
- (ActivityStore *)activities { return _activities; }
- (TrackPointStore *)points { return _points; }
- (IdentifierStore *)identifiers { return _identifiers; }
- (NSInteger)trackCount { return _trackCount; }
- (int64_t)totalPoints { return _totalPoints; }
- (uint64_t)fileSizeBytes { return _fileSizeBytes; }
- (BOOL)hasSecurityScope { return _hasSecurityScope; }

- (void)setFileURL:(NSURL *)url { if (_fileURL != url){ [_fileURL release]; _fileURL = [url retain]; } }
- (void)setBookmarkData:(NSData *)data { if (_bookmarkData != data){ [_bookmarkData release]; _bookmarkData = [data retain]; } }
- (void)setDisplayName:(NSString *)name { if (_displayName != name){ [_displayName release]; _displayName = [name retain]; } }
- (void)setDb:(DatabaseManager *)db { if (_db != db){ [_db release]; _db = [db retain]; } }
- (void)setActivities:(ActivityStore *)s { if (_activities != s){ [_activities release]; _activities = [s retain]; } }
- (void)setPoints:(TrackPointStore *)s { if (_points != s){ [_points release]; _points = [s retain]; } }
- (void)setIdentifiers:(IdentifierStore *)s { if (_identifiers != s){ [_identifiers release]; _identifiers = [s retain]; } }
- (void)setTrackCount:(NSInteger)c { _trackCount = c; }
- (void)setTotalPoints:(int64_t)p { _totalPoints = p; }
- (void)setFileSizeBytes:(uint64_t)b { _fileSizeBytes = b; }
- (void)setHasSecurityScope:(BOOL)flag { _hasSecurityScope = flag; }

@end

@implementation LibraryController

- (instancetype)initWithStateDirectoryURL:(NSURL *)stateDirURL {
    NSParameterAssert(stateDirURL);
    if ((self = [super init])) {
        _stateDirURL = [stateDirURL retain];
        _controllerQueue = dispatch_queue_create("com.montebellosoftware.Ascent.LibraryControllerQ",
                          dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
        _mutableLibraries = [[NSMutableArray alloc] init];
        [[NSFileManager defaultManager] createDirectoryAtURL:stateDirURL
                                 withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return self;
}

- (void)dealloc {
    if (_controllerQueue) { dispatch_release(_controllerQueue); _controllerQueue = NULL; }
    [_stateDirURL release];
    [_mutableLibraries release];
    [super dealloc];
}

- (dispatch_queue_t)controllerQueue { return _controllerQueue; }
- (NSArray<AscentLibrary *> *)openLibraries {
    @synchronized (self) { return [[_mutableLibraries copy] autorelease]; }
}
- (AscentLibrary *)activeLibrary { @synchronized (self) { return _activeLibrary; } }
- (void)setActiveLibraryInternal:(AscentLibrary *)lib {
    @synchronized (self) {
        if (_activeLibrary != lib) {
            [_activeLibrary release];
            _activeLibrary = [lib retain];
        }
    }
}

- (void)createLibraryAtURL:(NSURL *)url completion:(void (^)(AscentLibrary *, NSError *))completion {
    [self openOrCreate:url create:YES completion:completion];
}

- (void)openLibraryAtURL:(NSURL *)url completion:(void (^)(AscentLibrary *, NSError *))completion {
    [self openOrCreate:url create:NO completion:completion];
}

- (void)openOrCreate:(NSURL *)url create:(BOOL)create completion:(void (^)(AscentLibrary *, NSError *))completion {
    dispatch_async(_controllerQueue, ^{
        for (AscentLibrary *lib in _mutableLibraries) {
            if ([lib.fileURL isEqual:url]) {
                [self setActiveLibraryInternal:lib];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification object:self];
                    if (completion) completion(lib, nil);
                });
                return;
            }
        }

        if ([_delegate respondsToSelector:@selector(libraryWillOpenAtURL:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [_delegate libraryWillOpenAtURL:url]; });
        }

        NSData *bookmark = nil;
        BOOL needsScope = NO;
#if TARGET_OS_OSX
        NSString *p = url.path;
        needsScope = ([p rangeOfString:@"/Library/Containers/"].location == NSNotFound);
        if (needsScope) {
            NSError *bmErr = nil;
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                     includingResourceValuesForKeys:nil relativeToURL:nil error:&bmErr];
            if (!bookmark) {
                NSError *e = [NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                                 code:AscentLibraryControllerErrorBookmarkInvalid
                                             userInfo:@{NSLocalizedDescriptionKey:@"Failed to create security-scoped bookmark",
                                                        NSUnderlyingErrorKey: bmErr ?: [NSNull null]}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, e); });
                return;
            }
        }
#endif

        AscentLibrary *lib = [[AscentLibrary alloc] init];
        [lib setFileURL:url];
        [lib setBookmarkData:bookmark];
        [lib setDisplayName:url.lastPathComponent];

#if TARGET_OS_OSX
        if (needsScope) [lib setHasSecurityScope:[url startAccessingSecurityScopedResource]];
#endif

        DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:url];
        NSError *openErr = nil;
        if (![dbm open:&openErr]) {
#if TARGET_OS_OSX
            if (lib.hasSecurityScope) { [url stopAccessingSecurityScopedResource]; [lib setHasSecurityScope:NO]; }
#endif
            NSError *e = [NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                             code:AscentLibraryControllerErrorOpenFailed
                                         userInfo:@{NSLocalizedDescriptionKey:@"Failed to open database",
                                                    NSUnderlyingErrorKey: openErr ?: [NSNull null]}];
            [lib release];
            [dbm release];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, e); });
            return;
        }

        [lib setDb:dbm];

        ActivityStore   *activities = [[ActivityStore alloc] initWithDatabase:[dbm rawSQLite]];
        TrackPointStore *points     = [[TrackPointStore alloc] initWithDatabaseManager:dbm];
        IdentifierStore *idents     = [[IdentifierStore alloc] initWithDatabaseManager:dbm];

        NSError *schemaErr = nil;
        if (![activities open:&schemaErr] ||
            ![points createSchemaIfNeeded:&schemaErr] ||
            ![idents createSchemaIfNeeded:&schemaErr]) {
            [dbm close];
#if TARGET_OS_OSX
            if (lib.hasSecurityScope) { [url stopAccessingSecurityScopedResource]; [lib setHasSecurityScope:NO]; }
#endif
            [activities release];
            [points release];
            [idents release];
            [dbm release];
            [lib release];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, schemaErr); });
            return;
        }

        [lib setActivities:activities];
        [lib setPoints:points];
        [lib setIdentifiers:idents];
        [activities release];
        [points release];
        [idents release];
        [dbm release];

        @synchronized (self) { [_mutableLibraries addObject:lib]; }
        [self setActiveLibraryInternal:lib];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_delegate respondsToSelector:@selector(libraryDidOpen:)]) { [_delegate libraryDidOpen:lib]; }
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification object:self];
            if (completion) completion([lib autorelease], nil);
        });
    });
}

- (void)closeLibrary:(AscentLibrary *)library completion:(void (^)(NSError *))completion {
    if (!library) { if (completion) completion(nil); return; }
    dispatch_async(_controllerQueue, ^{
        if ([_delegate respondsToSelector:@selector(libraryWillClose:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [_delegate libraryWillClose:library]; });
        }
        [[library db] close];
#if TARGET_OS_OSX
        if (library.hasSecurityScope) {
            [library.fileURL stopAccessingSecurityScopedResource];
            [library setHasSecurityScope:NO];
        }
#endif
        @synchronized (self) {
            [_mutableLibraries removeObject:library];
            if ([self activeLibrary] == library) {
                [self setActiveLibraryInternal:(_mutableLibraries.count ? [_mutableLibraries objectAtIndex:0] : nil)];
            }
        }
        NSURL *closedURL = [library.fileURL retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification object:self];
            if ([_delegate respondsToSelector:@selector(libraryDidCloseURL:)]) { [_delegate libraryDidCloseURL:closedURL]; }
            [closedURL release];
            if (completion) completion(nil);
        });
    });
}

- (void)closeAllLibrariesWithCompletion:(void (^)(NSError *))completion {
    dispatch_async(_controllerQueue, ^{
        NSArray *libs = nil;
        @synchronized (self) { libs = [[_mutableLibraries copy] autorelease]; }
        for (AscentLibrary *lib in libs) {
            [[lib db] close];
#if TARGET_OS_OSX
            if (lib.hasSecurityScope) {
                [lib.fileURL stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
        }
        @synchronized (self) {
            [_mutableLibraries removeAllObjects];
            [self setActiveLibraryInternal:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification object:self];
            if (completion) completion(nil);
        });
    });
}

- (void)selectActiveLibrary:(AscentLibrary *)library {
    dispatch_async(_controllerQueue, ^{
        @synchronized (self) {
            if ([_mutableLibraries containsObject:library]) {
                [self setActiveLibraryInternal:library];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification object:self];
        });
    });
}

- (NSArray<NSURL *> *)recentLibraryURLs {
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    @synchronized (self) {
        for (AscentLibrary *lib in _mutableLibraries) { [urls addObject:[lib fileURL]]; }
    }
    return urls;
}

- (void)recordRecentLibraryURL:(NSURL *)url bookmark:(NSData *)bookmarkData {
    (void)url; (void)bookmarkData; // stub for MRU persistence
}

- (void)pruneRecentLibraryURL:(NSURL *)url { (void)url; }

- (void)exportActiveLibrarySnapshotToURL:(NSURL *)destURL
                              completion:(void (^)(NSError *))completion
{
    AscentLibrary *lib = [self activeLibrary];
    if (!lib) { if (completion) completion([NSError errorWithDomain:AscentLibraryControllerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"No active library"}]); return; }
    dispatch_async(_controllerQueue, ^{
        NSError *err = nil;
        BOOL ok = [[lib db] exportSnapshotToURL:destURL error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok ? nil : err); });
    });
}

- (void)refreshStatsForLibrary:(AscentLibrary *)library completion:(void (^)(NSError *))completion {
    if (!library) { if (completion) completion(nil); return; }
    [[library db] performRead:^(sqlite3 *db) {
        sqlite3_stmt *st = NULL;
        int64_t tracks = 0, points = 0;
        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM activities;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) tracks = sqlite3_column_int64(st, 0);
        }
        if (st) { sqlite3_finalize(st); st = NULL; }
        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM points;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) points = sqlite3_column_int64(st, 0);
        }
        if (st) { sqlite3_finalize(st); st = NULL; }

        [library setTrackCount:(NSInteger)tracks];
        [library setTotalPoints:points];

        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:library.fileURL.path error:NULL];
        [library setFileSizeBytes:(uint64_t)[attrs fileSize]];
    } completion:^{ if (completion) completion(nil); }];
}

@end
