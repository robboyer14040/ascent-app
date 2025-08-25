//
//  PrefsUser.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsUser : OAPreferenceClient 
{
	IBOutlet NSDatePicker*  agePicker;
	IBOutlet NSPopUpButton* genderPopup;
	IBOutlet NSTextField*   weightTextField;
	IBOutlet NSTextField*	weightLabelField;
	IBOutlet NSTextField*   heightTextField;
	IBOutlet NSTextField*	heightLabelField;
	IBOutlet NSTextField*   bmiTextField;
	IBOutlet NSTextField*	bmiLabelField;
	IBOutlet NSTextField*   vo2MaxTextField;
	IBOutlet NSImageView*	userImage;
	IBOutlet NSTextField*	userNameField;
	BOOL					useStatuteUnits;
}

@end
