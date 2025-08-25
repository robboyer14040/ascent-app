//
//  EquimentListWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/28/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentListWindowController.h"
#import "TrackBrowserDocument.h"
#import "TBWindowController.h"
#import "EquipmentLog.h"
#import "EquipmentItem.h"
#import "EquipmentLogInitialValuesWC.h"
#import "Utils.h"
#import <Quartz/Quartz.h>


@implementation MaintArrayController

-(void)setDocument:(TrackBrowserDocument*)tbd
{
	tbDocument = tbd;		// NOT retained
}

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index
{
	NSArray* dateRangeArray = [tbDocument documentDateRange];
	NSDate* mdate = [NSDate date];
	if (dateRangeArray && [dateRangeArray count] > 1)
	{
		NSDate* endDate = [dateRangeArray objectAtIndex:1];
		if ([mdate compare:endDate] == NSOrderedDescending) 
		{
			mdate = endDate;
		}
	}
	[object setDate:mdate];
	[super insertObject:object
  atArrangedObjectIndex:index];
}

@end


@implementation EquipmentListWindowController

@synthesize forceSelectionUUID;

- (id)initWithDocument:(TrackBrowserDocument*)tbd
{
	forceSelectionUUID = nil;
	tbDocument = tbd;					// NOT RETAINED
	equipmentLog = [tbd equipmentLog];	// NOT RETAINED
	equipmentLogInitialData = [tbd initialEquipmentLogData];		// NOT RETAINED
	self = [super initWithWindowNibName:@"EquipmentList"];
	alphaSortDescriptors = [[NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"name"
																				  ascending:YES
																				   selector:@selector(localizedCaseInsensitiveCompare:)],
							 nil] retain];

	dateSortDescriptors = [[NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"date"
																				 ascending:NO],
							 nil] retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(logChanged:)
												 name:@"EquipmentLogChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(lastMaintenanceDateChanged:)
												 name:@"LastMaintenanceDateChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:@"PreferencesChanged"
											   object:nil];
	return self;
}


-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [equipmentTable setDataSource:nil];
    [equipmentTable setDelegate:nil];
	[forceSelectionUUID release];
	[alphaSortDescriptors release];
	[dateSortDescriptors release];
	[super dealloc];
}	




-(void)updateWeightField
{
	BOOL isStatute = [Utils usingStatute];
	if (isStatute)
	{
		[weightUnitsTextField setStringValue:@"lbs"];
	}
	else
	{
		[weightUnitsTextField setStringValue:@"kg"];
	}
	id ei = [[equipmentItemsArrayController selectedObjects] lastObject];
	if (ei) [ei setValue:[ei valueForKey:@"weight"]
				  forKey:@"weight"];
	[weightTextField setNeedsDisplay:YES];
}


-(void)setMaintFilter:(NSPredicate*)mf
{
}


-(NSPredicate*) maintFilter
{
	return [equipmentLog maintFilterForDocument:tbDocument];
}


-(void)updateMaintenaceLogFilter
{
	[maintenanceLogArrayController setFilterPredicate:[self maintFilter]];
}


-(void)awakeFromNib
{
	[[self window] setFrameAutosaveName:@"EQLogWindowFrame"];
	if (![[self window] setFrameUsingName:@"EQLogWindowFrame"])
	{
		[[self window] center];
	}
	//[equipmentItemsArrayController addObserver:self
	//								forKeyPath:@"selectedObjects"
	//								   options:0
	//								   context:nil];
//    IKPictureTaker *picker = [IKPictureTaker pictureTaker];
//	NSString* path = [[NSBundle mainBundle] pathForResource:@"road bike" ofType:@"jpg"];
//	NSImage* img = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
//	[picker setInputImage:img];
	[typeComboBox setDataSource:self];
	[[self window] setTitle:[NSString stringWithFormat:@"Equipment Log for %@", [tbDocument displayName]]];
	[self updateWeightField];
	[equipmentTable deselectAll:self];
	[equipmentItemsArrayController setSelectionIndexes:[NSIndexSet indexSet]];
	[equipmentItemsArrayController setSortDescriptors:alphaSortDescriptors];
	[maintTable setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	[self updateMaintenaceLogFilter];
	[maintTable setAutosaveName:@"EQLogMaintTable"];
	[maintTable setAutosaveTableColumns:YES];
}


-(void) logChanged:(NSNotification *)notification
{
	if ([notification object] == tbDocument)
	{
		[equipmentLog updateTotalsForDocument:tbDocument
								 showProgress:YES 
							 windowController:self];
		[equipmentTable reloadData];
	}
}


- (void)prefsChanged:(NSNotification *)notification
{
	[equipmentTable reloadData];
	[maintTable reloadData];
	[self updateWeightField];
}



-(void)lastMaintenanceDateChanged:(NSNotification *)notification
{
	//NSLog(@"last maintenance date changed!");
	tbDocument.equipmentTotalsNeedUpdate = YES;
	[equipmentLog updateTotalsForDocument:tbDocument
							 showProgress:YES
						 windowController:self];
	[equipmentTable reloadData];
}


// enable undo/redo in core data world
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender 
{
    return [[[tbDocument equipmentLog] managedObjectContext] undoManager];
}


#if 0
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSArray* selectedObjects = [equipmentItemsArrayController selectedObjects];
	if ([selectedObjects count] > 0)
	{
		id o = [selectedObjects objectAtIndex:0];
		[o description];
	}
}
#endif


-(void)doUpdate:(id)sender
{
	[equipmentLog updateTotalsForDocument:tbDocument
							 showProgress:YES
						 windowController:self];
	[equipmentTable reloadData];
	[maintTable reloadData];
}


- (void)windowDidLoad
{
	[maintenanceLogArrayController setDocument:tbDocument];
	// prevent blinking the main window after the progress bar dismisses
	// by deferring this method
#if 1
	[self performSelector:@selector(doUpdate:)
			   withObject:self
			   afterDelay:0.1];
#else
    [self doUpdate:self];
#endif
}


- (void)windowWillClose:(NSNotification *)aNotification
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[self window] makeFirstResponder:nil];
	NSError* error = nil;
	[[[EquipmentLog sharedInstance] managedObjectContext] save:&error];
	if (error)
	{
		[self presentError:error];
	}
	TBWindowController* wc = [tbDocument windowController];
	[wc dismissEquipmentList:self];
}

-(void)updateMaintLog:(id)junk
{
	[maintenanceLogArrayController rearrangeObjects];
	[[EquipmentLog sharedInstance] updateTotalsForDocument:tbDocument
											  showProgress:YES 
										  windowController:self];
	[maintTable reloadData];
	[equipmentTable reloadData];
}


- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index
{
	
}



-(IBAction)addMaintItem:(id)sender
{
	// NOTE: add/remove operations don't really happen until next iteration of event loop!
	[maintenanceLogArrayController add:sender];
	[[[EquipmentLog sharedInstance] managedObjectContext] processPendingChanges];
	tbDocument.equipmentTotalsNeedUpdate = YES;
	[self performSelector:@selector(updateMaintLog:) 
			   withObject:nil 
			   afterDelay:0.2];
}


-(IBAction)removeMaintItem:(id)sender
{
	// NOTE: add/remove operations don't really happen until next iteration of event loop!
	[maintenanceLogArrayController remove:sender];
	[[[EquipmentLog sharedInstance] managedObjectContext] processPendingChanges];
	tbDocument.equipmentTotalsNeedUpdate = YES;
	[self performSelector:@selector(updateMaintLog:) 
			   withObject:nil 
			   afterDelay:0.2];
}


-(void)updateCurrentTrack:(id)junk
{
	// need to force equipment box to update
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" 
														object:[tbDocument currentlySelectedTrack]];
}


-(void)updateEquipmentListAfterAdd:(id)junk
{
	[equipmentItemsArrayController rearrangeObjects];
	[equipmentTable reloadData];
}


-(IBAction)addEquipmentItem:(id)sender
{
	// NOTE: add/remove operations don't really happen until next iteration of event loop!
	[equipmentItemsArrayController add:sender];
	[self performSelector:@selector(updateEquipmentListAfterAdd:) 
			   withObject:nil 
			   afterDelay:0.2];
}


-(IBAction)removeEquipmentItem:(id)sender
{
	// NOTE: add/remove operations don't really happen until next iteration of event loop!
	[equipmentItemsArrayController remove:sender];
	[self performSelector:@selector(updateCurrentTrack:) 
			   withObject:nil 
			   afterDelay:0.5];
}


-(IBAction)editItem:(id)sender
{
}


-(IBAction)dismiss:(id)sender
{
	[[self window]  close];
}

-(NSManagedObjectContext*)managedObjectContext
{
	return [[EquipmentLog sharedInstance] managedObjectContext];
}

-(NSArray*)alphaSort
{
	return alphaSortDescriptors;
}


-(void)setAlphaSort:(NSArray*)arr
{
	if (arr != alphaSortDescriptors)
	{
		[alphaSortDescriptors release];
		alphaSortDescriptors = [arr retain];
	}
}


-(NSArray*)dateSort
{
	return dateSortDescriptors;
}


-(void)setDateSort:(NSArray*)arr
{
	if (arr != dateSortDescriptors)
	{
		[dateSortDescriptors release];
		dateSortDescriptors = [arr retain];
	}
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	///printf("wtf?\n");
}


-(IBAction)setName:(id)sender
{
	EquipmentItem* ei = [[equipmentItemsArrayController selectedObjects] lastObject];
	if (!ei) return;
	NSString* name = [sender stringValue];
	name = [name stringByReplacingOccurrencesOfString:@"," 
										   withString:@" "];
	[ei setName:name];
	[equipmentLog updateEquipmentAttributeForTracksContainingEquipmentItem:[ei uniqueID]
																  document:tbDocument
																		wc:self];
	[self updateEquipmentListAfterAdd:nil];
}


-(void)add:(id)sender
{
	EquipmentItem* ei = [NSEntityDescription insertNewObjectForEntityForName:@"EquipmentItem"
													  inManagedObjectContext:[[tbDocument equipmentLog] managedObjectContext]];
	
	if (ei)
	{
		[ei setDefaultFields:equipmentLog];
		[equipmentItemsArrayController setSelectedObjects:[NSArray arrayWithObject:ei]];
		[equipmentTable scrollRowToVisible:[equipmentItemsArrayController selectionIndex]];
	}
}



-(NSIndexSet*)forcedSelectionSet
{
	NSIndexSet* ret = nil;
	if (self.forceSelectionUUID)
	{
	// lame linear search here, @@FIXME@@
		NSArray* arr = [equipmentItemsArrayController arrangedObjects];
		int count = [arr count];
		for (int i=0; i<count; i++)
		{
			EquipmentItem* e = [arr objectAtIndex:i];
			if ([self.forceSelectionUUID isEqualToString:[e uniqueID]])
			{
				ret = [NSIndexSet indexSetWithIndex:i];
				break;
			}
		}
	}
	return ret;
}


-(void)selectEquipmentItemWithUniqueID:(NSString*)uuid
{
	EquipmentItem* ei = [equipmentLog fetchObjectUsingStringValue:uuid
														   forKey:@"uniqueID"
														   entity:@"EquipmentItem"];
	if (ei)
	{
		self.forceSelectionUUID = ei.uniqueID;
		NSIndexSet* fs = [self forcedSelectionSet];
		if (fs)
		{
			[equipmentTable scrollRowToVisible:[fs firstIndex]];
			[equipmentTable selectRowIndexes:fs
						byExtendingSelection:NO];
			self.forceSelectionUUID = nil;
		}
	}
}

#if 0
- (void) pictureTakerDidEnd:(IKPictureTaker*) pictureTaker code:(int) returnCode contextInfo:(void*) ctxInf
{
 	id ei = [[equipmentItemsArrayController selectedObjects] lastObject];
	if (!ei) return;
	if (returnCode == NSOKButton)
	{
        NSImage *outputImage = [pictureTaker outputImage];
		NSSize sz = [outputImage size];
		NSRect offscreenRect = NSMakeRect(-10000.0, -10000.0,
										  sz.width, sz.height);
		NSWindow* offscreenWindow = [[NSWindow alloc]
									 initWithContentRect:offscreenRect
									 styleMask:NSBorderlessWindowMask
									 backing:NSBackingStoreRetained
									 defer:NO];
		
		NSImageView* iv = [[[NSImageView alloc] init] autorelease];
		[iv setImage:outputImage];
		[offscreenWindow setContentView:iv];
		[[offscreenWindow contentView] display]; // Draw to the backing  buffer
		
		// Create the NSBitmapImageRep
		[[offscreenWindow contentView] lockFocus];
		NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
								 NSMakeRect(0, 0, sz.width, sz.height)];
		
		// Clean up and delete the window, which is no longer needed.
		[[offscreenWindow contentView] unlockFocus];
		[offscreenWindow release];	
		
		NSData* data = [rep representationUsingType:NSPNGFileType 
										 properties:nil];
		NSString *destPath = [Utils applicationSupportPath];
		NSString* guid = [[NSProcessInfo processInfo] globallyUniqueString];
		destPath = [destPath stringByAppendingPathComponent:@"Equipment Images"];
		[Utils verifyDirAndCreateIfNecessary:destPath];
		destPath = [destPath stringByAppendingPathComponent:guid];
		if ([[NSFileManager defaultManager] createFileAtPath:destPath
													contents:data
												  attributes:nil])
		{
			[ei setValue:destPath
				  forKey:@"imagePath"];
			[ei setUserSuppliedImage:YES];
		}
    }
}
#endif

-(IBAction)showEquipmentLogInitialValues:(id)sender
{
	EquipmentLogInitialValuesWC* eswc = [[EquipmentLogInitialValuesWC alloc] initWithDocument:tbDocument];
	
	NSRect fr = [[self window] frame];
	NSRect panelRect = [[eswc window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
	
	[[eswc window] setFrameOrigin:origin];
	NSModalSession session = [NSApp beginModalSessionForWindow:[eswc window]];
	int result = NSRunContinuesResponse;
	
	// Loop until some result other than continues:
	while (result == NSRunContinuesResponse)
	{
		// Run the window modally until there are no events to process:
		result = [NSApp runModalSession:session];
		
		// Give the main loop some time:
		[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
	}
	
	[NSApp endModalSession:session];
	[[self window] makeKeyAndOrderFront:self];
	[eswc autorelease];
	tbDocument.equipmentTotalsNeedUpdate = YES;
	[[EquipmentLog sharedInstance] updateTotalsForDocument:tbDocument
											  showProgress:YES 
										  windowController:self];
	[self updateMaintenaceLogFilter];
	[self updateMaintLog:nil];
}	


-(IBAction)setImage:(id)sender
{
//	IKPictureTaker *picker = [IKPictureTaker pictureTaker];
//	[picker setTitle:@"Equipment Picture"];
//	[picker setValue:[NSNumber numberWithBool:YES]
//			  forKey:IKPictureTakerShowEffectsKey];
//	[picker beginPictureTakerSheetForWindow:[equipmentImageView window]
//							   withDelegate:self
//							 didEndSelector:@selector(pictureTakerDidEnd:code:contextInfo:)
//								contextInfo:nil];
}


-(IBAction)setEquipmentType:(id)sender
{
	EquipmentItem* ei = [[equipmentItemsArrayController selectedObjects] lastObject];
	if (!ei) return;
	NSArray* arrangedObjs = [equipmentTypesArrayController arrangedObjects];
	int idx = [sender indexOfSelectedItem];
	int ct = [arrangedObjs count];	// 'count' returns unsigned int
	if (IS_BETWEEN(0, idx, (ct-1)))
	{
		id et = [arrangedObjs objectAtIndex:idx];
	
		[ei setValue:et
			  forKey:@"type"];
		if (![ei userSuppliedImage])
		{
			[ei setValue:[et valueForKey:@"imagePath"]
				  forKey:@"imagePath"];
		}
		if (![ei userSuppliedWeight])
		{
			[ei setValue:[et valueForKey:@"defaultWeight"]
				  forKey:@"weight"];
		}
	}
}


-(IBAction)setDateAcquired:(id)sender
{
}


-(IBAction)setDocumentInitialValues:(id)sender
{
}


//---- data source methods for equipment items and maintenance list


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[equipmentItemsArrayController arrangedObjects] count];
}


-(float)initialEquipmentLogDataValue:(NSString*)eid index:(int)idx
{
	float val = 0;
	NSArray* arr = [equipmentLogInitialData objectForKey:eid];
	if (arr)
	{
		val = [[arr objectAtIndex:idx] floatValue];
	}
	return val;
}


-(NSSet*)filteredMaintenanceLogsForEquipmentItem:(EquipmentItem*)ei
{
	NSSet* maintenanceLogs = [ei maintenanceLogs];
	maintenanceLogs = [maintenanceLogs filteredSetUsingPredicate:[self maintFilter]];
	return maintenanceLogs;
}	


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	id obj = nil;
	NSArray* eis = [equipmentItemsArrayController arrangedObjects];
	if (aTableView == equipmentTable)
	{
		EquipmentItem* ei = [eis objectAtIndex:rowIndex];
		NSSet* maintenanceLogs = [self filteredMaintenanceLogsForEquipmentItem:ei];
		
		if ([[aTableColumn identifier] isEqualToString:@"name"])
		{
			obj = [ei name];
		}
		else if ([[aTableColumn identifier] isEqualToString:@"totalDistance"])
		{
			float v = [tbDocument getEquipmentDataAtIndex:0
										forEquipmentNamed:[ei uniqueID]];
			v += [self initialEquipmentLogDataValue:ei.uniqueID
											  index:0];
			v = [Utils convertDistanceValue:v];
			obj = [NSNumber numberWithFloat:v];
		}
		else if ([[aTableColumn identifier] isEqualToString:@"totalTime"])
		{
			float v = [tbDocument getEquipmentDataAtIndex:1
										forEquipmentNamed:[ei uniqueID]];
			v += [self initialEquipmentLogDataValue:ei.uniqueID
											  index:1];
			obj = [NSNumber numberWithFloat:v];
		}
		if ([[aTableColumn identifier] isEqualToString:@"distanceSinceMaintenance"])
		{
			float v = [tbDocument getEquipmentDataAtIndex:2
										forEquipmentNamed:[ei uniqueID]];
			if (!maintenanceLogs || [maintenanceLogs count] == 0)
			{
				v += [self initialEquipmentLogDataValue:ei.uniqueID
												  index:2];
			}
			v = [Utils convertDistanceValue:v];
			obj = [NSNumber numberWithFloat:v];
		}
		else if ([[aTableColumn identifier] isEqualToString:@"timeSinceMaintenance"])
		{
			float v = [tbDocument getEquipmentDataAtIndex:3
										forEquipmentNamed:[ei uniqueID]];
			if (!maintenanceLogs || [maintenanceLogs count] == 0)
			{
				v += [self initialEquipmentLogDataValue:ei.uniqueID
												  index:3];
			}
			obj = [NSNumber numberWithFloat:v];
		}
	}
	else if (aTableView == maintTable)
	{
		NSArray* selObjs = [equipmentItemsArrayController selectedObjects];
		if ([selObjs count] > 0)
		{
			EquipmentItem* ei = [selObjs lastObject];
			// should be sorted from most recent date to oldest
			NSSet* maintenanceLogs = [self filteredMaintenanceLogsForEquipmentItem:ei];
			int numLogs = maintenanceLogs ? [maintenanceLogs count] : 0;
			if ([[aTableColumn identifier] isEqualToString:@"dist"])
			{
				float v = 0.0;
				if ((numLogs > 0) && ((rowIndex+1) == numLogs))
				{
					v = [self initialEquipmentLogDataValue:ei.uniqueID
													 index:2];
				}
				v += [tbDocument getEquipmentDataAtIndex:4 + (rowIndex*2)
									   forEquipmentNamed:[ei uniqueID]];
				v = [Utils convertDistanceValue:v];
				obj = [NSNumber numberWithFloat:v];
			}
			else if ([[aTableColumn identifier] isEqualToString:@"time"])
			{
				float v;
				if ((numLogs > 0) && ((rowIndex+1) == numLogs))
				{
					v = [self initialEquipmentLogDataValue:ei.uniqueID
													 index:3];
				}
				v += [tbDocument getEquipmentDataAtIndex:5 + (rowIndex*2)
									  forEquipmentNamed:[ei uniqueID]];
				v = [Utils convertDistanceValue:v];
				obj = [NSNumber numberWithFloat:v];
			}
			else if ([[aTableColumn identifier] isEqualToString:@"cumDist"])
			{
				float v = [tbDocument getCumulativeEquipmentDataStartingAtIndex:4 + (rowIndex*2)
															  forEquipmentNamed:[ei uniqueID]];
				v += [self initialEquipmentLogDataValue:ei.uniqueID
												  index:0];
				v = [Utils convertDistanceValue:v];
				obj = [NSNumber numberWithFloat:v];
			}
			else if ([[aTableColumn identifier] isEqualToString:@"cumTime"])
			{
				float v = [tbDocument getCumulativeEquipmentDataStartingAtIndex:5 + (rowIndex*2)
															  forEquipmentNamed:[ei uniqueID]];
				v += [self initialEquipmentLogDataValue:ei.uniqueID
												  index:1];
				obj = [NSNumber numberWithFloat:v];
			}
		}
	}
	return obj;
}



- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == equipmentTable)
	{
		NSArray* eis = [equipmentItemsArrayController arrangedObjects];
		EquipmentItem* ei = [eis objectAtIndex:rowIndex];
		if ([[aTableColumn identifier] isEqualToString:@"name"])
		{
			NSString* name = [anObject stringByReplacingOccurrencesOfString:@"," 
																 withString:@" "];
			[ei setName:name];
			[equipmentItemsArrayController rearrangeObjects];
			[equipmentLog updateEquipmentAttributeForTracksContainingEquipmentItem:[ei uniqueID]
																		  document:tbDocument
																				wc:self];
			[aTableView reloadData];
		}
	}
	else if (aTableView == maintTable)
	{
		[self updateMaintLog:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"LastMaintenanceDateChanged" object:self];
#if 0
		[self performSelector:@selector(updateMaintLog:) 
				   withObject:nil 
				   afterDelay:0.3];
#endif
	}
}


//---- Equipment Table Delegate methods ----------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
 	id ei = [[equipmentItemsArrayController selectedObjects] lastObject];
	if (!ei) return;
		NSManagedObject* et = [ei valueForKey:@"type"];
	if (et)
	{
		NSString* name = [et valueForKey:@"name"];
		if (name)
		{
			[typeComboBox setStringValue:name];
		}
	}
}


#if 0
// does not work first time
- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
	NSIndexSet* ret;
	NSIndexSet* fs = [self forcedSelectionSet];
	if (fs != nil)
	{
		self.forceSelectionUUID = nil;
		ret = fs;
	}
	else
	{
		ret = proposedSelectionIndexes;
	}
	return ret;
}
#endif


- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return YES;
}



//---- Type ComboBox Delegate methods ------------------------------------------

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
}


//---- Type ComboBox Datasource methods ----------------------------------------

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
	NSString* s = @"";
	NSArray* arrangedObjs = [equipmentTypesArrayController arrangedObjects];
	int ct = [arrangedObjs count];	// 'count' returns unsigned int
	if (IS_BETWEEN(0, index, (ct-1)))
	{
		id et = [arrangedObjs objectAtIndex:index];
		s = [et valueForKey:@"name"];
	}
	return s;
}


- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	NSArray* arrangedObjs = [equipmentTypesArrayController arrangedObjects];
	return [arrangedObjs count];
}


//---- TextField delegate methods ----------------------------------------------

#if 0
- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector 
{
	BOOL retval = NO;
	if (commandSelector == @selector(insertNewline:)) 
	{
		retval = YES;
		if (control == notesTextField) 
		{
			[fieldEditor insertNewlineIgnoringFieldEditor:nil];
			[control validateEditing];
		}
		else
		{
			[fieldEditor insertTab:self];
		}
			
	}
	return retval;
}
#endif


@end
