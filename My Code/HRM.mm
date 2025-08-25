//
//  HRM.mm
//  Ascent
//
//  Created by Rob Boyer on 4/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HRM.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Utils.h"


@interface NSString(MyExt)
-(BOOL) containsString:(NSString*)s;
@end

@implementation NSString(MyExt)
-(BOOL) containsString:(NSString*)s
{
	NSRange r = [self rangeOfString:s];
	return r.location != NSNotFound;
}
@end



@interface HRM (Private)
-(NSArray*) arrayifyHRMBuffer:(NSString*)buf;
-(void) parse:(NSArray*)arr;
-(int) processParams:(NSArray*)arr startingAtLine:(int)startLine;
-(int) processLaps:(NSArray*)arr startingAtLine:(int)startLine;
-(int) processData:(NSArray*)arr startingAtLine:(int)startLine;
-(int) processNote:(NSArray*)arr startingAtLine:(int)startLine;
-(int) processLapNotes:(NSArray*)arr startingAtLine:(int)startLine;
-(int) processTrainingLog:(NSArray*)arr startingAtLine:(int)startLine;
@end


@implementation HRM


-(HRM*) initHRMWithFileURL:(NSURL*)url
{
	self = [super init];
	if (self)
	{
		hrmURL = url;
		duration = 0;
		currentImportTrack = [[Track alloc] init];
		currentImportPoint = nil;
		currentImportLap = nil;
		importedPoints = [NSMutableArray arrayWithCapacity:64];
		importedLaps = [NSMutableArray arrayWithCapacity:4];
		startDate = startTime = nil;
		notes = nil;
		startDateTime = nil;
		weight = -1;
		lapCount = 0;
		lapSeconds = 0;
	}
	return self;
}


-(void) dealloc
{
}


-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray
{
	[trackArray removeAllObjects];
	[importedPoints removeAllObjects];
	[importedLaps removeAllObjects];
	
	NSString* path = [hrmURL path];
	NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath:path];
	if (fh)
	{
		NSData* data = [fh readDataToEndOfFile];
		if (data)
		{
			NSString* buf = [NSString stringWithCString:(const char*)[data bytes]
											   encoding:NSASCIIStringEncoding];
			if (buf) 
			{
				NSArray* arr = [self arrayifyHRMBuffer:buf];
				if (arr) [self parse:arr];
				if (currentImportTrack)
				{
					[trackArray addObject:currentImportTrack];
				}
			}
		}
	}
	return [trackArray count] > 0;
}


-(NSArray*) arrayifyHRMBuffer:(NSString*)buf
{
	int slen = [buf length];
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:100];
	NSUInteger startIdx, contentsIdx;
	NSUInteger endIdx = 0;
	while (endIdx < slen)
	{
		NSRange range = NSMakeRange(endIdx, 1);
		[buf getLineStart:&startIdx 
					  end:&endIdx 
			  contentsEnd:&contentsIdx 
				 forRange:range];
		NSString* line = [buf substringWithRange:NSMakeRange(startIdx, contentsIdx-startIdx)];
		[arr addObject:line];
	}
	return arr;
}


-(void) completeTrack
{
 if (currentImportTrack != nil)
	{
		int numPoints = [importedPoints count];
		if (numPoints > 0)
		{
            TrackPoint* pt = [importedPoints objectAtIndex:0];
            //NSDate* cd = [pt date];
            [currentImportTrack setCreationTime:startDateTime];
            pt = [importedPoints objectAtIndex:(numPoints-1)];
            [currentImportTrack setDistance:[pt distance]]; 
            [currentImportTrack setPoints:importedPoints];
			if (weight > 0) [currentImportTrack setWeight:weight];
			if (notes) [currentImportTrack setAttribute:kNotes
											usingString:notes];
			if (importedLaps && [importedLaps count] > 0) [currentImportTrack setLaps:importedLaps];
			[currentImportTrack fixupTrack];
#if 0
			if (currentActivity != nil) [currentImportTrack setAttribute:kActivity 
															 usingString:currentActivity];
			if (currentTrackName != nil) 
			{
				[currentImportTrack setName:currentTrackName];
				[currentImportTrack setAttribute:kName
									 usingString:currentTrackName];
			}
			[currentImportTrackArray addObject:currentImportTrack];
#endif
		}
	}
}


-(void) parse:(NSArray*)arr
{
	@try 
	{
		int num = [arr count];
		int line = 0;
		while (line < num)
		{
			NSString* s = [arr objectAtIndex:line];
			if      ([s containsString:@"[Params]"])		line = [self processParams:arr		startingAtLine:line+1];
			else if ([s containsString:@"[IntTimes]"])		line = [self processLaps:arr		startingAtLine:line+1];
			else if ([s containsString:@"[HRData]"])		line = [self processData:arr		startingAtLine:line+1];
			else if ([s containsString:@"[Note]"])			line = [self processNote:arr		startingAtLine:line+1];
			else if ([s containsString:@"[IntNotes]"])		line = [self processLapNotes:arr	startingAtLine:line+1];
			else if ([s containsString:@"[TrainingLog]"])	line = [self processTrainingLog:arr startingAtLine:line+1];
			else ++line;
		}
		[self completeTrack];
	}
	@catch (NSException *exception) 
	{
	}
}


-(NSArray*) parseHHMMSS:(NSString*)s
{
	NSRange r = [s rangeOfString:@":"];
	int hh = [[s substringWithRange:NSMakeRange(0, r.location)] intValue];
	int mm = [[s substringWithRange:NSMakeRange(r.location+1, 2)] intValue];
	int ss = [[s substringWithRange:NSMakeRange(r.location+4, 2)] intValue];
	NSArray* arr = [NSArray arrayWithObjects:[NSNumber numberWithInt:hh],
											 [NSNumber numberWithInt:mm],
											 [NSNumber numberWithInt:ss], nil];
	return arr;
}


-(void)calcStartDateTime
{
	int yr = [[startDate substringWithRange:NSMakeRange(0, 4)] intValue];
	int mo = [[startDate substringWithRange:NSMakeRange(4, 2)] intValue];
	int da = [[startDate substringWithRange:NSMakeRange(6, 2)] intValue];
	NSArray* arr = [self parseHHMMSS:startTime];
	startDateTime = [[NSCalendarDate dateWithYear:yr
											month:mo
											  day:da
											 hour:[[arr objectAtIndex:0] intValue]
										   minute:[[arr objectAtIndex:1] intValue]
										   second:[[arr objectAtIndex:2] intValue]
										 timeZone:[NSTimeZone localTimeZone]] retain];
}	


-(void) processParamValue:(NSArray*)lineArr
{
	if ([lineArr count] > 1)
	{
		NSString* key = [lineArr objectAtIndex:0];
		NSString* val = [lineArr objectAtIndex:1];
		if ([key isEqualToString:@"Version"])
		{
			version = [val intValue];
		}
		else if ([key isEqualToString:@"Monitor"])
		{
			monitor = [val intValue];
		}
		else if ([key isEqualToString:@"Mode"])
		{
			int idx = 1;
			NSRange r = NSMakeRange(0, 1);
			if ([val length] > 3)
			{
				r.length = 2;
				idx = 2;
			}
			int v = [[val substringWithRange:r] intValue];
			hasCadence		= (v == 0);
			hasAltitude		= (v == 1);
			hasHRDataOnly	= [val characterAtIndex:idx++] == '0';
			hasEuroUnits	= [val characterAtIndex:idx++] == '0';
		}
		else if ([key isEqualToString:@"SMode"])
		{
			hasSpeed		= [val characterAtIndex:0] == '1';
			hasCadence		= [val characterAtIndex:1] == '1';
			hasAltitude		= [val characterAtIndex:2] == '1';
			hasPower		= [val characterAtIndex:3] == '1';
			hasEuroUnits	= [val characterAtIndex:7] == '0';
			if ((version >= 107) && ([val length] > 8))
			{
				hasHRDataOnly = [val characterAtIndex:8] == '0';
			}
		}
		else if ([key isEqualToString:@"Date"])
		{
			startDate = val;
			if (startTime) [self calcStartDateTime];
		}
		else if ([key isEqualToString:@"StartTime"])
		{
			startTime = val;
			if (startDate) [self calcStartDateTime];
		}
		else if ([key isEqualToString:@"Length"])
		{
			NSArray* arr = [self parseHHMMSS:val];
			duration = ([[arr objectAtIndex:0] intValue] * 60 * 60) +
					   ([[arr objectAtIndex:1] intValue] * 60) +
					   ([[arr objectAtIndex:2] intValue]);
			
		}
		else if ([key isEqualToString:@"Interval"])
		{
			timeInterval = [val intValue];
		}
		else if ([key isEqualToString:@"Upper1"])
		{
		}
		else if ([key isEqualToString:@"Lower1"])
		{
		}
		else if ([key isEqualToString:@"Upper2"])
		{
		}
		else if ([key isEqualToString:@"Lower2"])
		{
		}
		else if ([key isEqualToString:@"Upper3"])
		{
		}
		else if ([key isEqualToString:@"Lower3"])
		{
		}
		else if ([key isEqualToString:@"Timer1"])
		{
		}
		else if ([key isEqualToString:@"Timer2"])
		{
		}
		else if ([key isEqualToString:@"Timer3"])
		{
		}
		else if ([key isEqualToString:@"ActiveLimit"])
		{
		}
		else if ([key isEqualToString:@"MaxHR"])
		{
		}
		else if ([key isEqualToString:@"RestHR"])
		{
		}
		else if ([key isEqualToString:@"StartDelay"])
		{
		}
		else if ([key isEqualToString:@"VO2Max"])
		{
		}
		else if ([key isEqualToString:@"Weight"])
		{
			weight = [val intValue];
		}
		else if ([key isEqualToString:@"Sport"])
		{
		}
	}
}


-(int) processParams:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	NSString* s = [arr objectAtIndex:line];
	int num = [arr count];
	while (![s isEqualToString:@""] && ([s characterAtIndex:0] != '[') && (line < num))
	{
		[self processParamValue:[s componentsSeparatedByString:@"="]];
		++line;
		if (line < num) s = [arr objectAtIndex:line];
	}
	return line;
}


-(void) processLapValue:(NSArray*)lineArr
{
	if ([lineArr count] > 1)
	{
		NSString* s = [lineArr objectAtIndex:0];
		if ([s containsString:@":"] && startDateTime)
		{
			NSArray* timeArr = [self parseHHMMSS:s];
			if ([timeArr count] >= 3)
			{
				NSDate* lapStart = [[NSDate alloc] initWithTimeInterval:lapSeconds
															  sinceDate:startDateTime];
				int lapEndSeconds = ([[timeArr objectAtIndex:0] floatValue] * 3600.0) +
									([[timeArr objectAtIndex:1] floatValue] * 60.0) + 
									([[timeArr objectAtIndex:2] floatValue]);
				Lap* lap = [[Lap alloc] initWithGPSData:lapCount++
								 startTimeSecsSince1970:[lapStart timeIntervalSince1970]
											  totalTime:(lapEndSeconds - lapSeconds) * 100 
										  totalDistance:0 * 1609.344  // to meters
											   maxSpeed:0
											   beginLat:BAD_LATLON
											   beginLon:BAD_LATLON
												 endLat:BAD_LATLON
												 endLon:BAD_LATLON
											   calories:0
												  avgHR:0
												  maxHR:0
												  avgCD:0
											  intensity:0
												trigger:0];
				[lap setStartingWallClockTimeDelta:lapSeconds];
				[importedLaps addObject:lap];
				lapSeconds = lapEndSeconds;
			}
		}
	}
}


-(int) processLaps:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	NSString* s = [arr objectAtIndex:line];
	int num = [arr count];
	while (![s isEqualToString:@""] && ([s characterAtIndex:0] != '[') && (line < num))
	{
		[self processLapValue:[s componentsSeparatedByString:@"\t"]];
		++line; 
		if (line < num) s = [arr objectAtIndex:line];
	}
	return line;
}


-(void) processDataLine:(NSString*)lineStr time:(float*)pointTimePtr distance:(float*)currentDistancePtr
{
	NSArray* arr = [lineStr componentsSeparatedByString:@"\t"];
	int num = [arr count];
	float alt = 0.0;
	float sp = 0.0;
	float cd = 0.0;
	float power = 0.0;
	int fieldIndex = 0;
	if (num > 0) 
	{
		float hr = [[arr objectAtIndex:fieldIndex++] floatValue];
		if ((num > fieldIndex) && hasSpeed) sp = [[arr objectAtIndex:fieldIndex++] floatValue]/10.0;
		if (hasEuroUnits) sp = KilometersToMiles(sp);
		if ((num > fieldIndex) && hasCadence) cd = [[arr objectAtIndex:fieldIndex++] floatValue];
		if ((num > fieldIndex) && hasAltitude) alt = [[arr objectAtIndex:fieldIndex++] floatValue];
		if (hasEuroUnits) alt = MetersToFeet(alt);
		if ((num > fieldIndex) && hasPower) power = [[arr objectAtIndex:fieldIndex++] floatValue];
		*currentDistancePtr += (sp * ((float)timeInterval)/3600.0);
		TrackPoint* tp = [[TrackPoint alloc] initWithGPSData:*pointTimePtr
												  activeTime:*pointTimePtr
													latitude:BAD_LATLON
												   longitude:BAD_LATLON
													altitude:alt
												   heartrate:hr
													 cadence:cd
												 temperature:0.0
													   speed:sp
													distance:*currentDistancePtr];
		[tp setPower:power];
		[importedPoints addObject:tp];
	}		
}


-(int) processData:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	NSString* s = [arr objectAtIndex:line];
	int num = [arr count];
	float elapsedTime = 0.0;
	float distance = 0.0;
	while (![s isEqualToString:@""] && ([s characterAtIndex:0] != '[') && (line < num))
	{
		[self processDataLine:s
						 time:&elapsedTime
					 distance:&distance];
		 elapsedTime += timeInterval;
		++line;
		if (line < num) s = [arr objectAtIndex:line];
	}
	return line;
}


-(int) processNote:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	notes = [NSMutableString string];
	NSString* s = [arr objectAtIndex:line];
	int num = [arr count];
	while (![s isEqualToString:@""] && ([s characterAtIndex:0] != '[') && (line < num))
	{
		[notes appendString:s];
		 ++line;
		 if (line < num) s = [arr objectAtIndex:line];
	}
	return line;
}


-(int) processLapNotes:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	return line;
}


-(int) processTrainingLog:(NSArray*)arr startingAtLine:(int)startLine
{
	int line = startLine;
	return line;
}


@end
