//
//  EquipmentItem.mm
//  Ascent
//
//  Created by Rob Boyer on 12/19/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentItem.h"
#import "StringAdditions.h"
#import "EquipmentTrackInfo.h"
#import "MaintenanceLog.h"
#import "Track.h"
#import "TrackBrowserDocument.h"
#import "EquipmentLog.h"
#import "Utils.h"

#define TRACE_ADD_REMOVE					ASCENT_DBG&&0
#define TRACE_ADD_REMOVE_MAIN				ASCENT_DBG&&0


@interface EquipmentItem (CoreDataGeneratedAccessors2)
- (void)addTrackInfoSetObject:(EquipmentTrackInfo *)value;
- (void)removeTrackInfoSetObject:(EquipmentTrackInfo *)value;
- (void)addTrackInfoSet:(NSSet *)value;
- (void)removeTrackInfoSet:(NSSet *)value;
- (void)addMaintenanceLogsObject:(MaintenanceLog *)value;
- (void)removeMaintenanceLogsObject:(MaintenanceLog *)value;
- (void)addMaintenanceLogs:(NSSet *)value;
- (void)removeMaintenanceLogs:(NSSet *)value;
- (void)addTrackInfosWhereMainObject:(EquipmentTrackInfo *)value;
- (void)removeTrackInfosWhereMainObject:(EquipmentTrackInfo *)value;
- (void)addTrackInfosWhereMain:(NSSet *)value;
- (void)removeTrackInfosWhereMain:(NSSet *)value;
- (NSMutableSet*)primitiveTrackInfoSet;
- (NSMutableSet*)primitiveMaintenanceLogs;
- (NSMutableSet*)primitiveTrackInfosWhereMain;
@end


// Access to-many relationship via -[NSObject mutableSetValueForKey:]



@implementation EquipmentItem

@dynamic trackInfoSet;
@dynamic maintenanceLogs;
@dynamic trackInfosWhereMain;
@dynamic userSuppliedImage;
@dynamic userSuppliedWeight;


-(void)dealloc
{
    [super dealloc];
}


- (void)awakeFromFetch
{
	[super awakeFromFetch];
}


-(void)setDefaultFields:(EquipmentLog*)el
{
	[self setValue:[el defaultEquipmentImagePath]
			forKey:@"imagePath"];
	NSManagedObject* et = [el  defaultEquipmentType];
	[self setPrimitiveValue:et
					 forKey:@"type"];
}


- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setValue:[NSString uniqueString]
			forKey:@"uniqueID"];
	[self setValue:[NSDate date]
			forKey:@"dateAcquired"];
}



- (void)updateTotals
{
#if 0
	// totals are now per-document, and not stored in the database.  Fields are
	// stil there, however
	NSSet* trackInfoSet = [self primitiveValueForKey:@"trackInfoSet"];
	NSEnumerator* tiEnum = [trackInfoSet objectEnumerator];
	float mtime = 0.0;
	float mdist = 0.0;
	float ttime = 0.0;
	float tdist = 0.0;
	while (EquipmentTrackInfo* ti = [tiEnum nextObject])
	{
		ttime += [[ti activeTime] floatValue];
		tdist += [[ti distance] floatValue];
		if ([[ti date] compare:[self lastMaintenanceDate]] != NSOrderedAscending)
		{
			mtime += [[ti activeTime] floatValue];
			mdist += [[ti distance] floatValue];
		}
	}
	[self setTotalTime:[NSNumber numberWithFloat:ttime]];
	[self setTotalDistance:[NSNumber numberWithFloat:tdist]];
 	[self setTimeSinceMaintenance:[NSNumber numberWithFloat:mtime]];
	[self setDistanceSinceMaintenance:[NSNumber numberWithFloat:mdist]];
#endif
}


-(void)updateLastMaintenanceDate
{
	NSDate* lmd;
	NSSet* maintenanceLogs = [self primitiveValueForKey:@"maintenanceLogs"];

	NSMutableArray* sortedArray = [NSMutableArray arrayWithCapacity:[maintenanceLogs count]];
	for (id anObject in maintenanceLogs)
		[sortedArray addObject:anObject];
	NSArray* sortDescriptors = [NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"date"
																					 ascending: NO], nil];
	[sortedArray sortUsingDescriptors:sortDescriptors];
	
	if ([sortedArray count] > 0)
	{
		MaintenanceLog* ml = [sortedArray objectAtIndex:0];
		lmd = [ml date];
	}
	else
	{
		lmd = [NSDate date];
	}
	if ([lmd compare:[self lastMaintenanceDate]] != NSOrderedSame)
	{
		[self setLastMaintenanceDate:lmd];
		//[self updateTotals];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"LastMaintenanceDateChanged" object:self];
	}
}

	



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updateLastMaintenanceDate];
}



-(BOOL)mainForTrack:(Track*)track 
{
	BOOL answer = NO;
	NSSet* trackInfoSet = [self primitiveValueForKey:@"trackInfosWhereMain"];
	NSEnumerator* tiEnum = [trackInfoSet objectEnumerator];
	while (EquipmentTrackInfo* eti = [tiEnum nextObject])
	{
		if ([[eti trackID] isEqualToString:[track uuid]])
		{
			answer = YES;
			break;
		}
	}
	return answer;
}


-(void)setMainForTrack:(Track*)track equipmentLog:(EquipmentLog*)eqlog main:(BOOL)im
{
	EquipmentTrackInfo* eti = [eqlog  fetchObjectUsingStringValue:[track uuid]
														   forKey:@"trackID" 
														   entity:@"EquipmentTrackInfo"];
	if (eti)
	{
		NSMutableSet *tracksWhereMainSet = [self mutableSetValueForKey:@"trackInfosWhereMain"];
		if (im)
		{
			[tracksWhereMainSet addObject:eti];
		}
		else
		{
			[tracksWhereMainSet removeObject:eti];
		}
	}
}



-(BOOL)usesForTrack:(Track*)track
{
	BOOL answer = NO;
	NSSet* trackInfoSet = [self primitiveValueForKey:@"trackInfoSet"];
	NSEnumerator* tiEnum = [trackInfoSet objectEnumerator];
	while (EquipmentTrackInfo* ti = [tiEnum nextObject])
	{
		if ([[ti trackID] isEqualToString:[track uuid]])
		{
			answer = YES;
			break;
		}
	}
	return answer;
}


-(void)setUsesForTrack:(Track*)track equipmentLog:(EquipmentLog*)eqlog used:(BOOL)im
{
	EquipmentTrackInfo* eti = [eqlog  fetchObjectUsingStringValue:[track uuid]
														   forKey:@"trackID" 
														   entity:@"EquipmentTrackInfo"];
	if (eti)
	{
		NSMutableSet *trackInfoSet = [self mutableSetValueForKey:@"trackInfoSet"];
		BOOL isInSet = [trackInfoSet member:eti] != nil;
		if (isInSet && !im)
		{
			[trackInfoSet removeObject:eti];
			NSMutableSet *tracksWhereMainSet = [self mutableSetValueForKey:@"trackInfosWhereMain"];
			[tracksWhereMainSet removeObject:eti];
		}
		else if (!isInSet && im)
		{
			[trackInfoSet addObject:eti];
		}
	}
}


- (NSComparisonResult) compareByName:(id)ei2
{
	return [self.name localizedCaseInsensitiveCompare:[ei2 name]];
}



- (id)valueForUndefinedKey:(NSString *)key
{
	NSLog(@"EquipmentItem undefined key:%@", key);
	return nil;
}


-(BOOL)flagValue:(int)aflag
{
	int flags = [[self primitiveValueForKey:@"flags"] intValue];
	return FLAG_IS_SET(flags, aflag);
}


-(void)setFlagValue:(BOOL)yn flag:(int)flag
{
	int flags = [[self primitiveValueForKey:@"flags"] intValue];
	if (yn)
	{
		flags = SET_FLAG(flags, flag);
	}
	else
	{
		flags = CLEAR_FLAG(flags, flag);
	}
	[self setValue:[NSNumber numberWithInt:flags]
			forKey:@"flags"];
}


-(BOOL)userSuppliedImage
{
	return [self flagValue:kUserSuppliedImage];
}


-(void)setUserSuppliedImage:(BOOL)yn
{
	[self setFlagValue:yn
				  flag:kUserSuppliedImage];
}


-(BOOL)userSuppliedWeight
{
	return [self flagValue:kUserSuppliedWeight];
}


-(void)setUserSuppliedWeight:(BOOL)yn
{
	[self setFlagValue:yn
				  flag:kUserSuppliedWeight];
}



//------------------------------------------------------------------------------

- (void)addTrackInfoSetObject:(EquipmentTrackInfo *)value;
{
#if TRACE_ADD_REMOVE
	printf("EQUIPMENTITEM - adding track_info item %s to %s\n", [[value trackID] UTF8String], [[self name] UTF8String]);
#endif
	NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:@"trackInfoSet"
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:changedObjects];
    [[self primitiveTrackInfoSet] addObject:value];
    [self didChangeValueForKey:@"trackInfoSet"
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:changedObjects];
	//[self updateTotals];
}	



- (void)removeTrackInfoSetObject:(EquipmentTrackInfo *)value;
{
#if TRACE_ADD_REMOVE
	printf("EQUIPMENTITEM - removing track_info item %s from %s\n", [[value trackID] UTF8String], [[self name] UTF8String]);
#endif
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:@"trackInfoSet"
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:changedObjects];
    [[self primitiveTrackInfoSet] removeObject:value];
    [self didChangeValueForKey:@"trackInfoSet"
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:changedObjects];
	
	//[self updateTotals];
}


- (void)addTrackInfoSet:(NSSet *)value;
{
#if TRACE_ADD_REMOVE
	printf("EQUIPMENTITEM - adding track_info items to %s\n", [[self name] UTF8String]);
#endif
	[self willChangeValueForKey:@"trackInfoSet"
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:value];
    [[self primitiveTrackInfoSet] unionSet:value];
    [self didChangeValueForKey:@"trackInfoSet"
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:value];
}


- (void)removeTrackInfoSet:(NSSet *)value;
{
#if TRACE_ADD_REMOVE
	printf("EQUIPMENTITEM - removing track_info items from %s\n", [[self name] UTF8String]);
#endif
    [self willChangeValueForKey:@"trackInfoSet"
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:value];
    [[self primitiveTrackInfoSet] minusSet:value];
    [self didChangeValueForKey:@"trackInfoSet"
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:value];
}





- (void)addMaintenanceLogsObject:(MaintenanceLog *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveMaintenanceLogs] addObject:value];
    [self didChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
	[self updateLastMaintenanceDate];
}

- (void)removeMaintenanceLogsObject:(MaintenanceLog *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveMaintenanceLogs] removeObject:value];
    [self didChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
	[self updateLastMaintenanceDate];
}

- (void)addMaintenanceLogs:(NSSet *)value 
{    
    [self willChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitiveMaintenanceLogs] unionSet:value];
    [self didChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

- (void)removeMaintenanceLogs:(NSSet *)value 
{
    [self willChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
    [[self primitiveMaintenanceLogs] minusSet:value];
    [self didChangeValueForKey:@"maintenanceLogs" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
}



- (void)addTrackInfosWhereMainObject:(EquipmentTrackInfo *)value 
{    
#if TRACE_ADD_REMOVE_MAIN
	printf("EQUIPMENTITEM - adding track_info MAIN item %s to %s\n", [[value trackID] UTF8String], [[self name] UTF8String]);
#endif
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveTrackInfosWhereMain] addObject:value];
    [self didChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
}

- (void)removeTrackInfosWhereMainObject:(EquipmentTrackInfo *)value 
{
#if TRACE_ADD_REMOVE_MAIN
	printf("EQUIPMENTITEM - removing track_info MAIN item %s from %s\n", [[value trackID] UTF8String], [[self name] UTF8String]);
#endif
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveTrackInfosWhereMain] removeObject:value];
    [self didChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
}

- (void)addTrackInfosWhereMain:(NSSet *)value 
{    
#if TRACE_ADD_REMOVE_MAIN
	printf("EQUIPMENTITEM - adding track_info MAIN items to %s\n", [[self name] UTF8String]);
#endif
	[self willChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitiveTrackInfosWhereMain] unionSet:value];
    [self didChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

- (void)removeTrackInfosWhereMain:(NSSet *)value 
{
#if TRACE_ADD_REMOVE_MAIN
	printf("EQUIPMENTITEM - removing track_info MAIN items from %s\n", [[self name] UTF8String]);
#endif
    [self willChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
    [[self primitiveTrackInfosWhereMain] minusSet:value];
    [self didChangeValueForKey:@"trackInfosWhereMain" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
}



@end

