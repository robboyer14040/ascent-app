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



// build an NSTimeZone from Strava fields
static NSTimeZone *StravaTimeZoneForActivity(NSDictionary *act, NSDate *startDate) {
    NSString *tzString = act[@"timezone"]; // e.g. "(GMT-08:00) America/Los_Angeles"
    NSTimeZone *tz = nil;

    if ([tzString isKindOfClass:NSString.class] && tzString.length) {
        NSRange r = [tzString rangeOfString:@") "];
        if (r.location != NSNotFound) {
            NSString *iana = [tzString substringFromIndex:NSMaxRange(r)];
            tz = [NSTimeZone timeZoneWithName:iana];
        }
    }
    if (!tz) {
        NSNumber *off = act[@"utc_offset"]; // seconds
        if ([off isKindOfClass:NSNumber.class]) {
            tz = [NSTimeZone timeZoneForSecondsFromGMT:off.intValue];
        }
    }
    return tz ?: [NSTimeZone localTimeZone];
}


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
    NSArray *tmp      = Safe(Safe(streamsByType[@"temp"])[@"data"]);            // °C
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


// Extract array of NSURLs from Strava "photos" field (detailed activity)
// Accepts either a dictionary with "primary"->"urls" map, or an array of items with "urls".
static NSArray<NSURL *> *ASCPhotoURLsFromStravaPhotos(id photosObj) {
    if (!photosObj) return [NSArray array];

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];

    // Case 1: {"count":N, "primary":{"id":...,"urls":{"100":"...","600":"...","2048":"..."}}}
    if ([photosObj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *photosDict = (NSDictionary *)photosObj;
        id primary = photosDict[@"primary"];
        if ([primary isKindOfClass:[NSDictionary class]]) {
            id urlMap = ((NSDictionary *)primary)[@"urls"];
            if ([urlMap isKindOfClass:[NSDictionary class]]) {
                NSDictionary *m = (NSDictionary *)urlMap;

                // Deterministic order: sort size keys numerically (e.g., "100","600","2048")
                NSArray *keys = [[m allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                    NSInteger ia = [a respondsToSelector:@selector(integerValue)] ? [a integerValue] : 0;
                    NSInteger ib = [b respondsToSelector:@selector(integerValue)] ? [b integerValue] : 0;
                    if (ia < ib) return NSOrderedAscending;
                    if (ia > ib) return NSOrderedDescending;
                    return NSOrderedSame;
                }];

                for (id k in keys) {
                    NSString *s = [m[k] isKindOfClass:[NSString class]] ? (NSString *)m[k] : nil;
                    if (s.length) {
                        NSURL *u = [NSURL URLWithString:s];
                        if (u) [urls addObject:u];
                    }
                }
            }
        }

        // Some variants put a flat URL at photos.primary (string) — be lenient:
        if (urls.count == 0 && [primary isKindOfClass:[NSString class]]) {
            NSURL *u = [NSURL URLWithString:(NSString *)primary];
            if (u) [urls addObject:u];
        }
    }

    // Case 2 (rare in this endpoint but harmless): array of photo dicts, each with "urls"
    if (urls.count == 0 && [photosObj isKindOfClass:[NSArray class]]) {
        for (id e in (NSArray *)photosObj) {
            if (![e isKindOfClass:[NSDictionary class]]) continue;
            id urlMap = ((NSDictionary *)e)[@"urls"];
            if (![urlMap isKindOfClass:[NSDictionary class]]) continue;
            for (id k in [(NSDictionary *)urlMap allKeys]) {
                NSString *s = [urlMap[k] isKindOfClass:[NSString class]] ? (NSString *)urlMap[k] : nil;
                if (s.length) {
                    NSURL *u = [NSURL URLWithString:s];
                    if (u) [urls addObject:u];
                }
            }
        }
    }

    return urls;
}



// ---- Strava API helpers -----------------------------------------------------

@interface StravaImporter ()
@property (nonatomic, retain) NSDictionary<NSString *, NSString *> *stravaGearMap;
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
        _stravaGearMap = nil;
        _accessToken = [accessToken copy];
    }
    return self;
}

- (void)dealloc {
    [_stravaGearMap release];
    _stravaGearMap = nil;
    [_accessToken release];
    [super dealloc];
}


// ---- Public entry: import everything into Track/TrackPoint ------------------

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
    StravaImportProgress   progressCopy   = [progress copy];
    StravaImportCompletion completionCopy = [completion copy];
    NSDate *sinceRetained = [since retain];

    const NSUInteger perPageEff  = perPage  ? perPage  : 50;
    const NSUInteger maxPagesEff = maxPages ? maxPages : 1;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *tracksOut = [[NSMutableArray alloc] init];
        NSError *err = nil; // long-lived error snapshot (retain from temps)
        
        // Before paging loop, still inside the background queue block:

        if (!self.stravaGearMap) {
            dispatch_semaphore_t gsem = dispatch_semaphore_create(0);

            [[StravaAPI shared] fetchGearMap:^(NSDictionary<NSString *,NSString *> * _Nullable gearByID,
                                               NSError * _Nullable error)
            {
                if (gearByID) {
                    // property should be (retain) under MRC
                    self.stravaGearMap = gearByID;
                } else if (error) {
                    NSLog(@"[Importer] Gear map fetch failed: %@", error);
                }
                dispatch_semaphore_signal(gsem);
            }];

            // Wait up to 10s so gear names are available to the importer immediately
            (void)dispatch_semaphore_wait(gsem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)));
        #if !OS_OBJECT_USE_OBJC
            dispatch_release(gsem);
        #endif
        }

        __block int idx = 0;
        for (NSUInteger page = 1; page <= maxPagesEff; page++) {
            NSAutoreleasePool *pagePool = [[NSAutoreleasePool alloc] init];

            // --- Fetch a page of summary activities (use temp error) ---
            NSError *pageErr = nil;
            NSArray *activities = [[StravaAPI shared] fetchActivitiesSince:sinceRetained
                                                                   perPage:perPageEff
                                                                      page:page
                                                                     error:&pageErr];
            if (pageErr) { [err release]; err = [pageErr retain]; }

            if (!activities) { [pagePool drain]; break; }
            NSUInteger numActivities = [activities count];
            if (numActivities == 0) { [pagePool drain]; break; }


            // --- For each activity, build a Track ---
            for (NSDictionary *act in activities) {
                NSAutoreleasePool *rowPool = [[NSAutoreleasePool alloc] init];

                // Track header (CREATE IT HERE)
                Track *track = [[[Track alloc] init] autorelease];

                // Strava id → uuid (string) + numeric id
                id actIDObj = Safe(act[@"id"]);
                NSString *uuid = actIDObj ? [[actIDObj description] copy] : nil;
                if (uuid) { [track setUuid:uuid]; [uuid release]; }
                NSNumber *actIDNum = ([actIDObj isKindOfClass:[NSNumber class]]
                                      ? (NSNumber *)actIDObj
                                      : (actIDObj ? [NSNumber numberWithLongLong:[[actIDObj description] longLongValue]] : nil));
                [track setStravaActivityID:actIDNum];
                
                // Name
                NSString *name = Safe(act[@"name"]);
                if (name) {
                    [track setName:name];
                    [track setAttribute:kName
                            usingString:name];

                }

                // Start date (UTC)
                NSString *startISO = Safe(act[@"start_date"]);
                NSDate *startDate = ISO8601ToDate(startISO);
                if (startDate) {
                    [track setCreationTime:startDate];

                    // Resolve the activity's local time zone
                    NSTimeZone *tz = StravaTimeZoneForActivity(act, startDate);

                    // Store both the zone id (for future formatting) and the offset at start time (DST-aware)
                    // Adjust these setters to match your Track API
                    if ([track respondsToSelector:@selector(setTimeZoneName:)]) {
                        [track setTimeZoneName:tz.name]; // e.g. "America/Los_Angeles"
                    }
                    if ([track respondsToSelector:@selector(setSecondsFromGMT:)]) {
                        NSInteger offset = [tz secondsFromGMTForDate:startDate];
                        [track setSecondsFromGMT:(int)offset];
                    }
                }
                
                // Distance (m → miles)
                NSNumber *distM = Safe(act[@"distance"]);
                if (distM) [track setDistance:([distM doubleValue] * kMToMi)];

                // ===================== NEW: src* fields from summary =====================
                // Distance (as reported by Strava, in miles)
                if (distM && [track respondsToSelector:@selector(setSrcDistance:)]) {
                    [track setSrcDistance:(float)([distM doubleValue] * kMToMi)];
                }

                // Speeds (m/s → mph)
                NSNumber *maxSpeedMps = Safe(act[@"max_speed"]);
                if (maxSpeedMps && [track respondsToSelector:@selector(setSrcMaxSpeed:)]) {
                    [track setSrcMaxSpeed:(float)([maxSpeedMps doubleValue] * kMPSToMPH)];
                }

                // Heart rate (bpm)
                NSNumber *avgHR = Safe(act[@"average_heartrate"]);
                if (avgHR && [track respondsToSelector:@selector(setSrcAvgHeartrate:)]) {
                    [track setSrcAvgHeartrate:[avgHR floatValue]];
                }
                NSNumber *maxHR = Safe(act[@"max_heartrate"]);
                if (maxHR && [track respondsToSelector:@selector(setSrcMaxHeartrate:)]) {
                    [track setSrcMaxHeartrate:[maxHR floatValue]];
                }

                // Temperature: Strava average_temp is °C → convert to °F to match UI/TrackPoint
                NSNumber *avgTempC = Safe(act[@"average_temp"]);
                if (avgTempC && [track respondsToSelector:@selector(setSrcAvgTemperature:)]) {
                    double f = [avgTempC doubleValue] * 9.0/5.0 + 32.0;
                    [track setSrcAvgTemperature:(float)f];
                }

                // Elevation highs/lows (meters → feet)
                NSNumber *elevHighM = Safe(act[@"elev_high"]);
                if (elevHighM && [track respondsToSelector:@selector(setSrcMaxElevation:)]) {
                    [track setSrcMaxElevation:(float)([elevHighM doubleValue] * kMToFt)];
                }
                NSNumber *elevLowM = Safe(act[@"elev_low"]);
                if (elevLowM && [track respondsToSelector:@selector(setSrcMinElevation:)]) {
                    [track setSrcMinElevation:(float)([elevLowM doubleValue] * kMToFt)];
                }

                // Total climb (meters → feet)
                NSNumber *totalGainM = Safe(act[@"total_elevation_gain"]);
                if (totalGainM && [track respondsToSelector:@selector(setSrcTotalClimb:)]) {
                    [track setSrcTotalClimb:(float)([totalGainM doubleValue] * kMToFt)];
                }

                // Power (watts)
                NSNumber *avgW = Safe(act[@"weighted_average_watts"]) ?: Safe(act[@"average_watts"]);
                if (avgW && [track respondsToSelector:@selector(setSrcAvgPower:)]) {
                    [track setSrcAvgPower:[avgW floatValue]];
                }
                NSNumber *maxW = Safe(act[@"max_watts"]);
                if (maxW && [track respondsToSelector:@selector(setSrcMaxPower:)]) {
                    [track setSrcMaxPower:[maxW floatValue]];
                }

                // Cadence (rpm)
                NSNumber *avgCad = Safe(act[@"average_cadence"]);
                if (avgCad && [track respondsToSelector:@selector(setSrcAvgCadence:)]) {
                    [track setSrcAvgCadence:[avgCad floatValue]];
                }

                // Energy (kJ)
                NSNumber *kJ = Safe(act[@"kilojoules"]);
                if (kJ && [track respondsToSelector:@selector(setSrcKilojoules:)]) {
                    [track setSrcKilojoules:[kJ floatValue]];
                }

                // Durations (seconds)
                NSNumber *elapsed = Safe(act[@"elapsed_time"]);
                if (elapsed && [track respondsToSelector:@selector(setSrcElapsedTime:)]) {
                    [track setSrcElapsedTime:[elapsed doubleValue]];
                }
                NSNumber *moving = Safe(act[@"moving_time"]);
                if (moving && [track respondsToSelector:@selector(setSrcMovingTime:)]) {
                    [track setSrcMovingTime:[moving doubleValue]];
                }
                // =================== end NEW: src* fields from summary ===================
                // Activity / Event type
                NSString *sportType = Safe(act[@"sport_type"]) ?: Safe(act[@"type"]);
                if (sportType) [track setAttribute:kActivity usingString:sportType];
                
                NSString *eventType = EventTypeStringFromWorkoutType(Safe(act[@"workout_type"]), sportType);
                if (eventType) [track setAttribute:kEventType usingString:eventType];

                NSString *loc = Safe(act[@"location_city"]);
                if (loc) [track setAttribute:kLocation usingString:loc];

                
                if (self.stravaGearMap)
                {
                    NSString* equip = Safe(act[@"gear_id"]);
                    if (equip)
                    {
                        equip = self.stravaGearMap[equip];
                        [track setAttribute:kEquipment
                                usingString:equip];
                    }
                }
                // ---- Notes / description + Photo URLs ----
                // Try summary first
                ///NSString *desc = Safe(act[@"description"]);
                NSArray<NSURL *> *photoURLs = nil;

                // Summary may include a "photos" object with a primary photo; harvest if present
                id photosSummaryObj = Safe(act[@"photos"]);
                NSArray<NSURL *> *urlsFromSummary = ASCPhotoURLsFromStravaPhotos(photosSummaryObj);
                if (urlsFromSummary.count) {
                    photoURLs = urlsFromSummary; // autoreleased; Track property will retain
                }

                [track fixupTrack];
                [tracksOut addObject:track];
                if (progressCopy) {
                    dispatch_async(dispatch_get_main_queue(), ^{ progressCopy(idx++, numActivities); });
                }


                [rowPool drain];
            }

            [pagePool drain];
        }

        // --- Snapshot results off-main ---
        NSArray *finalTracks = [tracksOut copy];  // +1
        NSError *finalError  = [err retain];      // +1 (nil-safe)

        // Clean up background objects
        [tracksOut release];
        [sinceRetained release];
        [err release];

        // --- Finish on main ---
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                if (completionCopy) {
                    completionCopy([finalTracks autorelease],
                                   [finalError  autorelease]);
                } else {
                    [finalTracks release];
                    [finalError  release];
                }
            } @catch (NSException *ex) {
                NSLog(@"Completion threw exception: %@\n%@", ex, [ex callStackSymbols]);
                @throw;
            }
            [progressCopy release];
            [completionCopy release];
        });
    });
}


// StravaImporter.m (or a helper). Call OFF-MAIN.
// Returns YES if it populated anything; NO on hard failure (and sets *outError).
// Async, safe from main thread
// StravaImporter.m  (MRC)

static inline NSString *SafeStr(id v) {
    return [v isKindOfClass:[NSString class]] ? (NSString *)v : nil;
}

static inline NSNumber *SafeNum(id v) {
    return [v isKindOfClass:[NSNumber class]] ? (NSNumber *)v : nil;
}

static NSArray<NSURL *> *ExtractPhotoURLs(NSArray<NSDictionary *> *photos) {
    if (![photos isKindOfClass:[NSArray class]] || photos.count == 0) return [NSArray array];
    NSMutableArray<NSURL *> *out = [NSMutableArray arrayWithCapacity:photos.count];
    for (NSDictionary *p in photos) {
        NSDictionary *urls = [p objectForKey:@"urls"]; // { "2048":"https://...", ... }
        NSString *direct   = SafeStr([p objectForKey:@"url"]);
        NSString *picked = nil;

        if ([urls isKindOfClass:[NSDictionary class]] && urls.count) {
            NSString *maxKey = nil;
            for (NSString *k in urls) {
                if (![k isKindOfClass:[NSString class]]) continue;
                if (!maxKey || k.integerValue > maxKey.integerValue) maxKey = k;
            }
            picked = SafeStr(urls[maxKey]);
        } else if (direct.length) {
            picked = direct;
        }
        if (picked.length) {
            NSURL *u = [NSURL URLWithString:picked];
            if (u) [out addObject:u];
        }
    }
    return out;
}

// Uses your existing: - (NSDictionary *)fetchStreamsForActivityID:(NSNumber *)actID error:(NSError **)outError
// and static NSArray *PointsFromStreams(NSDictionary *streamsByType)

- (void)enrichTrack:(Track *)track
    withSummaryDict:(NSDictionary * _Nullable )summary
       rootMediaURL:(NSURL*)mediaURL
        completion:(void (^)(NSError * _Nullable error))completion
{
    // Pull the Strava activity id from the Track (already present per your note)
    NSNumber *activityID = nil;
    if ([track respondsToSelector:@selector(stravaActivityID)]) {
        activityID = [track stravaActivityID];
    } else {
        @try { activityID = [track valueForKey:@"stravaActivityID"]; } @catch (__unused id e) {}
    }
    
    dispatch_queue_t workQ = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_async(workQ, ^{
        @autoreleasepool {
            __block NSDictionary *detail = nil;
            __block NSArray<NSDictionary *> *photosPayload = nil;
            __block NSError *firstError = nil;
            
            // Streams (sync on background queue)
            NSError *streamsErr = nil;
            __block NSDictionary *streamsByType = nil;
            if (activityID) {
                streamsByType = [[[StravaAPI shared] fetchStreamsForActivityID:activityID error:&streamsErr] retain];
                if (streamsErr && !firstError) firstError = [streamsErr retain];
            }
            
            // Detail + Photos (async, in parallel)
            dispatch_group_t g = dispatch_group_create();
            
            if (activityID) {
                dispatch_group_enter(g);
                [[StravaAPI shared] fetchActivityDetail:activityID completion:^(NSDictionary *a, NSError *e) {
                    if (a) detail = [a retain];
                    if (e && !firstError) firstError = [e retain];
                    dispatch_group_leave(g);
                }];
                
                dispatch_group_enter(g);
                [[StravaAPI shared] fetchPhotosForActivity:activityID
                                              rootMediaURL:mediaURL
                                                completion:^(NSArray<NSString *> * photoFilenames, NSError * error) {
                    track.localMediaItems = photoFilenames;
                    
                    dispatch_group_leave(g);
                }];
            }
            
            dispatch_group_notify(g, dispatch_get_main_queue(), ^{
                // Description: prefer summary, else detail
                NSString *desc = SafeStr(summary[@"description"]);
                if (!desc.length && detail) desc = SafeStr(detail[@"description"]);
                if (desc.length) {
                    if ([track respondsToSelector:@selector(setAttribute:usingString:)]) {
                        [track setAttribute:kNotes usingString:desc];
                    } else {
                        @try { [track setValue:desc forKey:@"notes"]; } @catch (__unused id e) {}
                    }
                }
 
                NSString* dev = SafeStr(detail[@"device_name"]);
                if (dev.length) {
                    if ([track respondsToSelector:@selector(setAttribute:usingString:)]) {
                        [track setAttribute:kComputer usingString:dev];
                    }
                }
                
                NSNumber* suffer = SafeNum(detail[@"suffer_score"]);
                if (suffer) {
                    if ([track respondsToSelector:@selector(setAttribute:usingString:)]) {
                        [track setAttribute:kSufferScore usingString:[suffer description]];
                    }
                }

                
                // Photos → Track.photoURLs
                if (photosPayload) {
                    NSArray<NSURL *> *urls = ExtractPhotoURLs(photosPayload);
                    if (urls.count) {
                        if ([track respondsToSelector:@selector(setPhotoURLs:)]) {
                            [track setPhotoURLs:urls];
                        } else {
                            @try { [track setValue:urls forKey:@"photoURLs"]; } @catch (__unused id e) {}
                        }
                    }
                    [photosPayload release]; photosPayload = nil;
                }
                
                
                
                // Streams → PointsFromStreams → Track.points
                if (streamsByType) {
                    // No wrapping needed; your fetch returns {type:{data:[…]}} (or we already normalized it).
                    NSArray *pts = PointsFromStreams(streamsByType);
                    if (pts.count) {
                        @try { [track setValue:pts forKey:@"points"]; } @catch (__unused id e) {}
                        if ([track respondsToSelector:@selector(fixupTrack)]) [track fixupTrack];
                    }
                    [streamsByType release]; streamsByType = nil;
                }
                
                if (detail) { [detail release]; detail = nil; }
                
                if (completion) completion(firstError);
                [firstError release];
            });
        }
    });
}





@end
