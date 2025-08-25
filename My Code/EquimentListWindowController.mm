//
//  EquimentListWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquimentListWindowController.h"


@implementation EquimentListWindowController



//---- TableView data source methods -------------------------------------------

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [equipmentList count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
}


//---- TableView delegate methods ----------------------------------------------


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSArray* arr = [equipmentList keysSortedByValueUsingSelector:<#(SEL)comparator#>
    EquipmentItem *equipItem = [equipmentList objectAtIndex:row];
    return [equipItem valueForKey:[aTableColumn identifier]];
}


@end
