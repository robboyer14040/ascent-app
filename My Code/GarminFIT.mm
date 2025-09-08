//
//  GarminFIT.mm
//  Ascent
//
//  Created by Rob Boyer on 2/13/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "Defs.h"
#import "GarminFIT.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "fit_convert.h"

#define TRACE_PARSING        ASCENT_DBG&&0
#define TRACE_DEVICE_INFO    ASCENT_DBG&&0

@interface GarminFIT ()
@property(nonatomic, retain) NSDate *startDate;
@property(nonatomic, retain) NSURL  *fitURL;
@property(nonatomic, retain) NSDate *refDate;
@property(nonatomic, retain) NSDate *dataPointDeltaBasisDate;
@end

@implementation GarminFIT

@synthesize startDate = startDate;
@synthesize fitURL = fitURL;
@synthesize refDate = refDate;
@synthesize dataPointDeltaBasisDate = dataPointDeltaBasisDate;

-(float)semicirclesToDegrees:(int)semis
{
    return semis * (180.0f / (float)(0x7fffffff));
}

-(GarminFIT*)initWithFileURL:(NSURL*)url
{
    self = [super init];
    if (self)
    {
        self.fitURL = url;                 // retain via property
        self.startDate = nil;
        self.dataPointDeltaBasisDate = nil;

        NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        [cal setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

        NSDateComponents *comps = [[NSDateComponents alloc] init];
        [comps setYear:1989];
        [comps setMonth:12];
        [comps setDay:31];
        [comps setHour:0];
        [comps setMinute:0];
        [comps setSecond:0];

        self.refDate = [cal dateFromComponents:comps];    // retain via property

        [comps release];
        [cal release];
    }
    return self;
}

-(void) dealloc
{
    [startDate release];
    [refDate release];
    [dataPointDeltaBasisDate release];
    [fitURL release];
    [super dealloc];
}

-(TrackPoint*)createDeadZonePoint:(NSDate*)dt activeTime:(NSTimeInterval)at isBeginning:(BOOL)beginFlag
{
    TrackPoint *pt = [[[TrackPoint alloc] initWithGPSData:[dt timeIntervalSinceDate:startDate]
                                               activeTime:at
                                                 latitude:BAD_LATLON
                                                longitude:BAD_LATLON
                                                 altitude:BAD_ALTITUDE
                                                heartrate:0
                                                  cadence:0
                                              temperature:0
                                                    speed:0
                                                 distance:BAD_DISTANCE] autorelease];
    lastSpeed = 0.0f;
    lastCadence = 0.0f;
    lastAltitude = 0.0f;
    lastHeartRate = 0.0f;
    beginFlag ? [pt setBeginningOfDeadZone] : [pt setEndOfDeadZone];
    return pt;
}

-(void)setActivityType:(int)fitSport subSport:(int)ss forTrack:(Track*)track
{
    NSString *s = nil;
    switch (fitSport)
    {
        default:
        case FIT_SPORT_INVALID:
        case FIT_SPORT_GENERIC:
            break;

        case FIT_SPORT_RUNNING:
        {
            s  = @kRunning;
            switch (ss)
            {
                default: break;
                case FIT_SUB_SPORT_TREADMILL:       s = @"Treadmill"; break;
                case FIT_SUB_SPORT_STREET:          s = @"Street Running"; break;
                case FIT_SUB_SPORT_TRAIL:           s = @"Trail Running"; break;
                case FIT_SUB_SPORT_TRACK:           s = @"Track Running"; break;
            }
        } break;

        case FIT_SPORT_CYCLING:
        {
            s = @kCycling;
            switch (ss)
            {
                case FIT_SUB_SPORT_SPIN:            s = @"Spinning"; break;
                case FIT_SUB_SPORT_INDOOR_CYCLING:  s = @"Indoor Cycling"; break;
                default:
                case FIT_SUB_SPORT_ROAD:            break;
                case FIT_SUB_SPORT_MOUNTAIN:        s = @"Mountain Biking"; break;
                case FIT_SUB_SPORT_DOWNHILL:        s = @"Downhill"; break;
                case FIT_SUB_SPORT_RECUMBENT:       s = @"Recumbent"; break;
                case FIT_SUB_SPORT_CYCLOCROSS:      s = @"Cyclocross"; break;
                case FIT_SUB_SPORT_HAND_CYCLING:    s = @"Hand Cycling"; break;
            }
        } break;

        case FIT_SPORT_TRANSITION:
            break;

        case FIT_SPORT_FITNESS_EQUIPMENT:
        {
            s = @"Equipment";
            switch (ss)
            {
                default: break;
                case FIT_SUB_SPORT_INDOOR_ROWING:   s = @"Rowing"; break;
                case FIT_SUB_SPORT_ELLIPTICAL:      s = @"Elliptical"; break;
                case FIT_SUB_SPORT_STAIR_CLIMBING:  s = @"Stair Climbing"; break;
            }
        } break;

        case FIT_SPORT_SWIMMING:
        {
            s = @"Swimming";
            switch (ss)
            {
                default:
                    [track setAttribute:kActivity usingString:@"Swimming"];
                    break;
                case FIT_SUB_SPORT_LAP_SWIMMING:     s = @"Lap Swimming"; break;
                case FIT_SUB_SPORT_OPEN_WATER:       s = @"Open Water Swimming"; break;
            }
        } break;
    }
    if (s) {
        [track setAttribute:kActivity usingString:s];
    }
}

-(BOOL)setStartDateIfRequired:(NSDate*)dt forTrack:(Track*)track
{
    BOOL ret = NO;
    if (!startDate)
    {
        [track setCreationTime:dt];
        self.startDate = dt;   // retain via property
        ret = YES;
    }
    return ret;
}

-(BOOL)checkDataPointDeltaBasisDate:(NSDate*)dt
{
    BOOL ret = NO;
    if (!dataPointDeltaBasisDate)
    {
        self.dataPointDeltaBasisDate = dt;
        ret = YES;
    }
    else if ([dt compare:dataPointDeltaBasisDate] == NSOrderedAscending)
    {
        self.dataPointDeltaBasisDate = self.startDate;
        ret = YES;
    }
    return ret;
}

/*
  Import logic summary (unchanged):
  - Establish start time (SESSION/EVENT/first point).
  - Establish basis date for delta times.
  - Build Track/Lap/TrackPoint arrays, filling missing values with last-known.
*/

-(BOOL)import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray
{
    BOOL ret = NO;

    FILE *file;
    FIT_UINT8 buf[8];
    FIT_CONVERT_RETURN convert_return = FIT_CONVERT_CONTINUE;
    FIT_UINT32 buf_size;

    FitConvert_Init(FIT_TRUE);

    NSString *fitPath = [fitURL path];
    if (!fitPath) {
        return NO;
    }

    if ((file = fopen([fitPath UTF8String], "rb")) == NULL) {
        NSLog(@"Error opening file %@", fitPath);
        return NO;
    }

    Track *track = [[Track alloc] init];
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:256];
    self.dataPointDeltaBasisDate = nil;
    self.startDate = nil;

    int  numLaps = 0;
    BOOL inDeadZone = NO;
    BOOL hasDistance = NO;
    float activityDistance = 0.0f;
    BOOL nonMovingLap = NO;

    lastGoodDistance = 0.0f;
    lastHeartRate    = 0.0f;
    lastCadence      = 0.0f;
    lastPower        = 0.0f;
    lastSpeed        = 0.0f;
    lastAltitude     = BAD_ALTITUDE;
    lastLatitude     = BAD_LATLON;
    lastLongitude    = BAD_LATLON;

    while(!feof(file) && (convert_return == FIT_CONVERT_CONTINUE))
    {
        for (buf_size = 0; (buf_size < sizeof(buf)) && !feof(file); buf_size++) {
            buf[buf_size] = getc(file);
        }

        do
        {
            convert_return = FitConvert_Read(buf, buf_size);
            switch (convert_return)
            {
                case FIT_CONVERT_MESSAGE_AVAILABLE:
                {
                    const FIT_UINT8 *mesg = FitConvert_GetMessageData();
                    FIT_UINT16 mesg_num = FitConvert_GetMessageNumber();

                    switch (mesg_num)
                    {
                        case FIT_MESG_NUM_DEVELOPER_DATA_ID:
                        case FIT_MESG_NUM_EXERCISE_TITLE:
                        case FIT_MESG_NUM_SEGMENT_ID:
                        case FIT_MESG_NUM_FIELD_DESCRIPTION:
                            // Ignored; present for schema completeness.
                            break;

                        case FIT_MESG_NUM_FILE_ID:
                        {
#if TRACE_PARSING
                            const FIT_FILE_ID_MESG *id = (FIT_FILE_ID_MESG *) mesg;
                            printf("File ID: type=%u, number=%u\n", id->type, id->number);
#endif
                            break;
                        }

                        case FIT_MESG_NUM_USER_PROFILE:
                        {
#if TRACE_PARSING
                            const FIT_USER_PROFILE_MESG *user_profile = (FIT_USER_PROFILE_MESG *) mesg;
                            printf("User Profile: weight=%0.1fkg\n", user_profile->weight / 10.0f);
#endif
                            break;
                        }

                        case FIT_MESG_NUM_ACTIVITY:
                        {
                            // Reset last-knowns at activity start
                            lastGoodDistance = 0.0f;
                            lastHeartRate    = 0.0f;
                            lastCadence      = 0.0f;
                            lastPower        = 0.0f;
                            lastSpeed        = 0.0f;
                            lastAltitude     = BAD_ALTITUDE;
                            lastLatitude     = BAD_LATLON;
                            lastLongitude    = BAD_LATLON;

                            // Example of restoring fields if needed (left as original behavior)
                            FIT_ACTIVITY_MESG old_mesg;
                            old_mesg.num_sessions = 1;
                            FitConvert_RestoreFields(&old_mesg);
                            break;
                        }

                        case FIT_MESG_NUM_SESSION:
                        {
                            const FIT_SESSION_MESG *session = (const FIT_SESSION_MESG *) mesg;
                            [self setActivityType:session->sport subSport:session->sub_sport forTrack:track];

                            NSDate *dt = [[NSDate alloc] initWithTimeInterval:(NSTimeInterval)session->start_time
                                                                     sinceDate:refDate];
                            [self setStartDateIfRequired:dt forTrack:track];

                            if (FIT_UINT32_INVALID != session->total_distance) {
                                activityDistance = MetersToMiles(session->total_distance / 100.0f);
                            }

                            [dt release];
                            break;
                        }

                        case FIT_MESG_NUM_LAP:
                        {
                            const FIT_LAP_MESG *lap = (const FIT_LAP_MESG *) mesg;

                            NSDate *start = [[NSDate alloc] initWithTimeInterval:(NSTimeInterval)lap->start_time
                                                                        sinceDate:refDate];

                            float blat = BAD_LATLON, elat = BAD_LATLON;
                            float blon = BAD_LATLON, elon = BAD_LATLON;

                            if ((lap->start_position_lat != 0x7FFFFFFF) && (lap->start_position_long != 0x7FFFFFFF)) {
                                blat = [self semicirclesToDegrees:lap->start_position_lat];
                                blon = [self semicirclesToDegrees:lap->start_position_long];
                            }
                            if ((lap->end_position_lat != 0x7FFFFFFF) && (lap->end_position_long != 0x7FFFFFFF)) {
                                elat = [self semicirclesToDegrees:lap->end_position_lat];
                                elon = [self semicirclesToDegrees:lap->end_position_long];
                            }

                            float distance = 0.0f;
                            if (lap->total_distance != FIT_UINT32_INVALID) {
                                distance = ((float)lap->total_distance) / 100.0f;   // meters
                            }

                            float max_speed = 0.0f;
                            if (FIT_UINT16_INVALID != lap->max_speed) {
                                max_speed = MetersToMiles(((float)lap->max_speed) / (1000.0f * 60.0f)); // m/s -> mph
                            }

                            int avg_heartrate = 0;
                            if (FIT_UINT8_INVALID != lap->avg_heart_rate) {
                                avg_heartrate = (int)lap->avg_heart_rate;
                            }

                            int max_heartrate = 0;
                            if (FIT_UINT8_INVALID != lap->max_heart_rate) {
                                max_heartrate = (int)lap->max_heart_rate;
                            }

                            int avg_cadence = 0;
                            if (FIT_UINT8_INVALID != lap->avg_cadence) {
                                avg_cadence = (int)lap->avg_cadence;
                            }

                            NSTimeInterval startSecs = [start timeIntervalSince1970];
                            Lap *ascentLap = [[Lap alloc] initWithGPSData:numLaps++
                                            startTimeSecsSince1970:(time_t)startSecs
                                                        totalTime:((NSTimeInterval)lap->total_elapsed_time) * 100.0 / 1000.0
                                                     totalDistance:distance           // meters (as per original)
                                                          maxSpeed:max_speed
                                                          beginLat:blat
                                                          beginLon:blon
                                                            endLat:elat
                                                            endLon:elon
                                                          calories:lap->total_calories
                                                             avgHR:avg_heartrate
                                                             maxHR:max_heartrate
                                                             avgCD:avg_cadence
                                                         intensity:lap->intensity
                                                           trigger:lap->lap_trigger];

                            [ascentLap setDeviceTotalTime:lap->total_timer_time / 1000.0];
                            NSTimeInterval ttt = [track deviceTotalTime] + (lap->total_timer_time / 1000.0);
                            [track setDeviceTotalTime:ttt];

                            [lapArray addObject:ascentLap];
                            [ascentLap release];

                            if (distance <= 0.0f) nonMovingLap = YES;

                            [start release];
                            break;
                        }

                        case FIT_MESG_NUM_RECORD:
                        {
                            const FIT_RECORD_MESG *record = (const FIT_RECORD_MESG *) mesg;

                            if ((record->altitude   == FIT_UINT16_INVALID) &&
                                (record->speed      == FIT_UINT16_INVALID) &&
                                (record->distance   == FIT_UINT32_INVALID) &&
                                (record->heart_rate == FIT_UINT8_INVALID ) &&
                                (record->cadence    == FIT_UINT8_INVALID ) &&
                                (record->temperature== FIT_SINT8_INVALID )) {
                                break;
                            }

                            NSTimeInterval ti = (NSTimeInterval)record->timestamp;
                            NSDate *origdt = [[NSDate alloc] initWithTimeInterval:ti sinceDate:refDate];

                            [self setStartDateIfRequired:origdt forTrack:track];
                            [self checkDataPointDeltaBasisDate:origdt];

                            NSTimeInterval activeTimeDelta = 0.0;
                            NSDate *dt = origdt;
                            if (dataPointDeltaBasisDate) {
                                activeTimeDelta = [dt timeIntervalSinceDate:dataPointDeltaBasisDate];
                                dt = [startDate dateByAddingTimeInterval:activeTimeDelta];
                            }

                            if (activeTimeDelta >= 0.0)
                            {
                                // ---- position
                                float lat = BAD_LATLON, lon = BAD_LATLON;
                                if ((record->position_lat  != 0x7FFFFFFF) &&
                                    (record->position_long != 0x7FFFFFFF)) {
                                    lat = [self semicirclesToDegrees:record->position_lat];
                                    lon = [self semicirclesToDegrees:record->position_long];
                                }
                                float filteredLat = lat;
                                float filteredLon = lon;

                                // ---- altitude
                                float altitude = BAD_ALTITUDE;
                                bool hasAltitude = record->altitude != FIT_UINT16_INVALID;
                                if (hasAltitude) {
                                    float alt = (((float)record->altitude) / 5.0f) - 500.0f; // stored as 5*(m+500)
                                    altitude = lastAltitude = MetersToFeet(alt);
                                } else {
                                    altitude = lastAltitude;
                                }

                                // ---- speed
                                float speed = 0.0f;
                                bool hasSpeed = FIT_UINT16_INVALID != record->speed;
                                if (hasSpeed) {
                                    speed = MetersToMiles(((float)record->speed * 3600.0f) / 1000.0f);
                                    lastSpeed = speed;
                                }

                                // ---- distance
                                float distance = 0.0f;
                                hasDistance = record->distance != FIT_UINT32_INVALID;
                                if (hasDistance) {
                                    distance = lastGoodDistance = MetersToMiles((float)record->distance / 100.0f);
                                } else {
                                    distance = lastGoodDistance;
                                }

                                // ---- compressed speed + distance fallback
                                if ((!hasSpeed) &&
                                    ((record->compressed_speed_distance[0] != FIT_BYTE_INVALID) ||
                                     (record->compressed_speed_distance[1] != FIT_BYTE_INVALID) ||
                                     (record->compressed_speed_distance[2] != FIT_BYTE_INVALID)))
                                {
                                    static FIT_UINT32 accumulated_distance16 = 0;
                                    static FIT_UINT32 last_distance16 = 0;
                                    FIT_UINT16 speed100;
                                    FIT_UINT32 distance16;
                                    speed100   = record->compressed_speed_distance[0]
                                               | ((record->compressed_speed_distance[1] & 0x0F) << 8);
                                    distance16 = (record->compressed_speed_distance[1] >> 4)
                                               | (record->compressed_speed_distance[2] << 4);
                                    accumulated_distance16 += (distance16 - last_distance16) & 0x0FFF;
                                    last_distance16 = distance16;

                                    speed    = MetersToMiles((speed100 * 3600.0f) / 100.0f);
                                    lastSpeed = speed;
                                    distance = lastGoodDistance = MetersToMiles(accumulated_distance16 / 16.0f);
                                    hasSpeed = YES;
                                    hasDistance = YES;
                                }

                                // ---- heart rate
                                int heartrate = 0;
                                if (FIT_UINT8_INVALID != record->heart_rate) {
                                    heartrate = (int)record->heart_rate;
                                    lastHeartRate = heartrate;
                                } else {
                                    heartrate = (int)lastHeartRate;
                                }

                                // ---- cadence
                                int cadence = 0;
                                if (FIT_UINT8_INVALID != record->cadence) {
                                    cadence = (int)record->cadence;
                                    lastCadence = cadence;
                                } else {
                                    cadence = (int)lastCadence;
                                }

                                // ---- temperature
                                float temp = 0.0f;
                                if (FIT_SINT8_INVALID != record->temperature) {
                                    temp = CelsiusToFahrenheight((float)record->temperature);
                                }

                                TrackPoint *pt = [[TrackPoint alloc] initWithGPSData:[dt timeIntervalSinceDate:startDate]
                                                                           activeTime:activeTimeDelta
                                                                             latitude:filteredLat
                                                                            longitude:filteredLon
                                                                             altitude:altitude
                                                                            heartrate:heartrate
                                                                              cadence:cadence
                                                                          temperature:temp
                                                                                speed:speed
                                                                             distance:distance];

                                if (lastSpeed >= 0.0f) {
                                    [pt setSpeed:lastSpeed];
                                    [pt setSpeedOverriden:YES];
                                }

                                [pt setImportFlagState:kImportFlagMissingDistance state:!hasDistance];
                                [pt setImportFlagState:kImportFlagMissingSpeed    state:!hasSpeed];
                                [pt setImportFlagState:kImportFlagMissingAltitude state:!hasAltitude];

                                // ---- power
                                float power = record->power;
                                bool hasPower = power != FIT_UINT16_INVALID;
                                if (hasPower) {
                                    [pt setPower:power];
                                }

                                [points addObject:pt];
                                [pt release];
                            }

                            [origdt release];
                            break;
                        }

                        case FIT_MESG_NUM_EVENT:
                        {
                            const FIT_EVENT_MESG *event = (const FIT_EVENT_MESG *) mesg;

                            NSDate *dt = [[NSDate alloc] initWithTimeInterval:(NSTimeInterval)event->timestamp
                                                                     sinceDate:refDate];
                            BOOL first = [self setStartDateIfRequired:dt forTrack:track];
                            (void)first;

                            // ensure basis date sanity
                            [self setStartDateIfRequired:dt forTrack:track];
                            [self checkDataPointDeltaBasisDate:dt];

                            if ((event->event == FIT_EVENT_TIMER) &&
                                (event->event_type == FIT_EVENT_TYPE_START))
                            {
                                if (!first && inDeadZone)
                                {
                                    NSTimeInterval activeTimeDelta = 0.0;
                                    [points addObject:[self createDeadZonePoint:dt
                                                                      activeTime:activeTimeDelta
                                                                     isBeginning:NO]];
                                    inDeadZone = NO;
                                }
                            }
                            else if (!nonMovingLap &&
                                     (event->event == FIT_EVENT_TIMER) &&
                                     (event->event_type == FIT_EVENT_TYPE_STOP_ALL) &&
                                     startDate)
                            {
                                inDeadZone = YES;
                                NSTimeInterval activeTimeDelta = 0.0;
                                [points addObject:[self createDeadZonePoint:dt
                                                                  activeTime:activeTimeDelta
                                                                 isBeginning:YES]];
                            }

                            [dt release];
                            break;
                        }

                        case FIT_MESG_NUM_DEVICE_INFO:
                        {
                            const FIT_DEVICE_INFO_MESG *device_info = (const FIT_DEVICE_INFO_MESG *) mesg;

                            if ((device_info->product != FIT_UINT16_INVALID) &&
                                (device_info->device_index == 0))
                            {
                                [track setDeviceID:device_info->product];
                                [track setFirmwareVersion:device_info->software_version];
                                if ((device_info->product == FIT_GARMIN_PRODUCT_FR310XT) ||
                                    (device_info->product == FIT_GARMIN_PRODUCT_FR60))
                                {
                                    [track setUseOrigDistance:YES];
                                    [track setHasExplicitDeadZones:YES];
                                }
                            }
                            break;
                        }

                        case FIT_MESG_NUM_DEVICE_SETTINGS:
                            // ignored
                            break;

                        default:
#if TRACE_PARSING
                            printf("Unknown message: %d\n", mesg_num);
#else
                            (void)mesg_num;
#endif
                            break;
                    }
                    break;
                }

                case FIT_CONVERT_ERROR:
                    NSLog(@"Error converting FIT file");
                    fclose(file);
                    [track release];
                    return NO;

                case FIT_CONVERT_END_OF_FILE:
                    // handled after loop
                    break;

                case FIT_CONVERT_CONTINUE:
                    break;

                default:
                    break;
            }
        } while (convert_return == FIT_CONVERT_MESSAGE_AVAILABLE);
    }

    if (convert_return == FIT_CONVERT_CONTINUE)
    {
        NSLog(@"Unexpected end of FIT file");
        fclose(file);
        [track release];
        return NO;
    }

    if (convert_return == FIT_CONVERT_END_OF_FILE)
    {
        if (startDate == nil)
        {
            // No valid timing; nothing to add
            [track release];
            ret = NO;
        }
        else
        {
            if (!hasDistance)
            {
                [track setOverrideValue:kST_Distance index:kVal value:activityDistance];
            }
            [track setPoints:points];
            [track setHasDeviceTime:YES];
            [track fixupTrack];
            [trackArray addObject:track];
            [track release];   // balanced
            ret = YES;
#if TRACE_PARSING
            NSLog(@"FIT file converted successfully");
#endif
        }
    }

    fclose(file);
    return ret;
}

@end
