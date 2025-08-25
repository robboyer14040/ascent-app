//
//  EquipmentTrackInfo.mm
//  Ascent
//
//  Created by Rob Boyer on 12/20/09.
//  Copyright 2009 Montebello Software. All rights reserved.
//

#import "EquipmentTrackInfo.h"

@interface EquipmentTrackInfo (CoreDataGeneratedPrimitiveAccessors)

- (EquipmentItem *)primitiveMainEquipment;
- (void)setPrimitiveMainEquipment:(EquipmentItem *)value;
- (NSMutableSet*)primitiveEquipmentItems;
//- (void)setPrimitiveEmployees:(NSMutableSet*)value;
@end


@interface EquipmentTrackInfo (DirectReportsAccessors)
- (void)addEquipmentItemsObject:(EquipmentItem *)value;
- (void)removeEquipmentItemsObject:(EquipmentItem *)value;
- (void)addEquipmentItems:(NSSet *)value;
- (void)removeEquipmentItems:(NSSet *)value;
@end

@implementation EquipmentTrackInfo

@dynamic activeTime;
@dynamic date;
@dynamic distance;
@dynamic trackID;
@dynamic equipmentItems;
@dynamic mainEquipment;



- (void)addEquipmentItemsObject:(EquipmentItem *)value;
{
#if TRACE_ADD_REMOVE
	printf("TRACKINFO - adding equipment item %s to track_info item %s\n", [[value name] UTF8String], [[self trackID] UTF8String]);
#endif
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:@"equipmentItems"
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:changedObjects];
    [[self primitiveEquipmentItems] addObject:value];
    [self didChangeValueForKey:@"equipmentItems"
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:changedObjects];

}


- (void)removeEquipmentItemsObject:(EquipmentItem *)value
{
#if TRACE_ADD_REMOVE
	printf("TRACKINFO - removing equipment item %s from track_info item %s\n", [[value name] UTF8String], [[self trackID] UTF8String]);
#endif
   NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
	
    [self willChangeValueForKey:@"equipmentItems"
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:changedObjects];
    [[self primitiveEquipmentItems] removeObject:value];
    [self didChangeValueForKey:@"equipmentItems"
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:changedObjects];
	
}


- (void)addEquipmentItems:(NSSet *)value
{
#if TRACE_ADD_REMOVE
	printf("TRACKINFO - adding equipment items to track_info item %s\n", [[self trackID] UTF8String]);
#endif
    [self willChangeValueForKey:@"equipmentItems"
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:value];
    [[self primitiveEquipmentItems] unionSet:value];
    [self didChangeValueForKey:@"equipmentItems"
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:value];
}


- (void)removeEquipmentItems:(NSSet *)value
{
#if TRACE_ADD_REMOVE
	printf("TRACKINFO - removing equipment items from track_info item %s\n", [[self trackID] UTF8String]);
#endif
    [self willChangeValueForKey:@"equipmentItems"
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:value];
    [[self primitiveEquipmentItems] minusSet:value];
    [self didChangeValueForKey:@"equipmentItems"
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:value];
}


- (EquipmentItem *)mainEquipment 
{
    id tmpObject;
    
    [self willAccessValueForKey:@"mainEquipment"];
    tmpObject = [self primitiveMainEquipment];
    [self didAccessValueForKey:@"mainEquipment"];
    
    return tmpObject;
}

- (void)setMainEquipment:(EquipmentItem *)value 
{
#if TRACE_MAIN_EQ
	printf("::: Setting MAIN EQUIPMENT for track %s to %s :::\n",  [[self trackID] UTF8String], [[value name] UTF8String]);
#endif
    [self willChangeValueForKey:@"mainEquipment"];
    [self setPrimitiveMainEquipment:value];
    [self didChangeValueForKey:@"mainEquipment"];
}



@end


