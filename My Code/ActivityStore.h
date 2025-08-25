//
//  ActivityStore.h
//  Ascent
//
//  Created by Rob Boyer on 8/20/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class Track;

NS_ASSUME_NONNULL_BEGIN

@interface ActivityStore : NSObject
- (instancetype)initWithURL:(NSURL *)dbURL;
- (BOOL)open:(NSError **)error;
- (void)close;

/// Create/upgrade schema. Safe to call every launch.
- (BOOL)createSchema:(NSError **)error;

/// Upsert a Track (replaces laps/points for that uuid). Also stores Track.attributes / Track.markers / Track.overrideData as JSON in the track row.
- (BOOL)saveTrack:(Track *)track error:(NSError **)error;

- (BOOL)saveAllTracks:(NSArray<Track *> *)tracks error:(NSError **)error;

/// Load all tracks, each with laps, points, attributes, markers, overrideData
- (NSArray<Track *> *)loadAllTracks:(NSError **)error;

/// Load a single track by UUID (faster than loadAll)
- (nullable Track *)loadTrackWithUUID:(NSString *)uuid error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
