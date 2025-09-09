//
//  WeatherAPI.m
//  Ascent
//  MRC (non-ARC)
//

#import "WeatherAPI.h"
#import "Track.h"
#import "TrackPoint.h"

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
NSString * const kWXTimeUTC   = @"time_utc";
NSString * const kWXTItems    = @"items";


@implementation WeatherAPI

#pragma mark - Public

+ (NSDictionary *)fetchWeatherForTrack:(Track *)track
                                 error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2001
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track is nil"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    NSDate *creationUTC = [track creationTime];
    if (![creationUTC isKindOfClass:[NSDate class]]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2002
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track.creationTime missing/invalid"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    int secondsFromGMT = [track secondsFromGMT];
    NSTimeInterval duration = [track duration];
    if (duration <= 0) duration = 3600.0;

    NSDate *startUTC = creationUTC;
    NSDate *endUTC   = [NSDate dateWithTimeInterval:duration sinceDate:startUTC];

    NSDate *startLocal = [NSDate dateWithTimeInterval:secondsFromGMT sinceDate:startUTC];
    NSDate *endLocal   = [NSDate dateWithTimeInterval:secondsFromGMT sinceDate:endUTC];

    NSArray *pts = [track points];
    if (![pts isKindOfClass:[NSArray class]] || [pts count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2003
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track has no points"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    // Gather valid lat/lon indices
    NSMutableArray *validIdx = [[NSMutableArray alloc] init];
    NSUInteger N = [pts count];
    for (NSUInteger i = 0; i < N; i++) {
        TrackPoint *p = [pts objectAtIndex:i];
        if (![p isKindOfClass:[TrackPoint class]]) continue;
        float lat = [p latitude];
        float lon = [p longitude];
        BOOL ok = [p validLatLon] && isfinite(lat) && isfinite(lon) &&
                  (fabs(lat) <= 90.0f) && (fabs(lon) <= 180.0f) &&
                  !(lat == 0.0f && lon == 0.0f);
        if (ok) [validIdx addObject:[NSNumber numberWithUnsignedInteger:i]];
    }

    if ([validIdx count] == 0) {
        [validIdx release];
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2004
                                                  userInfo:[NSDictionary dictionaryWithObject:@"No valid lat/lon points in Track"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    const NSUInteger kMaxSamples = 8;
    NSArray *sampleIndices = [self _evenlySpacedIndicesFromArray:validIdx maxCount:kMaxSamples];
    [validIdx release];

    // Time window for weather query (UTC) with ±1h buffer
    NSDate *queryStartUTC = [startUTC dateByAddingTimeInterval:-3600.0];
    NSDate *queryEndUTC   = [endUTC   dateByAddingTimeInterval: 3600.0];
    NSString *startDay = [self _ymdUTC:queryStartUTC];
    NSString *endDay   = [self _ymdUTC:queryEndUTC];

    // Accumulators
    double sumTemp = 0, sumWindKph = 0, sumHum = 0, sumPrec = 0;
    NSInteger totalHourlySamples = 0;
    NSMutableDictionary *wmoCounts = [[NSMutableDictionary alloc] init];

    for (NSNumber *idxNum in sampleIndices) {
        NSUInteger idx = [idxNum unsignedIntegerValue];
        TrackPoint *p = [pts objectAtIndex:idx];
        double lat = (double)[p latitude];
        double lon = (double)[p longitude];

        NSDictionary *hourlyDict = [self _fetchERA5HourlyForLat:lat
                                                             lon:lon
                                                        startDay:startDay
                                                          endDay:endDay
                                                           error:outError];
        if (!hourlyDict) continue;

        NSArray *times = [hourlyDict objectForKey:@"time"];
        NSArray *tC    = [hourlyDict objectForKey:@"temperature_2m"];
        NSArray *rh    = [hourlyDict objectForKey:@"relative_humidity_2m"];
        NSArray *prec  = [hourlyDict objectForKey:@"precipitation"];
        NSArray *wind  = [hourlyDict objectForKey:@"windspeed_10m"];
        NSArray *wcode = [hourlyDict objectForKey:@"weathercode"];
        if (![times isKindOfClass:[NSArray class]] ||
            ![tC isKindOfClass:[NSArray class]] ||
            ![rh isKindOfClass:[NSArray class]] ||
            ![prec isKindOfClass:[NSArray class]] ||
            ![wind isKindOfClass:[NSArray class]] ||
            ![wcode isKindOfClass:[NSArray class]]) {
            continue;
        }

        NSDateFormatter *hourFmt = [self _isoHourUTCFormatter];
        NSTimeInterval sTI = [startUTC timeIntervalSince1970];
        NSTimeInterval eTI = [endUTC timeIntervalSince1970];

        for (NSUInteger i = 0, m = [times count]; i < m; i++) {
            NSString *ts = [times objectAtIndex:i];
            NSDate *d = [hourFmt dateFromString:ts];
            if (!d) continue;
            NSTimeInterval ti = [d timeIntervalSince1970];
            if (ti < floor(sTI - 0.5) || ti > ceil(eTI + 0.5)) continue;

            double t  = [[tC objectAtIndex:i]   respondsToSelector:@selector(doubleValue)] ? [[tC objectAtIndex:i]   doubleValue] : NAN;
            double h  = [[rh objectAtIndex:i]   respondsToSelector:@selector(doubleValue)] ? [[rh objectAtIndex:i]   doubleValue] : NAN;
            double pr = [[prec objectAtIndex:i] respondsToSelector:@selector(doubleValue)] ? [[prec objectAtIndex:i] doubleValue] : NAN;
            double w  = [[wind objectAtIndex:i] respondsToSelector:@selector(doubleValue)] ? [[wind objectAtIndex:i] doubleValue] : NAN;
            int    wc = [[wcode objectAtIndex:i] respondsToSelector:@selector(intValue)]   ? [[wcode objectAtIndex:i] intValue]    : -1;

            if (!isnan(t))  sumTemp    += t;
            if (!isnan(h))  sumHum     += h;
            if (!isnan(pr)) sumPrec    += pr;         // precip: total over hours; will average over spatial samples later
            if (!isnan(w))  sumWindKph += (w * 3.6);  // m/s -> km/h

            totalHourlySamples++;

            NSNumber *key = [NSNumber numberWithInt:wc];
            NSNumber *cnt = [wmoCounts objectForKey:key];
            NSInteger newCnt = (cnt ? [cnt integerValue] : 0) + 1;
            [wmoCounts setObject:[NSNumber numberWithInteger:newCnt] forKey:key];
        }
    }

    double avgT   = (totalHourlySamples > 0 ? (sumTemp    / (double)totalHourlySamples) : NAN);
    double avgHum = (totalHourlySamples > 0 ? (sumHum     / (double)totalHourlySamples) : NAN);
    double avgW   = (totalHourlySamples > 0 ? (sumWindKph / (double)totalHourlySamples) : NAN);

    NSInteger numSpatial = (NSInteger)[sampleIndices count];
    double totPrec = (numSpatial > 0 ? (sumPrec / (double)numSpatial) : NAN);

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
    if (!isnan(totPrec))[result setObject:[NSNumber numberWithDouble:totPrec] forKey:kWXPrecipMm];

    if (modalCode >= 0) {
        [result setObject:[NSNumber numberWithInt:modalCode] forKey:kWXCode];
        NSString *desc = [self _descForWMO:modalCode];
        if (desc) [result setObject:desc forKey:kWXDesc];
    }

    [result setObject:[self _isoFullLocal:startLocal] forKey:kWXStartLocal];
    [result setObject:[self _isoFullLocal:endLocal]   forKey:kWXEndLocal];
    [result setObject:[self _isoFullUTC:startUTC]     forKey:kWXStartUTC];
    [result setObject:[self _isoFullUTC:endUTC]       forKey:kWXEndUTC];
    [result setObject:[NSNumber numberWithInteger:numSpatial] forKey:kWXNumSamples];

    return [result autorelease];
}

#pragma mark - Networking

+ (NSDictionary *)_fetchERA5HourlyForLat:(double)lat
                                      lon:(double)lon
                                 startDay:(NSString *)startDay
                                   endDay:(NSString *)endDay
                                    error:(NSError * _Nullable * _Nullable)outError
{
    // Query variables string (avoid name clash with the JSON 'hourly' dict)
    NSString *hourlyVars = @"temperature_2m,relative_humidity_2m,precipitation,windspeed_10m,weathercode";

    NSMutableString *urlStr = [[NSMutableString alloc] initWithFormat:
        @"https://archive-api.open-meteo.com/v1/era5?latitude=%.6f&longitude=%.6f&hourly=%@&start_date=%@&end_date=%@&timezone=UTC",
        lat, lon, hourlyVars, startDay, endDay];

    NSURL *url = [NSURL URLWithString:urlStr];
    [urlStr release];
    if (!url) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2101
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Invalid URL"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    __block NSData *resp = nil;
    __block NSError *reqErr = nil;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:url
           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
               if (error) reqErr = [error retain]; else resp = [data retain];
               dispatch_semaphore_signal(sem);
           }];
    [task resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    [session invalidateAndCancel];

    if (reqErr) {
        if (outError) *outError = [reqErr autorelease];
        return nil;
    }
    if (!resp) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2102
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Empty weather response"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    NSError *jsonErr = nil;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:resp options:0 error:&jsonErr];
    [resp release];

    if (jsonErr || ![root isKindOfClass:[NSDictionary class]]) {
        if (outError) *outError = (jsonErr
            ? [jsonErr autorelease]
            : [NSError errorWithDomain:@"WeatherAPI" code:2103
                               userInfo:[NSDictionary dictionaryWithObject:@"Invalid JSON"
                                                                    forKey:NSLocalizedDescriptionKey]]);
        return nil;
    }

    NSDictionary *hourlyDict = [root objectForKey:@"hourly"];
    if (![hourlyDict isKindOfClass:[NSDictionary class]]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:2104
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Missing 'hourly' section"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    return hourlyDict;
}

#pragma mark - Sampling helpers

+ (NSArray *)_evenlySpacedIndicesFromArray:(NSArray<NSNumber*> *)indices
                                  maxCount:(NSUInteger)maxCount
{
    NSUInteger count = [indices count];
    if (count == 0) return [NSArray array];
    if (count <= maxCount) return [NSArray arrayWithArray:indices];

    NSMutableArray *out = [[NSMutableArray alloc] initWithCapacity:maxCount];
    double step = (double)(count - 1) / (double)(maxCount - 1);
    for (NSUInteger i = 0; i < maxCount; i++) {
        NSUInteger idx = (NSUInteger)llround(i * step);
        if (idx >= count) idx = count - 1;
        [out addObject:[indices objectAtIndex:idx]];
    }
    NSArray *ret = [NSArray arrayWithArray:out];
    [out release];
    return ret;
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
        case 48: return @"Rime fog";
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
        case 96: return @"TS w/ slight hail";
        case 99: return @"TS w/ heavy hail";
        default: return [NSString stringWithFormat:@"WMO %d", code];
    }
}


+ (NSArray *)fetchWeatherTimelineForTrack:(Track *)track
                                    error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3001
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track is nil"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    NSDate *startUTC = [track creationTime];
    if (![startUTC isKindOfClass:[NSDate class]]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3002
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track.creationTime missing/invalid"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    NSTimeInterval duration = [track duration];
    if (duration <= 0) duration = 3600.0;
    NSDate *endUTC = [NSDate dateWithTimeInterval:duration sinceDate:startUTC];

    NSArray *pts = [track points];
    if (![pts isKindOfClass:[NSArray class]] || [pts count] == 0) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3003
                                                  userInfo:[NSDictionary dictionaryWithObject:@"Track has no points"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    // Build valid point indices
    NSMutableArray *validIdx = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0, n = [pts count]; i < n; i++) {
        TrackPoint *p = [pts objectAtIndex:i];
        if (![p isKindOfClass:[TrackPoint class]]) continue;
        float lat = [p latitude], lon = [p longitude];
        if ([p validLatLon] && isfinite(lat) && isfinite(lon) &&
            fabs(lat) <= 90.0f && fabs(lon) <= 180.0f &&
            !(lat == 0.0f && lon == 0.0f)) {
            [validIdx addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }
    if ([validIdx count] == 0) {
        [validIdx release];
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:3004
                                                  userInfo:[NSDictionary dictionaryWithObject:@"No valid lat/lon points in Track"
                                                                                       forKey:NSLocalizedDescriptionKey]];
        return nil;
    }

    const NSUInteger kMaxSamples = 8;
    NSArray *sampleIdx = [self _evenlySpacedIndicesFromArray:validIdx maxCount:kMaxSamples];
    [validIdx release];

    // Query range (±1h buffer) by day; we'll bucket by hour string.
    NSDate *queryStart = [startUTC dateByAddingTimeInterval:-3600.0];
    NSDate *queryEnd   = [endUTC   dateByAddingTimeInterval: 3600.0];
    NSString *startDay = [self _ymdUTC:queryStart];
    NSString *endDay   = [self _ymdUTC:queryEnd];

    NSDateFormatter *hourFmt = [self _isoHourUTCFormatter];
    NSTimeInterval sTI = [startUTC timeIntervalSince1970];
    NSTimeInterval eTI = [endUTC timeIntervalSince1970];

    // hour -> accumulators
    NSMutableDictionary *hourBuckets = [[NSMutableDictionary alloc] init]; // key: hourStr -> dict {sumT,sumW,sumH,sumP,sumCodeCounts,count}
    NSMutableDictionary *codeCountPerHour = nil;

    for (NSNumber *num in sampleIdx) {
        TrackPoint *p = [pts objectAtIndex:[num unsignedIntegerValue]];
        double lat = (double)[p latitude], lon = (double)[p longitude];

        NSDictionary *hourlyDict = [self _fetchERA5HourlyForLat:lat lon:lon startDay:startDay endDay:endDay error:outError];
        if (!hourlyDict) continue;

        NSArray *times = [hourlyDict objectForKey:@"time"];
        NSArray *tC    = [hourlyDict objectForKey:@"temperature_2m"];
        NSArray *rh    = [hourlyDict objectForKey:@"relative_humidity_2m"];
        NSArray *prec  = [hourlyDict objectForKey:@"precipitation"];
        NSArray *wind  = [hourlyDict objectForKey:@"windspeed_10m"];
        NSArray *wcode = [hourlyDict objectForKey:@"weathercode"];
        if (![times isKindOfClass:[NSArray class]] ||
            ![tC isKindOfClass:[NSArray class]] ||
            ![rh isKindOfClass:[NSArray class]] ||
            ![prec isKindOfClass:[NSArray class]] ||
            ![wind isKindOfClass:[NSArray class]] ||
            ![wcode isKindOfClass:[NSArray class]]) {
            continue;
        }

        for (NSUInteger i = 0, m = [times count]; i < m; i++) {
            NSString *ts = [times objectAtIndex:i];            // "yyyy-MM-dd'T'HH:mm"
            NSDate *d = [hourFmt dateFromString:ts];
            if (!d) continue;
            NSTimeInterval ti = [d timeIntervalSince1970];
            if (ti < floor(sTI - 0.5) || ti > ceil(eTI + 0.5)) continue;

            // Bucket key: expand to full Z ISO (add :00 seconds)
            NSString *hourKey = [NSString stringWithFormat:@"%@:00Z", ts];

            // Ensure bucket exists
            NSMutableDictionary *bucket = [hourBuckets objectForKey:hourKey];
            if (!bucket) {
                bucket = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithDouble:0.0], @"sumT",
                          [NSNumber numberWithDouble:0.0], @"sumW",
                          [NSNumber numberWithDouble:0.0], @"sumH",
                          [NSNumber numberWithDouble:0.0], @"sumP",
                          [NSNumber numberWithInteger:0],  @"count",
                          nil];
                [hourBuckets setObject:bucket forKey:hourKey];
            }

            // Accumulate
            double t  = [[tC objectAtIndex:i]   respondsToSelector:@selector(doubleValue)] ? [[tC objectAtIndex:i]   doubleValue] : NAN;
            double h  = [[rh objectAtIndex:i]   respondsToSelector:@selector(doubleValue)] ? [[rh objectAtIndex:i]   doubleValue] : NAN;
            double pr = [[prec objectAtIndex:i] respondsToSelector:@selector(doubleValue)] ? [[prec objectAtIndex:i] doubleValue] : NAN;
            double w  = [[wind objectAtIndex:i] respondsToSelector:@selector(doubleValue)] ? [[wind objectAtIndex:i] doubleValue] : NAN;
            int    wc = [[wcode objectAtIndex:i] respondsToSelector:@selector(intValue)]   ? [[wcode objectAtIndex:i] intValue]    : -1;

            if (!isnan(t))  [bucket setObject:[NSNumber numberWithDouble:([[bucket objectForKey:@"sumT"] doubleValue] + t)]          forKey:@"sumT"];
            if (!isnan(h))  [bucket setObject:[NSNumber numberWithDouble:([[bucket objectForKey:@"sumH"] doubleValue] + h)]          forKey:@"sumH"];
            if (!isnan(pr)) [bucket setObject:[NSNumber numberWithDouble:([[bucket objectForKey:@"sumP"] doubleValue] + pr)]         forKey:@"sumP"];
            if (!isnan(w))  [bucket setObject:[NSNumber numberWithDouble:([[bucket objectForKey:@"sumW"] doubleValue] + (w * 3.6))]  forKey:@"sumW"]; // m/s -> km/h
            [bucket setObject:[NSNumber numberWithInteger:([[bucket objectForKey:@"count"] integerValue] + 1)] forKey:@"count"];

            // Per-hour modal code
            codeCountPerHour = [bucket objectForKey:@"codeCounts"];
            if (!codeCountPerHour) {
                codeCountPerHour = [NSMutableDictionary dictionary];
                [bucket setObject:codeCountPerHour forKey:@"codeCounts"];
            }
            NSNumber *wcKey = [NSNumber numberWithInt:wc];
            NSNumber *curr = [codeCountPerHour objectForKey:wcKey];
            NSInteger newCount = (curr ? [curr integerValue] : 0) + 1;
            [codeCountPerHour setObject:[NSNumber numberWithInteger:newCount] forKey:wcKey];
        }
    }

    // Emit sorted array by time
    NSArray *allHours = [[hourBuckets allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *timeline = [[NSMutableArray alloc] initWithCapacity:[allHours count]];
    for (NSString *hourKey in allHours) {
        NSDictionary *bucket = [hourBuckets objectForKey:hourKey];
        NSInteger c = [[bucket objectForKey:@"count"] integerValue];
        if (c <= 0) continue;

        double avgT = [[bucket objectForKey:@"sumT"] doubleValue] / (double)c;
        double avgH = [[bucket objectForKey:@"sumH"] doubleValue] / (double)c;
        double avgW = [[bucket objectForKey:@"sumW"] doubleValue] / (double)c;
        double totP = [[bucket objectForKey:@"sumP"] doubleValue]; // precip is sum across samples for this hour

        // modal code per hour
        NSDictionary *cc = [bucket objectForKey:@"codeCounts"];
        int modalCode = -1; NSInteger best = 0;
        for (NSNumber *k in cc) {
            NSInteger n = [[cc objectForKey:k] integerValue];
            if (n > best) { best = n; modalCode = [k intValue]; }
        }

        NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:6];
        [row setObject:hourKey forKey:kWXTimeUTC];
        [row setObject:[NSNumber numberWithDouble:avgT]   forKey:kWXTempC];
        [row setObject:[NSNumber numberWithDouble:avgW]   forKey:kWXWindKph];
        [row setObject:[NSNumber numberWithDouble:avgH]   forKey:kWXHumidityPct];
        [row setObject:[NSNumber numberWithDouble:totP]   forKey:kWXPrecipMm];
        if (modalCode >= 0) [row setObject:[NSNumber numberWithInt:modalCode] forKey:kWXCode];

        [timeline addObject:row];
    }

    [hourBuckets release];
    return [timeline autorelease];
}

+ (NSString *)stringForWeatherCode:(NSInteger)code {
    switch ((int)code) {
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
        default: return [NSString stringWithFormat:@"WMO %ld", (long)code];
    }
}


// Container keys
NSString * const kGeoStart = @"start";
NSString * const kGeoEnd   = @"end";

// (If you haven't already added these earlier in this file)
NSString * const kGeoCity        = @"city";
NSString * const kGeoCountry     = @"country";
NSString * const kGeoCountryCode = @"country_code";
NSString * const kGeoAdmin       = @"admin";
NSString * const kGeoLatitude    = @"lat";
NSString * const kGeoLongitude   = @"lon";

#pragma mark - Start/End reverse geocoding

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
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:4101
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

+ (NSDictionary *)startEndCityCountryForTrack:(Track *)track
                                        error:(NSError * _Nullable * _Nullable)outError
{
    if (!track) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:4201
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Track is nil"}];
        return nil;
    }

    double sLat=0, sLon=0, eLat=0, eLon=0;
    if (![self _extractFirstValidLatLonFromTrack:track lat:&sLat lon:&sLon]) {
        if (outError) *outError = [NSError errorWithDomain:@"WeatherAPI" code:4202
                                                  userInfo:@{NSLocalizedDescriptionKey:@"No valid start coordinate"}];
        return nil;
    }
    if (![self _extractLastValidLatLonFromTrack:track lat:&eLat lon:&eLon]) {
        // If no separate end found, reuse start as end
        eLat = sLat; eLon = sLon;
    }

    // Reverse-geocode (sequentially; rate-limit friendly). Call off main thread.
    NSError *sErr = nil, *eErr = nil;
    NSDictionary *startDict = [self _reverseGeocodeLatitude:sLat longitude:sLon error:&sErr];
    NSDictionary *endDict   = [self _reverseGeocodeLatitude:eLat longitude:eLon error:&eErr];

    if (!startDict && !endDict) {
        if (outError) *outError = (sErr ?: eErr ?: [NSError errorWithDomain:@"WeatherAPI" code:4203
                                                                   userInfo:@{NSLocalizedDescriptionKey:@"Reverse geocoding failed"}]);
        return nil;
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:2];
    if (startDict) [result setObject:startDict forKey:kGeoStart];
    if (endDict)   [result setObject:endDict   forKey:kGeoEnd];
    return [result autorelease];
}

@end
