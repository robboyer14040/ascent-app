//
//  WeatherAPI.m
//  Ascent
//  MRC (non-ARC)
//

#import "WeatherAPI.h"
#import "Track.h"
#import "TrackPoint.h"

#pragma mark - Public keys / constants

NSString * const kWXSource      = @"Open-Meteo ERA5";
NSString * const kWXTempC       = @"temp_c";
NSString * const kWXWindKph     = @"wind_kph";
NSString * const kWXHumidityPct = @"humidity_pct";
NSString * const kWXPrecipMm    = @"precip_mm";
NSString * const kWXCode        = @"weather_code";
NSString * const kWXDesc        = @"weather_desc";
NSString * const kWXStartLocal  = @"start_local_iso8601";
NSString * const kWXEndLocal    = @"end_local_iso8601";
NSString * const kWXStartUTC    = @"start_utc_iso8601";
NSString * const kWXEndUTC      = @"end_utc_iso8601";
NSString * const kWXNumSamples  = @"num_samples";
NSString * const kWXTimeUTC     = @"time_utc";
NSString * const kWXTItems      = @"items";

// Container/geo keys (kept for callers that expect them here)
NSString * const kGeoStart = @"start";
NSString * const kGeoEnd   = @"end";
NSString * const kGeoCity        = @"city";
NSString * const kGeoCountry     = @"country";
NSString * const kGeoCountryCode = @"country_code";
NSString * const kGeoAdmin       = @"admin";
NSString * const kGeoLatitude    = @"lat";
NSString * const kGeoLongitude   = @"lon";

// Optional quick logging
//#define WXLOG(fmt, ...) NSLog((@"[WX] " fmt), ##__VA_ARGS__)

#pragma mark - Single work queue

static void *kWXQueueSpecificKey = &kWXQueueSpecificKey;

@implementation WeatherAPI

+ (dispatch_queue_t)_wxWorkQueue {
    static dispatch_queue_t q = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.montebello.weatherapi.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(q, kWXQueueSpecificKey, kWXQueueSpecificKey, NULL);
    });
    return q;
}

+ (BOOL)_onWXQueue {
    return (dispatch_get_specific(kWXQueueSpecificKey) == kWXQueueSpecificKey);
}

#pragma mark - Shared session & caches

+ (NSURLCache *)_sharedURLCache {
    static NSURLCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSURLCache alloc] initWithMemoryCapacity:20*1024*1024
                                              diskCapacity:100*1024*1024
                                                  diskPath:@"WeatherAPICache"];
    });
    return cache;
}

+ (NSURLSession *)_sharedURLSession {
    static NSURLSession *session = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        cfg.URLCache = [self _sharedURLCache];
        cfg.timeoutIntervalForRequest  = 12.0;
        cfg.timeoutIntervalForResource = 20.0;
        session = [[NSURLSession sessionWithConfiguration:cfg] retain];
    });
    return session;
}

// Process-wide hourly JSON blob cache (keyed by rounded lat/lon + day span)
+ (NSCache *)_hourlyCache {
    static NSCache *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        c = [[NSCache alloc] init];
        [c setCountLimit:400]; // tune if needed
    });
    return c;
}

+ (NSString *)_roundedCellKeyForLat:(double)lat lon:(double)lon startDay:(NSString *)sd endDay:(NSString *)ed {
    double rlat = floor(lat*20.0+0.5)/20.0;   // ~0.05°
    double rlon = floor(lon*20.0+0.5)/20.0;
    return [NSString stringWithFormat:@"%.2f|%.2f|%@|%@", rlat, rlon, sd ?: @"", ed ?: @""];
}

#pragma mark - Public sync APIs (queue-wrapped, MRC-safe)

+ (NSDictionary *)fetchWeatherForTrack:(Track *)track
                                 error:(NSError * _Nullable * _Nullable)outError
{
    __block NSDictionary *ret = nil;
    __block NSError *err = nil;

    if ([self _onWXQueue]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        ret = [[self _fetchWeatherForTrack_work:track error:&err] retain];
        if (err) [err retain];
        [pool drain];
    } else {
        dispatch_sync([self _wxWorkQueue], ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            ret = [[self _fetchWeatherForTrack_work:track error:&err] retain];
            if (err) [err retain];
            [pool drain];
        });
    }

    if (outError) *outError = [err autorelease];
    return [ret autorelease];
}

+ (NSArray *)fetchWeatherTimelineForTrack:(Track *)track
                                    error:(NSError * _Nullable * _Nullable)outError
{
    __block NSArray *ret = nil;
    __block NSError *err = nil;

    if ([self _onWXQueue]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        ret = [[self _fetchWeatherTimelineForTrack_work:track error:&err] retain];
        if (err) [err retain];
        [pool drain];
    } else {
        dispatch_sync([self _wxWorkQueue], ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            ret = [[self _fetchWeatherTimelineForTrack_work:track error:&err] retain];
            if (err) [err retain];
            [pool drain];
        });
    }

    if (outError) *outError = [err autorelease];
    return [ret autorelease];
}

#pragma mark - Hourly sampling helpers

static inline NSTimeInterval _ceilToHour(NSTimeInterval t)  { return ceil(t / 3600.0)  * 3600.0; }
static inline NSTimeInterval _floorToHour(NSTimeInterval t) { return floor(t / 3600.0) * 3600.0; }

+ (NSUInteger)_nearestValidIndex:(NSUInteger)target from:(NSArray<NSNumber*> *)validIdx
{
    NSUInteger n = [validIdx count];
    if (n == 0) return NSNotFound;
    NSUInteger lo = 0, hi = n;
    while (lo < hi) {
        NSUInteger mid = (lo + hi) >> 1;
        NSUInteger v = [[validIdx objectAtIndex:mid] unsignedIntegerValue];
        if (v < target) lo = mid + 1;
        else hi = mid;
    }
    if (lo == 0) return [[validIdx objectAtIndex:0] unsignedIntegerValue];
    if (lo == n) return [[validIdx objectAtIndex:n-1] unsignedIntegerValue];
    NSUInteger a = [[validIdx objectAtIndex:lo-1] unsignedIntegerValue];
    NSUInteger b = [[validIdx objectAtIndex:lo]   unsignedIntegerValue];
    return (labs((long)a - (long)target) <= labs((long)b - (long)target)) ? a : b;
}

+ (NSArray<NSDictionary*> *)_hourTargetsForTrackWithPoints:(NSArray *)pts
                                              validIndices:(NSArray<NSNumber*> *)validIdx
                                                  startUTC:(NSDate *)startUTC
                                                    endUTC:(NSDate *)endUTC
{
    NSMutableArray *targets = [NSMutableArray array];
    NSTimeInterval s = [startUTC timeIntervalSince1970];
    NSTimeInterval e = [endUTC   timeIntervalSince1970];
    if (e < s) e = s;

    // Choose hour marks inside the activity window; ensure at least one sample
    NSTimeInterval hStart = _ceilToHour(s);
    NSTimeInterval hEnd   = _floorToHour(e);
    if (hEnd < hStart) { hStart = _floorToHour(s); hEnd = hStart; }

    NSUInteger N = [pts count];
    if (N == 0) return [NSArray array];

    for (NSTimeInterval t = hStart; t <= hEnd; t += 3600.0) {
        double f = (e > s ? ((t - s) / (e - s)) : 0.0);
        if (f < 0) f = 0; if (f > 1) f = 1;
        NSUInteger rawIdx = (NSUInteger)llround(f * (double)(N - 1));
        NSUInteger pick = [self _nearestValidIndex:rawIdx from:validIdx];
        if (pick == NSNotFound) continue;

        NSDate *hourDate = [NSDate dateWithTimeIntervalSince1970:t];
        [targets addObject:@{ @"idx": [NSNumber numberWithUnsignedInteger:pick],
                              @"date": hourDate }];
    }
    return targets;
}

#pragma mark - Core work (one sample per hour, de-duped per location)

+ (NSDictionary *)_fetchWeatherForTrack_work:(Track *)track
                                       error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2001
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    NSDate *startUTC = [track creationTime];
    if (![startUTC isKindOfClass:[NSDate class]]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2002
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track.creationTime missing/invalid"}];
        return nil;
    }
    NSTimeInterval duration = [track duration];
    if (duration <= 0) duration = 3600.0;
    NSDate *endUTC = [NSDate dateWithTimeInterval:duration sinceDate:startUTC];

    int secondsFromGMT = [track secondsFromGMT];
    NSDate *startLocal = [NSDate dateWithTimeInterval:secondsFromGMT sinceDate:startUTC];
    NSDate *endLocal   = [NSDate dateWithTimeInterval:secondsFromGMT sinceDate:endUTC];

    NSArray *pts = [track points];
    if (![pts isKindOfClass:[NSArray class]] || [pts count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2003
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track has no points"}];
        return nil;
    }

    // Valid indices (sorted)
    NSMutableArray *validIdx = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0, n = [pts count]; i < n; i++) {
        TrackPoint *p = [pts objectAtIndex:i];
        if (![p isKindOfClass:[TrackPoint class]]) continue;
        float lat = [p latitude], lon = [p longitude];
        if ([p validLatLon] && isfinite(lat) && isfinite(lon) &&
            fabsf(lat) <= 90.0f && fabsf(lon) <= 180.0f &&
            !(lat == 0.0f && lon == 0.0f)) {
            [validIdx addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }
    if ([validIdx count] == 0) {
        [validIdx release];
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2004
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No valid lat/lon points in Track"}];
        return nil;
    }

    NSString *startDay = [self _ymdUTC:startUTC];
    NSString *endDay   = [self _ymdUTC:endUTC];

    NSArray<NSDictionary*> *targets = [self _hourTargetsForTrackWithPoints:pts
                                                              validIndices:validIdx
                                                                  startUTC:startUTC
                                                                    endUTC:endUTC];
    [validIdx release];

    if ([targets count] == 0) {
        targets = @[ @{@"idx": [NSNumber numberWithUnsignedInteger:0], @"date": startUTC} ];
    }

    // Per-call small dict cache (rounded cell → hourly dict)
    NSMutableDictionary *dictCache = [[NSMutableDictionary alloc] init];
    NSDateFormatter *hourFmt = [self _isoHourUTCFormatter];

    // accumulators
    double sumTemp = 0, sumWindKph = 0, sumHum = 0, sumPrec = 0;
    NSUInteger tempN = 0, humN = 0, windN = 0;
    NSMutableDictionary *wmoCounts = [[NSMutableDictionary alloc] init];

    for (NSDictionary *t in targets) {
        NSUInteger idx = [[t objectForKey:@"idx"] unsignedIntegerValue];
        NSDate *hourDate = [t objectForKey:@"date"];
        NSString *hourStr = [hourFmt stringFromDate:hourDate];

        TrackPoint *p = [pts objectAtIndex:idx];
        double lat = (double)[p latitude], lon = (double)[p longitude];

        NSString *cellKey = [self _roundedCellKeyForLat:lat lon:lon startDay:startDay endDay:endDay];
        NSDictionary *hourlyDict = [dictCache objectForKey:cellKey];
        if (!hourlyDict) {
            // Check process-wide cache first
            hourlyDict = [[self _hourlyCache] objectForKey:cellKey];
            if (!hourlyDict) {
                NSError *fetchErr = nil;
                hourlyDict = [self _fetchERA5HourlyForLat:lat lon:lon startDay:startDay endDay:endDay error:&fetchErr];
                if (!hourlyDict) continue;
                [[self _hourlyCache] setObject:hourlyDict forKey:cellKey];
            }
            [dictCache setObject:hourlyDict forKey:cellKey];
        }

        NSArray *times = [hourlyDict objectForKey:@"time"];
        if (![times isKindOfClass:[NSArray class]]) continue;

        NSUInteger i = [times indexOfObject:hourStr];
        if (i == NSNotFound) continue;

        NSArray *tC    = [hourlyDict objectForKey:@"temperature_2m"];
        NSArray *rh    = [hourlyDict objectForKey:@"relative_humidity_2m"];
        NSArray *prec  = [hourlyDict objectForKey:@"precipitation"];
        NSArray *wind  = [hourlyDict objectForKey:@"windspeed_10m"];
        NSArray *wcode = [hourlyDict objectForKey:@"weathercode"];

        id vT = (i < [tC count]   ? [tC objectAtIndex:i]   : nil);
        id vH = (i < [rh count]   ? [rh objectAtIndex:i]   : nil);
        id vP = (i < [prec count] ? [prec objectAtIndex:i] : nil);
        id vW = (i < [wind count] ? [wind objectAtIndex:i] : nil);
        id vC = (i < [wcode count]? [wcode objectAtIndex:i]: nil);

        if ([vT respondsToSelector:@selector(doubleValue)]) { sumTemp += [vT doubleValue]; tempN++; }
        if ([vH respondsToSelector:@selector(doubleValue)]) { sumHum  += [vH doubleValue]; humN++;  }
        if ([vP respondsToSelector:@selector(doubleValue)]) { sumPrec += [vP doubleValue];          }
        if ([vW respondsToSelector:@selector(doubleValue)]) { sumWindKph += ([vW doubleValue] * 3.6); windN++; }

        if ([vC respondsToSelector:@selector(intValue)]) {
            int wc = [vC intValue];
            NSNumber *key = [NSNumber numberWithInt:wc];
            NSNumber *cnt = [wmoCounts objectForKey:key];
            NSInteger newCnt = (cnt ? [cnt integerValue] : 0) + 1;
            [wmoCounts setObject:[NSNumber numberWithInteger:newCnt] forKey:key];
        }
    }

    [dictCache release];

    double avgT   = (tempN > 0 ? (sumTemp    / (double)tempN) : NAN);
    double avgHum = (humN  > 0 ? (sumHum     / (double)humN)  : NAN);
    double avgW   = (windN > 0 ? (sumWindKph / (double)windN) : NAN);

    NSInteger numHours = (NSInteger)[targets count];
    double avgPrec = (numHours > 0 ? (sumPrec / (double)numHours) : NAN);

    int modalCode = -1; NSInteger modalCount = 0;
    for (NSNumber *code in wmoCounts) {
        NSInteger c = [[wmoCounts objectForKey:code] integerValue];
        if (c > modalCount) { modalCount = c; modalCode = [code intValue]; }
    }
    [wmoCounts release];

    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setObject:kWXSource forKey:kWXSource];
    if (!isnan(avgT))   [result setObject:[NSNumber numberWithDouble:avgT]    forKey:kWXTempC];
    if (!isnan(avgW))   [result setObject:[NSNumber numberWithDouble:avgW]    forKey:kWXWindKph];
    if (!isnan(avgHum)) [result setObject:[NSNumber numberWithDouble:avgHum]  forKey:kWXHumidityPct];
    if (!isnan(avgPrec))[result setObject:[NSNumber numberWithDouble:avgPrec] forKey:kWXPrecipMm];

    if (modalCode >= 0) {
        [result setObject:[NSNumber numberWithInt:modalCode] forKey:kWXCode];
        NSString *desc = [self _descForWMO:modalCode];
        if (desc) [result setObject:desc forKey:kWXDesc];
    }

    [result setObject:[self _isoFullLocal:startLocal] forKey:kWXStartLocal];
    [result setObject:[self _isoFullLocal:endLocal]   forKey:kWXEndLocal];
    [result setObject:[self _isoFullUTC:startUTC]     forKey:kWXStartUTC];
    [result setObject:[self _isoFullUTC:endUTC]       forKey:kWXEndUTC];
    [result setObject:[NSNumber numberWithInteger:numHours] forKey:kWXNumSamples];

    return [result autorelease];
}

+ (NSArray *)_fetchWeatherTimelineForTrack_work:(Track *)track
                                          error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3001
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    NSDate *startUTC = [track creationTime];
    if (![startUTC isKindOfClass:[NSDate class]]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3002
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track.creationTime missing/invalid"}];
        return nil;
    }

    NSTimeInterval duration = [track duration];
    if (duration <= 0) duration = 3600.0;
    NSDate *endUTC = [NSDate dateWithTimeInterval:duration sinceDate:startUTC];

    NSArray *pts = [track points];
    if (![pts isKindOfClass:[NSArray class]] || [pts count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3003
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track has no points"}];
        return nil;
    }

    // Valid indices (sorted)
    NSMutableArray *validIdx = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0, n = [pts count]; i < n; i++) {
        TrackPoint *p = [pts objectAtIndex:i];
        if (![p isKindOfClass:[TrackPoint class]]) continue;
        float lat = [p latitude], lon = [p longitude];
        if ([p validLatLon] && isfinite(lat) && isfinite(lon) &&
            fabsf(lat) <= 90.0f && fabsf(lon) <= 180.0f &&
            !(lat == 0.0f && lon == 0.0f)) {
            [validIdx addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }
    if ([validIdx count] == 0) {
        [validIdx release];
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3004
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No valid lat/lon points in Track"}];
        return nil;
    }

    NSString *startDay = [self _ymdUTC:startUTC];
    NSString *endDay   = [self _ymdUTC:endUTC];

    NSArray<NSDictionary*> *targets = [self _hourTargetsForTrackWithPoints:pts
                                                              validIndices:validIdx
                                                                  startUTC:startUTC
                                                                    endUTC:endUTC];
    [validIdx release];

    if ([targets count] == 0) {
        targets = @[ @{@"idx": [NSNumber numberWithUnsignedInteger:0], @"date": startUTC} ];
    }

    NSMutableDictionary *dictCache = [[NSMutableDictionary alloc] init];
    NSMutableArray *timeline = [[NSMutableArray alloc] initWithCapacity:[targets count]];
    NSDateFormatter *hourFmt = [self _isoHourUTCFormatter];

    for (NSDictionary *t in targets) {
        NSUInteger idx = [[t objectForKey:@"idx"] unsignedIntegerValue];
        NSDate *hourDate = [t objectForKey:@"date"];
        NSString *hourStr = [hourFmt stringFromDate:hourDate];

        TrackPoint *p = [pts objectAtIndex:idx];
        double lat = (double)[p latitude], lon = (double)[p longitude];

        NSString *cellKey = [self _roundedCellKeyForLat:lat lon:lon startDay:startDay endDay:endDay];
        NSDictionary *hourlyDict = [dictCache objectForKey:cellKey];
        if (!hourlyDict) {
            hourlyDict = [[self _hourlyCache] objectForKey:cellKey];
            if (!hourlyDict) {
                NSError *fetchErr = nil;
                hourlyDict = [self _fetchERA5HourlyForLat:lat lon:lon startDay:startDay endDay:endDay error:&fetchErr];
                if (!hourlyDict) continue;
                [[self _hourlyCache] setObject:hourlyDict forKey:cellKey];
            }
            [dictCache setObject:hourlyDict forKey:cellKey];
        }

        NSArray *times = [hourlyDict objectForKey:@"time"];
        if (![times isKindOfClass:[NSArray class]]) continue;
        NSUInteger i = [times indexOfObject:hourStr];
        if (i == NSNotFound) continue;

        NSArray *tC    = [hourlyDict objectForKey:@"temperature_2m"];
        NSArray *rh    = [hourlyDict objectForKey:@"relative_humidity_2m"];
        NSArray *prec  = [hourlyDict objectForKey:@"precipitation"];
        NSArray *wind  = [hourlyDict objectForKey:@"windspeed_10m"];
        NSArray *wcode = [hourlyDict objectForKey:@"weathercode"];

        NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:6];
        [row setObject:[NSString stringWithFormat:@"%@:00Z", hourStr] forKey:kWXTimeUTC];

        id vT = (i < [tC count]   ? [tC objectAtIndex:i]   : nil);
        id vH = (i < [rh count]   ? [rh objectAtIndex:i]   : nil);
        id vP = (i < [prec count] ? [prec objectAtIndex:i] : nil);
        id vW = (i < [wind count] ? [wind objectAtIndex:i] : nil);
        id vC = (i < [wcode count]? [wcode objectAtIndex:i]: nil);

        if ([vT respondsToSelector:@selector(doubleValue)]) [row setObject:[NSNumber numberWithDouble:[vT doubleValue]] forKey:kWXTempC];
        if ([vW respondsToSelector:@selector(doubleValue)]) [row setObject:[NSNumber numberWithDouble:([vW doubleValue]*3.6)] forKey:kWXWindKph];
        if ([vH respondsToSelector:@selector(doubleValue)]) [row setObject:[NSNumber numberWithDouble:[vH doubleValue]] forKey:kWXHumidityPct];
        if ([vP respondsToSelector:@selector(doubleValue)]) [row setObject:[NSNumber numberWithDouble:[vP doubleValue]] forKey:kWXPrecipMm];
        if ([vC respondsToSelector:@selector(intValue)])    [row setObject:[NSNumber numberWithInt:[vC intValue]] forKey:kWXCode];

        [timeline addObject:row];
    }

    [dictCache release];
    return [timeline autorelease];
}

#pragma mark - Networking (shared session + process cache)

+ (NSDictionary *)_fetchERA5HourlyForLat:(double)lat
                                      lon:(double)lon
                                 startDay:(NSString *)startDay
                                   endDay:(NSString *)endDay
                                    error:(NSError * _Nullable * _Nullable)outError
{
    // Build ERA5 request (archive API; timezone=UTC)
    NSString *hourlyVars = @"temperature_2m,relative_humidity_2m,precipitation,windspeed_10m,weathercode";
    NSMutableString *urlStr = [[NSMutableString alloc] initWithFormat:
       @"https://archive-api.open-meteo.com/v1/era5?latitude=%.6f&longitude=%.6f&hourly=%@&start_date=%@&end_date=%@&timezone=UTC",
       lat, lon, hourlyVars, startDay, endDay];

    NSURL *url = [NSURL URLWithString:urlStr];
    [urlStr release];
    if (!url) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2101
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Invalid ERA5 URL"}];
        return nil;
    }

    __block NSData *resp = nil;
    __block NSError *reqErr = nil;

    NSURLSession *session = [self _sharedURLSession];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:url
           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
               if (error) reqErr = [error retain]; else resp = [data retain];
               dispatch_semaphore_signal(sem);
           }];
    [task resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if (reqErr) {
        if (outError) *outError = [reqErr autorelease];
        return nil;
    }
    if (!resp) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2102
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Empty ERA5 response"}];
        return nil;
    }

    NSError *jsonErr = nil;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:resp options:0 error:&jsonErr];
    [resp release];

    if (jsonErr || ![root isKindOfClass:[NSDictionary class]]) {
        if (outError) *outError = (jsonErr
            ? [jsonErr autorelease]
            : [NSError errorWithDomain:@"WeatherAPI" code:2103
                               userInfo:@{NSLocalizedDescriptionKey:@"Invalid ERA5 JSON"}]);
        return nil;
    }

    NSDictionary *hourlyDict = [root objectForKey:@"hourly"];
    BOOL haveERA = [hourlyDict isKindOfClass:[NSDictionary class]];

    // Heuristic: if ERA5 looks bad, fallback to forecast API for same day window
    BOOL mostlyNulls = NO;
    if (haveERA) {
        NSArray *keys = [NSArray arrayWithObjects:@"temperature_2m", @"relative_humidity_2m",
                                               @"precipitation", @"windspeed_10m", @"weathercode", nil];
        for (NSString *k in keys) {
            NSArray *arr = [hourlyDict objectForKey:k];
            if (![arr isKindOfClass:[NSArray class]]) { mostlyNulls = YES; break; }
            NSUInteger n = [arr count], nulls = 0;
            for (id v in arr) if (v == (id)[NSNull null]) nulls++;
            if (n > 0 && nulls > (n / 2)) { mostlyNulls = YES; break; }
        }
    }

    if (!haveERA || mostlyNulls) {
        // Forecast fallback (timezone=UTC). We keep day window; we’ll pick exact hours client-side.
        NSMutableString *fURL = [[NSMutableString alloc] initWithFormat:
           @"https://api.open-meteo.com/v1/forecast?latitude=%.6f&longitude=%.6f&hourly=%@&start_date=%@&end_date=%@&timezone=UTC",
           lat, lon, hourlyVars, startDay, endDay];

        NSURL *urlF = [NSURL URLWithString:fURL];
        [fURL release];

        if (urlF) {
            __block NSData *respF = nil;
            __block NSError *errF = nil;

            NSURLSession *sessionF = [self _sharedURLSession];

            dispatch_semaphore_t semF = dispatch_semaphore_create(0);
            NSURLSessionDataTask *taskF =
            [sessionF dataTaskWithURL:urlF
                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                         if (error) errF = [error retain]; else respF = [data retain];
                         dispatch_semaphore_signal(semF);
                     }];
            [taskF resume];
            dispatch_semaphore_wait(semF, DISPATCH_TIME_FOREVER);

            if (!errF && respF) {
                NSError *jsonErrF = nil;
                NSDictionary *rootF = [NSJSONSerialization JSONObjectWithData:respF options:0 error:&jsonErrF];
                [respF release];
                if (!jsonErrF && [rootF isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *hourlyF = [rootF objectForKey:@"hourly"];
                    if ([hourlyF isKindOfClass:[NSDictionary class]]) {
                        return hourlyF; // prefer forecast if it parsed fine
                    }
                }
            } else {
                if (errF) [errF release]; // ignore; fall through to ERA result if any
            }
        }
    }

    if (!haveERA) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2104
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Missing 'hourly' section"}];
        return nil;
    }
    return hourlyDict;
}

#pragma mark - Date formatting

+ (NSDateFormatter *)_isoHourUTCFormatter {
    static NSDateFormatter *f = nil;
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        [f setDateFormat:@"yyyy-MM-dd'T'HH:mm"];
        [f setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    }
    return f;
}

+ (NSDateFormatter *)_isoFullUTCFormatter {
    static NSDateFormatter *f = nil;
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        [f setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [f setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    }
    return f;
}

+ (NSDateFormatter *)_isoFullLocalFormatter {
    static NSDateFormatter *f = nil;
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        // No 'Z' suffix; the date passed is already shifted by secondsFromGMT.
        [f setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
        [f setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    }
    return f;
}

+ (NSString *)_isoFullUTC:(NSDate *)d {
    return [[self _isoFullUTCFormatter] stringFromDate:d];
}

+ (NSString *)_isoFullLocal:(NSDate *)dLocalAlreadyShifted {
    return [[self _isoFullLocalFormatter] stringFromDate:dLocalAlreadyShifted];
}

+ (NSString *)_ymdUTC:(NSDate *)d {
    static NSDateFormatter *f = nil;
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        [f setDateFormat:@"yyyy-MM-dd"];
        [f setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    }
    return [f stringFromDate:d];
}

#pragma mark - WMO mapping

+ (NSString *)_descForWMO:(int)code {
    switch (code) {
        case 0:  return @"Clear";
        case 1:  return @"Mainly clear";
        case 2:  return @"Partly cloudy";
        case 3:  return @"Overcast";
        case 45: return @"Fog";
        case 48: return @"Depositing rime fog";
        case 51: return @"Drizzle: light";
        case 53: return @"Drizzle: moderate";
        case 55: return @"Drizzle: dense";
        case 61: return @"Rain: slight";
        case 63: return @"Rain: moderate";
        case 65: return @"Rain: heavy";
        case 66: return @"Freezing rain: light";
        case 67: return @"Freezing rain: heavy";
        case 71: return @"Snow: slight";
        case 73: return @"Snow: moderate";
        case 75: return @"Snow: heavy";
        case 77: return @"Snow grains";
        case 80: return @"Rain showers: slight";
        case 81: return @"Rain showers: moderate";
        case 82: return @"Rain showers: violent";
        case 85: return @"Snow showers: slight";
        case 86: return @"Snow showers: heavy";
        case 95: return @"Thunderstorm";
        case 96: return @"Thunderstorm with slight hail";
        case 99: return @"Thunderstorm with heavy hail";
        default: return [NSString stringWithFormat:@"WMO %d", code];
    }
}

+ (NSString *)stringForWeatherCode:(NSInteger)code {
    return [self _descForWMO:(int)code];
}

@end

