//
//  EquipmentItem.mm
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentItem.h"
#import "StringAdditions.h"

@implementation EquipmentItem

-(id) initWithName:(NSString*)iname
{
	if (self = [super init])
	{
		[self setName:iname];
		[self setUniqueID:[NSString uniqueString]];
		extensions = [[NSMutableDictionary alloc] init];
		notes = nil;
		dateAcquired = nil;
		lastMaintenanceDate = nil;
		imageData = nil;
		weight = nil;
		maintenanceDates = nil;
	}
	return self;
}

-(void)dealloc
{
	[extensions release];
	[name release];
	[notes release];
	[dateAcquired release];
	[lastMaintenanceDate release];
	[imageData release];
	[weight release];
	[maintenanceDates release];
	[super dealloc];
}


- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
	printf("decoding Equipment Item\n");
#endif
	[super init];
	[self setUniqueID:[coder decodeObject]];
	[self setName:[coder decodeObject]];
	[self setNotes:[coder decodeObject]];
	[self setDateAcquired:[coder decodeObject]];
	[self setLastMaintenanceDate:[coder decodeObject]];
	[self setImageData:[coder decodeObject]];
	[self setWeight:[coder decodeObject]];
	[self setMaintenanceDates:[coder decodeObject]];
	[self setExtensions:[coder decodeObject]];
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:uniqueID];
	[coder encodeObject:name];
	[coder encodeObject:notes];
	[coder encodeObject:dateAcquired];
	[coder encodeObject:lastMaintenanceDate];
	[coder encodeObject:imageData];
	[coder encodeObject:weight];
	[coder encodeObject:maintenanceDates];
	[coder encodeObject:extensions];
}


- (NSMutableDictionary*) extensions
{
	return extensions;
}


- (void) setExtensions:(NSMutableDictionary*)dict
{
	if (dict != extensions)
	{
		[extensions release];
		extensions = [dict retain];
	}
}


-(void)setName:(NSString*)s
{
	if (s != name)
	{
		[name release];
		name = [s retain];
	}
}


-(NSString*)name
{
	return name;
}


-(void)setUniqueID:(NSString*)s
{
	if (s != uniqueID)
	{
		[uniqueID release];
		uniqueID = [s retain];
	}
}


-(NSString*)uniqueID
{
	return uniqueID;
}


- (NSString *)notes 
{
    return [[notes retain] autorelease];
}

- (void)setNotes:(NSString *)value 
{
    if (notes != value) 
	{
        [notes release];
        notes = [value retain];
    }
}
	
	
- (NSNumber *)weight
{
	return [[weight retain] autorelease];
}

- (void)setWeight:(NSNumber *)value 
{
	if (weight != value) {
		[weight release];
		weight = [value retain];
	}
}


- (NSDate *)dateAcquired 
{
    return [[dateAcquired retain] autorelease];
}

- (void)setDateAcquired:(NSDate *)value 
{
    if (dateAcquired != value) 
	{
        [dateAcquired release];
        dateAcquired = [value retain];
    }
}


- (NSDate *)lastMaintenanceDate 
{
    return [[lastMaintenanceDate retain] autorelease];
}

- (void)setLastMaintenanceDate:(NSDate *)value 
{
    if (lastMaintenanceDate != value) 
	{
        [lastMaintenanceDate release];
        lastMaintenanceDate = [value retain];
    }
}


- (NSNumber *)totalDistance 
{
    return [[totalDistance retain] autorelease];
}

- (void)setTotalDistance:(NSNumber *)value 
{
    if (totalDistance != value) 
	{
        [totalDistance release];
        totalDistance = [value copy];
    }
}


- (NSNumber *)distanceSinceMaintenance 
{
    return [[distanceSinceMaintenance retain] autorelease];
}

- (void)setDistanceSinceMaintenance:(NSNumber *)value 
{
    if (distanceSinceMaintenance != value) 
	{
        [distanceSinceMaintenance release];
        distanceSinceMaintenance = [value retain];
    }
}


- (NSArray *)maintenanceDates 
{
    return [[maintenanceDates retain] autorelease];
}

- (void)setMaintenanceDates:(NSArray *)value 
{
    if (maintenanceDates != value) 
	{
        [maintenanceDates release];
        maintenanceDates = [value retain];
    }
}


- (NSData *)imageData 
{
    return [[imageData retain] autorelease];
}

- (void)setImageData:(NSData *)value 
{
    if (imageData != value) 
	{
        [imageData release];
        imageData = [value retain];
    }
}


- (NSImage *)image 
{
    return [[image retain] autorelease];
}

- (void)setImage:(NSImage *)value 
{
    if (image != value) 
	{
        [image release];
        image = [value retain];
    }
}


- (NSComparisonResult) compareByName:(EquipmentItem*)anotherItem
{
	return [name localizedCaseInsensitiveCompare:[anotherItem name]];
}

@end
