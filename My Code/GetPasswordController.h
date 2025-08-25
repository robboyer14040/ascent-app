//
//  GetPasswordController.h
//  Ascent
//
//  Created by Rob Boyer on 3/1/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GetPasswordController : NSWindowController 
{
	IBOutlet NSTextField*   pwField;
	IBOutlet NSButton*		okButton;
	BOOL	isValid;
}

-(id) initWithUser:(NSString*)nm email:(NSString*)em;
-(NSString*) pw;
-(IBAction) setPw:(NSString*)pw;
-(IBAction) ok:(id)sender;

@end
