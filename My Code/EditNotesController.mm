//
//  EditNotesController.mm
//  Ascent
//
//  Created by Rob Boyer on 4/1/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "EditNotesController.h"


@implementation EditNotesController

- (id) initWithText:(NSString*)t
{
   theText = t;
   return self;
}

- (id) init
{
   return [self initWithText:@""];
}

-(void) awakeFromNib
{
}


- (void) dealloc
{
}



-(NSString*) text
{
   return [textView string];
}


-(void) setText:(NSString*)t
{
   if (t == nil) t = @"";
   if (theText != t)
   {
      theText = t;
   }
   [textView setString:theText];
}


-(BOOL) valid
{
   return isValid;
}

- (IBAction) dismissPanel:(id)sender
{
   [NSApp stopModalWithCode:isValid?0:-1];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
   [NSApp stopModalWithCode:-1];
}


-(IBAction) done:(id)sender
{
   isValid = YES;
   [self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
   isValid = NO;
   [self dismissPanel:sender];
}

@end
