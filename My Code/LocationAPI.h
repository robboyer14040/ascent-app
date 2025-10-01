//
//  LocationAPI.h
//  Ascent
//
//  Created by Rob Boyer on 9/11/25.
//  Updated by ChatGPT on 9/11/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Track;

@interface LocationAPI : NSObject

// Reuse existing kGeo* keys for each location dictionary
FOUNDATION_EXPORT NSString * const kGeoCity;         // @"city"
FOUNDATION_EXPORT NSString * const kGeoCountry;      // @"country"
FOUNDATION_EXPORT NSString * const kGeoCountryCode;  // @"country_code"
FOUNDATION_EXPORT NSString * const kGeoAdmin;        // @"admin"
FOUNDATION_EXPORT NSString * const kGeoLatitude;     // @"lat"
FOUNDATION_EXPORT NSString * const kGeoLongitude;    // @"lon"

// Container keys
///FOUNDATION_EXPORT NSString * const kGeoStart;        // @"start" -> NSDictionary (kGeoCity, ...)
///FOUNDATION_EXPORT NSString * const kGeoEnd;          // @"end"   -> NSDictionary (kGeoCity, ...)

// Error domain
FOUNDATION_EXPORT NSString * const LocationAPIErrorDomain;

/// Synchronous (blocks), but **always runs work off the main thread** via an internal queue.
+ (nullable NSArray *)startEndCityCountryForTrack:(Track *)track
                                     numLocations:(NSUInteger)num
                                            error:(NSError * _Nullable * _Nullable)outError;

/// Asynchronous; executes on the same internal queue; completion is called on the **main thread**.
+ (void)startEndCityCountryForTrack:(Track *)track
                       numLocations:(NSUInteger)num
                         completion:(void(^)(NSArray * _Nullable result,
                                             NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
