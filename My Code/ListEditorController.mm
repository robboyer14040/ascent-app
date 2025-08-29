//
//  ListEditorController.mm
//  Ascent
//
//  Created by Rob Boyer on 7/4/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "ListEditorController.h"
#define    kPrivateTableViewDataType      @"NDDT"



@implementation LECTableView



- (void)textDidEndEditing:(NSNotification *)aNotification
{
   BOOL doEdit = YES;
   [super textDidEndEditing:aNotification];

   switch ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue]) 
   {
      case NSReturnTextMovement:        // return
      {
         doEdit = NO;
         break;
      }
      case NSBacktabTextMovement:    // shift tab
      {
         doEdit = YES;
         break;
      }
         //case NSTabTextMovement:        // tab
      default:
      {
         doEdit = YES;
      }
   } // switch
   
   if (!doEdit) 
   {
      [self validateEditing];
      [self abortEditing];
      // do something else ...
   }
}


- (void) dealloc
{
    [super dealloc];
}


- (void)editColumn:(NSInteger)column row:(NSInteger)row withEvent:(NSEvent *)theEvent
            select:(BOOL)select
{
   //    Extend the life....
   [[[self selectedCell] retain] autorelease];
   
   [super editColumn:column row:row withEvent:theEvent select:select];
}

@end




@implementation ListEditorController

- (id) initWithStringArray:(NSArray*)sa name:(NSString*)name
{
   self = [super initWithWindowNibName:@"ListEditor"];
   itemArray = [NSMutableArray arrayWithArray:sa];
   itemName = name;
   isValid = NO;
   return self;
}

- (id) init
{
   return [self initWithStringArray:[NSArray array]
                               name:@""];
}

-(void) awakeFromNib
{
   [[self window] setTitle:itemName];
   [tableView registerForDraggedTypes: [NSArray arrayWithObject:kPrivateTableViewDataType]];
   [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
   [tableView reloadData];
}


- (void) dealloc
{
}



-(NSArray *) stringArray
{
   return [NSArray arrayWithArray:itemArray];
}


-(IBAction) add:(id)sender
{
   // if nothing is selected in the table, add new element at the end
   if ([tableView selectedRow] == -1)
   {
      [itemArray addObject:@""];
      [tableView reloadData];
      NSIndexSet* is = [NSIndexSet indexSetWithIndex:[itemArray count]-1];
      [tableView selectRowIndexes:is
             byExtendingSelection:NO];
   }
   else
   {
      NSIndexSet* is = [tableView selectedRowIndexes];
      if (is != nil)
      {
         NSUInteger idx = [is firstIndex];
         if ((idx >= 0) && (idx != NSNotFound))
         {
            [itemArray insertObject:@""
                            atIndex:idx];
            NSIndexSet* is = [NSIndexSet indexSetWithIndex:idx];
            [tableView selectRowIndexes:is
                   byExtendingSelection:NO];
            [tableView reloadData];
         }
      }
   }
   // now, if anything is selected (which it should be), put it in edit mode
   NSIndexSet* is = [tableView selectedRowIndexes];
   if (is != nil)
   {
      NSUInteger idx = [is firstIndex];
      if ((idx >= 0) && (idx != NSNotFound))
      {
         [tableView editColumn:0
                           row:idx
                     withEvent:nil
                        select:YES];
      }
   }
}


-(BOOL) isValid
{
   return isValid;
}


-(IBAction) remove:(id)sender
{
   [[self window] makeFirstResponder:nil];
   NSIndexSet* is = [tableView selectedRowIndexes];
   if (is != nil)
   {
      [itemArray removeObjectsAtIndexes:is];
      [tableView reloadData];
   }
}

- (IBAction) dismissPanel:(id)sender
{
   [[self window] makeFirstResponder:nil];
   [NSApp stopModalWithCode:isValid?0:-1];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
   [[self window] makeFirstResponder:nil];
   [NSApp stopModalWithCode:-1];
}


-(IBAction) done:(id)sender
{
   [[self window] makeFirstResponder:nil];
   isValid = YES;
   [self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
   [[self window] makeFirstResponder:nil];
   isValid = NO;
   [self dismissPanel:sender];
}


//---- table view data source methods ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- 


- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
   id retVal = nil;
   if (itemArray != nil)
   {
      retVal = [itemArray objectAtIndex:rowIndex];
   }
   return retVal;
}


- (void)tableView:(NSTableView *)aTableView
   setObjectValue:anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(int)rowIndex
{
   if (itemArray != nil)
   {
#if 0
      if (![itemArray containsObject:anObject])
      {
         NSString* s = (NSString*) anObject;
         [itemArray replaceObjectAtIndex:rowIndex 
                              withObject:s];
      }
      else if ([itemArray indexOfObject:anObject] != rowIndex)
      {
         [itemArray removeObjectAtIndex:rowIndex];
         [aTableView reloadData];
      }
#else
      if (rowIndex < [itemArray count])
      {
         NSString* s = (NSString*) anObject;
         [itemArray replaceObjectAtIndex:rowIndex 
                              withObject:s];
      } 
#endif
      [aTableView deselectAll:self];
   }
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
   if (itemArray != nil)
   {
      return [itemArray count];
   }
   else
   {
      return 0;
   }
}



- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard 
{
   // Copy the row numbers to the pasteboard.
   NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
   [pboard declareTypes:[NSArray arrayWithObject:kPrivateTableViewDataType] owner:self];
   [pboard setData:data forType:kPrivateTableViewDataType];
   return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op 
{
   // Add code here to validate the drop
   return NSDragOperationEvery;    
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info 
              row:(int)targetRow dropOperation:(NSTableViewDropOperation)operation
{
   BOOL ret = NO;
   NSPasteboard* pboard = [info draggingPasteboard];
   NSData* rowData = [pboard dataForType:kPrivateTableViewDataType];
   NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
   NSUInteger nextDraggedRow = [rowIndexes firstIndex];
   NSMutableIndexSet* newSel = [NSMutableIndexSet indexSet];
   NSMutableArray* arrOrig = [NSMutableArray arrayWithArray:itemArray];
   int size = [arrOrig count];
   if (targetRow >= size)
   {
      targetRow = size-1;
   }
   int nextTargetRow = targetRow;
   NSMutableArray* arrNew = [NSMutableArray arrayWithCapacity:size];
   int ovecIndex = 0;
   for (int i=0; i<size; i++)
   {
      if ((i == nextTargetRow) && (nextDraggedRow != NSNotFound))
      {
         [arrNew addObject:[arrOrig objectAtIndex:nextDraggedRow]];
         [newSel addIndex:i];
         ++nextTargetRow;
         nextDraggedRow = [rowIndexes indexGreaterThanIndex:nextDraggedRow];
      }
      else
      {
         while ([rowIndexes containsIndex:ovecIndex] && (ovecIndex < (size-1)))
         {
            ++ovecIndex;
         }
         if (ovecIndex < size)
         {
            [arrNew addObject:[arrOrig objectAtIndex:ovecIndex]];
            ++ovecIndex;
         }
      }
   }
   itemArray = arrNew;
   [tableView selectRowIndexes:newSel byExtendingSelection:NO];
   [tableView reloadData];
   ret = YES;
   return ret;
}



@end
