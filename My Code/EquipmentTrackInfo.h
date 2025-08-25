//
//  EquipmentTrackInfo.h
//  Ascent
//
//  Created by Rob Boyer on 12/20/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class EquipmentItem;

@interface EquipmentTrackInfo : NSManagedObject 
{

}

@property (nonatomic, retain) NSNumber * activeTime;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSNumber * distance;
@property (nonatomic, retain) NSString * trackID;
@property (nonatomic, retain) NSSet* equipmentItems;
@property (nonatomic, retain) EquipmentItem * mainEquipment;
// coalesce these into one @interface EquipmentTrackInfo (CoreDataGeneratedAccessors) section
- (void)addEquipmentItemsObject:(EquipmentItem *)value;
- (void)removeEquipmentItemsObject:(EquipmentItem *)value;
- (void)addEquipmentItems:(NSSet *)value;
- (void)removeEquipmentItems:(NSSet *)value;
@end






