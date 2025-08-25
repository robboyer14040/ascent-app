//
//  PrefsHeartrate.h
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsHeartrate : OAPreferenceClient 
{
   IBOutlet NSColorWell*   belowZoneColor;
   IBOutlet NSTextField*   belowZoneRangeField;
   IBOutlet NSTextField*   maxHeartRateField;
   IBOutlet NSStepper*     maxHeartRateStepper;
   IBOutlet NSTextField*   zone1RangeField;
   IBOutlet NSColorWell*   zone1RangeColor;
   IBOutlet NSTextField*   zone1ThresholdField;
   IBOutlet NSStepper*     zone1ThresholdStepper;
   IBOutlet NSTextField*   zone2ThresholdField;
   IBOutlet NSStepper*     zone2ThresholdStepper;
   IBOutlet NSTextField*   zone2RangeField;
   IBOutlet NSColorWell*   zone2RangeColor;
   IBOutlet NSTextField*   zone3ThresholdField;
   IBOutlet NSStepper*     zone3ThresholdStepper;
   IBOutlet NSTextField*   zone3RangeField;
   IBOutlet NSColorWell*   zone3RangeColor;
   IBOutlet NSTextField*   zone4ThresholdField;
   IBOutlet NSStepper*     zone4ThresholdStepper;
   IBOutlet NSTextField*   zone4RangeField;
   IBOutlet NSColorWell*   zone4RangeColor;
   IBOutlet NSTextField*   zone5RangeField;
   IBOutlet NSColorWell*   zone5RangeColor;
   IBOutlet NSTextField*   zone5ThresholdField;
   IBOutlet NSStepper*     zone5ThresholdStepper;
   IBOutlet NSButton*      applyDefaultRangesButton;
   IBOutlet NSPopUpButton* calcMethodPopup;
   IBOutlet NSTextField*   ageField;
   IBOutlet NSTextField*   restingHeartRateField;
   IBOutlet NSStepper*     restingHeartRateStepper;
   IBOutlet NSButton*      estimateMaxHeartRateButton;
}

- (IBAction)setValueForSender:(id)sender;


@end
