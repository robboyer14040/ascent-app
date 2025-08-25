//
//  EquipmentLogInitialValuesWC.h
//  Ascent
//
//  Created by Rob on 1/20/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class EquipmentLog;


@interface EquipmentLogInitialValuesWC : NSWindowController 
{
	TrackBrowserDocument*		tbDocument;
	EquipmentLog*				equipmentLog;
	NSArray*					alphaSortDescriptors;
	NSDictionary*				equipmentLogInitialData;
	IBOutlet NSTableView*		equipmentTable;
	IBOutlet NSArrayController*	equipmentItemsArrayController;
	IBOutlet NSMatrix*			startDateMatrix;
	IBOutlet NSDatePicker*		startDatePicker;
	IBOutlet NSMatrix*			endDateMatrix;
	IBOutlet NSDatePicker*		endDatePicker;	
	IBOutlet NSButton*			setStartDateToFirstButton;
	IBOutlet NSButton*			setEndDateToLastButton;	
}
- (id)initWithDocument:(TrackBrowserDocument*)doc;
-(IBAction)dismiss:(id)sender;
-(IBAction)done:(id)sender;
-(IBAction)setDate:(id)sender;

@end
