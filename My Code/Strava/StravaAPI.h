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


// Detail + Streams helpers
- (void)fetchActivityDetail:(NSNumber *)activityID
                 completion:(void (^)(NSDictionary * _Nullable activity, NSError * _Nullable error))completion;

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

- (BOOL)fetchPhotosForActivity:(NSNumber*)stravaActivityID
                  rootMediaURL:(NSURL *)mediaURL
                    completion:(void (^)(NSArray<NSString *> * photoFilenames, NSError * error))completion;


typedef void (^StravaGearMapCompletion)(NSDictionary<NSString *, NSString *> * _Nullable gearByID,
                                        NSError * _Nullable error);

- (void)fetchGearMap:(StravaGearMapCompletion)completion;


// Synchronous helpers (call from a background thread)
- (NSArray<NSDictionary *> * _Nullable)fetchActivitiesSince:(NSDate *)since
                                                    perPage:(NSUInteger)perPage
                                                       page:(NSUInteger)page
                                                      error:(NSError * _Nullable * _Nullable)outError;

- (NSDictionary<NSString *, NSArray *> * _Nullable)fetchStreamsForActivityID:(NSNumber *)actID
                                                                       error:(NSError * _Nullable * _Nullable)outError;

- (void)fetchSegmentsForActivityID:(NSNumber *)activityID
                        completion:(void (^)(NSArray<NSDictionary *> * _Nullable segments,
                                             NSError * _Nullable error))completion;


@end

NS_ASSUME_NONNULL_END
