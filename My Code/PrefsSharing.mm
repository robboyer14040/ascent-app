//
//  PrefsSharing.mm
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsSharing.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "RegController.h"
#import "GetPasswordController.h"
#import "Utils.h"
#import "DBComm.h"

NSString*  RCBDefaultSharingAccountName			= @"DefaultSharingAccountName";
NSString*  RCBDefaultSharingAccountPassword		= @"DefaultSharingAccountPassword";
NSString*  RCBDefaultSharingAccountEmail		= @"DefaultSharingAccountEmail";



@implementation PrefsSharing

- (void)awakeFromNib
{
   [super awakeFromNib];
}


-(void)getAccountInfo
{
	GetPasswordController *gpwc = [[[GetPasswordController alloc] initWithUser:[userNameField stringValue]
																		email:[emailField stringValue]] autorelease];
	NSWindow* parentWind = [[self controlBox] window];
	NSRect fr = [parentWind frame];
	NSRect panelRect = [[gpwc window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
	
	[[gpwc window] setFrameOrigin:origin];
	[gpwc showWindow:self];
	int ok = [NSApp runModalForWindow:[gpwc window]];
	[[gpwc window] orderOut:parentWind];
	[parentWind makeKeyAndOrderFront:self];
	if (ok == 0) 
	{
		NSString* p = [gpwc pw];
		[Utils setStringDefault:p
						 forKey:RCBDefaultSharingAccountPassword];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];       /// rcb
        
        if (p && [p isNotEqualTo:@""])
		{
			DBComm* dbc = [[[DBComm alloc] init] autorelease];
			int result = [dbc createUser:[defaults stringForKey:RCBDefaultSharingAccountName]
								   ident:[defaults stringForKey:RCBDefaultSharingAccountEmail]
								password:[defaults stringForKey:RCBDefaultSharingAccountPassword]
							   birthdate:(NSDate*)[defaults objectForKey:RCBDefaultBirthday]
								   maxhr:(float)[defaults floatForKey:RCBDefaultMaxHeartrate]
								  regkey:@"" 
								 homelat:(double)0.0
								 homelon:(double)0.0];
			if (result == 0)
			{
				[emailField setEnabled:YES];
				[userNameField setEnabled:YES];
				[createOrModifyButton setStringValue:@"Change password..."];
			}
			else
			{
				// post "Could not create or modify account"
			}
		}
	}
}	


- (IBAction)setValueForSender:(id)sender;
{
	if (sender == createOrModifyButton)
	{
		[self getAccountInfo];
	} 
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


- (void)valuesHaveChanged
{
   [super valuesHaveChanged];
}



-(void)updateUI
{
	if ([RegController CHECK_REGISTRATION])
	{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		//NSString* regCode = [NSMutableString stringWithString:@""];
		NSString* email = [defaults stringForKey:RCBDefaultSharingAccountEmail];
		NSString* pw = [defaults stringForKey:RCBDefaultSharingAccountPassword];
		NSString* userName = [defaults stringForKey:RCBDefaultSharingAccountName];
		if (userName && ![userName isEqualToString:@""] && pw && ![pw isEqualToString:@""] && email && ![email isEqualToString:@""])
		{
			[emailField setStringValue:email];
			[emailField setEnabled:YES];
			[userNameField setStringValue:userName];
			[userNameField setEnabled:YES];
			[createOrModifyButton setStringValue:@"Change password..."];
		}
		else
		{
			NSMutableString* un = [NSMutableString stringWithString:@""];
			NSMutableString* em = [NSMutableString stringWithString:@""];
			NSMutableString* rc = [NSMutableString stringWithString:@""];
			[RegController gi:un a2:em a3:rc];
			[emailField setStringValue:em];
			[emailField setEnabled:NO];
			[userNameField setStringValue:un];
			[userNameField setEnabled:NO];
			[Utils setStringDefault:un
							 forKey:RCBDefaultSharingAccountName];
			[Utils setStringDefault:em
							 forKey:RCBDefaultSharingAccountEmail];
			[createOrModifyButton setStringValue:@"Create Password..."];
		}
	}
}

@end
