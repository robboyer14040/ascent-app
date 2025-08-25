//
//  KML.h
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TrackPoint;

@interface KML : NSObject 
{
   // used during import operations
   BOOL                             inPoint;
   BOOL                             inLap;
   BOOL                             inActivity;
   BOOL                             inTrack;
   Track*                           currentImportTrack;
   Lap*                             currentImportLap;
   TrackPoint*                      currentImportPoint;
   NSMutableArray*                  currentImportLapArray;
   NSMutableArray*                  currentImportPointArray;
   NSMutableArray*                  currentImportTrackArray;
   NSMutableString*                 currentStringValue;
   NSMutableString*                 currentActivity;
   NSString*                        currentTrackName;
   NSURL*                           xmlURL;
}


-(KML*) initKMLWithFileURL:(NSURL*)url;
//-(BOOL) import:(NSMutableArray*)trackArray laps:(NSMutableArray*)lapArray;
- (BOOL) exportTrack:(Track*)track;

@end
