//
//  StravaImporter.h
//  Ascent
//
//  Created by Rob Boyer on 8/31/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// StravaImporter.h (MRC)
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Track;

typedef void (^StravaImportProgress)(NSUInteger pagesFetched, NSUInteger totalActivitiesSoFar);
typedef void (^StravaImportCompletion)(NSArray * _Nullable tracks, NSError * _Nullable error);

@interface StravaImporter : NSObject {
@private
    NSString *_accessToken; // "Bearer xxxxxx"
}

+ (instancetype)shared;

- (id)initWithAccessToken:(NSString *)accessToken;

/**
 * Fetch activities since 'since' (UTC) and build Track objects with TrackPoints.
 * Returns autoreleased NSArray<Track *> or nil on error (see *outError).
 *
 * perPage: typical 30..200. maxPages: simple guard to avoid huge imports.
 */
- (NSArray *)importTracksSince:(NSDate *)since
                       perPage:(NSUInteger)perPage
                      maxPages:(NSUInteger)maxPages
                         error:(NSError **)outError;


- (void)importTracksSince:(NSDate *)since
                  perPage:(NSUInteger)perPage
                 maxPages:(NSUInteger)maxPages
                 progress:(StravaImportProgress)progress
               completion:(StravaImportCompletion)completion;

@end

NS_ASSUME_NONNULL_END
