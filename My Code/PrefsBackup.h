//
//  PrefsBackup.h
//  Ascent
//
//  Created by Rob Boyer on 8/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsBackup : OAPreferenceClient 
{
	IBOutlet NSButton*		doLocalBackupButton;
	IBOutlet NSButton*		doMobileMeBackupButton;
	IBOutlet NSButton*		postLocalFolderChooserButton;
	IBOutlet NSTextField*	localBackupFolderTextField;
	IBOutlet NSPopUpButton*	localBackupFreqPopup;
	IBOutlet NSPopUpButton*	numLocalBackupsToRetainPopup;
	IBOutlet NSPopUpButton*	mobileMeBackupFreqPopup;
}

- (IBAction)setValueForSender:(id)sender;

@end
