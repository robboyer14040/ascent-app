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

#pragma mark - Internal geocode queue

// Single serial queue for all geocoding (rate-limit friendly, never on main).
+ (dispatch_queue_t)_geoWorkQueue {
    static dispatch_queue_t queue = NULL;
    static void *queueKey = &queueKey;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.montebello.locationapi.geo", DISPATCH_QUEUE_SERIAL);
        // Tag the queue so we can detect re-entrancy and avoid dispatch_sync deadlocks.
        dispatch_queue_set_specific(queue, queueKey, queueKey, NULL);
    });
    return queue;
}

// Helper to test if we're currently on the geo queue.
+ (BOOL)_onGeoQueue {
    static void *queueKey = NULL;
    // We set the same address in _geoWorkQueue via dispatch_queue_set_specific.
    // Fetch it once so both methods share the same pointer value.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Touch the queue so it's created and keyed.
        (void)[self _geoWorkQueue];
        // Peek the key pointer by querying while on the queue.
        __block void *observed = NULL;
        dispatch_sync([self _geoWorkQueue], ^{
            // The exact pointer used as key is the address of the static in _geoWorkQueue.
            // We can retrieve it by using dispatch_get_specific with any non-null key;
            // but since we don't have the key pointer here, cache the result by setting a second key.
            observed = (void *)1; // marker
        });
        // We can't truly fetch the original key pointer externally; instead, we use dispatch_get_specific
        // with the address of this static "queueKey" after setting it on the queue as well:
        dispatch_sync([self _geoWorkQueue], ^{
            dispatch_queue_set_specific([self _geoWorkQueue], &queueKey, &queueKey, NULL);
        });
    });
    return dispatch_get_specific(&queueKey) == &queueKey;
}

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

+ (NSDictionary *)startEndCityCountryForTrack:(Track *)track
                                        error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4201
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    __block NSDictionary *resultDict = nil;
    __block NSError *blockErr = nil;

    if ([self _onGeoQueue]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        resultDict = [[self _startEndWork_forTrack:track error:&blockErr] retain];
        if (blockErr) [blockErr retain];   // <-- keep error alive past pool
        [pool drain];
    } else {
        dispatch_sync([self _geoWorkQueue], ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            resultDict = [[self _startEndWork_forTrack:track error:&blockErr] retain];
            if (blockErr) [blockErr retain]; // <-- keep error alive past pool
            [pool drain];
        });
    }

    if (outError) {
        // balance the retain above; return autoreleased error to caller’s pool
        *outError = [blockErr autorelease];
    }
    return [resultDict autorelease];
}

+ (void)startEndCityCountryForTrack:(Track *)track
                         completion:(void(^)(NSDictionary * _Nullable result,
                                             NSError * _Nullable error))completion
{
    if (!track) {
        NSError *err = [NSError errorWithDomain:LocationAPIErrorDomain
                                           code:4201
                                       userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
        return;
    }

    dispatch_async([self _geoWorkQueue], ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSError *err = nil;
        NSDictionary *dict = [self _startEndWork_forTrack:track error:&err];

        // Retain both before draining the pool they were created in
        [dict retain];
        [err retain];

        [pool drain];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Hand back autoreleased objects to the caller on main
            completion([dict autorelease], [err autorelease]);
        });
    });
}

@end
