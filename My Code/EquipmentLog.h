//
//  EquipmentLog.h
//  Ascent
//
//  Created by Rob Boyer on 12/14/09.
//  Copyright 2009 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SingletonBase.h"

@class Track;
@class TrackBrowserDocument;

@interface EquipmentLog : SingletonBase
{
	NSManagedObjectContext*	moc;
	NSManagedObject*		defaultEquipmentType;
	NSString*				defaultEquipmentImagePath;
	NSString*				defaultEquipmentName;
}
@property (nonatomic, retain) NSManagedObject* defaultEquipmentType;
@property (nonatomic, retain) NSString* defaultEquipmentImagePath;
@property (nonatomic, retain) NSString* defaultEquipmentName;

-(id)init;
-(NSManagedObjectContext*)managedObjectContext;
-(void)trackAddedOrUpdated:(Track*)track;
-(void)trackDeleted:(Track*)track;
-(void) buildEquipmentListFromDefaultAttributes:(TrackBrowserDocument*)tbdoc;
-(id)fetchObjectUsingStringValue:(NSString*)val forKey:(NSString*)key entity:(NSString*)ent;
-(NSArray*)fetchBoolItemsByKey:(NSString*)key value:(BOOL)val entity:(NSString*)ent;
-(NSImage*)mainEquipmentImageForTrack:(Track*)track;
-(NSString*)mainEquipmentNameForTrack:(Track*)track;
-(NSArray*)equipmentItemsForTrack:(Track*)track;
-(NSArray*)equipmentUUIDsForTrack:(Track*)track;
-(void)setCurrentEquipmentItemsAsDefault:(TrackBrowserDocument*)tbDocument;
-(float)equipmentWeightForTrack:(Track*)track;
-(NSArray*)equipmentItemNamesForTrack:(Track*)track;
-(NSString*)nameStringOfEquipmentItemsForTrack:(Track*)t;
-(void)updateEquipmentAttributeForTracksContainingEquipmentItem:(NSString*)eid document:(TrackBrowserDocument*)tbd wc:(NSWindowController*)wc;
-(void)updateTotalsForDocument:(TrackBrowserDocument*)tbd showProgress:(BOOL)showProg windowController:(NSWindowController*)wc;
-(NSPredicate*)maintFilterForDocument:(TrackBrowserDocument*)tbd;
@end
