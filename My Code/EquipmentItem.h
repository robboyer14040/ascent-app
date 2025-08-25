//
//  EquipmentItem.h
//  Ascent
//
//  Created by Rob Boyer on 12/19/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class EquipmentTrackInfo;
@class EquipmentLog;
@class Track;

// defined values for 'flags' field
enum
{
	kUserSuppliedImage	= 0x00000001,
	kUserSuppliedWeight = 0x00000002,
	kItemIsDefaultMain	= 0x00000004,
};

@interface EquipmentItem : NSManagedObject 
{

}


@property (nonatomic, retain) NSSet* trackInfoSet;
@property (nonatomic, retain) NSSet* maintenanceLogs;
@property (nonatomic, retain) NSSet* trackInfosWhereMain;
@property (nonatomic) BOOL userSuppliedImage;
@property (nonatomic) BOOL userSuppliedWeight;

-(void)setUsesForTrack:(Track*)track  equipmentLog:(EquipmentLog*)eqlog used:(BOOL)im;
-(BOOL)usesForTrack:(Track*)track;
-(void)setMainForTrack:(Track*)track equipmentLog:(EquipmentLog*)eqlog main:(BOOL)im;
-(BOOL)mainForTrack:(Track*)track;
-(void)setDefaultFields:(EquipmentLog*)el;
- (NSComparisonResult)compareByName:(EquipmentItem *)otherItem;
@end

// coalesce these into one @interface EquipmentItem (CoreDataGeneratedAccessors) section
@interface EquipmentItem (CoreDataGeneratedAccessors)
@property (nonatomic, retain) NSDate * dateAcquired;
@property (nonatomic, retain) NSNumber * distanceSinceMaintenance;
@property (nonatomic, retain) NSNumber * flags;
@property (nonatomic, retain) NSData * imageData;
@property (nonatomic, retain) NSNumber * Default;
@property (nonatomic, retain) NSDate * lastMaintenanceDate;
@property (nonatomic, retain) NSNumber * maintenanceIntervalDistance;
@property (nonatomic, retain) NSNumber * maintenanceIntervalTime;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * notes;
@property (nonatomic, retain) NSNumber * timeSinceMaintenance;
@property (nonatomic, retain) NSNumber * totalDistance;
@property (nonatomic, retain) NSNumber * totalTime;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSString * uniqueID;
@property (nonatomic, retain) NSNumber * weight;
@end



