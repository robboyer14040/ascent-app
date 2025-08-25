//
//  SyncController.mm
//  Ascent
//
//  Created by Rob Boyer on 7/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "SyncController.h"
#import "Defs.h"
#import "AscentClientProxy.h"
#import <JSON/JSON.h>
#import "TrackBrowserDocument.h"
#import "Track.h"
#import "TrackPoint.h"
#import "AppController.h"
#import "Utils.h"


#define kAscentProtocolID		@"ascent"
#define kMagic					0xABCD1234

@interface SyncController ()

@end

@implementation SyncController

-(id)initWithAppController:(AppController*)ac
{
	if (self = [super init])
	{
		appController = [ac retain];
		document = nil;
		tracksWithDataOnMobileDevice = nil;
		tracksWithoutDataOnMobileDevice = nil;
		remoteUUIDDict = nil;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(prefChange:)
													 name:@"PreferencesChanged"
												   object:nil];
	}
	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[remoteUUIDDict release];
	[tracksWithDataOnMobileDevice release];
	[tracksWithoutDataOnMobileDevice release];
	[document release];
	[appController release];
	[clientProxy release];
	[server release];
	[super dealloc];
}


- (void)prefChange:(NSNotification *)notification
{
	BOOL wifiEnabled = [Utils boolFromDefaults:RCBDefaultEnableWiFiSync];
	if (!server && wifiEnabled)
	{
		[self startAdvertising];
	}
	else if (server && !wifiEnabled)
	{
		[self stopAdvertising];
	}
}


-(void)setDocument:(TrackBrowserDocument*)tbd
{
	if (tbd != document)
	{
		[document release];
		document = [tbd retain];
	}
}


-(void)startAdvertising
{
	if (server == nil)
	{
		///----------------------------
		NSString* hostName = [[NSProcessInfo processInfo] hostName];
		NSRange range;
		range.location = [hostName length] - 6;
		range.length = 6;
		NSString* suffix = [hostName substringWithRange:range];
		if ([suffix isEqualToString:@".local"])
		{
			range.length = range.location; 
			range.location = 0;
			hostName = [hostName substringWithRange:range];
		}
		
		server = [[AscentServer alloc] initWithName:[NSString stringWithFormat:@"Ascent on %@", hostName] port:0];
	}
	[server setDelegate:self];
	if(server == nil) 
	{
		//[self _showAlertWithTitle:@"Failed creating server" message:@"Check your networking configuration."];
		return;
	}
	//Start looking for clients
	if(![server startAdvertisingToClientsWithIdentifier:kAscentProtocolID]) 
	{
		//[self _showAlertWithTitle:@"Failed advertising server" message:@"Check your networking configuration."];
		return;
	}
}


-(void)stopAdvertising
{
	[server release];
	server = nil;
}



//----- AscentServer delegate methods ------------------------------------------

- (void) ascentServerDidStartAdvertisingToClients:(AscentServer*)server
{
}


- (void) ascentServerWillStopAdvertisingToClients:(AscentServer*)server
{
}


- (BOOL) ascentServer:(AscentServer*)server shouldAllowConnectionToClient:(AscentClientProxy*)client
{
	return YES;
}


- (void) ascentServer:(AscentServer*)server didFailConnectingToClient:(AscentClientProxy*)client
{
}


- (void) ascentServer:(AscentServer*)theServer didConnectToClient:(AscentClientProxy*)client
{
	NSLog(@"connected to client!");
	//A previously started connection to a client completed successfully
	if(clientProxy == nil) 
	{
		clientProxy = [client retain];
		
		//Stop looking for clients
		[theServer stopAdvertisingToClients];
		
		//Show a user alert
		//alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Client \"%@\" Connected!", [client name]] message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
		//[alertView show];
		//[alertView release];
	}
}

// fixme: put these in central place
#define INFO_DATA_MSG			0
#define POINTS_DATA_MSG			1
#define SEND_TRACKS_REQ_MSG		2		
#define TRACK_ATTRIBUTES_MSG	3
#define TRACK_METRICS_MSG		4
#define UUIDS_OF_TRACKS			5
#define SYNC_START_MSG			4242
#define SYNC_END_MSG			4343

#define kTII_DateTime		@"DT"
#define	kTII_Name			@"Name"
#define	kTII_ActivityType	@"ActType"
#define kTII_Notes			@"Notes"
#define kTII_EventType		@"EType"
#define kTII_Effort			@"Eff"
#define kTII_Equipment		@"EQ"
#define kTII_Disposition	@"Disp"
#define kTII_Weather		@"Weath"
#define kTII_UserDefined1	@"U1"
#define kTII_UserDefined2	@"U2"
#define kTII_UserDefined3	@"U3"
#define kTII_UserDefined4	@"U4"


-(void)setTracksBeingSyncedArray:(NSMutableArray*)ma
{
	if (trackArrayBeingSynced != ma)
	{
		[trackArrayBeingSynced release];
		trackArrayBeingSynced = [ma retain];
	}
}

-(void)setTrackBeingSynced:(Track*)tr
{
	if (trackBeingSynced != tr)
	{
		[trackBeingSynced release];
		trackBeingSynced = [tr retain];
	}
}


-(void)getDocument
{
	NSWindow* w = [[NSApplication sharedApplication] mainWindow];
	NSWindowController* wc = [w windowController];
	TrackBrowserDocument* doc = [wc document];
	if (doc) [self setDocument:doc];
}


-(NSArray*)trackListForCurrentDocument
{
	NSArray* arr = nil;
	if (document)
	{
		arr = [document trackArray];
	}
	return arr;
}


- (NSData*) dataFromDictionary:(NSDictionary*)dictionary
{
	NSMutableData*				data = [NSMutableData data];
	int							magic = NSSwapHostIntToBig(kMagic);
	
	[data appendBytes:&magic length:sizeof(int)];
	[data appendData:[NSPropertyListSerialization dataFromPropertyList:dictionary 
																format:NSPropertyListBinaryFormat_v1_0 
													  errorDescription:NULL]];
	return data;
}


- (NSData*) dataFromArray:(NSArray*)array
{
	NSMutableData*				data = [NSMutableData data];
	int							magic = NSSwapHostIntToBig(kMagic);
	
	[data appendBytes:&magic length:sizeof(int)];
	[data appendData:[NSPropertyListSerialization dataFromPropertyList:array 
																format:NSPropertyListBinaryFormat_v1_0 
													  errorDescription:NULL]];
	return data;
}


-(NSDictionary*) attributeDictForTrack:(Track*)track
{
	NSArray* arr = [track attributes];
	NSMutableDictionary* attrDict = [NSMutableDictionary dictionaryWithCapacity:32];
    NSUInteger num = [arr count];
	[attrDict setObject:[track uuid]
				 forKey:@"uuid"];
	
	
	NSString* name = [track attribute:kName];
	if ([name isEqualToString:@""])
	{
		name = [track name];
	}
	
	[attrDict setObject:name
				 forKey:@"Name"];
	if (kActivity < num)[attrDict setObject:[arr objectAtIndex:kActivity]
									 forKey:@"ActType"];
	if (kNotes < num)[attrDict setObject:[arr objectAtIndex:kNotes]
								  forKey:@"Notes"];
	if (kEquipment < num)[attrDict setObject:[arr objectAtIndex:kEquipment]
									  forKey:@"EQ"];
	if (kEffort < num)[attrDict setObject:[arr objectAtIndex:kEffort]
								   forKey:@"Eff"];
	if (kEventType < num)[attrDict setObject:[arr objectAtIndex:kEventType]
									  forKey:@"EType"];
	if (kWeather < num)[attrDict setObject:[arr objectAtIndex:kWeather]
									forKey:@"Weath"];
	if (kDisposition < num)[attrDict setObject:[arr objectAtIndex:kDisposition]
										forKey:@"Disp"];
	if (kKeyword1 < num)[attrDict setObject:[arr objectAtIndex:kKeyword1]
									 forKey:@"U1"];
	if (kKeyword2 < num)[attrDict setObject:[arr objectAtIndex:kKeyword2]
									 forKey:@"U2"];
	if (kKeyword3 < num)[attrDict setObject:[arr objectAtIndex:kKeyword3]
									 forKey:@"U3"];
	if (kKeyword4 < num)[attrDict setObject:[arr objectAtIndex:kKeyword4]
									 forKey:@"U4"];
	return attrDict;
}


// convert mph to meters/sec
static float convertSpeedToMobile(float mph)
{
	return MilesToKilometers(mph)*1000.0/(60.0*60.0);
}


static float convertAltitudeToMobile(float ft)
{
	return FeetToMeters(ft);
}


static float convertDistanceToMobile(float miles)
{
	return MilesToKilometers(miles)*1000.0;
}


-(NSDictionary*) metricDictForTrack:(Track*)track
{
	NSMutableDictionary* metricDict = [NSMutableDictionary dictionaryWithCapacity:32];
	[metricDict setObject:[NSNumber numberWithFloat:[track duration]]
				   forKey:@"wallClockDuration"];
	[metricDict setObject:[NSNumber numberWithFloat:[track movingDuration]]
				   forKey:@"movingDuration"];
	[metricDict setObject:[track creationTime]
				   forKey:@"startTime"];
	tLatLonBounds bounds = [track getLatLonBounds];
	[metricDict setObject:[NSNumber numberWithFloat:bounds.minLat]
				   forKey:@"minLatitude"];
	[metricDict setObject:[NSNumber numberWithFloat:bounds.minLon]
				   forKey:@"minLongitude"];
	[metricDict setObject:[NSNumber numberWithFloat:bounds.maxLat]
				   forKey:@"maxLatitude"];
	[metricDict setObject:[NSNumber numberWithFloat:bounds.maxLon]
				   forKey:@"maxLongitude"];
	[metricDict setObject:[NSNumber numberWithFloat:convertDistanceToMobile([track distance])]
				   forKey:@"distance"];
	[metricDict setObject:[track uuid]
				   forKey:@"uuid"];
	//set in attributeDict [metricDict setObject:[track name]
	//set in attributeDict			   forKey:@"name"];
	[metricDict setObject:[NSNumber numberWithFloat:[track weight]]
				   forKey:@"weight"];
	[metricDict setObject:[NSNumber numberWithFloat:convertSpeedToMobile([track avgSpeed])]	
				   forKey:@"avgSpeed"];
	[metricDict setObject:[NSNumber numberWithFloat:convertSpeedToMobile([track avgMovingSpeed])]
				   forKey:@"avgMovingSpeed"];
	[metricDict setObject:[NSNumber numberWithFloat:convertSpeedToMobile([track maxSpeed])]
				   forKey:@"maxSpeed"];
	[metricDict setObject:[NSNumber numberWithFloat:convertAltitudeToMobile([track totalClimb])]
				   forKey:@"climb"];
	[metricDict setObject:[NSNumber numberWithFloat:convertAltitudeToMobile([track totalDescent])]
				   forKey:@"descent"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxTemperature:nil]]
				   forKey:@"maxTemperature"];
	[metricDict setObject:[NSNumber numberWithFloat:[track minTemperature:nil]]
				   forKey:@"minTemperature"];
	[metricDict setObject:[NSNumber numberWithFloat:[track avgTemperature]]
				   forKey:@"avgTemperature"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxAltitude:nil]]
				   forKey:@"maxAltitude"];
	[metricDict setObject:[NSNumber numberWithFloat:convertAltitudeToMobile([track minAltitude:nil])]
				   forKey:@"minAltitude"];
	[metricDict setObject:[NSNumber numberWithFloat:convertAltitudeToMobile([track avgAltitude])]
				   forKey:@"avgAltitude"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxGradient:nil]]
				   forKey:@"maxGradient"];
	[metricDict setObject:[NSNumber numberWithFloat:[track minGradient:nil]]
				   forKey:@"minGradient"];
	[metricDict setObject:[NSNumber numberWithFloat:[track avgGradient]]
				   forKey:@"avgGradient"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxCadence:nil]]
				   forKey:@"maxCadence"];
	[metricDict setObject:[NSNumber numberWithFloat:[track avgCadence]]
				   forKey:@"avgCadence"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxHeartrate:nil]]
				   forKey:@"maxHeartrate"];
	[metricDict setObject:[NSNumber numberWithFloat:[track minHeartrate:nil]]
				   forKey:@"minHeartrate"];
	[metricDict setObject:[NSNumber numberWithFloat:[track avgHeartrate]]
				   forKey:@"avgHeartrate"];
	[metricDict setObject:[NSNumber numberWithFloat:[track avgPower]]
				   forKey:@"avgPower"];
	[metricDict setObject:[NSNumber numberWithFloat:[track maxPower:nil]]
				   forKey:@"maxPower"];
	[metricDict setObject:[NSNumber numberWithFloat:[track calories]]
				   forKey:@"calories"];
	return metricDict;
}	


-(void)sendDict:(NSDictionary*)dict forCommand:(UInt32)icmd toClient:(AscentClientProxy*)client
{
	UInt32 cmd = NSSwapHostIntToBig(icmd);
	NSData* infoData = [self dataFromDictionary:dict];
    NSUInteger length = (NSUInteger)sizeof(UInt32) + [infoData length];
	NSMutableData* mdata = [NSMutableData dataWithLength:length];
	NSRange range;
	range.length = sizeof(UInt32);
	range.location = 0;
	[mdata replaceBytesInRange:range
					 withBytes:(const void *)&cmd];
	range.location = sizeof(UInt32);
	range.length = [infoData length];
	[mdata replaceBytesInRange:range
					 withBytes:[infoData bytes]];
	[server sendData:mdata
			toClient:client];
}

-(void)sendAttributeDictForTrack:(Track*)track toClient:(AscentClientProxy*)client
{
	[self sendDict:[self attributeDictForTrack:track]
		forCommand:TRACK_ATTRIBUTES_MSG
		  toClient:client];
}


-(void)sendMetricsForTrack:(Track*)track toClient:(AscentClientProxy*)client
{
	// send as a dictionary, with keys set to method names on AscentMobile track object
	[self sendDict:[self metricDictForTrack:track]
		forCommand:TRACK_METRICS_MSG
		  toClient:client];
}



-(NSArray*) arrayifyPoint:(TrackPoint*)pt
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:10];
	[arr addObject:[NSNumber numberWithFloat:[pt wallClockDelta]]];
	[arr addObject:[NSNumber numberWithDouble:[pt latitude]]];
	[arr addObject:[NSNumber numberWithDouble:[pt longitude]]];
	[arr addObject:[NSNumber numberWithFloat:FeetToMeters([pt origAltitude])]];
	[arr addObject:[NSNumber numberWithFloat:[pt heartrate]]];
	[arr addObject:[NSNumber numberWithFloat:[pt cadence]]];
	[arr addObject:[NSNumber numberWithFloat:MilesToKilometers([pt speed])*1000.0/(3600.0)]];
	[arr addObject:[NSNumber numberWithFloat:[pt temperature]]];
	float dist = MilesToKilometers([pt distance])*1000.0;
	[arr addObject:[NSNumber numberWithFloat:dist]];
	//[arr addObject:[NSNumber numberWithFloat:[pt speed]]];
	//[arr addObject:[NSNumber numberWithFloat:[pt gradient]]];
	return arr;
}


-(NSDictionary*) makeTrackPointData:(Track*)track
{
	NSArray* pts = [track goodPoints];
    NSUInteger num = [pts count];
	float factor = 1.0;
	if (num > 1000)
	{
		factor = ((float)num)/1000;
	}
	//printf("%d records to write\n", num);
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:num];
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:4];
	[dict setObject:@"1.0"
			 forKey:@"version"];
	//[dict setObject:[track uuid]
	//		 forKey:@"guid"];
	//[dict setObject:userDBID
	//		 forKey:@"userid"];
	float fidx = 0.0;
	float fnum = (float)num;
	while (fidx < fnum)
	{
		int i = (int)roundf(fidx);
		if (i < num)
		{
			TrackPoint* pt = [pts objectAtIndex:i];
			if ([pt validLatLon])
			{
				[arr addObject:[self arrayifyPoint:pt]];	// uses less storage than dict, but need to be careful about versioning!
			}
		}
		fidx += factor;
	}
	[dict setObject:arr
			 forKey:@"points"];
	return dict;
}



-(NSString*)pointDataAsJSONforTrack:(Track*)track
{
	NSDictionary* dataDict = [self makeTrackPointData:track];
	NSString* js = [dataDict JSONRepresentation];
    NSUInteger len = [js length];
	NSLog(@"json string is length:%d", (int)len);
	return js;
}



-(void)sendPointsForTrack:(Track*)track toClient:(AscentClientProxy*)client
{
	UInt32 cmd = NSSwapHostIntToBig(POINTS_DATA_MSG);
	NSString* s = [self pointDataAsJSONforTrack:track];
    NSUInteger length = sizeof(UInt32) + [s length];
	NSMutableData* mdata = [NSMutableData dataWithLength:length];
	NSRange range;
	range.length = sizeof(UInt32);
	range.location = 0;
	[mdata replaceBytesInRange:range
					 withBytes:(const void *)&cmd];
	range.length = [s length];
	range.location = sizeof(UInt32);
	const char * cs = [s cStringUsingEncoding:NSASCIIStringEncoding];
	[mdata replaceBytesInRange:range
					 withBytes:cs];
	[server sendData:mdata
			toClient:client];
}


-(BOOL)shouldSyncPointsForTrack:(Track*)track
{
	if ([track uploadToMobile])
	{
		return YES;
	}
	else
	{
		NSDate* trackStart = [track creationTime];
		NSDate* now = [NSDate date];
		int numMonths = [Utils intFromDefaults:RCBDefaultNumWeeksOrMonthsToSync];
		if (numMonths < 1) numMonths = 1;
		NSTimeInterval adjSecs = numMonths*4.0*7.0*24.0*60.0*60.0;
		NSDate* earliestDate = [now dateByAddingTimeInterval:-adjSecs];
		return ([trackStart compare:earliestDate] != NSOrderedAscending);
	}
}


-(void)sendTracksToClient:(AscentClientProxy*) client
{
	NSArray* arr = [self trackListForCurrentDocument];
	if (arr)
	{
		NSArray* sortedList = [arr sortedArrayUsingSelector:@selector(compareByDate:)];
        NSUInteger count = [sortedList count];
		for (int i=0; i<count; i++)
		{
			Track* track = [sortedList objectAtIndex:count - (i+1)];
			NSString* uuid = [track uuid];
			NSNumber* hasPoints = [remoteUUIDDict objectForKey:uuid];
			BOOL passesCriteriaToSendPoints = [self shouldSyncPointsForTrack:track];
			if ((hasPoints == nil) || 
				(passesCriteriaToSendPoints && ![hasPoints boolValue]))	// track not yet on remote device, or points aren't
			{
				NSLog(@"sending track header %d", i);
				[self sendAttributeDictForTrack:track
									   toClient:client];
				if (passesCriteriaToSendPoints)
				{
					NSLog(@"====> sending POINTS for track %d", i);
					[self sendPointsForTrack:track
									toClient:client];
				}
				[self sendMetricsForTrack:track
								 toClient:client];
			}
		}
	}
}


-(void)sendTracks:(id)notUsed
{
	[self getDocument];
	//NSWindow* w = [NSApp mainWindow];
	if (document)
	{
		if ([self trackListForCurrentDocument])
		{
			[self sendTracksToClient:clientProxy];
		}
	}
	UInt32 cmd = NSSwapHostIntToBig(SYNC_END_MSG);
	NSData* data = [NSData dataWithBytes:(const void*)&cmd 
								  length:sizeof(UInt32)];
	[server sendData:data 
			toClient:clientProxy];
	[document addTracks:trackArrayBeingSynced];
	
	[self setTracksBeingSyncedArray:nil];
	[self setTrackBeingSynced:nil];
}


-(Track*)findTrackUsingUID:(NSString*)uid
{
	NSArray* tracks = [self trackListForCurrentDocument];
    NSUInteger num = [tracks count];
	for (int i=0; i<num; i++)
	{
		Track* track = [tracks objectAtIndex:i];
		if ([[track uuid] isEqualToString:uid]) return track;
	}
	return nil;
}


-(void)setTracksWithDataOnMobileDevice:(NSArray*)arr
{
	if (arr != tracksWithDataOnMobileDevice)
	{
		[tracksWithDataOnMobileDevice release];
		tracksWithDataOnMobileDevice = [arr retain];
	}
}

-(void)setTracksWithoutDataOnMobileDevice:(NSArray*)arr
{
	if (arr != tracksWithoutDataOnMobileDevice)
	{
		[tracksWithoutDataOnMobileDevice release];
		tracksWithoutDataOnMobileDevice = [arr retain];
	}
}

-(void)setRemoteUUIDDict:(NSMutableDictionary*)dict
{
	if (dict != remoteUUIDDict)
	{
		[remoteUUIDDict release];
		remoteUUIDDict = [dict retain];
	}
}


-(Track*)trackWithUUID:(NSString*)uuid
{
	NSArray* trackList = [self trackListForCurrentDocument];
    NSUInteger num = [trackList count];
	for (int i=0; i<num; i++)
	{
		Track* track = [trackList objectAtIndex:i];
		if ([[track uuid] isEqualToString:uuid])
		{
			return track;
		}
	}
	return nil;
}


-(void)loadRemoteUUIDDict
{
	[self setRemoteUUIDDict:[NSMutableDictionary dictionaryWithCapacity:32]];
	
	NSNumber* trueObj = [NSNumber numberWithBool:YES];
	NSNumber* falseObj = [NSNumber numberWithBool:NO];
    NSUInteger num = [tracksWithDataOnMobileDevice count];
	for (int i=0; i<num; i++)
	{
		NSString* uuid = [tracksWithDataOnMobileDevice objectAtIndex:i];
		[remoteUUIDDict setObject:trueObj
						   forKey:uuid];
	}
	
	num = [tracksWithoutDataOnMobileDevice count];
	for (int i=0; i<num; i++)
	{
		NSString* uuid = [tracksWithoutDataOnMobileDevice objectAtIndex:i];
		[remoteUUIDDict setObject:falseObj
						   forKey:uuid];
	}
	
}


-(void)processTrackUUIDListFromMobileDevice:(NSDictionary*)uuidDict client:(AscentClientProxy*)client
{
	[self setTracksWithDataOnMobileDevice:[uuidDict objectForKey:@"tracksWithData"]];
	[self setTracksWithoutDataOnMobileDevice:[uuidDict objectForKey:@"tracksWithoutData"]];
	[self loadRemoteUUIDDict];
    NSUInteger num = [tracksWithDataOnMobileDevice count];
	NSMutableArray* uuidsOfTracksToGetFromMobileDevice = [NSMutableArray arrayWithCapacity:32];
	for (int i=0; i<num; i++)
	{
		NSString* uuid = [tracksWithDataOnMobileDevice objectAtIndex:i];
		if ([self trackWithUUID:uuid]) continue;
		[uuidsOfTracksToGetFromMobileDevice addObject:uuid];
	}

	NSMutableDictionary* sendDict = [NSMutableDictionary dictionaryWithCapacity:[uuidsOfTracksToGetFromMobileDevice count]];
	[sendDict setObject:uuidsOfTracksToGetFromMobileDevice
				 forKey:@"tracksToSend"];
	
	[self sendDict:sendDict
		forCommand:UUIDS_OF_TRACKS
		  toClient:client];
	
}


- (void) ascentServer:(AscentServer*)iserver didReceiveData:(NSData*)data fromClient:(AscentClientProxy*)client
{
	UInt32 cmd;
	NSRange r;
	r.location = 0;
	r.length = sizeof(UInt32);
	[data getBytes:&cmd
			 range:r];
	cmd = NSSwapBigIntToHost(cmd);
	r.location = r.length;
	r.length = [data length] - sizeof(UInt32);
	NSLog(@"received data (%d bytes) from client, cmd:%d", (int)[data length], (unsigned int)cmd);
	switch (cmd)
	{
		case SYNC_START_MSG:
		{
			NSLog(@"SYNC_START_MSG received");
			[self setTracksBeingSyncedArray:[[[NSMutableArray alloc] initWithCapacity:4] autorelease]];
			NSData* subdata = [NSData dataWithBytesNoCopy:(char *)[data bytes] + sizeof(UInt32)
												   length:[data length] - sizeof(UInt32)
											 freeWhenDone:NO];
			NSDictionary* uuidDict = [clientProxy dictionaryFromData:subdata];
			[self processTrackUUIDListFromMobileDevice:uuidDict
												client:client];
			break;
		}
			
			
		case INFO_DATA_MSG:
		{
			NSLog(@"INFO_DATA_MSG received");
			NSData* subdata = [NSData dataWithBytesNoCopy:(char *)[data bytes] + sizeof(UInt32)
												   length:[data length] - sizeof(UInt32)
											 freeWhenDone:NO];
			NSDictionary* infoDict = [clientProxy dictionaryFromData:subdata];
			NSString* uid = [infoDict objectForKey:@"uuid"];
			if (uid && [self findTrackUsingUID:uid] == nil)
			{
				[self setTrackBeingSynced:[[[Track alloc] init] autorelease]];
				[trackBeingSynced setUuid:uid];
				[trackArrayBeingSynced addObject:trackBeingSynced];
				NSString* s = [infoDict objectForKey:kTII_DateTime];
				int interval = 0;
				if (s) interval = (int)atol([s cStringUsingEncoding:NSASCIIStringEncoding]);
				NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:(float)interval];
				[trackBeingSynced setCreationTime:date];
				[trackBeingSynced setAttribute:kName
								   usingString:[infoDict objectForKey:kTII_Name]];
				[trackBeingSynced setAttribute:kActivity
								   usingString:[infoDict objectForKey:kTII_ActivityType]];
				[trackBeingSynced setAttribute:kDisposition
								   usingString:[infoDict objectForKey:kTII_Disposition]];
				[trackBeingSynced setAttribute:kEffort
								   usingString:[infoDict objectForKey:kTII_Effort]];
				[trackBeingSynced setAttribute:kEventType
								   usingString:[infoDict objectForKey:kTII_EventType]];
				[trackBeingSynced setAttribute:kWeather
								   usingString:[infoDict objectForKey:kTII_Weather]];
				[trackBeingSynced setAttribute:kEquipment
								   usingString:[infoDict objectForKey:kTII_Equipment]];
				[trackBeingSynced setUseOrigDistance:NO];	// there is no orig distance
			}
			else
			{
				[self setTrackBeingSynced:nil];
			}
			break;
		}
			
		case POINTS_DATA_MSG:
		{
			NSLog(@"POINTS_DATA_MSG received");
			if (trackBeingSynced)
			{
				NSData* jdata = [data subdataWithRange:r];
				NSString* js = [[[NSString alloc] initWithData:jdata
													 encoding:NSASCIIStringEncoding] autorelease];
				NSDictionary* pointsDict = [js JSONValue];
				NSArray* pointsArr = [pointsDict objectForKey:@"points"];
                NSUInteger num = [pointsArr count];
				NSMutableArray* trackPointArray = [trackBeingSynced points];
				for (int i=0; i<num; i++)
				{
					NSArray* ptArr = [pointsArr objectAtIndex:i];
					float wallClockDelta = [[ptArr objectAtIndex:0] floatValue] ;
					TrackPoint* pt = [[[TrackPoint alloc] initWithGPSData:wallClockDelta
															  activeTime:wallClockDelta
																latitude:[[ptArr objectAtIndex:1] floatValue]
															   longitude:[[ptArr objectAtIndex:2] floatValue]
																altitude:MetersToFeet([[ptArr objectAtIndex:3] floatValue])
															   heartrate:[[ptArr objectAtIndex:4] floatValue]
																 cadence:[[ptArr objectAtIndex:5] floatValue]
															 temperature:[[ptArr objectAtIndex:6] floatValue]
																   speed:0.0 
																distance:0.0] autorelease];
					[trackPointArray addObject:pt];
				}
				[trackBeingSynced fixupTrack];
				[self setTrackBeingSynced:nil];
			}
			break;
		}
			
		case SEND_TRACKS_REQ_MSG:
		{
			NSLog(@"SEND_TRACKS_REQ_MSG received");
			///[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
			[self sendTracks:nil];
			break;
		}
	}
}
	


- (void) ascentServer:(AscentServer*)theServer didDisconnectFromClient:(AscentClientProxy*)client
{
	NSLog(@"disconnected from client!");
	//Show a user alert
	if(client == clientProxy) 
	{
		//alertView = [[UIAlertView alloc] initWithTitle:@"Client Disconnected!" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
		//[alertView show];
		//[alertView release];
		
		[clientProxy release];
		clientProxy = nil;
		
		//Start looking for clients again
		[theServer startAdvertisingToClientsWithIdentifier:kAscentProtocolID];
		//if(![server startAdvertisingToClientsWithIdentifier:kGameIdentifier])
		//    [self _showAlertWithTitle:@"Failed advertising server" message:@"Check your networking configuration."];
	}
}

@end
