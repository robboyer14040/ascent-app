//
//  TrackBrowserDocument.m
//  TLP
//
//  Created by Rob Boyer on 7/10/06.
//  Copyright rcb Construction 2006 . All rights reserved.
//
#import "Defs.h"
#import "TrackBrowserDocument.h"
#import "MainWindowController.h"
#import "ADWindowController.h"
#import "TrackPoint.h"
#import "Track.h"
#import "LatLong-UTMconversion.h"
#import "TrackBrowserItem.h"
#import "BackupDelegate.h"
#import "BrowserInfo.h"
#import "Lap.h"
#import "Utils.h"
#import "RegController.h"
#import "TCX.h"
#import "GPX.h"
#import "KML.h"
#import "HRM.h"
#import "GarminFIT.h"
#import <stdio.h>
#import "ProgressBarController.h"
#import "StringAdditions.h"
#import "EquipmentLog.h"
#import "ActivityStore.h"
#import "TrackPointStore.h"
#import "DatabaseManager.h"
#import "IdentifierStore.h"
#import "SplashPanelController.h"
#import "TrackBrowserData.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AscentImporter.h"
#import "AscentExporter.h"
#import "LibraryController.h"

#include <unistd.h>        // for sleep()


#define DEBUG_SYNC      0&&ASCENT_DBG

static void ASCLogPathWritable(NSURL *u) {
    if (!u) return;
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:u.path error:NULL];
    NSNumber *perm = a[NSFilePosixPermissions];
    BOOL w = (access(u.path.fileSystemRepresentation, W_OK) == 0);
    NSLog(@"[Save] target=%@ perms=%@ writable=%d", u.path, perm, w);
}


@interface NSString (FilePathModDateComparison)
- (NSComparisonResult)compareFileModDates:(NSString*)anotherPath;
@end

@implementation NSString (FilePathModDateComparison)
-(NSComparisonResult) compareFileModDates:(NSString*)anotherFilePath
{
	NSError* error;

	NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary* attrs = [fm attributesOfItemAtPath:anotherFilePath 
									  error:&error];
	NSDate* anotherFileModDate = [attrs objectForKey:NSFileModificationDate];
	attrs = [fm attributesOfItemAtPath:(NSString*)self 
								 error:&error];
	NSDate* fileModDate = [attrs objectForKey:NSFileModificationDate];
	return [fileModDate compare:anotherFileModDate];
}
@end


NSString* getTracksPath()
{
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *path = [NSMutableString stringWithString:[paths objectAtIndex:0]];
    path = [path stringByAppendingPathComponent:PROGRAM_NAME];
    [Utils verifyDirAndCreateIfNecessary:path];
    path = [path stringByAppendingPathComponent:@"Tracks"];
    [Utils verifyDirAndCreateIfNecessary:path];
    return path;
}


//--------- TrackBrowserDocument ---------------------------------------------------------------------------------

@interface TrackBrowserDocument ()
{
    TrackBrowserData *_stagedBrowserData;   // parsed off-main, consumed by readFromURL:
    LibraryController *_libraryController;
    AscentLibrary *_library;
}
@property (nonatomic, strong) NSURL *stagedExportURL; // temp file we built
@property(nonatomic, assign) BOOL hasSecurityScope;
@property(nonatomic, retain) NSURL *scopedURL;
@property (nonatomic, strong) LibraryController *libraryController;
@property (nonatomic, strong) AscentLibrary *library;
@property (nonatomic, strong) NSData *libraryBookmark;

- (void)syncFileModDateFromDiskAtURL:(NSURL *)u;
@end

@interface NSDocument (ReadCompletionShim)
- (void)readFromURL:(NSURL *)url
             ofType:(NSString *)typeName
  completionHandler:(void (^)(NSError * _Nullable error))handler;
@end


@interface TrackBrowserDocument (Private)
-(int)loadGPSData:(Track**)lastTrackLoaded;
-(void)addPointsAtIndices:(Track*)track selected:(NSIndexSet*)is pointsToAdd:(NSArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset;
-(BOOL)trackExistsAtTime:(NSDate*)st startIndex:(int*)startIdx slop:(int)ss;
-(void)trackArrayChanged:(BOOL)rebuildBrowser;
-(void) copyTrackAttributes:track toTracks:(NSArray*)newTracks;
-(Track*) splitTrack:(Track*)track atIndices:(NSIndexSet*)is;
-(void) addTracksToDB:(NSArray*)arr alsoAddToTrackArray:(BOOL)ata;
-(void)syncDirect:(int*)numLoadedPtr lastTrackLoaded:(Track**)lastTrackLoadedPtr;
- (void)_presentProgress:(ProgressBarController *)pbc total:(int)total message:(NSString*)msg;
- (void)_dismissProgress;
- (void)teardownDocumentDBM;


@end


int kSearchTitles			= 0x0001;
int kSearchNotes			= 0x0002;
int kSearchKeywords			= 0x0004;
int kSearchActivityType		= 0x0008;
int kSearchEquipment		= 0x0010;
int kSearchEventType		= 0x0020;


@implementation TrackBrowserDocument

@synthesize equipmentLog;
@synthesize equipmentLogDataDict;
@synthesize equipmentTotalsNeedUpdate;
@synthesize docMetaData;
@synthesize documentDBM;
@synthesize activityStore;
@synthesize trackPointStore;
@synthesize identifierStore;
@synthesize libraryBookmark = _libraryBookmark;


+ (NSArray<UTType *> *)readableContentTypes {
    return @[
        [UTType typeWithIdentifier:@"com.montebellosoftware.ascent.tlp"],
        [UTType typeWithIdentifier:@"com.montebellosoftware.ascent.db"]
    ];
}

+ (NSArray<UTType *> *)writableContentTypes {
    return @[
        [UTType typeWithIdentifier:@"com.montebellosoftware.ascent.db"]
    ];
}

// Legacy APIs (pre-11) — harmless to keep alongside the new ones
+ (NSArray<NSString *> *)readableTypes {
    return @[@"com.montebellosoftware.ascent.tlp",
             @"com.montebellosoftware.ascent.db"];
}

+ (NSArray<NSString *> *)writableTypes {
    return @[@"com.montebellosoftware.ascent.db"];
}




- (id) init
{
    if ((self = [super init])) {
        NSURL *stateDir = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                  inDomains:NSUserDomainMask] firstObject];
        stateDir = [stateDir URLByAppendingPathComponent:@"Ascent" isDirectory:YES];
        _libraryController = [[LibraryController alloc] initWithStateDirectoryURL:stateDir];
		equipmentTotalsNeedUpdate = YES;
		currentlySelectedTrack = nil;
		selectedLap = nil;
        self.docMetaData = [[[TrackBrowserData alloc] init] autorelease];
		backupDelegate = [[BackupDelegate alloc] initWithDocument:self];
		tbWindowController = nil;
        databaseFileURL = nil;
		///FIXME equipmentLog = [EquipmentLog sharedInstance];
		///FIXME equipmentLogDataDict = [[NSMutableDictionary alloc] initWithCapacity:16];
	}
	return self;
}


- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
	// called when a NEW ACTIVITY DOCUMENT is created
	[self init];
	[equipmentLog buildEquipmentListFromDefaultAttributes:self];
	return self;
}


- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"doc DEALLOC %x rc: %d", self, [self retainCount]);
#endif
    [databaseFileURL release];
	[backupDelegate release];
	[self.docMetaData release];
    [_libraryController release];
    [_library release];
    [_libraryBookmark release];
	[selectedLap release];
	[currentlySelectedTrack release];
	[equipmentLog release];
	[equipmentLogDataDict release];
	[super dealloc];
}



- (void)setTracks:(NSMutableArray*)tracks
{
   [self.docMetaData setTrackArray:tracks];
}


-(NSString*)uuid
{
	return self.docMetaData.uuid;
}

#pragma mark TRACK FILE PARSING METHODS

#define BUF_SZ       1024

namespace
{
   // used while parsing
	time_t				sTrackStartTime;		// seconds since 1/1/1970
	time_t              startIgnoreTime;
	time_t              lastIgnoreTime;
	time_t              totalIgnoreTime;
	time_t              sPrevTime;
	BOOL                wasIgnoringData;
	float               prevDistance;
	float               prevSpeed;
	NSFileHandle*       sFile;
	NSData*             sBuffer;
	char*               sPtr;
	char*               sMaxPtr;
	NSString*           sTrackName;
	float               sDistanceOffset;
	TrackPoint*         sLastPoint;

	// tweak for 1.3.2 -- altitude may be bad, but distance ok.  Also allowed acceptance
	// if hr or cadence looked ok, may be useful for someone?
	BOOL  validPointData(float alt, float dist, int hr, int cad)
	{
	  return ((alt <  (1000.0 * 1000.0)) ||
			  (dist < (1000.0 * 1000.0)) ||
			  (hr > 0) ||
			  ((cad > 0) && (cad < 255)));
	}
}   


int readLine(char *srcbuf, char* outbuf, int outbuflen)
{
   int len = 0;
   while (*srcbuf != 0x0a && (len < (outbuflen-1)))
   {
      *outbuf++ = *srcbuf++;
      ++len;
   }
   return len;
}


BOOL readHeader(char* ptr, Track* track, char** optr)
{
	char buf[BUF_SZ];
	int count = readLine(ptr, buf, BUF_SZ);
	BOOL status = YES;
	if (count > 0)
	{
		int vers, index, numpts, deviceID;
		float deviceVersion;
		deviceID = -1;
		deviceVersion = 0.0;
		char tmpbuf[BUF_SZ];
		char junk[BUF_SZ];
		// note -- all strings are truncated to 64 chars max
		int num = sscanf(buf, "%d", &vers);
		if (num > 0)
		{
			if (vers > 1)
			{
				num = sscanf(buf, "%d %c%64[^\"]%c %64s %64s %d %d %d %f3.3", &vers, junk, tmpbuf, junk, junk, junk, &index, &numpts, &deviceID, &deviceVersion);
			}
			else
			{
				num = sscanf(buf, "%d %c%64[^\"]%c %64s %64s %d %d", &vers, junk, tmpbuf, junk, junk, junk, &index, &numpts);
			}
		}
		status = (num > 2) && (num != EOF);
		if (status)
		{
			size_t len = strlen(tmpbuf);
			if (len >= 64)
			{
				tmpbuf[64] = len;
			}
			else if (len >= 0)
			{
				tmpbuf[len] = 0;
			}
			sTrackName = [NSString stringWithCString:tmpbuf encoding:NSASCIIStringEncoding];
			[track setName:sTrackName];
			[track setDeviceID:deviceID];
			*optr = ptr + count + 1;
		}
	}
	return status;
}


int readDataLine(char *ptr, Track* track, NSMutableArray* points, char** optr)
{
   char buf[BUF_SZ];
   int count = readLine(ptr, buf, BUF_SZ);
   int status = 0;
   if (count > 0)
   {
      time_t creationTime;
      float lat, lon;
      int heartrate, cadence;
      float alt, temperature, speed, distance;
      char junk[BUF_SZ];
      int num = sscanf(buf, "%ld %s %s %f %f %f %d %d %f %f %f", 
                       &creationTime, junk, junk, &lon, &lat, &alt, &heartrate, &cadence, &temperature, &speed, &distance);
      status = ((num > 5) && (num != EOF)) ? 0 : -1;
      if (status != 0) return status;
      if (cadence == 255) cadence = 0;     // illegal cadence value, not present
      {
         if ([track creationTime] == nil)
         {
			 sPrevTime = creationTime;
			 sTrackStartTime = creationTime;
			 NSTimeInterval ti = (NSTimeInterval) creationTime;
			 [track setCreationTime:[NSDate dateWithTimeIntervalSince1970:ti]];
			 NSLog(@"     ***** SET CREATION TIME:%@", [track creationTime]);
         }
         if ([Utils boolFromDefaults:RCBDefaultAutoSplitEnabled])
         {
            int threshold = [Utils intFromDefaults:RCBDefaultAutoSplitMinutes];
            if (threshold < 30) threshold = 30;
            if ((creationTime - sPrevTime) > (threshold * 60.0))      
            {
               sDistanceOffset = prevDistance;
               return 1;      // start a new track.
            }
         }
         TrackPoint* pt;
         if (validPointData(alt, distance, heartrate, cadence))
         {
            if (wasIgnoringData)
            {
               wasIgnoringData = NO;
               totalIgnoreTime += ((lastIgnoreTime - startIgnoreTime)+1);
               sPrevTime = creationTime;
               prevDistance = distance;
            }
            distance = MetersToMiles(distance);
#if 0
            // handle Garmin 301, which doesn't output distance...manually calculate it
            if ((distance == 0.0) && (sLastPoint != nil) && [Utils validateLatitude:lat longitude:lon])
            {
               distance = prevDistance + [Utils latLonToDistanceInMiles:[sLastPoint latitude]
                                                                   lon1:[sLastPoint longitude]
                                                                   lat2:lat
                                                                   lon2:lon];
            }
#endif
            
            alt = MetersToFeet(alt);
            float deltaTime = (creationTime - sPrevTime);
            if (deltaTime > 0.0)
            {
               speed = (distance-prevDistance) * 60.0 * 60.0/deltaTime;
               prevSpeed = speed;
            }
            else
            {
               speed = prevSpeed;
            }
            prevDistance = distance;
            [track setDistance:distance - sDistanceOffset];
            pt = [[TrackPoint alloc] initWithGPSData:(creationTime - sTrackStartTime)
                                          activeTime:((creationTime-totalIgnoreTime) - sTrackStartTime)
                                            latitude:lat
                                           longitude:lon
                                            altitude:alt
                                           heartrate:heartrate
                                             cadence:cadence
                                         temperature:temperature
                                               speed:speed
                                            distance:distance - sDistanceOffset];
         }
         else
         {
            if (!wasIgnoringData)
            {
               wasIgnoringData = YES;
               startIgnoreTime = creationTime;
            }
            lastIgnoreTime = creationTime;
            pt = [[TrackPoint alloc] initWithDeadZoneMarker:(creationTime - sTrackStartTime)
											activeTimeDelta:((startIgnoreTime - totalIgnoreTime) - sTrackStartTime)];
         }
         sPrevTime = creationTime;
         [points addObject:pt];
         if ([pt validLatLon]) sLastPoint = pt;
         [pt autorelease];
      }
      *optr = ptr + count + 1;
   }
   return status;
}



- (Track*) readTrackFromFile:(NSString *)path isMore:(BOOL*)isMorePtr
{
   BOOL starting = (*isMorePtr == NO);
   if (starting)
   {
      NSFileManager* fm;
      fm = [NSFileManager defaultManager];
      sFile = [NSFileHandle fileHandleForReadingAtPath:path];
      if (sFile == nil)
      {
         *isMorePtr = NO;
         return nil;
      }
      
      sBuffer = [sFile readDataToEndOfFile];
      sPtr = (char*)[sBuffer bytes];
      sMaxPtr = sPtr + [sBuffer length];
   }
   Track *track = [[[Track alloc] init] autorelease];
   wasIgnoringData = NO;
   startIgnoreTime = lastIgnoreTime = totalIgnoreTime = 0;
   prevDistance = prevSpeed = 0.0;
   sLastPoint = nil;
   BOOL ok;
   if (starting)
   { 
      ok = readHeader(sPtr, track, &sPtr);
   }
   else
   {
      [track setName:sTrackName];      // use same as last time
      ok = YES;
   }
   int status = 0;
   if (ok)
   {
      while (sPtr < sMaxPtr) 
      {
         status = readDataLine(sPtr, track, [track points], &sPtr);
         if (status != 0) break;
      }
   }
   if (status == 1)
   {
      *isMorePtr = YES;
   }
   else
   {
      *isMorePtr = NO;
      [sFile closeFile];
   }
   return track;
}


bool readLapDataLine(char *ptr, NSMutableArray* laps, char** optr)
{
   char buf[1024];
   int count = readLine(ptr, buf, sizeof(buf));
   bool status = false;
   if (count > 0)
   {
      time_t startTime;
      float blat, blon, elat, elon;
      int index, avgHR, maxHR, avgCadence, intensity, trigger;
      unsigned int totalTime, calories;
      float maxSpeed, totalDistance;
      int num = sscanf(buf, "%d %ld %d %f %f %f %f %f %f %d %d %d %d %d %d", 
                       &index, &startTime, &totalTime, &totalDistance, &maxSpeed,
                       &blat, &blon, &elat, &elon, 
                       &calories, &avgHR, &maxHR, &avgCadence, &intensity, &trigger);
      status = (num > 9) && (num != EOF);
      if (status)
      {
         if (/*(blat != 180.0) && */ (totalDistance > 0.0) && (totalTime > 0))
         {      
            Lap* lap = [[[Lap alloc] initWithGPSData:index
							  startTimeSecsSince1970:startTime
										   totalTime:totalTime
									   totalDistance:totalDistance
											maxSpeed:maxSpeed
											beginLat:blat
											beginLon:blon
											  endLat:elat
											  endLon:elon
											calories:calories
											   avgHR:avgHR
											   maxHR:maxHR
											   avgCD:avgCadence
										   intensity:intensity
											 trigger:trigger] autorelease];

            [laps addObject:lap];
         }
         *optr = ptr + count + 1;
      }
   }
   return status;
}


- (NSMutableArray*) readLapData
{
   NSString* path = getTracksPath();
   path = [path stringByAppendingPathComponent:@"all.laps"];
   NSMutableArray* laps = [[[NSMutableArray alloc] init] autorelease];
   NSFileHandle* file = [NSFileHandle fileHandleForReadingAtPath:path];
   if (nil != file)
   {
      NSData*  buffer = [file readDataToEndOfFile];
      char* ptr = (char*)[buffer bytes];
      char* maxptr = ptr + [buffer length];
      while ((ptr < maxptr) && readLapDataLine(ptr, laps, &ptr))
         ;
      [file closeFile];
   }
   return laps;
}


-(void) processLapData:(NSMutableArray*)laps forTracks:(NSMutableArray*)newTracks
{
    NSUInteger lapCount = [laps count];
	// following algorithm depends on tracks being sorted in trackArray
	[newTracks sortUsingSelector:@selector(compareByDate:)];
    NSUInteger numTracks = [newTracks count];
	if ((numTracks > 0) && (lapCount > 0))
	{
		int lapIndex = 0;
		NSDate* earliestTrackDate = [[newTracks objectAtIndex:0] creationTime];
		int trackIndex = (int)[newTracks count] - 1;
		Lap* lap = [laps objectAtIndex:lapIndex];
		while ((trackIndex >= 0) && (lapIndex < lapCount))
		{
			if ([[lap origStartTime] compare:earliestTrackDate] == NSOrderedAscending) break;
			Track* track = [newTracks objectAtIndex:trackIndex];
			BOOL lapIsInTrack = [track isDateDuringTrack:[lap origStartTime]];
			while (!lapIsInTrack && ([[lap origStartTime] compare:[track creationTime]] == NSOrderedDescending) && (lapIndex < (lapCount-1)))
			{
				++lapIndex;
				lap = [laps objectAtIndex:lapIndex];
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


- (int)loadGPSData:(Track**)lastTrackLoaded
{   
	NSMutableArray* tracksNeedingFixup = [NSMutableArray arrayWithCapacity:16];
	[tbWindowController stopAnimations];
	NSFileManager* fm;
	fm = [NSFileManager defaultManager];
	Track* track;
	NSString* path = getTracksPath();
	NSDirectoryEnumerator* dirEnum = [fm enumeratorAtPath:path];
	const char* trkext = "trk";
	NSString* trackExt = [NSString stringWithCString:trkext encoding:NSASCIIStringEncoding];
	NSString* relTrackPath;
	NSMutableArray* trackArray = [self.docMetaData trackArray];
	int tracksAdded = 0;
	NSDate* lastSyncedTrackDate = nil;
	NSMutableArray* tracksJustSynced = [NSMutableArray arrayWithCapacity:16];
	while ((relTrackPath = [dirEnum nextObject]) != nil)
	{
		NSString* ext = [relTrackPath pathExtension];
#if ASCENT_DBG&&1
		NSLog(@"processing %s...\n", [relTrackPath UTF8String]);
#endif
		if ([ext isEqualToString:trackExt])
		{
			BOOL more = NO;
			sPtr = 0;
			sDistanceOffset = 0.0;
			while (more || (sPtr == 0))
			{
				NSString* fullPath = [path stringByAppendingPathComponent:relTrackPath];
				track = [self readTrackFromFile:fullPath isMore:(BOOL*)&more];
			
				if ((track != nil) && ([track creationTime] != 0))
				{
					[tracksJustSynced addObject:track];
				}
			}
		}
	}
	
	NSMutableArray* laps = [self readLapData];
#if ASCENT_DBG&&1
	NSLog(@"processing laps...\n");
#endif
	[self processLapData:laps
			   forTracks:tracksJustSynced];

	int si = 0;
	for (Track* track in tracksJustSynced)
	{
		BOOL contains = [trackArray containsObject:track];
		if (contains == NO)
		{
			contains = [self trackExistsAtTime:[track creationTime]
									startIndex:&si
										  slop:10.0];
		}
		if (contains == NO)
		{
			// make sure user hasn't deleted this track from this document already
			contains = [[self.docMetaData userDeletedTrackTimes] containsObject:[track creationTime]];
			if (contains == NO)
			{
                NSUInteger numTracks = [trackArray count];
				//if ([[docMetaData lastSyncTime] compare:[track creationTime]] == NSOrderedAscending) &&
				if ((numTracks <= kNumUnregisteredTracks) || [RegController CHECK_REGISTRATION])
				{
					[tracksNeedingFixup addObject:track];
					//[trackArray addObject:track];
					[self addTracksToDB:[NSArray arrayWithObject:track]
					alsoAddToTrackArray:YES];

					if (lastTrackLoaded) *lastTrackLoaded = track;
					lastSyncedTrackDate = [track creationTime];
					++tracksAdded;
				}
				else
				{
					[tbWindowController postNeedRegDialog:@"The unregistered version of Ascent is limited to 10 activites per document."  
														  @"Not all activities could be loaded."];
					goto getOut;
				}
			}
		}
	}
getOut:
	if (lastSyncedTrackDate != nil) [lastSyncedTrackDate retain];        // need to retain this *before* removing all objects below!
	NSArray* arr = [trackArray sortedArrayUsingSelector:@selector(comparator:)];
	[trackArray removeAllObjects];
	[trackArray addObjectsFromArray:arr];
	
	//[self processLapData:laps];

	if (tracksAdded > 0) 
	{
		if (lastSyncedTrackDate != nil)
		{
			[self.docMetaData setLastSyncTime:lastSyncedTrackDate];
		}
		[tracksNeedingFixup makeObjectsPerformSelector:@selector(doFixupAndCalcGradients)];
	}
	if (lastSyncedTrackDate != nil) [lastSyncedTrackDate release];
	return tracksAdded;
}


- (void)selectionChanged
{
    NSInteger row = [[tbWindowController trackTable]  selectedRow];
   TrackBrowserItem* bi = [[tbWindowController trackTable]  itemAtRow:row];
   if (bi != nil)
   {
      [self setCurrentlySelectedTrack:[bi track]];
   }
}


- (Track*)currentlySelectedTrack
{
	return currentlySelectedTrack;
}

- (void)setCurrentlySelectedTrack:(Track*)t
{
	if (t != currentlySelectedTrack)
	{
		[currentlySelectedTrack release];
		currentlySelectedTrack = t;
		[currentlySelectedTrack retain];
	}
}
   
- (Lap *)selectedLap {
	return [[selectedLap retain] autorelease];
}

- (void)setSelectedLap:(Lap *)value {
   if (selectedLap != value) 
   {
      [selectedLap release];
      selectedLap = value;
      [selectedLap retain];
   }
}

#if 0
-(NSDate*)getTrackStartTimeFromFileName:(NSString*)fn
{
    NSUInteger len = [fn length];
	if (len <= 18) return nil;
	NSRange r;
	r.length = 10;
	r.location = 0;
	NSMutableString* ds = [NSMutableString string];
	[ds appendString:[fn substringWithRange:r]];
	[ds appendString:@" "];
	r.length = 2;
	r.location = 11; 
	NSString* ts = [fn substringWithRange:r];
	[ds appendString:ts];
	[ds appendString:@":"];
	r.location = 14; 
	ts = [fn substringWithRange:r];
	[ds appendString:ts];
	[ds appendString:@":"];
	r.location = 17; 
	ts = [fn substringWithRange:r];
	[ds appendString:ts];
	[ds appendString:@" +0000"];
	return [NSDate dateWithString:ds];
}
#else
///AI  rewrite
- (NSDate *)getTrackStartTimeFromFileName:(NSString *)fn
{
    if (fn.length <= 18) return nil;

    NSMutableString *ds = [NSMutableString string];

    // Date portion (10 chars: "YYYY-MM-DD")
    [ds appendString:[fn substringWithRange:NSMakeRange(0, 10)]];
    [ds appendString:@" "];

    // Hour
    [ds appendString:[fn substringWithRange:NSMakeRange(11, 2)]];
    [ds appendString:@":"];

    // Minute
    [ds appendString:[fn substringWithRange:NSMakeRange(14, 2)]];
    [ds appendString:@":"];

    // Second
    [ds appendString:[fn substringWithRange:NSMakeRange(17, 2)]];
    [ds appendString:@" +0000"];  // always UTC

    static NSDateFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZ";
    }

    return [formatter dateFromString:ds];
}
#endif

#if 1
///AI rewrite
// Format: yyyymmdd-hhmmss-1-988-ANTFS-4.FIT  (we only need the first 15 chars)
- (NSDate *)getFitAntTrackStartTimeFromFileName:(NSString *)fn
{
    if (fn.length < 15) return nil;
    NSString *prefix = [fn substringToIndex:15]; // "yyyymmdd-hhmmss"

    static NSDateFormatter *fmt;
    if (!fmt) {
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        fmt.dateFormat = @"yyyyMMdd-HHmmss";
    }
    return [fmt dateFromString:prefix];
}
#else
// format: yyyymmdd-hhmmss-1-988-ANTFS-4.FIT
-(NSDate*)getFitAntTrackStartTimeFromFileName:(NSString*)fn
{
    NSUInteger len = [fn length];
	if (len <= 15) return nil;
	NSRange r;
	r.length = 4;
	r.location = 0;
	NSString* year = [fn substringWithRange:r];
	r.length = 2;
	r.location = 4;
	NSString* month = [fn substringWithRange:r];
	r.length = 2;
	r.location = 6;
	NSString* day = [fn substringWithRange:r];
	
	r.location = 9;
	NSString* hour = [fn substringWithRange:r];
	r.location = 11;
	NSString* minute = [fn substringWithRange:r];
	r.location = 13;
	NSString* sec = [fn substringWithRange:r];
	
	NSMutableString* ds = [NSMutableString stringWithFormat:@"%@-%@-%@ %@:%@:%@", year, month, day, hour, minute, sec];
	[ds appendString:@" +0000"];
	return [NSDate dateWithString:ds];
}
#endif



// format: (M)MDDYY (H)HMMSS [A/P]M.TCX  (x) means missing if not needed
// for example 21209 71112 PM.TCX is 2/12/09 7:11:12 PM
#if 1
///AI rewrite
// Example filename format: "3-07-24 9:15:30 PM ..."
- (NSDate *)getANTTrackStartTimeFromFileName:(NSString *)fn
{
    if (fn.length < 17) return nil; // quick sanity check

    // Extract just the date/time part up through AM/PM
    // (first 20 chars usually cover "M-d-yy h:mm:ss AM")
    NSRange range = [fn rangeOfString:@"M"];
    if (range.location == NSNotFound) {
        // just grab first ~20 chars as fallback
        range.location = 0;
        range.length = MIN(20, fn.length);
    } else {
        range.location = 0;
        range.length = MIN(range.location + 2, fn.length);
    }
    NSString *prefix = [fn substringToIndex:MIN(20, fn.length)];

    static NSDateFormatter *fmt;
    if (!fmt) {
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        // Matches formats like "3-07-24 9:15:30 PM"
        fmt.dateFormat = @"M-dd-yy h:mm:ss a";
    }
    return [fmt dateFromString:prefix];
}

#else
-(NSDate*)getANTTrackStartTimeFromFileName:(NSString*)fn
{
    NSUInteger len = [fn length];
	if (len <= 14) return nil;
	NSRange r = [fn rangeOfString:@" "];
	if (r.location == NSNotFound) return nil;
	
	NSString* month;
	if (r.location == 5)
	{
		r.location = 0;
		r.length = 1;
		month = [NSString stringWithFormat:@"0%@", [fn substringWithRange:r]];
	}
	else if (r.location == 6)
	{
		r.location = 0;
		r.length = 2;
		month = [NSString stringWithString:[fn substringWithRange:r]];
	}
	else return nil;
	r.location = r.length;
	r.length = 2;
	NSString* day = [fn substringWithRange:r];
	r.location += r.length;
	NSString* year = [NSString stringWithFormat:@"20%@", [fn substringWithRange:r]];
	r.location += r.length;
	
	r.location++;		// skip space
	
	r.length = 8;
	NSString* fnsub = [fn substringWithRange:r];
	
	NSRange rr = [fnsub rangeOfString:@" "];
	
	if (rr.location == NSNotFound) return nil;
	NSString* hour;
	if (rr.location == 5)
	{
		r.length = 1;
		hour = [NSString stringWithFormat:@"0%@", [fn substringWithRange:r]];
	} 
	else if (rr.location == 6)
	{
		r.length = 2;
		hour = [NSString stringWithString:[fn substringWithRange:r]];
	}
	else return nil;
	r.location += r.length;
	r.length = 2;
	NSString* minute = [fn substringWithRange:r];
	r.location += r.length;
	NSString* second = [fn substringWithRange:r];
	r.location += r.length;
	
	r.location++;		// skip space
	r.length = 2;
	rr = [fn rangeOfString:@"A"
				   options:NSLiteralSearch
					 range:r];
	
	if (rr.location == NSNotFound)
	{
		int hint = [hour intValue];
		hint += 12;
		hour = [NSString stringWithFormat:@"%d", hint];
	}
	
	NSString* ds = [NSString stringWithFormat:@"%@-%@-%@ %@:%@:%@ +0000", year, month, day, hour, minute, second];
	//NSCalendarDate* cd = [NSCalendarDate dateWithString:ds];
	return [NSDate dateWithString:ds];
}
#endif



-(void)add705Tracks:(NSMutableArray*)importList
{
#if DEBUG_SYNC
	NSLog(@"...adding 705 tracks");
#endif
	NSFileManager* fm = [NSFileManager defaultManager];
	NSError* error;
	NSArray* contents = [fm contentsOfDirectoryAtPath:@"/Volumes/GARMIN/Garmin/History"
												error:&error];
	if (contents != nil)
	{
        NSUInteger num = [contents count];
#if DEBUG_SYNC
		NSLog(@"...found %d tracks", num);
#endif
		int si = 0;
		for (int i=0; i<num; i++)
		{
			NSString* s = [contents objectAtIndex:i];
			if ([[s pathExtension] isEqualToString:@"tcx"])
			{
				NSDate* st = [self getTrackStartTimeFromFileName:s];
#if DEBUG_SYNC
				NSLog(@"...    checking track with start time %x: %@", st, [st description]);
#endif
				if (!st || ![self trackExistsAtTime:st
										 startIndex:&si
											   slop:10])
				{
					NSString* path = @"/Volumes/GARMIN/Garmin/History/";
					path = [path stringByAppendingPathComponent:s];
    				[importList addObject:path];
#if DEBUG_SYNC
					NSLog(@"...       WILL IMPORT track with start time %@ at path %@", [st description], path);
#endif
				}
				else 
				{
#if DEBUG_SYNC
					NSLog(@"...       SKIPPING track with start time %@", [st description]);
#endif
				}
			}
		}
	}
}


-(void)addAFITTrack:(NSString*)s startIndex:(int*)sip importList:(NSMutableArray*)importList
{
	// unlike the 705, the 500 stores files named with the LOCAL date/time, not GMT
	NSDate* st = [self getTrackStartTimeFromFileName:s];
	NSCalendar* cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
	[cal setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDateComponents *comps = [cal components:(NSCalendarUnitYear |
                                               NSCalendarUnitMonth |
                                               NSCalendarUnitDay |
                                               NSCalendarUnitHour |
                                               NSCalendarUnitMinute |
                                               NSCalendarUnitSecond)
                                    fromDate:st];
	[cal setTimeZone:[NSTimeZone localTimeZone]];
	st = [cal dateFromComponents:comps];
	
#if DEBUG_SYNC
	NSLog(@"...    checking track with start time %x: %@", st, [st description]);
#endif
	if (!st || ![self trackExistsAtTime:st
							 startIndex:sip
								   slop:10])
	{
#if DEBUG_FIT_IMPORT
		NSString* path = [NSString stringWithString:@"/Volumes/nd141/Users/rob/Desktop/Activities/"];
#else
		NSString* path = @"/Volumes/GARMIN/Garmin/Activities/";
#endif
		path = [path stringByAppendingPathComponent:s];
		[importList addObject:path];
#if DEBUG_SYNC
		NSLog(@"...       WILL IMPORT track with start time %@ at path %@", [st description], path);
#endif
	}
	else 
	{
#if DEBUG_SYNC
		NSLog(@"...       SKIPPING track with start time %@", [st description]);
#endif
	}
}



-(void)addAFITANTTrack:(NSString*)s basePath:(NSString*)basePath startIndex:(int*)sip importList:(NSMutableArray*)importList
{
    NSDate *st = [self getFitAntTrackStartTimeFromFileName:s];
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    [cal setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSDateComponents *comps = [cal components:(NSCalendarUnitYear |
                                               NSCalendarUnitMonth |
                                               NSCalendarUnitDay |
                                               NSCalendarUnitHour |
                                               NSCalendarUnitMinute |
                                               NSCalendarUnitSecond)
                                    fromDate:st];
	[cal setTimeZone:[NSTimeZone localTimeZone]];
	st = [cal dateFromComponents:comps];
	
#if DEBUG_SYNC
	NSLog(@"...    checking track with start time %x: %@", st, [st description]);
#endif
	if (!st || ![self trackExistsAtTime:st
							 startIndex:sip
								   slop:10])
	{
		NSString* path = [basePath stringByAppendingPathComponent:s];
		[importList addObject:path];
#if DEBUG_SYNC
		NSLog(@"...       WILL IMPORT track with start time %@ at path %@", [st description], path);
#endif
	}
	else 
	{
#if DEBUG_SYNC
		NSLog(@"...       SKIPPING track with start time %@", [st description]);
#endif
	}
}


#define DEBUG_FIT_IMPORT	ASCENT_DBG&&0

-(void)addFITTracks:(NSMutableArray*)importList
{
#if DEBUG_SYNC
	NSLog(@"...adding FIT tracks");
#endif
	NSFileManager* fm = [NSFileManager defaultManager];
	NSError* error;
#if DEBUG_FIT_IMPORT
	NSArray* contents = [fm contentsOfDirectoryAtPath:@"/Volumes/nd141/Users/rob/Desktop/Activities"
												error:&error];
#else
	NSArray* contents = [fm contentsOfDirectoryAtPath:@"/Volumes/GARMIN/Garmin/Activities"
												error:&error];
#endif
	if (contents != nil)
	{
        NSUInteger num = [contents count];
#if DEBUG_SYNC
		NSLog(@"...found %d tracks", num);
#endif
		int si = 0;
		for (int i=0; i<num; i++)
		{
			NSString* s = [contents objectAtIndex:i];
			if ([[s pathExtension] isEqualToString:@"fit"] || [[s pathExtension] isEqualToString:@"FIT"])
			{
				[self addAFITTrack:s
						startIndex:&si
						importList:importList];
			}
		}
	}
}


-(void)addANTTracks:(NSMutableArray*)importList
{
	NSError* error;
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *asd = [NSMutableString stringWithString:[paths objectAtIndex:0]];
	asd = [asd stringByAppendingPathComponent:@"Garmin/Devices"];
	NSArray* devContents = [fm contentsOfDirectoryAtPath:asd
												   error:&error];
	if (devContents != nil)
	{
        NSUInteger numDev = [devContents count];
		NSMutableArray* antTracks = [NSMutableArray arrayWithCapacity:8];
		for (int dev=0; dev<numDev; dev++)
		{
			BOOL hasFit = NO;
			NSString* d = [devContents objectAtIndex:dev];
			NSString* baseDevPath = [asd stringByAppendingPathComponent:d];
			NSString* activitiesDevPath = [baseDevPath stringByAppendingPathComponent:@"Activities"];
 			NSArray* contents = [fm contentsOfDirectoryAtPath:activitiesDevPath
														error:NULL];
            NSUInteger num = [contents count];
			int si = 0;
			for (int i=0; i<num; i++)
			{
				NSString* s = [contents objectAtIndex:i];
				if ([[s pathExtension] caseInsensitiveCompare:@"fit"] == NSOrderedSame)
				{
					[self addAFITANTTrack:s
								 basePath:activitiesDevPath
							   startIndex:&si
							   importList:antTracks];
				}
				hasFit = YES;
			}
			if (!hasFit)
			{
				NSString* historyDevPath = [baseDevPath stringByAppendingPathComponent:@"History"];
				contents = [fm contentsOfDirectoryAtPath:historyDevPath
												   error:&error];
				num = [contents count];
				si = 0;
				for (int i=0; i<num; i++)
				{
					NSString* s = [contents objectAtIndex:i];
					if ([[s pathExtension] caseInsensitiveCompare:@"tcx"] == NSOrderedSame)
					{
						NSDate* st = [self getTrackStartTimeFromFileName:s];
						if (!st || ![self trackExistsAtTime:st
												 startIndex:&si
													   slop:10.0])
						{
							NSString* path = [historyDevPath stringByAppendingPathComponent:s];
							[antTracks addObject:path];
						}
					}
				}
			}
		}
		[importList addObjectsFromArray:antTracks];
	}
}


-(BOOL)syncGarminMassStorageDevice:(int*)numLoadedPtr lastTrackLoaded:(Track**)lastLoadedPtr
{
#if DEBUG_SYNC
	NSLog(@"syncing GARMIN Mass Storage Device");
#endif
	BOOL ret = NO;
	NSMutableArray* importList = [NSMutableArray arrayWithCapacity:16];
	//if ([Utils boolFromDefaults:RCBDefaultGarminMassStorageSync]) 
	{
		[self add705Tracks:importList];
		[self addFITTracks:importList];
	}
	//if ([Utils boolFromDefaults:RCBDefaultGarminANTSync]) 
	[self addANTTracks:importList];
    NSUInteger num = [importList count];
	*numLoadedPtr = 0;
	Track* lastTrack = nil;
	for (int i=0; i<num; i++)
	{
		NSString* fileToImport = [importList objectAtIndex:i];
		NSString* ext = [fileToImport pathExtension];
		NSMutableArray* importedTrackArray = [NSMutableArray array];
		NSMutableArray* importedLapArray = [NSMutableArray array];
		BOOL sts = NO;
		if ([ext caseInsensitiveCompare:@"tcx"] == NSOrderedSame)
		{
			TCX* tcx = [[[TCX alloc] initWithFileURL:[NSURL fileURLWithPath:fileToImport]] autorelease];
			sts = [tcx import:importedTrackArray laps:importedLapArray];
            [tcx release];
		}
		else if ([ext caseInsensitiveCompare:@"fit"] == NSOrderedSame)
		{
			GarminFIT* fit = [[[GarminFIT alloc] initWithFileURL:[NSURL fileURLWithPath:fileToImport]] autorelease];
			sts = [fit import:importedTrackArray laps:importedLapArray];
            [fit release];
		}
		if (sts == YES)
		{
			NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
			NSMutableArray* trackArray = [self.docMetaData trackArray];
            NSUInteger numImported = [arr count];
			for (int i=0; i<numImported; i++)
			{
				Track* t = [arr objectAtIndex:i];
				// start time may have changed; check again and make *sure* it doesn't already exist
				if (![trackArray containsObject:t])
				{
					// make sure user hasn't deleted this track from this document already
					BOOL contains = [[self.docMetaData userDeletedTrackTimes] containsObject:[t creationTime]];
					if (contains == NO)
					{
						if (([trackArray count] <= kNumUnregisteredTracks) || [RegController CHECK_REGISTRATION])
						{
							[self addTracksToDB:[NSArray arrayWithObject:t]
							alsoAddToTrackArray:YES];

							*numLoadedPtr = *numLoadedPtr + 1;
							lastTrack = t;
						}
						else
						{
							[tbWindowController postNeedRegDialog:@"The unregistered version of Ascent is limited to 10 activites per document."  
							 @"Not all activities could be loaded"];
							break;
						}
					}
				}
			}
			if (importedLapArray != nil) [self processLapData:importedLapArray
													forTracks:importedTrackArray];
		}
		if (lastLoadedPtr) *lastLoadedPtr = lastTrack;
	}
	if (num > 0) ret = YES;
	return ret;
}


-(void) sendTrackSelChangeNotification:(Track*)trackToSel
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackSelectionChanged" object:trackToSel];
}




#include "USBDeviceAccess.h"

-(void)doSync:(int)iVendorID product:(int)iProductID isMassStorage:(BOOL)isMassStorage deviceIsPluggedIn:(BOOL)isPluggedIn
{
	int numLoaded = 0;
	Track* lastLoadedTrack = nil;
	if (isPluggedIn)
	{
		if (isMassStorage)
		{
			[self syncGarminMassStorageDevice:&numLoaded
							  lastTrackLoaded:&lastLoadedTrack];
		}
		else
		{
			[self syncDirect:&numLoaded
			 lastTrackLoaded:&lastLoadedTrack];
		}
	}
	else
	{
		[self syncGarminMassStorageDevice:&numLoaded
						  lastTrackLoaded:&lastLoadedTrack];
	}
	if (numLoaded > 0) 
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
		[tbWindowController buildBrowser:YES];
		[self updateChangeCount:NSChangeDone];
		if (lastLoadedTrack) 
		{
			// issuing this notification synchronously resulted in a hang on Tiger 
			// for some reason
			[self performSelectorOnMainThread:@selector(sendTrackSelChangeNotification:)
								   withObject:lastLoadedTrack
								waitUntilDone:NO];
		}
	}
	StopDeviceCallbacks();
}

static void deviceCB( void* p, tDeviceEvent iEvent, int iVendorID, int iProductID, bool isMassStorage) 
{
	id s = (id)p;
	[s doSync:iVendorID
		product:iProductID
	isMassStorage:isMassStorage
deviceIsPluggedIn:YES];
}


-(void)findDevices
{
	int hg = StartDeviceCallbacks(deviceCB, self);
	if (!hg) 
	{
		StopDeviceCallbacks();
		[self doSync:0
			 product:0
	   isMassStorage:YES
   deviceIsPluggedIn:NO];
	}
}


-(void)syncDirect:(int*)numLoadedPtr lastTrackLoaded:(Track**)lastTrackLoadedPtr
{
	int sts = 0;
	int numLoaded = 0;
	Track* lastLoadedTrack = nil;
#if !defined(ASCENT_DBG) || 1
	NSTask* task = [[[NSTask alloc] init] autorelease];
	NSString* path = [[NSBundle mainBundle] resourcePath];
	path = [path stringByAppendingPathComponent:@"gpsbabel"];
	[task setLaunchPath:path];
	path = getTracksPath();
	if (path != nil)
	{
		NSFileManager* fm = [NSFileManager defaultManager];
		NSError* error;
		[fm removeItemAtPath:path 
						error:&error];
		path = getTracksPath();    
	}
	[task setCurrentDirectoryPath:path];    
	
	NSMutableArray* args = [[[NSMutableArray alloc] init] autorelease];
	[args addObject:@"-t"];
	[args addObject:@"-i"];
	[args addObject:@"garmin"];
	[args addObject:@"-f"];
	[args addObject:@"usb:"];
	[args addObject:@"-o"];
	[args addObject:@"ascent"];
	[args addObject:@"-F"];
	[args addObject:@"r.r"];
	[task setArguments:args];
	//NSLog(@"launch gpsbabel...\n");
	[task launch];
	//NSLog(@"waiting for gpsbabel...\n");
	[task waitUntilExit];
	//NSLog(@"gpsbabel exited...\n");
	sts = [task terminationStatus];
	[task terminate];
#endif
	if (sts == 0)
	{
		//NSLog(@"loading gps data...\n");
		numLoaded = [self loadGPSData:&lastLoadedTrack];
	}
	*numLoadedPtr = numLoaded;
	*lastTrackLoadedPtr = lastLoadedTrack;
}


- (void)syncGPS
{
	[self findDevices];
#if 0	
	//NSLog(@"syncing...\n");
	[tbWindowController stopAnimations];
	[self syncGarminMassStorageDevice:&numLoaded
					  lastTrackLoaded:&lastLoadedTrack];
	if ([Utils boolFromDefaults:RCBDefaultGarminUSBSync])
	{
#if !defined(ASCENT_DBG) || 0
		NSTask* task = [[[NSTask alloc] init] autorelease];
		NSString* path = [[NSBundle mainBundle] resourcePath];
		path = [path stringByAppendingPathComponent:@"gpsbabel"];
		[task setLaunchPath:path];
		path = getTracksPath();
		if (path != nil)
		{
			NSFileManager* fm = [NSFileManager defaultManager];
			[fm removeFileAtPath:path handler:self];
			path = getTracksPath();    
		}
		[task setCurrentDirectoryPath:path];    
		  
		NSMutableArray* args = [[[NSMutableArray alloc] init] autorelease];
		[args addObject:@"-t"];
		[args addObject:@"-i"];
		[args addObject:@"garmin"];
		[args addObject:@"-f"];
		[args addObject:@"usb:"];
		[args addObject:@"-o"];
		[args addObject:@"ascent"];
		[args addObject:@"-F"];
		[args addObject:@"r.r"];
		[task setArguments:args];
		//NSLog(@"launch gpsbabel...\n");
		[task launch];
		//NSLog(@"waiting for gpsbabel...\n");
		[task waitUntilExit];
		//NSLog(@"gpsbabel exited...\n");
		sts = [task terminationStatus];
		[task terminate];
#endif
		if (sts == 0)
		{
			//NSLog(@"loading gps data...\n");
			numLoaded = [self loadGPSData:&lastLoadedTrack];
		}
	}
	//NSLog(@"loaded gps data...\n");
	if (numLoaded > 0) 
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
		[tbWindowController buildBrowser:YES];
		[self updateChangeCount:NSChangeDone];
		if (lastLoadedTrack) 
		{
			// issuing this notification synchronously resulted in a hang on Tiger 
			// for some reason
			[self performSelectorOnMainThread:@selector(sendTrackSelChangeNotification:)
								   withObject:lastLoadedTrack
								waitUntilDone:NO];
		}
	}
	//NSLog(@"sync gps complete...\n");
#endif
}


- (NSDate*)lastSyncTime
{
    if (self.docMetaData)
    {
        return [self.docMetaData lastSyncTime];
    }
    return [NSDate distantPast];
}


- (void)setLastSyncTime:(NSDate*) d
{
    if (self.docMetaData)
    {
        [self.docMetaData setLastSyncTime:d];
    }
}




-(BOOL)trackExistsAtTime:(NSDate*)st startIndex:(int*)startIdx slop:(int)secondsSlop
{
	BOOL ret = NO;
	NSArray* trackArray = [self.docMetaData trackArray];
    NSUInteger num = [trackArray count];
	//for (int i=*startIdx; i<num; i++)
	for (int i=0; i<num; i++)
	{
		Track* track = [trackArray objectAtIndex:i];
		NSDate* cd = [track creationTime];
		NSDate* lower = [cd dateByAddingTimeInterval:(-secondsSlop)];
		NSDate* upper = [cd dateByAddingTimeInterval:( secondsSlop)];
#if ASCENT_DBG&&0
		NSLog(@"    lower, upper: %@ %@ st:%@", lower, upper, st);
#endif
		if (([lower compare:st] == NSOrderedAscending) &&
			([upper compare:st] == NSOrderedDescending))
		//if ([cd isEqualToDate:st])
		{
			ret = YES;
			*startIdx = i;
			break;
		}
#if 0
		else if ([cd earlierDate:st] == st)
		{
			ret = NO;
			break;
		}
#endif
	}
	return ret;
}






- (NSString *)windowNibName
{
   // Override returning the nib file name of the document
   // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
   return @"TrackBrowserDocument";
}


-(void)windowControllerDidLoadNib:(NSWindowController *) aController
{
   [super windowControllerDidLoadNib:aController];
   // Add any code here that needs to be executed once the windowController has loaded the document's window.
}


- (NSData *)dataOfType:(NSString *)aType error:(NSError**)outError
{
   *outError = 0;
   // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
   
   // For applications targeted for Tiger or later systems, you should use the new Tiger API -dataOfType:error:.  In this case you can also choose to override -writeToURL:ofType:error:, -fileWrapperOfType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
 #if USE_KEYED_ENCODING
   data = [NSKeyedArchiver archivedDataWithRootObject:docMetaData];
#else
   // NOTE: archivedDataWithRootObject (and encodeRootObject) cause the encoding process to be run 2x, and
   // this is not necessary here.  Therefore, since there are no cycles in the data being encoded, we just
   // call encodeObject on on the root docMetaData object
   NSMutableData* data = [NSMutableData data];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArchiver* arch = [[[NSArchiver alloc] initForWritingWithMutableData:data] autorelease];
#pragma clang diagnostic pop
   [arch encodeObject:self.docMetaData];
   //data = [NSArchiver archivedDataWithRootObject:docMetaData];
#endif
   return data;
}



- (MainWindowController*) windowController
{
   return tbWindowController;
}

-(void) startProgressIndicator:(NSString*)text
{
	NSRect fr = [[NSScreen mainScreen] frame];
	if (tbWindowController)
	{
		NSWindow* w = [tbWindowController window];
		fr = [w frame];
	}
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
	NSPoint origin;
	origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
	origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
	[[[pb controller] window] setFrameOrigin:origin];
	[[pb controller] showWindow:self];
	[[pb controller] begin:@"" 
				 divisions:0];
	[[pb controller] updateMessage:text];
}


- (void) updateProgressIndicator:(NSString*)msg
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	[[pb controller] updateMessage:msg];
}

- (void) endProgressIndicator
{
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	[[pb controller] end];
	[[[pb controller] window] orderOut:nil];
}


- (void)setDatabaseFileURL:(NSURL*)url
{
    [databaseFileURL release];
    databaseFileURL = [url retain];
}


- (NSURL*)databaseFileURL
{
    return databaseFileURL;
}


#pragma mark - Async Read (preferred) doesn't seem to work, the'completionHandler' version below is never called

// these 'canAsynchronouslyRead' methods are also never called currently.
- (BOOL)canAsynchronouslyReadFromURL:(NSURL *)url ofType:(NSString *)typeName {
    return YES;
}

- (BOOL)canAsynchronouslyReadFromData:(NSData *)data ofType:(NSString *)typeName {
    return YES;
}


- (void)readFromURL:(NSURL *)url
             ofType:(NSString *)typeName
  completionHandler:(void (^)(NSError * _Nullable error))handler
{
    // --- Present progress on MAIN ---
    ProgressBarController *pbc = [[SharedProgressBar sharedInstance] controller];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *docWin = self.windowForSheet ?: self.windowControllers.firstObject.window;
        NSWindow *pbWin  = pbc.window; // loads nib

        // Start indeterminate; you can restart as determinate later if you learn a total
        [pbc begin:[NSString stringWithFormat:@"Opening activity document “%@”…",
                    self.displayName ?: url.lastPathComponent]
           divisions:0];

        if (docWin) {
            NSRect fr = docWin.frame, pfr = pbWin.frame;
            NSPoint origin = NSMakePoint(NSMidX(fr) - pfr.size.width/2.0,
                                         NSMidY(fr) - pfr.size.height/2.0);
            [pbWin setFrameOrigin:origin];
        }
        [pbc showWindow:self];
        [pbWin displayIfNeeded];
    });

    // --- Heavy work on BACKGROUND queue ---
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;

        @try {
            if ([typeName isEqualToString:AscentUTIDatabase]) {

                // If your loader can report a total, have it call back with (done,total)
                // and on first tick, restart the bar as determinate:
                __block BOOL madeDeterminate = NO;

                AscentImporter *importer = [[[AscentImporter alloc] init] autorelease];

                /*BOOL ok =*/ [importer loadDatabaseFile:url
                                        documentMeta:self.docMetaData
                                            progress:^(NSInteger done, NSInteger total) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!madeDeterminate && total > 0) {
                            madeDeterminate = YES;
                            [[ [SharedProgressBar sharedInstance] controller]
                                begin:@"Opening activity document…"
                                divisions:(int)total];
                        }
                        [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                        if (done >= total)
                        {
                            [[[SharedProgressBar sharedInstance] controller] updateMessage:@"building browser..."];
                      }
                    });
                }];

            } else if ([typeName isEqualToString:AscentUTIDatabaseOLD]) {

                NSData *data = [NSData dataWithContentsOfURL:url];
                if (!data) {
                    err = [NSError errorWithDomain:NSCocoaErrorDomain
                                              code:-2
                                          userInfo:@{NSLocalizedDescriptionKey:
                                                     @"Unable to read legacy file"}];
                } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                   id obj = [NSUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
                    if ([obj isKindOfClass:[TrackBrowserData class]]) {
                        self.docMetaData = obj;
                    } else {
                        TrackBrowserData *bd = [[[TrackBrowserData alloc] init] autorelease];
                        [bd setTrackArray:obj];
                        self.docMetaData = bd; // retained
                    }
                    // A couple of UI ticks so the user sees motion
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                        [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                    });
                }

            } else {
                err = [NSError errorWithDomain:NSCocoaErrorDomain
                                          code:NSFileReadUnknownError
                                      userInfo:@{NSLocalizedDescriptionKey:
                                                 @"Unsupported document type"}];
            }
        }
        @catch (NSException *ex) {
            err = [NSError errorWithDomain:NSCocoaErrorDomain
                                      code:-3
                                  userInfo:@{NSLocalizedDescriptionKey:
                                             @"Exception while reading document",
                                             @"exception": ex.reason ?: @""}];
        }

        // --- Commit model & finish on MAIN ---
        dispatch_async(dispatch_get_main_queue(), ^{
            // If your `loadDatabaseFile:` created/filled a new model object,
            // assign it to `docMetaData` ivar here as needed.

            // Hide progress
            ProgressBarController *pbcm = [[SharedProgressBar sharedInstance] controller];
            [[pbcm window] orderOut:self];
            [pbcm end];

            if (handler) handler(err);
        });
    });
}


- (BOOL)readFromURL:(NSURL *)url
             ofType:(NSString *)typeName
              error:(NSError **)outError
{
    NSLog(@"readFromURL: %s", [[url description] UTF8String]);

    // 0) Bring the app to front so our windows actually show.
    if (![NSApp isActive]) {
        [NSApp activateIgnoringOtherApps:YES];
    }

    // 1) Splash / progress UI.
    SplashPanelController *sp = [SplashPanelController sharedInstance];
    BOOL splashWanted = (sp && sp.window && sp.window.isVisible);

    NSString *name = [[url URLByDeletingPathExtension] lastPathComponent];
    NSString *displayName = [name stringByRemovingPercentEncoding];
    if (displayName.length == 0) {
        displayName = name ?: @"document";
    }

    NSModalSession splashSession = NULL;
    if (splashWanted) {
        NSWindow *w = sp.window;
        [w setLevel:(NSStatusWindowLevel + 1)];
        w.collectionBehavior |= (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                 NSWindowCollectionBehaviorFullScreenAuxiliary);
        [w orderFrontRegardless];
        [sp updateMessage:[NSString stringWithFormat:@"opening “%@”…", displayName]];

        splashSession = [NSApp beginModalSessionForWindow:w];
        for (int i = 0; i < 4; i++) {
            [NSApp runModalSession:splashSession];
        }
    } else {
        ProgressBarController *pbc = [[[SharedProgressBar sharedInstance] controller] retain];
        NSWindow *pbWin = [pbc window];
        pbWin.collectionBehavior |= (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary);
        pbWin.level = NSStatusWindowLevel;
        [pbc showWindow:self];
        [pbc begin:[NSString stringWithFormat:@"opening “%@”…", displayName] divisions:0];
        [pbWin orderFrontRegardless];
        [pbWin displayIfNeeded];
        [pbc release]; // controller is retained by its singleton
    }

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);

    // 2) Background load + (for DB UTI) open the AscentLibrary so we have a live connection to reuse.
    __block NSError *bgErr = nil;
    __block BOOL ok = NO;

    dispatch_semaphore_t done = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            @try {
                if ([typeName isEqualToString:AscentUTIDatabase]) {
                    __block BOOL madeDeterminate = NO;

                    AscentImporter *importer = [[[AscentImporter alloc] init] autorelease];
                    ok = [importer loadDatabaseFile:url
                                       documentMeta:self.docMetaData
                                           progress:^(NSInteger doneCount, NSInteger total) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (splashWanted) {
                                if (total > 0) {
                                    [sp updateProgress:(int)doneCount total:(int)total];
                                }
                            } else {
                                if (!madeDeterminate && total > 0) {
                                    madeDeterminate = YES;
                                    [[[SharedProgressBar sharedInstance] controller]
                                        begin:[NSString stringWithFormat:@"opening “%@”…", displayName]
                                        divisions:(int)total];
                                }
                                [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                            }
                        });
                    }];

                    if (ok) {
#if TARGET_OS_OSX
                        // Create or reuse a bookmark so we can start scope in the library open.
                        NSData *bm = self.libraryBookmark;
                        if (bm == nil) {
                            NSError *bmErr = nil;
                            NSData *fresh =
                                [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                 includingResourceValuesForKeys:nil
                                                  relativeToURL:nil
                                                          error:&bmErr];
                            if (fresh != nil) {
                                bm = fresh;
                            } else {
                                // Not fatal inside the container; keep going without a bookmark.
                                NSLog(@"[Document] bookmark create failed for %@: %@", url.path, bmErr);
                            }
                        }
#else
                        NSData *bm = nil;
#endif
                        // Open the library now (single connection), so later incremental saves just reuse it.
                        __block AscentLibrary *openedLib = nil;
                        __block NSError *openErr = nil;
                        dispatch_semaphore_t semOpen = dispatch_semaphore_create(0);

                        [self.libraryController openLibraryAtURL:url
                                                        bookmark:bm
                                                      completion:^(AscentLibrary *lib, NSError *err) {
                            openedLib = [lib retain];
                            openErr   = [err retain];
                            dispatch_semaphore_signal(semOpen);
                        }];

                        dispatch_semaphore_wait(semOpen, DISPATCH_TIME_FOREVER);
                        dispatch_release(semOpen);

                        if (openedLib != nil && openErr == nil) {
                            // Replace any previous library with the newly opened one.
                            if (self.library != openedLib) {
                                [self.library release];
                                self.library = [openedLib retain];
                            }
#if TARGET_OS_OSX
                            if (self.libraryBookmark == nil && openedLib.bookmarkData != nil) {
                                self.libraryBookmark = openedLib.bookmarkData;
                            }
#endif
                            [openedLib release];
                        } else {
                            ok = NO;
                            if (openErr != nil) {
                                bgErr = openErr; // already retained above
                            } else {
                                bgErr = [[NSError errorWithDomain:@"Ascent.Document"
                                                             code:-1001
                                                         userInfo:@{NSLocalizedDescriptionKey:
                                                                    @"Failed to open library for document"}] retain];
                            }
                            if (openedLib != nil) {
                                [openedLib release];
                            }
                        }
                    }
                } else if ([typeName isEqualToString:AscentUTIDatabaseOLD]) {
                    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&bgErr];
                    if (data != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        id obj = [NSUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
                        TrackBrowserData *bd = nil;
                        if ([obj isKindOfClass:[TrackBrowserData class]]) {
                            bd = obj;
                        } else {
                            bd = [[TrackBrowserData alloc] init];
                            [bd setTrackArray:obj];
                        }
                        self.docMetaData = bd; // retained
                        ok = YES;

                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (splashWanted) {
                                [sp updateMessage:@"Opening…"];
                            } else {
                                [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                                [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                            }
                        });
                    } else {
                        ok = NO;
                    }
                } else {
                    ok = NO;
                    bgErr = [[NSError errorWithDomain:NSCocoaErrorDomain
                                                 code:NSFileReadUnknownError
                                             userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported document type" }] retain];
                }
            }
            @catch (NSException *ex) {
                ok = NO;
                bgErr = [[NSError errorWithDomain:NSCocoaErrorDomain
                                             code:-3
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Exception while reading document",
                                                     @"exception" : (ex.reason ?: @"") }] retain];
            }

            dispatch_semaphore_signal(done);
        }
    });

    // 3) Keep UI responsive while waiting.
    while (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_MSEC))) {
        if (splashSession != NULL) {
            [NSApp runModalSession:splashSession];
        } else {
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
        }
    }
    dispatch_release(done);

    // 4) Tear down progress UI.
    // ... everything above unchanged ...

    if (splashWanted) {
        [sp updateProgress:100 total:100];
        [sp updateMessage:@"building browser..."];
        [sp canDismiss:YES];
        [sp startFade:nil];
    } else {
        ProgressBarController *pbc = [[SharedProgressBar sharedInstance] controller];
        [pbc updateMessage:@"building browser..."];
        [[pbc window] orderOut:self];
        [pbc end];
    }
    if (splashSession) {
        [NSApp endModalSession:splashSession];
        splashSession = NULL;
    }

    // If open/import was successful, sync NSDocument's view of the mod date.
    // Do this on main to avoid the external-change sheet on the first save after reopen.
    if (ok) {
        [self syncFileModDateFromDiskAtURL:url];

        // Ensure AppKit sees a clean state right after open
        [self updateChangeCount:NSChangeCleared];
    }

    // Standard error out
    if (!ok && outError) {
        *outError = bgErr ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                 code:NSFileReadUnknownError
                                             userInfo:nil];
    }
    return ok;
}

    
- (BOOL)keepBackupFile
{
    return NO;
}

- (void)_presentProgress:(ProgressBarController *)pbc total:(int)total  message:(NSString*)msg
{
    NSWindow *docWin = self.windowForSheet ?: self.windowControllers.firstObject.window;
    NSWindow *pbWin  = pbc.window;
    [pbc begin:msg divisions:total];
    NSRect fr = docWin.frame, pfr = pbWin.frame;
    [pbWin setFrameOrigin:NSMakePoint(NSMidX(fr)-pfr.size.width/2.0, NSMidY(fr)-pfr.size.height/2.0)];
    [pbc showWindow:self];
    [pbWin displayIfNeeded];
}
- (void)_dismissProgress {
    ProgressBarController *pbc = [[SharedProgressBar sharedInstance] controller];
    [[pbc window] orderOut:self];
    [pbc end];
}


- (BOOL)shouldPreferIncrementalForOperation:(NSSaveOperationType)op
                                 destination:(NSURL *)destURL
{
    if (op == NSAutosaveInPlaceOperation) {
        return YES;
    }
    if (op == NSSaveAsOperation) {
        return NO;
    }
    if (op == NSSaveToOperation) {
        return NO;
    }
    if (self.fileURL == nil) {
        return NO;
    }
    if (destURL != nil && ![destURL isEqual:self.fileURL]) {
        return NO;
    }
    return YES; // Save / Autosave to the same on-disk file
}


- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)type
 forSaveOperation:(NSSaveOperationType)op
completionHandler:(void (^)(NSError * _Nullable error))handler
{
    // -------- Progress UI (main) --------
    NSString *base = [[url URLByDeletingPathExtension] lastPathComponent];
    NSString *displayName = [base stringByRemovingPercentEncoding];
    if (displayName.length == 0) {
        displayName = (base ?: @"document");
    }
    
    if (op != NSAutosaveInPlaceOperation)
        [self startProgressIndicator:[NSString stringWithFormat:@"saving “%@”…", displayName]];

    // Decide incremental vs full.
    BOOL preferIncremental = [self shouldPreferIncrementalForOperation:op destination:url];

    // ---------- Incremental path ----------
    if (preferIncremental) {
        NSURL *docURL = self.fileURL;
        NSLog(@"SAVING INCREMENTALLY… %s", [displayName UTF8String]);

        // 1) Reuse an already-open library if available.
        __block AscentLibrary *lib = self.library;

        if (lib == nil) {
            // 2) Try any other open library with the same URL.
            for (AscentLibrary *candidate in [self.libraryController openLibraries]) {
                if ([[candidate fileURL] isEqual:docURL]) {
                    lib = candidate;
                    break;
                }
            }
        }

        // NSDocument save-token (pre-acquired on main).
        id saveToken = [self changeCountTokenForSaveOperation:NSSaveOperation];

        // Helper: perform the export off-main using the given library.
        void (^runIncremental)(AscentLibrary *useLib) = ^(AscentLibrary *useLib) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                @autoreleasepool {
                    // --- Reset connection to avoid stale SQLITE_BUSY/LOCKED ---
                    [[useLib db] close];

                    NSError *reopenErr = nil;
                    if (![[useLib db] open:&reopenErr]) {
                        NSError *errForMain = [reopenErr retain];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSError *err = [errForMain autorelease];
                            [self _dismissProgress];
                            if (handler) {
                                handler(err ?: [NSError errorWithDomain:@"AscentExporter"
                                                                   code:-1
                                                               userInfo:@{NSLocalizedDescriptionKey:
                                                                          @"Reopen failed before incremental save"}]);
                            }
                        });
                        return;
                    }
                             
                    
                    NSError *exportErr = nil;
                    AscentExporter *exporter = [[[AscentExporter alloc] init] autorelease];

                    BOOL ok = [exporter performIncrementalExportWithMetaData:self.docMetaData
                                                             databaseManager:useLib.db
                                                               activityStore:useLib.activities
                                                            trackPointStore:useLib.points
                                                           identifierStore:useLib.identifiers
                                                                      error:&exportErr];

                    NSError *errForMain = [exportErr retain];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSError *err = [errForMain autorelease];

                        [self _dismissProgress];

                        if (ok) {
                            // Tell NSDocument the save succeeded (token-based API keeps it non-racy).
                            [self updateChangeCountWithToken:saveToken forSaveOperation:NSSaveOperation];

                            // Sync the mod-date so AppKit doesn’t think an external app changed the file.
                            NSError *attrErr = nil;
                            NSDictionary *attrs =
                                [[NSFileManager defaultManager] attributesOfItemAtPath:self.fileURL.path error:&attrErr];
                            NSDate *mod = [attrs objectForKey:NSFileModificationDate];
                            if (mod != nil) {
                                [self syncFileModDateFromDiskAtURL:self.fileURL];
                            }

                            [self updateChangeCount:NSChangeCleared];

                            // Optional stats refresh.
                            [self.libraryController refreshStatsForLibrary:useLib completion:nil];

                            if (handler != nil) {
                                handler(nil);
                            }
                        } else {
                            if (handler != nil) {
                                handler(err ?: [NSError errorWithDomain:@"AscentExporter"
                                                                   code:-1
                                                               userInfo:@{NSLocalizedDescriptionKey:@"Incremental save failed"}]);
                            }
                        }
                    });
                }
            });
        };

        if (lib != nil) {
            runIncremental(lib);
            return;
        }

        // 3) No open library: open one (asynchronously) and then run the export.
        NSData *bm = nil;
        if ([self respondsToSelector:@selector(libraryBookmark)]) {
            bm = [self valueForKey:@"libraryBookmark"];
        }
        if (bm == nil && self.library != nil) {
            bm = self.library.bookmarkData;
        }

        [self.libraryController openLibraryAtURL:docURL
                                        bookmark:bm
                                      completion:^(AscentLibrary *opened, NSError *openErr)
        {
            if (openErr != nil || opened == nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _dismissProgress];
                    if (handler != nil) {
                        handler(openErr ?: [NSError errorWithDomain:@"AscentExporter"
                                                               code:-1
                                                           userInfo:@{NSLocalizedDescriptionKey:
                                                                      @"Failed to open scoped library for incremental save"}]);
                    }
                });
                return;
            }

            // Cache for subsequent saves.
            if ([self respondsToSelector:@selector(setLibrary:)]) {
                self.library = opened;
            }
            if ([self respondsToSelector:@selector(setLibraryBookmark:)]
                && self.libraryBookmark == nil
                && opened.bookmarkData != nil) {
                self.libraryBookmark = opened.bookmarkData;
            }

            runIncremental(opened);
        }];

        return;
    }

    // ---------- Full export path ----------
    [self performFullExportToURL:url
                          ofType:type
                forSaveOperation:op
               completionHandler:handler];
}


- (void)performFullExportToURL:(NSURL *)url
                        ofType:(NSString *)type
              forSaveOperation:(NSSaveOperationType)op
             completionHandler:(void (^)(NSError * _Nullable error))handler
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSError *exportErr = nil;

            AscentExporter *exporter = [[[AscentExporter alloc] init] autorelease];
            NSURL *tmp = [exporter exportDocumentToTemporaryURLWithProgress:^(NSInteger done, NSInteger total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[SharedProgressBar sharedInstance] controller] incrementDiv];
                });
            } metaData:self.docMetaData
                 error:&exportErr];

            // Own values across the queue hop
            NSError *errForMain = [exportErr retain];
            NSURL   *tmpForMain = [tmp retain];

            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err = [errForMain autorelease];
                NSURL   *staged = [tmpForMain autorelease];

                if (staged == nil || err != nil) {
                    [self _dismissProgress];
                    if (handler != nil) {
                        handler(err ?: [NSError errorWithDomain:@"AscentExporter"
                                                           code:-1
                                                       userInfo:@{NSLocalizedDescriptionKey:@"Full export failed"}]);
                    }
                    return;
                }

                self.stagedExportURL = staged;

                NSError *writeErr = nil;
                BOOL ok = [self writeSafelyToURL:url
                                          ofType:type
                                forSaveOperation:op
                                           error:&writeErr];

                // Cleanup the staged file
                if (self.stagedExportURL != nil) {
                    [[NSFileManager defaultManager] removeItemAtURL:self.stagedExportURL error:NULL];
                    self.stagedExportURL = nil;
                }

                [self _dismissProgress];

                if (!ok) {
                    if (handler != nil) {
                        handler(writeErr);
                    }
                    return;
                }

                // Adopt new identity on Save / Save As…
                if (op == NSSaveOperation || op == NSSaveAsOperation) {
                    BOOL isNewIdentity = (self.fileURL == nil) || ![self.fileURL isEqual:url];

                    if (isNewIdentity) {
                        [self setFileURL:url];

                        NSDocumentController *dc = [NSDocumentController sharedDocumentController];
                        if ([dc respondsToSelector:@selector(noteNewRecentDocumentURL:)]) {
                            [dc noteNewRecentDocumentURL:url];
                        }

#if TARGET_OS_OSX
                        NSError *bmErr = nil;
                        NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                         includingResourceValuesForKeys:nil
                                                          relativeToURL:nil
                                                                  error:&bmErr];
                        if (bookmark == nil) {
                            NSLog(@"[Save] Warning: failed to create bookmark for %@: %@", url.path, bmErr);
                        }

                        // Eagerly open (and scope) the library so the next save can be incremental.
                        [self.libraryController openLibraryAtURL:url
                                                        bookmark:bookmark
                                                      completion:^(AscentLibrary *lib, NSError *openErr) {
                            if (openErr != nil || lib == nil) {
                                NSLog(@"[Save] Warning: failed to adopt/open library for %@: %@", url.path, openErr);
                            } else {
                                if ([self respondsToSelector:@selector(setLibrary:)]) {
                                    self.library = lib;
                                }
                                if ([self respondsToSelector:@selector(setLibraryBookmark:)]
                                    && bookmark != nil) {
                                    self.libraryBookmark = bookmark;
                                }
                                [self.libraryController refreshStatsForLibrary:lib completion:nil];
                            }
                        }];
#else
                        [self.libraryController openLibraryAtURL:url
                                                        bookmark:nil
                                                      completion:^(AscentLibrary *lib, NSError *openErr) {
                            if (openErr != nil || lib == nil) {
                                NSLog(@"[Save] Warning: failed to adopt/open library for %@: %@", url.path, openErr);
                            } else {
                                if ([self respondsToSelector:@selector(setLibrary:)]) {
                                    self.library = lib;
                                }
                            }
                        }];
#endif
                    }
                }

                [self updateChangeCount:NSChangeCleared];

                if (handler != nil) {
                    handler(nil);
                }
            });
        }
    });
}


- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation
{
    return YES; // AppKit will call write… on a background thread/queue
}


- (BOOL)writeSafelyToURL:(NSURL *)destURL
                  ofType:(NSString *)type
        forSaveOperation:(NSSaveOperationType)op
                   error:(NSError **)outError
{
    // If saveToURL: already staged an export, use it.
    NSURL *staged = self.stagedExportURL;
    BOOL  stagedOwnedHere = NO;

    // Duplicate / some autosave paths call writeSafelyToURL: directly.
    // In that case, build the staged export synchronously *here*.
    if (!staged) {
        NSError *exportErr = nil;
        AscentExporter* exporter = [[[AscentExporter alloc] init] autorelease];
        staged = [exporter exportDocumentToTemporaryURLWithProgress:nil
                                                           metaData:self.docMetaData
                                                              error:&exportErr];
        if (!staged) {
            if (outError) *outError = exportErr ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                                       code:NSFileWriteUnknownError
                                                                   userInfo:@{NSLocalizedDescriptionKey:@"No staged export found"}];
            return NO;
        }
        stagedOwnedHere = YES;
    }

    
    
    __block BOOL ok = NO;
    __block NSError *err = nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    __block NSURL *resultURL = nil;

    NSFileCoordinator *coord = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [coord coordinateWritingItemAtURL:destURL
                              options:NSFileCoordinatorWritingForReplacing
                                error:&err
                           byAccessor:^(NSURL *newURL) {

        // 1) Create a same-volume replacement dir
        NSError *locErr = nil;
        NSURL *repDir = [fm URLForDirectory:NSItemReplacementDirectory
                                   inDomain:NSUserDomainMask
                          appropriateForURL:newURL
                                     create:YES
                                      error:&locErr];
        if (!repDir) { err = locErr; return; }

        // 2) Copy staged DB into that dir (same filesystem)
        NSURL *sibling = [repDir URLByAppendingPathComponent:newURL.lastPathComponent];
        if (![fm copyItemAtURL:staged toURL:sibling error:&locErr]) { err = locErr; return; }

        // 3) Atomically replace
        if (![fm replaceItemAtURL:newURL
                      withItemAtURL:sibling
                     backupItemName:nil
                            options:0
                   resultingItemURL:&resultURL
                              error:&locErr]) { err = locErr; return; }

        // 4) Best-effort cleanup
        [fm removeItemAtURL:repDir error:NULL];

        ok = YES;
    }];
    [coord release];

    if (!ok)
    {
        if (outError)
            *outError = err;
        return NO;
    }

    // IMPORTANT: tell NSDocument about the new mod date
    NSDate *mod = [[NSFileManager defaultManager] attributesOfItemAtPath:(resultURL ?: destURL).path error:NULL][NSFileModificationDate];
    [self setFileModificationDate:mod];

    // Clear dirty state (you already do this)
    [self updateChangeCount:NSChangeCleared];


    return YES;
}


#if 1
- (BOOL)writeToURL:(NSURL *)absoluteURL
            ofType:(NSString *)typeName
  forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)absoluteOriginalContentsURL
             error:(NSError **)error
{
   
	BOOL couldBeWritten = [super writeToURL: absoluteURL
									ofType: typeName
						  forSaveOperation: saveOperation
					   originalContentsURL: absoluteOriginalContentsURL
									 error: error];
	
	return couldBeWritten;
}
#endif




- (void)makeWindowControllers
{
   if (tbWindowController == nil)
   {
       MainWindowController *wc = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
       [self addWindowController:wc];   // <-- this sets wc.document = self
       [wc release];
   }
}


- (NSMutableArray*)trackArray
{
   return [self.docMetaData trackArray];
}



-(NSMutableDictionary*) colInfoDict
{
   return [self.docMetaData tableInfoDict];
}


-(void) setColInfoDict:(NSMutableDictionary*)dict
{
   [self.docMetaData setTableInfoDict:dict];
}


-(NSMutableDictionary*) splitsColInfoDict
{
   return [self.docMetaData splitsTableInfoDict];
}


-(void) setSplitsColInfoDict:(NSMutableDictionary*)dict
{
   [self.docMetaData setSplitsTableInfoDict:dict];
}



//---- Editing methods

- (void) updateTrack:(Track*)track
{
   [track fixupTrack];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" object:track];
}

   
- (void) replaceTrackPoint:(Track*)track point:(TrackPoint*)pt newPoint:(TrackPoint*)np key:(id)ident updateTrack:(BOOL)upd
{
	NSUndoManager* undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] replaceTrackPoint:track point:np newPoint:pt key:ident updateTrack:YES];		// always update on UNDO/REDO
	if (![undo isUndoing])
	{
	  
	  NSString* s = @"Change ";
	  s = [s stringByAppendingString:ident];
	  [undo setActionName:s];
	}
	NSMutableArray* pts = [track points];
	NSUInteger idx = [pts indexOfObjectIdenticalTo:pt];
	if (idx != NSNotFound)
	{
		//NSLog(@"replaced %@ object %x at index %d with object %x\n", ident, pt, idx, np);
		[pts replaceObjectAtIndex:idx 
					   withObject:np];
		[track setPoints:pts];	// force goodPoints to be invalidated, etc
	
	}
	if (upd) [self updateTrack:track];
}


- (void) changeTrackPoints:(Track*)track newPointArray:(NSMutableArray*)pts updateTrack:(BOOL)upd
{
	NSUndoManager* undo = [self undoManager];
	NSMutableArray* oldPts = [track points];
	[[undo prepareWithInvocationTarget:self] changeTrackPoints:track newPointArray:oldPts updateTrack:upd];
	if (![undo isUndoing])
	{
		
		NSString* s = @"Change Track Point Values";
		[undo setActionName:s];
	}
	[track setPoints:pts];
	if (upd) [self updateTrack:track];
}


- (void)close
{
    NSLog(@"document close...");
    AscentLibrary *lib = [self.library retain];

    [super close];

    if (lib != nil) {
        [self.libraryController closeLibrary:lib completion:nil];
        [lib release];
    }

    self.library = nil;
}


-(NSMutableArray*)copyPoints:(NSArray*)pts
{
    NSUInteger num = [pts count];
	NSMutableArray* outArr = [NSMutableArray arrayWithCapacity:num];
	for (int i=0; i<num; i++)
	{
		TrackPoint* np = [[[pts objectAtIndex:i] mutableCopyWithZone:nil] autorelease];
		[outArr addObject:np];
	}
	return outArr;
}



-(NSArray*) adjustPoints:(NSArray*)pts byDistance:(float)deltaDist andTime:(NSTimeInterval)deltaTime hasDistance:(BOOL)hasDistance
{
	NSArray* cpts = [self copyPoints:pts];
    NSUInteger num = [cpts count];
	for (int i=0; i<num; i++)
	{
		TrackPoint* tpt = [cpts objectAtIndex:i];
		if (hasDistance)
		{
			float dist = [tpt distance];
			if (dist != BAD_DISTANCE) 
			{
				[tpt setDistance:(dist + deltaDist)];
			}
			dist = [tpt origDistance];
			if (dist != BAD_DISTANCE) 
			{
				[tpt setOrigDistance:(dist + deltaDist)];
			}
		}
		[tpt setWallClockDelta:[tpt wallClockDelta] + deltaTime];
	}
	return cpts;
}


-(void) copyTrackAttributes:track toTracks:(NSArray*)newTracks
{
    NSUInteger count = [newTracks count];
	for (int i=0; i<count; i++)
	{
		Track* nt = [newTracks objectAtIndex:i];
		for (int j=0; j<kNumAttributes; j++)
		{
			[nt setAttribute:j
				 usingString:[track attribute:j]];
		}
		[[EquipmentLog sharedInstance] trackAddedOrUpdated:nt];
	}
}


-(void) replaceTracks:(NSArray*)tracksToRemove withTracks:(NSArray*)tracksToAdd actionName:(NSString*)an
{
	NSMutableArray* trackArray = [self.docMetaData trackArray];
	[tbWindowController storeExpandedState];
	NSUndoManager* undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] replaceTracks:tracksToAdd 
												withTracks:tracksToRemove
												actionName:an];
	if (![undo isUndoing])
	{
		[undo setActionName:an];
	}
	[trackArray removeObjectsInArray:tracksToRemove];
	[self addTracksToDB:tracksToAdd
	alsoAddToTrackArray:YES];
	
	[self trackArrayChanged:YES];
	[tbWindowController buildBrowser:YES];
	[tbWindowController restoreExpandedState];
	if ([tracksToAdd count] > 0)
	{
		[tbWindowController selectBrowserRowsForTracks:tracksToAdd];
		[tbWindowController resetSelectedTrack:[tracksToAdd objectAtIndex:0]
										   lap:nil];
	}
}


-(NSArray*) copyLapsAndApplyDelta:(Track*)tr wallDelta:(NSTimeInterval)delta
{
	NSArray* laps = [tr laps];
    NSUInteger numLaps = [laps count];
	NSMutableArray* newLaps = [NSMutableArray arrayWithCapacity:numLaps];
	for (int i=0; i<numLaps; i++)
	{
		Lap* l = [laps objectAtIndex:i];
		l = [[l mutableCopyWithZone:nil] autorelease];
		[l setStartingWallClockTimeDelta:([l startingWallClockTimeDelta] + delta)];
		[newLaps addObject:l];
	}
	return newLaps;
}


-(Track*)combineTracks:(NSArray*)tracks
{
	Track* combinedTrack = nil;
    NSUInteger numTracks = [tracks count];
	if (numTracks > 1)
	{
		NSMutableArray* sortedTracks = [NSMutableArray arrayWithArray:[tracks sortedArrayUsingSelector:@selector(comparator:)]];
		// deep-copy the earliest track, including its points
		combinedTrack = [[[sortedTracks objectAtIndex:0] mutableCopyWithZone:nil] autorelease];
		NSMutableArray* combinedPoints = [combinedTrack points];	// points from deep-copied track
        NSUInteger origPointCount = [combinedPoints count];
		NSDate* prevEnd = [[combinedTrack creationTime] dateByAddingTimeInterval:[combinedTrack duration]];
		// need to update each point's distance and wall clock time, by adding in the sub
		float lastDist = [combinedTrack distance];
		NSTimeInterval lastDeltaTime = [combinedTrack duration];
		NSMutableArray* copyOfSortedTracks = [NSMutableArray arrayWithArray:sortedTracks];
		NSMutableArray* newLaps = [NSMutableArray arrayWithCapacity:8];
		[newLaps addObjectsFromArray:[self copyLapsAndApplyDelta:combinedTrack
													   wallDelta:0]];
		for (int i=1; i<numTracks; i++)	// skip first track, already copied its points...
		{
			Track* tr = [sortedTracks objectAtIndex:i];
			NSDate* start = [tr creationTime];
			[tr copyOrigDistance];
			if ([prevEnd earlierDate:start] == prevEnd)
			{
				NSArray* copyPoints = [self adjustPoints:[tr points] 
											  byDistance:lastDist
												 andTime:lastDeltaTime
											 hasDistance:[tr hasDistance]];
				[combinedPoints addObjectsFromArray:copyPoints];
				[newLaps addObjectsFromArray:[self copyLapsAndApplyDelta:tr
															   wallDelta:lastDeltaTime]];
				prevEnd = [[tr creationTime] dateByAddingTimeInterval:[tr duration]];
				lastDist += [tr distance];
				lastDeltaTime += [tr duration];
			}
			else
			{
				[copyOfSortedTracks removeObjectIdenticalTo:tr];
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				[alert addButtonWithTitle:@"OK"];
				NSString* s = [NSString stringWithFormat:@"The activity named %@ overlaps another activity being combined", [tr name]];
				[alert setMessageText:s];
				[alert setInformativeText:@"This activity was removed from the list of activities to combine"];
				[alert setAlertStyle:NSAlertStyleInformational];
				[alert runModal];
			}
		}	
		if ([combinedPoints count] > origPointCount)
		{
			[combinedTrack setPoints:combinedPoints];
			[combinedTrack setLaps:newLaps];
			[combinedTrack fixupTrack];
			[self replaceTracks:copyOfSortedTracks
					 withTracks:[NSArray arrayWithObject:combinedTrack]
					 actionName:@"Combine activities"];
		}
		else
		{
			combinedTrack = nil;
		}
	}
	return combinedTrack;
}


-(Track*) splitTrack:(Track*)track usingThreshold:(NSTimeInterval)threshold
{
	NSArray* pts = [track points];
    NSUInteger numPts = [pts count];
	NSMutableIndexSet* is = [NSMutableIndexSet indexSet];
	NSTimeInterval lastDelta = 0.0;
	NSTimeInterval offset = 0.0;
	for (int i=0; i<numPts; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		NSTimeInterval delta = [pt wallClockDelta];
		if ((i>0) && ((delta - offset) - lastDelta) >= threshold)
		{
			offset = delta;
			//printf("will split at index %d out of %d\n", i, numPts);
			[is addIndex:i];
			lastDelta = 0.0;
		}
		lastDelta = delta - offset;
	}
	return [self splitTrack:track
				  atIndices:is];
}


-(Track*)splitTrack:(Track*)trk atActiveTimeDelta:(NSTimeInterval)activeTimeDelta
{
	Track* firstTrack = nil;
	int idx = [trk findIndexOfFirstPointAtOrAfterActiveTimeDelta:activeTimeDelta];
	if (idx != -1)
	{
		firstTrack = [self splitTrack:trk
							atIndices:[NSIndexSet indexSetWithIndex:idx]];
	}
	return firstTrack;	
}


-(void)addLapsToTrackAndRemove:(Track*)track laps:(NSMutableArray*)laps wallOffset:(NSTimeInterval)wallOff isFirst:(BOOL)isFirst;
{
    NSUInteger count = [laps count];
	if (count > 0)
	{
		NSMutableArray* lapsToRemove = [NSMutableArray arrayWithCapacity:4];
		NSMutableArray* newLaps = [NSMutableArray arrayWithCapacity:4];
		NSTimeInterval trackDuration = [track duration];
		for (int i=0; i<count; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			NSTimeInterval lapWallDelta = [lap startingWallClockTimeDelta];
			lapWallDelta -= wallOff;
			if ((i==0) && !isFirst)
			{
				[newLaps addObject:[[[Lap alloc] init] autorelease]];
			}
			if (IS_BETWEEN(0, lapWallDelta, trackDuration))
			{
				[lapsToRemove addObject:lap];
				lap = [[lap mutableCopyWithZone:nil] autorelease];
				[lap setStartingWallClockTimeDelta:lapWallDelta];
				[newLaps addObject:lap];
			}
		}	
		if ([lapsToRemove count] > 0) [laps removeObjectsInArray:lapsToRemove];
		if ([newLaps count] > 0) [track setLaps:newLaps];
	}
}


-(Track*) splitTrack:(Track*)track atIndices:(NSIndexSet*)is
{
	Track* firstTrack = nil;
	if ([is count] > 0)
	{
		NSArray* pts = [track points];
        NSUInteger numPts = [pts count];
		NSMutableArray* newTracks = [NSMutableArray arrayWithCapacity:[is count]];
		NSMutableArray* lapsCopy = [NSMutableArray arrayWithArray:[track laps]];
		NSUInteger idx = [is firstIndex];
		int st = 0;
		while (true)
		{
			NSUInteger end = (idx == NSNotFound) ? numPts : idx;
			TrackPoint* pt = [pts objectAtIndex:st];
			NSTimeInterval delta = [pt wallClockDelta];
			float dist = [pt distance];
			float origDist = [pt origDistance];
			
			//Track* curTrack = [[[Track alloc] init] autorelease];
			Track* curTrack = [track mutableCopyWithZone:nil];
			
			
			NSMutableArray* curTrackPoints = [NSMutableArray arrayWithCapacity:end-st+1];
			[curTrack setCreationTime:[[track creationTime] dateByAddingTimeInterval:delta]];
			for (int i=st; i<end; i++)
			{
				pt = [pts objectAtIndex:i];
				pt = [[pt mutableCopyWithZone:nil] autorelease];
				[pt setWallClockDelta:[pt wallClockDelta] - delta];
				float d = [pt distance];
				if (d != BAD_DISTANCE) [pt setDistance:d-dist];
				d = [pt origDistance];
				if (d != BAD_DISTANCE) [pt setOrigDistance:d-origDist];
				[curTrackPoints addObject:pt];
			}
			[curTrack setPoints:curTrackPoints];
			[curTrack fixupTrack];
			[self addLapsToTrackAndRemove:curTrack
									 laps:lapsCopy
							   wallOffset:delta
								  isFirst:st == 0];
			
			[newTracks addObject:curTrack];
			// make sure database knows about this track
			if (!firstTrack) firstTrack = curTrack;
			if (idx == NSNotFound) break;
			st = (int)idx+1;
			idx = [is indexGreaterThanIndex:idx];
		}
		if ([newTracks count] > 1)
		{
			[self copyTrackAttributes:track
							 toTracks:newTracks];
			[self replaceTracks:[NSArray arrayWithObject:track]
					 withTracks:newTracks
					 actionName:@"Split activity"];
		}
	}
	return firstTrack;
}


-(void) addPointsAtIndices:(Track*)track selected:(NSIndexSet*)is pointsToAdd:(NSArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset
{
	NSUndoManager* undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] removePointsAtIndices:track 
														  selected:is];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Add point(s)"];
	}
	NSMutableArray* ptsCopy = [NSMutableArray arrayWithArray:[track points]];
	[ptsCopy insertObjects:pts 
				 atIndexes:is];
	[track setPointsAndAdjustTimeDistance:ptsCopy
							 newStartTime:nst
						   distanceOffset:distOffset];
	[self updateTrack:track];
}




-(void) removePointsAtIndices:(Track*)track selected:(NSIndexSet*)is
{	
	NSMutableArray* newPoints = [NSMutableArray arrayWithArray:[track points]];
	[newPoints removeObjectsAtIndexes:is];
	NSDate* nst = [track creationTime];
	float dst = 0.0;
	if ([newPoints count] > 0)
	{
		TrackPoint* pt = [newPoints objectAtIndex:0];
		nst = [[track creationTime] dateByAddingTimeInterval:[pt wallClockDelta]];
        NSUInteger ct = [newPoints count];
		for (int i=0; i<ct; i++)
		{
			TrackPoint* pt = [newPoints objectAtIndex:i];
			if ([pt validOrigDistance])
			{
				dst = [pt origDistance];
				break;
			}
		}
	}
		
	NSUndoManager* undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] addPointsAtIndices:track 
													   selected:is 
													pointsToAdd:[[track points] objectsAtIndexes:is]
												   newStartTime:[track creationTime]
												 distanceOffset:-dst];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Delete point(s)"];
	}
	[track setPointsAndAdjustTimeDistance:newPoints
							 newStartTime:nst
						   distanceOffset:dst];
	[self updateTrack:track];
}





-(void) addTracks:(NSArray*)arr
{
   NSMutableArray* trackArray = [self.docMetaData trackArray];
  NSUInteger num = [arr count];
   if ((trackArray != nil) && (num > 0))
   {
      NSUndoManager* undo = [self undoManager];
      if (![undo isUndoing])
      {
         if (num == 1)
         {
            [undo setActionName:@"Add activity"];
         }
         else
         {
            [undo setActionName:@"Add activities"];
         }
      }
      [[undo prepareWithInvocationTarget:self] deleteTracks:arr];
      for (int i=0; i<num; i++)
      {
         Track* t = [arr objectAtIndex:i];
         if ([trackArray indexOfObject:t] == NSNotFound)
         {
             t.dirtyMask |= kDirtyMeta;
        
			 ///[trackArray addObject:t];
			 [self addTracksToDB:[NSArray arrayWithObject:t]
			 alsoAddToTrackArray:YES];

			 NSMutableArray* deletedTracks = [self.docMetaData userDeletedTrackTimes];
			 if ([deletedTracks containsObject:[t creationTime]])
			 {
				 [deletedTracks removeObject:[t creationTime]];
				 //NSLog(@"REMOVED track at time %@ from user deleted list", [t creationTime]);
			 }
		 }
         else
         {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            NSString* s = [NSString stringWithFormat:@"Track with the same start time as the track named %@ is already in this document", [t name]];
            [alert setMessageText:s];
            [alert setInformativeText:@"The add or paste operation was not done for this track"];
            [alert setAlertStyle:NSAlertStyleInformational];
            [alert runModal];
          }
      }
	  [[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
      [trackArray sortUsingSelector:@selector(compareByDate:)];
	  [tbWindowController storeExpandedState];
      [tbWindowController buildBrowser:NO];
	  [tbWindowController restoreExpandedState];
      if ([undo isUndoing] || [undo isRedoing])
      {
         [[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
      }
   }
}


-(NSArray*) addTracksAfterStravaSync:(NSArray*)arr
{
    NSDate* newestCreatedTrack = [NSDate distantPast];
    NSDate* oldestCreatedTrack = [NSDate distantFuture];
    NSMutableArray* trackArray = [self.docMetaData trackArray];
    NSUInteger num = [arr count];
    if ((trackArray != nil) && (num > 0))
    {
        NSUndoManager* undo = [self undoManager];
        if (![undo isUndoing])
        {
            if (num == 1)
            {
            [undo setActionName:@"Add Strava activity"];
            }
            else
            {
            [undo setActionName:@"Add Strava activities"];
            }
        }
        [[undo prepareWithInvocationTarget:self] deleteTracks:arr];
        for (int i=0; i<num; i++)
        {
            Track* t = [arr objectAtIndex:i];
            NSDate* trackCreationDate = [t creationTime];
            if (trackCreationDate)
            {
                if ([trackCreationDate compare:newestCreatedTrack] == NSOrderedDescending)
                {
                    newestCreatedTrack = trackCreationDate;
                 }
                if ([trackCreationDate compare:oldestCreatedTrack] == NSOrderedAscending)
                {
                    oldestCreatedTrack = trackCreationDate;
                }
            }
            if ([trackArray indexOfObject:t] == NSNotFound)
            {
                ///[trackArray addObject:t];
                [self addTracksToDB:[NSArray arrayWithObject:t]
                alsoAddToTrackArray:YES];

                    NSMutableArray* deletedTracks = [self.docMetaData userDeletedTrackTimes];
                if ([deletedTracks containsObject:[t creationTime]])
                {
                    [deletedTracks removeObject:[t creationTime]];
                    //NSLog(@"REMOVED track at time %@ from user deleted list", [t creationTime]);
                }
                
            }
            else
            {
                NSLog(@"skipping Strava imported track %s, already there", [[t name] UTF8String]);
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
        [trackArray sortUsingSelector:@selector(compareByDate:)];
        [tbWindowController storeExpandedState];
        [tbWindowController buildBrowser:YES];
        [tbWindowController restoreExpandedState];
        if ([undo isUndoing] || [undo isRedoing])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
        }
    }
    return [NSArray arrayWithObjects:oldestCreatedTrack, newestCreatedTrack, nil];
}


-(void) deleteTracks:(NSArray*)arr;
{
	NSMutableArray* trackArray = [self.docMetaData trackArray];
    NSUInteger num = [arr count];
	if ((trackArray != nil) && (num > 0))
	{
		NSUndoManager* undo = [self undoManager];
		if (![undo isUndoing])
		{
			if (num == 1)
			{
				[undo setActionName:@"Delete activity"];
			}
			else
			{
				[undo setActionName:@"Delete activities"];
			}
		}
        
        if (self.library == nil || self.library.db == nil) {
            NSLog(@"[tbDoc - deleteTracks] no database library or dbm, file has never been saved, so can't delete database tracks");
        } else {
            NSError* err = nil;
            ActivityStore* actStore = [[[ActivityStore alloc] initWithDatabaseManager:self.library.db] autorelease];
            [actStore deleteTracks:arr
                             error:&err];
            if (err != nil) {
                NSLog(@"[TBDoc] database deleteTracks failed for %ld tracks, status \"%@\"", arr.count, [err description]);
            } else {
                NSLog(@"[TBDoc] successfully deleted %ld tracks+points from database", arr.count);
                [self syncFileModDateFromDiskAtURL:self.fileURL];
            }
        }
        
		[[undo prepareWithInvocationTarget:self] addTracks:arr];
        NSMutableArray* deletedTracks = [self.docMetaData userDeletedTrackTimes];
		for (int i=0; i<num; i++)
		{
			Track* t = [arr objectAtIndex:i];
			NSUInteger index = [trackArray indexOfObjectIdenticalTo:t];
			if (index != NSNotFound)
			{
				if (![deletedTracks containsObject:[t creationTime]])
				{
                    t.dirtyMask = kDirtyMeta | kDirtyLaps;  // make sure it's saved if re-added
					[t setEquipmentUUIDs:[equipmentLog equipmentUUIDsForTrack:t]];
					[deletedTracks addObject:[t creationTime]];
					//NSLog(@"ADDED track at time %@ to user deleted list", [t creationTime]);
				}
				[trackArray removeObjectAtIndex:index];
			}
		}
 		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackSelectionChanged" object:nil];
       
		[self trackArrayChanged:NO];
        
#if 0
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
		[tbWindowController storeExpandedState];
		[tbWindowController buildBrowser:NO];
		[tbWindowController restoreExpandedState];
		if ([undo isUndoing] || [undo isRedoing])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
		}
#endif
	}
}


-(void)trackArrayChanged:(BOOL)expandLastItem
{
	///NSMutableArray* trackArray = [docMetaData trackArray];
	///[trackArray sortUsingSelector:@selector(compareByDate:)];
	[tbWindowController storeExpandedState];
	[tbWindowController buildBrowser:expandLastItem];
	[tbWindowController restoreExpandedState];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
	NSUndoManager* undo = [self undoManager];
	if ([undo isUndoing] || [undo isRedoing])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
	}
}

-(void) replaceTrack:(Track*)oldTrack with:(Track*)newTrack
{
	[tbWindowController storeExpandedState];
	NSUndoManager* undo = [self undoManager];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Edit activity"];
	}
	[[undo prepareWithInvocationTarget:self] replaceTrack:newTrack with:oldTrack];
	NSMutableArray* trackArray = [self.docMetaData trackArray];
	[trackArray removeObjectIdenticalTo:oldTrack];
	[self addTracksToDB:[NSArray arrayWithObject:newTrack]
	alsoAddToTrackArray:YES];
	[self trackArrayChanged:NO];
	[tbWindowController restoreExpandedState];
}


-(BOOL) addLap:(Lap*)lap toTrack:(Track*)track
{
	NSUndoManager* undo = [self undoManager];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Add Lap"];
	}
	[[undo prepareWithInvocationTarget:self] deleteLap:lap fromTrack:track];
	[track addLapInFront:lap];
	[tbWindowController storeExpandedState];
	[tbWindowController buildBrowser:NO];
	[tbWindowController restoreExpandedState];
	if ([undo isUndoing] || [undo isRedoing])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackEdited" object:track];
	return YES;
}



-(void) restoreLaps:(NSMutableArray*)laps toTrack:(Track*)track deletedLap:(Lap*)lap
{
	NSMutableArray* prevLaps = [[NSMutableArray alloc] initWithArray:track.laps
														   copyItems:YES];
	[track setLaps:laps];
	NSUndoManager* undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] restoreLaps:prevLaps toTrack:track deletedLap:nil];
    [tbWindowController rebuildBrowserAndRestoreState:track
                                            selectLap:lap];
	if ([undo isUndoing] || [undo isRedoing])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackEdited" object:track];
}


-(BOOL) deleteLap:(Lap*)lap fromTrack:(Track*)track
{
	BOOL ret = NO;
	NSUndoManager* undo = [self undoManager];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Delete Lap"];
	}
	NSMutableArray* prevLaps = [[NSMutableArray alloc] initWithArray:track.laps
														   copyItems:YES];
	if ([track deleteLap:lap])
	{
		[[undo prepareWithInvocationTarget:self] restoreLaps:prevLaps toTrack:track deletedLap:lap];
		if ([undo isUndoing] || [undo isRedoing])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackEdited" object:track];
		ret = YES;
	}
	return ret;
}



-(BOOL) insertLapMarker:(NSTimeInterval)atActiveTimeDelta inTrack:(Track*)track
{
	BOOL ret = NO;
	NSUndoManager* undo = [self undoManager];
	if (![undo isUndoing])
	{
		[undo setActionName:@"Insert Lap Marker"];
	}
	Lap* lap = [track addLap:atActiveTimeDelta];
	if (lap)
	{
		[[undo prepareWithInvocationTarget:self] deleteLap:lap fromTrack:track];
		[tbWindowController storeExpandedState];
		[tbWindowController buildBrowser:NO];
		[tbWindowController restoreExpandedState];
		if ([undo isUndoing] || [undo isRedoing])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"UndoRedoCompleted" object:self];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackEdited" object:track];
		ret = YES;
	}
	return ret;
}




// ---- file import begins here ----

// remove duplicates, if any
-(NSArray*) pruneNewTrackArray:(NSArray*)arr
{
	NSMutableArray* returnArr = [NSMutableArray arrayWithArray:arr];
    NSUInteger numNew = [arr count];
	NSMutableArray* trackArray = [self.docMetaData trackArray];
	for (int i=0; i<numNew; i++)
	{
		Track* track = [arr objectAtIndex:i];
		BOOL contains = [trackArray containsObject:track];
		if (contains)
		{
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            NSDate *date = [track creationTime];

            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];
            formatter.dateFormat = @"dd-MMM-yy HH:mm";

            NSString *s = [formatter stringFromDate:date];
            [formatter release]; // if not using ARC            s = [NSString stringWithFormat:@"An activity being imported has same start time as an activity already in the current document:\n\n\t%@",s];
            [alert setMessageText:s];
            [alert setInformativeText:@"\nEach activity contained within an activity document must have a unique start time. \n\n"
									   "The import operation was not completed for this activity. "
									   "If you want to import this activity, use a new or different activity document."];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert runModal];
			[returnArr removeObject:track];
		}
	}
	return returnArr;
}


-(Track*) importTCXFile:(NSString*)fileName;
{
	Track* lastTrack = nil;
	TCX* tcx = [[[TCX alloc] initWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
	NSMutableArray* importedTrackArray = [NSMutableArray array];
	NSMutableArray* importedLapArray = [NSMutableArray array];
	BOOL sts = [tcx import:importedTrackArray laps:importedLapArray];
	if (sts == YES)
	{
		NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
		//NSMutableArray* trackArray = [docMetaData trackArray];
		arr = [self pruneNewTrackArray:arr];
		if ([arr count] > 0)
		{
			lastTrack = [arr lastObject];
		}
		//[trackArray addObjectsFromArray:arr];
		[self addTracksToDB:arr
		alsoAddToTrackArray:YES];

		if (importedLapArray != nil)
		{
			[self processLapData:importedLapArray
					   forTracks:importedTrackArray];
		}
		//[tbWindowController buildBrowser:YES];
		//[[tbWindowController window] setDocumentEdited:YES];   
		//[self updateChangeCount:NSChangeDone];
	}
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
	return lastTrack;
}


-(Track*) importGPXFile:(NSString*)fileName
{
	Track* lastTrack = nil;
	//NSLog(@"import GPX: %@\n", fileName);
	GPX* gpxie = [[[GPX alloc] initGPXWithFileURL:[NSURL fileURLWithPath:fileName]
							   windowController:tbWindowController] autorelease];
	NSMutableArray* importedTrackArray = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray* importedLapArray = [[[NSMutableArray alloc] init] autorelease];
	BOOL sts = [gpxie import:importedTrackArray laps:importedLapArray];
	if (sts == YES)
	{
		NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
		//NSMutableArray* trackArray = [docMetaData trackArray];
		arr = [self pruneNewTrackArray:arr];
		//[trackArray addObjectsFromArray:arr];
		[self addTracksToDB:arr
		alsoAddToTrackArray:YES];

		if ([arr count] > 0)
		{
			lastTrack = [arr lastObject];
		}
		if (importedLapArray != nil)
		{
			[self processLapData:importedLapArray
					   forTracks:importedTrackArray];
		}
		//[tbWindowController buildBrowser:YES];
		//[[tbWindowController window] setDocumentEdited:YES];   
		//[self updateChangeCount:NSChangeDone];
	}
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
	return lastTrack;
}


-(void) addTracksToDB:(NSArray*)arr alsoAddToTrackArray:(BOOL)ata
{
	if (ata)
	{
		NSMutableArray* trackArray = [self.docMetaData trackArray];
		[trackArray addObjectsFromArray:arr];
	}
	for (Track* t in arr)
	{
		[equipmentLog trackAddedOrUpdated:t];
	}
}
	

-(Track*) importHRMFile:(NSString*)fileName;
{
	Track* lastTrack = nil;
	HRM* hrm = [[[HRM alloc] initHRMWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
	NSMutableArray* importedTrackArray = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray* importedLapArray = [[[NSMutableArray alloc] init] autorelease];
	BOOL sts = [hrm import:importedTrackArray laps:importedLapArray];
	if (sts == YES)
	{
		NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
		//NSMutableArray* trackArray = [docMetaData trackArray];
		arr = [self pruneNewTrackArray:arr];
		if ([arr count] > 0)
		{
			lastTrack = [arr lastObject];
		}
		//[trackArray addObjectsFromArray:arr];
		[self addTracksToDB:arr
		alsoAddToTrackArray:YES];
		
		if (importedLapArray != nil)
		{
			[self processLapData:importedLapArray
					   forTracks:importedTrackArray];
		}
		//[tbWindowController buildBrowser:YES];
		//[[tbWindowController window] setDocumentEdited:YES];   
		//[self updateChangeCount:NSChangeDone];
	}
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackArrayChanged" object:self];
	return lastTrack;
}


-(Track*) importFITFile:(NSString*)fileName;
{
	Track* lastTrack = nil;
	GarminFIT* fit = [[[GarminFIT alloc] initWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
	NSMutableArray* importedTrackArray = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray* importedLapArray = [[[NSMutableArray alloc] init] autorelease];
	BOOL sts = [fit import:importedTrackArray laps:importedLapArray];
	if (sts == YES)
	{
		NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
		//NSMutableArray* trackArray = [docMetaData trackArray];
		arr = [self pruneNewTrackArray:arr];
		if ([arr count] > 0)
		{
			lastTrack = [arr lastObject];
		}
		//[trackArray addObjectsFromArray:arr];
		[self addTracksToDB:arr
		alsoAddToTrackArray:YES];
		
		if (arr != nil)
		{
			[self processLapData:importedLapArray
					   forTracks:importedTrackArray];
		}
		for (Track* t in arr)
		{
			[t invalidateStats];
		}
	}
	return lastTrack;
}



-(void) exportGPXFile:(Track*)track fileName:(NSString*)fileName
{
    NSLog(@"export GPX: %@\n", fileName);
    GPX* gpxie = [[[GPX alloc] initGPXWithFileURL:[NSURL fileURLWithPath:fileName] windowController:tbWindowController] autorelease];
    [gpxie release];
}


-(void) exportKMLFile:(Track*)track fileName:(NSString*)fileName
{
    NSLog(@"export KML: %@\n", fileName);
    KML* kmlie = [[[KML alloc] initKMLWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
     [kmlie release];
}


-(void) exportTCXFile:(NSArray*)tracks fileName:(NSString*)fileName
{
    NSLog(@"export TCX: %@\n", fileName);
    TCX* tcxie = [[[TCX alloc] initWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
    [tcxie release];
}


-(void) exportLatLonTextFile:(Track*)track fileName:(NSString*)fileName
{
   NSLog(@"export Lat Lon Text: %@\n", fileName);
   FILE* fh = fopen([fileName UTF8String], "a");
   int num = 0;
   if (fh != nil)
   {
      NSMutableArray* pts = [track goodPoints];
       NSUInteger count = [pts count];
      fprintf(fh, "{");
      for (int i=0 ;i<count; i++)
      {
         TrackPoint* pt = [pts objectAtIndex:i];
         if ([pt validLatLon])
         {
            if (num != 0)
            {
               fprintf(fh, ",");
            } 
            fprintf(fh, "{%8.5f,%8.5f}", [pt latitude], [pt longitude] );
            ++num;
         }
      }
      fprintf(fh, "}");
      fclose(fh);
   }
}


-(int)numberOfSavesSinceLocalBackup;
{
	return [self.docMetaData numberOfSavesSinceLocalBackup];
}


-(int)numberOfSavesSinceMobileMeBackup
{
    return 0;
}


-(void)setNumberOfSavesSinceLocalBackup:(int)n
{
	[self.docMetaData setNumberOfSavesSinceLocalBackup:n];
}


-(void)setNumberOfSavesSinceMobileMeBackup:(int)n
{
}


-(BOOL)usesEquipmentLog
{
	int flags = [self.docMetaData flags];
	return FLAG_IS_SET(flags, kUsesEquipmentLog);
}

-(void)setUsesEquipmentLog:(BOOL)uses
{
	int savedFlags = [self.docMetaData flags];
	int temp = savedFlags;
	if (uses)
	{
		SET_FLAG(temp, kUsesEquipmentLog);
	}
	else
	{
		CLEAR_FLAG(temp, kUsesEquipmentLog);
	}
	if (temp != savedFlags)
	{
		[self.docMetaData setFlags:temp];
		[self updateChangeCount:NSChangeDone];
	}
}


-(float)getEquipmentDataAtIndex:(int)idx forEquipmentNamed:(NSString*)eq
{
	float v = 0.0;
	NSArray* arr = [equipmentLogDataDict objectForKey:eq];
	if (arr && (idx < [arr count]))
	{
		v = [[arr objectAtIndex:idx] floatValue];
	}
	return v;
}


-(float)getCumulativeEquipmentDataStartingAtIndex:(int)idx forEquipmentNamed:(NSString*)eq
{
	float v = 0.0;
	NSArray* arr = [equipmentLogDataDict objectForKey:eq];
	if (arr && (idx < [arr count]))
	{
		while (idx < [arr count])
		{
			v += [[arr objectAtIndex:idx] floatValue];
			idx+=2;
		}
	}
	return v;
}


-(void)setInitialEquipmentLogData:(NSMutableDictionary*)eld
{
	[self.docMetaData setInitialEquipmentLogData:eld];
	[self updateChangeCount:NSChangeDone];
}


-(NSMutableDictionary*)initialEquipmentLogData
{
	return [self.docMetaData initialEquipmentLogData];
}



-(void)setDocumentDateRange:(NSArray*)datesArray;
{
	[self.docMetaData setStartEndDateArray:datesArray];
	[self updateChangeCount:NSChangeDone];
}

-(NSArray*)documentDateRange
{
	return [self.docMetaData startEndDateArray];
}

+ (BOOL)autosavesInPlace {
    return YES;  // opt in
}

// 2) Disable periodic draft autosaving
- (NSTimeInterval)autosavingDelay {
    return 10.0;   // 0 disables the autosave timer
}

// (Optional) also disable Versions UI if you don’t use it
+ (BOOL)preservesVersions {
    return NO;
}



- (void)teardownDocumentDBM
{
    if (self.identifierStore) { [self.identifierStore release]; self.identifierStore = nil; }
    if (self.trackPointStore) { [self.trackPointStore release]; self.trackPointStore = nil; }
    if (self.activityStore)   { [self.activityStore release];   self.activityStore   = nil; }
    if (self.documentDBM)     { [self.documentDBM close];       [self.documentDBM release]; self.documentDBM = nil; }

    if (self.hasSecurityScope && self.scopedURL) {
        [self.scopedURL stopAccessingSecurityScopedResource];
        [self.scopedURL release];
        self.scopedURL = nil;
        self.hasSecurityScope = NO;
    }
}


#pragma mark - Incremental decision



#pragma mark - Writable DBM acquisition

- (DatabaseManager *)documentDBMForURL:(NSURL *)url
                                 error:(NSError **)outError
{
    if (url == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteInvalidFileNameError
                                        userInfo:@{NSLocalizedDescriptionKey:@"Nil destination URL"}];
        }
        return nil;
    }

    // Reuse current writable DBM if it points at the same URL.
    if (self.documentDBM != nil) {
        NSURL *currentURL = nil;
        if ([self.documentDBM respondsToSelector:@selector(url)]) {
            // If DatabaseManager exposes its URL, use it to confirm reuse.
            currentURL = [self.documentDBM performSelector:@selector(url)];
        }

        if (currentURL == nil || [currentURL isEqual:url]) {
            return self.documentDBM;
        }

        // Different target URL -> retire the existing DBM and dependent stores.
        @try {
            [self.activityStore release];
            self.activityStore = nil;

            [self.trackPointStore release];
            self.trackPointStore = nil;

            [self.identifierStore release];
            self.identifierStore = nil;

            [self.documentDBM close];
        } @catch (__unused id e) {
            // Best effort; continue cleanup.
        }

        [self.documentDBM release];
        self.documentDBM = nil;
    }

    // Create a fresh writable DBM for the requested URL.
    NSError *openErr = nil;
    DatabaseManager *dbm = [[DatabaseManager alloc] initWithURL:url];
    if (![dbm open:&openErr]) {
        if (outError) {
            *outError = openErr ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:NSFileWriteUnknownError
                                                   userInfo:@{NSLocalizedDescriptionKey:@"Failed to open writable database"}];
        }
        [dbm release];
        return nil;
    }

    self.documentDBM = dbm;   // property retains
    [dbm release];            // balance our alloc

    return self.documentDBM;
}


- (void)syncFileModDateFromDiskAtURL:(NSURL *)u
{
    if (u == nil) {
        return;
    }

    NSError *attrErr = nil;
    NSDictionary *attrs =
        [[NSFileManager defaultManager] attributesOfItemAtPath:u.path error:&attrErr];

    NSDate *mod = [attrs objectForKey:NSFileModificationDate];
    if (mod != nil) {
        // Must happen on main; this is an NSDocument property.
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setFileModificationDate:mod];
            });
        } else {
            [self setFileModificationDate:mod];
        }
    }
}

@end
