//
//  GMTOffsetController.h
//  Ascent
//
//  Created by Rob Boyer on 5/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GMTOffsetController : NSWindowController 
{
   IBOutlet NSStepper*     offsetStepper;
   IBOutlet NSTextField*   offsetTextField;
   int                     offset;
   BOOL                    isValid;
}

-(id) initWithOffset:(int)off;
-(int) offset;

-(IBAction) setOffset:(id)sender;
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;

@end
