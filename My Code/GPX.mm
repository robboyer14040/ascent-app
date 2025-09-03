//
//  GPX.mm
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "GPX.h"
#import "Utils.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Defs.h"
#import "ImportDateEntryController.h"

@implementation GPX

-(GPX*) initGPXWithFileURL:(NSURL*)url  windowController:(NSWindowController*)wc
{
   //NSLog(@"import GPX: %@\n", url);
   self = [super init];
   xmlURL = url;
   [xmlURL retain];
   currentImportTrack = nil;
   currentImportPoint = nil;
   currentImportLap = nil;
   currentImportPointArray = nil;
   currentTrackName = nil;
   parentWindowController = wc;
   inPoint = inActivity = inLap = inTrack = NO;
   currentStringValue = nil;
   return self;
}


-(void) dealloc
{
    [parser release];
    [xmlURL release];
    [super dealloc];
}


// this code is very similar to the code executed during sync, currently in TrackBrowserDocument.mm
-(void) processLapData:(NSMutableArray*)laps
{
    NSUInteger lapCount = [laps count];
    NSUInteger numTracks = [currentImportTrackArray count];
	if ((numTracks > 0) && (lapCount > 0))
	{
		int lapIndex = 0;
		NSDate* earliestTrackDate = [[currentImportTrackArray objectAtIndex:0] creationTime];
		int trackIndex = (int)[currentImportTrackArray count] - 1;
		Lap* lap = [laps objectAtIndex:lapIndex];
		while ((trackIndex >= 0) && (lapIndex < lapCount))
		{
			if ([[lap origStartTime] compare:earliestTrackDate] == NSOrderedAscending) break;
			Track* track = [currentImportTrackArray objectAtIndex:trackIndex];
			//NSLog(@"TRACK %d at %@", trackIndex, [track creationTime]);
			BOOL lapIsInTrack = [track isDateDuringTrack:[lap origStartTime]];
			//NSLog(@"  checking lap %d %@", lapIndex, [lap origStartTime]);
			// while lap start time is > track start time, go to the next lap (Laps are assumed to be in DESCENDING order)
			while (!lapIsInTrack && ([[lap origStartTime] compare:[track creationTime]] == NSOrderedDescending) && (lapIndex < (lapCount-1)))
			{
				++lapIndex;
				lap = [laps objectAtIndex:lapIndex];
				//NSLog(@"  -->checking lap %d %@", lapIndex, [lap origStartTime]);
				lapIsInTrack = [track isDateDuringTrack:[lap origStartTime]];
			}
			while ((lapIndex < lapCount) && ([track isDateDuringTrack:[lap origStartTime]] || [lap isOrigDateDuringLap:[track creationTime]]))
			{
				// lap may start b4 first data point in track (especially if satellites not acquired)
				// so adj track start if so...
				[lap setStartingWallClockTimeDelta:[[lap origStartTime] timeIntervalSinceDate:[track creationTime]]];
				//printf("adding lap %d to track %d\n", lapIndex, trackIndex);
				[track addLapInFront:lap];	// must do this AFTER setting the start time delta!!!!!
				if ([[lap origStartTime] compare:[track creationTime]] == NSOrderedAscending)
				{
					[track setCreationTime:[lap origStartTime]];
				}
				++lapIndex;
				if ((lapIndex >= 0) && (lapIndex < [laps count]))
				{
					lap = [laps objectAtIndex:lapIndex];
				}
				else
					break;
			}
			--trackIndex;
		}
	} 
}


-(void)doNothing:(int)v
{
}


-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray
{
	importTrackArray = trackArray;
	activityStartDate = nil;
	BOOL success = NO;
	skipTrack = NO;
	summarySetter = (tLapAvgMaxSetter)[GPX instanceMethodForSelector:@selector(doNothing:)];
	currentImportTrackArray = nil;
	currentImportLapArray = nil;
	currentActivity = [[Utils stringFromDefaults:RCBDefaultActivity] retain];
	parser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
	[parser setDelegate:self];
	[parser setShouldResolveExternalEntities:YES];
	[parser parse];
	if (currentImportLapArray)
	{
		[currentImportTrackArray sortUsingSelector:@selector(compareByDate:)];
		[currentImportLapArray sortUsingSelector:@selector(reverseCompareByOrigStartTime:)];
		[self processLapData:currentImportLapArray];
	}
	[trackArray addObjectsFromArray:currentImportTrackArray];
	success = YES;
	return success;
}


-(void) setActivityStartDate:(NSDate*)dt
{
	if (activityStartDate != dt)
	{
		activityStartDate = dt;
	}
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

-(void) startTrack
{
	inActivity = YES;
	inPoint = NO;
	if (currentImportTrack == nil)
	{
		currentImportTrack = [[Track alloc] init];
	}
	if (currentImportTrackArray == nil)
	{
		currentImportTrackArray = [[NSMutableArray alloc] init];
	}
	if (currentImportLapArray == nil)
	{
		currentImportLapArray = [[NSMutableArray alloc] init];
	}
}



- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict 
{
	//NSLog(@"START element:%@", elementName);
	if ([elementName isEqualToString:@"trk"] ||
		[elementName isEqualToString:@"rte"])
	{
		skipTrack = NO;
		inTrack = YES;
		inLap = NO;
		pointsHaveTime = NO;
		haveActivityStartTime = NO;
		[self setActivityStartDate:nil];
		if ([elementName isEqualToString:@"rte"])
		{
			[self startTrack];
		}
		return;
	}

	if ([elementName isEqualToString:@"trkseg"])
	{
		[self startTrack];
		return;
	}

	if ([elementName isEqualToString:@"trkpt"] ||
	    [elementName isEqualToString:@"rtept"])
	{
		distanceExtensionFound = NO;
		inPoint = YES;
		inLap = NO;
		pointStartDate = nil;
		if (currentImportPoint == nil)
		{
		 currentImportPoint = [[TrackPoint alloc] init];
		}
		if (currentImportPointArray == nil)
		{
		 currentImportPointArray = [[NSMutableArray alloc] init];
		}
		NSString *s = [attributeDict objectForKey:@"lat"];
		float lat, lon;
		if (s != nil)
		{
			lat = [s floatValue];
			s = [attributeDict objectForKey:@"lon"];
			if (s != nil)
			{
				lon = [s floatValue];
				[currentImportPoint setLatitude:lat];
				[currentImportPoint setLongitude:lon];
			}
		}
		return;
	}
	
   	if ([elementName isEqualToString:@"gpxdata:lap"])
	{
		inPoint = NO;
		inLap = YES;
		//numLapPoints = 0;
		//lapStartDistance = 0.0;
		//lapFirstDistance = 0.0;
		//currentLapStartTime = nil;
		if (currentImportLap == nil)
		{
			currentImportLap = [[Lap alloc] init];
		}
		if (currentImportLapArray == nil)
		{
			currentImportLapArray = [[NSMutableArray alloc] init];
		}
		return;
	}

	if ([elementName isEqualToString:@"startPoint"])
	{
		if (inLap && (currentImportLap != nil))
		{
			NSString *s = [attributeDict objectForKey:@"lat"];
			if (s != nil) [currentImportLap setBeginLatitude:[s floatValue]];
			 s = [attributeDict objectForKey:@"lon"];
			if (s != nil) [currentImportLap setBeginLongitude:[s floatValue]];
		}
	}
	
	if ([elementName isEqualToString:@"endPoint"])
	{
		if (inLap && (currentImportLap != nil))
		{
			NSString *s = [attributeDict objectForKey:@"lat"];
			if (s != nil) [currentImportLap setEndLatitude:[s floatValue]];
			s = [attributeDict objectForKey:@"lon"];
			if (s != nil) [currentImportLap setEndLongitude:[s floatValue]];
		}
	}
	
	if ([elementName isEqualToString:@"summary"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			summarySetter = (tLapAvgMaxSetter)[GPX instanceMethodForSelector:@selector(doNothing:)];
			
			// averages and max values are calculated by ascent, but we store them here anyway
			NSString* kind = [attributeDict objectForKey:@"kind"];
			NSString* name = [attributeDict objectForKey:@"name"];
			if ([kind isEqualToString:@"avg"])
			{
				if ([name isEqualToString:@"cadence"])
				{
					summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAverageCadence:)];
				}
				else if ([name isEqualToString:@"hr"])
				{
					summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAvgHeartRate:)];
				}
                else if ([name isEqualToString:@"power"])
                {
                    /// FIXME! summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAvgPower:)];
                }
			}
			else if ([kind isEqualToString:@"max"])
			{
				if ([name isEqualToString:@"speed"])
				{
					summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setMaxSpeed:)];
				}
			}
				
		}
	}
	
	if ([elementName isEqualToString:@"trigger"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			int val = 0;
			NSString*s = [attributeDict objectForKey:@"kind"];
			if ([s isEqualToString:@"manual"])
			{
				val = 0;
			}
			else if ([s isEqualToString:@"distance"])
			{
				val = 1;
			}
			else if ([s isEqualToString:@"location"])
			{
				val = 2;
			}
			else if ([s isEqualToString:@"time"])
			{
				val= 3;
			}
			else if ([s isEqualToString:@"heart_rate"])
			{
				val = 4;
			}
			[currentImportLap setTriggerMethod:val];
		}
	}
	
	
	if (([elementName isEqualToString:@"time"]) ||
	    ([elementName isEqualToString:@"ele"] ) ||
	    ([elementName isEqualToString:@"name"]) ||
	    ([elementName isEqualToString:@"desc"]))
	 {
		 currentStringValue = nil;
		 return;
	 }
   
	currentStringValue = nil;
	return;
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
   if (!currentStringValue) 
   {
      currentStringValue = [[NSMutableString alloc] initWithCapacity:50];
   }
   [currentStringValue appendString:string];
}


- (NSDate*) getStartTime
{
   NSDate* dt = [NSDate date];
   NSString* tn = currentTrackName;
   if ((tn == nil) ||
       ([tn isEqualToString:@""]))
   {
      tn = @"unknown";
   }
   if (activityStartDate == nil)
   {
	   [self setActivityStartDate:[NSDate date]];
   }
   ImportDateEntryController* dec = [[ImportDateEntryController alloc] initWithTrackName:tn defaultDate:activityStartDate];
   NSRect fr = [[parentWindowController window] frame];
   NSRect dfr = [[dec window] frame];
   NSPoint origin;
   origin.x = fr.origin.x + fr.size.width/2.0 - dfr.size.width/2.0;
   origin.y = fr.origin.y + fr.size.height/2.0 - dfr.size.height/2.0;  
   [[dec window] setFrameOrigin:origin];
   [dec showWindow:parentWindowController];
   BOOL contains = YES;
   while (contains)
   {
      [NSApp runModalForWindow:[dec window]];
      tDateEntryStatus sts = [dec entryStatus];
      if (sts == kCancelDateEntry)
      {
         [currentImportTrackArray removeAllObjects];
         [parser abortParsing];
         break;
      }
      else if (sts == kSkipDateEntry)
      {
         skipTrack = YES;
         break;
      }
      else
      {
         dt = [dec date];
         [currentImportTrack setCreationTime:dt];
         contains = ([currentImportTrackArray containsObject:currentImportTrack] ||
                     [importTrackArray containsObject:currentImportTrack]);
         if (contains)
         {
            NSString* nm = nil;
            NSUInteger idx = [currentImportTrackArray indexOfObject:currentImportTrack];
            if (idx !=  NSNotFound)
            {
               nm = [[currentImportTrackArray objectAtIndex:idx] name];
            }
            else
            { 
               idx = [importTrackArray indexOfObject:currentImportTrack];
               if (idx !=  NSNotFound)
               {
                  nm = [[importTrackArray objectAtIndex:idx] name];
               }
            }
            NSString* s;
            if (nm)
            {
               s = [NSString stringWithFormat:@"An activity named %@ already exists with this date and time in the current document", nm];
            }
            else
            {
               s = @"An activity already exists with this date and time in the current document";
            }
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"Re-enter Date and Time"];
            [alert setMessageText:@"Invalid Activity Time"];
            [alert setInformativeText:s];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert runModal];
         }
      }
   }
   [[dec window] orderOut:[parentWindowController window]];
   [[parentWindowController window] makeKeyAndOrderFront:[dec window]];
   return dt;
}



- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	//NSLog(@"END element:%@", elementName);
	if ([elementName isEqualToString:@"trk"] ||
		[elementName isEqualToString:@"rte"])
   {
      if (currentImportTrack != nil)
      {
          NSUInteger numPoints = [currentImportPointArray count];
         if ((numPoints > 0) && !skipTrack)
         {
            TrackPoint* pt = [currentImportPointArray objectAtIndex:0];
            //NSDate* cd = [pt date];
            [currentImportTrack setCreationTime:activityStartDate];
            pt = [currentImportPointArray objectAtIndex:(numPoints-1)];
            [currentImportTrack setDistance:[pt distance]]; 
            [currentImportTrack setPoints:currentImportPointArray];
#if 0
			 if ([currentImportLapArray count] == 0)
            {
               NSArray* pts = [currentImportTrack goodPoints];
               TrackPoint* lastPoint = nil;
               if ([pts count] > 0) lastPoint = [pts objectAtIndex:[pts count]-1];
               Lap* lap = [[Lap alloc] initWithGPSData:0
								startTimeSecsSince1970:[[currentImportTrack creationTime] timeIntervalSince1970]
                                             totalTime:[currentImportTrack duration] * 100 
                                         totalDistance:[currentImportTrack distance] * 1609.344  // to meters
                                              maxSpeed:[currentImportTrack maxSpeed] * (1609.344/3600.0)
                                              beginLat:[currentImportTrack firstValidLatitude]
                                              beginLon:[currentImportTrack firstValidLongitude]
                                                endLat:lastPoint ? [lastPoint latitude] : BAD_LATLON
                                                endLon:lastPoint ? [lastPoint longitude] : BAD_LATLON
                                              calories:0
                                                 avgHR:[currentImportTrack avgHeartrate]
                                                 maxHR:[currentImportTrack maxHeartrate:0]
                                                 avgCD:[currentImportTrack avgCadence]
                                             intensity:0
                                               trigger:0];
			   [lap setStartingWallClockTimeDelta:0.0];
               [currentImportLapArray addObject:lap];
               [lap release];
            }
#endif
             //NSLog(@"importing track %@ with %d laps and %d points.\n", cd, [currentImportLapArray count], [currentImportPointArray count]);
			 [currentImportTrack fixupTrack];
             if (currentActivity != nil) [currentImportTrack setAttribute:kActivity 
															  usingString:currentActivity];
			if (currentTrackName != nil) 
			{
				[currentImportTrack setName:currentTrackName];
				[currentImportTrack setAttribute:kName
									 usingString:currentTrackName];
			}
			[currentImportTrackArray addObject:currentImportTrack];
         }
          currentImportPointArray = nil;
         currentImportTrack = nil;
      }
      inTrack = NO;
      [currentTrackName release];
      currentTrackName = nil;
      return;
	}

	if ([elementName isEqualToString:@"trkseg"])
	{
		return;
	}
   
	if ([elementName isEqualToString:@"trkpt"] ||
	    [elementName isEqualToString:@"rtept"])
	{
		if (currentImportPoint != nil)
		{
			if (inActivity)
			{
                NSUInteger num = [currentImportPointArray count];
				if (num > 1)
				{
					TrackPoint* prevPt = [currentImportPointArray objectAtIndex:num-1];
					float distance;
					if (!distanceExtensionFound)
					{ 
						float ptDist = [Utils latLonToDistanceInMiles:[currentImportPoint latitude]
																   lon1:[currentImportPoint longitude]
																   lat2:[prevPt latitude]
																   lon2:[prevPt longitude]];
						distance = [prevPt distance] + ptDist;
						[currentImportPoint setDistance:distance];
						[currentImportPoint setOrigDistance:distance];
					}
					else
					{
						distance = [currentImportPoint distance];
					}
					// need to re-calc speed because it isn't in the xml file!
					float speed = [prevPt speed];
					if (!pointsHaveTime)
					{
						[currentImportPoint setWallClockDelta:0.0];
						[currentImportPoint setActiveTimeDelta:0.0];
					}
					NSTimeInterval now = [currentImportPoint wallClockDelta];
					NSTimeInterval prev =[prevPt wallClockDelta];
					if (now > prev)
					{
						speed = (distance)/((now-prev)/(60.0*60.0)); // miles/hour
					}
					[currentImportPoint setSpeed:speed];
				}
				else
				{
					if (!pointsHaveTime)
					{
						if (!haveActivityStartTime)
						{
							NSDate* st = [self getStartTime];
							[self setActivityStartDate:st];
							haveActivityStartTime = YES;
						}
						[currentImportPoint setWallClockDelta:0.0];
						[currentImportPoint setActiveTimeDelta:0.0];
					}
					[currentImportPoint setSpeed:0.0];
					[currentImportPoint setDistance:0.0];
				}
				if ([Utils checkDataSanity:0.0
								  latitude:(float)[currentImportPoint latitude]
								 longitude:(float)[currentImportPoint longitude]
								  altitude:(float)[currentImportPoint origAltitude]
								 heartrate:(int)[currentImportPoint heartrate]
								   cadence:(int)[currentImportPoint cadence]
							   temperature:(float)[currentImportPoint temperature]
									 speed:(float)[currentImportPoint speed]
								  distance:(float)[currentImportPoint distance]])
				{
					float speed = [currentImportPoint speed];
					if (!(IS_BETWEEN(kMinPossibleSpeed,      speed,      kMaxPossibleSpeed)))
					  [currentImportPoint setSpeed:0.0];

					float altitude = [currentImportPoint origAltitude];
					if (!(IS_BETWEEN(kMinPossibleAltitude,   altitude,   kMaxPossibleAltitude)))
					  [currentImportPoint setOrigAltitude:0.0];

					[currentImportPointArray addObject:currentImportPoint];
				}
			}
			currentImportPoint = nil;
		}
		inPoint = NO;
		return;
	}
	
	if ([elementName isEqualToString:@"time"])
	{  
      if (inPoint && inActivity && (currentStringValue != nil) && ([currentStringValue length] >= 20))
      {
         if (currentImportPoint != nil)
         {
            pointsHaveTime = YES;
			// NSLog(@"%@", currentStringValue);
            NSDate* dt = [self dateFromTimeString:currentStringValue];
			if (!haveActivityStartTime)
			{
				[self setActivityStartDate:dt];
				haveActivityStartTime = YES;
			}
            [currentImportPoint setWallClockDelta:[dt timeIntervalSinceDate:activityStartDate]];
            [currentImportPoint setActiveTimeDelta:[dt timeIntervalSinceDate:activityStartDate]];
          }
      }
      return;
   }
   
   
   if ([elementName isEqualToString:@"ele"])
   {
      if (currentStringValue != nil)
      {
         float val = MetersToFeet([currentStringValue floatValue]);
         if (currentImportPoint != nil)
         {
            [currentImportPoint setOrigAltitude:val];
         }
      }
      return;
   }
	
	if ([elementName isEqualToString:@"gpxdata:hr"] ||
		[elementName isEqualToString:@"gpxtpx:hr"])
    {
		if ((currentStringValue != nil) && (currentImportPoint != nil))
		{
			[currentImportPoint setHeartrate:[currentStringValue floatValue]];
		}
	}
	
	if ([elementName isEqualToString:@"gpxdata:cadence"] ||
		[elementName isEqualToString:@"gpxtpx:cad"])
    {
		if ((currentStringValue != nil) && (currentImportPoint != nil))
		{
			[currentImportPoint setCadence:[currentStringValue floatValue]];
		}
	}
	
    if ([elementName isEqualToString:@"power"])
    {
        if ((currentStringValue != nil) && (currentImportPoint != nil))
        {
            [currentImportPoint setPower:[currentStringValue floatValue]];
        }
    }
	if ([elementName isEqualToString:@"gpxtpx:atemp"])
	{
		if ((currentStringValue != nil) && (currentImportPoint != nil))
		{
			[currentImportPoint setTemperature:CelsiusToFahrenheight([currentStringValue floatValue])];
		}
	}
	
	
	if ([elementName isEqualToString:@"gpxdata:distance"])
    {
		if ((currentStringValue != nil) && (currentImportPoint != nil))
		{
			distanceExtensionFound = YES;
			float val = KilometersToMiles([currentStringValue floatValue]/1000.0);
			[currentImportPoint setDistance:val];
			[currentImportPoint setOrigDistance:val];
 		}
	}
	
   if ([elementName isEqualToString:@"name"])
   {
      if (currentStringValue != nil)
      {
         if (inTrack && !inPoint)
         {
            NSRange r = [currentStringValue rangeOfString:@"![CDATA["];
            if (r.location != NSNotFound)
            {
               int len = (int)[currentStringValue length];
               r.location += 8;
               r.length = len - 10;
               currentTrackName = [currentStringValue substringWithRange:r];
            }
            else
            {
               currentTrackName = [NSString stringWithString:currentStringValue];
            }
         }
      }
      return;
   }
	
	if ([elementName isEqualToString:@"gpxdata:lap"])
	{
		if (currentImportLap != nil)
		{
			//[currentImportLap setStartingWallClockTimeDelta:[lapStartTime timeIntervalSinceDate:currentTrackStartTime]];
			//NSLog(@"added lap starting at %@\n", [currentImportLap origStartTime]); 
			[currentImportLapArray addObject:currentImportLap];
			currentImportLap = nil;
		}
		inLap = NO;
		return;
	}
	
	if ([elementName isEqualToString:@"startTime"])
	{
		if (inLap && (currentStringValue != nil) && ([currentStringValue length] >= 20) && (currentImportLap != nil))
		{
			NSDate* dt = [self dateFromTimeString:currentStringValue];
			[currentImportLap setOrigStartTime:dt];
		}
	}
	
	if ([elementName isEqualToString:@"elapsedTime"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			[currentImportLap setTotalTime:[currentStringValue floatValue]];
		}
	}

	if ([elementName isEqualToString:@"startPoint"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
		}
	}
	
	if ([elementName isEqualToString:@"endPoint"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
		}
	}
	
	if ([elementName isEqualToString:@"calories"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			[currentImportLap setCalories:[currentStringValue intValue]];
		}
	}
	
	if ([elementName isEqualToString:@"distance"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil) )
		{
			float val = KilometersToMiles([currentStringValue floatValue]/1000.0);
			[currentImportLap setDistance:val];
		}
	}
	
	if ([elementName isEqualToString:@"summary"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			summarySetter(currentImportLap, nil, [currentStringValue intValue]);
		}
	}
	if ([elementName isEqualToString:@"trigger"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
		}
	}
	if ([elementName isEqualToString:@"intensity"])
	{
		if (inLap && (currentStringValue != nil) && (currentImportLap != nil))
		{
			int val =  [currentStringValue isEqualToString:@"active"] ? 1 : 0;
			[currentImportLap setIntensity:val];
		}
	}
}


//---- EXPORT ----------------------------------------------------------------------------------------------------


-(NSString*)stringValueForTriggerMethod:(int)meth
{
	switch (meth)
	{
		case 1:
			return @"distance";
		case 2:
			return @"location";
		case 3:
			return @"time";
		case 4:
			return @"heart_rate";
	}
	return @"manual";
}


- (BOOL) exportTrack:(Track*)track
{
	NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"gpx"];
	NSString* v = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	NSMutableString* me = [NSMutableString stringWithString:@"Ascent "];
	[me appendString:v];
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns" 
										stringValue:@"http://www.topografix.com/GPX/1/1"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"version" 
									   stringValue:@"1.1"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"creator" 
									   stringValue:me]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns:xsi" 
									   stringValue:@"http://www.w3.org/2001/XMLSchema-instance"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns:gpxdata" 
										stringValue:@"http://www.cluetrust.com/XML/GPXDATA/1/0"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"xsi:schemaLocation" 
									   stringValue:@"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd"]];

	NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	NSXMLElement* trk = [NSXMLNode elementWithName:@"trk"];

	// name and description
	NSString* s = [track attribute:kName];
	if (!s || [s isEqualToString:@""])
	{
		NSMutableString* nm = [NSMutableString stringWithString:@"Activity on "];
		[nm appendString:[[track creationTime] description]];
		s = nm;
	}
	NSXMLElement* name = [NSXMLNode elementWithName:@"name"
										  stringValue:s];
	[trk addChild:name];
	NSString* ds = [track name];
	if ((ds != nil) && ([ds isEqualToString:@""] == NO))
	{
	  NSXMLElement* desc = [NSXMLNode elementWithName:@"desc"
										  stringValue:ds];
	  [trk addChild:desc];
	}

	// start sequence of track points
	NSXMLElement* trkseg = [NSXMLNode elementWithName:@"trkseg"];
	NSArray* pts = [track goodPoints];
	//NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];
	NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSUInteger num = [pts count];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validLatLon])
		{
			NSXMLElement* trkpt = [NSXMLNode elementWithName:@"trkpt"];
			[trkpt addAttribute:[NSXMLNode attributeWithName:@"lat"
												 stringValue:[NSString stringWithFormat:@"%1.8f",[pt latitude]]]];
			[trkpt addAttribute:[NSXMLNode attributeWithName:@"lon"
												 stringValue:[NSString stringWithFormat:@"%1.8f",[pt longitude]]]];
			float alt = FeetToMeters([pt origAltitude]);
			NSXMLElement* ele = [NSXMLNode elementWithName:@"ele"
											   stringValue:[NSString stringWithFormat:@"%1.1f", alt]];
			[trkpt addChild:ele];
			NSString* dt = [[[track creationTime] addTimeInterval:[pt wallClockDelta]] 
			descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ"
									timeZone:tz 
									locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
			NSXMLElement* time = [NSXMLNode elementWithName:@"time"
												stringValue:dt];
			[trkpt addChild:time];

			//.... gpxdata trkpt EXTENSIONS ...........................................
		
			NSXMLElement* ext = [NSXMLNode elementWithName:@"extensions"];
			
			NSXMLElement* extChild = [NSXMLNode elementWithName:@"gpxdata:hr"
											  stringValue:[NSString stringWithFormat:@"%d", (int)([pt heartrate] + 0.5)]];
			[ext addChild:extChild];
			
			extChild = [NSXMLNode elementWithName:@"gpxdata:cadence"
									  stringValue:[NSString stringWithFormat:@"%d", (int)([pt cadence] + 0.5)]];
			
			[ext addChild:extChild];
	
			extChild = [NSXMLNode elementWithName:@"gpxdata:distance"
									  stringValue:[NSString stringWithFormat:@"%1.6f", (MilesToKilometers([pt distance])*1000.0)]];
			
			[ext addChild:extChild];
			
			[trkpt addChild:ext];
			
			//.... end gpxdata trkpt EXTENSIONS .................................
			
			[trkseg addChild:trkpt];
		}
	}
	[trk addChild:trkseg];
	[root addChild:trk];
	
	NSArray* laps = [track laps];
    NSUInteger numLaps = [laps count];
	if (numLaps > 0)
	{
		//.... gpxdata LAP EXTENSIONS ...............................................
		NSXMLElement* ext = [NSXMLNode elementWithName:@"extensions"];
		for (int i=0; i<numLaps; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			NSXMLElement* lapext = (NSXMLElement *)[NSXMLNode elementWithName:@"gpxdata:lap"];
			[lapext addAttribute:[NSXMLNode attributeWithName:@"xmlns" 
												stringValue:@"http://www.cluetrust.com/XML/GPXDATA/1/0"]];
			
			// .... lap index (0-based)
			NSXMLElement* extChild = [NSXMLNode elementWithName:@"index"
									  stringValue:[NSString stringWithFormat:@"%d", i]];
			[lapext addChild:extChild];
			
			// .... lap GPS start point
			extChild = [NSXMLNode elementWithName:@"startPoint"];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"lat"
												 stringValue:[NSString stringWithFormat:@"%1.8f",[lap beginLatitude]]]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"lon"
												 stringValue:[NSString stringWithFormat:@"%1.8f",[lap beginLongitude]]]];
			[lapext addChild:extChild];
			
			// .... lap GPS end point
			extChild = [NSXMLNode elementWithName:@"endPoint"];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"lat"
													stringValue:[NSString stringWithFormat:@"%1.8f",[lap endLatitude]]]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"lon"
													stringValue:[NSString stringWithFormat:@"%1.8f",[lap endLongitude]]]];
			[lapext addChild:extChild];
			
			// .... lap startTime 
			NSString* st = [[lap origStartTime] descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ"
																	 timeZone:tz 
																	   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
			extChild = [NSXMLNode elementWithName:@"startTime"
													stringValue:st];
			[lapext addChild:extChild];
			
			// .... lap elapsed Time 
			extChild = [NSXMLNode elementWithName:@"elapsedTime"
									  stringValue:[NSString stringWithFormat:@"%1.4f", [lap totalTime]]];
			[lapext addChild:extChild];

			// .... lap calories 
			extChild = [NSXMLNode elementWithName:@"calories"
									  stringValue:[NSString stringWithFormat:@"%1.0f", [track caloriesForLap:lap]]];
			[lapext addChild:extChild];
			
			// .... lap distance, in meters 
			extChild = [NSXMLNode elementWithName:@"distance"
									  stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track distanceOfLap:lap])*1000.0]];
			[lapext addChild:extChild];

			// .... lap average hr
			extChild = [NSXMLNode elementWithName:@"summary"
									  stringValue:[NSString stringWithFormat:@"%d", (int)[track avgHeartrateForLap:lap]]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
													stringValue:@"avg"]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"name"
													stringValue:@"hr"]];
			[lapext addChild:extChild];
			  
			// .... lap max hr
			extChild = [NSXMLNode elementWithName:@"summary"
									  stringValue:[NSString stringWithFormat:@"%d", (int)[track maxHeartrateForLap:lap
																								 atActiveTimeDelta:nil]]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
													stringValue:@"max"]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"name"
													stringValue:@"hr"]];
			[lapext addChild:extChild];
				
			// .... lap max speed (m/sec)
			extChild = [NSXMLNode elementWithName:@"summary"
							stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track maxSpeedForLap:lap atActiveTimeDelta:nil])*1000.0/3600.0]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
													stringValue:@"max"]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"name"
													stringValue:@"speed"]];
			[lapext addChild:extChild];
			
			// .... lap avg cadence
			extChild = [NSXMLNode elementWithName:@"summary"
									  stringValue:[NSString stringWithFormat:@"%1.1f", [track avgCadenceForLap:lap]]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
													stringValue:@"avg"]];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"name"
													stringValue:@"cadence"]];
			[lapext addChild:extChild];
			
			// .... lap trigger method
			extChild = [NSXMLNode elementWithName:@"trigger"];
			[extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
													stringValue:[self stringValueForTriggerMethod:[lap triggerMethod]]]];
			[lapext addChild:extChild];
			
			// .... lap intensity
			extChild = [NSXMLNode elementWithName:@"intensity"
									  stringValue:[lap intensity] > 0 ? @"rest" : @"active"];
			[lapext addChild:extChild];
			[ext addChild:lapext];
		}
		[root addChild:ext];
		
		//.... end gpxdata LAP EXTENSIONS .......................................
	}
	
	
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	if (![xmlData writeToURL:xmlURL atomically:YES]) 
	{
	  NSLog(@"Could not write document out...");
	  return NO;
	}   
	return YES;
}




@end
