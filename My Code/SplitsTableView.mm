//
//  SplitsTableView.mm
//  Ascent
//
//  Created by Rob Boyer on 9/22/07.
//  Copyright 2007 Montebello Software, LLC. All rights reserved.
//

#import "SplitsTableView.h"
#import "Track.h"
#import "Lap.h"
#import "ColumnHelper.h"
#import "ColumnInfo.h"


@implementation SplitsTableView


- (id) init
{
	self = [super init];
	if (self != nil) 
	{
		columnHelper = nil;
	}
	return self;
}

-(void)prepareToDie
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	columnHelper = nil;
}


- (void) dealloc
{
#if DEBUG_LEAKS
	NSLog(@"splits table view DEALLOC %x rc: %d\n", self, [self retainCount]);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


// default version of this causes an exception if clicked in a non-column area of the table
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if([theEvent type] == NSRightMouseDown || ([theEvent type] == 
											   NSLeftMouseDown && ([theEvent modifierFlags] & NSControlKeyMask)))
	{
		return [self menu];
	}
	return nil;
}


- (void) rebuild
{
	[columnHelper rebuild];
}


- (void)tableInfoLoaded:(NSNotification *)notification
{
	[self rebuild];
}


- (void)columnResized:(NSNotification *)aNotification
{
	[columnHelper columnResized:aNotification];
}


- (void)columnMoved:(NSNotification *)aNotification
{
	[columnHelper columnMoved:aNotification];
}


- (void) awakeFromNib
{
	SplitsTableStaticColumnInfo* stci = [[SplitsTableStaticColumnInfo alloc] init];
	columnHelper = [[ColumnHelper alloc] initWithTableView:self
											 staticColInfo:stci
											  dictSelector:@selector(splitsColInfoDict)
										   setDictSelector:@selector(setSplitsColInfoDict:)];
	[self rebuild];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(columnMoved:)
												 name:NSTableViewColumnDidMoveNotification
											   object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(columnResized:)
												 name:NSTableViewColumnDidResizeNotification
											   object:self];
}


-(void) buildSplitGraphItemPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd
{
	SplitsTableStaticColumnInfo* stci = [[SplitsTableStaticColumnInfo alloc] init];
	[p removeAllItems];
	if (ipd) [p addItemWithTitle:@" "];		// pull-down fills this with selected entry
	int num = [stci numPossibleColumns];
	int ctr = 0;
	for (int i=0; i<num; i++)
	{
		tColInfo* colInfo = [stci nthPossibleColumnInfo:i];
		if (!FLAG_IS_SET(colInfo->flags, kNotAValidSplitGraphItem))
		{
			[p addItemWithTitle:[NSString stringWithUTF8String:colInfo->menuLabel]];
			id menuItem = [p itemAtIndex:ctr] ;
			[menuItem setTag:i];
			++ctr;
		}
	}
}



@end
