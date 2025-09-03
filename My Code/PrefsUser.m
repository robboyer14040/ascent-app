//
//  PrefsUser.m
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsUser.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "Utils.h"
#import "Defs.h"
#import <AddressBook/ABAddressBook.h>
#import <AddressBook/ABPerson.h>


NSString*  RCBDefaultGender      = @"DefaultGender";
NSString*  RCBDefaultVO2Max      = @"DefaultVO2Max";
NSString*  RCBDefaultWeight      = @"DefaultWeight";
NSString*  RCBDefaultHeight      = @"DefaultHeight";
NSString*  RCBDefaultBirthday    = @"DefaultBirthday";

NSString* TrackPBoardType = @"com.montebello.ascent.tracks";


@implementation PrefsUser


- (void)awakeFromNib
{
    [super awakeFromNib];
	[userImage setImageFrameStyle:NSImageFramePhoto];
	ABPerson* curPerson = [[ABAddressBook sharedAddressBook] me];
	if (curPerson)
	{	
		NSData* personImageData;
		SEL sel = @selector(imageData);				// do all this to prevent compiler warning
		if ([curPerson respondsToSelector:sel])
		{
			personImageData = [curPerson performSelector:sel];
		}
		if (personImageData)
		{
			NSImage* personImage = [[[NSImage alloc] initWithData:personImageData] autorelease];
			[userImage setImage:personImage];
		}
		NSString* name = [NSString stringWithFormat:@"%@ %@",
			[curPerson valueForProperty:kABFirstNameProperty],
			[curPerson valueForProperty:kABLastNameProperty]];
		[userNameField setStringValue:name];
	}
}


- (void) updateBMI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	float wt = [defaults floatForKey:RCBDefaultWeight];
	float ht = [defaults floatForKey:RCBDefaultHeight];
    float bmi = 0.0;
	if (useStatuteUnits)
	{
		ht *= 12.0;		// feet to inches
		if (ht > 0.0) bmi = 703.0 * wt / (ht*ht);
	}
	else
	{
		ht = FeetToMeters(ht);		
		wt = PoundsToKilograms(wt);
		if (ht > 0.0) bmi = wt/(ht*ht);
	}
	[bmiTextField setFloatValue:bmi];
}



//add startup code to see if 'birthday' default is 0, if so, calculate from age and store in defaults
//remove all code that gets 'default age' pref and create utils method to return age by using birthday

- (IBAction)setValueForSender:(id)sender;
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
    if (sender == agePicker)
	{
		NSDate* birthDate = [sender dateValue];
		[defaults setInteger:[Utils calculateAge:birthDate] forKey:RCBDefaultAge];
		[defaults setObject:birthDate forKey:RCBDefaultBirthday];
	}
	else if (sender == weightTextField)
	{
		float v = [sender floatValue];
		if (!useStatuteUnits) v = KilogramsToPounds(v);
		[defaults setFloat:v forKey:RCBDefaultWeight];
		[self updateBMI];
	}
	else if (sender == heightTextField)
	{
		float v = [sender floatValue];
		if (useStatuteUnits)
		{
			v /= 12.0;		// inches to feet
		}
		else
		{
			v = MetersToFeet(v/100.0);		// cm to feet
		}
		[defaults setFloat:v forKey:RCBDefaultHeight];
		[self updateBMI];
	}
	else if (sender == vo2MaxTextField)
	{
		float v = [sender floatValue];
		[defaults setFloat:v forKey:RCBDefaultVO2Max];
	}
	else if (sender == genderPopup)
	{
		int iv = [sender indexOfSelectedItem];
		[defaults setInteger:iv forKey:RCBDefaultGender];
	}
  	[defaults synchronize];
}


-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	float wt = [defaults floatForKey:RCBDefaultWeight];
	float ht = [defaults floatForKey:RCBDefaultHeight];
	float bmi = 0.0;
	if (useStatuteUnits)
	{
		ht *= 12.0;		// feet to inches
		[weightLabelField setStringValue:@"lbs"];
		[heightLabelField setStringValue:@"inches"];
		if (ht > 0.0) bmi = 703.0 * wt / (ht*ht);
	}
	else
	{
		ht = FeetToMeters(ht)*100.0;		// feet to centimeters
		wt = PoundsToKilograms(wt);
		[weightLabelField setStringValue:@"kg"];
		[heightLabelField setStringValue:@"cm"];
		if (ht > 0.0) bmi = wt/(ht*ht);
	}
	[self updateBMI];
	[heightTextField setFloatValue:ht];
	[weightTextField setFloatValue:wt];

	NSDate* birthDate  = [defaults objectForKey:RCBDefaultBirthday];
	if (birthDate)
	{
		[agePicker setDateValue:birthDate];
	}
	float vO2max = [defaults floatForKey:RCBDefaultVO2Max];
	[vo2MaxTextField setFloatValue:vO2max];

	int gender = [defaults integerForKey:RCBDefaultGender];
	[genderPopup selectItemAtIndex:gender];
}

@end
