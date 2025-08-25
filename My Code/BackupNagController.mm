//
//  BackupNagController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "BackupNagController.h"
#import "Defs.h"
#import "Utils.h"
#import <OmniAppKit/OAPreferenceController.h>


NSString*  RCBDefaultShowBackupNagDialog				= @"DefaultShowBackupNagDialog";


@implementation BackupNagController


- (id) init
{
	self = [super initWithWindowNibName:@"BackupNag"];
	if (self)
	{
		isValid = YES;
	}
	return self;
}


-(void) awakeFromNib
{
	NSString* backupFolder = [Utils stringFromDefaults:RCBDefaultLocalBackupFolder];
	if (backupFolder)
	{
		[currentBackupFolderTextField setStringValue:backupFolder];
	}
	else
	{
		[currentBackupFolderTextField setStringValue:@"<not set>"];
	}
}



- (IBAction) dismissPanel
{
	[NSApp stopModalWithCode:isValid ? 0: -1];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp stopModalWithCode:-1];
}


-(IBAction) cancel:(id)sender
{
	isValid = NO;
	[self dismissPanel];
}



-(IBAction) gotoBackupPreferences:(id)sender
{
	[[OAPreferenceController sharedPreferenceController] showPreferencesPanel:nil];
	[[OAPreferenceController sharedPreferenceController] setCurrentClientByClassName:@"PrefsBackup"];
	[self dismissPanel];
}

-(IBAction) dontShowThisAgain:(id)sender
{
	[Utils setBoolDefault:NO forKey:RCBDefaultShowBackupNagDialog];
}

@end
