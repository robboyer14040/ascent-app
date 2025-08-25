//
//  PrefsGeneral.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsGeneral : OAPreferenceClient 
{
	IBOutlet NSPopUpButton* unitsPopup;
	IBOutlet NSPopUpButton* temperatureUnitsPopup;
	IBOutlet NSPopUpButton* doubleClickActionPopup;
	IBOutlet NSPopUpButton* defaultMapType;
	IBOutlet NSPopUpButton* defaultXAxisType;
	IBOutlet NSPopUpButton* timeFormatPopup;
	IBOutlet NSPopUpButton* dateFormatPopup;
	IBOutlet NSPopUpButton* weekStartPopup;
	IBOutlet NSTextField*   customFieldLabel;
	IBOutlet NSTextField*   keyword1Label;
	IBOutlet NSTextField*   keyword2Label;
	IBOutlet NSPopUpButton* activityPopup;
	IBOutlet NSPopUpButton* defaultEventTypePopup;
	IBOutlet NSPopUpButton* equipmentPopup;
	IBOutlet NSPopUpButton* startingLapNumberPopup;
	IBOutlet NSButton*		showIntervalMarkersButton;
	IBOutlet NSTextField*	intervalIncrementTextField;
	IBOutlet NSStepper*		intervalIncrementStepper;
	IBOutlet NSTextField*	intervalIncrementUnitsLabel;
	IBOutlet NSSlider*		scrollingSensitivitySlider;
}
- (IBAction)setShowIntervalMarkers:(id)sender;
- (IBAction)setIntervalIncrement:(id)sender;
- (IBAction)setScrollingSensitivity:(id)sender;

@end
