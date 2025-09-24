//
//  TrackBrowserItem.mm
//  TLP
//
//  Created by Rob Boyer on 7/22/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "TrackBrowserItem.h"
#import "Track.h"
#import "Lap.h"
#import "Defs.h"
#import "Utils.h"
#import "EquipmentLog.h"

@interface TrackBrowserItem ()
{
    float                    _cachedDistance;
    float                    _cachedTotalClimb;
    float                    _cachedTotalDescent;
    float                    _cachedRateOfClimb;
    float                    _cachedRateOfDescent;
    float                    _cachedAvgSpeed;
    float                    _cachedAvgMovingSpeed;
    float                    _cachedMaxSpeed;
    float                    _cachedAvgHeartRate;
    float                    _cachedMaxHeartRate;
    float                    _cachedAvgGradient;
    float                    _cachedMaxGradient;
    float                    _cachedMinGradient;
    float                    _cachedAvgCadence;
    float                    _cachedMaxCadence;
    float                    _cachedAvgPower;
    float                    _cachedMaxPower;
    float                    _cachedWork;
    float                    _cachedMaxAltitude;
    float                    _cachedMinAltitude;
    float                    _cachedAvgAltitude;
    float                    _cachedCalories;
    float                    _cachedTimeInHRZ[kNumHRZones];
    float                    _cachedTimeInNonHRZ[kMaxZoneType+1][kNumNonHRZones];
    float                    _cachedDuration;
    float                    _cachedMovingDuration;
    float                    _cachedWeight;
    float                    _cachedMaxTemperature;
    float                    _cachedMinTemperature;
    float                    _cachedAvgTemperature;
}
@end


@implementation TrackBrowserItem

#define BAD_FLOAT       999999999.0f


- (id)init
{
	return [self initWithData:nil lap:nil name:@"" date:nil type:kTypeNone parent:nil];
}

- (void) invalidateCache:(BOOL)recursively
{
	_cachedDistance = BAD_FLOAT;
	_cachedTotalClimb = BAD_FLOAT;
	_cachedTotalDescent = BAD_FLOAT;
	_cachedRateOfClimb = BAD_FLOAT;
	_cachedRateOfDescent = BAD_FLOAT;
	_cachedAvgSpeed = BAD_FLOAT;
	_cachedAvgMovingSpeed = BAD_FLOAT;
	_cachedMaxSpeed = BAD_FLOAT;
	_cachedAvgHeartRate = BAD_FLOAT;
	_cachedMaxHeartRate = BAD_FLOAT;
	_cachedAvgCadence = BAD_FLOAT;
	_cachedMaxCadence = BAD_FLOAT;
	_cachedAvgPower = BAD_FLOAT;
	_cachedWork = BAD_FLOAT;
	_cachedMaxPower = BAD_FLOAT;
	_cachedAvgGradient = BAD_FLOAT;
	_cachedMaxGradient = BAD_FLOAT;
	_cachedMinGradient = BAD_FLOAT;
	_cachedMaxAltitude = BAD_FLOAT;
	_cachedMinAltitude = BAD_FLOAT;
	_cachedAvgAltitude = BAD_FLOAT;
	_cachedMaxTemperature = BAD_FLOAT;
	_cachedMinTemperature = BAD_FLOAT;
	_cachedAvgTemperature = BAD_FLOAT;
	_cachedCalories = BAD_FLOAT;
	for (int i=0; i<kNumHRZones; i++) _cachedTimeInHRZ[i] = BAD_FLOAT;
	for (int ty=0; ty<=kMaxZoneType; ty++)
	   for (int i=0; i<kNumNonHRZones; i++)
		   _cachedTimeInNonHRZ[ty][i] = BAD_FLOAT;
	_cachedDuration = BAD_FLOAT;
	_cachedMovingDuration = BAD_FLOAT;
	_cachedWeight = BAD_FLOAT;
	if (recursively)
        [[_children allValues] makeObjectsPerformSelector:@selector(invalidateCacheRecursively)];
}


-(void)invalidateCacheRecursively
{
	[self invalidateCache:YES];
}


- (void)prefChange:(NSNotification *)notification
{
	id obj = [notification object];
	if (!obj || obj == _track)
	{
		[self invalidateCache:YES];
	}
}


- (void)mustFixup:(NSNotification *)notification
{
   if ((_track != nil) && (_lap == nil))
   {
      [_track fixupTrack];
   }
}


-(id) initWithData:(Track *)t lap:(Lap*)l name:(NSString*)n date:(NSDate*)d  type:(tBrowserItemType)ty parent:(TrackBrowserItem*)par;
{
	self = [super init];
	self.track  = t;
    self.lap  = l;
    self.name = n;
    self.date = d;
    self.type = ty;
	[self invalidateCache:NO];
	_parentItem = par;				// do NOT retain to avoid retain loops
	_expanded = NO;
	_sortedChildKeys= nil;
	_sortedChildKeysSeqno = 0;
	_seqno = 0;
	_children = [[NSMutableDictionary alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefChange:)
												 name:@"PreferencesChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(mustFixup:)
												 name:@"MustFixupTrack"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefChange:)
												 name:@"InvalidateBrowserCache"
											   object:nil];
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    self.track = nil;
    self.lap = nil;
    self.date = nil;
    self.children = nil;
    self.parentItem = nil;
    self.sortedChildKeys = nil;
    self.name = nil;
    [super dealloc];
}


-(BOOL) isRoot
{
   return (_children == nil) ? YES : NO;
}


extern NSString*      gCompareString;


-(NSComparisonResult) compare:(TrackBrowserItem*)item
{
   if (gCompareString == nil)
      return [_date compare:[item date]];
   float v1 = [[self valueForKey:gCompareString] floatValue];
   float v2 = [[item valueForKey:gCompareString] floatValue];
   return (v1 < v2) ? NSOrderedAscending : NSOrderedDescending;
}

-(NSComparisonResult) reverseCompare:(TrackBrowserItem*)item
{
   if (gCompareString == nil)
      return [[item date] compare:_date];
   float v1 = [[self valueForKey:gCompareString] floatValue];
   float v2 = [[item valueForKey:gCompareString] floatValue];
   return (v1 > v2) ? NSOrderedAscending : NSOrderedDescending;
}

-(NSComparisonResult) compareString:(TrackBrowserItem*)item
{
   //NSString* dbg = [NSString stringWithString:gCompareString];
   //NSLog(@"comparing using %@...", dbg);
   NSString* v1 = [self valueForKey:gCompareString];
   NSString* v2 = [item valueForKey:gCompareString];
   return [v1 caseInsensitiveCompare:v2];
}


-(NSComparisonResult) reverseCompareString:(TrackBrowserItem*)item
{
   NSString* v1 = [self valueForKey:gCompareString];
   NSString* v2 = [item valueForKey:gCompareString];
   return [v2 caseInsensitiveCompare:v1];
}

- (BOOL) isEqual:(id) tbi
{
   return ([[self name] isEqualToString:[tbi name]]);
}


-(float) distance
{
   if (_cachedDistance == BAD_FLOAT)
   {
      float distance = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            distance += [bi distance];
         }
      }
      else if (_lap == nil)
      {
         distance = [Utils convertDistanceValue:[_track distance]];
      }
      else
      {
         distance =  [Utils convertDistanceValue:[_track distanceOfLap:_lap]];
      }
      _cachedDistance = distance;
   }
   return _cachedDistance;
}


-(float) totalClimb
{
   if (_cachedTotalClimb == BAD_FLOAT)
   {
      float total = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            total += [bi totalClimb];
         }
      }
      else if (_lap == nil)
      {
         total = [Utils convertClimbValue:[_track totalClimb]];
      }
      else
      {
         total = [Utils convertClimbValue:[_track lapClimb:_lap]];
      }
      _cachedTotalClimb = total;
   }
   return _cachedTotalClimb;
}


-(float) totalDescent
{
   if (_cachedTotalDescent == BAD_FLOAT)
   {
      float sum = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            sum += [bi totalDescent];
         }
      }
      else if (_lap == nil)
      {
         sum = [Utils convertClimbValue:[_track totalDescent]];
      }
      else
      {
         sum = [Utils convertClimbValue:[_track lapDescent:_lap]];
      }
      _cachedTotalDescent = sum;
   }
   return _cachedTotalDescent;
}


-(float) rateOfClimb
{
	if (_cachedRateOfClimb == BAD_FLOAT)
	{
		float answer = 0.0;
		float totalClimb = 0.0;
		float totalDur = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				totalClimb += [bi totalClimb];
				totalDur += [bi movingDurationAsFloat];
			}
		}
		else if (_lap == nil)
		{
			totalClimb += [Utils convertClimbValue:[_track totalClimb]];
			totalDur += [Utils convertDistanceValue:[_track movingDuration]];
		}
		else
		{
			totalClimb = [Utils convertClimbValue:[_track lapClimb:_lap]];
			totalDur += [Utils convertDistanceValue:[_track movingDurationOfLap:_lap]];
		}
		if (totalDur > 0.0) answer = (totalClimb*3600.0)/totalDur;	// convert to ft or m per hour
		_cachedRateOfClimb = answer;
	}
	return _cachedRateOfClimb;
}


-(float) rateOfDescent
{
	if (_cachedRateOfDescent == BAD_FLOAT)
	{
		float answer = 0.0;
		float totalClimb = 0.0;
		float totalDur = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				totalClimb += [bi totalDescent];
				totalDur += [bi movingDurationAsFloat];
			}
		}
		else if (_lap == nil)
		{
			totalClimb += [Utils convertClimbValue:[_track totalDescent]];
			totalDur += [Utils convertDistanceValue:[_track movingDuration]];
		}
		else
		{
			totalClimb = [Utils convertClimbValue:[_track lapDescent:_lap]];
			totalDur += [Utils convertDistanceValue:[_track movingDurationOfLap:_lap]];
		}
		if (totalDur > 0.0) answer = (totalClimb*3600.0)/totalDur;	// convert to ft or m per hour
		_cachedRateOfDescent = answer;
	}
	return _cachedRateOfDescent;
}


-(float) avgSpeed
{
   if (_cachedAvgSpeed == BAD_FLOAT)
   {
      float avg = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         float totalDur = 0.0;
         float totalDist = 0.0;
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            totalDur += [bi durationAsFloat];
            totalDist += [bi distance];
         }
         if (totalDist != 0)
         {
            avg = totalDist/(totalDur/(60.0*60.0));
         }
      }
      else if (_lap == nil)
      {
		  avg = [Utils convertSpeedValue:[_track avgSpeed]];
      }
      else
      {
          avg = [Utils convertSpeedValue:[_track avgLapSpeed:_lap]];
      }
      _cachedAvgSpeed = avg;
   }
   return _cachedAvgSpeed;
}


-(float) avgPace
{
   return SpeedToPace([self avgSpeed]);
}


-(NSString*) avgPaceAsString
{
   float answer = [self avgPace];
   return [NSString stringWithFormat:@"%02d:%02d", ((int)(answer/60)) % 60, ((int)answer)%60];
}




-(float) maxSpeed
{
	if (_cachedMaxSpeed == BAD_FLOAT)
	{
		float max = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi maxSpeed];
				if (m > max) max = m;
			}
		}
		else if (_lap == nil)
		{
			max = [Utils convertSpeedValue:[_track maxSpeed]];
		}
		else
		{
			max = [Utils convertSpeedValue:[_track maxSpeedForLap:_lap atActiveTimeDelta:0]];
		}
		_cachedMaxSpeed = max;
	}
	return _cachedMaxSpeed;
}


-(float) durationAsFloat
{
   if (_cachedDuration == BAD_FLOAT)
   {
      float dur = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         float sum = 0;
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            sum += [bi durationAsFloat];
         }
         dur = sum;
      }
      else if (_lap == nil)
      {
         dur = [_track durationAsFloat];
      }
      else
      {
		  dur = [_track durationOfLap:_lap];
     }
      _cachedDuration = dur;
   }
   return _cachedDuration;
}   


-(float) movingDurationAsFloat
{
	if (_cachedMovingDuration == BAD_FLOAT)
	{
		float dur = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			float sum = 0.0;
			while ((bi = [enumerator nextObject])) 
			{
				sum += [bi movingDurationAsFloat];
			}
			dur = sum;
		}
		else if (_lap == nil)
		{
			dur = [_track movingDuration];
		}
		else
		{
			dur = [_track movingDurationOfLap:_lap];
		}
		_cachedMovingDuration = dur;
	}
	return _cachedMovingDuration;
}   


-(NSString*) durationAsString
{
   if (_cachedDuration == BAD_FLOAT)
   {
      _cachedDuration = [self durationAsFloat];
   }
   int hours = (int)_cachedDuration/3600;
   int mins = (int)(_cachedDuration/60.0) % 60;
   int secs = (int)_cachedDuration % 60;
   return  [NSString stringWithFormat:@"%3.3d:%02d:%02d",hours, mins, secs];
}   
   

-(NSString*) movingTimeAsString
{
   if (_cachedMovingDuration == BAD_FLOAT)
   {
      _cachedMovingDuration = [self movingDurationAsFloat];
   }
   int hours = (int)_cachedMovingDuration/3600;
   int mins = (int)(_cachedMovingDuration/60.0) % 60;
   int secs = (int)_cachedMovingDuration % 60;
   return  [NSString stringWithFormat:@"%02d:%02d:%02d",hours, mins, secs];
}



-(NSTimeInterval) duration
{
   return [_track duration];
}


-(NSString*) title
{
   NSString* answer = @"";
   if ((_track == nil) && (_lap == nil))
   {
   }
   else if (_lap == nil)
   {
      answer = [_track attribute:kName];
      if ([answer isEqualToString:@""])
      {
         answer = [_track name];
      }
   }
   return answer;
}


- (NSString*) keyword1
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kKeyword1];
   else
      return @"";
}

- (NSString*) keyword2
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kKeyword2];
   else
      return @"";
}

- (NSString*) custom
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kKeyword3];    // custom text field is stored in keyword 3
   else
      return @"";
}


- (NSString*) notes
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kNotes];
   else
      return @"";
}

- (NSString*) location
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kLocation];
   else
      return @"";
}

- (NSString*) computer
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kComputer];
   else
      return @"";
}

- (NSString*) sufferScore
{
   if ((_track != nil) && (_lap == nil))
      return [_track attribute:kSufferScore];
   else
      return @"";
}


-(float) avgMovingSpeed
{
	if (_cachedAvgMovingSpeed == BAD_FLOAT)
	{
		float answer = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			float totalDuration = [self movingDurationAsFloat];
			if (totalDuration > 0.0)
			{
				TrackBrowserItem* bi;
				float sum = 0;
				NSEnumerator *enumerator = [_children objectEnumerator];
				while ((bi = [enumerator nextObject])) 
				{
					float td = [bi movingDurationAsFloat];
					sum += ([bi avgMovingSpeed] * td);
				}
				answer = sum/totalDuration;
			}
		}
		else if (_lap == nil)
		{
			answer = [Utils convertSpeedValue:[_track avgMovingSpeed]];
		}
		else
		{
			answer = [Utils convertSpeedValue:[_track movingSpeedForLap:_lap]];
		}
		_cachedAvgMovingSpeed = answer;
	}
   
	return _cachedAvgMovingSpeed;
}




-(float) avgMovingPace
{
   float v = [self avgMovingSpeed];
   if (v != 0.0)
   {
      // hours/mile * mins/hour = mins/mile; 
      v = (1.0*60.0*60.0)/v;
   }
   return v;
}


-(NSString*) avgMovingPaceAsString
{
   float answer = [self avgMovingPace];
   return [NSString stringWithFormat:@"%02d:%02d", ((int)(answer/60)) % 60, ((int)answer)%60];
}


-(float) maxHeartRate
{
   if (_cachedMaxHeartRate == BAD_FLOAT)
   {
      float max = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            float m = [bi maxHeartRate];
            if (m > max) max = m;
         }
      }
      else if (_lap == nil)
      {
         max = [_track maxHeartrate:nil];
      }
      else
      {
         //max = [_lap maxHeartRate];
         max = [_track maxHeartrateForLap:_lap atActiveTimeDelta:0];
      }
      _cachedMaxHeartRate = max;
   }
   return _cachedMaxHeartRate;
}


-(float) avgHeartRate
{
   if (_cachedAvgHeartRate == BAD_FLOAT)
   {
      float answer = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         float totalDuration = [self durationAsFloat];
         if (totalDuration > 0.0)
         {
            float sum = 0;
            NSEnumerator *enumerator = [_children objectEnumerator];
            TrackBrowserItem* bi;
            while ((bi = [enumerator nextObject])) 
            {
               float td = [bi durationAsFloat];
               float ahr = [bi avgHeartRate];
               if (ahr > 1.0)
               {
                  sum += ([bi avgHeartRate] * td);
               }
               else
               {
                  // no valid hr avg, so subtract it from time
                  totalDuration -= td;
               }
            }
            if (totalDuration > 0.0)
               answer = sum/totalDuration;
         }
      }
      else if (_lap == nil)
      {
         answer = [_track avgHeartrate];
      }
      else
      {
         answer = [_track avgHeartrateForLap:_lap];
      }
      _cachedAvgHeartRate = answer;
   }
   return _cachedAvgHeartRate;
}



- (float)calories
{
   if (_cachedCalories == BAD_FLOAT)
   {
      float sum = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            sum += [bi calories];
         }
      }
      else if (_lap == nil)
      {
         sum = [_track calories];
      }
      else
      {
		  sum = [_track caloriesForLap:_lap];
      }
      _cachedCalories = sum;
   }
   return _cachedCalories;
}




-(float) maxCadence
{
   if (_cachedMaxCadence == BAD_FLOAT)
   {
      float max = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            float m = [bi maxCadence];
            if (m > max) max = m;
         }
      }
      else if (_lap == nil)
      {
         max = [_track maxCadence:nil];
      }
      else
      {
         max = [_track maxCadenceForLap:_lap atActiveTimeDelta:0];
      }
      _cachedMaxCadence = max;
   }
   return _cachedMaxCadence;
}


-(float) maxPower
{
	if (_cachedMaxPower == BAD_FLOAT)
	{
		float max = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi maxPower];
				if (m > max) max = m;
			}
		}
		else if (_lap == nil)
		{
			max = [_track maxPower:nil];
		}
		else
		{
			max = [_track maxPowerForLap:_lap atActiveTimeDelta:0];
		}
		_cachedMaxPower = max;
	}
	return _cachedMaxPower;
}


-(float) avgCadence
{
   if (_cachedAvgCadence == BAD_FLOAT)
   {
      float answer = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         float totalDuration = [self durationAsFloat];
         if (totalDuration > 0.0)
         {
            float sum = 0;
            NSEnumerator *enumerator = [_children objectEnumerator];
            TrackBrowserItem* bi;
            while ((bi = [enumerator nextObject])) 
            {
               float td = [bi durationAsFloat];
               float acd = [bi avgCadence];
               if ((acd > 1.0) && (acd <= 254.0))
               {
                  sum += ([bi avgCadence] * td);
               }
               else
               {
                  totalDuration -= td;    // bad data, don't count this track
               }
            }
            if (totalDuration > 0.0)
               answer = sum/totalDuration;
         }
      }
      else if (_lap == nil)
      {
         answer = [_track avgCadence];
      }
      else
      {
         answer = [_track avgCadenceForLap:_lap];
      }
      _cachedAvgCadence = answer;
   }
   return _cachedAvgCadence;
}


-(float) work
{
	if (_cachedWork == BAD_FLOAT)
	{
		float answer = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			float sum = 0;
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float acd = [bi work];
				if (acd >= 0.0)
				{
					sum += acd;
				}
			}
			answer = sum;
		}
		else if (_lap == nil)
		{
			answer = [_track work];
		}
		else
		{
			answer = [_track workForLap:_lap];
		}
		_cachedWork = answer;
	}
	return _cachedWork;
}


-(float) avgPower
{
	if (_cachedAvgPower == BAD_FLOAT)
	{
		float answer = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			float totalDuration = [self movingDurationAsFloat];
			if (totalDuration > 0.0)
			{
				float sum = 0;
				NSEnumerator *enumerator = [_children objectEnumerator];
				TrackBrowserItem* bi;
				while ((bi = [enumerator nextObject])) 
				{
					float td = [bi movingDurationAsFloat];
					float acd = [bi avgPower];
					if ((acd > 1.0) && (acd <= 254.0))
					{
						sum += (acd * td);
					}
					else
					{
						totalDuration -= td;    // bad data, don't count this track
					}
				}
				if (totalDuration > 0.0)
					answer = sum/totalDuration;
			}
		}
		else if (_lap == nil)
		{
			answer = [_track avgPower];
		}
		else
		{
			answer = [_track avgPowerForLap:_lap];
		}
		_cachedAvgPower = answer;
	}
	return _cachedAvgPower;
}


-(float) maxGradient
{
   if (_cachedMaxGradient == BAD_FLOAT)
   {
      float max = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            float m = [bi maxGradient];
            if (m > max) max = m;
         }
      }
      else if (_lap == nil)
      {
         max = [_track maxGradient:nil];
      }
      else
      {
         max = [_track maxGradientForLap:_lap atActiveTimeDelta:0];
      }
      _cachedMaxGradient = max;
   }
   return _cachedMaxGradient;
}

-(float) minGradient
{
   if (_cachedMinGradient == BAD_FLOAT)
   {
      float min = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            float m = [bi minGradient];
            if (m  < min) min = m;
         }
      }
      else if (_lap == nil)
      {
         min = [_track minGradient:nil];
      }
      else
      {
         min = [_track minGradientForLap:_lap atActiveTimeDelta:0];
      }
      _cachedMinGradient = min;
   }
   return _cachedMinGradient;
}


-(float) avgGradient
{
   if (_cachedAvgGradient == BAD_FLOAT)
   {
      float answer = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         float totalDuration = [self durationAsFloat];
         if (totalDuration > 0.0)
         {
            float sum = 0;
            NSEnumerator *enumerator = [_children objectEnumerator];
            TrackBrowserItem* bi;
            while ((bi = [enumerator nextObject])) 
            {
               float td = [bi durationAsFloat];
               sum += ([bi avgGradient] * td);
            }
            answer = sum/totalDuration;
         }
      } 
      else if (_lap == nil)
      {
         answer = [_track avgGradient];
      }
      else
      {
         answer = [_track avgGradientForLap:_lap];
      }
      _cachedAvgGradient = answer;
   }
   return _cachedAvgGradient;
}


-(float) maxTemperature
{
	if (_cachedMaxTemperature == BAD_FLOAT)
	{
		float max = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi maxTemperature];
				if (m > max) max = m;
			}
		}
		else if (_lap == nil)
		{
			max = [_track maxTemperature:nil];
			if (max > 0.0) max = [Utils convertTemperatureValue:max];
		}
		else
		{
			max = [_track maxTemperatureForLap:_lap atActiveTimeDelta:0];
			if (max > 0.0) max = [Utils convertTemperatureValue:max];
		}
		_cachedMaxTemperature = max;
	}
	return _cachedMaxTemperature;
}


-(float) minTemperature
{
	if (_cachedMinTemperature == BAD_FLOAT)
	{
		float min = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi minTemperature];
				if ((m > 0.0) && (m  < min)) min = m;
			}
		}
		else if (_lap == nil)
		{
			min = [_track minTemperature:nil];
			if (min > 0.0) min = [Utils convertTemperatureValue:min];
		}
		else
		{
			min = [_track minTemperatureForLap:_lap atActiveTimeDelta:0];
			if (min > 0.0) min = [Utils convertTemperatureValue:min];
		}
		_cachedMinTemperature = min;
	}
	return _cachedMinTemperature;
}


-(float) avgTemperature
{
	if (_cachedAvgTemperature == BAD_FLOAT)
	{
		float answer = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			float totalDuration = [self durationAsFloat];
			if (totalDuration > 0.0)
			{
				float sum = 0;
				NSEnumerator *enumerator = [_children objectEnumerator];
				TrackBrowserItem* bi;
				while ((bi = [enumerator nextObject])) 
				{
					// anything zero or less is considered to be a non-event
					float temp = [bi avgTemperature];
					float td = [bi durationAsFloat];
					if (temp > 0.0)
					{
						sum += (temp * td);
					}
					else
					{
						totalDuration -= td;
					}
				}
				if (totalDuration > 0.0)
					answer = sum/totalDuration;
			}
		} 
		else if (_lap == nil)
		{
			answer = [_track avgTemperature];
			if (answer > 0.0) answer = [Utils convertTemperatureValue:answer];
		}
		else
		{
			answer = [_track avgTemperatureForLap:_lap];
			if (answer > 0.0) answer = [Utils convertTemperatureValue:answer];
		}
		_cachedAvgTemperature = answer;
	}
	return _cachedAvgTemperature;
}


-(float) maxAltitude
{
	if (_cachedMaxAltitude == BAD_FLOAT)
	{
		float max = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi maxAltitude];
				if (m > max) max = m;
			}
		}
		else if (_lap == nil)
		{
			max =  [Utils convertClimbValue:[_track maxAltitude:nil]];
		}
		else
		{
			max =  [Utils convertClimbValue:[_track maxAltitudeForLap:_lap atActiveTimeDelta:0]];
		}
		_cachedMaxAltitude = max;
	}
	return _cachedMaxAltitude;
}


-(float) minAltitude
{
	if (_cachedMinAltitude == BAD_FLOAT)
	{
		float min = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				float m = [bi minAltitude];
				if (m  < min) min = m;
			}
		}
		else if (_lap == nil)
		{
			min = [Utils convertClimbValue:[_track minAltitude:nil]];
		}
		else
		{
			min = [Utils convertClimbValue:[_track minAltitudeForLap:_lap atActiveTimeDelta:0]];
		}
		_cachedMinAltitude = min;
	}
	return _cachedMinAltitude;
}


-(float) avgAltitude
{
	if (_cachedAvgAltitude == BAD_FLOAT)
	{
		float answer = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			float totalDuration = [self durationAsFloat];
			if (totalDuration > 0.0)
			{
				float sum = 0;
				NSEnumerator *enumerator = [_children objectEnumerator];
				TrackBrowserItem* bi;
				while ((bi = [enumerator nextObject])) 
				{
					float td = [bi durationAsFloat];
					sum += ([bi avgAltitude] * td);
				}
				answer = sum/totalDuration;
			}
		} 
		else if (_lap == nil)
		{
			answer = [Utils convertClimbValue:[_track avgAltitude]];
		}
		else
		{
			answer = [Utils convertClimbValue:[_track avgAltitudeForLap:_lap]];
		}
		_cachedAvgAltitude = answer;
	}
	return _cachedAvgAltitude;
}


-(NSString*) timeInHRZAsString:(int)zone
{
   float totalDur = [self timeInHRZone:zone];   
   int hours = (int)totalDur/3600;
   int mins = (int)(totalDur/60.0) % 60;
   int secs = (int)totalDur % 60;
   return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
}


-(NSString*) timeInNonHRZAsString:(int)ty zone:(int)zn
{
	//float totalDur = [_track timeInNonHRZone:ty zone:zn];   
	float totalDur = [self timeInNonHRZone:ty zone:zn];   
	int hours = (int)totalDur/3600;
	int mins = (int)(totalDur/60.0) % 60;
	int secs = (int)totalDur % 60;
	return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
}


-(NSString*) timeInAltitudeZ1AsString
{
	return [self timeInNonHRZAsString:kAltitudeDefaults
								 zone:0];
}

-(NSString*) timeInAltitudeZ2AsString
{
	return [self timeInNonHRZAsString:kAltitudeDefaults
								 zone:1];
}
-(NSString*) timeInAltitudeZ3AsString
{
	return [self timeInNonHRZAsString:kAltitudeDefaults
								 zone:2];
}
-(NSString*) timeInAltitudeZ4AsString
{
	return [self timeInNonHRZAsString:kAltitudeDefaults
								 zone:3];
}
-(NSString*) timeInAltitudeZ5AsString;
{
	return [self timeInNonHRZAsString:kAltitudeDefaults
								 zone:4];
}


-(NSString*) timeInCadenceZ1AsString
{
   return [self timeInNonHRZAsString:kCadenceDefaults
                                zone:0];
}

-(NSString*) timeInCadenceZ2AsString
{
   return [self timeInNonHRZAsString:kCadenceDefaults
                                zone:1];
}
-(NSString*) timeInCadenceZ3AsString
{
   return [self timeInNonHRZAsString:kCadenceDefaults
                                zone:2];
}
-(NSString*) timeInCadenceZ4AsString
{
   return [self timeInNonHRZAsString:kCadenceDefaults
                                zone:3];
}
-(NSString*) timeInCadenceZ5AsString;
{
   return [self timeInNonHRZAsString:kCadenceDefaults
                                zone:4];
}

-(NSString*) timeInGradientZ1AsString
{
   return [self timeInNonHRZAsString:kGradientDefaults
                                zone:0];
}
-(NSString*) timeInGradientZ2AsString
{
   return [self timeInNonHRZAsString:kGradientDefaults
                                zone:1];
}
-(NSString*) timeInGradientZ3AsString
{
   return [self timeInNonHRZAsString:kGradientDefaults
                                zone:2];
}
-(NSString*) timeInGradientZ4AsString
{
   return [self timeInNonHRZAsString:kGradientDefaults
                                zone:3];
}
-(NSString*) timeInGradientZ5AsString
{
   return [self timeInNonHRZAsString:kGradientDefaults
                                zone:4];
}

-(NSString*) timeInSpeedZ1AsString;
{
   return [self timeInNonHRZAsString:kSpeedDefaults
                                zone:4];
}
-(NSString*) timeInSpeedZ2AsString;
{
   return [self timeInNonHRZAsString:kSpeedDefaults
                                zone:3];
}
-(NSString*) timeInSpeedZ3AsString;
{
   return [self timeInNonHRZAsString:kSpeedDefaults
                                zone:2];
}
-(NSString*) timeInSpeedZ4AsString;
{
   return [self timeInNonHRZAsString:kSpeedDefaults
                                zone:1];
}
-(NSString*) timeInSpeedZ5AsString;
{
   return [self timeInNonHRZAsString:kSpeedDefaults
                                zone:0];
}

-(NSString*) timeInPaceZ1AsString;
{
   return [self timeInNonHRZAsString:kPaceDefaults
                                zone:4];
}
-(NSString*) timeInPaceZ2AsString
{
   return [self timeInNonHRZAsString:kPaceDefaults
                                zone:3];
}
-(NSString*) timeInPaceZ3AsString
{
   return [self timeInNonHRZAsString:kPaceDefaults
                                zone:2];
}
-(NSString*) timeInPaceZ4AsString
{
   return [self timeInNonHRZAsString:kPaceDefaults
                                zone:1];
}
-(NSString*) timeInPaceZ5AsString
{
   return [self timeInNonHRZAsString:kPaceDefaults
                                zone:0];
}


- (float)timeInHRZone:(int)zne
{
   if (_cachedTimeInHRZ[zne] == BAD_FLOAT)
   {
      float ans = 0.0;
      if ((_track == nil) && (_lap == nil))
      {
         NSEnumerator *enumerator = [_children objectEnumerator];
         TrackBrowserItem* bi;
         while ((bi = [enumerator nextObject])) 
         {
            ans += [bi timeInHRZone:zne];
         }
      }
      else if (_lap == nil)
      {
         ans = [_track timeInHRZone:zne];
      }
      else
      {
         ans = [_track timeLapInHRZone:zne lap:_lap];
      }
      
      _cachedTimeInHRZ[zne] = ans;
   }
   return _cachedTimeInHRZ[zne];
}


- (float)timeInNonHRZone:(int)ty zone:(int)zne
{
	if (_cachedTimeInNonHRZ[ty][zne] == BAD_FLOAT)
	{
		float ans = 0.0;
		if ((_track == nil) && (_lap == nil))
		{
			NSEnumerator *enumerator = [_children objectEnumerator];
			TrackBrowserItem* bi;
			while ((bi = [enumerator nextObject])) 
			{
				ans += [bi timeInNonHRZone:ty zone:zne];
			}
		}
		else if (_lap == nil)
		{
			ans = [_track timeInNonHRZone:ty zone:zne];
		}
		else
		{
			ans = [_track timeLapInNonHRZone:ty zone:zne lap:_lap];
		}
		
		_cachedTimeInNonHRZ[ty][zne] = ans;
	}
	return _cachedTimeInNonHRZ[ty][zne];
}




-(float) timeInHRZ1AsFloat
{
   return [self timeInHRZone:0];
}
-(float) timeInHRZ2AsFloat
{
   return [self timeInHRZone:1];
}
-(float) timeInHRZ3AsFloat
{
   return [self timeInHRZone:2];
}
-(float) timeInHRZ4AsFloat
{
   return [self timeInHRZone:3];
}
-(float) timeInHRZ5AsFloat
{
   return [self timeInHRZone:4];
}


-(float) timeInALTZ1AsFloat
{
	return [self timeInNonHRZone:kAltitudeDefaults
							zone:0];
}
-(float) timeInALTZ2AsFloat
{
	return [self timeInNonHRZone:kAltitudeDefaults
							zone:1];
}
-(float) timeInALTZ3AsFloat
{
	return [self timeInNonHRZone:kAltitudeDefaults
							zone:2];
}
-(float) timeInALTZ4AsFloat
{
	return [self timeInNonHRZone:kAltitudeDefaults
							zone:3];
}
-(float) timeInALTZ5AsFloat
{
	return [self timeInNonHRZone:kAltitudeDefaults
							zone:4];
}



-(float) timeInCDZ1AsFloat
{
   return [self timeInNonHRZone:kCadenceDefaults
						   zone:0];
}
-(float) timeInCDZ2AsFloat
{
   return [self timeInNonHRZone:kCadenceDefaults
						   zone:1];
}
-(float) timeInCDZ3AsFloat
{
   return [self timeInNonHRZone:kCadenceDefaults
						   zone:2];
}
-(float) timeInCDZ4AsFloat
{
   return [self timeInNonHRZone:kCadenceDefaults
						   zone:3];
}
-(float) timeInCDZ5AsFloat
{
   return [self timeInNonHRZone:kCadenceDefaults
						   zone:4];
}


-(float) timeInGDZ1AsFloat
{
   return [self timeInNonHRZone:kGradientDefaults
						   zone:0];
}
-(float) timeInGDZ2AsFloat
{
   return [self timeInNonHRZone:kGradientDefaults
						   zone:1];
}
-(float) timeInGDZ3AsFloat
{
   return [self timeInNonHRZone:kGradientDefaults
						   zone:2];
}
-(float) timeInGDZ4AsFloat
{
   return [self timeInNonHRZone:kGradientDefaults
						   zone:3];
}
-(float) timeInGDZ5AsFloat
{
   return [self timeInNonHRZone:kGradientDefaults
						   zone:4];
}


-(float) timeInPCZ1AsFloat
{
   return [self timeInNonHRZone:kPaceDefaults
						   zone:4];
}
-(float) timeInPCZ2AsFloat
{
   return [self timeInNonHRZone:kPaceDefaults
						   zone:3];
}

-(float) timeInPCZ3AsFloat
{
   return [self timeInNonHRZone:kPaceDefaults
						   zone:2];
}
-(float) timeInPCZ4AsFloat
{
   return [self timeInNonHRZone:kPaceDefaults
						   zone:1];
}
-(float) timeInPCZ5AsFloat
{
   return [self timeInNonHRZone:kPaceDefaults
						   zone:0];
}

-(float) timeInSPZ1AsFloat
{
   return [self timeInNonHRZone:kSpeedDefaults
						   zone:0];
}
-(float) timeInSPZ2AsFloat
{
   return [self timeInNonHRZone:kSpeedDefaults
						   zone:1];
}
-(float) timeInSPZ3AsFloat
{
   return [self timeInNonHRZone:kSpeedDefaults
						   zone:2];
}
-(float) timeInSPZ4AsFloat
{
   return [self timeInNonHRZone:kSpeedDefaults
						   zone:3];
}
-(float) timeInSPZ5AsFloat
{
   return [self timeInNonHRZone:kSpeedDefaults
						   zone:4];
}

-(NSString*) timeInHRZ1AsString
{
   return [self timeInHRZAsString:1];
}


-(NSString*) timeInHRZ2AsString
{
   return [self timeInHRZAsString:2];
}


-(NSString*) timeInHRZ3AsString
{
   return [self timeInHRZAsString:3];
}


-(NSString*) timeInHRZ4AsString
{
   return [self timeInHRZAsString:4];
}

-(NSString*) timeInHRZ5AsString
{
   return [self timeInHRZAsString:5];
}

- (NSString*) activity
{
   if (_track != nil)
      return [_track attribute:kActivity];
   else
      return @"";
}


- (NSString*) equipment
{
   if (_track != nil)
   {
	   if ([_track staleEquipmentAttr])
	   {
		   [_track setAttribute:kEquipment
				   usingString:[[EquipmentLog sharedInstance] nameStringOfEquipmentItemsForTrack:_track]];
		   [_track setStaleEquipmentAttr:NO];
	   }
		   
	   return [_track attribute:kEquipment];
   }
   else
      return @"";
}


- (float) weight
{
   if (_cachedWeight == BAD_FLOAT)
   {
      float answer = 0.0;
      if (_track == nil)
      {
         float totalDuration = [self durationAsFloat];
         if (totalDuration > 0.0)
         {
            float sum = 0;
            NSEnumerator *enumerator = [_children objectEnumerator];
            TrackBrowserItem* bi;
            while ((bi = [enumerator nextObject])) 
            {
               float td = [bi durationAsFloat];
               sum += ([bi weight] * td);
            }
            answer = sum/totalDuration;
         }
      } 
      else
      {
         answer = [Utils convertWeightValue:[_track weight]];
      }
      _cachedWeight = answer;
   }
   return _cachedWeight;
}


- (NSString*) effort;
{
   if (_track != nil)
      return [_track attribute:kEffort];
   else
      return @"";
}


- (NSString*) disposition;
{
   if (_track != nil)
      return [_track attribute:kDisposition];
   else
      return @"";
}


- (NSString*) weather
{
   if (_track != nil)
      return [_track attribute:kWeather];
   else
      return @"";
}


- (NSString*) eventType
{
   if (_track != nil)
      return [_track attribute:kEventType];
   else
      return @"";
}


-(NSString*)deviceNameFromID:(int)deviceID
{
	NSString* s = nil;
	if (deviceID <= 0)
	{
		s = @"not available";
	}
	else
	{
		s = [Utils deviceNameForID:deviceID];
		if (s == nil)
		{
			s = [NSString stringWithFormat:@"Product code %d", deviceID];
		}
	}
	return s;
}


-(NSString*) device
{
	if (_track != nil)
		return [self deviceNameFromID:[_track deviceID]];
	else
		return @"";
}


-(NSString*) firmwareVersion
{
	if (_track != nil)
		return [NSString stringWithFormat:@"%d", [_track firmwareVersion]];
	else
		return @"";
}



@end
