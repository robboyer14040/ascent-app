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
#import "ColumnHelper.h"


NSString* ActivityDragType = @"ActivityDragType";


//--------------------------------------------------------------------------------------------------------------
//---- ActivityOutlineView -------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------

@implementation ActivityOutlineView

@synthesize trackDragImage;


- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect])
	{
		tableHeaderView = nil;
		columnHelper = nil;
	}
	return self;
}


-(void)prepareToDie
{
	// this routine is needed to make sure that the ColumnHelper releases its
	// references to the current document, table view, etc.
#if DEBUG_LEAKS
	NSLog(@"ActivityOutlineView PREPARING TO DIE rc: %d", self, [self retainCount]);
	NSLog(@"ColumnHelper rc: %d\n", [columnHelper retainCount]);
#endif	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	columnHelper = nil;
}

- (void) dealloc
{
	self.trackDragImage = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}



- (void) awakeFromNib
{
	NSString* path = [[NSBundle mainBundle] pathForResource:@"TrackDragImage" ofType:@"png"];
	self.trackDragImage = [[NSImage alloc] initWithContentsOfFile:path];
	[self registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, ActivityDragType, nil]];
	
	MainBrowserStaticColumnInfo* mbci = [[MainBrowserStaticColumnInfo alloc] init];
	columnHelper = [[ColumnHelper alloc] initWithTableView:self
											 staticColInfo:mbci
											  dictSelector:@selector(colInfoDict)
										   setDictSelector:@selector(setColInfoDict:)];
	[self setAutoresizesOutlineColumn:NO];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(columnMoved:)
												 name:NSOutlineViewColumnDidMoveNotification
											   object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(columnResized:)
												 name:NSOutlineViewColumnDidResizeNotification
											   object:self];
}



// default version of this causes an exception if clicked in a non-column area of the table
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if([theEvent type] == NSEventTypeRightMouseDown || ([theEvent type] == 
											   NSEventTypeLeftMouseDown && ([theEvent modifierFlags] & NSEventModifierFlagControl)))
	{
		return [self menu];
	}
	return nil;
}


#if 0
- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
    NSLog(@"AOL validateMenuItem...");
    
   if (([menuItem action] == @selector(copy:)) ||
       ([menuItem action] == @selector(cut:)) ||
       ([menuItem action] == @selector(deleteActivity:)))
   {
      return ([self numberOfSelectedRows] > 0);
   }
   else if  ([menuItem action] == @selector(paste:))
   {
      return ([[NSPasteboard generalPasteboard] dataForType:TrackPBoardType] != nil);
   }
 
   return YES;
}
#endif


- (void)setDocument:(TrackBrowserDocument *)doc {
    _document = doc; // assign on purpose
    if (_document)
    {
        [columnHelper setDocument:doc];
        [columnHelper rebuild];
    }
}


- (void)keyDown:(NSEvent *)theEvent
{
	int kc = [theEvent keyCode];
    NSEventModifierFlags mods = [theEvent modifierFlags];
    bool optionKeyDown = ((mods&NSEventModifierFlagOption)!=0);
	if (kc == 49)
	{
	  [[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
	}
	else if (kc == 126)		// up arrow
	{
        NSInteger row = [self selectedRow];
		if (row > 0)
		{
			NSIndexSet* is = [NSIndexSet indexSetWithIndex:row-1];
			[self selectRowIndexes:is
				byExtendingSelection:NO];
			[self scrollRowToVisible:row-1];
		}
	}
	else if (kc == 125)		// down arrow
	{
        NSInteger row = [self selectedRow];
		if (row < ([self numberOfRows]-1))
		{
			NSIndexSet* is = [NSIndexSet indexSetWithIndex:row+1];
			[self selectRowIndexes:is
				byExtendingSelection:NO];
			[self scrollRowToVisible:row+1];
		}
	}
	else if (kc == 51)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DeleteSelectedRows" object:self];
	}
	else if ((kc == 122) || ((kc == 9)&& optionKeyDown))        // F1 or opt-V
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeBad]];
    }
#if 1
	else if ((kc == 0)  && optionKeyDown )          // opt-A
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeActvities]];
    }
	else if ((kc == 45) &&optionKeyDown )           // opt-N
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeCurrent]];
    }
	else if ((kc == 13) &&optionKeyDown )           // opt-W
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeWeeks]];
    }
	else if ((kc == 46) &&optionKeyDown )           // opt-M
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeMonths]];
    }
	else if ((kc == 16) &&optionKeyDown )           // opt-Y
    {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleBrowserView" object:[NSNumber numberWithInt:kViewTypeYears]];
    }
#endif
    else
	{
		[super keyDown:theEvent];
	}
}

- (void) docChanged
{
   [[self document] updateChangeCount:NSChangeDone];
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


- (BOOL) columnUsesStringCompare:(NSString*)colIdent
{
	return [columnHelper columnUsesStringCompare:colIdent];
}



- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender 
{
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) 
	{
        if (sourceDragMask & NSDragOperationLink) 
		{
			return NSDragOperationLink;
        } 
		else if (sourceDragMask & NSDragOperationCopy) 
		{
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationEvery;
	
}


- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
    NSUInteger count = dragRows.count;
	NSSize s = NSMakeSize(trackDragImage.size.width, count*(trackDragImage.size.height + 2.0));
	NSImage* anImage = [[NSImage alloc] initWithSize:s];
	[anImage lockFocus];
	NSInteger idx = [dragRows firstIndex];
	NSPoint p;
	p.x = 0.0;
	p.y = 0.0;
	while (idx != NSNotFound)
	{
		///NSRect r = [self frameOfCellAtColumn:0
		///								 row:idx];
		[self.trackDragImage drawAtPoint:p
								fromRect:NSZeroRect
							   operation:NSCompositingOperationSourceOver
								fraction:1.0];
		idx = [dragRows indexGreaterThanIndex:idx];
		p.y += trackDragImage.size.height + 2.0;
	}
	[anImage unlockFocus];
	///*dragImageOffset = location;
	return anImage;
}


@end





