//
//  TCX.mm
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "TCX.h"
#import "Utils.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Defs.h"

#define DO_PARSING							1
#define TRACE_DEAD_ZONES        ASCENT_DBG&&0

@implementation TCX


-(void)commonInit
{
	[super init];
	importData = nil;
	xmlURL = nil;
	currentImportTrack = nil;
	currentImportPoint = nil;
	currentImportLap = nil;
	currentImportPointArray = nil;
	haveGoodSpeed = haveGoodAltitude = haveGoodDistance = haveGoodLatLon = NO;
	haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
	inHR = inPoint = inActivity = inLap = isHST = NO;
	currentStringValue = nil;
	distanceSoFar = 0.0;
	lapStartDistance = 0.0;
	lapFirstDistance = 0.0;
	numLapPoints = 0;
    lastLap = nil;
}


-(TCX*) initWithData:(NSData*)data
{
	[self commonInit];
	importData = data;
	return self;
}


-(TCX*) initWithFileURL:(NSURL*)url
{
#if _DEBUG
	NSLog(@"IMPORTING %@", url);
#endif
	[self commonInit];
	xmlURL = url;
	return self;
}


-(void) dealloc
{
}


-(void)setCurrentActivity:(NSString*)a
{
	currentActivity = a;
}


#define BAD_VALUE		(-9999999.0)

-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray
{
	BOOL success = NO;
	currentImportTrackArray = nil;
	currentImportLapArray = nil;
	currentPointStartTime = lastPointStartTime = nil;
	[self setCurrentActivity:[Utils stringFromDefaults:RCBDefaultActivity]];
	[[NSURLCache sharedURLCache] setMemoryCapacity:0];
	[[NSURLCache sharedURLCache] setDiskCapacity:0];	
	NSXMLParser* parser = nil;
	if (importData)
	{
		parser = [[NSXMLParser alloc] initWithData:importData];
	}
	else
	{
		parser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
	}
	[parser setDelegate:self];
	[parser setShouldResolveExternalEntities:NO];
	[parser setDelegate:nil];
	[trackArray addObjectsFromArray:currentImportTrackArray];
	currentImportTrackArray= nil;
	success = YES;
	return success;
}



- (NSDate*) dateFromTimeString:(NSString*) ts
{
	NSRange r;
	r.length = 10;
	r.location = 0;
	NSString* sub = [ts substringWithRange:r];
	NSMutableString* d = [NSMutableString stringWithString:sub];
	r.length = 8;
	r.location = 11;
	NSString* t = [ts substringWithRange:r];
	//NSLog(@"point at %@ %@\n", d, t);
	[d appendString:@" "];
	[d appendString:t];
	[d appendString:@" +0000"];
	return [NSDate dateWithString:d];
}



- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict 
{
	BOOL isActivity = [elementName isEqualToString:@"Activity"] || [elementName isEqualToString:@"Course"] ;
 	///printf("start %s\n", [elementName UTF8String]);
  
	if (isActivity ||
       ([elementName isEqualToString:@"Run"]))        // hst
	{
#if DO_PARSING
		versionMajor = versionMinor = buildMajor = buildMinor = 0;
		inDeadZone = NO;
		inActivity = YES;
		inPoint = NO;
		haveGoodSpeed = haveGoodAltitude = haveGoodDistance = haveGoodLatLon = NO;
		haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
		currentTrackStartTime = currentLapStartTime = currentPointStartTime =  nil;
		ignoreInterval = 0.0;
		lastGoodDistance = 0.0;
		lastSpeed = BAD_VALUE;
		lastAltitude = lastLatitude = lastLongitude = lastHeartRate = lastCadence = lastPower = BAD_VALUE;
		if (currentImportTrack == nil)
		{
			currentImportTrack = [[Track alloc] init];
		}
		if (currentImportTrackArray == nil)
		{
			currentImportTrackArray = [[NSMutableArray alloc] init];
		}
		if (isActivity)
		{
		 NSString *sport = [attributeDict objectForKey:@"Sport"];
		 if (sport != nil)
		 {
			 if ([sport isEqualToString:@"Biking"])
			 {
				 [self setCurrentActivity: [NSString stringWithFormat:@"%s", kCycling]];
			 }
			 else if ([sport isEqualToString:@"Running"])
			 {
				 [self setCurrentActivity: [NSString stringWithFormat:@"%s", kRunning]];
			 }
		 }
		 else
		 {
			 isHST = YES;
		 }
      }
#endif
      return;
   }
   
   if ([elementName isEqualToString:@"Lap"])
   {
#if DO_PARSING
		inPoint = NO;
		inLap = YES;
	   insertDeadZone = NO;
		numLapPoints = 0;
		lapStartDistance = 0.0;
		lapFirstDistance = 0.0;
		currentLapStartTime = nil;
		numTracksWithinLap = 0;
		tracksInLap = 0;
		if (currentImportLap == nil)
		{
			currentImportLap = [[Lap alloc] init];
		}
		if (currentImportLapArray == nil)
		{
			currentImportLapArray = [[NSMutableArray alloc] init];
		}
		NSString *st = [attributeDict objectForKey:@"StartTime"];
		if (st != nil)
		{
			//NSDate* dt = [self dateFromTimeString:st];
			//[currentImportLap setStartTime:dt];
			currentLapStartTime = [self dateFromTimeString:st];
			if (currentTrackStartTime == nil) currentTrackStartTime = currentLapStartTime;
		}
#endif
      return;
   }
   
   if ([elementName isEqualToString:@"Trackpoint"])
   {
#if DO_PARSING
		currentPointStartTime = nil;
		inPoint = YES;
		isDeadMarker = YES;
		if (currentImportPoint == nil)
		{
			currentImportPoint = [[TrackPoint alloc] init];
		}
		if (currentImportPointArray == nil)
		{
			currentImportPointArray = [[NSMutableArray alloc] init];
		}
#endif
		return;
   }
   
	if ([elementName isEqualToString:@"Time"])
	{
#if DO_PARSING
	   currentStringValue = nil;
#endif
		return;
	}
   
	if ([elementName isEqualToString:@"Running"])         // hst
	{
#if DO_PARSING
		[self setCurrentActivity: [NSString stringWithFormat:@"%s", kRunning]];
#endif
		return;
	}
  
	if ([elementName isEqualToString:@"Biking"])          // hst
	{
#if DO_PARSING
		[self setCurrentActivity: [NSString stringWithFormat:@"%s", kCycling]];
#endif
		return;
	}
   
	if ([elementName isEqualToString:@"Track"])
	{
		++tracksInLap;
		if (tracksInLap > 1)
			insertDeadZone = YES;
		return;
	}
	
	
	if (([elementName isEqualToString:@"Value"]) ||
		([elementName isEqualToString:@"AltitudeMeters"]) ||
		([elementName isEqualToString:@"DistanceMeters"]) ||
		([elementName isEqualToString:@"LatitudeDegrees"]) ||
		([elementName isEqualToString:@"LongitudeDegrees"]) ||
		([elementName isEqualToString:@"Cadence"]) ||
		([elementName isEqualToString:@"AvgRunCadence"]) ||
		([elementName isEqualToString:@"MaxRunCadence"]) ||
		([elementName isEqualToString:@"MaxBikeCadence"]) ||
		([elementName isEqualToString:@"TotalTimeSeconds"]) ||
		([elementName isEqualToString:@"Calories"]) ||
		([elementName isEqualToString:@"Speed"]) ||
		([elementName isEqualToString:@"AvgSpeed"]) ||
		([elementName isEqualToString:@"ProductID"]) ||
		([elementName isEqualToString:@"AverageHeartRateBpm"]) ||
		([elementName isEqualToString:@"MaximumHeartRateBpm"]) ||
		([elementName isEqualToString:@"Intensity"]) ||
		([elementName isEqualToString:@"TriggerMethod"]) ||
		([elementName isEqualToString:@"MaximumSpeed"]))
	{
#if DO_PARSING
		isDeadMarker = NO;
		currentStringValue = nil;
#endif
		return;
	}
   
	currentStringValue = nil;
	return;
}


-(void) setCurrentPointStartTime:(NSDate*)dt
{
	if (dt != currentPointStartTime)
	{
		currentPointStartTime = dt;
	}
}

-(void) setLastPointStartTime:(NSDate*)dt
{
	if (dt != lastPointStartTime)
	{
		lastPointStartTime = dt;
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
#if DO_PARSING
  if (!currentStringValue) 
   {
      //currentStringValue = [[NSMutableString alloc] initWithCapacity:50];
	   currentStringValue = [[NSMutableString alloc] init];
   }
   [currentStringValue appendString:string];
#endif
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	//printf("end %s\n", [elementName UTF8String]);
	if (([elementName isEqualToString:@"Activity"]) ||
		([elementName isEqualToString:@"Course"]) ||
	    ([elementName isEqualToString:@"Run"]))        // hst
	{
#if DO_PARSING
		if (currentImportTrack != nil)
		{
			int numPoints = [currentImportPointArray count];
			[currentImportTrack setCreationTime:currentTrackStartTime];
			if (numPoints > 0)
			{
				TrackPoint* pt = [currentImportPointArray objectAtIndex:0];
				//NSDate* cd = [pt date];
				pt = [currentImportPointArray objectAtIndex:(numPoints-1)];
				[currentImportTrack setDistance:lastGoodDistance]; 
				[currentImportTrack setPoints:currentImportPointArray];
				//NSLog(@"importing track %@ with %d laps and %d points.\n", cd, [currentImportLapArray count], [currentImportPointArray count]);
			}
			else
			{
				int numLaps = [currentImportLapArray count];
				if (numLaps > 0)
				{
					NSNumber* totalDist = [currentImportLapArray valueForKeyPath:@"@sum.distance"];		// in FEET
					[currentImportTrack setDistance:[totalDist floatValue]]; 
					if (currentTrackStartTime == nil)
					{
						currentTrackStartTime = [[currentImportLapArray objectAtIndex:0] origStartTime];
						[currentImportTrack setCreationTime:currentTrackStartTime];
					}
				}
			}
			if (currentTrackStartTime == nil)
			{
				currentTrackStartTime = [NSDate date];
			}
 
			[currentImportTrack setFirmwareVersion:(versionMajor * 100) + (versionMinor)];
			[currentImportTrack setHasDeviceTime:YES];
			if (currentActivity != nil) [currentImportTrack setAttribute:kActivity usingString:currentActivity];
			[currentImportTrack fixupTrack];
            if (lastLap)
            {
                NSTimeInterval lapWallClockDuration;
                if ([lastLap distance] == 0.0)
                {
                    // no distance, hence activeTime == wallTime.  Usually indicates non-moving activity
                    lapWallClockDuration = [lastLap deviceTotalTime];
                }
                else
                {
                    // track all clock duration is the time of the last data point.  Doesn't work with non-moving activities
                    lapWallClockDuration = [currentImportTrack duration] - [lastLap startingWallClockTimeDelta];
                }
                [lastLap setTotalTime:lapWallClockDuration];
                lastLap = nil;
            }
			[currentImportTrack setLaps:currentImportLapArray];	// NOTE: must fixup track BEFORE adding laps, for proper active time calculations!!!!
			[currentImportTrackArray addObject:currentImportTrack];
			currentImportPointArray = nil;
			currentImportLapArray = nil;
			currentImportTrack = nil;
            lastLap = nil;
			[self setCurrentPointStartTime:nil];
			[self setLastPointStartTime:nil];
		}
#endif
		inActivity = NO;
		return;
	}

	if ([elementName isEqualToString:@"Lap"])
	{
#if DO_PARSING
	  if (currentImportLap != nil)
	  {
		  if (currentTrackStartTime == nil)
		  {
			  currentTrackStartTime = currentLapStartTime;
			  [currentImportTrack setCreationTime:currentTrackStartTime];
		  }
		  [currentImportLap setOrigStartTime:currentLapStartTime];
		  [currentImportLap setStartingWallClockTimeDelta:[currentLapStartTime timeIntervalSinceDate:currentTrackStartTime]];
          if (lastLap)
          {
              NSTimeInterval lapWallClockDuration;
              if ([lastLap distance] == 0.0)
              {
                  lapWallClockDuration = [lastLap deviceTotalTime];
              }
              else
              {
                  lapWallClockDuration = [currentImportLap startingWallClockTimeDelta] - [lastLap startingWallClockTimeDelta];  
              }
               [lastLap setTotalTime:lapWallClockDuration];
          }
          if (inActivity) [currentImportLapArray addObject:currentImportLap];
          lastLap = currentImportLap;
		  currentImportLap = nil;
		}
#endif
		inLap = NO;
	   return;
	}

	if ([elementName isEqualToString:@"Notes"])
	{
#if DO_PARSING
		if (inActivity) [currentImportTrack setAttribute:kNotes
											 usingString:currentStringValue];
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"Name"])
	{
#if DO_PARSING
		if (inActivity) [currentImportTrack setAttribute:kName
											 usingString:currentStringValue];
#endif
		return;
	}
	

	if ([elementName isEqualToString:@"Trackpoint"])
	{
#if DO_PARSING
		if ((lastPointStartTime == nil) || [lastPointStartTime compare:currentPointStartTime] == NSOrderedAscending)
		{
			if (currentImportPoint != nil)
			{
				if (inActivity)
				{
					NSTimeInterval wallClockDelta = [currentPointStartTime timeIntervalSinceDate:currentTrackStartTime];
					[currentImportPoint setActiveTimeDelta:wallClockDelta];
					if (!isDeadMarker)
					{
						if (!haveGoodAltitude)
						{
							// parsing code sets origAltitude in point, so we only do it here if 
							// altitude was missing iduring point parsing
							float v = (lastAltitude == BAD_VALUE) ? BAD_ALTITUDE : lastAltitude;
							[currentImportPoint setOrigAltitude:v];
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingAltitude
														 state:!haveGoodAltitude];
								
						if (!haveGoodDistance)
						{
							// parsing code sets origDistance in point, so we only do it here if 
							// distance was missing during point parsing
							float v = (lastGoodDistance == BAD_VALUE) ? BAD_DISTANCE : lastGoodDistance;
							[currentImportPoint setOrigDistance:v];
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingDistance
														 state:!haveGoodDistance];
						
						if (!haveGoodLatLon) 
						{
							// parsing code sets lat/lon in point, so we only do it here if 
							// location was missing during point parsing
							float v = (lastLatitude == BAD_VALUE) ? BAD_LATLON : lastLatitude;
							[currentImportPoint setLatitude:v];
							v = (lastLongitude == BAD_VALUE) ? BAD_LATLON : lastLongitude;
							[currentImportPoint setLongitude:v];
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingLocation
														 state:!haveGoodLatLon];
						
						[currentImportPoint setImportFlagState:kImportFlagMissingPower
														 state:!haveGoodPower];
						
						if (lastHeartRate != BAD_VALUE)
						{
							// parsing code sets lastHeartRate if found, DOESNT UPDATE POINT!
							[currentImportPoint setHeartrate:(int)lastHeartRate];	
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingHeartRate
														 state:!haveGoodHeartRate];
						
						if (lastCadence != BAD_VALUE)
						{
							// parsing code sets lastCadence if found, DOESNT UPDATE POINT
							[currentImportPoint setCadence:(int)lastCadence];	
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingCadence
														 state:!haveGoodCadence];
						
						if (lastSpeed != BAD_VALUE) 
						{
							// parsing code sets lastSpeed if found, DOESNT UPDATE POINT!
							[currentImportPoint setSpeed:lastSpeed];
							// only override speed if we've actually had a valid speed point
							// in the Trackpoint section of the activity.  Otherwise the
							// speed can be calculated if we have good GPS points by the
							// track fixup code.
							[currentImportPoint setSpeedOverriden:YES];
						}
						[currentImportPoint setImportFlagState:kImportFlagMissingSpeed
														 state:!haveGoodSpeed];
						
					}
					else
					{
#if TRACE_DEAD_ZONES
						NSLog(@" == DEAD MARKER at %@", currentPointStartTime);
#endif
					}
					++numLapPoints;
					[currentImportPoint setWallClockDelta:wallClockDelta];
					NSTimeInterval dt = [currentPointStartTime timeIntervalSinceDate:lastPointStartTime];
#define MAX_POINT_TIME_DELTA	600.0
					
					if (insertDeadZone || (dt > MAX_POINT_TIME_DELTA))
					{
						if ([currentImportPointArray count] > 0)
						{
							TrackPoint* lastPoint = [currentImportPointArray lastObject];
							while ([currentImportPointArray count] && [lastPoint isDeadZoneMarker])
							{
								[currentImportPointArray removeLastObject];
								lastPoint = [currentImportPointArray lastObject];
							}	
#if TRACE_DEAD_ZONES
							NSString* s = insertDeadZone ? @"NEW TRACK" : @"LARGE DELTA TIME BETWEEN POINTS";
							NSLog(@"Lap %d: %@, INSERTING DEAD ZONE (%0.1f seconds) AT %@ (%0.1f seconds)", 
								  [currentImportLapArray count] + 1, s, dt, currentPointStartTime, wallClockDelta);
#endif
                            // add BEGIN DEAD ZONE point 
							NSTimeInterval lastWCD = [lastPoint wallClockDelta];
							NSTimeInterval lastATD = [lastPoint activeTimeDelta];
							TrackPoint* pt = [[TrackPoint alloc] initWithDeadZoneMarker:lastWCD
																		 activeTimeDelta:lastATD];
                            [pt setBeginningOfDeadZone];
							[pt setImportFlagState:kImportFlagDeadZoneMarker
											 state:YES];
							[currentImportPointArray addObject:pt];
							
                            // and END DEAD ZONE point
                            pt = [[TrackPoint alloc] initWithDeadZoneMarker:wallClockDelta
															 activeTimeDelta:lastATD];
							[pt setImportFlagState:kImportFlagDeadZoneMarker
											 state:YES];
                            [pt setEndOfDeadZone];
							[currentImportPointArray addObject:pt];
						}
						if (insertDeadZone) 
							insertDeadZone = NO;
					}
					[currentImportPointArray addObject:currentImportPoint];
					[self setLastPointStartTime:currentPointStartTime];
				}
			}
		}
donePoint:
		currentImportPoint = nil;
		haveGoodAltitude = haveGoodDistance = haveGoodLatLon = haveGoodSpeed = NO;
		haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
		inPoint = NO;
#endif
		return;
	}
  
	if ([elementName isEqualToString:@"Track"])
	{  
		if (tracksInLap > 1)
			insertDeadZone = YES;
		return;
	}
	
	if ([elementName isEqualToString:@"Time"])
	{  
#if DO_PARSING
		if (inPoint && inActivity && (currentStringValue != nil) && ([currentStringValue length] >= 20))
		{
			if (currentImportPoint != nil)
			{
				[self setCurrentPointStartTime:[self dateFromTimeString:currentStringValue]];
				if (!inLap && (currentTrackStartTime == nil))
				{
					currentTrackStartTime = currentPointStartTime;
				}
			}
		}
#endif
		return;
	}

	
	
	if ([elementName isEqualToString:@"HeartRateBpm"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float hr = [currentStringValue intValue];
			if (currentImportPoint != nil)
			{
				//[currentImportPoint setHeartrate:lastHeartRate];
				lastHeartRate = (float)hr;
				haveGoodHeartRate = YES;
			}
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"Speed"] || [elementName isEqualToString:@"ns3:Speed"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float spd = [currentStringValue floatValue];
			if (currentImportPoint != nil)
			{
				spd = (MetersToMiles(spd))*(60.0 * 60.0);
				lastSpeed = spd;
				haveGoodSpeed = YES;
			}
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"ProductID"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			int prodID = [currentStringValue intValue];
			[currentImportTrack setDeviceID:prodID];
			if ((prodID == PROD_ID_310XT) ||
                (prodID == PROD_ID_FR60))
			{
				[currentImportTrack setUseOrigDistance:YES];
                [currentImportTrack setHasExplicitDeadZones:YES];
			}
		}
#endif
		return;
	}
	
	
	if ([elementName isEqualToString:@"VersionMajor"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			versionMajor = [currentStringValue intValue];
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"VersionMinor"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			versionMinor = [currentStringValue intValue];
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"BuildMajor"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			buildMajor = [currentStringValue intValue];
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"BuildMinor"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			buildMinor= [currentStringValue intValue];
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"DistanceMeters"])
	{
		if (currentStringValue != nil)
#if DO_PARSING
		{
			float val = KilometersToMiles([currentStringValue floatValue]/1000.0);
			if (inPoint && (currentImportPoint != nil))
			{
				if ((numLapPoints == 0) ||                         // start of lap, or...
					(((val == 0.0) && (lastGoodDistance > 0.0))))  // distance reset in the middle of a lap.  Garmin problem?
				{
					lapStartDistance = (val == 0.0) ? lastGoodDistance : val;      // store distance so far of overall activity
					lapFirstDistance  = val;                  // first distance reading this lap, may reset to 0 for some reason
				}
				++numLapPoints;
				distanceSoFar = lapStartDistance + (val - lapFirstDistance); 
				[currentImportPoint setOrigDistance:distanceSoFar];
				haveGoodDistance = YES;
				lastGoodDistance = distanceSoFar;
			}
			else if (inLap && (currentImportLap != nil))
			{
				[currentImportLap setDistance:val];
			}
		}
#endif
		return;
	}

	if ([elementName isEqualToString:@"AltitudeMeters"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float val = MetersToFeet([currentStringValue floatValue]);
			if (currentImportPoint != nil)
			{
				[currentImportPoint setOrigAltitude:val];
				haveGoodAltitude = YES;
				lastAltitude = val;
			}
		}
#endif
		return;
	}

	if ([elementName isEqualToString:@"LatitudeDegrees"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float val = [currentStringValue floatValue];
			if (currentImportPoint != nil)
			{
				[currentImportPoint setLatitude:val];
				lastLatitude = val;
			}
		}
#endif
		return;
	}

	if ([elementName isEqualToString:@"LongitudeDegrees"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float val = [currentStringValue floatValue];
			if (currentImportPoint != nil)
			{
				[currentImportPoint setLongitude:val];
				haveGoodLatLon = YES;
				lastLongitude = val;
			}
		}
#endif
		return;
	}

	if ([elementName isEqualToString:@"Watts"] || [elementName isEqualToString:@"ns3:Watts"] )
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportPoint != nil)
			{
#if _DEBUG
				if (val > MAX_REASONABLE_POWER)
				{
					printf("power value:%d, wtf?\n", val);
				}
#endif
				haveGoodPower = YES;
				[currentImportPoint setPower:val];
			}
		}
#endif
		return;
	}

	if (([elementName isEqualToString:@"Cadence"]) ||
		([elementName isEqualToString:@"RunCadence"]))	// footpod
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (inPoint && currentImportPoint != nil)
			{
				haveGoodCadence = YES;
				lastCadence = (float)val;
				//[currentImportPoint setCadence:val];
				if ([elementName isEqualToString:@"RunCadence"])
				{
					[currentImportPoint setImportFlagState:kImportFlagHasFootpod
													 state:YES];
				}
			}
			else if (inLap && (currentImportLap != nil))
			{
				[currentImportLap setAverageCadence:val];
			}
		}
#endif
		return;
	}
	
	if ([elementName isEqualToString:@"AvgRunCadence"]) 
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportLap != nil)
			{
				[currentImportLap setAverageCadence:val];
			}
		}
#endif
		return;
	}

	
	if ([elementName isEqualToString:@"AvgSpeed"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportLap != nil)
			{
				[currentImportLap setAvgSpeed:val];
			}
		}
#endif
		return;
	}
	
	
	if ([elementName isEqualToString:@"MaxRunCadence"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportLap != nil)
			{
				[currentImportLap setMaxCadence:val];
			}
		}
#endif
		return;
	}
	
	
	if ([elementName isEqualToString:@"MaxBikeCadence"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportLap != nil)
			{
				[currentImportLap setMaxCadence:val];
			}
		}
#endif
		return;
	}
	
	
	if ([elementName isEqualToString:@"TotalTimeSeconds"])
	{
#if DO_PARSING
	  if (currentStringValue != nil)
	  {
		 float val = [currentStringValue floatValue];
		 if (currentImportLap != nil)
		 {
			[currentImportLap setDeviceTotalTime:val];
		 }
	  }
#endif
		return;
	}

	if ([elementName isEqualToString:@"MaximumSpeed"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			float val = [currentStringValue floatValue];      // in meters/sec
			val = (val*60.0*60.0)/1609.344;           // meters/sec to mph
			if (currentImportLap != nil)
			{
				[currentImportLap setMaxSpeed:val];
			}
		}
#endif
		return;
	}

	if ([elementName isEqualToString:@"Calories"])
	{
#if DO_PARSING
		if (currentStringValue != nil)
		{
			int val = [currentStringValue intValue];
			if (currentImportLap != nil)
			{
				[currentImportLap setCalories:val];
			}
		}
#endif
		return;
	}



	if ([elementName isEqualToString:@"AverageHeartRateBpm"])
	{
#if DO_PARSING
	  if (currentStringValue != nil)
	  {
		 int val = [currentStringValue intValue];
		 if (currentImportLap != nil)
		 {
			[currentImportLap setAvgHeartRate:val];
		 }
	  }
#endif
		return;
	}

	if ([elementName isEqualToString:@"MaximumHeartRateBpm"])
	{
#if DO_PARSING
	  if (currentStringValue != nil)
	  {
		 int val = [currentStringValue intValue];
		 if (currentImportLap != nil)
		 {
			[currentImportLap setMaxHeartRate:val];
		 }
	  }
#endif
		return;
	}

	if ([elementName isEqualToString:@"Intensity"])
	{
#if DO_PARSING
	  if (currentStringValue != nil)
	  {
		 int val = [currentStringValue intValue];
		 if (currentImportLap != nil)
		 {
			[currentImportLap setIntensity:val];
		 }
	  }
#endif
		return;
	}

	if ([elementName isEqualToString:@"TriggerMethod"])
	{
#if DO_PARSING
	  if (currentStringValue != nil)
	  {
		 int val = [currentStringValue intValue];
		 if (currentImportLap != nil)
		 {
			[currentImportLap setTriggerMethod:val];
		 }
	  }
#endif
		return;
	}

}



//---- EXPORT ----------------------------------------------------------------------------------------------------

- (NSString*) utzStringFromDate:(NSDate*) dt
                      gmtOffset:(NSTimeInterval)gmtOffset
{
	NSDate* gmtDate = [[NSDate alloc] initWithTimeInterval:-gmtOffset
												sinceDate:dt];
	NSString* s = [gmtDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ"
											   timeZone:nil
												 locale:nil];
	return s;
}


- (BOOL) validHR:(float)hr
{
   return ((hr > 1.0) && (hr < 254.0));
}


-(NSXMLElement*) TPXElement
{
	
	NSXMLElement* tpxElem = [NSXMLNode elementWithName:@"TPX"];
	[tpxElem addAttribute:[NSXMLNode attributeWithName:@"xmlns" 
										   stringValue:@"http://www.garmin.com/xmlschemas/ActivityExtension/v2"]];
	return tpxElem;
}



-(void) addTrackPoints:(Track*)track startTimeDelta:(NSTimeInterval)startTimeDelta startingIndex:(int)idx nextLap:(Lap*)nextLap elem:(NSXMLElement*)lapElem
{
	NSArray* points = [track points];
	NSXMLElement* elem;
	int numPointsInTrack = [points count];
	BOOL hasEverHadSensorData = NO;
	if (numPointsInTrack > 0 && idx >= 0)
	{
		NSXMLElement* trackElem = [NSXMLNode elementWithName:@"Track"];
		//inDeadZone = NO;
		while (idx < numPointsInTrack)
		{
			TrackPoint *pt = [points objectAtIndex:idx];
			//if ((nextLap == 0) || ([[pt date] compare:[nextLap startTime]] == NSOrderedAscending))
			if ((nextLap == 0) || ([pt wallClockDelta] <= [nextLap startingWallClockTimeDelta]))
			{
				NSXMLElement* tpElem = [NSXMLNode elementWithName:@"Trackpoint"];

				elem = [NSXMLNode elementWithName:@"Time"
									stringValue:[self utzStringFromDate:[[track creationTime] addTimeInterval:[pt wallClockDelta]]
															  gmtOffset:[track secondsFromGMTAtSync]]];
				[tpElem addChild:elem];
				BOOL isDeadZoneMarker = [pt importFlagState:kImportFlagDeadZoneMarker] /*|| [pt isDeadZoneMarker]*/;
				if (!isDeadZoneMarker)
				{
					if (([pt latitude] != BAD_LATLON) && ![pt importFlagState:kImportFlagMissingLocation])	// tcx can't tolerate bad GPS values
					{
						NSXMLElement* posElem = [NSXMLNode elementWithName:@"Position"];
						elem = [NSXMLNode elementWithName:@"LatitudeDegrees"
										   stringValue:[NSString stringWithFormat:@"%1.6f", [pt latitude]]];
						[posElem addChild:elem];
						elem = [NSXMLNode elementWithName:@"LongitudeDegrees"
										   stringValue:[NSString stringWithFormat:@"%1.6f", [pt longitude]]];
						[posElem addChild:elem];
						[tpElem addChild:posElem];
					}
					
					///if ([pt origAltitude] == BAD_ALTITUDE) goto next;	// tcx can't tolerate bad altitude values
					if (([pt origAltitude] != BAD_ALTITUDE) && (![pt importFlagState:kImportFlagMissingAltitude])) 
					{
						elem = [NSXMLNode elementWithName:@"AltitudeMeters"
											  stringValue:[NSString stringWithFormat:@"%1.6f", FeetToMeters([pt origAltitude])]];
						[tpElem addChild:elem];
					}
					
					///if ([pt distance] == BAD_DISTANCE) goto next;		// tcx can't tolerate bad distance values
					if (([pt origDistance] != BAD_DISTANCE) && (![pt importFlagState:kImportFlagMissingDistance]))		
					{
						elem = [NSXMLNode elementWithName:@"DistanceMeters"
											  stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([pt origDistance])*1000.0]];
												///stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([pt distance])*1000.0]];
						[tpElem addChild:elem];
					}
					
					float hr = [pt heartrate];
					if ([self validHR:hr] && ![pt importFlagState:kImportFlagMissingHeartRate])
					{
						NSXMLElement* hrElem = [NSXMLNode elementWithName:@"HeartRateBpm"];
						[hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
															  stringValue:@"HeartRateInBeatsPerMinute_t"]];
						elem = [NSXMLNode elementWithName:@"Value"
											  stringValue:[NSString stringWithFormat:@"%1.0f", [pt heartrate]]];
						[hrElem addChild:elem];
						[tpElem addChild:hrElem];
					}
					
					BOOL hasFootpod		= [pt importFlagState:kImportFlagHasFootpod];
					BOOL missingCadence = [pt importFlagState:kImportFlagMissingCadence];
					BOOL missingPower	= [pt importFlagState:kImportFlagMissingPower];
					BOOL missingSpeed	= [pt importFlagState:kImportFlagMissingSpeed];
					if (!missingCadence && !hasFootpod)
					{
						elem = [NSXMLNode elementWithName:@"Cadence"
											  stringValue:[NSString stringWithFormat:@"%1.0f", [pt cadence]]];
						[tpElem addChild:elem];
					}
					BOOL hasSensorData = !missingPower || !missingSpeed || (!missingCadence && hasFootpod);
					if (!hasSensorData && !hasEverHadSensorData)
					{
						elem = [NSXMLNode elementWithName:@"SensorState"
											  stringValue:@"Absent"];
						[tpElem addChild:elem];
					}
				
					if (hasSensorData)
					{
						hasEverHadSensorData = YES;
						NSXMLElement* extElem = [NSXMLNode elementWithName:@"Extensions"];
						
						
						
						BOOL hasCalculatedPower = [track activityIsValidForPowerCalculation];
						if (hasCalculatedPower || [track hasDevicePower])
						{
							NSXMLElement* tpxElem = [self TPXElement];
							elem = [NSXMLNode elementWithName:@"Watts"
												  stringValue:[NSString stringWithFormat:@"%1.0f", [pt power]]];
							[tpxElem addChild:elem];
							[extElem addChild:tpxElem];
						}
						
						if (!missingSpeed)
						{
							NSXMLElement* tpxElem = [self TPXElement];
							[tpxElem addAttribute:[NSXMLNode attributeWithName:@"CadenceSensor" 
																   stringValue:@"Bike"]];
							elem = [NSXMLNode elementWithName:@"Speed"
												  stringValue:[NSString stringWithFormat:@"%1.7f", MilesToKilometers([pt speed])*1000.0/(60.0*60.0)]];	// convert to meters/sec
							[tpxElem addChild:elem];
							[extElem addChild:tpxElem];
						}
						
						if (!missingCadence && hasFootpod)
						{
							NSXMLElement* tpxElem = [self TPXElement];
							[tpxElem addAttribute:[NSXMLNode attributeWithName:@"CadenceSensor" 
																   stringValue:@"Footpod"]];
							elem = [NSXMLNode elementWithName:@"RunCadence"
												  stringValue:[NSString stringWithFormat:@"%1.0f", [pt cadence]]];
							[tpxElem addChild:elem];
							[extElem addChild:tpxElem];
						}
						
						[tpElem addChild:extElem];
					}
					[trackElem addChild:tpElem];
				}
				
				
				if (isDeadZoneMarker)
				{
					int ii = idx+1;
					while (ii < numPointsInTrack)
					{
						TrackPoint *ppt = [points objectAtIndex:ii];
						//if (![ppt isDeadZoneMarker]) break;
						if (![ppt importFlagState:kImportFlagDeadZoneMarker]) break;
						++ii;
					}
					idx = ii-1;
					if ([trackElem childCount] > 0) 
					{
						[lapElem addChild:trackElem];
						if (idx < numPointsInTrack) 
							trackElem = [NSXMLNode elementWithName:@"Track"];
					}
				}
			}
			else
			{
				break;
			}
next:
			++idx;
		}
		if ([trackElem childCount] > 0) [lapElem addChild:trackElem];
	}
}


-(NSXMLElement*) manufactureLap:(Track*)track
{				
	NSXMLElement* lapElem = [NSXMLNode elementWithName:@"Lap"];
	[lapElem addAttribute:[NSXMLNode attributeWithName:@"StartTime"
										   stringValue:[self utzStringFromDate:[track creationTime]
																	 gmtOffset:[track secondsFromGMTAtSync]]]];
	
	NSXMLElement* elem = [NSXMLNode elementWithName:@"TotalTimeSeconds"
										stringValue:[NSString stringWithFormat:@"%1.6f", [track duration]]];
	[lapElem addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"DistanceMeters"
						  stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track distance])*1000.0]];
	[lapElem addChild:elem];
	
	// max speed in m/sec
	elem = [NSXMLNode elementWithName:@"MaximumSpeed"
						  stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track maxSpeed])*1000.0/3600.0]];
	[lapElem addChild:elem];
	
	int cals = [track calories];
	if (IS_BETWEEN(0, cals, 65535))
	{
		elem = [NSXMLNode elementWithName:@"Calories"
							  stringValue:[NSString stringWithFormat:@"%d", cals]];
		[lapElem addChild:elem];
	}
	float avghr = [track avgHeartrate];
	NSXMLElement* hrElem;
	if ([self validHR:avghr])
	{
		hrElem = [NSXMLNode elementWithName:@"AverageHeartRateBpm"];
		[hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
											  stringValue:@"HeartRateInBeatsPerMinute_t"]];
		elem = [NSXMLNode elementWithName:@"Value"
							  stringValue:[NSString stringWithFormat:@"%1.0f", avghr]];
		[hrElem addChild:elem];
		[lapElem addChild:hrElem];
	}
	
	NSTimeInterval junk;
	float maxhr = [track maxHeartrate:&junk];
	if ([self validHR:maxhr])
	{
		hrElem = [NSXMLNode elementWithName:@"MaximumHeartRateBpm"];
		[hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
											  stringValue:@"HeartRateInBeatsPerMinute_t"]];
		elem = [NSXMLNode elementWithName:@"Value"
							  stringValue:[NSString stringWithFormat:@"%1.0f", maxhr]];
		[hrElem addChild:elem];
		[lapElem addChild:hrElem];
	}
	
	elem = [NSXMLNode elementWithName:@"Intensity"
						  stringValue:@"Active"];
	[lapElem addChild:elem];
	
	
	elem = [NSXMLNode elementWithName:@"Cadence"
						  stringValue:[NSString stringWithFormat:@"%1.0f", [track avgCadence]]];
	[lapElem addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"TriggerMethod"
						  stringValue:@"Manual"];
	
	[lapElem addChild:elem];
	return lapElem;
}



- (BOOL) export:(NSArray*)trackArray
{
	NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"TrainingCenterDatabase"];
	//NSString* v = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	//NSMutableString* me = [NSMutableString stringWithString:@"Ascent "];
	//[me appendString:v];
	//[root addAttribute:[NSXMLNode attributeWithName:@"version" 
	//                                    stringValue:@"1.0"]];
	//[root addAttribute:[NSXMLNode attributeWithName:@"creator" 
	//                                    stringValue:me]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns" 
									   stringValue:@"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns:xsi" 
									   stringValue:@"http://www.w3.org/2001/XMLSchema-instance"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xsi:schemaLocation" 
									   stringValue:@"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd"]];

	NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];

	int count = [trackArray count];
	NSXMLElement* folders = [NSXMLNode elementWithName:@"Folders"];
	[root addChild:folders];
	NSXMLElement* activities = [NSXMLNode elementWithName:@"Activities"];
	NSXMLElement* elem;
	for (int i=0; i<count; i++)
	{
		Track* track = [trackArray objectAtIndex:i];
		NSTimeInterval gmtOffset = [track secondsFromGMTAtSync];
		NSXMLElement* activity = [NSXMLNode elementWithName:@"Activity"];
		NSString* atype = @"Other";
		NSString* s = [track attribute:kActivity];
		
		NSRange r = [s rangeOfString:@"Biking"];
		BOOL isBiking = r.location == NSNotFound;
		r = [s rangeOfString:@"Bike"];
		isBiking |= (r.location == NSNotFound);
		r = [s rangeOfString:@"Cycling"];
		isBiking |= (r.location == NSNotFound);
		r = [s rangeOfString:@"Cyclo"];
		isBiking |= (r.location == NSNotFound);
		if ([s isEqualToString:[NSString stringWithUTF8String:kCycling]] ||
			isBiking )
		{
			atype = @"Biking";
		}
		else if ([s isEqualToString:[NSString stringWithUTF8String:kRunning]])
		{
			atype = @"Running";
		}
		[activity addAttribute:[NSXMLNode attributeWithName:@"Sport" 
											  stringValue:atype]];
      
		NSXMLElement* aid = [NSXMLNode elementWithName:@"Id"
										 stringValue:[self utzStringFromDate:[track creationTime]
																   gmtOffset:gmtOffset]];
		[activity addChild:aid];

		NSArray* lapArray = [track laps];
		int numLaps = [lapArray count];
		int lapIdx;
		int idx = 0;
		if (numLaps > 0)
		{
			for (lapIdx=0; lapIdx<numLaps; lapIdx++)
			{
				Lap* lap = [lapArray objectAtIndex:lapIdx];
				Lap* nextLap = 0;
				if (lapIdx < (numLaps-1)) nextLap = [lapArray objectAtIndex:(lapIdx+1)];
				[track calculateLapStats:lap];

				NSXMLElement* lapElem = [NSXMLNode elementWithName:@"Lap"];
				[lapElem addAttribute:[NSXMLNode attributeWithName:@"StartTime"
													stringValue:[self utzStringFromDate:[track lapStartTime:lap]
																			  gmtOffset:gmtOffset]]];

				elem = [NSXMLNode elementWithName:@"TotalTimeSeconds"
								   stringValue:[NSString stringWithFormat:@"%1.6f", [lap deviceTotalTime]]];
				[lapElem addChild:elem];

                float miles = [track distanceOfLap:lap];
				elem = [NSXMLNode elementWithName:@"DistanceMeters"
                                      stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers(miles)*1000.0]];
				[lapElem addChild:elem];

				struct tStatData* statData;

				// max speed in m/sec
				statData = [lap getStat:kST_MovingSpeed];
				elem = [NSXMLNode elementWithName:@"MaximumSpeed"
								   stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers(statData->vals[kMax])*1000.0/3600.0]];
				[lapElem addChild:elem];

				elem = [NSXMLNode elementWithName:@"Calories"
								   stringValue:[NSString stringWithFormat:@"%d", [lap calories]]];
				[lapElem addChild:elem];

				statData = [lap getStat:kST_Heartrate];
				float avghr = statData->vals[kAvg];
				NSXMLElement* hrElem;
				if ([self validHR:avghr])
				{
					hrElem = [NSXMLNode elementWithName:@"AverageHeartRateBpm"];
					[hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
														stringValue:@"HeartRateInBeatsPerMinute_t"]];
					elem = [NSXMLNode elementWithName:@"Value"
										  stringValue:[NSString stringWithFormat:@"%1.0f", avghr]];
					[hrElem addChild:elem];
					[lapElem addChild:hrElem];
				}
			 
				float maxhr = statData->vals[kMax];
				if ([self validHR:maxhr])
				{
					hrElem = [NSXMLNode elementWithName:@"MaximumHeartRateBpm"];
					[hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
														  stringValue:@"HeartRateInBeatsPerMinute_t"]];
					elem = [NSXMLNode elementWithName:@"Value"
										  stringValue:[NSString stringWithFormat:@"%1.0f", maxhr]];
					[hrElem addChild:elem];
					[lapElem addChild:hrElem];
				}
			 
				elem = [NSXMLNode elementWithName:@"Intensity"
								   stringValue:([lap intensity] == 0 ? @"Active" : @"Resting")];
				[lapElem addChild:elem];


				statData = [lap getStat:kST_Cadence];
				elem = [NSXMLNode elementWithName:@"Cadence"
								   stringValue:[NSString stringWithFormat:@"%1.0f", statData->vals[kAvg]]];
				[lapElem addChild:elem];

				elem = [NSXMLNode elementWithName:@"TriggerMethod"
								   stringValue:@"Manual"];

				[lapElem addChild:elem];

				// Track point data for lap starts here
				
				// pick up points *b4* lap start time, if any (sometimes lap seems to start a few seconds AFTER track)
				int delta = (lapIdx == 0) ? 0 : [lap startingWallClockTimeDelta];
				idx = [track findFirstPointAtOrAfterDelta:delta
												  startAt:idx];
				[self addTrackPoints:track
					  startTimeDelta:delta	
					   startingIndex:idx
							 nextLap:nextLap
								elem:lapElem];
				[activity addChild:lapElem];
			} // end of lap loop
		}
		else
		{
			NSXMLElement* lapElem = [self manufactureLap:track];
			[self addTrackPoints:track
				  startTimeDelta:0
				   startingIndex:idx
						 nextLap:nil
							elem:lapElem];
			[activity addChild:lapElem];
			
		}
		NSString* notes = [track attribute:kNotes];
		if (![notes isEqualToString:@""])
		{
			elem = [NSXMLNode elementWithName:@"Notes"
							   stringValue:notes];
			[activity addChild:elem];
		}
		
		int deviceID = [track deviceID];
		if (deviceID != 0)
		{
			NSString* deviceName = [Utils deviceNameForID:deviceID];
			if (deviceName)
			{
				NSXMLElement* el = [NSXMLNode elementWithName:@"Creator"];
				[el addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
												  stringValue:@"Device_t"]];
				elem = [NSXMLNode elementWithName:@"Name"
									  stringValue:deviceName];
				[el addChild:elem];

				elem = [NSXMLNode elementWithName:@"UnitId"
									  stringValue:[NSString stringWithFormat:@"%d", 0]];
				[el addChild:elem];
				
				elem = [NSXMLNode elementWithName:@"ProductID"
									  stringValue:[NSString stringWithFormat:@"%d", deviceID]];
				[el addChild:elem];
				
				
				NSXMLElement* vel = [NSXMLNode elementWithName:@"Version"];
				int version = [track firmwareVersion];
				elem = [NSXMLNode elementWithName:@"VersionMajor"
									  stringValue:[NSString stringWithFormat:@"%d", version/100]];
				[vel addChild:elem];
				
				elem = [NSXMLNode elementWithName:@"VersionMinor"
									  stringValue:[NSString stringWithFormat:@"%d", version%100]];
				
				[vel addChild:elem];
				
				elem = [NSXMLNode elementWithName:@"BuildMajor"
									  stringValue:[NSString stringWithFormat:@"%d", 0]];
				[vel addChild:elem];
				
				elem = [NSXMLNode elementWithName:@"BuildMinor"
									  stringValue:[NSString stringWithFormat:@"%d", 0]];
				[vel addChild:elem];
				
				
				[el addChild:vel];
				
				[activity addChild:el];
			}
		}
		[activities addChild:activity];
	}
	[root addChild:activities];
	
	NSXMLElement* auth = [NSXMLNode elementWithName:@"Author"];
	[auth addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
									  stringValue:@"Application_t"]];
	elem = [NSXMLNode elementWithName:@"Name"
						  stringValue:@"Ascent"];
	[auth addChild:elem];
	
	NSXMLElement* bld = [NSXMLNode elementWithName:@"Build"];
	
	NSXMLElement* ver = [NSXMLNode elementWithName:@"Version"];

	NSString* vmaj = @"0";
	NSString* vmin = @"0";
	NSString* bmaj = @"0";
	NSString* s = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	if (s != nil)
	{  
		NSArray *vItems = [s componentsSeparatedByString:@"."];
		if ([vItems count] >= 3)
		{
			vmaj = [vItems objectAtIndex:0];
			vmin =  [vItems objectAtIndex:1];
			NSArray *bItems = [[vItems objectAtIndex:2] componentsSeparatedByString:@" "];	// any BETA strings must start AFTER a space char
			if ([bItems count] > 0) bmaj = [bItems objectAtIndex:0];
		}
	}
	elem = [NSXMLNode elementWithName:@"VersionMajor"
						  stringValue:vmaj];
	[ver addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"VersionMinor"
						  stringValue:vmin];
	
	[ver addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"BuildMajor"
						  stringValue:bmaj];
	[ver addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"BuildMinor"
						  stringValue:[NSString stringWithFormat:@"%d", 0]];
	[ver addChild:elem];
	
	
	[bld addChild:ver];
	NSString* ty = @"Release";		// GTC requires this, ugh
	elem = [NSXMLNode elementWithName:@"Type"
						  stringValue:ty];
	[bld addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"Time"
						  stringValue:[NSString stringWithFormat:@"%s, %s", __DATE__, __TIME__]];
	[bld addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"Builder"
						  stringValue:@"xcode"];
	[bld addChild:elem];
	
	
	[auth addChild:bld];

	elem = [NSXMLNode elementWithName:@"LangID"
						  stringValue:@"en"];
	[auth addChild:elem];
	
	elem = [NSXMLNode elementWithName:@"PartNumber"
						  stringValue:@"000-00000-00"];
	[auth addChild:elem];
	
	[root addChild:auth];
	
	
	
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLDocumentXMLKind];
	if (![xmlData writeToURL:xmlURL atomically:YES]) 
	{
		NSLog(@"Could not write document out...");
		return NO;
	}   
	return YES;
}




@end
