//
//  GarminFIT.mm
//  Ascent
//
//  Created by Rob Boyer on 2/13/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "GarminFIT.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "fit_convert.h"


#define TRACE_PARSING		ASCENT_DBG&&0
#define TRACE_DEVICE_INFO	ASCENT_DBG&&0

@interface GarminFIT ()
@property(nonatomic, retain) NSDate* startDate;
@property(nonatomic, retain) NSURL* fitURL;
@property(nonatomic, retain) NSDate* refDate;
@property(nonatomic, retain) NSDate* dataPointDeltaBasisDate;
@end


@implementation GarminFIT

@synthesize startDate;
@synthesize fitURL;
@synthesize refDate;
@synthesize dataPointDeltaBasisDate;

-(float)semicirclesToDegrees:(int)semis
{
	return semis * (180.0/(float)(0x7fffffff));
}


-(GarminFIT*)initWithFileURL:(NSURL*)url
{
	self = [super init];
	if (self)
	{
		fitURL = [url retain];
		startDate = nil;
		dataPointDeltaBasisDate = nil;
		NSCalendar* cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
		[cal setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		NSDateComponents *comps = [[[NSDateComponents alloc] init] autorelease];
		[comps setYear:1989];
		[comps setMonth:12];
		[comps setDay:31];
		[comps setHour:0];
		[comps setMinute:0];
		[comps setSecond:0];
		refDate = [[cal dateFromComponents:comps] retain];
		
	}
	return self;
}


-(void) dealloc
{
	[refDate release];
	[fitURL release];
	[startDate release];
	[dataPointDeltaBasisDate release];
	[super dealloc];
}


-(TrackPoint*)createDeadZonePoint:(NSDate*)dt activeTime:(NSTimeInterval)at
{
	TrackPoint* pt = [[[TrackPoint alloc] initWithGPSData:[dt timeIntervalSinceDate:startDate] 
											   activeTime:at
												 latitude:BAD_LATLON 
												longitude:BAD_LATLON 
												 altitude:BAD_ALTITUDE 
												heartrate:0
												  cadence:0
											  temperature:0
													speed:0 
												 distance:BAD_DISTANCE] autorelease];
	return pt;	
}


-(void)setActivityType:(int)fitSport subSport:(int)ss forTrack:(Track*)track
{
	NSString* s = nil;
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
					default:
						break;
						
					case FIT_SUB_SPORT_TREADMILL:
						s = @"Treadmill";
						break;
						
					case FIT_SUB_SPORT_STREET:
						s = @"Street Running";
						break;
						
					case FIT_SUB_SPORT_TRAIL:
						s = @"Trail Running";
						break;
						
					case FIT_SUB_SPORT_TRACK:
						s = @"Track Running";
						break;
				}
			}
			break;

		case FIT_SPORT_CYCLING:
			{
				s = @kCycling;
				switch (ss)
				{
					case FIT_SUB_SPORT_SPIN:
						s = @"Spinning";
						break;
						
					case FIT_SUB_SPORT_INDOOR_CYCLING:
						s = @"Indoor Cycling";
						break;
						
					default:
					case FIT_SUB_SPORT_ROAD:
						break;
						
					case FIT_SUB_SPORT_MOUNTAIN:
						s = @"Mountain Biking";
						break;
						
					case FIT_SUB_SPORT_DOWNHILL:
						s = @"Downhill";
						break;
						
					case FIT_SUB_SPORT_RECUMBENT:
						s = @"Recumbent";
						break;
						
					case FIT_SUB_SPORT_CYCLOCROSS:
						s = @"Cyclocross";
						break;
						
					case FIT_SUB_SPORT_HAND_CYCLING:
						s = @"Hand Cycling";
						break;
				}
			}
			break;

		case FIT_SPORT_TRANSITION:
			break;

		case FIT_SPORT_FITNESS_EQUIPMENT:
			{
				s = @"Equipment";
				switch (ss)
				{
					default:
						break;
						
					case FIT_SUB_SPORT_INDOOR_ROWING:
						s = @"Rowing";
						break;
						
					case FIT_SUB_SPORT_ELLIPTICAL:
						s = @"Elliptical";
						break;
						
					case FIT_SUB_SPORT_STAIR_CLIMBING:
						s = @"Stair Climbing";
						break;
				}
			}
			break;
		
		case FIT_SPORT_SWIMMING:                                  
			{
				s = @"Swimming";
				switch (ss)
				{
					default:
						break;
						[track setAttribute:kActivity
						usingString:@"Swimming"];
					
					case FIT_SUB_SPORT_LAP_SWIMMING:
						s = @"Lap Swimming";
						break;
						
					case FIT_SUB_SPORT_OPEN_WATER:
						s = @"Open Water Swimming";
						break;
				}
			}
			break;
	}
	if (s) 
		[track setAttribute:kActivity
				usingString:s];
}


-(BOOL)setStartDateIfRequired:(NSDate*)dt
                     forTrack:(Track*)track
{
	BOOL ret = NO;
	if (!startDate)
	{
		[track setCreationTime:dt];
		self.startDate = dt;
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
	

// calculating the proper start time and point delta times are difficult.  Current algorithm:
// if start time not set and SESSION record found, use start session time for start time
// if LAP record found, AND DELTA BASIS TIME not set use LAP END TIME as basis for delta basis time but DON'T ADJUST start time
// if EVENT record found, and time is less than start session time, reset start session time AND basis for point deltas to that value delta (basis time)
// if point RECORD found and start time not set, use point time as start session time
// if point RECORD found and basis time not set, use first point as basis time

-(BOOL)import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray
{
	BOOL ret = NO;

	FILE *file;
	FIT_UINT8 buf[8];
	FIT_CONVERT_RETURN convert_return = FIT_CONVERT_CONTINUE;
	FIT_UINT32 buf_size;
	
	FitConvert_Init(FIT_TRUE);
	
	NSString* fitPath = [fitURL path];
	if (!fitPath)
	{
		return NO;
	}
	
	if((file = fopen([fitPath UTF8String], "rb")) == NULL)
	{
		NSLog(@"Error opening file %@", fitPath);
		return NO;
	}
	
	Track* track = [[[Track alloc] init] autorelease];
	NSMutableArray* points = [NSMutableArray arrayWithCapacity:256];
	self.dataPointDeltaBasisDate = nil;
    self.startDate = nil;
	int numLaps = 0;
	BOOL inDeadZone = NO;
	BOOL hasDistance = NO;
	float activityDistance = 0.0;
	//float lastLat = BAD_LATLON;
	//float lastLon = BAD_LATLON;
	while(!feof(file) && (convert_return == FIT_CONVERT_CONTINUE))
	{
		for(buf_size=0;(buf_size < sizeof(buf)) && !feof(file); buf_size++)
		{
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
					
					switch(mesg_num)
					{
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
                            
                            lastGoodDistance = 0.0;
                            lastHeartRate = 0.0;
                            lastCadence = 0.0;
                            lastPower = 0.0;
                            lastSpeed = 0.0;
                            lastAltitude = BAD_ALTITUDE;
                            lastLatitude = BAD_LATLON;
                            lastLongitude = BAD_LATLON;

#if TRACE_PARSING
							const FIT_ACTIVITY_MESG *activity = (FIT_ACTIVITY_MESG *) mesg;
							NSDate* dt = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)activity->timestamp
																	 sinceDate:refDate] autorelease];
							NSDate* localTime = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)activity->local_timestamp
																			 sinceDate:refDate] autorelease];
							NSLog(@"Activity time: %@ local_timestamp:%@ total_seconds:%lu type=%u, event=%u, event_type=%u, num_sessions=%u", 
								   dt, localTime, activity->total_timer_time/1000, activity->type, activity->event, activity->event_type, activity->num_sessions); 
#endif
							{
								FIT_ACTIVITY_MESG old_mesg;
								old_mesg.num_sessions = 1;
								FitConvert_RestoreFields(&old_mesg);
#if TRACE_PARSING
								printf("Restored num_sessions=1 - Activity: timestamp=%lu, type=%u, event=%u, event_type=%u, num_sessions=%u\n", 
									   activity->timestamp, activity->type, activity->event, activity->event_type, activity->num_sessions); 
#endif
							}
							break;
						}
							
						case FIT_MESG_NUM_SESSION:
						{
							const FIT_SESSION_MESG *session = (FIT_SESSION_MESG *) mesg;
							[self setActivityType:session->sport
										 subSport:session->sub_sport
										 forTrack:track];
							NSDate* dt = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)session->start_time
																	 sinceDate:refDate] autorelease];
							[self setStartDateIfRequired:dt
                                                forTrack:track];
							if (FIT_UINT32_INVALID != session->total_distance)
							{
								activityDistance = MetersToMiles(session->total_distance/100.0);
							}
#if TRACE_PARSING
							NSDate* et = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)session->timestamp
																	 sinceDate:refDate] autorelease];
							NSLog(@"Session: %@ => %@, distance:%0.1f, num_laps:%d, first_lap_index:%d, sport:%d, calories%d, total_time:%lu elapsed_time:%lu", 
									dt, et, activityDistance, session->num_laps, session->first_lap_index, session->sport, session->total_calories, session->total_timer_time, session->total_elapsed_time); 
#endif
							break;
						}
							
						case FIT_MESG_NUM_LAP:
						{
							const FIT_LAP_MESG *lap = (FIT_LAP_MESG *) mesg;
							NSDate* start = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)lap->start_time
																		sinceDate:refDate] autorelease];
							NSDate* dt = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)lap->timestamp
																	 sinceDate:refDate] autorelease];
#if TRACE_PARSING
							NSLog(@"Lap: %@ => %@, event:%d event_type:%d event_group:%d, total_time:%lu, elapsed_time:%lu distance:%lu", 
                                  start, dt, lap->event, lap->event_type, lap->event_group, lap->total_timer_time, lap->total_elapsed_time, lap->total_distance); 
#endif
							////[self checkDataPointDeltaBasisDate:dt]; 
							
                            float blat = BAD_LATLON;
							float elat = BAD_LATLON;
							float blon = BAD_LATLON;
							float elon = BAD_LATLON;
							if ((lap->start_position_lat != 0x7FFFFFFF) && (lap->start_position_long != 0x7FFFFFFF))
							{
								blat = [self semicirclesToDegrees:lap->start_position_lat];
								blon = [self semicirclesToDegrees:lap->start_position_long];
							}
							if ((lap->end_position_lat != 0x7FFFFFFF) && (lap->end_position_long != 0x7FFFFFFF))
							{
								elat = [self semicirclesToDegrees:lap->end_position_lat];
								elon = [self semicirclesToDegrees:lap->end_position_long];
							}
							float distance = 0.0;	
                            if (lap->total_distance != FIT_UINT32_INVALID)
                            {
                                distance = MetersToMiles((float)lap->total_distance/100.0);		// stored as 100 * m
                            }
							float max_speed = 0.0;
                            if (FIT_UINT16_INVALID != lap->max_speed)
                            {
                                max_speed = MetersToMiles(((float)lap->max_speed)/(1000.0*60.0));	// stored as 1000 * m/s
                            }
							int avg_heartrate = 0;
                            if (FIT_UINT8_INVALID != lap->avg_heart_rate)
                            {
                                avg_heartrate = (int)lap->avg_heart_rate;
                            }
 							int max_heartrate = 0;
                            if (FIT_UINT8_INVALID != lap->max_heart_rate)
                            {
                                max_heartrate = (int)lap->max_heart_rate;
                            }
                            int avg_cadence = 0;
                            if (FIT_UINT8_INVALID != lap->avg_cadence)
                            {
                                avg_cadence = (int)lap->avg_cadence;
                            }
							NSTimeInterval startSecs = [start timeIntervalSince1970];
							Lap* ascentLap = [[[Lap alloc] initWithGPSData:numLaps++ 
													startTimeSecsSince1970:(time_t)startSecs 
																 totalTime:((NSTimeInterval)lap->total_elapsed_time)*100.0/1000.0 // ms to centiseconds
															 totalDistance:distance
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
																   trigger:lap->lap_trigger] autorelease];
							[lapArray addObject:ascentLap];
							break;
						}
                            
						case FIT_MESG_NUM_RECORD:
						{
							const FIT_RECORD_MESG *record = (FIT_RECORD_MESG *) mesg;
							
							if ((record->altitude == FIT_UINT16_INVALID) &&
								(record->speed == FIT_UINT16_INVALID) &&
								(record->distance == FIT_UINT32_INVALID) &&
								(record->heart_rate == FIT_UINT8_INVALID) &&
								(record->cadence == FIT_UINT8_INVALID) &&
								(record->temperature == FIT_SINT8_INVALID)) continue;
							
							NSTimeInterval ti = (NSTimeInterval) record->timestamp;
							NSDate* origdt = [[[NSDate alloc] initWithTimeInterval:ti
                                                                         sinceDate:refDate] autorelease];
							
							[self setStartDateIfRequired:origdt
												forTrack:track];
							[self checkDataPointDeltaBasisDate:origdt];
						
							NSTimeInterval activeTimeDelta = 0.0;
                            NSDate* dt = origdt;
							if (dataPointDeltaBasisDate)
							{
								activeTimeDelta = [dt timeIntervalSinceDate:dataPointDeltaBasisDate];
	                            dt = [startDate dateByAddingTimeInterval:activeTimeDelta];
							}
							if (activeTimeDelta >= 0.0)
							{
                                //---- position --------------------------------
								float lat = BAD_LATLON;
								float lon = BAD_LATLON;
								if ((record->position_lat != 0x7FFFFFFF) && (record->position_long != 0x7FFFFFFF))
								{
									lat = [self semicirclesToDegrees:record->position_lat];
									lon = [self semicirclesToDegrees:record->position_long];
								}
								float filteredLat = lat;
								float filteredLon = lon;
#if 0
								// interesting experiment, but didn't seem to help much, and made
								// speed spikes actually worse!
								if ((lat != BAD_LATLON) && (lon != BAD_LATLON))
								{
									if (lastLat != BAD_LATLON)
									{
										filteredLat = lastLat + (0.5 * (lat - lastLat));
										filteredLon = lastLon + (0.5 * (lon - lastLon));
									}
									lastLat = lat;
									lastLon = lon;
								}
#endif
                                //---- altitude --------------------------------
								float altitude = BAD_ALTITUDE;
                                bool hasAltitude = record->altitude != FIT_UINT16_INVALID;
								if (hasAltitude)
								{
									float alt = (((float)record->altitude)/5.0) - 500.0;				// stored as 5.0 * (m + 500.0)
									altitude = lastAltitude = MetersToFeet(alt) ;
									
								}
                                else
                                {
                                    altitude = lastAltitude;
                                }
                                
                                
                                //---- speed -----------------------------------
								float speed = 0.0;
                                bool hasSpeed = FIT_UINT16_INVALID != record->speed;
								if (hasSpeed)
								{
									speed = MetersToMiles(((float)record->speed)/(1000.0*60.0));	// stored as 1000 * m/s
                                    lastSpeed = speed;
 								}
                                 
                                
                                //---- distance --------------------------------
								float distance = 0.0;	
                                hasDistance = record->distance != FIT_UINT32_INVALID;
								if (hasDistance)
								{
									distance = lastGoodDistance = MetersToMiles((float)record->distance/100.0);		// stored as 100 * m
 								}
                                else
                                {
                                    distance = lastGoodDistance;
                                }

                                
                                //---- compressed speed + distance -------------
                                 if ((!hasSpeed) &&
									((record->compressed_speed_distance[0] != FIT_BYTE_INVALID) ||
									 (record->compressed_speed_distance[1] != FIT_BYTE_INVALID) ||
									 (record->compressed_speed_distance[2] != FIT_BYTE_INVALID)))
								{
									static FIT_UINT32 accumulated_distance16 = 0;
									static FIT_UINT32 last_distance16 = 0;
									FIT_UINT16 speed100;
									FIT_UINT32 distance16;
									speed100 = record->compressed_speed_distance[0] | ((record->compressed_speed_distance[1] & 0x0F) << 8);
									distance16 = (record->compressed_speed_distance[1] >> 4) | (record->compressed_speed_distance[2] << 4);
									accumulated_distance16 += (distance16 - last_distance16) & 0x0FFF;
									last_distance16 = distance16;
									speed = MetersToMiles(speed100/100.0f);
                                    lastSpeed = speed;
									distance = lastGoodDistance = MetersToMiles(accumulated_distance16/16.0f);
                                    hasSpeed = YES;
                                    hasDistance = YES;
								}
								
   
                                //---- heart rate ------------------------------
                                int heartrate = 0;
								if (FIT_UINT8_INVALID != record->heart_rate)
								{
									heartrate = (int)record->heart_rate;
								}
								
                                
                                //---- cadence ---------------------------------
                                int cadence = 0;
								if (FIT_UINT8_INVALID != record->cadence)
								{
									cadence = (int)record->cadence;
								}
                                
                                
                                //---- temperature -----------------------------
								float temp = 0.0;
								if (FIT_SINT8_INVALID != record->temperature)
								{
									temp = CelsiusToFahrenheight((float)record->temperature);
								}
								
                                TrackPoint* pt = [[[TrackPoint alloc] initWithGPSData:[dt timeIntervalSinceDate:startDate] 
																		   activeTime:activeTimeDelta
																			 latitude:filteredLat 
																			longitude:filteredLon 
																			 altitude:altitude
																			heartrate:heartrate
																			  cadence:cadence
																		  temperature:temp
																				speed:speed 
																			 distance:distance] autorelease];	
                                
                                // ---- set flags for missing data items -------
                                if (lastSpeed >= 0.0) 
                                {
                                    // parsing code sets lastSpeed if found, DOESNT UPDATE POINT!
                                    printf("speed: has: %s %0.7f last: %0.7f\n", hasSpeed ? "YES" : "NO", speed, lastSpeed);
                                    [pt setSpeed:lastSpeed];
                                    // only override speed if we've actually had a valid speed point
                                    // in the Trackpoint section of the activity.  Otherwise the
                                    // speed can be calculated if we have good GPS points by the
                                    // track fixup code.
                                    [pt setSpeedOverriden:YES];
                                }
                                
 
                                [pt setImportFlagState:kImportFlagMissingDistance
                                                 state:!hasDistance];

                                [pt setImportFlagState:kImportFlagMissingSpeed
                                                 state:!hasSpeed];
                                
                                [pt setImportFlagState:kImportFlagMissingAltitude
                                                 state:!hasAltitude];
                                
                                
                                //---- power -----------------------------------
								if (record->power != FIT_UINT16_INVALID) 
                                {
                                   [pt setPower:(float)record->power]; 
                                }
								
                                [points addObject:pt];
#if TRACE_PARSING
								if (activeTimeDelta == 0.0)
								{
									printf("*** DUPLICATE TIME ***\n");
								}
								NSLog(@"Record: date:%@ (remapped to %@), delta:%0.1f distance:%0.1f, speed:%0.1f hr:%d cad:%d temp:%0.1f loc:[%0.5f,%0.5f] altitude:%0.1f", 
									  origdt, dt, activeTimeDelta, distance, speed, heartrate, cadence, temp, lat, lon, altitude);
#endif
                                
 							}
							break;
						}
							
						case FIT_MESG_NUM_EVENT:
						{
							const FIT_EVENT_MESG *event = (FIT_EVENT_MESG *) mesg;
							NSDate* dt = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)event->timestamp
																	 sinceDate:refDate] autorelease];
							BOOL first = [self setStartDateIfRequired:dt
															 forTrack:track];

                            // if this event has a time *earlier* than the last time, then we reset last active time
                            // to the earlier time.  This seems to be a bug in the FIT files generated by the FR60 --
                            // sometimes they start generating points with times in the future, then an event resets
                            // the time to the correct value.
                            NSTimeInterval activeTimeDelta = 0.0;
							
							[self setStartDateIfRequired:dt
												forTrack:track];
							[self checkDataPointDeltaBasisDate:dt];
    							
                            if ((event->event == FIT_EVENT_TIMER) &&
								(event->event_type == FIT_EVENT_TYPE_START))
							{
								if (!first && inDeadZone)
								{
									// starting after a deadZone
#if TRACE_PARSING
									NSLog(@"==== ended dead zone at %@, lastActiveTime:%@ ====", dt, dataPointDeltaBasisDate);
#endif
									NSTimeInterval activeTimeDelta = 0.0;
									[points addObject:[self createDeadZonePoint:dt
																	 activeTime:activeTimeDelta]];
								}
							}
							else if ((event->event == FIT_EVENT_TIMER) &&
									 (event->event_type == FIT_EVENT_TYPE_STOP_ALL) &&
									 startDate)
							{
								inDeadZone = YES;
#if TRACE_PARSING
								NSLog(@"==== started dead zone at %@, lastActiveTime:%@  delta:%0.1f ========", 
                                      dt, dataPointDeltaBasisDate, activeTimeDelta);
#endif
								[points addObject:[self createDeadZonePoint:dt
																 activeTime:activeTimeDelta]];
							}
#if TRACE_PARSING
							NSLog(@"Event: date:%@ event:%d type:%d group:%d", dt, event->event, event->event_type, event->event_group);
#endif
							break;
						}
							
#if 0
						// rcb -- wtf is this?  not defined anywhere...?
						case FIT_MESG_NUM_SOURCES:
						{
							const FIT_SOURCES_MESG *sources = (FIT_SOURCES_MESG *) mesg;
							printf("Sources: timestamp=%u\n", sources->timestamp); 
							break;
						}
#endif
							
						case FIT_MESG_NUM_DEVICE_INFO:
						{
							const FIT_DEVICE_INFO_MESG *device_info = (FIT_DEVICE_INFO_MESG *) mesg;
#if TRACE_DEVICE_INFO
							NSDate* dt = [[[NSDate alloc] initWithTimeInterval:(NSTimeInterval)device_info->timestamp
																	 sinceDate:refDate] autorelease];
							NSLog(@"Device date:%@ manufacturer:%d serial#:%lu product:%d swvers:%d dev_index:%d dev_type:%d hw_vers:%d", 
								  dt, device_info->manufacturer, device_info->serial_number, device_info->product, 
								  device_info->software_version, device_info->device_index, device_info->device_type,
								  device_info->hardware_version); 
#endif
                            // hpefully, device_index == 0 for the main device  
							if ((device_info->product != FIT_UINT16_INVALID) && (device_info->device_index == 0))
							{
								NSLog(@"SETTING PRODUCT DEVICE ID TO: %d", device_info->product);
								[track setDeviceID:device_info->product];
								[track setFirmwareVersion:device_info->software_version];
                                if (device_info->product == PROD_ID_310XT)
                                {
                                    [track setUseOrigDistance:YES];
                                }
							}
							break;
						}
							
						case FIT_MESG_NUM_DEVICE_SETTINGS:
						{
#if TRACE_PARSING
							const FIT_DEVICE_SETTINGS_MESG *device_settings = (FIT_DEVICE_SETTINGS_MESG *) mesg;
							printf("Device Settings: timestamp=%lu\n", device_settings->utc_offset); 
#endif
							break;
						}
							
						default:
#if TRACE_PARSING
							printf("Unknown\n");
#endif
							break;
					}
					break;
				}
					
				case FIT_CONVERT_ERROR:
					NSLog(@"Error converting FIT file");
					fclose(file);
					return NO;
					
				case FIT_CONVERT_END_OF_FILE:
				case FIT_CONVERT_CONTINUE:
				default:
					break;
			}
		} while (convert_return == FIT_CONVERT_MESSAGE_AVAILABLE);
	}
	
	if (convert_return == FIT_CONVERT_CONTINUE)
	{
		NSLog(@"Unexpected end of FIT file");
		fclose(file);
		return 1;
	}
	
	if (convert_return == FIT_CONVERT_END_OF_FILE)
	{
		if (startDate == nil)
		{
			printf("wtf?\n");
		}
		else
		{
			if (!hasDistance)
			{
				[track setOverrideValue:kST_Distance
								  index:kVal 
								  value:activityDistance];
			}
			[track setPoints:points];
			[track fixupTrack];
			[trackArray addObject:track];
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
