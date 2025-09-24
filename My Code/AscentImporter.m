//
//  AscentImporter.m
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import "AscentImporter.h"
#import "Track.h"
#import "ActivityStore.h"
#import "TrackPointStore.h"
#import "IdentifierStore.h"
#import "DatabaseManager.h"
#import "TrackBrowserData.h"


@implementation AscentImporter

- (BOOL)loadDatabaseFile:(NSURL *)url
            documentMeta:(TrackBrowserData *)docMeta
                progress:(ASProgress)prog
{
    if (url == nil || docMeta == nil) {
        NSLog(@"[AscentImporter] Nil argument(s): url=%@, docMeta=%@", url, docMeta);
        return NO;
    }

    NSError *err = nil;
    BOOL worked = NO;

    BOOL started = NO;
    if ([url respondsToSelector:@selector(startAccessingSecurityScopedResource)]) {
        started = [url startAccessingSecurityScopedResource];
    }

    @try {
        // 1) Open read-only
        DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:url readOnly:YES];
        if (![dbm open:&err]) {
            NSLog(@"[AscentImporter] DB open failed: %@", err);
            [dbm release];
            return NO;
        }

        // 2) Stores (no schema creation on read-only handles)
        ActivityStore   *actStore = [[[ActivityStore alloc]   initWithDatabaseManager:dbm] autorelease];
        ///TrackPointStore *tpStore  = [[[TrackPointStore alloc] initWithDatabaseManager:dbm] autorelease];

        // 3) Load META
        NSDictionary *tableInfo   = nil;
        NSDictionary *splitsInfo  = nil;
        NSString     *uuid        = nil;
        NSDate       *startDate   = nil;
        NSDate       *endDate     = nil;
        NSDate       *lastSync    = nil;
        NSInteger     flags       = 0;
        NSInteger     totalTracks = 0;
        NSInteger     i3          = 0;
        NSInteger     i4          = 0;

        worked = [actStore loadMetaTableInfo:&tableInfo
                             splitsTableInfo:&splitsInfo
                                        uuid:&uuid
                                   startDate:&startDate
                                     endDate:&endDate
                                lastSyncTime:&lastSync
                                       flags:&flags
                                 totalTracks:&totalTracks
                                        int3:&i3
                                        int4:&i4
                                       error:&err];

        if (!worked) {
            NSLog(@"[AscentImporter] Failed to load META info: %@", err);
        } else {
            // 4) Push META into TrackBrowserData
            if (tableInfo != nil) {
                docMeta.tableInfoDict = [NSMutableDictionary dictionaryWithDictionary:tableInfo];
            }

            if (splitsInfo != nil) {
                docMeta.splitsTableInfoDict = [NSMutableDictionary dictionaryWithDictionary:splitsInfo];
            }

            if (uuid != nil) {
                docMeta.uuid = uuid;
            }

            if (startDate != nil && endDate != nil) {
                docMeta.startEndDateArray = [NSArray arrayWithObjects:startDate, endDate, nil];
            }

            if (lastSync != nil) {
                docMeta.lastSyncTime = lastSync;
            }

            docMeta.flags = (int)flags;

            // 5) Load tracks (no points)
            NSArray *tracks = [actStore loadAllTracks:&err
                                          totalTracks:totalTracks
                                        progressBlock:prog];

            if (tracks == nil) {
                NSLog(@"[AscentImporter] No tracks loaded (err=%@)", err);
                worked = NO;
            } else {
                docMeta.trackArray = [NSMutableArray arrayWithArray:tracks];
                worked = YES;
            }

#if 0
            // 6) Load points per-track if tracks were loaded
            if (worked) {
                NSUInteger count = docMeta.trackArray.count;

                for (NSUInteger i = 0; i < count; i++) {
                    @autoreleasepool {
                        Track *t = [docMeta.trackArray objectAtIndex:i];
                        if (t == nil) {
                            continue;
                        }

                        // Clear any prior error before each fetch
                        err = nil;

                        NSArray *pts = [tpStore loadPointsForTrackUUID:t.uuid error:&err];
                        if (err != nil) {
                            NSLog(@"[AscentImporter] loadPoints failed for uuid=%@: %@", t.uuid, err);
                            worked = NO;
                            break;
                        }

                        if (pts != nil) {
                            NSMutableArray *mpts = [[pts mutableCopy] autorelease];

                            if ([t respondsToSelector:@selector(setPoints:)]) {
                                [t setPoints:mpts];
                            }

                            if ([t respondsToSelector:@selector(fixupTrack)]) {
                                [t fixupTrack];
                            }
                        }
                    }
                }
            }
#endif
            
        }

        // 7) Close DB
        [dbm close];
        [dbm release];
    }
    @finally {
        if (started) {
            [url stopAccessingSecurityScopedResource];
        }
    }

    return worked;
}

@end
