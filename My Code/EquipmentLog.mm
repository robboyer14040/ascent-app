//
//  EquipmentLog.mm
//  Ascent
//
//  Created by Rob Boyer on 12/14/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentLog.h"
#import "EquipmentItem.h"
#import "EquipmentTrackInfo.h"
#import "MaintenanceLog.h"
#import "Track.h"
#import "TrackBrowserDocument.h"
#import "MainWindowController.h"
#import "ProgressBarController.h"
#import "Utils.h"


@interface EquipmentLog () 
-(id)fetchItemByValue:(NSString*)uid forKey:(NSString*)key inEntity:(NSString*)ent;
-(BOOL)presentError:(NSError*)err;
-(BOOL)checkEquipmentTypes;
-(void) updateEquipmentUUIDsForTrack:(Track*)t fromTrackInfo:(EquipmentTrackInfo*)eti;
@end


@implementation EquipmentLog

@synthesize defaultEquipmentType;
@synthesize defaultEquipmentImagePath;
@synthesize defaultEquipmentName;


-(id) init
{
	if (self = [super init])
	{
		NSError* error = nil;
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString *p = [NSMutableString stringWithString:[paths objectAtIndex:0]];
		p = [p stringByAppendingPathComponent:@"Ascent"];
		[Utils verifyDirAndCreateIfNecessary:p];
		p = [p stringByAppendingPathComponent:@"EquipmentLog"];
		NSURL *url = [NSURL fileURLWithPath:p];

		
		NSString* path = [[NSBundle mainBundle] pathForResource:@"EquipmentLog" 
														 ofType:@"mom"];
		NSURL *elURL = [NSURL fileURLWithPath:path];

		///NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
		///NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:bundles];
		NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:elURL] autorelease];
		NSPersistentStoreCoordinator *coordinator =
			[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
		[coordinator addPersistentStoreWithType:NSSQLiteStoreType 
								  configuration:nil 
											URL:url
										options:nil
										  error:&error];
		if (error)
		{
			moc = nil;
			[self presentError:error];
		}
		else
		{
			///AI moc = [[NSManagedObjectContext alloc] init];
            moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [moc setPersistentStoreCoordinator: coordinator];
		}
		[coordinator release];
	}
	return self;
}


-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


-(NSManagedObjectContext*)managedObjectContext
{
	return moc;
}


-(BOOL)presentError:(NSError*)err
{
	TrackBrowserDocument* tbd = (TrackBrowserDocument*)
		[[NSDocumentController sharedDocumentController] currentDocument];
	MainWindowController* wc = [tbd windowController];
	[wc presentError:err];
	return NO;
}


-(NSArray*)getEquipmentList
{
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"EquipmentItem" 
								   inManagedObjectContext:moc]];
	NSError* error = nil;
	NSArray* results = [moc executeFetchRequest:request
										  error:&error];
	if (error)
	{
		[self presentError:error];
	}
	return results;
}


-(NSManagedObject*)getEquipmentType:(NSString*)name
{
	return [self fetchObjectUsingStringValue:name
									  forKey:@"name" 
									  entity:@"EquipmentType"];
}


-(NSString*)bundleImageCopy:(NSString*)iconName
{
	NSString* path = [Utils imagePathFromBundleWithName:iconName];
	NSString *destPath = nil;
	if (path)
	{
		NSFileManager* fm = [NSFileManager defaultManager];
		destPath = [Utils applicationSupportPath];
		destPath = [destPath stringByAppendingPathComponent:@"Equipment Images"];
		[Utils verifyDirAndCreateIfNecessary:destPath];
		destPath = [destPath stringByAppendingPathComponent:iconName];
		destPath = [destPath stringByAppendingPathExtension:@"png"];
		if (![fm fileExistsAtPath:destPath])
		{
			NSError* error = nil;
			if (![fm copyItemAtPath:path 
							 toPath:destPath 
							  error:&error])
			{
				NSLog(@"file copy error, copying to %@, error:%@", destPath, error);
			}
		}
	}
	return destPath;
}



-(void)convertOldStyleTrack:(Track*)track isFirst:(BOOL*)isFirst
{
	// check if we've already created a TrackInfo object for this track,
	// if so, get out of here!
	EquipmentTrackInfo* trackInfo = [self fetchItemByValue:[track uuid]
													forKey:@"trackID"
												  inEntity:@"EquipmentTrackInfo"];
	if (!trackInfo)
	{
		// create a new trackinfo object for this track, and set attributes
		trackInfo = [NSEntityDescription insertNewObjectForEntityForName:@"EquipmentTrackInfo"
												  inManagedObjectContext:moc];
		[trackInfo setTrackID:[track uuid]];
		[trackInfo setDate:[track creationTime]];
        NSTimeInterval at = [track movingDuration];
		[trackInfo setActiveTime:[NSNumber numberWithFloat:(at > 0.0 ? at : 0.0)]];
        float d = [track distance];
		[trackInfo setDistance:[NSNumber numberWithFloat:d > 0.0 ? d : 0.0]];
		NSMutableSet* eis = [trackInfo mutableSetValueForKey:@"equipmentItems"];
		NSString* eqs = [track attribute:kEquipment];
		NSMutableArray* eqsArr = [NSMutableArray arrayWithArray:[eqs componentsSeparatedByString:@","]];
		[eqsArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
		for (NSString* e in eqsArr)
		{
			if (e && ![e isEqualToString:@""])
			{
				// look for existing equipment item with this name.
				// if not found, create new one...
				///e = [e kPowerDataCalculatedOrZeroedString];
				EquipmentItem* ei = [self fetchItemByValue:e
													forKey:@"name"
												  inEntity:@"EquipmentItem"];
				NSDate* trackDate = [track creationTime];
				if (!ei)
				{
					ei = [NSEntityDescription insertNewObjectForEntityForName:@"EquipmentItem"
													   inManagedObjectContext:moc];
					[ei setPrimitiveValue:e
								   forKey:@"name"];
					[ei setPrimitiveValue:trackDate
								   forKey:@"dateAcquired"];
					NSString* activity = [track attribute:kActivity];
					NSRange range = [activity rangeOfString:@"cycling"
													options:NSCaseInsensitiveSearch];
					if (range.location != NSNotFound)
					{
						NSString* pathToImage = [self bundleImageCopy:@"road bike"];
						
						[ei setPrimitiveValue:pathToImage
									   forKey:@"imagePath"];
						[ei setPrimitiveValue:[NSNumber numberWithFloat:22.0]
									   forKey:@"weight"];
						
						[ei setPrimitiveValue:[self getEquipmentType:@"road bike"]
									   forKey:@"type"];
					}
					else
					{
						range = [activity rangeOfString:@"mountain"
												options:NSCaseInsensitiveSearch];
						if (range.location != NSNotFound)
						{
							NSString* pathToImage = [self bundleImageCopy:@"mountain bike"];
							[ei setPrimitiveValue:pathToImage
										   forKey:@"imagePath"];
							[ei setPrimitiveValue:[NSNumber numberWithFloat:26.0]
										   forKey:@"weight"];
							[ei setPrimitiveValue:[self getEquipmentType:@"mountain bike"]
										   forKey:@"type"];
						}
						else
						{
							range = [activity rangeOfString:@"running"
													options:NSCaseInsensitiveSearch];
							if (range.location != NSNotFound)
							{
								NSString* pathToImage = [self bundleImageCopy:@"running shoes"];
								[ei setPrimitiveValue:pathToImage
											   forKey:@"imagePath"];
								[ei setPrimitiveValue:[self getEquipmentType:@"running shoes"]
											   forKey:@"type"];
							}
							else
							{
								range = [activity rangeOfString:@"walking"
														options:NSCaseInsensitiveSearch];
								if (range.location != NSNotFound)
								{
									NSString* pathToImage = [self bundleImageCopy:@"walking shoes"];
									[ei setPrimitiveValue:pathToImage
												   forKey:@"imagePath"];
									[ei setPrimitiveValue:[self getEquipmentType:@"walking shoes"]
												   forKey:@"type"];
								}
								else
								{
									[ei setPrimitiveValue:[self getEquipmentType:@"other"]
												   forKey:@"type"];
								}
							}
						}
					}
					// make the first equipment item created the "default"
					if (isFirst && *isFirst)
					{
						[ei setValue:[NSNumber numberWithBool:YES]
							  forKey:@"default"];
						*isFirst = NO;
					}
				}
				[eis addObject:ei];
				// if this track has an earlier time than the equipment item's
				// acquired date, update the acquired date.
				NSDate* acqTime = [ei valueForKey:@"dateAcquired"];
				if ([acqTime compare:trackDate] == NSOrderedDescending)
				{
					[ei setPrimitiveValue:trackDate
								   forKey:@"dateAcquired"];
				}
			}
		}
		[self updateEquipmentUUIDsForTrack:track 
							 fromTrackInfo:trackInfo];
		[track setEquipmentWeight:[self equipmentWeightForTrack:track]];
	}
}


-(void)applyEquipmentDefaultsToTrackInfo:(EquipmentTrackInfo*)trackInfo
{
	NSArray* el = [self getEquipmentList];
	if (el && trackInfo)
	{
		NSEnumerator* elEnum = [el objectEnumerator];
		while (EquipmentItem* ei = [elEnum nextObject])
		{
			BOOL isDefault = [[ei valueForKey:@"default"] boolValue];
			if (isDefault)
			{
				NSMutableSet *trackInfoSet = [ei mutableSetValueForKey:@"trackInfoSet"];
				[trackInfoSet addObject:trackInfo];
			}
			int flags = [[ei flags] intValue];
			if (FLAG_IS_SET(flags, kItemIsDefaultMain))
			{
				[trackInfo setValue:ei
							 forKey:@"mainEquipment"];
			}
		}
	}
}


-(void)setCurrentEquipmentItemsAsDefault:(TrackBrowserDocument*)tbDocument
{
	Track* track = [tbDocument currentlySelectedTrack];
	if (track)
	{
		EquipmentTrackInfo* trackInfo = [self fetchItemByValue:[track uuid]
														forKey:@"trackID"
													  inEntity:@"EquipmentTrackInfo"];
		NSArray* el = [self getEquipmentList];
		if (el && trackInfo)
		{
			NSSet* equipmentItems = [trackInfo equipmentItems];
			EquipmentItem* eimain = [trackInfo mainEquipment];
			for (EquipmentItem* ei in el)
			{
				BOOL used = [equipmentItems containsObject:ei];
				[ei setPrimitiveValue:[NSNumber numberWithBool:used]
							   forKey:@"default"];
				int flags = [[ei flags] intValue];
				if ([[eimain uniqueID] isEqualToString:[ei uniqueID]])
				{
					SET_FLAG(flags, kItemIsDefaultMain);
				}
				else
				{
					CLEAR_FLAG(flags, kItemIsDefaultMain);
				}
				[ei setFlags:[NSNumber numberWithInt:flags]];
			}
		}
	}
}


-(void)applyEquipmentUUIDListFromTrack:(Track*)track trackInfo:(EquipmentTrackInfo*)trackInfo
{
	NSArray* eqarr = [track equipmentUUIDs];
	if (eqarr && [eqarr count] > 0)
	{
		for (NSString* uid in eqarr)
		{
			EquipmentItem* ei = [self fetchObjectUsingStringValue:uid
														   forKey:@"uniqueID" 
														   entity:@"EquipmentItem"];
			[ei setUsesForTrack:track
				   equipmentLog:self
						   used:YES];
		}
		NSString* mid = track.mainEquipmentUUID;
		if (mid) 
		{
			EquipmentItem* ei = [self fetchObjectUsingStringValue:mid
														   forKey:@"uniqueID" 
														   entity:@"EquipmentItem"];
			if (ei) [trackInfo setMainEquipment:ei];
		}
	}
	else
	{
		// apply default equipment items to this track
		[self applyEquipmentDefaultsToTrackInfo:trackInfo];
		[self updateEquipmentUUIDsForTrack:track
							 fromTrackInfo:trackInfo];
	}
}


-(EquipmentTrackInfo*)insertNewTrack:(Track*)track
{
	EquipmentTrackInfo* trackInfo = nil;
	if ([track creationTime] != nil)
	{
		EquipmentTrackInfo* trackInfo = [NSEntityDescription insertNewObjectForEntityForName:@"EquipmentTrackInfo"
																	  inManagedObjectContext:moc];
		[trackInfo setTrackID:[track uuid]];
		// update fields in new or existing object with current track value
		[trackInfo setDate:[track creationTime]];
		[trackInfo setActiveTime:[NSNumber numberWithFloat:[track movingDuration]]];
		[trackInfo setDistance:[NSNumber numberWithFloat:[track distance]]];
		
		// new track may have been copied from an existing track and have an
		// equipment UUID list, if so make sure the database reflects this.
		// Otherwise, if no UUIDList, supply defaults.
		[self applyEquipmentUUIDListFromTrack:track
									trackInfo:trackInfo];
	}
	else
	{
		NSLog(@"Attempt to insert track with no creation date into database!");
	}
	return trackInfo;
}


-(void)trackAddedOrUpdated:(Track*)track
{
	NSArray* el = [self getEquipmentList];
	if (el)
	{
		//[self checkTrackEquipmentSet:track
		//		convertFromAttribute:YES];
		// get the EquipmentTrackInfo object for this track from the db (if it exists)
		// and subtrack the track's old time/distance values from the current equipment list totals.
		EquipmentTrackInfo* trackInfo = [self fetchItemByValue:[track uuid]
														forKey:@"trackID"
													  inEntity:@"EquipmentTrackInfo"];
		// if the EquipmentTrackInfo object exists, update it with new track values
		// else, create a new object.
		if (!trackInfo)
		{
			trackInfo = [self insertNewTrack:track];
		}
		else
		{
			// update fields in new or existing object with current track values
			[trackInfo setDate:[track creationTime]];
			[trackInfo setActiveTime:[NSNumber numberWithFloat:[track movingDuration]]];
			[trackInfo setDistance:[NSNumber numberWithFloat:[track distance]]];
			//NSMutableSet* eis = [trackInfo mutableSetValueForKey:@"equipmentItems"];
			//[eis setSet:[self buildEquipmentItemSetFromIDSet:[track equipmentItemIDList]]];
		}
		NSError* error = nil;
		[moc save:&error];
		if (error)
		{
			[self presentError:error];
		}
	}
}


-(void)trackDeleted:(Track*)track
{
	NSArray* el = [self getEquipmentList];
	if (el)
	{
		EquipmentTrackInfo* trackInfo = [self fetchItemByValue:[track uuid]
														forKey:@"trackID"
													  inEntity:@"EquipmentTrackInfo"];
		
		if (trackInfo)
		{
			[moc deleteObject:trackInfo]; 
			NSError* error = nil;
			[moc save:&error];
			if (error)
			{
				[self presentError:error];
			}
		}
	}
}


-(NSArray*)fetchBoolItemsByKey:(NSString*)key value:(BOOL)val entity:(NSString*)ent
{
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:ent
								   inManagedObjectContext:moc]];
	NSPredicate* pred = [NSPredicate predicateWithFormat:@"%K == %@", key, val ? @"YES" : @"NO"];
	[request setPredicate:pred];
	NSError* error = nil;
	NSArray* results = [moc executeFetchRequest:request
										  error:&error];
	if (error)
	{
		[self presentError:error];
	}
	return results;
}


-(id)fetchObjectUsingStringValue:(NSString*)val forKey:(NSString*)key entity:(NSString*)ent;
{
	EquipmentItem* ei = nil;
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:ent
								   inManagedObjectContext:moc]];
	NSPredicate* pred = [NSPredicate predicateWithFormat:@"%K like[cd] %@", key, val];
	[request setPredicate:pred];
	NSError* error = nil;
	NSArray* results = [moc executeFetchRequest:request
										  error:&error];
	if (error)
	{
		[self presentError:error];
	}
	else
	{
		if ([results count] > 0)
		{
			ei = [results lastObject];
		}
	}
	return ei;
}


-(id)fetchItemByValue:(NSString*)uid forKey:(NSString*)key inEntity:(NSString*)ent
{
	return [self fetchObjectUsingStringValue:uid
									  forKey:key
									  entity:ent];
}


struct EqTypeInfo
{
	NSString*	name;
	NSString*	imagePath;
	float		defaultWeight;
};

-(void)initEquipmentTypes
{
	static EqTypeInfo sEQTypes[] =
	{
		{ @"road bike",			@"road bike",		21.0 },
		{ @"mountain bike",		@"mountain bike",	26.0 },
		{ @"cyclocross bike",	@"cyclocross bike", 24.0 },
		{ @"running shoes",		@"running shoes",	0.0 },
		{ @"walking shoes",		@"walking shoes",	0.0 },
		{ @"skis",				@"skiis",			0.0 },
		{ @"bike shoes",		@"bike shoes",		0.0 },
		{ @"bike tires",		@"bike tires",		0.0 },
		{ @"bike wheels",		@"bike wheels",		0.0 },
		{ @"bike chain",		@"bike chain",		0.0 },
		{ @"kayak",				@"kayak",			0.0 },
		{ @"canoe",				@"canoe",			0.0 },
		{ @"other",				@"other equipment",	0.0 },
	};
	for (int i=0; i<sizeof(sEQTypes)/sizeof(EqTypeInfo); i++)
	{
		NSManagedObject* eqType = [NSEntityDescription insertNewObjectForEntityForName:@"EquipmentType"
																inManagedObjectContext:moc];
		[eqType setValue:[NSString stringWithString:sEQTypes[i].name]
				  forKey:@"name"];
		NSString* pathToImage = [self bundleImageCopy:sEQTypes[i].imagePath];
		[eqType setValue:pathToImage
				  forKey:@"imagePath"];
		[eqType setValue:[NSNumber numberWithFloat:sEQTypes[i].defaultWeight]
				  forKey:@"defaultWeight"];
	}
}
	

-(BOOL)checkEquipmentTypes
{
	BOOL created = NO;
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"EquipmentType"
								   inManagedObjectContext:moc]];
	NSError* error = nil;
	NSArray* results = [moc executeFetchRequest:request
										  error:&error];
	if (error)
	{
		[self presentError:error];
	}
	else
	{
		if (!results || [results count] == 0)
		{
			[self initEquipmentTypes];
			created = YES;
		}
	}
	return created;
}


-(NSPredicate*)maintFilterForDocument:(TrackBrowserDocument*)tbd
{
	NSDate* earliestDate = [NSDate distantPast];
	NSDate* latestDate = [NSDate distantFuture];
	NSArray* dateRangeArray = [tbd documentDateRange];
	if (dateRangeArray && [dateRangeArray count] > 1)
	{
		earliestDate = [dateRangeArray objectAtIndex:0];
		latestDate = [dateRangeArray objectAtIndex:1];
	}
	NSPredicate* pred = [NSPredicate predicateWithFormat:@"(date >= %@) AND (date <= %@)", earliestDate, latestDate];
	return pred;
}


-(NSManagedObject*)defaultEquipmentType
{
	[self checkEquipmentTypes];
	if (!defaultEquipmentType)
	{
		[self setDefaultEquipmentType:[self fetchObjectUsingStringValue:@"other"
																 forKey:@"name"
																 entity:@"EquipmentType"]];
	}
	return defaultEquipmentType;
}


-(void)incNumberAtIndex:(int)idx inArray:(NSMutableArray*)arr withValue:(float)val
{
	NSNumber* num = [arr objectAtIndex:idx];
	float v = [num floatValue] + val;
	[arr replaceObjectAtIndex:idx 
				   withObject:[NSNumber numberWithFloat:v]];
}


-(NSArray*)sortedMaintArrayForEquipmentItem:(EquipmentItem*)ei usingDocument:(TrackBrowserDocument*)tbd
{
	NSSet* maintenanceLogs = [ei maintenanceLogs];
    NSUInteger numLogs = [maintenanceLogs count];
	NSMutableArray* maintArr = [NSMutableArray arrayWithCapacity:(numLogs > 0 ? numLogs : 1)];
	if (numLogs > 0)
	{
		for (id anObject in maintenanceLogs)
		{
			[maintArr addObject:anObject];	
		}
		NSSortDescriptor* sd = [[[NSSortDescriptor alloc] initWithKey:@"date"
															ascending: NO] autorelease];
		[maintArr sortUsingDescriptors:[NSArray arrayWithObjects:sd, nil]];
	}
	[maintArr filterUsingPredicate:[self maintFilterForDocument:tbd]];
	return maintArr;
}	


-(void)updateDataDictionary:(NSMutableDictionary*)dataDict usingTrack:(Track*)t itemDict:(NSMutableDictionary*)uidToEQDict
{
	NSArray* eqUIDArr = [t equipmentUUIDs];
	for (NSString* eqUID in eqUIDArr)
	{
		EquipmentItem* ei = [[uidToEQDict objectForKey:eqUID] objectAtIndex:0];
		NSArray* maintArr = [[uidToEQDict objectForKey:eqUID] objectAtIndex:1];
		if (ei)
		{
			// Layout of data in array:
			// (n = #maint entries)
			// idx		use
			// -----------------------------------------------------------------
			//	0			total distance
			//	1			total time
			//  2			delta distance since most recent maintenance entry
			//  3			delta time since most recent maintenance entry
			//	4			delta distance since 2nd most recent maintenance entry and most recent
			//  5			delta time since 2nd most recent maintenance entry and most recent
			//  ..
			//	2 + (2n)	delta distance between last maint entry and beginning of time
			//	2 + (2n+1)	delta time between last maint entry and beginning of time
			//
			NSMutableArray* dataArr = [dataDict objectForKey:eqUID];
            NSUInteger arraySize = 4 + ([maintArr count] * 2);
			if (arraySize < 6) arraySize = 6;
			if (!dataArr || [dataArr count] < arraySize)
			{
				// array size is 2 (for overall totals) + 
				// 2 entries (dist, time) for each maintenance log entry
				dataArr = [NSMutableArray arrayWithCapacity:arraySize];
				for (int i=0; i<arraySize; i++)
					[dataArr addObject:[NSNumber numberWithFloat:0.0]];
				[dataDict setObject:dataArr
							 forKey:eqUID];
			}
			int idx = 0;
			[self incNumberAtIndex:idx++
						   inArray:dataArr
						 withValue:[t distance]];
			[self incNumberAtIndex:idx++
						   inArray:dataArr
						 withValue:[t movingDuration]];
			BOOL found = NO;
			for (MaintenanceLog* ml in maintArr)
			{
				NSDate* dt = [ml date];
				// ASSUMING maintenance log is sorted most recent date first,
				// code here finds first entry in maint log where track date 
				// is >= maint. entry date, and adds to total at the corresponding
				// location in the totals array
				if ([[t creationTime] compare:dt] != NSOrderedAscending)
				{
					[self incNumberAtIndex:idx
								   inArray:dataArr
								 withValue:[t distance]];
					[self incNumberAtIndex:idx + 1
								   inArray:dataArr
								 withValue:[t movingDuration]];
					found = YES;
					break;
				}
				idx += 2;
			}
			if (!found)
			{
				[self incNumberAtIndex:idx
							   inArray:dataArr
							 withValue:[t distance]];
				[self incNumberAtIndex:idx + 1
							   inArray:dataArr
							 withValue:[t movingDuration]];
			}
		}
	}
}

		 
-(void) updateEquipmentUUIDsForTrack:(Track*)t fromTrackInfo:(EquipmentTrackInfo*)eti
{
	if (eti && t)
	{
		NSSet* eis = [eti equipmentItems];
		NSEnumerator* elEnum = [eis objectEnumerator];
		NSMutableArray* arr = [NSMutableArray arrayWithCapacity:4];
		NSMutableArray* nameArray = [NSMutableArray arrayWithCapacity:4];
		while (EquipmentItem* ei = [elEnum nextObject])
		{
			[arr addObject:[ei uniqueID]];
			[nameArray addObject:[ei name]];
		}
		[t setEquipmentUUIDs:arr];
		///EquipmentItem* mei = [eti mainEquipment];
		///if (mei) [t setMainEquipmentUUID:mei.uniqueID];
		[nameArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
		[[t attributes] replaceObjectAtIndex:kEquipment 
								  withObject:[nameArray componentsJoinedByString:@","]];
	}
}



-(NSDictionary*)dictionaryOfTrackIDToInfoObject:(TrackBrowserDocument*)tbd
{
	NSMutableDictionary* uuidToTrackInDBDict = nil;
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"EquipmentTrackInfo"
								   inManagedObjectContext:moc]];
	NSError* error = nil;
	NSArray* results = [moc executeFetchRequest:request
										  error:&error];
	if (error)
	{
		[self presentError:error];
	}
	else
	{
		uuidToTrackInDBDict = [NSMutableDictionary dictionaryWithCapacity:[results count]];
		// prepare a temporary dictionary to quickly map track UUIDs to EquipmenTrackInfo
		// managed objects.  This should avoid a lot of DB fetches.
		for (EquipmentTrackInfo* eti in results)
		{
			[uuidToTrackInDBDict setObject:eti
									forKey:[eti primitiveValueForKey:@"trackID"]];
		}
	}
	return uuidToTrackInDBDict;
}



-(NSString*)nameStringOfEquipmentItemsForTrack:(Track*)t
{
	NSString* ret = nil;
	EquipmentTrackInfo* eti = [self fetchObjectUsingStringValue:[t uuid]
														 forKey:@"trackID"
														 entity:@"EquipmentTrackInfo"];
	if (eti)
	{
		NSSet* eis = [eti equipmentItems];
		NSEnumerator* elEnum = [eis objectEnumerator];
		NSMutableArray* nameArray = [NSMutableArray arrayWithCapacity:4];
		while (EquipmentItem* ei = [elEnum nextObject])
		{
			[nameArray addObject:[ei name]];
		}
		[nameArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
		ret = [nameArray componentsJoinedByString:@","];
	}
	return ret;
}
		 
#define NUM_PROG_DIVS			(25.0)

-(void)updateEquipmentUUIDsForTrack:(Track*)t uuidToTrackInDBDict:(NSDictionary*)uuidToTrackInDBDict
{
	// update the equipmentUUIDs array in the track, contains info cached
	// in the track but stored in the db.  This will be fixed when everything
	// is core data.
	EquipmentTrackInfo* eti = [uuidToTrackInDBDict objectForKey:[t uuid]];
	if (eti == nil) eti = [self insertNewTrack:t];
	if (eti != nil)
	{
		[self updateEquipmentUUIDsForTrack:t
							 fromTrackInfo:eti];
	}
}


-(void)updateEquipmentLogForDocument:(TrackBrowserDocument*)tbd showProgress:(BOOL)showProg windowController:(NSWindowController*)wc
{
	NSDictionary* uuidToTrackInDBDict = [self dictionaryOfTrackIDToInfoObject:tbd];
	if (uuidToTrackInDBDict)
	{
		NSArray* eqLog = [self getEquipmentList];
		NSMutableDictionary* uidToEQDict = [NSMutableDictionary dictionaryWithCapacity:[eqLog count]];
		NSMutableDictionary* dataDict = [tbd equipmentLogDataDict];
		// prepare a dictionary with an entry for each equipment item -- each entry
		// contains an array of total active time/distance for the document
		for (EquipmentItem* ei in eqLog)
		{
			NSArray* mlarr = [self sortedMaintArrayForEquipmentItem:ei
													  usingDocument:tbd];
			NSString* uid = [ei uniqueID];
			[uidToEQDict setObject:[NSArray arrayWithObjects:ei, mlarr, nil]
							forKey:uid];
			NSMutableArray* dataArr = [dataDict objectForKey:uid];
			if (dataArr) [dataArr removeAllObjects];
		}
		NSArray* trackArray = [tbd trackArray];
		
		SharedProgressBar* pb = nil; 
		float incr = 1.0;
		if (showProg)
		{	
			pb = [SharedProgressBar sharedInstance];
			NSRect fr = [[wc window] frame];
			NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
			
            NSUInteger num = [trackArray count];
			if (num > 0) incr = (float)NUM_PROG_DIVS/(float)num;
			[[pb controller] begin:@"Equipment Log Update"
						 divisions:(int)NUM_PROG_DIVS];
			NSPoint origin;
			origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
			origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
			[[[pb controller] window] setFrameOrigin:origin];
			[[pb controller] showWindow:self];
			[[pb controller] updateMessage:@"updating equipment log totals ..."];
		}			
		
		int ii = (int)incr;
		float totalIncr = 0.0;
		for (Track* t in trackArray)
		{
			[self updateEquipmentUUIDsForTrack:t
						   uuidToTrackInDBDict:uuidToTrackInDBDict];
			// we store, in the document, a dictionary that contains the
			// total times and distances for each equipment item  The next method
			// updates that based on info in the track
			[self updateDataDictionary:dataDict
							usingTrack:t
							  itemDict:uidToEQDict];
			if (pb) 
			{
				totalIncr += incr;
				if ((int)totalIncr > ii)
				{
					[[pb controller] incrementDiv];
					ii = (int)totalIncr;
				}
			}
		}
		[tbd setEquipmentLogDataDict:dataDict];
		if (pb) [[[pb controller] window] orderOut:[wc window]];

	}
}
	
										 
-(void) trackArrayChanged:(NSNotification *)notification
{
	TrackBrowserDocument* tbd = [notification object];
	if (tbd)
	{
		//[self updateEquipmentLogForDocument:tbd];
		tbd.equipmentTotalsNeedUpdate = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"EquipmentLogChanged" object:tbd];
	}
}


-(void)updateTotalsForDocument:(TrackBrowserDocument*)doc showProgress:(BOOL)sp windowController:(NSWindowController*)wc
{
	if (doc.equipmentTotalsNeedUpdate)
	{
		[self updateEquipmentLogForDocument:doc
							   showProgress:sp
						   windowController:wc];
		doc.equipmentTotalsNeedUpdate = NO;
	}
}


-(BOOL)areTracksInEquipmentLog:(NSArray*)trackArray
{
	// check first and last activity in the document.  If both are missing,
	// assume this document's activities have not been reflected in the
	// equipment log
	BOOL answer = NO;
	if (trackArray && [trackArray count] > 0)
	{
		Track* t = [trackArray objectAtIndex:0];
		EquipmentTrackInfo* eti = [self fetchObjectUsingStringValue:[t uuid]
															 forKey:@"trackID"
															 entity:@"EquipmentTrackInfo"];
		if (eti && [trackArray count] > 1)
		{
			t = [trackArray lastObject];
			eti = [self fetchObjectUsingStringValue:[t uuid]
											 forKey:@"trackID"
											 entity:@"EquipmentTrackInfo"];
			if (eti) answer = YES;
		}
	}
	return answer;
}


//------------------------------------------------------------------------------
//---- conversion from old-style equipment attribute to equipment log ----------
//------------------------------------------------------------------------------

-(void) buildEquipmentListFromDefaultAttributes:(TrackBrowserDocument*)tbdoc
{
	NSArray* trackArray = [tbdoc trackArray];
    NSUInteger num = [trackArray count];
	if (![tbdoc usesEquipmentLog] || [self checkEquipmentTypes] || ![self areTracksInEquipmentLog:trackArray])
	{
		NSArray* defaults = [self fetchBoolItemsByKey:@"default"
												value:YES
											   entity:@"EquipmentItem"];
		BOOL isfirst = !defaults || ([defaults count] == 0);
		
		MainWindowController* wc = [tbdoc windowController];
		
		SharedProgressBar* pb = [SharedProgressBar sharedInstance];
		NSRect fr = [[wc window] frame];
		NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
		[[pb controller] begin:@"Equipment Log Update"
					 divisions:(int)num];
		NSPoint origin;
		origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
		origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
		[[[pb controller] window] setFrameOrigin:origin];
		[[pb controller] showWindow:self];
		
		
		[[pb controller] updateMessage:@"converting activities to new equipment log format..."];
		for (int i=0; i<num; i++)
		{
			Track* track = [trackArray objectAtIndex:i];
			[self convertOldStyleTrack:track
							   isFirst:&isfirst];
			[[pb controller] incrementDiv];
		}
		NSError* error = nil;
		[moc save:&error];
		if (error)
		{
			[self presentError:error];
		}
		[[[pb controller] window] orderOut:[wc window]];

		[tbdoc setUsesEquipmentLog:YES];
	}
	// have to make sure equipment UUID array is set in each track
	NSDictionary* dict = [self dictionaryOfTrackIDToInfoObject:tbdoc];
	for (Track* t in trackArray)
	{
		[self updateEquipmentUUIDsForTrack:t
					   uuidToTrackInDBDict:dict];
	}
	tbdoc.equipmentTotalsNeedUpdate = YES;
		 
	defaultEquipmentType = nil;
	[self defaultEquipmentType];
	[self setDefaultEquipmentName:[defaultEquipmentType valueForKey:@"name"]];			// fault data in
	[self setDefaultEquipmentImagePath:[defaultEquipmentType valueForKey:@"imagePath"]];	// fault data in

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(trackArrayChanged:)
												 name:@"TrackArrayChanged"
											   object:nil];
	
}


-(EquipmentTrackInfo*)trackInfoForTrack:(Track*)track
{
	EquipmentTrackInfo* trackInfo = nil;
	NSArray* el = [self getEquipmentList];
	if (el)
	{
		trackInfo = [self fetchItemByValue:[track uuid]
									forKey:@"trackID"
								  inEntity:@"EquipmentTrackInfo"];
   	}
	return trackInfo;
}


-(EquipmentItem*)mainEquipmentItemForTrack:(Track*)track
{
	EquipmentItem* ei = nil;
	EquipmentTrackInfo* trackInfo = [self trackInfoForTrack:track];
	if (trackInfo)
	{
		ei = [trackInfo valueForKey:@"mainEquipment"];
	}
	return ei;
}


-(NSImage*)mainEquipmentImageForTrack:(Track*)track
{
	NSImage* img = nil;
	EquipmentItem* ei = [self mainEquipmentItemForTrack:track];
	if (ei)
	{
		img = [[[NSImage alloc] initWithContentsOfFile:[ei valueForKey:@"imagePath"]] autorelease];
	}
	return img;
}


-(NSString*)mainEquipmentNameForTrack:(Track*)track
{
	NSString* name = @"";
	EquipmentItem* ei = [self mainEquipmentItemForTrack:track];
	if (ei)
	{
		name = [ei valueForKey:@"name"];
	}
	return name;							 
}


-(NSArray*)equipmentItemsForTrack:(Track*)track
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:4];
	EquipmentTrackInfo* trackInfo = [self trackInfoForTrack:track];
	if (trackInfo)
	{
		NSSet* eis = [trackInfo equipmentItems];
		NSEnumerator* elEnum = [eis objectEnumerator];
		while (EquipmentItem* ei = [elEnum nextObject])
		{
			[arr addObject:ei];
		}
	}
	return [arr sortedArrayUsingSelector:@selector(compareByName:)];
}



-(NSArray*)equipmentUUIDsForTrack:(Track*)track
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:4];
	EquipmentTrackInfo* trackInfo = [self trackInfoForTrack:track];
	if (trackInfo)
	{
		NSSet* eis = [trackInfo equipmentItems];
		NSEnumerator* elEnum = [eis objectEnumerator];
		while (EquipmentItem* ei = [elEnum nextObject])
		{
			[arr addObject:[ei uniqueID]];
		}
	}
	return arr;
}



-(float)equipmentWeightForTrack:(Track*)track
{
	float weight = kDefaultEquipmentWeight;
	NSArray* arr = [self equipmentItemsForTrack:track];
	float w = 0.0;
	for (EquipmentItem* ei in arr)
	{
		w += [[ei weight] floatValue];
	}
	if (w > 0.0) weight = w;
	return weight;
}


-(NSArray*)equipmentItemNamesForTrack:(Track*)track
{
	NSArray* arr = [self equipmentItemsForTrack:track];
	NSMutableArray* nameArray = [NSMutableArray arrayWithCapacity:[arr count]];
	for (EquipmentItem* ei in arr)
	{
		[nameArray addObject:[ei name]];
	}
	[nameArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	return nameArray;
}





-(void)updateEquipmentAttributeForTracksContainingEquipmentItem:(NSString*)eid document:(TrackBrowserDocument*)tbd wc:(NSWindowController*)wc
{
	NSArray* trackArray = [tbd trackArray];
	MainWindowController* tbwc = [tbd windowController];
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
	int d = 20;
	[[pb controller] begin:@"Equipment Log Update"
				 divisions:(int)[trackArray count]/d];
	NSPoint origin;
	NSRect fr = [[wc window] frame];
	origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
	origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;  
	[[[pb controller] window] setFrameOrigin:origin];
	[[pb controller] showWindow:self];
	[[pb controller] updateMessage:@"updating activities ..."];
	int c = 0;
	for (Track* t in trackArray)
	{
		NSArray* uids = [t equipmentUUIDs];
		if ([uids indexOfObject:eid] != NSNotFound)
		{
			[t setStaleEquipmentAttr:YES];
			[tbwc simpleUpdateBrowserTrack:t];
		}
		if ((++c % d) == 0)
		{
			[[pb controller] incrementDiv];
		}
	}
	[[[pb controller] window] orderOut:[wc window]];
}


@end
