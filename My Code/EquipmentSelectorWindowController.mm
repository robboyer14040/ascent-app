//
//  EquipmentSelectorWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 12/29/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentSelectorWindowController.h"
#import "EquipmentListWindowController.h"
#import "TrackBrowserDocument.h"
#import "EquipmentLog.h"
#import "Track.h"
#import "EquipmentItem.h"
#import "EquipmentTrackinfo.h"
#import "Utils.h"


@implementation EquipmentSelectorWindowController

@synthesize showEquipmentLogOnExit;
@synthesize selectedItemsIndexSet;

-(NSManagedObjectContext*)managedObjectContext
{
	return [[tbDocument equipmentLog] managedObjectContext];
}


-(void)updateCurrentSelection:(id)sender
{
	NSMutableIndexSet* mis = [NSMutableIndexSet indexSet];
	NSArray* eis = [equipmentItemsArrayController arrangedObjects];
	int count = [eis count];
	for (int i=0; i<count; i++)
	{
		EquipmentItem* ei = [eis objectAtIndex:i];
		if (ei)
		{
			BOOL uses = [ei usesForTrack:[tbDocument.windowControllers.firstObject currentlySelectedTrack]];
			if (uses) [mis addIndex:i];
		}
	}
	self.selectedItemsIndexSet = mis;
	[equipmentTable selectRowIndexes:selectedItemsIndexSet
				byExtendingSelection:NO];
	[equipmentItemsArrayController setSelectionIndexes:selectedItemsIndexSet];
	[equipmentTable scrollRowToVisible:[mis firstIndex]];

}


- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"EquipmentSelector"];
	selectedItemsIndexSet = nil;
	tbDocument = doc;					// NOT RETAINED
	equipmentLog = [doc equipmentLog];	// NOT RETAINED
	showEquipmentLogOnExit = NO;
	alphaSortDescriptors = [NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"name"
																				  ascending:YES
																				   selector:@selector(localizedCaseInsensitiveCompare:)],
							 nil];
	//NSLog(@"init with document");
	[equipmentItemsArrayController setAutomaticallyPreparesContent:YES];
	[equipmentItemsArrayController rearrangeObjects];
	return self;
}


-(void)dealloc
{
    [super dealloc];
}


-(void)awakeFromNib
{
	//NSLog(@"awake from NIB");
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	NSError* error = nil;
	[[[tbDocument equipmentLog] managedObjectContext] save:&error];
	if (error)
	{
		[self presentError:error];
	}
	[NSApp stopModal];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	//NSLog(@"did become key");
	[useAsDefaultsButton setState:NSControlStateValueOff];
	[equipmentItemsArrayController rearrangeObjects];
	[self performSelector:@selector(updateCurrentSelection:)
			   withObject:nil
			   afterDelay:0.5];
}



-(IBAction)dismiss:(id)sender
{
	[[self window]  close];
}


-(IBAction)done:(id)sender
{
	[[self window]  close];
	[equipmentTable setDelegate:nil];
	[equipmentTable setDataSource:nil];
	
	Track* track = [tbDocument currentlySelectedTrack];
	if (track)
	{
		NSIndexSet* sis = [equipmentItemsArrayController selectionIndexes];
		NSArray* eis = [equipmentItemsArrayController arrangedObjects];
		for (EquipmentItem* ei in eis)
		{
			[ei setUsesForTrack:track
				   equipmentLog:equipmentLog
						   used:NO];
		}
		[track setEquipmentUUIDs:nil];
		NSUInteger idx = [sis firstIndex];
		NSMutableArray* eqUUIDs = [NSMutableArray arrayWithCapacity:[sis count]];
		while (idx != NSNotFound)
		{
			EquipmentItem* ei = [eis objectAtIndex:idx];
			if (ei)
			{
				[ei setUsesForTrack:track
					   equipmentLog:equipmentLog
							   used:YES];
				[eqUUIDs addObject:ei.uniqueID];
			}
			idx = [sis indexGreaterThanIndex:idx];
		}
		[track setEquipmentUUIDs:eqUUIDs];
		NSString* eqStr = [[equipmentLog equipmentItemNamesForTrack:track] componentsJoinedByString:@","];
		if (eqStr)
		{
			[track setAttribute:kEquipment
					usingString:eqStr];
			[track setEquipmentWeight:[equipmentLog equipmentWeightForTrack:track]];
			///[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" object:track];
		}
		tbDocument.equipmentTotalsNeedUpdate = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"EquipmentLogChanged" object:tbDocument];
		NSError* error;
		[[[EquipmentLog sharedInstance] managedObjectContext] save:&error];
	}
	if ([useAsDefaultsButton state] == NSControlStateValueOn)
	{
		[equipmentLog setCurrentEquipmentItemsAsDefault:tbDocument];
	}
}


-(NSArray*)alphaSort
{
	return alphaSortDescriptors;
}


-(void)setAlphaSort:(NSArray*)arr
{
	if (arr != alphaSortDescriptors)
	{
		alphaSortDescriptors = arr;
	}
}

-(IBAction)showEquipmentLog:(id)sender
{
	showEquipmentLogOnExit = YES;
	[self dismiss:self];
}


-(IBAction)setCurrentAsDefault:(id)sender
{
}



//---- data source methods for equipment items


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[equipmentItemsArrayController arrangedObjects] count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	id obj = nil;
	if ([[aTableColumn identifier] isEqualToString:@"used"])
	{
		BOOL uses = NO;
		NSArray* eis = [equipmentItemsArrayController arrangedObjects];
        NSUInteger count = [eis count];
		if (rowIndex < count)
		{
			EquipmentItem* ei = [eis objectAtIndex:rowIndex];
			if (ei)
			{
				uses = [ei usesForTrack:[tbDocument currentlySelectedTrack]];
			}
		}
		obj = [NSNumber numberWithBool:uses];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"main"])
	{
		BOOL uses = NO;
		NSArray* eis = [equipmentItemsArrayController arrangedObjects];
        NSUInteger count = [eis count];
		if (rowIndex < count)
		{
			EquipmentItem* ei = [eis objectAtIndex:rowIndex];
			if (ei)
			{
				uses = [ei mainForTrack:[tbDocument currentlySelectedTrack]];
			}
		}
		obj = [NSNumber numberWithBool:uses];
	}
	return obj;
}



- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSArray* eis = [equipmentItemsArrayController arrangedObjects];
	if ([[aTableColumn identifier] isEqualToString:@"used"])
	{
        NSUInteger count = [eis count];
		if (rowIndex < count)
		{
			EquipmentItem* ei = [eis objectAtIndex:rowIndex];
			if (ei)
			{
				Track* t = [tbDocument currentlySelectedTrack];
				BOOL uses = [anObject boolValue];
				[ei setUsesForTrack:t
					   equipmentLog:equipmentLog
							   used:uses];
				if (!uses)
				{
					[ei setMainForTrack:t
						   equipmentLog:equipmentLog
								   main:NO];
				}
				[aTableView reloadData];		// fixme
				[t setEquipmentUUIDs:[equipmentLog equipmentUUIDsForTrack:t]];
			}
		}
	}
	else if ([[aTableColumn identifier] isEqualToString:@"main"])
	{
        NSUInteger count = [eis count];
		if (rowIndex < count)
		{
			EquipmentItem* ei = [eis objectAtIndex:rowIndex];
			if (ei)
			{
				[ei setMainForTrack:[tbDocument currentlySelectedTrack]
					   equipmentLog:equipmentLog
							   main:[anObject boolValue]];
				[aTableView reloadData];		// fixme
			}
		}
	}
}

//---- TableView delegate methods ----------------------------------------------

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"main"])
	{
		BOOL uses = NO;
		NSArray* eis = [equipmentItemsArrayController arrangedObjects];
        NSUInteger count = [eis count];
		if (rowIndex < count)
		{
			EquipmentItem* ei = [eis objectAtIndex:rowIndex];
			if (ei)
			{
				uses = [ei usesForTrack:[tbDocument currentlySelectedTrack]];
			}
		}
		[aCell setEnabled:uses];
	}
}


- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
}



@end
