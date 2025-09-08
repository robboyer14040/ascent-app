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

- (void)importTracksSince:(NSDate *)since
                  perPage:(NSUInteger)perPage
                 maxPages:(NSUInteger)maxPages
                 progress:(StravaImportProgress)progress
               completion:(StravaImportCompletion)completion;

- (void)enrichTrack:(Track *)track
    withSummaryDict:(NSDictionary * _Nullable )summary
       rootMediaURL:(NSURL*)mediaURL
         completion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
