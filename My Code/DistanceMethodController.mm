//
//  DistanceMethodController.mm
//  Ascent
//
//  Created by Rob Boyer on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "DistanceMethodController.h"


@implementation DistanceMethodController

-(id) initWithValue:(BOOL)useDistanceData
{
   self = [super init];
   useDistance = useDistanceData;
   self = [super initWithWindowNibName:@"DistanceMethod"];
   isValid = YES;
   return self;
}


-(void) awakeFromNib
{
   [useDistanceButton setIntValue:useDistance ? 1 : 0];
}


- (void) dealloc
{
}


-(IBAction) setUseDistanceData:(id)sender
{
   useDistance = [sender intValue] == 1 ? YES : NO;
}

-(BOOL) useDistanceData
{
   return useDistance;
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
