//
//  PrefsSharing.mm
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsSync.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "Utils.h"

	
NSString*  RCBDefaultEnableWiFiSync				= @"DefaultEnableWiFiSync";
NSString*  RCBDefaultEnableWeeksOrMonthsSync	= @"DefaultEnableWeeksOrMonthsSync";
NSString*  RCBDefaultNumWeeksOrMonthsToSync		= @"DefaultNumWeeksOrMonthsToSync";
NSString*  RCBDefaultWeeksOrMonthsSync			= @"DefaultWeeksOrMonthsSync";
NSString*  RCBDefaultGarminUSBSync				= @"DefaultGarminUSBSync";
NSString*  RCBDefaultGarminMassStorageSync		= @"DefaultGarminMassStorageSync";
NSString*  RCBDefaultGarminANTSync				= @"DefaultGarminANTSync";

@implementation PrefsSync

- (void)awakeFromNib
{
	[super awakeFromNib];
}


- (IBAction)setValueForSender:(id)sender;
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	if (sender == numOfWeeksOrMonthsPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem]+1 forKey:RCBDefaultNumWeeksOrMonthsToSync];
	}
	else if (sender == weeksOrMonthsPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultWeeksOrMonthsSync];
	}
	else if (sender == enableWiFiSync)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultEnableWiFiSync];
	}
	else if (sender == syncLastWeeksOrMonths)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultEnableWeeksOrMonthsSync];
	}
#if 0
	else if (sender == syncGarminUSB)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultGarminUSBSync];
	}
	else if (sender == syncGarminANT)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultGarminANTSync];
	}
	else if (sender == syncGarminMassStorage)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultGarminMassStorageSync];
	}
#endif
    [defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}



-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[enableWiFiSync setState:[defaults boolForKey:RCBDefaultEnableWiFiSync]];
	[syncLastWeeksOrMonths setState:[defaults boolForKey:RCBDefaultEnableWeeksOrMonthsSync]];
	[numOfWeeksOrMonthsPopup	selectItemAtIndex:[defaults integerForKey:RCBDefaultNumWeeksOrMonthsToSync]-1];	// 0-based index, 1-based item
	[weeksOrMonthsPopup         selectItemAtIndex:[defaults integerForKey:RCBDefaultWeeksOrMonthsSync]];
#if 0
	[syncGarminUSB setState:[defaults boolForKey:RCBDefaultGarminUSBSync]];
	[syncGarminANT setState:[defaults boolForKey:RCBDefaultGarminANTSync]];
	[syncGarminMassStorage setState:[defaults boolForKey:RCBDefaultGarminMassStorageSync]];
#endif
}

@end
