//
//  BrowserColumnsWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 2/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BrowserColumnsWindowController : NSWindowController 
{
   NSMutableArray*      buttonArray;
   NSMutableDictionary* tempColInfoDict;
}


- (IBAction) updateColumnOptionsFromPanel:(id)sender;
- (IBAction) dismissColumnOptionsPanel:(id)sender;


@end
