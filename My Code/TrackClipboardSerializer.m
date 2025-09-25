//
//  TrackClipboardSerializer.m
//  Ascent
//
//  Created by Rob Boyer on 9/24/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "TrackClipboardSerializer.h"
#import "Track.h"
#import "TrackPoint.h"
#import "Lap.h"
#import "PathMarker.h"

static NSString * const kASCClipboardErrorDomain = @"com.montebellosoftware.Ascent.TrackClipboard";
static const NSInteger kASCClipboardPayloadVersion = 1;

@implementation TrackClipboardSerializer

#pragma mark - Public API

+ (NSString *)serializeTracksToJSONString:(NSArray *)tracks
                                    error:(NSError * __autoreleasing *)error
{
    if (![tracks isKindOfClass:[NSArray class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:1001
                                     userInfo:[NSDictionary dictionaryWithObject:@"Input is not an NSArray"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSMutableArray *tracksOut = [NSMutableArray arrayWithCapacity:[tracks count]];

    NSEnumerator *e = [tracks objectEnumerator];
    Track *t = nil;
    while ((t = [e nextObject])) {
        if (![t isKindOfClass:[Track class]]) {
            continue;
        }
        NSDictionary *td = [self _dictionaryForTrack:t];
        if (td != nil) {
            [tracksOut addObject:td];
        }
    }

    NSMutableDictionary *root = [NSMutableDictionary dictionaryWithCapacity:4];
    [root setObject:[NSNumber numberWithInteger:kASCClipboardPayloadVersion] forKey:@"payload_version"];
    [root setObject:@"Ascent" forKey:@"source_app"];
    [root setObject:[NSNumber numberWithLongLong:(long long)floor([[NSDate date] timeIntervalSince1970])] forKey:@"exported_at_s"];
    [root setObject:tracksOut forKey:@"tracks"];

    NSError *jsonErr = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:root options:0 error:&jsonErr];
    if (jsonData == nil) {
        if (error != NULL) {
            *error = jsonErr;
        }
        return nil;
    }

    NSString *json = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease];
    if (json == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:1002
                                     userInfo:[NSDictionary dictionaryWithObject:@"Failed to UTF-8 encode JSON"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    return json;
}


+ (NSArray *)deserializeTracksFromJSONString:(NSString *)json
                                       error:(NSError * __autoreleasing *)error
{
    if (![json isKindOfClass:[NSString class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:2001
                                     userInfo:[NSDictionary dictionaryWithObject:@"Input is not an NSString"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:2002
                                     userInfo:[NSDictionary dictionaryWithObject:@"Input is not valid UTF-8"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSError *jsonErr = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
    if (root == nil || ![root isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = (jsonErr != nil) ? jsonErr
                                      : [NSError errorWithDomain:kASCClipboardErrorDomain
                                                            code:2003
                                                        userInfo:[NSDictionary dictionaryWithObject:@"JSON root not a dictionary"
                                                                                             forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSNumber *pv = [(NSDictionary *)root objectForKey:@"payload_version"];
    if (![pv isKindOfClass:[NSNumber class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:2004
                                     userInfo:[NSDictionary dictionaryWithObject:@"Missing payload_version"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    NSInteger payloadVersion = [pv integerValue];
    if (payloadVersion != kASCClipboardPayloadVersion) {
        // Future-proof note: adjust as you evolve the format
        // For now we only accept exact version match.
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:2005
                                     userInfo:[NSDictionary dictionaryWithObject:@"Unsupported payload_version"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSArray *tracksIn = [(NSDictionary *)root objectForKey:@"tracks"];
    if (![tracksIn isKindOfClass:[NSArray class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kASCClipboardErrorDomain
                                         code:2006
                                     userInfo:[NSDictionary dictionaryWithObject:@"Missing tracks array"
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSMutableArray *out = [NSMutableArray arrayWithCapacity:[tracksIn count]];

    NSEnumerator *e = [tracksIn objectEnumerator];
    NSDictionary *td = nil;
    while ((td = [e nextObject])) {
        if (![td isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        Track *t = [self _trackFromDictionary:td];
        if (t != nil) {
            [out addObject:t];
            [t release];
        }
    }

    return out;
}

#pragma mark - Track -> NSDictionary

+ (NSDictionary *)_dictionaryForTrack:(Track *)t
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:32];

    if (t.uuid != nil) {
        [d setObject:t.uuid forKey:@"uuid"];
    }
    if (t.name != nil) {
        [d setObject:t.name forKey:@"name"];
    }
    if (t.stravaActivityID != nil) {
        [d setObject:t.stravaActivityID forKey:@"stravaActivityID"];
    }
    if (t.creationTime != nil) {
        [d setObject:[self _numberFromDate:t.creationTime] forKey:@"creation_time_s"];
    }
    if (t.creationTimeOverride != nil) {
        [d setObject:[self _numberFromDate:t.creationTimeOverride] forKey:@"creation_time_override_s"];
    }

    [d setObject:[NSNumber numberWithDouble:t.deviceTotalTime] forKey:@"device_total_time_s"];
    [d setObject:[NSNumber numberWithInt:(int)t.firmwareVersion] forKey:@"firmware_version"];
    [d setObject:[NSNumber numberWithFloat:t.minGradientDistance] forKey:@"min_gradient_distance"];
    [d setObject:[NSNumber numberWithBool:t.movingSpeedOnly] forKey:@"moving_speed_only"];
    [d setObject:[NSNumber numberWithFloat:t.weight] forKey:@"weight_lb"];
    [d setObject:[NSNumber numberWithFloat:t.altitudeSmoothingFactor] forKey:@"altitude_smoothing_factor"];
    [d setObject:[NSNumber numberWithInt:(int)t.secondsFromGMT] forKey:@"seconds_from_gmt"];
    [d setObject:[NSNumber numberWithInt:(int)t.flags] forKey:@"flags"];
    [d setObject:[NSNumber numberWithInt:(int)t.deviceID] forKey:@"device_id"];

    if (t.timeZoneName != nil) {
        [d setObject:t.timeZoneName forKey:@"time_zone_name"];
    }

    // src* fields
    [d setObject:[NSNumber numberWithFloat:t.srcDistance] forKey:@"src_distance"];
    [d setObject:[NSNumber numberWithFloat:t.srcMaxSpeed] forKey:@"src_max_speed"];
    [d setObject:[NSNumber numberWithFloat:t.srcAvgHeartrate] forKey:@"src_avg_hr"];
    [d setObject:[NSNumber numberWithFloat:t.srcMaxHeartrate] forKey:@"src_max_hr"];
    [d setObject:[NSNumber numberWithFloat:t.srcAvgTemperature] forKey:@"src_avg_temp"];
    [d setObject:[NSNumber numberWithFloat:t.srcMaxElevation] forKey:@"src_max_elev"];
    [d setObject:[NSNumber numberWithFloat:t.srcMinElevation] forKey:@"src_min_elev"];
    [d setObject:[NSNumber numberWithFloat:t.srcAvgPower] forKey:@"src_avg_power"];
    [d setObject:[NSNumber numberWithFloat:t.srcMaxPower] forKey:@"src_max_power"];
    [d setObject:[NSNumber numberWithFloat:t.srcAvgCadence] forKey:@"src_avg_cadence"];
    [d setObject:[NSNumber numberWithFloat:t.srcTotalClimb] forKey:@"src_total_climb"];
    [d setObject:[NSNumber numberWithFloat:t.srcKilojoules] forKey:@"src_kilojoules"];
    [d setObject:[NSNumber numberWithDouble:t.srcElapsedTime] forKey:@"src_elapsed_time_s"];
    [d setObject:[NSNumber numberWithDouble:t.srcMovingTime] forKey:@"src_moving_time_s"];

    // attributes: preserve positions including NSNull sentinels
    NSArray *attrs = t.attributes;
    if ([attrs isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[attrs count]];
        NSUInteger i = 0;
        for (i = 0; i < [attrs count]; i++) {
            id v = [attrs objectAtIndex:i];
            if (v == nil || v == (id)kCFNull) {
                [arr addObject:[NSNull null]];
            } else if ([v isKindOfClass:[NSString class]]) {
                [arr addObject:v];
            } else {
                [arr addObject:[NSNull null]];
            }
        }
        [d setObject:arr forKey:@"attributes"];
    }

    // localMediaItems
    if ([t.localMediaItems isKindOfClass:[NSArray class]]) {
        NSMutableArray *lm = [NSMutableArray arrayWithCapacity:[t.localMediaItems count]];
        NSEnumerator *lme = [t.localMediaItems objectEnumerator];
        id s = nil;
        while ((s = [lme nextObject])) {
            if ([s isKindOfClass:[NSString class]]) {
                [lm addObject:s];
            }
        }
        [d setObject:lm forKey:@"local_media_items"];
    }

    // points
    if ([t.points isKindOfClass:[NSArray class]]) {
        NSMutableArray *ptsOut = [NSMutableArray arrayWithCapacity:[t.points count]];
        NSEnumerator *pe = [t.points objectEnumerator];
        TrackPoint *p = nil;
        while ((p = [pe nextObject])) {
            if (![p isKindOfClass:[TrackPoint class]]) {
                continue;
            }
            [ptsOut addObject:[self _dictionaryForPoint:p]];
        }
        [d setObject:ptsOut forKey:@"points"];
    }

    // laps
    if ([t.laps isKindOfClass:[NSArray class]]) {
        NSMutableArray *lapsOut = [NSMutableArray arrayWithCapacity:[t.laps count]];
        NSEnumerator *le = [t.laps objectEnumerator];
        Lap *lap = nil;
        while ((lap = [le nextObject])) {
            if (![lap isKindOfClass:[Lap class]]) {
                continue;
            }
            [lapsOut addObject:[self _dictionaryForLap:lap]];
        }
        [d setObject:lapsOut forKey:@"laps"];
    }

    // markers
    if ([t.markers isKindOfClass:[NSArray class]]) {
        NSMutableArray *marksOut = [NSMutableArray arrayWithCapacity:[t.markers count]];
        NSEnumerator *me = [t.markers objectEnumerator];
        PathMarker *m = nil;
        while ((m = [me nextObject])) {
            if (![m isKindOfClass:[PathMarker class]]) {
                continue;
            }
            [marksOut addObject:[self _dictionaryForMarker:m]];
        }
        [d setObject:marksOut forKey:@"markers"];
    }

    return d;
}

+ (NSDictionary *)_dictionaryForPoint:(TrackPoint *)p
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:20];

    [d setObject:[NSNumber numberWithDouble:p.wallClockDelta] forKey:@"wall_clock_delta_s"];
    [d setObject:[NSNumber numberWithDouble:p.activeTimeDelta] forKey:@"active_time_delta_s"];
    [d setObject:[NSNumber numberWithFloat:p.latitude] forKey:@"lat"];
    [d setObject:[NSNumber numberWithFloat:p.longitude] forKey:@"lon"];
    [d setObject:[NSNumber numberWithFloat:p.altitude] forKey:@"altitude"];
    [d setObject:[NSNumber numberWithFloat:p.origAltitude] forKey:@"orig_altitude"];
    [d setObject:[NSNumber numberWithFloat:p.heartrate] forKey:@"heartrate"];
    [d setObject:[NSNumber numberWithFloat:p.cadence] forKey:@"cadence"];
    [d setObject:[NSNumber numberWithFloat:p.temperature] forKey:@"temperature"];
    [d setObject:[NSNumber numberWithFloat:p.speed] forKey:@"speed"];
    [d setObject:[NSNumber numberWithFloat:p.power] forKey:@"power"];
    [d setObject:[NSNumber numberWithFloat:p.origDistance] forKey:@"orig_distance"];
    [d setObject:[NSNumber numberWithFloat:p.distance] forKey:@"distance"];
    [d setObject:[NSNumber numberWithFloat:p.gradient] forKey:@"gradient"];
    [d setObject:[NSNumber numberWithFloat:p.climbSoFar] forKey:@"climb_so_far"];
    [d setObject:[NSNumber numberWithFloat:p.descentSoFar] forKey:@"descent_so_far"];
    [d setObject:[NSNumber numberWithInt:(int)p.flags] forKey:@"flags"];
    [d setObject:[NSNumber numberWithBool:p.validLatLon] forKey:@"valid_lat_lon"];

    return d;
}

+ (NSDictionary *)_dictionaryForLap:(Lap *)lap
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:24];

    [d setObject:[NSNumber numberWithInt:(int)lap.index] forKey:@"index"];
    if (lap.origStartTime != nil) {
        [d setObject:[self _numberFromDate:lap.origStartTime] forKey:@"orig_start_time_s"];
    }
    [d setObject:[NSNumber numberWithDouble:lap.startTimeDelta] forKey:@"start_time_delta_s"];
    [d setObject:[NSNumber numberWithDouble:lap.totalTime] forKey:@"total_time_s"];
    [d setObject:[NSNumber numberWithDouble:lap.deviceTotalTime] forKey:@"device_total_time_s"];

    [d setObject:[NSNumber numberWithFloat:lap.distance] forKey:@"distance"];
    [d setObject:[NSNumber numberWithFloat:lap.maxSpeed] forKey:@"max_speed"];
    [d setObject:[NSNumber numberWithFloat:lap.avgSpeed] forKey:@"avg_speed"];

    [d setObject:[NSNumber numberWithFloat:lap.beginLatitude] forKey:@"begin_lat"];
    [d setObject:[NSNumber numberWithFloat:lap.beginLongitude] forKey:@"begin_lon"];
    [d setObject:[NSNumber numberWithFloat:lap.endLatitude] forKey:@"end_lat"];
    [d setObject:[NSNumber numberWithFloat:lap.endLongitude] forKey:@"end_lon"];

    [d setObject:[NSNumber numberWithInt:(int)lap.averageHeartRate] forKey:@"avg_hr"];
    [d setObject:[NSNumber numberWithInt:(int)lap.maxHeartRate] forKey:@"max_hr"];
    [d setObject:[NSNumber numberWithInt:(int)lap.averageCadence] forKey:@"avg_cadence"];
    [d setObject:[NSNumber numberWithInt:(int)lap.maxCadence] forKey:@"max_cadence"];

    [d setObject:[NSNumber numberWithInt:(int)lap.calories] forKey:@"calories"];
    [d setObject:[NSNumber numberWithInt:(int)lap.intensity] forKey:@"intensity"];
    [d setObject:[NSNumber numberWithInt:(int)lap.triggerMethod] forKey:@"trigger_method"];

    return d;
}

+ (NSDictionary *)_dictionaryForMarker:(PathMarker *)m
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:4];

    if (m.name != nil) {
        [d setObject:m.name forKey:@"name"];
    }
    if (m.imagePath != nil) {
        [d setObject:m.imagePath forKey:@"image_path"];
    }
    if (m.soundPath != nil) {
        [d setObject:m.soundPath forKey:@"sound_path"];
    }
    [d setObject:[NSNumber numberWithFloat:m.distance] forKey:@"distance"];

    return d;
}

#pragma mark - NSDictionary -> Track

+ (Track *)_trackFromDictionary:(NSDictionary *)d
{
    Track *t = [[Track alloc] init];

    id v = nil;

    v = [d objectForKey:@"uuid"];
    if ([v isKindOfClass:[NSString class]]) {
        t.uuid = v;
    }

    v = [d objectForKey:@"name"];
    if ([v isKindOfClass:[NSString class]]) {
        t.name = v;
    }

    v = [d objectForKey:@"stravaActivityID"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.stravaActivityID = v;
    }

    v = [d objectForKey:@"creation_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.creationTime = [self _dateFromUnixSecondsNumber:v];
    }

    v = [d objectForKey:@"creation_time_override_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.creationTimeOverride = [self _dateFromUnixSecondsNumber:v];
    }

    v = [d objectForKey:@"device_total_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.deviceTotalTime = [v doubleValue];
    }

    v = [d objectForKey:@"firmware_version"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.firmwareVersion = [v intValue];
    }

    v = [d objectForKey:@"min_gradient_distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.minGradientDistance = [v floatValue];
    }

    v = [d objectForKey:@"moving_speed_only"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.movingSpeedOnly = [v boolValue];
    }

    v = [d objectForKey:@"weight_lb"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.weight = [v floatValue];
    }

    v = [d objectForKey:@"altitude_smoothing_factor"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.altitudeSmoothingFactor = [v floatValue];
    }

    v = [d objectForKey:@"seconds_from_gmt"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.secondsFromGMT = [v intValue];
    }

    v = [d objectForKey:@"flags"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.flags = [v intValue];
    }

    v = [d objectForKey:@"device_id"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.deviceID = [v intValue];
    }

    v = [d objectForKey:@"time_zone_name"];
    if ([v isKindOfClass:[NSString class]]) {
        t.timeZoneName = v;
    }

    // src* fields
    v = [d objectForKey:@"src_distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcDistance = [v floatValue];
    }

    v = [d objectForKey:@"src_max_speed"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMaxSpeed = [v floatValue];
    }

    v = [d objectForKey:@"src_avg_hr"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcAvgHeartrate = [v floatValue];
    }

    v = [d objectForKey:@"src_max_hr"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMaxHeartrate = [v floatValue];
    }

    v = [d objectForKey:@"src_avg_temp"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcAvgTemperature = [v floatValue];
    }

    v = [d objectForKey:@"src_max_elev"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMaxElevation = [v floatValue];
    }

    v = [d objectForKey:@"src_min_elev"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMinElevation = [v floatValue];
    }

    v = [d objectForKey:@"src_avg_power"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcAvgPower = [v floatValue];
    }

    v = [d objectForKey:@"src_max_power"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMaxPower = [v floatValue];
    }

    v = [d objectForKey:@"src_avg_cadence"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcAvgCadence = [v floatValue];
    }

    v = [d objectForKey:@"src_total_climb"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcTotalClimb = [v floatValue];
    }

    v = [d objectForKey:@"src_kilojoules"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcKilojoules = [v floatValue];
    }

    v = [d objectForKey:@"src_elapsed_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcElapsedTime = [v doubleValue];
    }

    v = [d objectForKey:@"src_moving_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        t.srcMovingTime = [v doubleValue];
    }

    // attributes (preserve NSNull)
    v = [d objectForKey:@"attributes"];
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *attrs = [NSMutableArray arrayWithCapacity:[(NSArray *)v count]];
        NSUInteger i = 0;
        for (i = 0; i < [(NSArray *)v count]; i++) {
            id a = [(NSArray *)v objectAtIndex:i];
            if (a == nil) {
                [attrs addObject:[NSNull null]];
            } else if (a == (id)kCFNull) {
                [attrs addObject:[NSNull null]];
            } else if ([a isKindOfClass:[NSString class]]) {
                [attrs addObject:a];
            } else {
                [attrs addObject:[NSNull null]];
            }
        }
        t.attributes = attrs;
    }

    // local media items
    v = [d objectForKey:@"local_media_items"];
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *lm = [NSMutableArray arrayWithCapacity:[(NSArray *)v count]];
        NSEnumerator *lme = [(NSArray *)v objectEnumerator];
        id s = nil;
        while ((s = [lme nextObject])) {
            if ([s isKindOfClass:[NSString class]]) {
                [lm addObject:s];
            }
        }
        t.localMediaItems = lm;
    }

    // points
    v = [d objectForKey:@"points"];
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *pts = [NSMutableArray arrayWithCapacity:[(NSArray *)v count]];
        NSEnumerator *pe = [(NSArray *)v objectEnumerator];
        NSDictionary *pd = nil;
        while ((pd = [pe nextObject])) {
            if (![pd isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            TrackPoint *p = [self _pointFromDictionary:pd];
            if (p != nil) {
                [pts addObject:p];
                [p release];
            }
        }
        t.points = pts;
    }

    // laps
    v = [d objectForKey:@"laps"];
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *laps = [NSMutableArray arrayWithCapacity:[(NSArray *)v count]];
        NSEnumerator *le = [(NSArray *)v objectEnumerator];
        NSDictionary *ld = nil;
        while ((ld = [le nextObject])) {
            if (![ld isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            Lap *lap = [self _lapFromDictionary:ld];
            if (lap != nil) {
                [laps addObject:lap];
                [lap release];
            }
        }
        t.laps = laps;
    }

    // markers
    v = [d objectForKey:@"markers"];
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *marks = [NSMutableArray arrayWithCapacity:[(NSArray *)v count]];
        NSEnumerator *me = [(NSArray *)v objectEnumerator];
        NSDictionary *md = nil;
        while ((md = [me nextObject])) {
            if (![md isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            PathMarker *m = [self _markerFromDictionary:md];
            if (m != nil) {
                [marks addObject:m];
                [m release];
            }
        }
        t.markers = marks;
    }

    return t;
}

+ (TrackPoint *)_pointFromDictionary:(NSDictionary *)d
{
    TrackPoint *p = [[TrackPoint alloc] init];

    id v = nil;

    v = [d objectForKey:@"wall_clock_delta_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.wallClockDelta = [v doubleValue];
    }

    v = [d objectForKey:@"active_time_delta_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.activeTimeDelta = [v doubleValue];
    }

    v = [d objectForKey:@"lat"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.latitude = [v floatValue];
    }

    v = [d objectForKey:@"lon"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.longitude = [v floatValue];
    }

    v = [d objectForKey:@"altitude"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.altitude = [v floatValue];
    }

    v = [d objectForKey:@"orig_altitude"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.origAltitude = [v floatValue];
    }

    v = [d objectForKey:@"heartrate"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.heartrate = [v floatValue];
    }

    v = [d objectForKey:@"cadence"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.cadence = [v floatValue];
    }

    v = [d objectForKey:@"temperature"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.temperature = [v floatValue];
    }

    v = [d objectForKey:@"speed"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.speed = [v floatValue];
    }

    v = [d objectForKey:@"power"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.power = [v floatValue];
    }

    v = [d objectForKey:@"orig_distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.origDistance = [v floatValue];
    }

    v = [d objectForKey:@"distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.distance = [v floatValue];
    }

    v = [d objectForKey:@"gradient"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.gradient = [v floatValue];
    }

    v = [d objectForKey:@"climb_so_far"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.climbSoFar = [v floatValue];
    }

    v = [d objectForKey:@"descent_so_far"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.descentSoFar = [v floatValue];
    }

    v = [d objectForKey:@"flags"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.flags = [v intValue];
    }

    v = [d objectForKey:@"valid_lat_lon"];
    if ([v isKindOfClass:[NSNumber class]]) {
        p.validLatLon = [v boolValue];
    }

    return p;
}

+ (Lap *)_lapFromDictionary:(NSDictionary *)d
{
    Lap *lap = [[Lap alloc] init];

    id v = nil;

    v = [d objectForKey:@"index"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.index = [v intValue];
    }

    v = [d objectForKey:@"orig_start_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.origStartTime = [self _dateFromUnixSecondsNumber:v];
    }

    v = [d objectForKey:@"start_time_delta_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.startTimeDelta = [v doubleValue];
    }

    v = [d objectForKey:@"total_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.totalTime = [v doubleValue];
    }

    v = [d objectForKey:@"device_total_time_s"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.deviceTotalTime = [v doubleValue];
    }

    v = [d objectForKey:@"distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.distance = [v floatValue];
    }

    v = [d objectForKey:@"max_speed"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.maxSpeed = [v floatValue];
    }

    v = [d objectForKey:@"avg_speed"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.avgSpeed = [v floatValue];
    }

    v = [d objectForKey:@"begin_lat"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.beginLatitude = [v floatValue];
    }

    v = [d objectForKey:@"begin_lon"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.beginLongitude = [v floatValue];
    }

    v = [d objectForKey:@"end_lat"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.endLatitude = [v floatValue];
    }

    v = [d objectForKey:@"end_lon"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.endLongitude = [v floatValue];
    }

    v = [d objectForKey:@"avg_hr"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.averageHeartRate = [v intValue];
    }

    v = [d objectForKey:@"max_hr"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.maxHeartRate = [v intValue];
    }

    v = [d objectForKey:@"avg_cadence"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.averageCadence = [v intValue];
    }

    v = [d objectForKey:@"max_cadence"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.maxCadence = [v intValue];
    }

    v = [d objectForKey:@"calories"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.calories = [v intValue];
    }

    v = [d objectForKey:@"intensity"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.intensity = [v intValue];
    }

    v = [d objectForKey:@"trigger_method"];
    if ([v isKindOfClass:[NSNumber class]]) {
        lap.triggerMethod = [v intValue];
    }

    return lap;
}

+ (PathMarker *)_markerFromDictionary:(NSDictionary *)d
{
    PathMarker *m = [[PathMarker alloc] init];

    id v = nil;

    v = [d objectForKey:@"name"];
    if ([v isKindOfClass:[NSString class]]) {
        m.name = v;
    }

    v = [d objectForKey:@"image_path"];
    if ([v isKindOfClass:[NSString class]]) {
        m.imagePath = v;
    }

    v = [d objectForKey:@"sound_path"];
    if ([v isKindOfClass:[NSString class]]) {
        m.soundPath = v;
    }

    v = [d objectForKey:@"distance"];
    if ([v isKindOfClass:[NSNumber class]]) {
        m.distance = [v floatValue];
    }

    return m;
}

#pragma mark - Helpers

+ (NSNumber *)_numberFromDate:(NSDate *)date
{
    if (![date isKindOfClass:[NSDate class]]) {
        return nil;
    }
    NSTimeInterval ti = [date timeIntervalSince1970];
    return [NSNumber numberWithLongLong:(long long)floor(ti)];
}

+ (NSDate *)_dateFromUnixSecondsNumber:(NSNumber *)n
{
    NSTimeInterval ti = (NSTimeInterval)[n longLongValue];
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:ti];
    return d;
}

@end
