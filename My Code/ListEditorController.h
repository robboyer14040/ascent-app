//
//  ListEditorController.h
//  Ascent
//
//  Created by Rob Boyer on 7/4/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LECTableView : NSTableView
{
}
@end

@interface ListEditorController : NSWindowController 
{
   IBOutlet LECTableView*   tableView;
   NSMutableArray*         itemArray;
   NSString*               itemName;
   BOOL                    isValid;
}

-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
-(IBAction) add:(id)sender;
-(IBAction) remove:(id)sender;

- (id) initWithStringArray:(NSArray*)sa name:(NSString*)name;
- (NSArray*) stringArray;

@end
