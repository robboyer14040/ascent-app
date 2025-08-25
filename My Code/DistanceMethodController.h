//
//  DistanceMethodController.h
//  Ascent
//
//  Created by Rob Boyer on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DistanceMethodController : NSWindowController 
{
   IBOutlet NSButton*   useDistanceButton;
   BOOL                 useDistance;
   BOOL                 isValid;
}

-(id) initWithValue:(BOOL)useDistanceData;
-(BOOL) useDistanceData;
-(IBAction) setUseDistanceData:(id)sender;
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;

@end
