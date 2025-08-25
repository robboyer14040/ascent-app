//
//  EditNotesController.h
//  Ascent
//
//  Created by Rob Boyer on 4/1/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface EditNotesController : NSWindowController 
{
   IBOutlet NSTextView*    textView;
   NSString*               theText;
   BOOL                    isValid;
}

-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
-(NSString*) text;
-(void) setText:(NSString*)t;
-(BOOL) valid;


@end
