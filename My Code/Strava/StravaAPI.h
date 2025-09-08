//
//  StravaAPI.h
//  Ascent
//
//  Created by Rob Boyer on 8/29/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


// StravaAPI.h
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^StravaAuthCompletion)(NSError * _Nullable error);
typedef void (^StravaActivitiesPageCompletion)(NSArray<NSDictionary *> * _Nullable activities,
                                               NSURLResponse * _Nullable response,
                                               NSError * _Nullable error);
typedef void (^StravaActivitiesAllCompletion)(NSArray<NSDictionary *> * _Nullable activities,
                                              NSError * _Nullable error);
typedef void (^StravaProgress)(NSUInteger pagesFetched, NSUInteger totalSoFar);

@interface StravaAPI : NSObject

+ (instancetype)shared;

/// Begin OAuth flow in a system sheet. Call this once (or when tokens are invalid).
- (void)startAuthorizationFromWindow:(NSWindow *)window completion:(StravaAuthCompletion)completion;

/// Handle your app's custom URL scheme callback (ascent://oauth-callback?...).
- (BOOL)handleCallbackURL:(NSURL *)url error:(NSError **)outError;

/// Returns YES if we have a valid (or refreshable) token.
- (BOOL)isAuthorized;

/// Fetch a single page of recent activities (as raw dictionaries)
/// sinceDate: pass nil for "Strava default", or a date to set the `after` param.
/// page: 1-based page index; perPage: up to 200 (Strava max).
- (void)fetchActivitiesSince:(NSDate * _Nullable)sinceDate
                        page:(NSUInteger)page
                     perPage:(NSUInteger)perPage
                  completion:(StravaActivitiesPageCompletion)completion;

/// Convenience that auto-paginates until fewer than perPage are returned.
/// Calls progress for each page fetched.
- (void)fetchAllActivitiesSince:(NSDate * _Nullable)sinceDate
                        perPage:(NSUInteger)perPage
                       progress:(StravaProgress _Nullable)progress
                     completion:(StravaActivitiesAllCompletion)completion;

// Detail + Streams helpers
- (void)fetchActivityDetail:(NSNumber *)activityID
                 completion:(void (^)(NSDictionary * _Nullable activity, NSError * _Nullable error))completion;

// Convenience: deliver completion on the given queue (nil => main)
//- (void)fetchActivityDetail:(NSNumber *)activityID
//                      queue:(dispatch_queue_t _Nullable)queue
//                 completion:(void (^)(NSDictionary * _Nullable activity,
//                                      NSError * _Nullable error))completion;
- (void)fetchActivityStreams:(NSNumber *)activityID
                       types:(NSArray<NSString *> *)types
                  completion:(void (^)(NSDictionary<NSString *, NSArray *> * _Nullable streams, NSError * _Nullable error))completion;


// Returns an autoreleased copy of the current token, or nil if none.
- (NSString * _Nullable)currentAccessToken;

// Ensures you have a valid token (refreshing or reauthing if needed) and returns it.
- (void)fetchFreshAccessToken:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion;

- (void)_ensureFreshAccessToken:(StravaAuthCompletion)completion;

- (void)persistTokensWithAccess:(NSString *)access refresh:(NSString *)refresh;

typedef void (^StravaPhotosCompletion)(NSArray<NSDictionary *> * _Nullable photos, NSError * _Nullable error);

// Get all photos for an activity (Strava + external). `size` is the longest edge (e.g. 1024 or 2048).
- (void)fetchActivityPhotos:(NSNumber *)activityID
                       size:(NSUInteger)size
                      queue:(dispatch_queue_t _Nullable)queue
                 completion:(StravaPhotosCompletion)completion;


- (BOOL)fetchPhotosForActivity:(NSNumber*)stravaActivityID
                  rootMediaURL:(NSURL *)mediaURL
                    completion:(void (^)(NSArray<NSString *> * photoFilenames, NSError * error))completion;

@end

NS_ASSUME_NONNULL_END
