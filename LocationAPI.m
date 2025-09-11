//
//  LocationAPI.m
//  Ascent
//
//  Created by Rob Boyer on 9/11/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


//
//  LocationAPI.m
//  Ascent
//
//  Created by Rob Boyer on 9/11/25.
//  Updated by ChatGPT on 9/11/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import "LocationAPI.h"
#import "Track.h"
#import "TrackPoint.h"
#import <CoreLocation/CoreLocation.h>

NSString * const kGeoCity        = @"city";
NSString * const kGeoCountry     = @"country";
NSString * const kGeoCountryCode = @"country_code";
NSString * const kGeoAdmin       = @"admin";
NSString * const kGeoLatitude    = @"lat";
NSString * const kGeoLongitude   = @"lon";

NSString * const kGeoStart = @"start";
NSString * const kGeoEnd   = @"end";

NSString * const LocationAPIErrorDomain = @"LocationAPI";

@implementation LocationAPI

#pragma mark - Helpers (coordinate extraction)

+ (BOOL)_extractFirstValidLatLonFromTrack:(Track *)track
                                      lat:(double *)outLat
                                      lon:(double *)outLon
{
    double lat = (double)[track firstValidLatitude];
    double lon = (double)[track firstValidLongitude];
    BOOL ok = isfinite(lat) && isfinite(lon) &&
              fabs(lat) <= 90.0 && fabs(lon) <= 180.0 &&
              !(lat == 0.0 && lon == 0.0);

    if (!ok) {
        NSArray *pts = [track points];
        for (NSUInteger i = 0, n = [pts count]; i < n; i++) {
            TrackPoint *p = [pts objectAtIndex:i];
            if (![p isKindOfClass:[TrackPoint class]]) continue;
            float plat = [p latitude], plon = [p longitude];
            if ([p validLatLon] && isfinite(plat) && isfinite(plon) &&
                fabs(plat) <= 90.0f && fabs(plon) <= 180.0f &&
                !(plat == 0.0f && plon == 0.0f)) {
                lat = plat; lon = plon; ok = YES; break;
            }
        }
    }
    if (ok) { if (outLat) *outLat = lat; if (outLon) *outLon = lon; }
    return ok;
}

+ (BOOL)_extractLastValidLatLonFromTrack:(Track *)track
                                     lat:(double *)outLat
                                     lon:(double *)outLon
{
    NSArray *pts = [track points];
    for (NSInteger i = (NSInteger)[pts count] - 1; i >= 0; i--) {
        TrackPoint *p = [pts objectAtIndex:(NSUInteger)i];
        if (![p isKindOfClass:[TrackPoint class]]) continue;
        float lat = [p latitude], lon = [p longitude];
        if ([p validLatLon] && isfinite(lat) && isfinite(lon) &&
            fabs(lat) <= 90.0f && fabs(lon) <= 180.0f &&
            !(lat == 0.0f && lon == 0.0f)) {
            if (outLat) *outLat = lat;
            if (outLon) *outLon = lon;
            return YES;
        }
    }
    return NO;
}

#pragma mark - Reverse geocoding

+ (NSDictionary *)_reverseGeocodeLatitude:(double)lat
                                longitude:(double)lon
                                    error:(NSError * _Nullable * _Nullable)outError
{
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
    CLGeocoder *geo = [[CLGeocoder alloc] init];

    __block NSArray<CLPlacemark*> *places = nil;
    __block NSError *gErr = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [geo reverseGeocodeLocation:loc completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (placemarks) places = [placemarks retain];
        if (error)      gErr    = [error retain];
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    [geo release];
    [loc release];

    if (gErr) {
        if (outError) *outError = [gErr autorelease];
        if (places) [places release];
        return nil;
    }
    if (!places || [places count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4101
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No placemark found"}];
        return nil;
    }

    CLPlacemark *pm = [places objectAtIndex:0];
    NSString *city =
        (pm.locality              ?:
        (pm.subLocality           ?:
        (pm.subAdministrativeArea ?:
        (pm.administrativeArea    ?: pm.name))));
    NSString *admin   = (pm.administrativeArea ?: pm.subAdministrativeArea);
    NSString *country = pm.country;
    NSString *cc      = pm.ISOcountryCode;

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    if (city)    [dict setObject:city    forKey:kGeoCity];
    if (admin)   [dict setObject:admin   forKey:kGeoAdmin];
    if (country) [dict setObject:country forKey:kGeoCountry];
    if (cc)      [dict setObject:cc      forKey:kGeoCountryCode];
    [dict setObject:[NSNumber numberWithDouble:lat] forKey:kGeoLatitude];
    [dict setObject:[NSNumber numberWithDouble:lon] forKey:kGeoLongitude];

    [places release];
    return [dict autorelease];
}

#pragma mark - Public API (sync)

+ (NSDictionary *)startEndCityCountryForTrack:(Track *)track
                                        error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4201
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    // If we're on the main thread, do the work on a background queue to avoid blocking UI,
    // but still behave synchronously for the caller by waiting on a semaphore.
    if ([NSThread isMainThread]) {
        __block NSDictionary *resultDict = nil;
        __block NSError *blockErr = nil;

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            resultDict = [[self _startEndWork_forTrack:track error:&blockErr] retain];
            [pool drain];
            dispatch_semaphore_signal(done);
        });
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);

        if (outError) *outError = [blockErr autorelease];
        return [resultDict autorelease];
    } else {
        // Already off-main; just run directly.
        return [self _startEndWork_forTrack:track error:outError];
    }
}

#pragma mark - Public API (async)

+ (void)startEndCityCountryForTrack:(Track *)track
                         completion:(void(^)(NSDictionary * _Nullable result,
                                             NSError * _Nullable error))completion
{
    if (!track) {
        // Call back on main immediately with error
        NSError *err = [NSError errorWithDomain:LocationAPIErrorDomain
                                           code:4201
                                       userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, err);
        });
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSError *err = nil;
        NSDictionary *dict = [self _startEndWork_forTrack:track error:&err];

        // Always invoke completion on main.
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(dict, err);
        });

        [pool drain];
    });
}

#pragma mark - Core work (shared by sync & async)

+ (NSDictionary *)_startEndWork_forTrack:(Track *)track
                                   error:(NSError * _Nullable * _Nullable)outError
{
    double sLat=0, sLon=0, eLat=0, eLon=0;

    if (![self _extractFirstValidLatLonFromTrack:track lat:&sLat lon:&sLon]) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4202
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No valid start coordinate"}];
        return nil;
    }
    if (![self _extractLastValidLatLonFromTrack:track lat:&eLat lon:&eLon]) {
        // If no separate end found, reuse start as end
        eLat = sLat; eLon = sLon;
    }

    // Reverse-geocode sequentially (Apple's CLGeocoder is rate-limited).
    NSError *sErr = nil, *eErr = nil;
    NSDictionary *startDict = [self _reverseGeocodeLatitude:sLat longitude:sLon error:&sErr];
    NSDictionary *endDict   = [self _reverseGeocodeLatitude:eLat longitude:eLon error:&eErr];

    if (!startDict && !endDict) {
        if (outError) *outError = (sErr ?: eErr ?: [NSError errorWithDomain:LocationAPIErrorDomain
                                                                       code:4203
                                                                   userInfo:@{NSLocalizedDescriptionKey:@"Reverse geocoding failed"}]);
        return nil;
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (startDict) [result setObject:startDict forKey:kGeoStart];
    if (endDict)   [result setObject:endDict   forKey:kGeoEnd];
    return [result autorelease];
}

@end
