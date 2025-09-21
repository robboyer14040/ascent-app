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

#pragma mark - AscentLibrary

@implementation AscentLibrary

- (void)dealloc
{
#if TARGET_OS_OSX
    if (_hasSecurityScope && _fileURL != nil) {
        [_fileURL stopAccessingSecurityScopedResource];
    }
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

- (void)setFileURL:(NSURL *)url
{
    if (_fileURL != url) {
        [_fileURL release];
        _fileURL = [url retain];
    }
}
- (void)setBookmarkData:(NSData *)data
{
    if (_bookmarkData != data) {
        [_bookmarkData release];
        _bookmarkData = [data retain];
    }
}
- (void)setDisplayName:(NSString *)name
{
    if (_displayName != name) {
        [_displayName release];
        _displayName = [name retain];
    }
}
- (void)setDb:(DatabaseManager *)db
{
    if (_db != db) {
        [_db release];
        _db = [db retain];
    }
}
- (void)setActivities:(ActivityStore *)s
{
    if (_activities != s) {
        [_activities release];
        _activities = [s retain];
    }
}
- (void)setPoints:(TrackPointStore *)s
{
    if (_points != s) {
        [_points release];
        _points = [s retain];
    }
}
- (void)setIdentifiers:(IdentifierStore *)s
{
    if (_identifiers != s) {
        [_identifiers release];
        _identifiers = [s retain];
    }
}
- (void)setTrackCount:(NSInteger)c { _trackCount = c; }
- (void)setTotalPoints:(int64_t)p { _totalPoints = p; }
- (void)setFileSizeBytes:(uint64_t)b { _fileSizeBytes = b; }
- (void)setHasSecurityScope:(BOOL)flag { _hasSecurityScope = flag; }

@end

#pragma mark - Private helpers (LibraryController)

@interface LibraryController ()
- (NSURL *)_mruPlistURL;
- (BOOL)_url:(NSURL *)a refersToSameFileAsURL:(NSURL *)b;
- (AscentLibrary *)_libraryForSamePhysicalFileAsURL:(NSURL *)url;
@end

#pragma mark - LibraryController

@implementation LibraryController

- (instancetype)initWithStateDirectoryURL:(NSURL *)stateDirURL
{
    NSParameterAssert(stateDirURL);

    if ((self = [super init])) {
        _stateDirURL = [stateDirURL retain];
        _controllerQueue =
            dispatch_queue_create("com.montebellosoftware.Ascent.LibraryControllerQ",
                                  dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                          QOS_CLASS_USER_INITIATED,
                                                                          0));
        _mutableLibraries = [[NSMutableArray alloc] init];

        [[NSFileManager defaultManager] createDirectoryAtURL:stateDirURL
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];
    }
    return self;
}

- (void)dealloc
{
    if (_controllerQueue != NULL) {
        dispatch_release(_controllerQueue);
        _controllerQueue = NULL;
    }
    [_securityScopedURL release];
    [_stateDirURL release];
    [_mutableLibraries release];
    [super dealloc];
}

- (dispatch_queue_t)controllerQueue
{
    return _controllerQueue;
}

- (NSArray<AscentLibrary *> *)openLibraries
{
    @synchronized (self) {
        return [[_mutableLibraries copy] autorelease];
    }
}

- (AscentLibrary *)activeLibrary
{
    @synchronized (self) {
        return _activeLibrary;
    }
}

- (void)setActiveLibraryInternal:(AscentLibrary *)lib
{
    @synchronized (self) {
        if (_activeLibrary != lib) {
            [_activeLibrary release];
            _activeLibrary = [lib retain];
        }
    }
}

#pragma mark - Public open/create

- (void)createLibraryAtURL:(NSURL *)url
                completion:(void (^)(AscentLibrary *, NSError *))completion
{
    [self openLibraryAtURL:url bookmark:nil completion:completion];
}

- (void)openLibraryAtURL:(NSURL *)url
              completion:(void (^)(AscentLibrary *, NSError *))completion
{
    [self openLibraryAtURL:url bookmark:nil completion:completion];
}

- (void)openLibraryAtURL:(NSURL *)url
                bookmark:(NSData * _Nullable)bookmark
              completion:(void (^_Nullable)(AscentLibrary * _Nullable library, NSError * _Nullable error))completion
{
    dispatch_async(_controllerQueue, ^{
        // 1) If a library for the same *physical* file is already open, reuse it.
        AscentLibrary *existing = [self _libraryForSamePhysicalFileAsURL:url];
        if (existing != nil) {
            [self setActiveLibraryInternal:existing];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                                  object:self];

                if (completion != nil) {
                    completion(existing, nil);
                }
            });
            return;
        }

        if ([_delegate respondsToSelector:@selector(libraryWillOpenAtURL:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate libraryWillOpenAtURL:url];
            });
        }

        // 2) Security scope / bookmark (macOS)
        NSURL *scopedURL = url;
        BOOL beganScope = NO;
        NSData *bookmarkToKeep = nil;

#if TARGET_OS_OSX
        if (bookmark != nil) {
            BOOL stale = NO;
            NSError *resolveErr = nil;
            NSURL *resolved = [NSURL URLByResolvingBookmarkData:bookmark
                                                        options:NSURLBookmarkResolutionWithSecurityScope
                                                  relativeToURL:nil
                                            bookmarkDataIsStale:&stale
                                                          error:&resolveErr];
            if (resolved != nil) {
                scopedURL = resolved;
            } else {
                scopedURL = url;
                NSLog(@"[LibraryController] Warning: bookmark resolve failed for %@: %@",
                      url.path, resolveErr);
            }

            if (stale) {
                NSError *rebmErr = nil;
                NSData *fresh = [scopedURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                   includingResourceValuesForKeys:nil
                                                    relativeToURL:nil
                                                            error:&rebmErr];
                if (fresh != nil) {
                    bookmarkToKeep = [fresh retain];
                } else {
                    bookmarkToKeep = [bookmark retain];
                    NSLog(@"[LibraryController] Warning: failed to refresh stale bookmark for %@: %@",
                          scopedURL.path, rebmErr);
                }
            } else {
                bookmarkToKeep = [bookmark retain];
            }

            beganScope = [scopedURL startAccessingSecurityScopedResource];
            if (!beganScope) {
                NSLog(@"[LibraryController] Warning: startAccessingSecurityScopedResource failed for %@",
                      scopedURL.path);
            }
        } else {
            NSString *p = url.path;
            BOOL needsScope = ([p rangeOfString:@"/Library/Containers/"].location == NSNotFound);

            if (needsScope) {
                NSError *bmErr = nil;
                NSData *fresh = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                              includingResourceValuesForKeys:nil
                                               relativeToURL:nil
                                                       error:&bmErr];
                if (fresh != nil) {
                    bookmarkToKeep = [fresh retain];
                } else {
                    NSLog(@"[LibraryController] Warning: bookmark creation failed for %@: %@",
                          url.path, bmErr);
                }

                beganScope = [url startAccessingSecurityScopedResource];
                if (!beganScope) {
                    NSLog(@"[LibraryController] Warning: startAccessingSecurityScopedResource failed for %@",
                          url.path);
                }

                scopedURL = url;
            } else {
                scopedURL = url;
            }
        }
#endif // TARGET_OS_OSX

        // 3) Build library object
        AscentLibrary *lib = [[AscentLibrary alloc] init];
        [lib setFileURL:url];
        [lib setDisplayName:url.lastPathComponent];

#if TARGET_OS_OSX
        if (bookmarkToKeep != nil) {
            [lib setBookmarkData:bookmarkToKeep];
            [bookmarkToKeep release];
            bookmarkToKeep = nil;
        }

        if (beganScope) {
            [lib setHasSecurityScope:YES];
        }
#endif

        // 4) Open DB with the *scoped* URL and ensure schema
        DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:scopedURL];

        NSError *openErr = nil;
        BOOL opened = [dbm open:&openErr];
        if (!opened) {
#if TARGET_OS_OSX
            if (beganScope) {
                [scopedURL stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
            NSError *e = [NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                             code:AscentLibraryControllerErrorOpenFailed
                                         userInfo:@{
                                             NSLocalizedDescriptionKey : @"Failed to open database",
                                             NSUnderlyingErrorKey      : (openErr ?: (id)[NSNull null])
                                         }];

            [lib release];
            [dbm release];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion != nil) {
                    completion(nil, e);
                }
            });
            return;
        }

        [lib setDb:dbm];

        ActivityStore   *activities = [[ActivityStore alloc] initWithDatabaseManager:dbm];
        TrackPointStore *points     = [[TrackPointStore alloc] initWithDatabaseManager:dbm];
        IdentifierStore *idents     = [[IdentifierStore alloc] initWithDatabaseManager:dbm];

        NSError *schemaErr = nil;
        BOOL okA = [activities createSchemaIfNeeded:&schemaErr];
        BOOL okP = NO;
        BOOL okI = NO;

        if (okA) {
            okP = [points createSchemaIfNeeded:&schemaErr];
        }
        if (okA && okP) {
            okI = [idents createSchemaIfNeeded:&schemaErr];
        }

        if (!(okA && okP && okI)) {
            [dbm close];

#if TARGET_OS_OSX
            if (beganScope) {
                [scopedURL stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
            [activities release];
            [points release];
            [idents release];
            [dbm release];
            [lib release];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion != nil) {
                    completion(nil, schemaErr);
                }
            });
            return;
        }

        [lib setActivities:activities];
        [lib setPoints:points];
        [lib setIdentifiers:idents];

        [activities release];
        [points release];
        [idents release];
        [dbm release];

        // 5) Track in controller and notify
        @synchronized (self) {
            [_mutableLibraries addObject:lib];
        }
        [self setActiveLibraryInternal:lib];

        [self recordRecentLibraryURL:url bookmark:[lib bookmarkData]];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_delegate respondsToSelector:@selector(libraryDidOpen:)]) {
                [_delegate libraryDidOpen:lib];
            }

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if (completion != nil) {
                completion([lib autorelease], nil);
            }
        });
    });
}

#pragma mark - Close

- (void)closeLibrary:(AscentLibrary *)library
          completion:(void (^)(NSError *))completion
{
    if (library == nil) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }

    dispatch_async(_controllerQueue, ^{
        if ([_delegate respondsToSelector:@selector(libraryWillClose:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate libraryWillClose:library];
            });
        }

        [[library db] close];

#if TARGET_OS_OSX
        if (library.hasSecurityScope) {
            [[library fileURL] stopAccessingSecurityScopedResource];
            [library setHasSecurityScope:NO];
        }
#endif

        @synchronized (self) {
            [_mutableLibraries removeObject:library];

            if ([self activeLibrary] == library) {
                AscentLibrary *replacement = nil;
                if (_mutableLibraries.count > 0) {
                    replacement = [_mutableLibraries objectAtIndex:0];
                }
                [self setActiveLibraryInternal:replacement];
            }
        }

        NSURL *closedURL = [[library fileURL] retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if ([_delegate respondsToSelector:@selector(libraryDidCloseURL:)]) {
                [_delegate libraryDidCloseURL:closedURL];
            }

            [closedURL release];

            if (completion != nil) {
                completion(nil);
            }
        });
    });
}

- (void)closeAllLibrariesWithCompletion:(void (^)(NSError *))completion
{
    dispatch_async(_controllerQueue, ^{
        NSArray *libs = nil;

        @synchronized (self) {
            libs = [[_mutableLibraries copy] autorelease];
        }

        for (AscentLibrary *lib in libs) {
            [[lib db] close];

#if TARGET_OS_OSX
            if (lib.hasSecurityScope) {
                [[lib fileURL] stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
        }

        @synchronized (self) {
            [_mutableLibraries removeAllObjects];
            [self setActiveLibraryInternal:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if (completion != nil) {
                completion(nil);
            }
        });
    });
}

#pragma mark - Selection

- (void)selectActiveLibrary:(AscentLibrary *)library
{
    dispatch_async(_controllerQueue, ^{
        @synchronized (self) {
            if ([_mutableLibraries containsObject:library]) {
                [self setActiveLibraryInternal:library];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];
        });
    });
}

#pragma mark - MRU

- (NSArray<NSURL *> *)recentLibraryURLs
{
    NSMutableArray *urls = [NSMutableArray array];

    NSArray *items = [NSArray arrayWithContentsOfURL:[self _mruPlistURL]];
    for (NSDictionary *e in items) {
        NSString *s = [e objectForKey:@"url"];
        if (s != nil) {
            NSURL *u = [NSURL URLWithString:s];
            if (u != nil) {
                [urls addObject:u];
            }
        }
    }
    return urls;
}

- (void)recordRecentLibraryURL:(NSURL *)url
                      bookmark:(NSData *)bookmarkData
{
    NSMutableArray *items = [NSMutableArray arrayWithContentsOfURL:[self _mruPlistURL]];
    if (items == nil) {
        items = [NSMutableArray array];
    }

    NSDictionary *entry =
    @{
        @"url"      : url.absoluteString ?: @"",
        @"bookmark" : (bookmarkData ?: [NSData data]),
        @"added"    : @([[NSDate date] timeIntervalSince1970])
    };

    NSString *u = url.absoluteString;
    NSMutableArray *filtered = [NSMutableArray array];

    for (NSDictionary *e in items) {
        NSString *eu = [e objectForKey:@"url"];
        if (eu != nil) {
            if (![eu isEqualToString:u]) {
                [filtered addObject:e];
            }
        }
    }

    [filtered insertObject:entry atIndex:0];

    while (filtered.count > 10) {
        [filtered removeLastObject];
    }

    [filtered writeToURL:[self _mruPlistURL] atomically:YES];
}

- (void)pruneRecentLibraryURL:(NSURL *)url
{
    (void)url;
}

#pragma mark - Export + Stats

- (void)exportActiveLibrarySnapshotToURL:(NSURL *)destURL
                              completion:(void (^)(NSError *))completion
{
    AscentLibrary *lib = [self activeLibrary];

    if (!lib) {
        if (completion != nil) {
            completion([NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey:@"No active library"}]);
        }
        return;
    }

    dispatch_async(_controllerQueue, ^{
        NSError *err = nil;
        BOOL ok = [[lib db] exportSnapshotToURL:destURL error:&err];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(ok ? nil : err);
            }
        });
    });
}

- (void)refreshStatsForLibrary:(AscentLibrary *)library
                    completion:(void (^)(NSError *))completion
{
    if (!library) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }

    [[library db] performRead:^(sqlite3 *db) {

        sqlite3_stmt *st = NULL;
        int64_t tracks = 0;
        int64_t points = 0;

        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM activities;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) {
                tracks = sqlite3_column_int64(st, 0);
            }
        }
        if (st != NULL) {
            sqlite3_finalize(st);
            st = NULL;
        }

        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM points;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) {
                points = sqlite3_column_int64(st, 0);
            }
        }
        if (st != NULL) {
            sqlite3_finalize(st);
            st = NULL;
        }

        [library setTrackCount:(NSInteger)tracks];
        [library setTotalPoints:points];

        NSDictionary *attrs =
            [[NSFileManager defaultManager] attributesOfItemAtPath:library.fileURL.path error:NULL];
        [library setFileSizeBytes:(uint64_t)[attrs fileSize]];

    } completion:^{
        if (completion != nil) {
            completion(nil);
        }
    }];
}

#pragma mark - Security scope helpers

- (BOOL)startSecurityScopeForURL:(NSURL * _Nonnull)url
                        bookmark:(NSData * _Nullable)bookmarkData
                    scopedURLOut:(NSURL * _Nullable __autoreleasing * _Nullable)scopedURLOut
                           error:(NSError * _Nullable __autoreleasing * _Nullable)outErr
{
#if TARGET_OS_OSX
    NSError *err = nil;
    NSURL *scoped = nil;

    if (bookmarkData != nil) {
        BOOL stale = NO;

        NSURL *resolved =
            [NSURL URLByResolvingBookmarkData:bookmarkData
                                      options:NSURLBookmarkResolutionWithSecurityScope
                                relativeToURL:nil
                          bookmarkDataIsStale:&stale
                                        error:&err];
        if (resolved == nil) {
            if (outErr != NULL) {
                *outErr = err ?: [NSError errorWithDomain:@"Ascent.SecurityScope"
                                                     code:-2
                                                 userInfo:@{NSLocalizedDescriptionKey:@"Failed to resolve bookmark"}];
            }
            return NO;
        }

        BOOL ok = [resolved startAccessingSecurityScopedResource];
        if (!ok) {
            if (outErr != NULL) {
                *outErr = [NSError errorWithDomain:@"Ascent.SecurityScope"
                                              code:-3
                                          userInfo:@{NSLocalizedDescriptionKey:@"startAccessingSecurityScopedResource failed"}];
            }
            return NO;
        }

        scoped = resolved;
    } else {
        BOOL ok = [url startAccessingSecurityScopedResource];
        if (ok) {
            scoped = url;
        } else {
            scoped = url;
        }
    }

    if (scopedURLOut != NULL) {
        *scopedURLOut = scoped;
    }

    return YES;
#else
    if (scopedURLOut != NULL) {
        *scopedURLOut = url;
    }
    return YES;
#endif
}

- (NSURL *)securityScopedURL
{
    return _securityScopedURL;
}

- (void)setSecurityScopedURL:(NSURL * _Nullable)url
{
    if (_securityScopedURL != url) {
        [_securityScopedURL release];
        _securityScopedURL = [url retain];
    }
}

#pragma mark - Private

// Compare by physical file identity using NSURLFileResourceIdentifierKey.
// Falls back to standardized path equality if needed.
- (BOOL)_url:(NSURL *)a refersToSameFileAsURL:(NSURL *)b
{
    if (a == nil || b == nil) {
        return NO;
    }

    if ([a isEqual:b]) {
        return YES;
    }

#if TARGET_OS_OSX
    id ida = nil;
    id idb = nil;

    NSError *ea = nil;
    NSError *eb = nil;

    BOOL gotA = [a getResourceValue:&ida forKey:NSURLFileResourceIdentifierKey error:&ea];
    BOOL gotB = [b getResourceValue:&idb forKey:NSURLFileResourceIdentifierKey error:&eb];

    if (gotA && gotB && ida != nil && idb != nil) {
        return [ida isEqual:idb];
    }
#endif

    NSURL *sa = [[a URLByStandardizingPath] URLByResolvingSymlinksInPath];
    NSURL *sb = [[b URLByStandardizingPath] URLByResolvingSymlinksInPath];

    if (sa != nil && sb != nil) {
        return [sa isEqual:sb];
    }

    return NO;
}

// Look for an already-open library that points to the same physical file as url.
- (AscentLibrary *)_libraryForSamePhysicalFileAsURL:(NSURL *)url
{
    @synchronized (self) {
        for (AscentLibrary *lib in _mutableLibraries) {
            NSURL *libURL = [lib fileURL];
            if ([self _url:libURL refersToSameFileAsURL:url]) {
                return lib;
            }
        }
    }
    return nil;
}

- (NSURL *)_mruPlistURL
{
    return [_stateDirURL URLByAppendingPathComponent:@"RecentLibraries.plist" isDirectory:NO];
}

@end




#if 0
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


@interface LibraryController ()
- (NSURL *)_mruPlistURL;
@end

#pragma mark - AscentLibrary

@implementation AscentLibrary

- (void)dealloc
{
#if TARGET_OS_OSX
    if (_hasSecurityScope && _fileURL != nil) {
        [_fileURL stopAccessingSecurityScopedResource];
    }
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

- (void)setFileURL:(NSURL *)url
{
    if (_fileURL != url) {
        [_fileURL release];
        _fileURL = [url retain];
    }
}
- (void)setBookmarkData:(NSData *)data
{
    if (_bookmarkData != data) {
        [_bookmarkData release];
        _bookmarkData = [data retain];
    }
}
- (void)setDisplayName:(NSString *)name
{
    if (_displayName != name) {
        [_displayName release];
        _displayName = [name retain];
    }
}
- (void)setDb:(DatabaseManager *)db
{
    if (_db != db) {
        [_db release];
        _db = [db retain];
    }
}
- (void)setActivities:(ActivityStore *)s
{
    if (_activities != s) {
        [_activities release];
        _activities = [s retain];
    }
}
- (void)setPoints:(TrackPointStore *)s
{
    if (_points != s) {
        [_points release];
        _points = [s retain];
    }
}
- (void)setIdentifiers:(IdentifierStore *)s
{
    if (_identifiers != s) {
        [_identifiers release];
        _identifiers = [s retain];
    }
}
- (void)setTrackCount:(NSInteger)c { _trackCount = c; }
- (void)setTotalPoints:(int64_t)p { _totalPoints = p; }
- (void)setFileSizeBytes:(uint64_t)b { _fileSizeBytes = b; }
- (void)setHasSecurityScope:(BOOL)flag { _hasSecurityScope = flag; }

@end

#pragma mark - LibraryController

@implementation LibraryController

- (instancetype)initWithStateDirectoryURL:(NSURL *)stateDirURL
{
    NSParameterAssert(stateDirURL);

    if ((self = [super init])) {
        _stateDirURL = [stateDirURL retain];
        _controllerQueue =
            dispatch_queue_create("com.montebellosoftware.Ascent.LibraryControllerQ",
                                  dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                          QOS_CLASS_USER_INITIATED,
                                                                          0));
        _mutableLibraries = [[NSMutableArray alloc] init];

        [[NSFileManager defaultManager] createDirectoryAtURL:stateDirURL
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];
    }
    return self;
}

- (void)dealloc
{
    if (_controllerQueue != NULL) {
        dispatch_release(_controllerQueue);
        _controllerQueue = NULL;
    }
    [_securityScopedURL release];
    [_stateDirURL release];
    [_mutableLibraries release];
    [super dealloc];
}

- (dispatch_queue_t)controllerQueue
{
    return _controllerQueue;
}

- (NSArray<AscentLibrary *> *)openLibraries
{
    @synchronized (self) {
        return [[_mutableLibraries copy] autorelease];
    }
}

- (AscentLibrary *)activeLibrary
{
    @synchronized (self) {
        return _activeLibrary;
    }
}

- (void)setActiveLibraryInternal:(AscentLibrary *)lib
{
    @synchronized (self) {
        if (_activeLibrary != lib) {
            [_activeLibrary release];
            _activeLibrary = [lib retain];
        }
    }
}

#pragma mark - Public open/create

- (void)createLibraryAtURL:(NSURL *)url
                completion:(void (^)(AscentLibrary *, NSError *))completion
{
    [self openLibraryAtURL:url bookmark:nil completion:completion];
}

- (void)openLibraryAtURL:(NSURL *)url
              completion:(void (^)(AscentLibrary *, NSError *))completion
{
    [self openLibraryAtURL:url bookmark:nil completion:completion];
}


- (void)openLibraryAtURL:(NSURL *)url
                bookmark:(NSData * _Nullable)bookmark
              completion:(void (^_Nullable)(AscentLibrary * _Nullable library, NSError * _Nullable error))completion
{
    dispatch_async(_controllerQueue, ^{
        // Reuse if already open.
        for (AscentLibrary *lib in _mutableLibraries) {
            if ([[lib fileURL] isEqual:url]) {
                [self setActiveLibraryInternal:lib];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                                      object:self];

                    if (completion != nil) {
                        completion(lib, nil);
                    }
                });
                return;
            }
        }

        if ([_delegate respondsToSelector:@selector(libraryWillOpenAtURL:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate libraryWillOpenAtURL:url];
            });
        }

        // ---------- Security scope / bookmark (macOS) ----------
        NSURL *scopedURL = url;
        BOOL beganScope = NO;
        NSData *bookmarkToKeep = nil;

#if TARGET_OS_OSX
        if (bookmark != nil) {
            BOOL stale = NO;
            NSError *resolveErr = nil;
            NSURL *resolved = [NSURL URLByResolvingBookmarkData:bookmark
                                                        options:NSURLBookmarkResolutionWithSecurityScope
                                                  relativeToURL:nil
                                            bookmarkDataIsStale:&stale
                                                          error:&resolveErr];
            if (resolved != nil) {
                scopedURL = resolved;
            } else {
                // Could not resolve the provided bookmark. Fall back to raw URL.
                scopedURL = url;
                NSLog(@"[LibraryController] Warning: bookmark resolve failed for %@: %@",
                      url.path, resolveErr);
            }

            if (stale) {
                NSError *rebmErr = nil;
                NSData *fresh = [scopedURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                   includingResourceValuesForKeys:nil
                                                    relativeToURL:nil
                                                            error:&rebmErr];
                if (fresh != nil) {
                    bookmarkToKeep = [fresh retain];
                } else {
                    bookmarkToKeep = [bookmark retain];
                    NSLog(@"[LibraryController] Warning: failed to refresh stale bookmark for %@: %@",
                          scopedURL.path, rebmErr);
                }
            } else {
                bookmarkToKeep = [bookmark retain];
            }

            beganScope = [scopedURL startAccessingSecurityScopedResource];
            if (!beganScope) {
                NSLog(@"[LibraryController] Warning: startAccessingSecurityScopedResource failed for %@",
                      scopedURL.path);
            }
        } else {
            // No bookmark supplied. If outside the app container, opportunistically create one and start scope.
            NSString *p = url.path;
            BOOL needsScope = ([p rangeOfString:@"/Library/Containers/"].location == NSNotFound);

            if (needsScope) {
                NSError *bmErr = nil;
                NSData *fresh = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                              includingResourceValuesForKeys:nil
                                               relativeToURL:nil
                                                       error:&bmErr];
                if (fresh != nil) {
                    bookmarkToKeep = [fresh retain];
                } else {
                    NSLog(@"[LibraryController] Warning: bookmark creation failed for %@: %@",
                          url.path, bmErr);
                }

                beganScope = [url startAccessingSecurityScopedResource];
                if (!beganScope) {
                    NSLog(@"[LibraryController] Warning: startAccessingSecurityScopedResource failed for %@",
                          url.path);
                }

                scopedURL = url;
            } else {
                // Inside container; no bookmark or scope needed.
                scopedURL = url;
            }
        }
#endif // TARGET_OS_OSX

        // ---------- Build library object ----------
        AscentLibrary *lib = [[AscentLibrary alloc] init];
        [lib setFileURL:url];
        [lib setDisplayName:url.lastPathComponent];

#if TARGET_OS_OSX
        if (bookmarkToKeep != nil) {
            [lib setBookmarkData:bookmarkToKeep];
            [bookmarkToKeep release];
            bookmarkToKeep = nil;
        }

        if (beganScope) {
            [lib setHasSecurityScope:YES];
        }
#endif

        // ---------- Open DB with the *scoped* URL and ensure schema ----------
        DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:scopedURL];

        NSError *openErr = nil;
        BOOL opened = [dbm open:&openErr];
        if (!opened) {
#if TARGET_OS_OSX
            if (beganScope) {
                [scopedURL stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
            NSError *e = [NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                             code:AscentLibraryControllerErrorOpenFailed
                                         userInfo:@{
                                             NSLocalizedDescriptionKey : @"Failed to open database",
                                             NSUnderlyingErrorKey      : (openErr ?: (id)[NSNull null])
                                         }];

            [lib release];
            [dbm release];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion != nil) {
                    completion(nil, e);
                }
            });
            return;
        }

        [lib setDb:dbm];

        ActivityStore *activities = [[ActivityStore alloc] initWithDatabaseManager:dbm];
        TrackPointStore *points = [[TrackPointStore alloc] initWithDatabaseManager:dbm];
        IdentifierStore *idents = [[IdentifierStore alloc] initWithDatabaseManager:dbm];

        NSError *schemaErr = nil;
        BOOL okActivities = [activities createSchemaIfNeeded:&schemaErr];
        BOOL okPoints = NO;
        BOOL okIdents = NO;

        if (okActivities) {
            okPoints = [points createSchemaIfNeeded:&schemaErr];
        }

        if (okActivities && okPoints) {
            okIdents = [idents createSchemaIfNeeded:&schemaErr];
        }

        if (!(okActivities && okPoints && okIdents)) {
            [dbm close];

#if TARGET_OS_OSX
            if (beganScope) {
                [scopedURL stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
            [activities release];
            [points release];
            [idents release];
            [dbm release];
            [lib release];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion != nil) {
                    completion(nil, schemaErr);
                }
            });
            return;
        }

        [lib setActivities:activities];
        [lib setPoints:points];
        [lib setIdentifiers:idents];

        [activities release];
        [points release];
        [idents release];
        [dbm release];

        // Track in controller and notify.
        @synchronized (self) {
            [_mutableLibraries addObject:lib];
        }
        [self setActiveLibraryInternal:lib];

        // Persist MRU entry (keep whatever bookmark we have).
        [self recordRecentLibraryURL:url bookmark:[lib bookmarkData]];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_delegate respondsToSelector:@selector(libraryDidOpen:)]) {
                [_delegate libraryDidOpen:lib];
            }

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if (completion != nil) {
                completion([lib autorelease], nil);
            }
        });
    });
}

#pragma mark - Close

- (void)closeLibrary:(AscentLibrary *)library
          completion:(void (^)(NSError *))completion
{
    if (library == nil) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }

    dispatch_async(_controllerQueue, ^{
        if ([_delegate respondsToSelector:@selector(libraryWillClose:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate libraryWillClose:library];
            });
        }

        [[library db] close];

#if TARGET_OS_OSX
        if (library.hasSecurityScope) {
            [[library fileURL] stopAccessingSecurityScopedResource];
            [library setHasSecurityScope:NO];
        }
#endif

        @synchronized (self) {
            [_mutableLibraries removeObject:library];

            if ([self activeLibrary] == library) {
                AscentLibrary *replacement = nil;
                if (_mutableLibraries.count > 0) {
                    replacement = [_mutableLibraries objectAtIndex:0];
                }
                [self setActiveLibraryInternal:replacement];
            }
        }

        NSURL *closedURL = [[library fileURL] retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if ([_delegate respondsToSelector:@selector(libraryDidCloseURL:)]) {
                [_delegate libraryDidCloseURL:closedURL];
            }

            [closedURL release];

            if (completion != nil) {
                completion(nil);
            }
        });
    });
}

- (void)closeAllLibrariesWithCompletion:(void (^)(NSError *))completion
{
    dispatch_async(_controllerQueue, ^{
        NSArray *libs = nil;

        @synchronized (self) {
            libs = [[_mutableLibraries copy] autorelease];
        }

        for (AscentLibrary *lib in libs) {
            [[lib db] close];

#if TARGET_OS_OSX
            if (lib.hasSecurityScope) {
                [[lib fileURL] stopAccessingSecurityScopedResource];
                [lib setHasSecurityScope:NO];
            }
#endif
        }

        @synchronized (self) {
            [_mutableLibraries removeAllObjects];
            [self setActiveLibraryInternal:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerLibrariesDidChangeNotification
                              object:self];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];

            if (completion != nil) {
                completion(nil);
            }
        });
    });
}

#pragma mark - Selection

- (void)selectActiveLibrary:(AscentLibrary *)library
{
    dispatch_async(_controllerQueue, ^{
        @synchronized (self) {
            if ([_mutableLibraries containsObject:library]) {
                [self setActiveLibraryInternal:library];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:AscentLibraryControllerActiveLibraryDidChangeNotification
                              object:self];
        });
    });
}

#pragma mark - MRU

- (NSArray<NSURL *> *)recentLibraryURLs
{
    NSMutableArray *urls = [NSMutableArray array];

    NSArray *items = [NSArray arrayWithContentsOfURL:[self _mruPlistURL]];
    for (NSDictionary *e in items) {
        NSString *s = [e objectForKey:@"url"];
        if (s != nil) {
            NSURL *u = [NSURL URLWithString:s];
            if (u != nil) {
                [urls addObject:u];
            }
        }
    }
    return urls;
}

- (void)recordRecentLibraryURL:(NSURL *)url
                      bookmark:(NSData *)bookmarkData
{
    NSMutableArray *items = [NSMutableArray arrayWithContentsOfURL:[self _mruPlistURL]];
    if (items == nil) {
        items = [NSMutableArray array];
    }

    NSDictionary *entry =
    @{
        @"url"      : url.absoluteString ?: @"",
        @"bookmark" : (bookmarkData ?: [NSData data]),
        @"added"    : @([[NSDate date] timeIntervalSince1970])
    };

    // De-dupe by URL string.
    NSString *u = url.absoluteString;
    NSMutableArray *filtered = [NSMutableArray array];

    for (NSDictionary *e in items) {
        NSString *eu = [e objectForKey:@"url"];
        if (eu != nil) {
            if (![eu isEqualToString:u]) {
                [filtered addObject:e];
            }
        }
    }

    [filtered insertObject:entry atIndex:0];

    while (filtered.count > 10) {
        [filtered removeLastObject];
    }

    [filtered writeToURL:[self _mruPlistURL] atomically:YES];
}

- (void)pruneRecentLibraryURL:(NSURL *)url
{
    (void)url;
}

#pragma mark - Export + Stats

- (void)exportActiveLibrarySnapshotToURL:(NSURL *)destURL
                              completion:(void (^)(NSError *))completion
{
    AscentLibrary *lib = [self activeLibrary];

    if (!lib) {
        if (completion != nil) {
            completion([NSError errorWithDomain:AscentLibraryControllerErrorDomain
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey:@"No active library"}]);
        }
        return;
    }

    dispatch_async(_controllerQueue, ^{
        NSError *err = nil;
        BOOL ok = [[lib db] exportSnapshotToURL:destURL error:&err];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(ok ? nil : err);
            }
        });
    });
}

- (void)refreshStatsForLibrary:(AscentLibrary *)library
                    completion:(void (^)(NSError *))completion
{
    if (!library) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }

    [[library db] performRead:^(sqlite3 *db) {

        sqlite3_stmt *st = NULL;
        int64_t tracks = 0;
        int64_t points = 0;

        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM activities;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) {
                tracks = sqlite3_column_int64(st, 0);
            }
        }
        if (st != NULL) {
            sqlite3_finalize(st);
            st = NULL;
        }

        if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM points;", -1, &st, NULL) == SQLITE_OK) {
            if (sqlite3_step(st) == SQLITE_ROW) {
                points = sqlite3_column_int64(st, 0);
            }
        }
        if (st != NULL) {
            sqlite3_finalize(st);
            st = NULL;
        }

        [library setTrackCount:(NSInteger)tracks];
        [library setTotalPoints:points];

        NSDictionary *attrs =
            [[NSFileManager defaultManager] attributesOfItemAtPath:library.fileURL.path error:NULL];
        [library setFileSizeBytes:(uint64_t)[attrs fileSize]];

    } completion:^{
        if (completion != nil) {
            completion(nil);
        }
    }];
}

#pragma mark - Security scope helpers

- (BOOL)startSecurityScopeForURL:(NSURL * _Nonnull)url
                        bookmark:(NSData * _Nullable)bookmarkData
                    scopedURLOut:(NSURL * _Nullable __autoreleasing * _Nullable)scopedURLOut
                           error:(NSError * _Nullable __autoreleasing * _Nullable)outErr
{
#if TARGET_OS_OSX
    NSError *err = nil;
    NSURL *scoped = nil;

    if (bookmarkData != nil) {
        BOOL stale = NO;

        NSURL *resolved =
            [NSURL URLByResolvingBookmarkData:bookmarkData
                                      options:NSURLBookmarkResolutionWithSecurityScope
                                relativeToURL:nil
                          bookmarkDataIsStale:&stale
                                        error:&err];
        if (resolved == nil) {
            if (outErr != NULL) {
                *outErr = err ?: [NSError errorWithDomain:@"Ascent.SecurityScope"
                                                     code:-2
                                                 userInfo:@{NSLocalizedDescriptionKey:@"Failed to resolve bookmark"}];
            }
            return NO;
        }

        BOOL ok = [resolved startAccessingSecurityScopedResource];
        if (!ok) {
            if (outErr != NULL) {
                *outErr = [NSError errorWithDomain:@"Ascent.SecurityScope"
                                              code:-3
                                          userInfo:@{NSLocalizedDescriptionKey:@"startAccessingSecurityScopedResource failed"}];
            }
            return NO;
        }

        scoped = resolved;
    } else {
        // Inside container this often returns NO; tolerate that and still use URL.
        BOOL ok = [url startAccessingSecurityScopedResource];
        if (ok) {
            scoped = url;
        } else {
            scoped = url;
        }
    }

    if (scopedURLOut != NULL) {
        *scopedURLOut = scoped;
    }

    return YES;
#else
    if (scopedURLOut != NULL) {
        *scopedURLOut = url;
    }
    return YES;
#endif
}

- (NSURL *)securityScopedURL
{
    return _securityScopedURL;
}

- (void)setSecurityScopedURL:(NSURL * _Nullable)url
{
    if (_securityScopedURL != url) {
        [_securityScopedURL release];
        _securityScopedURL = [url retain];
    }
}

#pragma mark - Private

- (NSURL *)_mruPlistURL
{
    return [_stateDirURL URLByAppendingPathComponent:@"RecentLibraries.plist" isDirectory:NO];
}

@end
#endif

