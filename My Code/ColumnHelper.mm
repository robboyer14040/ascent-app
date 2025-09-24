//
//  ColumnHelper.mm
//  Ascent
//
//  Created by Robert Boyer on 9/28/07.
//  Copyright 2007 Montebello Software, LLC. All rights reserved.
//

#import "ColumnHelper.h"
#import "ColumnInfo.h"
#import "TrackBrowserDocument.h"
#import "BrowserInfo.h"
#import "Defs.h"


@interface MyTableHeaderView :  NSTableHeaderView
{
	ColumnHelper*		helper;
	NSMenu*             menuOfColumns;
	int                 lastClickedColumn;
}
- (MyTableHeaderView*) initWithHelper:(ColumnHelper*)h;
- (NSMenu *)menuOfColumns;
- (void)setMenuOfColumns:(NSMenu *)value;
@end


@interface ColumnHelper ()
{
    NSTableView*            tableView;
    TrackBrowserDocument*   tbDocument;
    SEL                     dictSelector;
    SEL                     setDictSelector;
    StaticColumnInfo*       staticColumnInfo;
}
@end


@implementation ColumnHelper

- (id) initWithTableView:(NSTableView*)view
		   staticColInfo:(StaticColumnInfo*)sci
			dictSelector:(SEL)dictSel
		 setDictSelector:(SEL)setDictSel
{
	if (self = [super init])
	{
		tableView = [view retain];
		staticColumnInfo = [sci retain];
		dictSelector = dictSel;
		setDictSelector = setDictSel;
		NSWindow* w = [tableView window];
		tbDocument = [[[NSDocumentController sharedDocumentController] documentForWindow:w] retain];
	}
	return self;
}

- (void) dealloc
{
    [tableView release];
    [staticColumnInfo release];
    [super dealloc];
}


- (TrackBrowserDocument*) document
{
	return (TrackBrowserDocument*) [[NSDocumentController sharedDocumentController] documentForWindow:[tableView window]];
}


- (void) docChanged
{
	[[self document] updateChangeCount:NSChangeDone];
}


- (void) buildColumnDict
{
	if (!tbDocument)
	{
		tbDocument = [self document];
	}
	
	if (tbDocument)
	{	
		int num = [staticColumnInfo numPossibleColumns];
		int i;
		int next = 0;
		//NSMutableDictionary* ciDict = [tbDocument tableInfoDict];
		NSMutableDictionary* ciDict = [tbDocument performSelector:dictSelector];
		if (ciDict == nil)
		{
			//NSDictionary* protoDict = [[BrowserInfo sharedInstance] colInfoDict];
			NSDictionary* protoDict = [[BrowserInfo sharedInstance] performSelector:dictSelector];
			ciDict = [[NSMutableDictionary alloc] initWithDictionary:protoDict copyItems:YES] ;      // COPY it
			//[tbDocument setTableInfoDict:ciDict];
			[tbDocument  performSelector:setDictSelector
							  withObject:ciDict];
		}
		
		NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:ciDict];
		[ciDict removeAllObjects];
		for (i=0; i<num; i++)
		{
			tColInfo* colInfo = [staticColumnInfo nthPossibleColumnInfo:i];
			ColumnInfo* ci = [[ColumnInfo alloc] initWithInfo:colInfo];
			int order = kNotInBrowser;
			if (([ci flags] & kDefaultField) != 0) order = next++;
			[ci setOrder:order];
			if (tempDict != nil)
			{
				ColumnInfo* ti = [tempDict objectForKey:[ci ident]];
				if (ti != nil) 
				{
					[ci setOrder:[ti order]];
					[ci setWidth:[ti width]];
				}
			}
			[ciDict setObject:ci forKey:[ci ident]];
		}
	}
}


- (void) removeAllColumns
{
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSArray* sortedKeysArray = [[ciDict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSUInteger num = [sortedKeysArray count];
	int i;
	for (i=0; i<num; i++)
	{
		id aKey = [sortedKeysArray objectAtIndex:i];
		ColumnInfo* ci = [ciDict objectForKey:aKey];
		int flags = [ci flags];
		if ((flags & kCantRemove) == 0)
		{  
			NSString* iden = [ci ident];
            NSInteger idx = [tableView columnWithIdentifier:iden];
			if (idx != -1)    // column is present, so remove it
			{
				NSTableColumn* col = [[tableView tableColumns] objectAtIndex:idx];
				[tableView removeTableColumn:col];
			}
		}
	}
}


-(NSMenu*) buildColumnMenu
{
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSMenu* menu = [[NSMenu alloc] init];
	NSArray* sortedKeysArray = [ciDict keysSortedByValueUsingSelector:@selector(compareUsingMenuName:)];
	int num = (int)[sortedKeysArray count];
	int i;
	for (i=0; i<num; i++)
	{
		id aKey = [sortedKeysArray objectAtIndex:i];
		/// ColumnInfo* ci = [ciDict objectForKey:aKey];
        id ci = ciDict[aKey];
        if (!ci) {
            NSLog(@"⚠️ No ColumnInfo for key %@", aKey);
            continue;
        }
        int flags = [ci flags];
        
		if ((flags & kCantRemove) == 0)
		{
#if 1
            id raw = (ci && [ci respondsToSelector:@selector(menuLabel)]) ? [ci menuLabel] : nil;
            NSString *title = nil;

            if ([raw isKindOfClass:[NSString class]]) {
                title = (NSString *)raw;
            } else if ([raw isKindOfClass:[NSAttributedString class]]) {
                title = [(NSAttributedString *)raw string];
            }

            // fallback options if still nil
            if (title.length == 0) {
                // try an alternate property or key
                if ([ci respondsToSelector:@selector(menuName)]) title = [ci menuName];
                else if ([ci isKindOfClass:[NSDictionary class]]) title = ci[@"menuLabel"] ?: ci[@"menuName"];
            }

            if (title.length == 0) {
                NSLog(@"⚠️ Missing menu title. ci=%@ (%@)", ci, [ci class]);
                title = @"(Untitled)";
            }

            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:title
                                                        action:@selector(doit:)
                                                 keyEquivalent:@""];
#else
			NSMenuItem* mi = [[NSMenuItem alloc] initWithTitle:[ci menuLabel] action:@selector(doit:) keyEquivalent:@""];
#endif
            NSCellStateValue state = ([ci order] == kNotInBrowser) ? NSControlStateValueOff : NSControlStateValueOn;
			[mi setState:state];
			[mi setTag:[ci colTag]];
			[menu  addItem:mi];
		}
	}
	return menu;
}



- (void) installColumn:(ColumnInfo*)ci 
{
	NSTableColumn* col = nil;
	if (([ci flags] & kCantRemove) == 0)
	{
		NSString* ii = [ci ident];
		col = [[NSTableColumn alloc] initWithIdentifier:ii];
		NSFormatter* fm = [ci formatter];
		if (fm != nil)
		{
			[[col dataCell] setFormatter:fm];
		}
		[[col headerCell] setStringValue:[ci title]];
		[tableView addTableColumn:col];
	}
	else
	{
		col = [tableView tableColumnWithIdentifier:[ci ident]];
	}
	if (col != nil)
	{
		float w = [ci width];
		[col setWidth:w];
		[col setMinWidth:40];
		[col setEditable:NO];
		if (([ci flags] & kLeftAlignment) != 0)
		{
			[[col dataCell] setAlignment:NSTextAlignmentLeft];
			[[col headerCell] setAlignment:NSTextAlignmentLeft];
		}
		else
		{
			[[col dataCell] setAlignment:NSTextAlignmentRight];
			[[col headerCell] setAlignment:NSTextAlignmentRight];
		}
	}
}


-(void)adjustLastColumn
{
    NSInteger numcols = [tableView numberOfColumns];
	if (numcols > 0)
	{
		NSTableColumn* col = [[tableView tableColumns] objectAtIndex:(numcols-1)];
		if (col)
		{
			NSRect crect = [tableView rectOfColumn:numcols-1];
			NSRect trect = [tableView bounds];
			float cwid = [col width];
			if (trect.size.width > (crect.origin.x + cwid))
			{
				float newW = (trect.size.width - crect.origin.x);
				[col setWidth:newW];
			}
		}
	}
}


- (void) etherealizeColumnsFromDict
{
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSArray *sortedKeysArray = [ciDict keysSortedByValueUsingSelector:@selector(compare:)];	// sort by 'order' field	
	int num = (int)[sortedKeysArray count];
	int i;
	for (i=0; i<num; i++)
	{
		NSString* aKey = [sortedKeysArray objectAtIndex:i];
		ColumnInfo* ci = [ciDict objectForKey:aKey];
		if ([ci order] != kNotInBrowser)
		{
			[self installColumn:ci];
		}
	}
	//[self adjustLastColumn];
	[tableView reloadData];
}


- (void) rebuild
{
	[self buildColumnDict];
	NSMenu* cm = [self buildColumnMenu];
	NSTableHeaderView* currentTableHeaderView = [tableView headerView];
	MyTableHeaderView* tableHeaderView = [[MyTableHeaderView alloc] initWithHelper:self];
	[tableHeaderView setFrame:[currentTableHeaderView frame]];
	[tableHeaderView setBounds:[currentTableHeaderView bounds]];
	[tableHeaderView setMenuOfColumns:cm];
	[tableView setHeaderView:tableHeaderView];
#ifdef DEBUG_RC
	NSLog(@"setHeaderView rc, before:%d after:%d\n", before, [tableHeaderView retainCount]);
#endif
	[cm autorelease];
	[self removeAllColumns];
	[self etherealizeColumnsFromDict];
}





- (ColumnInfo*) columnInfoFromTag:(int)tag
{
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSEnumerator *enumerator = [ciDict objectEnumerator];
	id value;
	
	while ((value = [enumerator nextObject])) 
	{
		if ([value tag] == tag) return value;
	}
	return nil;
}


- (void)updateOrder
{
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSArray* colArray = [tableView tableColumns];
	int next = 0;
    NSUInteger num = [colArray count];
	ColumnInfo* ci;
	for (int i=0; i<num; i++)
	{
		id ident = [[colArray objectAtIndex:i] identifier];
		//NSLog(@"column: %@\n", ident);
		ci = [ciDict objectForKey:ident];
		if (ci != nil) [ci setOrder:next++];
	}
}


- (void) columnize:(NSMenu*)colMenu item:(id)it colIndex:(int)colIndex
{
	NSMenuItem* mi = it;
	if ([mi state] == NSControlStateValueOn) 
		[mi setState:NSControlStateValueOff];
	else
		[mi setState:NSControlStateValueOn];
	int tag = (int)[mi tag];
	ColumnInfo* ci = [self columnInfoFromTag:tag];
	if (ci != nil)
	{
		int flags = [ci flags];
		if ((flags & kCantRemove) == 0)
		{
			NSTableColumn* col = nil;
			int idx = (int)[tableView columnWithIdentifier:[ci ident]];
			if (idx != -1)    // column is present, so remove it
			{
				col = [[tableView tableColumns] objectAtIndex:idx];
				[tableView removeTableColumn:col];
				[ci setOrder:kNotInBrowser];
			}
			else              // column is not present, so add it
			{
				[self installColumn:ci];
                NSInteger nc = [tableView numberOfColumns];
				if (nc > 2)
				{
                    NSInteger targetColIndex = colIndex;
					if (targetColIndex < 1) targetColIndex = 1;
					if (targetColIndex > (nc-1)) targetColIndex = nc-1;
					[tableView moveColumn:nc-1  
								 toColumn:targetColIndex];
				}
				[self updateOrder];
			}
		}
		[tableView reloadData];
		[self docChanged];
		// the following line of code causes a COPY to be stored in the BrowserInfo shared instance
		[[self document] performSelector:setDictSelector
							  withObject:[[self document] performSelector:dictSelector]];
	}
}




- (void)columnMoved:(NSNotification *)aNotification
{
	//NSLog(@"column moved...");
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	NSEnumerator *enumerator = [ciDict objectEnumerator];
	ColumnInfo* ci;
	
	while ((ci = [enumerator nextObject])) 
	{
		[ci setOrder:kNotInBrowser];
	}
	NSArray* colArray = [tableView tableColumns];
	int i;
    NSUInteger num = [colArray count];
	// can't let the user move col 0!!!  scan first for this possibility
	for (i=0; i<num; i++)
	{
		id ident = [[colArray objectAtIndex:i] identifier];
		BOOL isName = ([ident isEqualToString:@kCT_Name]);
		if (isName && (i == 0)) break;      // ok
		if ((i != 0) && isName)
		{
			[tableView moveColumn:i
						 toColumn:0];
			break;
		}
	}
	[self updateOrder];
	[self docChanged];
	[[self document] performSelector:setDictSelector
						  withObject:ciDict];
}


- (void)columnResized:(NSNotification *)aNotification
{
	//NSLog(@"column resized...");
	NSDictionary* dict = [aNotification userInfo];
	NSTableColumn* col = [dict objectForKey:@"NSTableColumn"];
	if ([[tableView headerView] resizedColumn] != -1)
	{
		NSString* s = [col identifier];
		//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
		NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
		ColumnInfo* ci = [ciDict objectForKey:s];
		if (ci != nil) 
		{
			[ci setWidth:[col width]];
		}
		[self docChanged];
		//[[tableView document] setTableInfoDict:ciDict];
		[tbDocument  performSelector:setDictSelector
						  withObject:ciDict];
		//[self adjustLastColumn];
	}
}


- (BOOL) columnUsesStringCompare:(NSString*)colIdent
{
	//NSMutableDictionary* ciDict = [[self document] tableInfoDict];
	NSMutableDictionary* ciDict = [[self document] performSelector:dictSelector];
	if (ciDict != nil)
	{
		ColumnInfo* ci = [ciDict objectForKey:colIdent];
		if (ci != nil)
		{
			return (([ci flags] & kUseStringComparator) != 0);
		}
	}
	return NO;
}



@end



//---- MyTableHeaderView implementation ---------------------------------------------------------------------

@implementation MyTableHeaderView

- (MyTableHeaderView*) initWithHelper:(ColumnHelper*)h
{
	self = [super init];
	helper = h;	// NOT retained!
	lastClickedColumn = 0;
	return self;
}


- (void) dealloc
{
    [super dealloc];
}

- (IBAction) doit:(id)sender
{
	[helper columnize:menuOfColumns item:sender colIndex:lastClickedColumn];
}



- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if([theEvent type] == NSEventTypeRightMouseDown || ([theEvent type] == 
											   NSEventTypeLeftMouseDown && ([theEvent modifierFlags] & NSEventModifierFlagControl)))
	{
		NSPoint point = [self convertPoint:[theEvent locationInWindow] 
								  fromView:NULL];
		lastClickedColumn = (int)[self columnAtPoint:point];
		return menuOfColumns;
	}
	//NSLog(@"menu for event, col:%d\n", lastClickedColumn);
	return nil;
}


- (NSMenu *)menuOfColumns {
	return menuOfColumns;
}

- (void)setMenuOfColumns:(NSMenu *)value {
	if (menuOfColumns != value) {
		[menuOfColumns release];
		menuOfColumns = [value copy];
	}
}


@end
