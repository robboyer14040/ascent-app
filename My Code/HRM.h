//
//  HRM.h
//  Ascent
//
//  Created by Rob Boyer on 4/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TrackPoint;

@interface HRM : NSObject 
{
	NSURL*                          hrmURL;
	Track*                          currentImportTrack;
	Lap*                            currentImportLap;
	TrackPoint*                     currentImportPoint;
	NSMutableArray*                 importedLaps;
	NSMutableArray*					importedPoints;
	NSString*						startDate;
	NSString*						startTime;
	NSMutableString*				notes;
	NSCalendarDate*					startDateTime;
	NSTimeInterval					duration;
	NSTimeInterval					lapSeconds;
	int								version;
	int								monitor;
	int								timeInterval;
	int								maxHR;
	int								weight;
	int								lapCount;
	BOOL							hasSpeed;
	BOOL							hasCadence;
	BOOL							hasAltitude;
	BOOL							hasPower;
	BOOL							hasEuroUnits;
	BOOL							hasHRDataOnly;
}
-(HRM*) initHRMWithFileURL:(NSURL*)url;
-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray;

@end
