//
//  EquimentListWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface EquimentListWindowController : NSWindowController 
{
	IBOutlet* NSTableView*	tableView;
	IBOutlet* NSButton*		doneButton;
	IBOutlet* NSButton*		editButton;
	IBOutlet* NSButton*		deleteButton;

	NSMutableDictionary*	equipmentList;		// EquipmentItem objects
}






@end
