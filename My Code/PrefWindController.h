//
//  PrefWindController.h
//  TLP
//
//  Created by Rob Boyer on 9/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PrefWindController : NSWindowController 
{
   IBOutlet NSMatrix*   unitsMatrix;
}

- (IBAction) changeDefaultUnits:(id)sender;
- (IBAction) setColor:(id)sender;
- (IBAction) setDefaultColors:(id)sender;
- (BOOL) defaultUnitsAreEnglish;
@end
