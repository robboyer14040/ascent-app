//
//  GPX.h
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TrackPoint;

typedef void (*tLapAvgMaxSetter)(id, SEL, int);

@interface GPX : NSObject <NSXMLParserDelegate>
{
	// used during import operations
	BOOL                            inPoint;
	BOOL                            inLap;
	BOOL                            inActivity;
	BOOL                            inTrack;
	BOOL                            pointsHaveTime;
	BOOL                            haveActivityStartTime;
	BOOL                            skipTrack;
	BOOL							distanceExtensionFound;
	tLapAvgMaxSetter				summarySetter;
	Track*                          currentImportTrack;
	Lap*                            currentImportLap;
	TrackPoint*                     currentImportPoint;
	NSArray*                        importTrackArray;
	NSXMLParser*                    parser;
	NSMutableArray*                 currentImportLapArray;
	NSMutableArray*                 currentImportPointArray;
	NSMutableArray*                 currentImportTrackArray;
	NSMutableString*                currentStringValue;
	NSString*						currentActivity;
	NSString*                       currentTrackName;
	NSURL*                          xmlURL;
	NSWindowController*             parentWindowController;
	NSDate*                         activityStartDate;
	NSDate*							pointStartDate;
	NSDate*							lapStartTime;
}



-(GPX*) initGPXWithFileURL:(NSURL*)url windowController:(NSWindowController*)wc;
-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray;
- (BOOL) exportTrack:(Track*)track;

@end
