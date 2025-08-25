//
//  PrefsAdvanced.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsAdvanced : OAPreferenceClient 
{
	IBOutlet NSButton*      checkForUpdatesAtStartupButton;
	IBOutlet NSButton*      checkForUpdatesPeriodicallyButton;
	IBOutlet NSPopUpButton* checkForUpdatesFrequencyPopup;
	IBOutlet NSPopUpButton* powerActvitiesPopup;
	IBOutlet NSButton*      calculatePowerIfAbsentButton;
	IBOutlet NSButton*      enableAutoSplitButton;
	IBOutlet NSButton*      useDistanceDataButton;
	IBOutlet NSTextField*   minSpeedField;
	IBOutlet NSTextField*   altitudeFilterField;
	IBOutlet NSTextField*   autoSplitThresholdField;
	IBOutlet NSTextField*   autoSplitThresholdText;
	IBOutlet NSTextField*   altitudeAverageWindowTextField;
	IBOutlet NSTextField*   defaultMaxAltitudeTextField;
	IBOutlet NSSlider*		autoSplitThresholdSlider;
	IBOutlet NSSlider*		minSpeedSlider;
	IBOutlet NSSlider*		altitudeFilterSlider;
	IBOutlet NSSlider*		altitudeAverageWindowSlider;
	IBOutlet NSSlider*		defaultMaxAltitudeSlider;
}

- (IBAction)setValueForSender:(id)sender;

@end
