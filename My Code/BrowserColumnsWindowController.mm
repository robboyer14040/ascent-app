//
//  BrowserColumnsWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 2/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "BrowserColumnsWindowController.h"
#import "ColumnInfo.h"
#import "BrowserInfo.h"
#import "TrackBrowserDocument.h"

@implementation BrowserColumnsWindowController


- (id) init
{
    self = [super init];
   tempColInfoDict = nil;
   buttonArray = [[NSMutableArray alloc] initWithCapacity:30];
   return self;
}


- (void) dealloc
{
    [super dealloc];
}


- (void) awakeFromNib
{
   
}   

- ( TrackBrowserDocument*) getDocument
{
   return (TrackBrowserDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
}


- (IBAction) updateColumnOptionsFromPanel:(id)sender
{
   [[self getDocument] setColInfoDict:tempColInfoDict];
   [NSApp stopModalWithCode:0];
}


- (IBAction) dismissColumnOptionsPanel:(id)sender
{
   [NSApp stopModalWithCode:1];
}



- (IBAction) enableColumn:(id)sender
{
   //NSArray* sortedKeysArray = [[tempColInfoDict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
   NSArray* sortedKeysArray = [tempColInfoDict keysSortedByValueUsingSelector:@selector(compareUsingMenuName:)];
   int num = [sortedKeysArray count];
   id aKey = [sortedKeysArray objectAtIndex:[sender tag]];
   ColumnInfo* ci = [tempColInfoDict objectForKey:aKey];
   if (ci != nil)
   {
      int state = [sender state];
      if (state == 1)
      {
         int minord = 999999999;
         for (int i=0; i<num; i++)
         {
            aKey = [sortedKeysArray objectAtIndex:i];
            ColumnInfo* colInfo = [tempColInfoDict objectForKey:aKey];
            int flags = [colInfo flags];
            if ((flags & kCantRemove) == 0)
            {
               int ord = [colInfo order];
               if (ord != kNotInBrowser)
               {
                  if (ord < minord) minord = ord;
                  [colInfo setOrder:++ord];
               }
            }
         }
         [ci setOrder:minord];
      }
      else
      {
         [ci setOrder:kNotInBrowser];
      }
   }
}




#define COL_TOP_YOFF    60.0
#define COL_WIDTH       200.0



- (void) rebuild
{
   if (tempColInfoDict != nil)
   {
      NSRect bounds = [[[self window] contentView] bounds];
      NSArray* sortedKeysArray = [tempColInfoDict keysSortedByValueUsingSelector:@selector(compareUsingMenuName:)];
      int num = [sortedKeysArray count];
      int i;
      NSButton* button;
      NSRect r;
      r.origin.x = 20.0;
      r.origin.y = bounds.size.height - COL_TOP_YOFF;
      r.size.width = COL_WIDTH - 20.0;
      r.size.height = 16.0;
      BOOL built = [buttonArray count] > 0;
      int arrIdx = 0;
      for (i=0; i<num; i++)
      {
         id aKey = [sortedKeysArray objectAtIndex:i];
         ColumnInfo* ci = [tempColInfoDict objectForKey:aKey];
         int flags = [ci flags];
         if ((flags & kCantRemove) == 0)
         {  
            if (built == NO)
            {
               button = [[NSButton alloc] init];
               [buttonArray addObject:button];
               [button setFrame:r];
               [button setButtonType:NSSwitchButton];
               NSRect br = r;
               br.origin.x = br.origin.y = 0.0;
               [button setBounds:br];
               [button setTitle:[ci menuLabel]];
               [button setTag:i];
               [button setAction:@selector(enableColumn:)];
               [[[self window] contentView] addSubview:button];
                r.origin.y -= 24.0;
               if (r.origin.y < 60.0)
               {
                  r.origin.y = bounds.size.height - COL_TOP_YOFF;
                  r.origin.x += COL_WIDTH;
               }
            }
            else
            {
               button = [buttonArray objectAtIndex:arrIdx++];
            }
            [button setState:([ci order] != kNotInBrowser)]; 
         }
      }
   }
}   

- (IBAction)showWindow:(id)sender
{
   NSMutableDictionary* ciDict = [[self getDocument] colInfoDict];
   tempColInfoDict = [[NSMutableDictionary alloc] initWithDictionary:ciDict copyItems:YES];      // COPY it
   [self rebuild];
   [super showWindow:sender];
}



- (void)windowWillClose:(NSNotification *)aNotification
{
   [NSApp stopModalWithCode:1];
}


@end
