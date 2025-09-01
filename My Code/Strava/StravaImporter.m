//
//  StravaImporter.m
//  Ascent
//
//  Created by Rob Boyer on 8/31/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// StravaImporter.m (MRC)
#import "StravaImporter.h"
#import "StravaAPI.h"
#import "Track.h"
#import "TrackPoint.h"

static inline id Safe(id v) { return (v == (id)kCFNull ? nil : v); }

// Unit conversions (statute)
static const double kMToMi     = 0.000621371;
static const double kMToFt     = 3.28084;
static const double kMPSToMPH  = 2.2369362921;

// ---- ISO8601 (UTC Z) -> NSDate
static NSDate *ISO8601ToDate(NSString *iso) {
    if (!iso) return nil;
    static NSDateFormatter *fmt = nil;
    if (!fmt) {
        fmt = [[NSDateFormatter alloc] init];
        [fmt setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
        [fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [fmt setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    return [fmt dateFromString:iso];
}

// ---- Simple sync JSON GET
static id GET_JSON(NSString *urlStr, NSString *accessToken, NSError **outError) {
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [[[NSMutableURLRequest alloc] initWithURL:url
                                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                         timeoutInterval:60.0] autorelease];
    [req setHTTPMethod:@"GET"];
    if (accessToken.length) {
        NSString *hdr = [@"Bearer " stringByAppendingString:accessToken];
        [req setValue:hdr forHTTPHeaderField:@"Authorization"];
    }
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    __block NSData *data = nil;
    __block NSHTTPURLResponse *resp = nil;
    __block NSError *taskError = nil;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];

    // Use the class factory (avoids the "instance method not found" warning).
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:nil
                                                     delegateQueue:nil];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                            completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        data = [d retain];
        resp = [(NSHTTPURLResponse *)r retain];
        taskError = [e retain];
        dispatch_semaphore_signal(sema);
    }];

    [task resume];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    [session finishTasksAndInvalidate];
#if !OS_OBJECT_USE_OBJC
    dispatch_release(sema);
#endif

    if (taskError) {
        if (outError) { *outError = [taskError autorelease]; }
        [data release];
        [resp release];
        return nil;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (outError) {
            // Prefer the NSURL-valued key
            NSDictionary *ui = [NSDictionary dictionaryWithObject:url forKey:NSURLErrorFailingURLErrorKey];
            *outError = [NSError errorWithDomain:@"StravaHTTP" code:resp.statusCode userInfo:ui];
        }
        [data release];
        [resp release];
        return nil;
    }

    NSError *jsonErr = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];

    [data release];
    [resp release];

    if (!json || jsonErr) {
        if (outError) *outError = jsonErr;
        return nil;
    }
    return json; // autoreleased
}

// ---- Map Strava workout_type -> event string (best-effort)
static NSString *EventTypeStringFromWorkoutType(NSNumber *workoutType, NSString *sportType) {
    if (!workoutType || (id)workoutType == (id)kCFNull) return nil;
    // Strava commonly: For runs: 1=race, 2=long run, 3=workout
    NSInteger w = [workoutType integerValue];
    if ([sportType isEqualToString:@"Run"] || [sportType isEqualToString:@"Running"]) {
        if (w == 1) return @"race";
        if (w == 2) return @"long_run";
        if (w == 3) return @"workout";
    }
    // Otherwise just tag as "training" for now
    return @"training";
}

// ---- Build TrackPoint array from streams (statute units)
static NSArray *PointsFromStreams(NSDictionary *streamsByType) {
    NSArray *time     = Safe(Safe(streamsByType[@"time"])[@"data"]);
    NSArray *latlng   = Safe(Safe(streamsByType[@"latlng"])[@"data"]);
    NSArray *distance = Safe(Safe(streamsByType[@"distance"])[@"data"]);        // m cumulative
    NSArray *vel      = Safe(Safe(streamsByType[@"velocity_smooth"])[@"data"]); // m/s
    NSArray *alt      = Safe(Safe(streamsByType[@"altitude"])[@"data"]);        // m
    NSArray *hr       = Safe(Safe(streamsByType[@"heartrate"])[@"data"]);       // bpm
    NSArray *cad      = Safe(Safe(streamsByType[@"cadence"])[@"data"]);         // rpm
    NSArray *tmp      = Safe(Safe(streamsByType[@"temperature"])[@"data"]);     // °C
    NSArray *wat      = Safe(Safe(streamsByType[@"watts"])[@"data"]);           // W
    NSArray *grade    = Safe(Safe(streamsByType[@"grade_smooth"])[@"data"]);    // %
    NSArray *moving   = Safe(Safe(streamsByType[@"moving"])[@"data"]);          // 0/1 per-sample (optional)

    NSUInteger N = 0;
    NSArray *all = [NSArray arrayWithObjects:time,latlng,distance,vel,alt,hr,cad,tmp,wat,grade,moving,nil];
    for (NSArray *arr in all) if ([arr isKindOfClass:[NSArray class]]) N = MAX(N, [arr count]);
    if (N == 0) return [NSArray array];

    NSMutableArray *out = [NSMutableArray arrayWithCapacity:N];

    double prevTime = NAN, prevDistM = NAN, prevAltM = NAN;

    for (NSUInteger i = 0; i < N; i++) {
        TrackPoint *p = [[[TrackPoint alloc] init] autorelease];

        // Time: seconds since start
        double t = (i < [time count]) ? [[time objectAtIndex:i] doubleValue]
                                      : (isnan(prevTime) ? 0.0 : prevTime);
        p.wallClockDelta = t;
        double dt = (isnan(prevTime) ? 0.0 : MAX(0.0, t - prevTime));

        // Lat/Lon
        if (i < [latlng count]) {
            id pair = [latlng objectAtIndex:i];
            if ([pair isKindOfClass:[NSArray class]] && [pair count] == 2) {
                p.latitude  = [[pair objectAtIndex:0] floatValue];
                p.longitude = [[pair objectAtIndex:1] floatValue];
            }
        }

        // Distance (meters -> miles)
        double d_m = (i < [distance count]) ? [[distance objectAtIndex:i] doubleValue]
                                            : (isnan(prevDistM) ? NAN : prevDistM);
        p.origDistance = isnan(d_m) ? 0.0f : (float)(d_m * kMToMi);

        // Speed (m/s -> mph), fallback Δd/Δt
        double v_mps = (i < [vel count]) ? [[vel objectAtIndex:i] doubleValue] : NAN;
        if (isnan(v_mps) && !isnan(prevDistM) && !isnan(d_m) && dt > 0.0) v_mps = (d_m - prevDistM) / dt;
        p.speed = isnan(v_mps) ? 0.0f : (float)(v_mps * kMPSToMPH);

        // Active time delta: prefer 'moving' stream
        if (i < [moving count]) {
            BOOL isMoving = [[moving objectAtIndex:i] boolValue];
            p.activeTimeDelta = isMoving ? dt : 0.0;
        } else {
            // threshold 0.1 m/s
            p.activeTimeDelta = (!isnan(v_mps) && v_mps > 0.1) ? dt : 0.0;
        }

        // Altitude (m -> ft)
        double a_m = (i < [alt count]) ? [[alt objectAtIndex:i] doubleValue]
                                       : (isnan(prevAltM) ? NAN : prevAltM);
        p.origAltitude = isnan(a_m) ? 0.0f : (float)(a_m * kMToFt);

        // Sensors
        if (i < [hr count])   p.heartrate   = [[hr objectAtIndex:i] floatValue];
        if (i < [cad count])  p.cadence     = [[cad objectAtIndex:i] floatValue];
        if (i < [wat count])  p.power       = [[wat objectAtIndex:i] floatValue];
        if (i < [tmp count]) {
            double c = [[tmp objectAtIndex:i] doubleValue];
            p.temperature = (float)(c * 9.0/5.0 + 32.0); // °F
        }

        // Gradient
        if (i < [grade count]) {
            p.gradient = [[grade objectAtIndex:i] floatValue];
        } else if (!isnan(prevAltM) && !isnan(prevDistM) && !isnan(a_m) && !isnan(d_m)) {
            double dh = a_m - prevAltM, dd = d_m - prevDistM;
            p.gradient = (dd > 0.0) ? (float)((dh / dd) * 100.0) : 0.0f;
        }

        [out addObject:p];
        prevTime  = t;
        prevDistM = d_m;
        prevAltM  = a_m;
    }

    return out;
}

// ---- Strava API helpers -----------------------------------------------------

@interface StravaImporter ()
@end;


@implementation StravaImporter
+ (instancetype)shared {
    static StravaImporter *gShared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ gShared = [[self alloc] init]; });
    return gShared;
}

- (id)initWithAccessToken:(NSString *)accessToken {
    if ((self = [super init])) {
        _accessToken = [accessToken copy];
    }
    return self;
}

- (void)dealloc {
    [_accessToken release];
    [super dealloc];
}

// GET /api/v3/athlete/activities?after=...&per_page=...&page=...
- (NSArray *)fetchActivitiesSince:(NSDate *)since
                          perPage:(NSUInteger)perPage
                            page:(NSUInteger)page
                           error:(NSError **)outError
{
    NSTimeInterval after = floor([since timeIntervalSince1970]); // seconds
    NSString *url = [NSString stringWithFormat:
                     @"https://www.strava.com/api/v3/athlete/activities?after=%.0f&per_page=%lu&page=%lu",
                     after, (unsigned long)perPage, (unsigned long)page];
    id json = GET_JSON(url, _accessToken, outError);
    if (!json || ![json isKindOfClass:[NSArray class]])
        return nil;
    return json; // NSArray<NSDictionary *>
}

// GET /api/v3/activities/{id}/streams?keys=...&key_by_type=true
- (NSDictionary *)fetchStreamsForActivityID:(NSNumber *)actID
                                      error:(NSError **)outError
{
    NSString *keys = @"time,latlng,distance,velocity_smooth,altitude,heartrate,cadence,temperature,watts,grade_smooth,moving";
    NSString *url = [NSString stringWithFormat:
                     @"https://www.strava.com/api/v3/activities/%@/streams?keys=%@&key_by_type=true",
                     actID, keys];
    id json = GET_JSON(url, _accessToken, outError);
    if (!json) return nil;
    
    if ([json isKindOfClass:[NSDictionary class]]) {
        // key_by_type=true (ideal)
        return json;
    }
    
    if ([json isKindOfClass:[NSArray class]]) {
        // Convert array of stream dicts into a by-type dictionary
        NSMutableDictionary *byType = [NSMutableDictionary dictionary];
        for (NSDictionary *stream in (NSArray *)json) {
            NSString *type = stream[@"type"];
            if (type) [byType setObject:stream forKey:type];
        }
        return byType;
    }
    
    // Unexpected shape
    if (outError) {
        *outError = [NSError errorWithDomain:@"StravaJSON"
                                        code:-1
                                    userInfo:@{ NSLocalizedDescriptionKey : @"Unexpected streams JSON format" }];
    }
    return nil;
}


// ---- Public entry: import everything into Track/TrackPoint ------------------

#if 0
- (NSArray *)importTracksSince:(NSDate *)since
                       perPage:(NSUInteger)perPage
                      maxPages:(NSUInteger)maxPages
                         error:(NSError **)outError
{
    NSMutableArray *tracksOut = [NSMutableArray array];
    NSError *err = nil;

    for (NSUInteger page = 1; page <= maxPages; page++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSArray *activities = [self fetchActivitiesSince:since perPage:perPage page:page error:&err];
        if (!activities) { if (outError) *outError = err; [pool drain]; break; }
        if ([activities count] == 0) { [pool drain]; break; }

        for (NSDictionary *act in activities) {
            NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];

            // ---- Build Track header
            Track *track = [[[Track alloc] init] autorelease];

            // uuid: use Strava id (string)
            id actIDObj = Safe(act[@"id"]);
            NSString *uuid = actIDObj ? [[actIDObj description] copy] : nil;
            if (uuid) { [track setUuid:uuid]; [uuid release]; }

            // name
            NSString *name = Safe(act[@"name"]);
            if (name) [track setName:name];

            // creationTime: start_date (UTC ISO8601 Z)
            NSString *startISO = Safe(act[@"start_date"]);
            NSDate *startDate = ISO8601ToDate(startISO);
            if (startDate) [track setCreationTime:startDate];

            // distance: meters -> miles
            NSNumber *distM = Safe(act[@"distance"]);
            if (distM) [track setDistance:([distM doubleValue] * kMToMi)];

            // notes / description
            NSString *desc = Safe(act[@"description"]);
            if (desc && [desc length] > 0) {
                // Store as attribute kNotes
                [track setAttribute:kNotes usingString:desc];
            }

            // activity_type -> kActivity (use sport_type or type)
            NSString *sportType = Safe(act[@"sport_type"]) ?: Safe(act[@"type"]);
            if (sportType) [track setAttribute:kActivity usingString:sportType];

            // event_type -> kEventType (best-effort from workout_type)
            NSString *eventType = EventTypeStringFromWorkoutType(Safe(act[@"workout_type"]), sportType);
            if (eventType) [track setAttribute:kEventType usingString:eventType];

            // ---- Fetch streams and build TrackPoints
            NSNumber *actIDNum = ([actIDObj isKindOfClass:[NSNumber class]]
                                  ? (NSNumber *)actIDObj
                                  : [NSNumber numberWithLongLong:[[actIDObj description] longLongValue]]);
            NSDictionary *streams = [self fetchStreamsForActivityID:actIDNum error:&err];
            if (!streams && err) {
                // If streams fail, push empty points but still keep the track header.
                err = nil;
                [track setPoints:[NSMutableArray array]];
                [tracksOut addObject:track];
                [p drain];
                continue;
            }

            NSArray *pts = PointsFromStreams(streams);

            // put into mutable array for Track API
            NSMutableArray *mutablePts = [NSMutableArray arrayWithCapacity:[pts count]];
            for (TrackPoint *tp in pts) [mutablePts addObject:tp];

            [track setPoints:mutablePts];
            [track fixupTrack];
            [tracksOut addObject:track];
            [p drain];
        }

        [pool drain];
    }

    return tracksOut;
}
#else
- (NSArray *)importTracksSince:(NSDate *)since
                       perPage:(NSUInteger)perPage
                      maxPages:(NSUInteger)maxPages
                         error:(NSError **)outError
{
    NSMutableArray *tracksOut = [NSMutableArray array];
    NSError *err = nil;

    for (NSUInteger page = 1; page <= maxPages; page++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSArray *activities = [self fetchActivitiesSince:since perPage:perPage page:page error:&err];
        if (!activities) { if (outError) *outError = err; [pool drain]; break; }
        if ([activities count] == 0) { [pool drain]; break; }

        for (NSDictionary *act in activities) {
            NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];

            // ---- Build Track header
            Track *track = [[[Track alloc] init] autorelease];

            // Strava id → uuid (string)
            id actIDObj = Safe(act[@"id"]);
            NSString *uuid = actIDObj ? [[actIDObj description] copy] : nil;
            if (uuid) { [track setUuid:uuid]; [uuid release]; }

            // Numeric ID for API calls
            NSNumber *actIDNum = ([actIDObj isKindOfClass:[NSNumber class]]
                                  ? (NSNumber *)actIDObj
                                  : (actIDObj ? [NSNumber numberWithLongLong:[[actIDObj description] longLongValue]] : nil));

            // name
            NSString *name = Safe(act[@"name"]);
            if (name) [track setName:name];

            // creationTime: start_date (UTC ISO8601 Z)
            NSString *startISO = Safe(act[@"start_date"]);
            NSDate *startDate = ISO8601ToDate(startISO);
            if (startDate) [track setCreationTime:startDate];

            // distance: meters -> miles
            NSNumber *distM = Safe(act[@"distance"]);
            if (distM) [track setDistance:([distM doubleValue] * kMToMi)];

            // activity_type -> kActivity (use sport_type or type)
            NSString *sportType = Safe(act[@"sport_type"]) ?: Safe(act[@"type"]);
            if (sportType) [track setAttribute:kActivity usingString:sportType];

            // event_type -> kEventType (best-effort from workout_type)
            NSString *eventType = EventTypeStringFromWorkoutType(Safe(act[@"workout_type"]), sportType);
            if (eventType) [track setAttribute:kEventType usingString:eventType];

            // ---- Notes / description
            // Summary payload often lacks "description" (or it's NSNull). If so, fetch the detailed activity.
            NSString *desc = Safe(act[@"description"]);
            if (!(desc && desc.length > 0) && actIDNum) {
                
                __block NSDictionary *detail = nil;
                __block NSError *detailErr = nil;

                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                [[StravaAPI shared] fetchActivityDetail:actIDNum
                                             completion:^(NSDictionary * _Nullable activity, NSError * _Nullable error)
                {
                    if (activity) detail = [activity retain];   // MRC
                    if (error)    detailErr = [error retain];   // (unused; for debugging)
                    dispatch_semaphore_signal(sem);
                }];

                // Wait up to ~20s (tune as you like)
                (void)dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
                #if !OS_OBJECT_USE_OBJC
                dispatch_release(sem);
                #endif

                if (detail) {
                    NSString *d = Safe(detail[@"description"]);
                    if (d.length) [track setAttribute:kNotes usingString:d];
                    [detail release];
                }
                if (detailErr) [detailErr release];
            } else if (desc.length) {
                [track setAttribute:kNotes usingString:desc];
            }

            // ---- Fetch streams and build TrackPoints
            NSDictionary *streams = actIDNum ? [self fetchStreamsForActivityID:actIDNum error:&err] : nil;
            if (!streams && err) {
                // Keep the header even if streams fail.
                err = nil;
                [track setPoints:[NSMutableArray array]];
                [tracksOut addObject:track];
                [p drain];
                continue;
            }

            NSArray *pts = PointsFromStreams(streams);

            // put into mutable array for Track API
            NSMutableArray *mutablePts = [NSMutableArray arrayWithCapacity:[pts count]];
            for (TrackPoint *tp in pts) [mutablePts addObject:tp];

            [track setPoints:mutablePts];
            [track fixupTrack];
            [tracksOut addObject:track];
            [p drain];
        }

        [pool drain];
    }

    return tracksOut;
}
#endif


// StravaImporter.m (implementation)
// Assumes typedefs:
// typedef void (^StravaImportProgress)(NSUInteger pagesFetched, NSUInteger totalSoFar);
// typedef void (^StravaImportCompletion)(NSArray * _Nullable tracks, NSError * _Nullable error);

- (void)importTracksSince:(NSDate *)since
                  perPage:(NSUInteger)perPage
                 maxPages:(NSUInteger)maxPages
                 progress:(StravaImportProgress)progress
               completion:(StravaImportCompletion)completion
{
    // Copy blocks for MRC safety
    StravaImportProgress      progressCopy   = [progress copy];
    StravaImportCompletion    completionCopy = [completion copy];
    NSDate *sinceRetained = [since retain];

    // Sanitize values outside the async block to avoid __block warnings
    const NSUInteger perPageEff  = (perPage  ? perPage  : 50);
    const NSUInteger maxPagesEff = (maxPages ? maxPages : 1);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *tracksOut = [[NSMutableArray alloc] init];
        NSError *err = nil;

        
        for (NSUInteger page = 1; page <= maxPagesEff; page++) {
            NSAutoreleasePool *pagePool = [[NSAutoreleasePool alloc] init];

            // ——— Page fetch (summary activities) ———
            NSArray *activities = [self fetchActivitiesSince:sinceRetained
                                                     perPage:perPageEff
                                                        page:page
                                                       error:&err];
            if (!activities) {
                // Hard failure fetching this page
                [pagePool drain];
                break;
            }
            NSUInteger numActivities = [activities count];
            if (numActivities == 0) {
                // No more pages
                [pagePool drain];
                break;
            }
            __block int idx = 0;
           // ——— Build Tracks for this page ———
            for (NSDictionary *act in activities) {
                NSAutoreleasePool *rowPool = [[NSAutoreleasePool alloc] init];


                // Track header
                Track *track = [[[Track alloc] init] autorelease];

                // Strava id → uuid (string)
                id actIDObj = Safe(act[@"id"]);
                NSString *uuid = actIDObj ? [[actIDObj description] copy] : nil;
                if (uuid) { [track setUuid:uuid]; [uuid release]; }

                // numeric ID for API calls
                NSNumber *actIDNum = ([actIDObj isKindOfClass:[NSNumber class]]
                                      ? (NSNumber *)actIDObj
                                      : (actIDObj ? [NSNumber numberWithLongLong:[[actIDObj description] longLongValue]] : nil));

                // name
                NSString *name = Safe(act[@"name"]);
                if (name) [track setName:name];

                // start_date (UTC ISO8601)
                NSString *startISO = Safe(act[@"start_date"]);
                NSDate *startDate = ISO8601ToDate(startISO);
                if (startDate) [track setCreationTime:startDate];

                // distance meters → miles
                NSNumber *distM = Safe(act[@"distance"]);
                if (distM) [track setDistance:([distM doubleValue] * kMToMi)];

                // activity type
                NSString *sportType = Safe(act[@"sport_type"]) ?: Safe(act[@"type"]);
                if (sportType) [track setAttribute:kActivity usingString:sportType];

                // event type (best-effort)
                NSString *eventType = EventTypeStringFromWorkoutType(Safe(act[@"workout_type"]), sportType);
                if (eventType) [track setAttribute:kEventType usingString:eventType];

                // ---- Notes / description
                // Summary often lacks "description". If missing, fetch detail.
                NSString *desc = Safe(act[@"description"]);
                if (!(desc && desc.length > 0) && actIDNum) {
                    __block NSDictionary *detail = nil;
                    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

                    // Current StravaAPI delivers completion on main; we’re off-main, so it’s safe to wait briefly.
                    [[StravaAPI shared] fetchActivityDetail:actIDNum
                                                 completion:^(NSDictionary * _Nullable activity, NSError * _Nullable error) {
                        if (activity) detail = [activity retain]; // MRC retain for use after wait
                        dispatch_semaphore_signal(sem);
                    }];

                    (void)dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
                #if !OS_OBJECT_USE_OBJC
                    dispatch_release(sem);
                #endif

                    if (detail) {
                        NSString *d = Safe(detail[@"description"]);
                        if (d.length) [track setAttribute:kNotes usingString:d];
                        [detail release];
                    }
                } else if (desc.length) {
                    [track setAttribute:kNotes usingString:desc];
                }

                // ---- Streams → TrackPoints
                NSDictionary *streams = actIDNum ? [self fetchStreamsForActivityID:actIDNum error:&err] : nil;
                if (!streams && err) {
                    // Keep the header even if streams fail; clear err so the whole import continues.
                    err = nil;
                    [track setPoints:[NSMutableArray array]];
                    [tracksOut addObject:track];

                    [rowPool drain];
                    continue;
                }

                NSArray *pts = PointsFromStreams(streams);
                NSMutableArray *mutablePts = [NSMutableArray arrayWithCapacity:pts.count];
                for (TrackPoint *tp in pts) [mutablePts addObject:tp];

                [track setPoints:mutablePts];
                [track fixupTrack];
                [tracksOut addObject:track];

                // Progress after each track (or you could move this to end-of-page)
                if (progressCopy) {
                     dispatch_async(dispatch_get_main_queue(), ^{ progressCopy(idx++, numActivities); });
                }

                [rowPool drain];
            }

            [pagePool drain];
        }

        // Finish on main
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionCopy) {
                NSArray *final = [[tracksOut copy] autorelease];
                completionCopy(final, err);
            }
            // Cleanup
            [tracksOut release];
            [sinceRetained release];
            if (progressCopy)   Block_release(progressCopy);
            if (completionCopy) Block_release(completionCopy);
        });
    });
}

@end
