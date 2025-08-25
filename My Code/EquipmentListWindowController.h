//
//  EquipmentListWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class EquipmentLog;

@interface MaintArrayController : NSArrayController
{
	TrackBrowserDocument*		tbDocument;
}
@end


@interface EquipmentListWindowController : NSWindowController <NSComboBoxDataSource>
{

	NSArray*						alphaSortDescriptors;
	NSArray*						dateSortDescriptors;
	IBOutlet NSTableView*			equipmentTable;
	IBOutlet NSTableView*			maintTable;
	IBOutlet MaintArrayController*	maintenanceLogArrayController;
	IBOutlet NSArrayController*		equipmentItemsArrayController;
	IBOutlet NSArrayController*		equipmentTypesArrayController;
	IBOutlet NSImageView*			equipmentImageView;
	IBOutlet NSComboBox*			typeComboBox;
	IBOutlet NSTextField*			weightTextField;
	IBOutlet NSTextView*			notesTextView;
	IBOutlet NSTextField*			nameTextField;
	IBOutlet NSTextField*			weightUnitsTextField;
	TrackBrowserDocument*			tbDocument;
	EquipmentLog*					equipmentLog;
	NSDictionary*					equipmentLogInitialData;
	NSString*						forceSelectionUUID;
}

@property (retain, nonatomic) NSString* forceSelectionUUID;

- (id)initWithDocument:(TrackBrowserDocument*)tbd;
-(void)add:(id)sender;
-(IBAction)showEquipmentLogInitialValues:(id)sender;
-(IBAction)dismiss:(id)sender;
-(IBAction)addMaintItem:(id)sender;
-(IBAction)removeMaintItem:(id)sender;
-(IBAction)addEquipmentItem:(id)sender;
-(IBAction)removeEquipmentItem:(id)sender;
-(IBAction)setName:(id)sender;
-(IBAction)setImage:(id)sender;
-(IBAction)setEquipmentType:(id)sender;
-(IBAction)setDateAcquired:(id)sender;
-(IBAction)setDocumentInitialValues:(id)sender;
-(IBAction)selectEquipmentItemWithUniqueID:(NSString*)uuid;



@end
