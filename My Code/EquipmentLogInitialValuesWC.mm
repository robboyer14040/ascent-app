//
//  EquipmentLogInitialValuesWC.mm
//  Ascent
//
//  Created by Rob on 1/20/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentLogInitialValuesWC.h"
#import "EquipmentLog.h"
#import "EquipmentItem.h"
#import "TrackBrowserDocument.h"
#import "Track.h"
#import "Utils.h"

@implementation EquipmentLogInitialValuesWC

- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"EquipmentLogInitialValues"];
	tbDocument = doc;					// NOT RETAINED
	equipmentLog = [doc equipmentLog];	// NOT RETAINED
	equipmentLogInitialData = [doc initialEquipmentLogData];		// NOT RETAINED
	alphaSortDescriptors = [NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"name"
																				  ascending:YES
																				   selector:@selector(localizedCaseInsensitiveCompare:)],
							 nil];
	return self;
}


-(void)dealloc
{
}	


-(void)awakeFromNib
{
	NSMutableArray* dateRangeArray = [NSMutableArray arrayWithArray:[tbDocument documentDateRange]];
	NSDate* startDate = [dateRangeArray objectAtIndex:0];
	NSDate* endDate = [dateRangeArray objectAtIndex:1];
	BOOL startPickerEnabled = NO;
	BOOL endPickerEnabled = NO;
	if ([startDate compare:[NSDate distantPast]] == NSOrderedSame)
	{
		[startDateMatrix setState:NSControlStateValueOn atRow:0 column:0];
	}
	else
	{
		[startDateMatrix setState:NSControlStateValueOn atRow:1 column:0];
		[startDatePicker setDateValue:[dateRangeArray objectAtIndex:0]];
		startPickerEnabled = YES;
	}
	if ([endDate compare:[NSDate distantFuture]] == NSOrderedSame)
	{
		[endDateMatrix setState:NSControlStateValueOn atRow:0 column:0];
	}
	else
	{
		[endDateMatrix setState:NSControlStateValueOn atRow:1 column:0];
		[endDatePicker setDateValue:[dateRangeArray objectAtIndex:1]];
		endPickerEnabled = YES;
	}
	[startDatePicker setEnabled:startPickerEnabled];
	[endDatePicker setEnabled:startPickerEnabled];
	
}


-(NSManagedObjectContext*)managedObjectContext
{
	return [[tbDocument equipmentLog] managedObjectContext];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	NSError* error = nil;
	[[equipmentLog managedObjectContext] save:&error];
	if (error)
	{
		[self presentError:error];
	}
	[NSApp stopModal];
}


-(IBAction)dismiss:(id)sender
{
	[[self window]  close];
}


-(IBAction)done:(id)sender
{
	[[self window]  close];
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

-(IBAction)setDate:(id)sender
{
	NSArray* trackArray = [tbDocument trackArray];
	NSMutableArray* dateRangeArray = [NSMutableArray arrayWithArray:[tbDocument documentDateRange]];
	if (sender == startDateMatrix)
	{
		NSDate* startDate = [NSDate distantPast];
		int tag = [[sender selectedCell] tag];
		BOOL pickerEnabled = NO;
		if (tag == 1)
		{
			pickerEnabled = YES;
			startDate = [startDatePicker dateValue];
		}
		[startDatePicker setEnabled:pickerEnabled];
		[dateRangeArray replaceObjectAtIndex:0 
								  withObject:startDate];
	}
	else if (sender == endDateMatrix)
	{
		NSDate* endDate = [NSDate distantFuture];
		int tag = [[sender selectedCell] tag];
		BOOL pickerEnabled = NO;
		if (tag == 1)
		{
			pickerEnabled = YES;
			endDate = [endDatePicker dateValue];
		}
		[endDatePicker setEnabled:pickerEnabled];
		[dateRangeArray replaceObjectAtIndex:1 
								  withObject:endDate];
	}
	else if (sender == startDatePicker)
	{
		NSDate* startDate = [startDatePicker dateValue];
		NSDate* endDate = [dateRangeArray objectAtIndex:1];
		if ([startDate compare:endDate] != NSOrderedDescending)
		{
			[dateRangeArray replaceObjectAtIndex:0 
									  withObject:startDate];
		}
	}
	else if (sender == endDatePicker)
	{
		NSDate* endDate = [endDatePicker dateValue];
		NSDate* startDate = [dateRangeArray objectAtIndex:0];
		if ([startDate compare:endDate] != NSOrderedDescending)
		{
			[dateRangeArray replaceObjectAtIndex:1 
									  withObject:endDate];
		}
	}
	else if (sender == setStartDateToFirstButton)
	{
		if ([trackArray count] > 0)
		{
			NSDate* startDate = [[trackArray objectAtIndex:0] creationTime];
			[dateRangeArray replaceObjectAtIndex:0 
									  withObject:startDate];
			[startDatePicker setEnabled:YES];
			[startDatePicker setDateValue:startDate];
			[startDateMatrix setState:NSControlStateValueOn atRow:1 column:0];
		}
	}
	else if (sender == setEndDateToLastButton)
	{
		if ([trackArray count] > 0)
		{
			NSDate* endDate = [[trackArray lastObject] creationTime];
			[dateRangeArray replaceObjectAtIndex:1
									  withObject:endDate];
			[endDatePicker setEnabled:YES];
			[endDatePicker setDateValue:endDate];
			[endDateMatrix setState:NSControlStateValueOn atRow:1 column:0];
		}
	}
	[tbDocument setDocumentDateRange:dateRangeArray];
}


//---- data source methods for equipment items


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[equipmentItemsArrayController arrangedObjects] count];
}


-(int)arrayIndexForIdentifier:(NSString*)ident
{
	int idx = -1;
	if ([ident isEqualToString:@"totalDistance"])
	{
		idx = 0;
	}
	else if ([ident isEqualToString:@"totalActiveTime"])
	{
		idx = 1;
	}
	else if ([ident isEqualToString:@"distSinceMaint"])
	{
		idx = 2;
	}
	else if ([ident isEqualToString:@"activeTimeSinceMaint"])
	{
		idx = 3;
	}
	return idx;
}


-(id)initialValueObjectForRow:(int)row arrayIndex:(int)idx
{
	id obj = nil;
	NSArray* eis = [equipmentItemsArrayController arrangedObjects];
	int count = [eis count];
	if (row < count)
	{
		EquipmentItem* ei = [eis objectAtIndex:row];
		if (ei && equipmentLogInitialData)
		{
			NSArray* arr = [equipmentLogInitialData objectForKey:ei.uniqueID];
			if (!arr)
			{
				arr = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0],
					   [NSNumber numberWithFloat:0.0], 
					   [NSNumber numberWithFloat:0.0], 
					   [NSNumber numberWithFloat:0.0], nil];
				[equipmentLogInitialData setValue:arr
										   forKey:ei.uniqueID];
			}
			if (arr) obj = [arr objectAtIndex:idx];
		}
	}
	return obj;
}


-(void)setInitialValueObjectForRow:(int)row arrayIndex:(int)idx val:(id)obj
{
	NSArray* eis = [equipmentItemsArrayController arrangedObjects];
	int count = [eis count];
	if (row < count)
	{
		EquipmentItem* ei = [eis objectAtIndex:row];
		if (ei && equipmentLogInitialData)
		{
			NSArray* arr = [equipmentLogInitialData objectForKey:ei.uniqueID];
			if (!arr)
			{
				arr = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0],
					   [NSNumber numberWithFloat:0.0], 
					   [NSNumber numberWithFloat:0.0], 
					   [NSNumber numberWithFloat:0.0], nil];
			}
			if (arr)
			{
				NSMutableArray* marr = [NSMutableArray arrayWithCapacity:4];
				[marr addObjectsFromArray:arr];
				[marr replaceObjectAtIndex:idx
								withObject:obj];
				[equipmentLogInitialData setValue:marr
										   forKey:ei.uniqueID];
				[tbDocument updateChangeCount:NSChangeDone];
			}
		}
	}
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSNumber* num = nil;
	int idx = [self arrayIndexForIdentifier:[aTableColumn identifier]];
	if (idx >= 0)
	{
		NSString* colIdent = [aTableColumn identifier];
		num = [self initialValueObjectForRow:rowIndex
								  arrayIndex:idx];
		if ([colIdent isEqualToString:@"totalDistance"] || 
			[colIdent isEqualToString:@"distSinceMaint"])
		{
			float v = [num floatValue];
			if (![Utils usingStatute])
			{
				v = MilesToKilometers(v);
				num = [NSNumber numberWithFloat:v];
			}
		}
	}
	return num;
}



- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString* colIdent = [aTableColumn identifier];
	int idx = [self arrayIndexForIdentifier:colIdent];
	if (idx >= 0)
	{
		NSNumber* num = (NSNumber*)anObject;
		if ([colIdent isEqualToString:@"totalDistance"] || 
			[colIdent isEqualToString:@"distSinceMaint"])
		{
			float v = [num floatValue];
			if (![Utils usingStatute])
			{
				v = KilometersToMiles(v);
				num = [NSNumber numberWithFloat:v];
			}
		}
		[self setInitialValueObjectForRow:rowIndex
							   arrayIndex:idx
									  val:num];
	}
}



//---- TableView delegate methods ----------------------------------------------

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
}


@end
