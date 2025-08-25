//
//  DBComm.mm
//  Ascent
//
//  Created by Rob Boyer on 2/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "DBComm.h"
#import <JSON/JSON.h>
#import "Track.h"
#import "TrackPoint.h"
#include <curl/curl.h>

//#define HOST_ALIAS		"https://ascent.c7.ixwebhosting.com"
#define HOST_ALIAS			"http://localhost"
#define HTTP_PW				"ascentUsers:completely369"
#define DEBUG_ONLY_PHP_ARG  "?XDEBUG_SESSION_START=1"
#define DEBUG_2ND_PHP_ARG	"&XDEBUG_SESSION_START=1"


@interface DBComm(Private)
-(NSString*) putData:(NSString*)method data:(NSData*)dataToSend;
-(NSString*) getData:(NSString*)method userName:(NSString*)name password:(NSString*)pw;
-(NSData*) createUserInfoXML:(NSString*)nm ident:(NSString*)ident password:(NSString*)pw birthdate:(NSDate*)bd maxhr:(float)mhr
					  regkey:(NSString*)rkey homelat:(double)lat homelon:(double)lon;
-(NSData*) createTrackInfoXML:(Track*)track;
-(NSDictionary*) makeTrackDict:(Track*)track;
-(NSArray*) arrayifyPoint:(TrackPoint*)pt;
-(NSDictionary*) dictifyPoint:(TrackPoint*)pt;
-(NSDictionary*) makeTrackPointData:(Track*)track;
@end


//---- callback world used by curl when reading and writing chunks of data during 
//---- PUTs, GETs, and POSTs

static int offset = 0;

size_t writeFunction( void *ptr,  size_t  size,  size_t  nmemb,  void *dataObj)
{
	printf("write %d bytes\n", (int)(size*nmemb));
	NSMutableData* data = (NSMutableData*)dataObj;
	[data appendBytes:ptr
			   length:(size*nmemb)];
	return (size*nmemb);
}


size_t putFunction( void *ptr,  size_t  size,  size_t  nmemb,  void *dataObj)
{
	NSMutableData* data = (NSMutableData*)dataObj;
	const char* bytes = (const char*) [data bytes];
	int lenLeftToSend = [data length] - offset;
	int sizeToCopy = 0;
	if (lenLeftToSend > 0)
	{
		int bufSize = (size*nmemb);
		sizeToCopy = (lenLeftToSend <= bufSize) ? lenLeftToSend : bufSize;
		memcpy(ptr, &bytes[offset], sizeToCopy);
		offset += sizeToCopy;
	}
	printf("putting %d bytes\n", sizeToCopy);
	return (sizeToCopy);
}

//---- end of callback world


@implementation DBComm

-(id) init
{
	id me = [super init];
	if (me)
	{
		curl_global_init(CURL_GLOBAL_ALL);
		curlHandle  = curl_easy_init();
	}
	return me;
}


-(void)dealloc
{
	curl_easy_cleanup(curlHandle);
	[super dealloc];
}

- (NSString *)userDBID
{
	return userDBID;
}


- (void)setUserDBID:(NSString *)value
{
	if (value != userDBID)
	{
		[userDBID release];
		userDBID = [value retain];
	}
}


- (int) loginUser:(NSString*)name email:(NSString*)em password:(NSString*)pw;
{
	// issue HTTP "GET" operation to retrieve xml containing all user info
	NSString* response = [self getData:@"ascentDBUser"
							  userName:(NSString*)name
							  password:(NSString*)pw];
	NSLog(@"%@", response);
	
	NSError* err;
	NSXMLDocument* xmldoc = [[[NSXMLDocument alloc] initWithXMLString:response
															 options:NSXMLDocumentTidyXML
															   error:&err] autorelease];
	
	if (xmldoc)
	{
		NSArray* arr = [xmldoc nodesForXPath:@"//body/uid" 
									   error:&err];
		if ([arr count] > 0)
		{
			NSXMLElement* ele = [arr objectAtIndex:0];
			NSString* uid = [ele stringValue];
			NSLog(@"login confirmed: %@",uid);
			[self setUserDBID:uid];
		}
	}
	return 1;			// fixme!
}


-(NSData*) createUserInfoXML:(NSString*)nm ident:(NSString*)ident password:(NSString*)pw birthdate:(NSDate*)bd maxhr:(float)mhr
						regkey:(NSString*)rkey homelat:(double)lat homelon:(double)lon
{
	NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"ascentUser"];
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithRootElement:root] autorelease];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	NSXMLElement* ele = [NSXMLNode elementWithName:@"uname"
									   stringValue:nm];
	[root addChild:ele];
	
	ele = [NSXMLNode elementWithName:@"ident"
						 stringValue:ident];
	[root addChild:ele];
	
	ele = [NSXMLNode elementWithName:@"pw"
						 stringValue:pw];
	[root addChild:ele];
	
    NSMutableString* s = [NSMutableString stringWithString:@"%Y-%m-%d"];
	NSString* dt = [bd descriptionWithCalendarFormat:s
											  timeZone:nil 
												locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	ele = [NSXMLNode elementWithName:@"birthdate"
						 stringValue:dt];
	[root addChild:ele];

	ele = [NSXMLNode elementWithName:@"maxhr"
						 stringValue:[NSString stringWithFormat:@"%0.2f", mhr]];
	[root addChild:ele];
	
	ele = [NSXMLNode elementWithName:@"homelat"
						 stringValue:[NSString stringWithFormat:@"%0.8f", lat]];
	[root addChild:ele];
	ele = [NSXMLNode elementWithName:@"homelon"
						 stringValue:[NSString stringWithFormat:@"%0.8f", lon]];
	[root addChild:ele];
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];

	return xmlData;
}


- (int) createUser:(NSString*)name ident:(NSString*)ident password:(NSString*)pw birthdate:(NSDate*)bd maxhr:(float)mhr
			regkey:(NSString*)rkey homelat:(double)lat homelon:(double)lon
{
	// issue HTTP "PUT" operation to create user, with xml in http body containing user info
	NSData* dataToSend = [self createUserInfoXML:name
										   ident:ident
										password:pw
									   birthdate:bd
										   maxhr:mhr
										  regkey:rkey
										 homelat:lat
										 homelon:lon];
	NSString* response = [self putData:@"ascentDBUser"
								  data:dataToSend];
	NSLog(@"%@", response);
	return 0;
}


- (int) publishTrackPoints:(Track*)track
{
	// track points are sent as an array within a dict object.  The dict also contains
	// header information (version#, track id, user id)
	NSDictionary* dataDict = [self makeTrackPointData:track];
	NSString* js = [dataDict JSONRepresentation];
	NSString* response = [self putData:@"ascentDBActivityPoints"
								  data:[NSData dataWithBytes:[js UTF8String] 
													  length:[js length]]];
	NSLog(@"%@", response);
	return 0;
}


- (int) publishTracks:(NSArray*)tracks
{
	int num = [tracks count];
	for (int i=0; i<num; i++)
	{
		Track* track = [tracks objectAtIndex:i];
		NSString* response = [self putData:@"ascentDBActivity"
									  data:[self createTrackInfoXML:track]];
		NSLog(@"%@", response);
		[self publishTrackPoints:track];
	}
	return 0;
}



-(NSString*) putData:(NSString*)method data:(NSData*)dataToSend
{
#if 0
	NSString* url = [NSString stringWithFormat:@"%s/adb/activity", HOST_ALIAS ];	
#else
	NSString* url = [NSString stringWithFormat:@"%s/db/%@.php%s", HOST_ALIAS, method, DEBUG_ONLY_PHP_ARG];	
#endif
	url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	curl_easy_setopt(curlHandle, CURLOPT_URL, [url UTF8String]);
	curl_easy_setopt(curlHandle, CURLOPT_UPLOAD, 1);	
	curl_easy_setopt(curlHandle, CURLOPT_INFILESIZE, [dataToSend length]);		
	curl_easy_setopt(curlHandle, CURLOPT_READFUNCTION, putFunction);			
	curl_easy_setopt(curlHandle, CURLOPT_READDATA, dataToSend);			
	offset = 0;
	curl_easy_setopt(curlHandle, CURLOPT_VERBOSE, 1);
	curl_easy_setopt(curlHandle, CURLOPT_SSL_VERIFYPEER, 0);
	curl_easy_setopt(curlHandle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
	curl_easy_setopt(curlHandle, CURLOPT_USERPWD, HTTP_PW);
	NSMutableData* rdata = [NSMutableData dataWithCapacity:1024];
	curl_easy_setopt(curlHandle, CURLOPT_WRITEDATA, rdata);
	curl_easy_setopt(curlHandle, CURLOPT_WRITEFUNCTION, writeFunction);
	/*CURLcode success = */ curl_easy_perform(curlHandle);
	curl_easy_reset(curlHandle);
	[rdata appendBytes:"\0"
				length:1];
	return [NSString stringWithUTF8String:(const char*)[rdata bytes]];
}


-(NSString*) getData:(NSString*)method userName:(NSString*)name password:(NSString*)pw
{
#if 0
	NSString* url = [NSString stringWithFormat:@"%s/adb/user/%@:%@", HOST_ALIAS, name, pw];
#else
	NSString* url;
	if (name != nil)
	{
		 url = [NSString stringWithFormat:@"%s/db/%@.php?userinfo=%@:%@%s", HOST_ALIAS, method, name, pw, DEBUG_2ND_PHP_ARG];
	}
	else
	{
		 url = [NSString stringWithFormat:@"%s/db/%@.php%s", HOST_ALIAS, method, DEBUG_ONLY_PHP_ARG];
	}
#endif	
	url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	curl_easy_setopt(curlHandle, CURLOPT_URL, [url UTF8String]);
	curl_easy_setopt(curlHandle, CURLOPT_HTTPGET, 1);
	curl_easy_setopt(curlHandle, CURLOPT_VERBOSE, 1);
	curl_easy_setopt(curlHandle, CURLOPT_SSL_VERIFYPEER, 0);
	curl_easy_setopt(curlHandle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
	curl_easy_setopt(curlHandle, CURLOPT_USERPWD, HTTP_PW);
	NSMutableData* rdata = [NSMutableData dataWithCapacity:1024];
	curl_easy_setopt(curlHandle, CURLOPT_WRITEDATA, rdata);
	curl_easy_setopt(curlHandle, CURLOPT_WRITEFUNCTION, writeFunction);
	/*CURLcode success = */ curl_easy_perform(curlHandle);
	curl_easy_reset(curlHandle);
	[rdata appendBytes:"\0"
				length:1];
	const char* b = (const char*)[rdata bytes];
	return [NSString stringWithUTF8String:(const char*)b];
}	



-(NSData*) createTrackInfoXML:(Track*)track
{
	NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"ascentTrack"];
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithRootElement:root] autorelease];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	/**********/
	NSXMLElement* ele = [NSXMLNode elementWithName:@"activityGUID"
									   stringValue:[track uuid]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"userID"
						 stringValue:userDBID];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"name"
						 stringValue:[track attribute:kName]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"type"
						 stringValue:[track attribute:kActivity]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"equipment"
						 stringValue:[track attribute:kEquipment]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"deviceID"
						 stringValue:[[NSNumber numberWithInt:[track deviceID]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"disposition"
						 stringValue:[track attribute:kDisposition]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"effort"
						 stringValue:[track attribute:kEffort]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"eventType"
						 stringValue:[track attribute:kEventType]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"weather"
						 stringValue:[track attribute:kWeather]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"notes"
						 stringValue:[track attribute:kNotes]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"custom1"
						 stringValue:[track attribute:kKeyword1]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"custom2"
						 stringValue:[track attribute:kKeyword2]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"custom3"
						 stringValue:[track attribute:kKeyword3]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"custom4"
						 stringValue:[track attribute:kKeyword4]];
	[root addChild:ele];
	
	
	/**********/
	ele = [NSXMLNode elementWithName:@"date"
						 stringValue:[[track creationTime] description]];
	[root addChild:ele];
	
	/**********/
	ele = [NSXMLNode elementWithName:@"weight"
						 stringValue:[[NSNumber numberWithFloat:[track weight]] stringValue]];
	[root addChild:ele];

	/**********/
	ele = [NSXMLNode elementWithName:@"distance"
						 stringValue:[[NSNumber numberWithFloat:[track distance]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"duration"
						 stringValue:[[NSNumber numberWithFloat:[track duration]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"minLat"
						 stringValue:[[NSNumber numberWithFloat:[track minLatitude]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"minLon"
						 stringValue:[[NSNumber numberWithFloat:[track minLongitude]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"maxLat"
						 stringValue:[[NSNumber numberWithFloat:[track maxLatitude]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"maxLon"
						 stringValue:[[NSNumber numberWithFloat:[track maxLongitude]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"climb"
						 stringValue:[[NSNumber numberWithFloat:[track totalClimb]] stringValue]];
	[root addChild:ele];
	/**********/
	ele = [NSXMLNode elementWithName:@"descent"
						 stringValue:[[NSNumber numberWithFloat:[track totalDescent]] stringValue]];
	[root addChild:ele];
	
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	
	return xmlData;
}


-(NSDictionary*) makeTrackDict:(Track*)track
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:30];
	[dict setObject:[track uuid] forKey:@"guid"];
	[dict setObject:userDBID forKey:@"userID"];
	[dict setObject:[track attribute:kName] forKey:@"name"];
	[dict setObject:[track attribute:kActivity] forKey:@"atype"];
	[dict setObject:[track attribute:kDisposition] forKey:@"disposition"];
	[dict setObject:[track attribute:kEffort] forKey:@"effort"];
	[dict setObject:[track attribute:kEventType] forKey:@"eventtype"];
	[dict setObject:[track attribute:kWeather] forKey:@"weather"];
	NSString* s = [track attribute:kEquipment];
	[dict setObject:s forKey:@"equipment"];
	[dict setObject:[track attribute:kNotes] forKey:@"notes"];
	[dict setObject:[track attribute:kKeyword1] forKey:@"custom1"];
	[dict setObject:[track attribute:kKeyword2] forKey:@"custom2"];
	[dict setObject:[track attribute:kKeyword3] forKey:@"custom3"];
	[dict setObject:[track attribute:kKeyword4] forKey:@"custom4"];
	[dict setObject:[[track creationTime] description] forKey:@"datetime"];
	[dict setObject:[NSNumber numberWithFloat:[track distance]] forKey:@"distance"];
	[dict setObject:[NSNumber numberWithFloat:[track duration]] forKey:@"duration"];
	[dict setObject:[NSNumber numberWithInt:[track deviceID]] forKey:@"deviceID"];
	[dict setObject:[NSNumber numberWithDouble:[track minLatitude]] forKey:@"minLat"];
	[dict setObject:[NSNumber numberWithDouble:[track maxLatitude]] forKey:@"maxLat"];
	[dict setObject:[NSNumber numberWithDouble:[track minLongitude]] forKey:@"minLon"];
	[dict setObject:[NSNumber numberWithDouble:[track maxLongitude]] forKey:@"maxLon"];
	[dict setObject:[NSNumber numberWithFloat:[track totalClimb]] forKey:@"climb"];
	[dict setObject:[NSNumber numberWithFloat:[track totalDescent]] forKey:@"descent"];
	return dict;
}


-(NSDictionary*) dictifyPoint:(TrackPoint*)pt
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:10];
	[dict setObject:[NSNumber numberWithFloat:[pt activeTimeDelta]]
			 forKey:@"atd"];
	[dict setObject:[NSNumber numberWithDouble:[pt latitude]]
			 forKey:@"lat"];
	[dict setObject:[NSNumber numberWithDouble:[pt longitude]]
			 forKey:@"lon"];
	[dict setObject:[NSNumber numberWithFloat:[pt altitude]]
			 forKey:@"alt"];
	[dict setObject:[NSNumber numberWithFloat:[pt heartrate]]
			 forKey:@"hr"];
	[dict setObject:[NSNumber numberWithFloat:[pt cadence]]
			 forKey:@"cad"];
	[dict setObject:[NSNumber numberWithFloat:[pt temperature]]
			 forKey:@"tmp"];
	[dict setObject:[NSNumber numberWithFloat:[pt speed]]
			 forKey:@"spd"];
	[dict setObject:[NSNumber numberWithFloat:[pt gradient]]
			 forKey:@"grd"];
	return dict;
}


-(NSArray*) arrayifyPoint:(TrackPoint*)pt
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:10];
	[arr addObject:[NSNumber numberWithFloat:[pt activeTimeDelta]]];
	[arr addObject:[NSNumber numberWithDouble:[pt latitude]]];
	[arr addObject:[NSNumber numberWithDouble:[pt longitude]]];
	[arr addObject:[NSNumber numberWithFloat:[pt altitude]]];
	[arr addObject:[NSNumber numberWithFloat:[pt heartrate]]];
	[arr addObject:[NSNumber numberWithFloat:[pt cadence]]];
	[arr addObject:[NSNumber numberWithFloat:[pt temperature]]];
	[arr addObject:[NSNumber numberWithFloat:[pt speed]]];
	[arr addObject:[NSNumber numberWithFloat:[pt gradient]]];
	return arr;
}


-(NSDictionary*) makeTrackPointData:(Track*)track
{
	NSArray* pts = [track points];
	int num = [pts count];
	printf("%d records to write\n", num);
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:num];
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:4];
	[dict setObject:@"1.0"
			 forKey:@"version"];
	[dict setObject:[track uuid]
			 forKey:@"guid"];
	[dict setObject:userDBID
			 forKey:@"userid"];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		//[arr addObject:[self dictifyPoint:pt]];
		[arr addObject:[self arrayifyPoint:pt]];	// uses less storage than dict, but need to be careful about versioning!
	}
	[dict setObject:arr
			 forKey:@"points"];
	return dict;
}




@end
