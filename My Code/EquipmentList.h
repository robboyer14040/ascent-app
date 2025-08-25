//
//  EquipmentList.h
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EquipmentItem;

@interface EquipmentList : NSObject  <NSCoding>
{
	NSMutableDictionary*	equipmentList;		// EquipmentItem objects, indexed by GUID
	NSMutableArray*			keysSortedByName;
}


-(int)count;
-(EquipmentItem*)itemAtIndex:(int)idx;
-(void)addItem:(EquipmentItem*)ei;
-(void)removeItem:(EquipmentItem*)ei;
-(void)removeItemAtIndex:(int)idx;

@end
