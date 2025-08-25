//
//  GMTOffsetController.mm
//  Ascent
//
//  Created by Rob Boyer on 5/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "GMTOffsetController.h"


@implementation GMTOffsetController

- (id) initWithOffset:(int)off
{
   self = [super init];
   offset = off;
   self = [super initWithWindowNibName:@"GMTOffset"];
   isValid = YES;
   return self;
}

- (id) init
{
   return [self initWithOffset:0];
}

-(void) awakeFromNib
{
   [offsetTextField setIntValue:offset];
   [offsetStepper setIntValue:offset];
}


- (void) dealloc
{
   //NSLog(@"EditMarkerController::dealloc");
}



-(int) offset
{
   return offset;
}


- (IBAction) setOffset:(id)sender
{
   offset = [sender intValue];
   [offsetTextField setIntValue:offset];
   [offsetStepper setIntValue:offset];
}


- (IBAction) dismissPanel:(id)sender
{
   [NSApp stopModalWithCode:isValid ? 0: -1];
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
