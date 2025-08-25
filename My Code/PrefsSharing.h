//
//  PrefsSharing.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsSharing : OAPreferenceClient 
{
	IBOutlet NSTextField*   userNameField;
	IBOutlet NSTextField*   emailField;
	IBOutlet NSButton*		createOrModifyButton;
}

@end
