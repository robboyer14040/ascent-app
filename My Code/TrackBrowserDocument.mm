//
//  TrackBrowserDocument.m
//  TLP
//
//  Created by Rob Boyer on 7/10/06.
//  Copyright rcb Construction 2006 . All rights reserved.
//
#import "Defs.h"
#import "TrackBrowserDocument.h"
#import "TBWindowController.h"
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

#include <unistd.h>        // for sleep()


#define DEBUG_SYNC      0&&ASCENT_DBG

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



// values for the TrackBrowserData 'flags' field
enum
{
	kUsesEquipmentLog				= 0x00000001,
	kHasInitialEquipmentLogData		= 0x00000002,
};

@interface TrackBrowserData : NSObject <NSCoding>
{
	NSMutableArray*                 trackArray;
	NSMutableDictionary*            tableInfoDict;			// main browser column info
	NSMutableDictionary*            splitsTableInfoDict;	// splits table column info
	NSDate*							lastSyncTime;
	NSMutableArray*					userDeletedTrackTimes;
	NSMutableDictionary*			initialEquipmentLogData;
	NSString*						uuid;
	NSArray*						startEndDateArray;
	int								numberOfSavesSinceLocalBackup;
	int								numberOfSavesSinceMobileMeBackup;
	int								flags;
}
@property (nonatomic, retain) NSString* uuid;
@property (nonatomic, retain) NSMutableDictionary* initialEquipmentLogData;
@property (nonatomic, retain) NSArray* startEndDateArray;
-(void)setTrackArray:(NSMutableArray*)ta;
-(NSMutableArray*)trackArray;
-(NSMutableDictionary *)tableInfoDict;
-(NSMutableDictionary *)splitsTableInfoDict;
-(NSMutableArray*) userDeletedTrackTimes;
-(void)setLastSyncTime:(NSDate*)d;
-(void)setTableInfoDict:(NSMutableDictionary *)value;
-(void)setSplitsTableInfoDict:(NSMutableDictionary *)value;
-(void)setUserDeletedTrackTimes:(NSMutableArray*)arr;
-(int)numberOfSavesSinceLocalBackup;
-(int)numberOfSavesSinceMobileMeBackup;
-(void)setNumberOfSavesSinceLocalBackup:(int)n;
-(void)setNumberOfSavesSinceMobileMeBackup:(int)n;
-(int)flags;
-(void)setFlags:(int)flgs;
-(void)storeMetaData:(ActivityStore*)store;
@end


@implementation TrackBrowserData

@synthesize uuid;
@synthesize initialEquipmentLogData;
@synthesize startEndDateArray;

- (id) init
{
	if (self = [super init])
	{
		flags = 0;
		uuid = [[NSString uniqueString] retain];
		trackArray = [[NSMutableArray alloc] init];
		userDeletedTrackTimes = [[NSMutableArray alloc] init];
		lastSyncTime = [NSDate distantPast];
		[lastSyncTime retain];
		numberOfSavesSinceLocalBackup = numberOfSavesSinceMobileMeBackup = 0;
		initialEquipmentLogData = [[NSMutableDictionary dictionaryWithCapacity:4] retain];
		SET_FLAG(flags, kHasInitialEquipmentLogData);
		startEndDateArray = [[NSArray arrayWithObjects:[NSDate distantPast], [NSDate distantFuture], nil] retain];
	}
	return self;
}


- (void) dealloc
{
	[startEndDateArray release];
	[trackArray release];
	[lastSyncTime release];
	[tableInfoDict release];
	[splitsTableInfoDict release];
	[userDeletedTrackTimes release];
	[initialEquipmentLogData release];
	[uuid release];
	[super dealloc];
}



#define CUR_VERSION 8

- (id)initWithCoder:(NSCoder *)coder
{
	[super init];
	trackArray = [[NSMutableArray alloc] init];
	if ( [coder allowsKeyedCoding] )
	{
	   [self setTrackArray:[coder decodeObjectForKey:@"tracks"]];
	   [self setLastSyncTime:[coder decodeObjectForKey:@"lastSyncTime"]];
	}
	else
	{
		float fval;
		float ival;
		int version;
		flags = 0;
		@try 
		{

			[coder decodeValueOfObjCType:@encode(int) at:&version];
			if (version > CUR_VERSION)
			{
				NSException *e = [NSException exceptionWithName:ExFutureVersionName
													   reason:ExFutureVersionReason
													 userInfo:nil];			  
				@throw e;
			}
			if (version >= 1)
			{
				[self setTrackArray:[coder decodeObject]];
				// remove any tracks without creation times
                NSUInteger num = [trackArray count];
				NSMutableIndexSet* is = [NSMutableIndexSet indexSet];
				for (int i=0; i<num; i++)
				{
					Track* t = [trackArray objectAtIndex:i];
					if ([t creationTime] == nil)
					{
						[is addIndex:i];
						NSLog(@"Removed track (%d of %d) with nil creation date!", (int)i, (int)num);
					}
				}
				[trackArray removeObjectsAtIndexes:is];
					  
				  
				[self setLastSyncTime:[coder decodeObject]];
				NSString* spareString;

				NSString* s = [coder decodeObject];      // added in v5, did not change version#
				if (!s || [s isEqualToString:@""])
				{
					s = [NSString uniqueString];
				}
				self.uuid = s;

				if (version > 7)
				{
					self.startEndDateArray = [coder decodeObject];      // changed from spare in v8
				}
				else
				{
					self.startEndDateArray = [NSArray arrayWithObjects:[NSDate distantPast], [NSDate distantFuture], nil];
					spareString = [coder decodeObject];      // spare
				}
				spareString = [coder decodeObject];      // spare
				spareString = [coder decodeObject];      // spare
				[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
				[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
				[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
				[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
				[coder decodeValueOfObjCType:@encode(int) at:&numberOfSavesSinceLocalBackup];        // was spare
				[coder decodeValueOfObjCType:@encode(int) at:&numberOfSavesSinceMobileMeBackup];     // was spare
				[coder decodeValueOfObjCType:@encode(int) at:&flags];		// changed in v6 (was spare)
				[coder decodeValueOfObjCType:@encode(int) at:&ival];		// spare
			}
		  
		   if (version > 1)
		   {
			   [self setTableInfoDict:[coder decodeObject]];
		   }
		  
		   if (version > 2)
		   {
			   [self setSplitsTableInfoDict:[coder decodeObject]];
		   }
		  
		   if (version > 3)
		   {
			   [self setUserDeletedTrackTimes:[coder decodeObject]];
		   }
		   if (!userDeletedTrackTimes)  userDeletedTrackTimes = [[NSMutableArray alloc] init];
		  
		   if (![RegController CHECK_REGISTRATION])
		   {
			   while ([trackArray count] > kNumUnregisteredTracks)
			   {
				   [trackArray removeLastObject];
			   }
		   }
		   BOOL hasInitialEquipmentLogData = NO;
		   if (version >= 6)
		   {
			   hasInitialEquipmentLogData = FLAG_IS_SET(flags, kHasInitialEquipmentLogData);
		   }
		   if (hasInitialEquipmentLogData)
		   {
			   [self setInitialEquipmentLogData:[coder decodeObject]];
		   }
		   else
		   {
			   [self setInitialEquipmentLogData:[NSMutableDictionary dictionaryWithCapacity:4]];
		   }
		   SET_FLAG(flags, kHasInitialEquipmentLogData);
		}
		@catch (NSException *exception) 
		{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"Document Read Error"];
			[alert setInformativeText:[exception reason]];
			[alert setAlertStyle:NSAlertStyleWarning];
			[alert runModal];
			@throw;
		}
	}
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	if ( [coder allowsKeyedCoding] )
	{
		[coder encodeObject:trackArray forKey:@"tracks"];
		[coder encodeObject:lastSyncTime forKey:@"lastSyncTime"];
	}
	else
	{
		int version = CUR_VERSION;
		// version 1
		float spareFloat = 0.0f;
		int spareInt = 0;

		[coder encodeValueOfObjCType:@encode(int) at:&version];
		[coder encodeObject:trackArray];
		[coder encodeObject:lastSyncTime];
		NSString* spareString = @"";
		[coder encodeObject:self.uuid];
		[coder encodeObject:startEndDateArray];
		[coder encodeObject:spareString];
		[coder encodeObject:spareString];
		[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
		[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
		[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
		[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
		[coder encodeValueOfObjCType:@encode(int) at:&numberOfSavesSinceLocalBackup];
		[coder encodeValueOfObjCType:@encode(int) at:&numberOfSavesSinceMobileMeBackup];
		[coder encodeValueOfObjCType:@encode(int) at:&flags];		// changed in v6 (was spareInt)
		[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
		// version 2
		[coder encodeObject:tableInfoDict];
		// version 3
		[coder encodeObject:splitsTableInfoDict];
		// version 4
		[coder encodeObject:userDeletedTrackTimes];
		// added in version 7, did not bump version (using flag technique)
		SET_FLAG(flags, kHasInitialEquipmentLogData);
		[coder encodeObject:initialEquipmentLogData];
		
	}
}


-(void)storeMetaData:(ActivityStore*)store
{
    if (store) {
        NSError* err;
        BOOL worked = [store saveMetaWithTableInfo:tableInfoDict
                                   splitsTableInfo:splitsTableInfoDict
                                              uuid:uuid
                                         startDate:(NSDate *)startEndDateArray[0]
                                           endDate:(NSDate *)startEndDateArray[1]
                                             flags:flags
                                              int2:0
                                              int3:0
                                              int4:0
                                             error:&err];
        if (!worked)
        {
            NSLog(@"Metadata store FAILED");
        }
    }
}


-(int)flags
{
	return flags;
}


-(void)setFlags:(int)flgs
{
	flags = flgs;
}


- (void)setTrackArray:(NSMutableArray*)ta
{
	if (ta != trackArray)
	{
		[trackArray release];
		trackArray = ta;
		[trackArray retain];
	}
}


- (NSDate*)lastSyncTime
{
	return lastSyncTime;
}


- (void)setLastSyncTime:(NSDate*)d
{
	if (d != lastSyncTime)
	{
		[lastSyncTime release];
		lastSyncTime = d;
		[lastSyncTime retain];
	}
}


- (NSMutableArray*)trackArray
{
	return trackArray;
}


- (NSMutableDictionary *)tableInfoDict 
{
	return tableInfoDict;
}


- (void)setTableInfoDict:(NSMutableDictionary *)value 
{
	if (tableInfoDict != value) 
	{
		[tableInfoDict autorelease];
		tableInfoDict = value;
		[tableInfoDict retain];
	}
	[[BrowserInfo sharedInstance] setColInfoDict:tableInfoDict];
}


- (NSMutableDictionary *)splitsTableInfoDict 
{
	return splitsTableInfoDict;
}


- (void)setSplitsTableInfoDict:(NSMutableDictionary *)value 
{
	if (splitsTableInfoDict != value) 
	{
		[splitsTableInfoDict autorelease];
		splitsTableInfoDict = value;
		[splitsTableInfoDict retain];
	}
	[[BrowserInfo sharedInstance] setSplitsColInfoDict:splitsTableInfoDict];
}


-(void)setUserDeletedTrackTimes:(NSMutableArray*)arr
{
	if (arr != userDeletedTrackTimes)
	{
		[userDeletedTrackTimes autorelease];
		userDeletedTrackTimes = [arr retain];
	}
}



-(NSMutableArray*) userDeletedTrackTimes
{
	return userDeletedTrackTimes;
}

-(int)numberOfSavesSinceLocalBackup
{
	return numberOfSavesSinceLocalBackup;
}


-(int)numberOfSavesSinceMobileMeBackup
{
	return numberOfSavesSinceMobileMeBackup;
}


-(void)setNumberOfSavesSinceLocalBackup:(int)n
{
	numberOfSavesSinceLocalBackup = n;
}


-(void)setNumberOfSavesSinceMobileMeBackup:(int)n
{
	numberOfSavesSinceMobileMeBackup = n;
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

@interface TrackBrowserDocument (Private)
-(int)loadGPSData:(Track**)lastTrackLoaded;
-(void)addPointsAtIndices:(Track*)track selected:(NSIndexSet*)is pointsToAdd:(NSArray*)pts newStartTime:(NSDate*)nst distanceOffset:(float)distOffset;
-(BOOL)trackExistsAtTime:(NSDate*)st startIndex:(int*)startIdx slop:(int)ss;
-(void)trackArrayChanged:(BOOL)rebuildBrowser;
-(void) copyTrackAttributes:track toTracks:(NSArray*)newTracks;
-(Track*) splitTrack:(Track*)track atIndices:(NSIndexSet*)is;
-(void) addTracksToDB:(NSArray*)arr alsoAddToTrackArray:(BOOL)ata;
-(void)syncDirect:(int*)numLoadedPtr lastTrackLoaded:(Track**)lastTrackLoadedPtr;
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


- (id) init
{
	self = [super init];
	if (self) 
	{
		equipmentTotalsNeedUpdate = YES;
		currentlySelectedTrack = nil;
		selectedLap = nil;
		browserData = [[TrackBrowserData alloc] init];
		backupDelegate = [[BackupDelegate alloc] initWithDocument:self];
		tbWindowController = nil;
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


- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
   [[[NSUserDefaultsController sharedUserDefaultsController] values]  
   setValue:[NSArchiver archivedDataWithRootObject:absoluteURL] 
     forKey:@"lastFileURL"];
#if _DEBUG
	NSLog(@"opened url:%@\n", absoluteURL);
#endif
	id ret = [super initWithContentsOfURL:absoluteURL
								   ofType:typeName
									error:outError];

	if (ret)
	{
		//[equipmentLog buildEquipmentListFromDefaultAttributes:tb];
	}
	return ret;
}


- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"doc DEALLOC %x rc: %d", self, [self retainCount]);
#endif
	[backupDelegate release];
	[browserData release];
	[selectedLap release];
	[currentlySelectedTrack release];
	[equipmentLog release];
	[equipmentLogDataDict release];
	[super dealloc];
}



- (void)setTracks:(NSMutableArray*)tracks
{
   [browserData setTrackArray:tracks];
}


-(NSString*)uuid
{
	return browserData.uuid;
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
	NSMutableArray* trackArray = [browserData trackArray];
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
			contains = [[browserData userDeletedTrackTimes] containsObject:[track creationTime]];
			if (contains == NO)
			{
                NSUInteger numTracks = [trackArray count];
				//if ([[browserData lastSyncTime] compare:[track creationTime]] == NSOrderedAscending) &&
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
			[browserData setLastSyncTime:lastSyncedTrackDate];
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
		}
		else if ([ext caseInsensitiveCompare:@"fit"] == NSOrderedSame)
		{
			GarminFIT* fit = [[[GarminFIT alloc] initWithFileURL:[NSURL fileURLWithPath:fileToImport]] autorelease];
			sts = [fit import:importedTrackArray laps:importedLapArray];
		}
		if (sts == YES)
		{
			NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
			NSMutableArray* trackArray = [browserData trackArray];
            NSUInteger numImported = [arr count];
			for (int i=0; i<numImported; i++)
			{
				Track* t = [arr objectAtIndex:i];
				// start time may have changed; check again and make *sure* it doesn't already exist
				if (![trackArray containsObject:t])
				{
					// make sure user hasn't deleted this track from this document already
					BOOL contains = [[browserData userDeletedTrackTimes] containsObject:[t creationTime]];
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


-(BOOL)trackExistsAtTime:(NSDate*)st startIndex:(int*)startIdx slop:(int)secondsSlop
{
	BOOL ret = NO;
	NSArray* trackArray = [browserData trackArray];
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
   data = [NSKeyedArchiver archivedDataWithRootObject:browserData];
#else
   // NOTE: archivedDataWithRootObject (and encodeRootObject) cause the encoding process to be run 2x, and
   // this is not necessary here.  Therefore, since there are no cycles in the data being encoded, we just
   // call encodeObject on on the root browserData object
   NSMutableData* data = [NSMutableData data];
   NSArchiver* arch = [[[NSArchiver alloc] initForWritingWithMutableData:data] autorelease];
   [arch encodeObject:browserData];
   //data = [NSArchiver archivedDataWithRootObject:browserData];
#endif
   return data;
}



- (TBWindowController*) windowController
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

#if 0
- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	BOOL ret = YES;
	[self startProgressIndicator:[NSString stringWithFormat:@"opening activity document \"%@\"...", [self displayName]]];

	// Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.

	// For applications targeted for Tiger or later systems, you should use the new Tiger API readFromData:ofType:error:.  In this case you can also choose to override -readFromURL:ofType:error: or -readFromFileWrapper:ofType:error: instead.
	browserData = nil;
	@try
	{
		browserData = [NSUnarchiver unarchiveObjectWithData:data];
		if (![browserData isKindOfClass:[TrackBrowserData class]])
		{
			browserData = [[TrackBrowserData alloc] init];
			NSMutableArray* ta = [NSUnarchiver unarchiveObjectWithData:data];
			[browserData setTrackArray:ta];
		}
		else
		{
			[browserData retain];
		}
	}
	@catch (NSException* ex)
	{
	}

	if (browserData == nil)
	{
	  ret =  NO;
	}
	else
	{
		if (tbWindowController == nil)
		{
			tbWindowController = [[[TBWindowController alloc] initWithDocument:self] autorelease];     // does this go here?
			[self addWindowController:tbWindowController];
		}
		[self updateProgressIndicator:@"updating main browser and equipment log..."];
		//[tbWindowController buildBrowser:YES];
		[equipmentLog buildEquipmentListFromDefaultAttributes:self];
	}
	[self endProgressIndicator];
	return YES;
}
#else
// NSDocument subclass
- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError * _Nullable *)outError
{
    BOOL ret = YES;
    [self startProgressIndicator:[NSString stringWithFormat:@"opening activity document \"%@\"...", [self displayName]]];

    // Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.

    // For applications targeted for Tiger or later systems, you should use the new Tiger API readFromData:ofType:error:.  In this case you can also choose to override -readFromURL:ofType:error: or -readFromFileWrapper:ofType:error: instead.
    browserData = nil;
    @try
    {
        browserData = [NSUnarchiver unarchiveObjectWithData:data];
        if (![browserData isKindOfClass:[TrackBrowserData class]])
        {
            browserData = [[TrackBrowserData alloc] init];
            NSMutableArray* ta = [NSUnarchiver unarchiveObjectWithData:data];
            [browserData setTrackArray:ta];
        }
        else
        {
            [browserData retain];
        }
    }
    @catch (NSException* ex)
    {
    }

    if (browserData == nil)
    {
      ret =  NO;
    }
    else
    {
        if (tbWindowController == nil)
        {
            tbWindowController = [[[TBWindowController alloc] initWithDocument:self] autorelease];     // does this go here?
            [self addWindowController:tbWindowController];
        }
        [self updateProgressIndicator:@"updating main browser and equipment log..."];
        //[tbWindowController buildBrowser:YES];
        [equipmentLog buildEquipmentListFromDefaultAttributes:self];
    }
    [self endProgressIndicator];
    return YES;
}

//- (NSData *)dataOfType:(NSString *)typeName
//                 error:(NSError * _Nullable *)outError
//{
//    // ✳︎ Put your old "dataRepresentationOfType" logic here
//    return [NSKeyedArchiver archivedDataWithRootObject:self.model
//                                requiringSecureCoding:YES
//                                                error:outError];
//}
#endif

- (BOOL)keepBackupFile
{
	return NO;
}


- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
#if 1
//    NSURL *urlWithoutExt = [absoluteURL URLByDeletingPathExtension];
//    NSURL* newURL = [urlWithoutExt URLByAppendingPathExtension:@"sql"];
   
    
    NSError *err = nil;
    NSURL *downloadsURL =
        [[NSFileManager defaultManager] URLForDirectory:NSDownloadsDirectory
                                               inDomain:NSUserDomainMask
                                      appropriateForURL:nil
                                                 create:NO
                                                  error:&err];
    if (!downloadsURL) {
        NSLog(@"Downloads URL error: %@", err);
    } else {
        NSURL* newURL = [downloadsURL URLByAppendingPathComponent:[absoluteURL lastPathComponent]];
        newURL = [newURL URLByDeletingPathExtension];
        newURL = [newURL URLByAppendingPathExtension:@"sql"];
        ActivityStore *store = [[ActivityStore alloc] initWithURL:newURL];
        NSError *err = nil;
        [store open:&err];
        [store createSchema:&err];
        [browserData storeMetaData:store];
        [store saveAllTracks:[browserData trackArray]  error:&err];
        [store close];
   }
#endif
    
    
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	NSRect fr = [[tbWindowController window] frame];
	NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
	[[pb controller] begin:@"Saving activity document..."
				 divisions:(int)[[browserData trackArray] count]];
	NSPoint origin;
	origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
	origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
	[[[pb controller] window] setFrameOrigin:origin];
	[[pb controller] showWindow:self];
	BOOL couldBeWritten = [super writeSafelyToURL:absoluteURL 
										   ofType:typeName 
								 forSaveOperation:saveOperation 
											error:outError];
	
	// if the above worked, then we should have a backup file in the same directory as original file.
	// based on backup options, we may copy this file elsewhere...
	if (couldBeWritten)
	{
		NSData* archivedData = [NSArchiver archivedDataWithRootObject:absoluteURL];
		[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:archivedData
																			forKey:@"lastFileURL"];
		BOOL isFinished = [backupDelegate doBackupsIfRequired:absoluteURL];
		while (!isFinished)
		{
			isFinished = [backupDelegate isFinished];
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		}
	}
	[[[pb controller] window] orderOut:[tbWindowController window]];
	return couldBeWritten;
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
      tbWindowController = [[TBWindowController alloc] initWithDocument:self];     // does this go here?
      [self addWindowController:tbWindowController];
      [tbWindowController release];
   }
}


- (NSMutableArray*)trackArray
{
   return [browserData trackArray];
}



-(NSMutableDictionary*) colInfoDict
{
   return [browserData tableInfoDict];
}


-(void) setColInfoDict:(NSMutableDictionary*)dict
{
   [browserData setTableInfoDict:dict];
}


-(NSMutableDictionary*) splitsColInfoDict
{
   return [browserData splitsTableInfoDict];
}


-(void) setSplitsColInfoDict:(NSMutableDictionary*)dict
{
   [browserData setSplitsTableInfoDict:dict];
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
	NSMutableArray* trackArray = [browserData trackArray];
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





-(void) addTracks:(NSMutableArray*)arr
{
   NSMutableArray* trackArray = [browserData trackArray];
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
			 ///[trackArray addObject:t];
			 [self addTracksToDB:[NSArray arrayWithObject:t]
			 alsoAddToTrackArray:YES];

			 NSMutableArray* deletedTracks = [browserData userDeletedTrackTimes];
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


-(void) deleteTracks:(NSMutableArray*)arr;
{
	NSMutableArray* trackArray = [browserData trackArray];
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
		[[undo prepareWithInvocationTarget:self] addTracks:arr];
        NSMutableArray* deletedTracks = [browserData userDeletedTrackTimes];
		for (int i=0; i<num; i++)
		{
			Track* t = [arr objectAtIndex:i];
			NSUInteger index = [trackArray indexOfObjectIdenticalTo:t];
			if (index != NSNotFound)
			{
				if (![deletedTracks containsObject:[t creationTime]])
				{
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
	///NSMutableArray* trackArray = [browserData trackArray];
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
	NSMutableArray* trackArray = [browserData trackArray];
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
	NSMutableArray* trackArray = [browserData trackArray];
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
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
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
	TCX* tcx = [[TCX alloc] initWithFileURL:[NSURL fileURLWithPath:fileName]];
	NSMutableArray* importedTrackArray = [NSMutableArray array];
	NSMutableArray* importedLapArray = [NSMutableArray array];
	BOOL sts = [tcx import:importedTrackArray laps:importedLapArray];
	[tcx release];
	if (sts == YES)
	{
		NSArray* arr = [importedTrackArray sortedArrayUsingSelector:@selector(comparator:)];
		//NSMutableArray* trackArray = [browserData trackArray];
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
		//NSMutableArray* trackArray = [browserData trackArray];
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
		NSMutableArray* trackArray = [browserData trackArray];
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
		//NSMutableArray* trackArray = [browserData trackArray];
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
		//NSMutableArray* trackArray = [browserData trackArray];
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
   [gpxie exportTrack:track];
}


-(void) exportKMLFile:(Track*)track fileName:(NSString*)fileName
{
   NSLog(@"export KML: %@\n", fileName);
   KML* kmlie = [[[KML alloc] initKMLWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
   [kmlie exportTrack:track];
}


-(void) exportTCXFile:(NSArray*)tracks fileName:(NSString*)fileName
{
   NSLog(@"export TCX: %@\n", fileName);
   TCX* tcxie = [[[TCX alloc] initWithFileURL:[NSURL fileURLWithPath:fileName]] autorelease];
   [tcxie export:tracks];
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
	return [browserData numberOfSavesSinceLocalBackup];
}


-(int)numberOfSavesSinceMobileMeBackup
{
	return [browserData numberOfSavesSinceMobileMeBackup];
}


-(void)setNumberOfSavesSinceLocalBackup:(int)n
{
	[browserData setNumberOfSavesSinceLocalBackup:n];
}


-(void)setNumberOfSavesSinceMobileMeBackup:(int)n
{
	[browserData setNumberOfSavesSinceMobileMeBackup:n];
}


-(BOOL)usesEquipmentLog
{
	int flags = [browserData flags];
	return FLAG_IS_SET(flags, kUsesEquipmentLog);
}

-(void)setUsesEquipmentLog:(BOOL)uses
{
	int savedFlags = [browserData flags];
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
		[browserData setFlags:temp];
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
	[browserData setInitialEquipmentLogData:eld];
	[self updateChangeCount:NSChangeDone];
}


-(NSMutableDictionary*)initialEquipmentLogData
{
	return [browserData initialEquipmentLogData];
}



-(void)setDocumentDateRange:(NSArray*)datesArray;
{
	[browserData setStartEndDateArray:datesArray];
	[self updateChangeCount:NSChangeDone];
}

-(NSArray*)documentDateRange
{
	return [browserData startEndDateArray];
}


@end
