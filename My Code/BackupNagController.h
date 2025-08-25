//
//  BackupNagController.h
//  Ascent
//
//  Created by Rob Boyer on 11/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BackupNagController : NSWindowController 
{
	IBOutlet NSTextField*	currentBackupFolderTextField;
	BOOL					isValid;
}
- (id) init;
-(IBAction) cancel:(id)sender;
-(IBAction) gotoBackupPreferences:(id)sender;
-(IBAction) dontShowThisAgain:(id)sender;

@end
