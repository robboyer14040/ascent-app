//
//  TCX.h
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TrackPoint;

@interface TCX : NSObject <NSXMLParserDelegate>
{
	// used during import operations
	BOOL							inHR;
	BOOL                            inPoint;
	BOOL                            inLap;
	BOOL                            inActivity;
	BOOL                            isHST;
	BOOL                            haveGoodAltitude;
	BOOL                            haveGoodDistance;
	BOOL                            haveGoodLatLon;
	BOOL							haveGoodSpeed;
	BOOL							haveGoodCadence;
	BOOL							haveGoodHeartRate;
	BOOL							haveGoodPower;
	BOOL                            isDeadMarker;
	BOOL							inDeadZone;
	BOOL							insertDeadZone;
	Track*                          currentImportTrack;
	Lap*                            currentImportLap;
    Lap*                            lastLap;
	TrackPoint*                     currentImportPoint;
	NSMutableArray*                 currentImportLapArray;
	NSMutableArray*                 currentImportPointArray;
	NSMutableArray*                 currentImportTrackArray;
	NSMutableString*                currentStringValue;
	NSString*						currentActivity;
	NSURL*                          xmlURL;
	NSData*							importData;
	NSTimeInterval                  ignoreInterval;
	NSTimeInterval                  startDeadZoneWallClockDelta;
	NSDate*							currentPointStartTime;
	NSDate*							lastPointStartTime;
	NSDate*							currentLapStartTime;
	NSDate*							currentTrackStartTime;
	float                           lastGoodDistance;
	float                           distanceSoFar;
	float                           lapStartDistance; // activity-wide distance where lap starts
	float                           lapFirstDistance; // first distance reading for lap (may always be 0)
	float							lastHeartRate;
	float							lastCadence;
	float							lastPower;
	float							lastSpeed;
	float							lastAltitude;
	float							lastLatitude, lastLongitude;
	int                             numLapPoints;
	int								numTracksWithinLap;
	int								versionMajor, versionMinor, buildMajor, buildMinor;
	int								tracksInLap;
}


-(TCX*)initWithData:(NSData*)data;
-(TCX*)initWithFileURL:(NSURL*)url;
-(BOOL)import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray;
-(BOOL)export:(NSArray*)trackArray;
-(void)setCurrentActivity:(NSString*)a;

@end
