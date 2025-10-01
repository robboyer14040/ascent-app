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

+ (NSArray *)startEndCityCountryForTrack:(Track *)track
                                 numLocations:(NSUInteger)num
                                        error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4201
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    __block NSArray *resultArr = nil;
    __block NSError *blockErr = nil;

    if ([self _onGeoQueue]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        resultArr = [[self _startEndWork_forTrack:track
                                     numLocations:num
                                            error:&blockErr] retain];
        if (blockErr)
            [blockErr retain];   // <-- keep error alive past pool
        [pool drain];
    } else {
        dispatch_sync([self _geoWorkQueue], ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            resultArr = [[self _startEndWork_forTrack:track
                                         numLocations:num
                                                error:&blockErr] retain];
            if (blockErr)
                [blockErr retain]; // <-- keep error alive past pool
            [pool drain];
        });
    }

    if (outError) {
        // balance the retain above; return autoreleased error to caller’s pool
        *outError = [blockErr autorelease];
    }
    return [resultArr autorelease];
}


+ (void)startEndCityCountryForTrack:(Track *)track
                       numLocations:(NSUInteger)num
                         completion:(void(^)(NSArray * _Nullable result,
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
        NSArray *arr = [self _startEndWork_forTrack:track
                                       numLocations:num
                                              error:&err];

        // Retain both before draining the pool they were created in
        [arr retain];
        [err retain];

        [pool drain];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Hand back autoreleased objects to the caller on main
            completion([arr autorelease], [err autorelease]);
        });
    });
}


// Helpers (same as before)
+ (BOOL)_validLatLonFromPoint:(TrackPoint *)p lat:(double *)outLat lon:(double *)outLon {
    if (![p isKindOfClass:[TrackPoint class]]) return NO;
    float plat = [p latitude], plon = [p longitude];
    BOOL ok = [p validLatLon] && isfinite(plat) && isfinite(plon) &&
              fabsf(plat) <= 90.0f && fabsf(plon) <= 180.0f &&
              !(plat == 0.0f && plon == 0.0f);
    if (ok) { if (outLat) *outLat = plat; if (outLon) *outLon = plon; }
    return ok;
}

+ (BOOL)_extractFirstValidLatLonIndexFromTrack:(Track *)track
                                        index:(NSUInteger *)outIdx
                                          lat:(double *)outLat
                                          lon:(double *)outLon
{
    NSArray *pts = [track points];
    for (NSUInteger i = 0, n = [pts count]; i < n; i++) {
        TrackPoint *p = [pts objectAtIndex:i];
        double lat=0, lon=0;
        if ([self _validLatLonFromPoint:p lat:&lat lon:&lon]) {
            if (outIdx) *outIdx = i;
            if (outLat) *outLat = lat;
            if (outLon) *outLon = lon;
            return YES;
        }
    }
    return NO;
}

+ (BOOL)_extractLastValidLatLonIndexFromTrack:(Track *)track
                                       index:(NSUInteger *)outIdx
                                         lat:(double *)outLat
                                         lon:(double *)outLon
{
    NSArray *pts = [track points];
    for (NSInteger i = (NSInteger)[pts count] - 1; i >= 0; i--) {
        TrackPoint *p = [pts objectAtIndex:(NSUInteger)i];
        double lat=0, lon=0;
        if ([self _validLatLonFromPoint:p lat:&lat lon:&lon]) {
            if (outIdx) *outIdx = (NSUInteger)i;
            if (outLat) *outLat = lat;
            if (outLon) *outLon = lon;
            return YES;
        }
    }
    return NO;
}

// Find the nearest valid point to a target index by scanning outward.
+ (BOOL)_nearestValidLatLonInTrack:(Track *)track
                           nearIdx:(NSUInteger)idx
                               lat:(double *)outLat
                               lon:(double *)outLon
{
    NSArray *pts = [track points];
    NSUInteger n = [pts count];
    if (n == 0) return NO;
    if (idx >= n) idx = n - 1;

    TrackPoint *p = [pts objectAtIndex:idx];
    if ([self _validLatLonFromPoint:p lat:outLat lon:outLon]) return YES;

    for (NSUInteger step = 1; step < n; step++) {
        if (idx >= step) {
            p = [pts objectAtIndex:(idx - step)];
            if ([self _validLatLonFromPoint:p lat:outLat lon:outLon]) return YES;
        }
        if (idx + step < n) {
            p = [pts objectAtIndex:(idx + step)];
            if ([self _validLatLonFromPoint:p lat:outLat lon:outLon]) return YES;
        }
    }
    return NO;
}

// NEW: NSArray-returning API (ordered locations after de-dup).
+ (NSArray<NSDictionary *> *)_startEndWork_forTrack:(Track *)track
                                       numLocations:(NSUInteger)numLocations
                                              error:(NSError * _Nullable * _Nullable)outError
{
    if (numLocations == 0) numLocations = 1;

    // Start / End indices & coords
    NSUInteger iStart = 0, iEnd = 0;
    double sLat=0, sLon=0, eLat=0, eLon=0;

    if (![self _extractFirstValidLatLonIndexFromTrack:track index:&iStart lat:&sLat lon:&sLon]) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4202
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No valid start coordinate"}];
        return nil;
    }
    if (![self _extractLastValidLatLonIndexFromTrack:track index:&iEnd lat:&eLat lon:&eLon]) {
        iEnd = iStart; eLat = sLat; eLon = sLon; // reuse start if no separate end
    }

    // Build target indices: start, evenly spaced interior, end (inclusive)
    NSMutableArray *indices = [NSMutableArray arrayWithCapacity:numLocations];
    if (numLocations == 1) {
        [indices addObject:[NSNumber numberWithUnsignedInteger:iStart]];
    } else {
        double span = (iEnd >= iStart) ? (double)(iEnd - iStart) : 0.0;
        double step = (numLocations > 1) ? (span / (double)(numLocations - 1)) : 0.0;

        NSInteger lastAdded = -1;
        for (NSUInteger k = 0; k < numLocations; k++) {
            double dIdx = (double)iStart + step * (double)k;
            NSInteger idx = (NSInteger)llround(dIdx);
            if (idx < (NSInteger)iStart) idx = (NSInteger)iStart;
            if (idx > (NSInteger)iEnd)   idx = (NSInteger)iEnd;
            if (idx != lastAdded) {
                [indices addObject:[NSNumber numberWithInteger:idx]];
                lastAdded = idx;
            }
        }
        if ([indices count] == 0) {
            [indices addObject:[NSNumber numberWithUnsignedInteger:iStart]];
        }
    }

    // Reverse geocode each index (sequentially to respect CLGeocoder limits)
    NSMutableArray *geoSeq = [NSMutableArray arrayWithCapacity:[indices count]];
    for (NSNumber *nIdx in indices) {
        NSUInteger idx = (NSUInteger)[nIdx unsignedIntegerValue];

        double lat=0, lon=0;
        if (![self _nearestValidLatLonInTrack:track nearIdx:idx lat:&lat lon:&lon]) {
            continue; // no valid coordinate found near this index
        }

        NSError *gErr = nil;
        NSDictionary *loc = [self _reverseGeocodeLatitude:lat longitude:lon error:&gErr];
        if (!loc) {
            // Keep lat/lon so spacing is preserved even if geocode fails
            NSMutableDictionary *fallback = [[NSMutableDictionary alloc] initWithCapacity:2];
            [fallback setObject:[NSNumber numberWithDouble:lat] forKey:kGeoLatitude];
            [fallback setObject:[NSNumber numberWithDouble:lon] forKey:kGeoLongitude];
            loc = [fallback autorelease];
        }
        [geoSeq addObject:loc];
    }

    if ([geoSeq count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:LocationAPIErrorDomain
                                                      code:4203
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No locations could be geocoded"}];
        return nil;
    }

    // Collapse adjacent duplicates where (city, country) match
    NSMutableArray *uniqueSeq = [NSMutableArray arrayWithCapacity:[geoSeq count]];
    NSString *prevCity = nil, *prevCountry = nil;

    for (NSDictionary *loc in geoSeq) {
        NSString *city    = [loc objectForKey:kGeoCity];
        NSString *country = [loc objectForKey:kGeoCountry];

        BOOL same =
            ((prevCity    && city    && [prevCity isEqualToString:city])    || (!prevCity && !city)) &&
            ((prevCountry && country && [prevCountry isEqualToString:country]) || (!prevCountry && !country));

        if (![uniqueSeq count] || !same) {
            [uniqueSeq addObject:loc];
            prevCity    = city;
            prevCountry = country;
        }
    }

    // Return immutable NSArray (ordered)
    return [[uniqueSeq copy] autorelease];
}

@end
