//
//  GarminFIT.h
//  Ascent
//
//  Created by Rob Boyer on 2/13/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;

@interface GarminFIT : NSObject 
{
	NSDate*							startDate;
	NSDate*							currentTimeInSession;
	NSDate*							refDate;
	NSDate*                         dataPointDeltaBasisDate;
	NSURL*							fitURL;
	float                           lastGoodDistance;
	float                           lapStartDistance; // activity-wide distance where lap starts
	float                           lapFirstDistance; // first distance reading for lap (may always be 0)
	float							lastHeartRate;
	float							lastCadence;
	float							lastPower;
	float							lastSpeed;
	float							lastAltitude;
	float							lastLatitude, lastLongitude;
}	


-(GarminFIT*)initWithFileURL:(NSURL*)url;
-(BOOL)import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray;

@end
