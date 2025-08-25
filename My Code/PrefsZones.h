//
//  PrefsZones.h
//  Ascent
//
//  Created by Rob Boyer on 5/6/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <OmniAppKit/OAPreferenceClient.h>


@interface PrefsZones : OAPreferenceClient 
{
   IBOutlet NSColorWell*   belowZoneColor;
   IBOutlet NSTextField*   belowZoneRangeField;
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
   IBOutlet NSPopUpButton* zoneTypePopup;
}

- (IBAction)setValueForSender:(id)sender;


@end
