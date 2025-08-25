//
//  EquipmentSelectorWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 12/29/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class EquipmentLog;


@interface EquipmentSelectorWindowController : NSWindowController 
{
	TrackBrowserDocument*		tbDocument;
	EquipmentLog*				equipmentLog;
	NSArray*					alphaSortDescriptors;
	IBOutlet NSTableView*		equipmentTable;
	IBOutlet NSArrayController*	equipmentItemsArrayController;
	IBOutlet NSButton*			useAsDefaultsButton;
	NSMutableIndexSet*			selectedItemsIndexSet;
	BOOL						showEquipmentLogOnExit;
}
@property (nonatomic) BOOL showEquipmentLogOnExit;
@property (nonatomic, retain) NSMutableIndexSet* selectedItemsIndexSet;

- (id)initWithDocument:(TrackBrowserDocument*)doc;
-(IBAction)dismiss:(id)sender;
-(IBAction)done:(id)sender;
-(IBAction)showEquipmentLog:(id)sender;
-(IBAction)setCurrentAsDefault:(id)sender;
@end
