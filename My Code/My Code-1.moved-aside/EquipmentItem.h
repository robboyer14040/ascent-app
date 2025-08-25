//
//  EquipmentItem.h
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface EquipmentItem : NSObject <NSCoding>
{
	NSString*				uniqueID;	
	NSString*				name;
	NSString*				notes;
	NSNumber*				weight;
	NSDate*					dateAcquired;
	NSDate*					lastMaintenanceDate;
	NSNumber*				totalDistance;
	NSNumber*				distanceSinceMaintenance;
	NSData*					imageData;
	NSArray*				maintenanceDates;	// array of NSDate objects
	NSImage*				image;
	NSMutableDictionary*	extensions;
}

-(id)initWithName:(NSString*)nm;

-(NSString*)name;
-(void)setName:(NSString*)s;

-(NSString*)uniqueID;
-(void)setUniqueID:(NSString*)s;

- (NSString *)notes;
- (void)setNotes:(NSString *)value;

- (NSNumber *)weight;
- (void)setWeight:(NSNumber *)value;

- (NSDate *)dateAcquired;
- (void)setDateAcquired:(NSDate *)value;

- (NSDate *)lastMaintenanceDate;
- (void)setLastMaintenanceDate:(NSDate *)value;

- (NSNumber *)totalDistance;
- (void)setTotalDistance:(NSNumber *)value;

- (NSNumber *)distanceSinceMaintenance;
- (void)setDistanceSinceMaintenance:(NSNumber *)value;

- (NSData *)imageData;
- (void)setImageData:(NSData *)value;

- (NSArray *)maintenanceDates;
- (void)setMaintenanceDates:(NSArray *)value;

- (NSImage *)image;
- (void)setImage:(NSImage *)value;

- (NSMutableDictionary*) extensions;
- (void) setExtensions:(NSMutableDictionary*)dict;

- (NSComparisonResult) compareByName:(EquipmentItem*)anotherItem;

@end
