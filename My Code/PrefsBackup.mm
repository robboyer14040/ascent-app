//
//  PrefsBackup.mm
//  Ascent
//
//  Created by Rob Boyer on 8/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PrefsBackup.h"
#import "Utils.h"
#import "zlib.h"

NSString*  RCBDefaultDoLocalBackup				= @"DefaultDoLocalBackup";
NSString*  RCBDefaultDoMobileMeBackup			= @"DefaultDoMobileMeBackup";
NSString*  RCBDefaultLocalBackupFrequency		= @"DefaultLocalBackupFrequency";
NSString*  RCBDefaultLocalBackupFolder			= @"DefaultLocalBackupFolder";
NSString*  RCBDefaultLocalBackupRetainCount		= @"DefaultLocalBackupRetainCount";
NSString*  RCBDefaultMobileMeBackupFrequency	= @"DefaultMobileMeBackupFrequency";


@implementation PrefsBackup


- (IBAction)setValueForSender:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	if (sender == doLocalBackupButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultDoLocalBackup];
	}
	else if (sender == localBackupFreqPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem]+1 forKey:RCBDefaultLocalBackupFrequency];
	}
	else if (sender == numLocalBackupsToRetainPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem]+2 forKey:RCBDefaultLocalBackupRetainCount];
	}
	else if (sender == postLocalFolderChooserButton)
	{
		int runResult;
		
		NSOpenPanel *op = [NSOpenPanel openPanel];
		[op setCanCreateDirectories:YES];
		[op setCanChooseFiles:NO];
		[op setCanChooseDirectories:YES];
		[op setTitle:@"Choose backup folder"];
		[op setPrompt:@"Choose"];
		NSString* curBackupFolder = [Utils stringFromDefaults:RCBDefaultLocalBackupFolder];
		runResult = [op runModalForDirectory:curBackupFolder
										file:nil];

		if (runResult == NSModalResponseOK) 
		{
			[defaults setObject:[op directory] forKey:RCBDefaultLocalBackupFolder];
			[localBackupFolderTextField setStringValue:[op directory]];
		}	
	}
	else if (sender == doMobileMeBackupButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultDoMobileMeBackup];
	}
	else if (sender == mobileMeBackupFreqPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem]+1 forKey:RCBDefaultMobileMeBackupFrequency];
	}
	[defaults synchronize];
}


-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[doLocalBackupButton setState:[defaults boolForKey:RCBDefaultDoLocalBackup]];
	[doMobileMeBackupButton setState:[defaults boolForKey:RCBDefaultDoMobileMeBackup]];
	
	int v = [defaults integerForKey:RCBDefaultLocalBackupFrequency];
	[localBackupFreqPopup selectItemAtIndex:v-1];			// 10 items in menu, [1,10]
	
	v = [defaults integerForKey:RCBDefaultLocalBackupRetainCount];
	[numLocalBackupsToRetainPopup selectItemAtIndex:v-2];	// 9 items in menu, [2,10]
	
	v = [defaults integerForKey:RCBDefaultMobileMeBackupFrequency];
	[mobileMeBackupFreqPopup selectItemAtIndex:v-1];		// 10 items in menu, [1,10]
	
	NSString* localBackupFolder = [defaults stringForKey:RCBDefaultLocalBackupFolder];
	[localBackupFolderTextField setStringValue:localBackupFolder];
}



	

@end
