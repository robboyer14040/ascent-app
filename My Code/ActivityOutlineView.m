//
//  ActivityOutlineView.m
//  Ascent
//
//  Created by Rob Boyer on 11/20/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "ActivityOutlineView.h"
#import "Defs.h"
#import "ColumnInfo.h"
#import "TrackBrowserDocument.h"
#import "BrowserInfo.h"


@interface MyTableHeaderView :  NSTableHeaderView
{
   NSMenu*              menuOfColumns;
   ActivityOutlineView* activityOutlineView;
   int                  lastClickedColumn;
}
- (MyTableHeaderView*) initWithView:(ActivityOutlineView*)av;
- (NSMenu *)menuOfColumns;
- (void)setMenuOfColumns:(NSMenu *)value;


@end



//--------------------------------------------------------------------------------------------------------------
//---- ActivityOutlineView -------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------





@implementation ActivityOutlineView

- (id) init
{
   self = [super init];
   if (self != nil) 
   {
      tableHeaderView = nil;
   }
   return self;
}


- (void) dealloc
{
   NSLog(@"aov DEALLOC %x rc: %d", self, [self retainCount]);
   [[NSNotificationCenter defaultCenter] removeObserver:self];
   [[NSNotificationCenter defaultCenter] removeObserver:self];
   [super dealloc];
}


- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
   if (([menuItem action] == @selector(copy:)) ||
       ([menuItem action] == @selector(cut:)) ||
       ([menuItem action] == @selector(delete:)))
   {
      return ([self numberOfSelectedRows] > 0);
   }
   else if  ([menuItem action] == @selector(paste:))
   {
      return ([[NSPasteboard generalPasteboard] dataForType:TrackPBoardType] != nil);
   }
 
   return YES;
}


- ( TrackBrowserDocument*) document
{
   return (TrackBrowserDocument*) [[NSDocumentController sharedDocumentController] documentForWindow:[self window]];
}


- (void)keyDown:(NSEvent *)theEvent
{
   int kc = [theEvent keyCode];
   if (kc == 49)
   {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
   }
	else if (kc == 126)		// up arrow
	{
		int row = [self selectedRow];
		if (row > 0)
		{
			NSIndexSet* is = [NSIndexSet indexSetWithIndex:row-1];
			[self selectRowIndexes:is
				byExtendingSelection:NO];
		}
	}
	else if (kc == 125)		// down arrow
	{
		int row = [self selectedRow];
		if (row < ([self numberOfRows]-1))
		{
			NSIndexSet* is = [NSIndexSet indexSetWithIndex:row+1];
			[self selectRowIndexes:is
				byExtendingSelection:NO];
		}
	}
}

- (void) docChanged
{
   [[self document] updateChangeCount:NSChangeDone];
}


- (void) buildColumnDict
{
   int num = [ColumnInfo numPossibleColumns];
   int i;
   int next = 0;
   TrackBrowserDocument* doc = [self document];
   NSMutableDictionary* ciDict = [doc tableInfoDict];
   if (ciDict == nil)
   {
      ciDict = [[NSMutableDictionary alloc] initWithDictionary:[[BrowserInfo sharedInstance] colInfoDict] copyItems:YES];      // COPY it
      [doc setTableInfoDict:ciDict];
      [ciDict release];
   }
   
   NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:ciDict];
   [ciDict removeAllObjects];
   for (i=0; i<num; i++)
   {
      tColInfo* colInfo = [ColumnInfo nthPossibleColumnInfo:i];
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
      [ci release];
   }
}


- (void) removeAllColumns
{
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
   NSArray* sortedKeysArray = [[ciDict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
   int num = [sortedKeysArray count];
   int i;
   for (i=0; i<num; i++)
   {
      id aKey = [sortedKeysArray objectAtIndex:i];
      ColumnInfo* ci = [ciDict objectForKey:aKey];
      int flags = [ci flags];
      if ((flags & kCantRemove) == 0)
      {  
         int idx = [self columnWithIdentifier:[ci ident]];
         if (idx != -1)    // column is present, so remove it
         {
            NSTableColumn* col = [[self tableColumns] objectAtIndex:idx];
            [self removeTableColumn:col];
         }
      }
   }
}




-(NSMenu*) buildColumnMenu
{
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
   NSMenu* menu = [[NSMenu alloc] init];
   NSArray* sortedKeysArray = [ciDict keysSortedByValueUsingSelector:@selector(compareUsingTitle:)];
   int num = [sortedKeysArray count];
   int i;
   for (i=0; i<num; i++)
   {
      id aKey = [sortedKeysArray objectAtIndex:i];
      ColumnInfo* ci = [ciDict objectForKey:aKey];
      int flags = [ci flags];
      if ((flags & kCantRemove) == 0)
      {  
         NSMenuItem* mi = [[NSMenuItem alloc] initWithTitle:[ci menuLabel] action:@selector(doit:) keyEquivalent:@""];
         NSCellStateValue state = ([ci order] == kNotInBrowser) ? NSOffState : NSOnState;
         [mi setState:state];
         [mi setTag:[ci tag]];
         [menu  addItem:mi];
         [mi release];
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
      [self addTableColumn:col];
      [col autorelease];       // there were retain/release issues here, now resolved?
   }
   else
   {
      col = [self tableColumnWithIdentifier:[ci ident]];
   }
   if (col != nil)
   {
      float w = [ci width];
      [col setWidth:w];
      [col setMinWidth:40];
      [col setEditable:NO];
      if (([ci flags] & kLeftAlignment) != 0)
      {
         [[col dataCell] setAlignment:NSLeftTextAlignment];
         [[col headerCell] setAlignment:NSLeftTextAlignment];
      }
      else
      {
         [[col dataCell] setAlignment:NSRightTextAlignment];
         [[col headerCell] setAlignment:NSRightTextAlignment];
      }
   }
}


- (void) etherealizeColumnsFromDict
{
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
   NSArray *sortedKeysArray =
      [ciDict keysSortedByValueUsingSelector:@selector(compare:)];
   int num = [sortedKeysArray count];
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
   [self reloadData];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(columnMoved:)
                                                name:NSOutlineViewColumnDidMoveNotification
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(columnResized:)
                                                name:NSOutlineViewColumnDidResizeNotification
                                              object:nil];
}


- (void) rebuild
{
   [self buildColumnDict];
   NSMenu* cm = [self buildColumnMenu];
   NSTableHeaderView* currentTableHeaderView = [self headerView];
   tableHeaderView = [[MyTableHeaderView alloc] initWithView:self];
   [tableHeaderView setFrame:[currentTableHeaderView frame]];
   [tableHeaderView setBounds:[currentTableHeaderView bounds]];
   [tableHeaderView setMenuOfColumns:cm];
#ifdef DEBUG_RC
   int before = [tableHeaderView retainCount];
#endif
   [self setHeaderView:tableHeaderView];
#ifdef DEBUG_RC
   NSLog(@"setHeaderView rc, before:%d after:%d\n", before, [tableHeaderView retainCount]);
#endif
   [cm autorelease];
   [tableHeaderView autorelease];  
   [self removeAllColumns];
   [self etherealizeColumnsFromDict];
}



- (void)tableInfoLoaded:(NSNotification *)notification
{
   [self rebuild];
}




- (void) awakeFromNib
{
   [self setAutoresizesOutlineColumn:NO];
   [self rebuild];
}



- (ColumnInfo*) columnInfoFromTag:(int)tag
{
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
   NSEnumerator *enumerator = [ciDict objectEnumerator];
   id value;
   
   while ((value = [enumerator nextObject])) 
   {
      if ([value tag] == tag) return value;
   }
   return nil;
}


- (void) columnize:(NSMenu*)colMenu item:(id)it colIndex:(int)colIndex
{
   NSMenuItem* mi = it;
   if ([mi state] == NSOnState) 
      [mi setState:NSOffState];
   else
      [mi setState:NSOnState];
   int tag = [mi tag];
   ColumnInfo* ci = [self columnInfoFromTag:tag];
   if (ci != nil)
   {
      int flags = [ci flags];
      if ((flags & kCantRemove) == 0)
      {
         NSTableColumn* col = nil;
         int idx = [self columnWithIdentifier:[ci ident]];
         if (idx != -1)    // column is present, so remove it
         {
            col = [[self tableColumns] objectAtIndex:idx];
            [self removeTableColumn:col];
            [ci setOrder:kNotInBrowser];
         }
         else              // column is not present, so add it
         {
            [self installColumn:ci];
            //[ci setOrder:0];
            int nc = [self numberOfColumns];
            if (nc > 2)
            {
               int targetColIndex = colIndex;
               if (targetColIndex < 1) targetColIndex = 1;
               if (targetColIndex > (nc-1)) targetColIndex = nc-1;
               [self moveColumn:nc-1  
                       toColumn:targetColIndex];
            }
          }
      }
      [self reloadData];
      [self docChanged];
      [[self document] setTableInfoDict:[[self document] tableInfoDict]];
   }
}



- (void)columnMoved:(NSNotification *)aNotification
{
   //NSLog(@"column moved...");
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
   NSEnumerator *enumerator = [ciDict objectEnumerator];
   ColumnInfo* ci;
   
   while ((ci = [enumerator nextObject])) 
   {
      [ci setOrder:kNotInBrowser];
   }
   NSArray* colArray = [self tableColumns];
   int i;
   int next = 0;
   int num = [colArray count];
   // can't let the user move col 0!!!  scan first for this possibility
   for (i=0; i<num; i++)
   {
      id ident = [[colArray objectAtIndex:i] identifier];
      BOOL isName = ([ident compare:@kCT_Name] == NSOrderedSame);
      if (isName && (i == 0)) break;      // ok
      if ((i != 0) && isName)
      {
         [self moveColumn:i
                 toColumn:0];
         break;
      }
   }
   
   for (i=0; i<num; i++)
   {
      id ident = [[colArray objectAtIndex:i] identifier];
      //NSLog(@"column: %@\n", ident);
      ci = [ciDict objectForKey:ident];
      if (ci != nil) [ci setOrder:next++];
   }
   [self docChanged];
   [[self document] setTableInfoDict:ciDict];
}


- (void)columnResized:(NSNotification *)aNotification
{
   //NSLog(@"column resized...");
   NSDictionary* dict = [aNotification userInfo];
   NSTableColumn* col = [dict objectForKey:@"NSTableColumn"];
   if ([[self headerView] resizedColumn] != -1)
   {
      NSString* s = [col identifier];
      NSMutableDictionary* ciDict = [[self document] tableInfoDict];
      ColumnInfo* ci = [ciDict objectForKey:s];
      if (ci != nil) 
      {
         [ci setWidth:[col width]];
      }
      [self docChanged];
      [[self document] setTableInfoDict:ciDict];
   }
}


- (BOOL) columnUsesStringCompare:(NSString*)colIdent
{
   NSMutableDictionary* ciDict = [[self document] tableInfoDict];
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

- (MyTableHeaderView*) initWithView:(ActivityOutlineView*)av
{
   [super init];
   activityOutlineView = av;
   lastClickedColumn = 0;
   [activityOutlineView retain];
   return self;
}
   

- (void) dealloc
{
   [menuOfColumns release];
   [activityOutlineView release];
   [super dealloc];
}


- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
   if([theEvent type] == NSRightMouseDown || ([theEvent type] == 
                                           NSLeftMouseDown && ([theEvent modifierFlags] & NSControlKeyMask)))
   {
      NSPoint point = [self convertPoint:[theEvent locationInWindow] 
                                fromView:NULL];
      lastClickedColumn = [self columnAtPoint:point];
      return menuOfColumns;
   }
   //NSLog(@"menu for event, col:%d\n", lastClickedColumn);
   return nil;
}


- (NSMenu *)menuOfColumns {
   return [[menuOfColumns retain] autorelease];
}

- (void)setMenuOfColumns:(NSMenu *)value {
   if (menuOfColumns != value) {
      [menuOfColumns release];
      menuOfColumns = [value copy];
   }
}


- (IBAction) doit:(id)sender
{
   [activityOutlineView columnize:menuOfColumns item:sender colIndex:lastClickedColumn];
}


@end


