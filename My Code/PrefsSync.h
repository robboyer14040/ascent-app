//
//  PrefsSharing.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsSync : OAPreferenceClient 
{
	IBOutlet NSPopUpButton* numOfWeeksOrMonthsPopup;
	IBOutlet NSPopUpButton* weeksOrMonthsPopup;
	IBOutlet NSButton*      enableWiFiSync;
	IBOutlet NSButton*      syncLastWeeksOrMonths;
#if 0
	IBOutlet NSButton*      syncGarminUSB;
	IBOutlet NSButton*      syncGarminANT;
	IBOutlet NSButton*      syncGarminMassStorage;
#endif
}

@end
