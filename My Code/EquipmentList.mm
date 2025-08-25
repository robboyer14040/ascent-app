//
//  EquipmentList.mm
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software. All rights reserved.
//

#import "Defs.h"
#import "EquipmentList.h"
#import "EquipmentItem.h"
#import "StringAdditions.h"


@interface EquipmentList ()
-(void) updateKeys:(BOOL)reSort;
- (NSArray *)keysSortedByName;
- (void)setKeysSortedByName:(NSArray*)ksbn;
- (NSMutableDictionary *)equipmentList;
- (void)setEquipmentList:(NSMutableDictionary *)value;

@end


@implementation EquipmentList


-(id)init
{
	if (self = [super init])
	{
		[self setEquipmentList:[NSMutableDictionary dictionaryWithCapacity:16]];
		keysSortedByName = nil;
	}
	return self;
}


-(void)dealloc
{
	[keysSortedByName release];
	[equipmentList release];
	[super dealloc];
}



- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
	printf("decoding Equipment LIST\n");
#endif
	[super init];
	[self setEquipmentList:[coder decodeObject]];
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:equipmentList];
}


-(int)count
{
	[self updateKeys:NO];
	return [equipmentList count];
}


-(void) updateKeys:(BOOL)reSort
{
	if (keysSortedByName == nil || reSort)
	{
		[self setKeysSortedByName:[equipmentList keysSortedByValueUsingSelector:@selector(compareByName:)]];
	}
}


-(EquipmentItem*)itemAtIndex:(int)idx
{
	EquipmentItem* ei = nil;
	[self updateKeys:NO];
	if (IS_BETWEEN(0, idx, ([keysSortedByName count]-1)))
	{
		NSString* key = [keysSortedByName objectAtIndex:idx];
		ei = [equipmentList objectForKey:key];
	}
	return ei;
}


-(void)addItem:(EquipmentItem*)ei
{
	NSString* uid = [NSString uniqueString];
	[equipmentList setObject:ei
					  forKey:uid];
	[self updateKeys:YES];
}


-(void)removeItem:(EquipmentItem*)ei
{
	NSString* uid = [ei uniqueID];
	[equipmentList removeObjectForKey:uid];
	[self updateKeys:YES];
}


-(void)removeItemAtIndex:(int)idx
{
	[self updateKeys:NO];
	if (IS_BETWEEN(0, idx, ([keysSortedByName count]-1)))
	{
		[equipmentList removeObjectForKey:[keysSortedByName objectAtIndex:idx]];
	}
	[self updateKeys:YES];
}	


- (NSArray *)keysSortedByName
{
	return keysSortedByName;
}


- (void)setKeysSortedByName:(NSArray*)ksbn
{
	if (ksbn != keysSortedByName)
	{
		[keysSortedByName release];
		keysSortedByName = [ksbn retain];
	}
}


- (NSMutableDictionary *)equipmentList 
{
    return [[equipmentList retain] autorelease];
}

- (void)setEquipmentList:(NSMutableDictionary *)value 
{
    if (equipmentList != value) 
	{
        [equipmentList release];
        equipmentList = [value retain];
    }
}




@end
