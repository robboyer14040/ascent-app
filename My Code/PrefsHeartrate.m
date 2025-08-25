//
//  PrefsHeartrate.m
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsHeartrate.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>

NSString*  RCBDefaultMaxHeartrate      = @"DefaultMaxHeartrate";
NSString*  RCBDefaultZone1Threshold    = @"DefaultZone1Threshold";
NSString*  RCBDefaultZone2Threshold    = @"DefaultZone2Threshold";
NSString*  RCBDefaultZone3Threshold    = @"DefaultZone3Threshold";
NSString*  RCBDefaultZone4Threshold    = @"DefaultZone4Threshold";
NSString*  RCBDefaultZone5Threshold    = @"DefaultZone5Threshold";
NSString*  RCBDefaultBelowZoneColor    = @"DefaultBelowZoneColor";
NSString*  RCBDefaultZone1Color        = @"DefaultZone1Color";
NSString*  RCBDefaultZone2Color        = @"DefaultZone2Color";
NSString*  RCBDefaultZone3Color        = @"DefaultZone3Color";
NSString*  RCBDefaultZone4Color        = @"DefaultZone4Color";
NSString*  RCBDefaultZone5Color        = @"DefaultZone5Color";
NSString*  RCBDefaultAge               = @"DefaultAge";
NSString*  RCBDefaultRestingHeartrate  = @"DefaultRestingHeartrate";
NSString*  RCBDefaultHRZoneMethod      = @"DefaultHRZoneMethod";


enum
{
   kClassic,
   kKervonen,
   kZoladz,
   kCustom
};


@implementation PrefsHeartrate


int pct(int v, int mx)
{
   if (mx != 0)
      return ((v*100)+(mx-1))/mx;
   else
      return 0;
}


- (void) updateRanges
{
   int maxhr = [maxHeartRateField intValue];

   int top = 100;
   int v = [zone5ThresholdField intValue];
   [zone5RangeField setStringValue:[NSString stringWithFormat:@"%d-%d%%", pct(v, maxhr), top]];

   top = v;
   v = [zone4ThresholdField intValue];
   [zone4RangeField setStringValue:[NSString stringWithFormat:@"%d-%d%%", pct(v, maxhr), pct(top, maxhr)]];

   top = v;
   v = [zone3ThresholdField intValue];
   [zone3RangeField setStringValue:[NSString stringWithFormat:@"%d-%d%%", pct(v, maxhr), pct(top, maxhr)]];
   
   top = v;
   v = [zone2ThresholdField intValue];
   [zone2RangeField setStringValue:[NSString stringWithFormat:@"%d-%d%%", pct(v, maxhr), pct(top, maxhr)]];
   
   top = v;
   v = [zone1ThresholdField intValue];
   [zone1RangeField setStringValue:[NSString stringWithFormat:@"%d-%d%%",  pct(v, maxhr), pct(top, maxhr)]];
   
   [belowZoneRangeField setStringValue:[NSString stringWithFormat:@"< %d%%",  pct(v, maxhr)]];
}


- (void) adjustRanges
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   int maxhr = [maxHeartRateField intValue];
   int v = [zone5ThresholdField intValue];
   if (v > maxhr)
   {
      v = maxhr;
      [zone5ThresholdField setIntValue:v];
      [zone5ThresholdStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone5Threshold];

   }
   //----
   maxhr = v;
   v = [zone4ThresholdField intValue];
   if (v > maxhr)
   {
      v = maxhr;
      [zone4ThresholdField setIntValue:v];
      [zone4ThresholdStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone4Threshold];
   }
   //----
   maxhr = v;
   v = [zone3ThresholdField intValue];
   if (v > maxhr)
   {
      v = maxhr;
      [zone3ThresholdField setIntValue:v];
      [zone3ThresholdStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone3Threshold];
   }
   //----
   maxhr = v;
   v = [zone2ThresholdField intValue];
   if (v > maxhr)
   {
      v = maxhr;
      [zone2ThresholdField setIntValue:v];
      [zone2ThresholdStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone2Threshold];
   }
   //----
   maxhr = v;
   v = [zone1ThresholdField intValue];
   if (v > maxhr)
   {
      v = maxhr;
      [zone1ThresholdField setIntValue:v];
      [zone1ThresholdStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone1Threshold];
   }
   [self updateRanges];
   
}


-(void) enableFields:(BOOL)enabled
{
   [zone1ThresholdField setEnabled:enabled];
   [zone1ThresholdStepper setEnabled:enabled];
   [zone2ThresholdField setEnabled:enabled];
   [zone2ThresholdStepper setEnabled:enabled];
   [zone3ThresholdField setEnabled:enabled];
   [zone3ThresholdStepper setEnabled:enabled];
   [zone4ThresholdField setEnabled:enabled];
   [zone4ThresholdStepper setEnabled:enabled];
   [zone5ThresholdField setEnabled:enabled];
   [zone5ThresholdStepper setEnabled:enabled];
}


- (void) setHRZoneRanges:(int)z1
                   zone2:(int)z2
                   zone3:(int)z3
                   zone4:(int)z4
                   zone5:(int)z5
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   [self enableFields:YES];
   [zone1ThresholdField setIntValue:z1];
   [zone1ThresholdStepper setIntValue:z1];
   [defaults setInteger:z1 forKey:RCBDefaultZone1Threshold];
   
   [zone2ThresholdField setIntValue:z2];
   [zone2ThresholdStepper setIntValue:z2];
   [defaults setInteger:z2 forKey:RCBDefaultZone2Threshold];
   
   [zone3ThresholdField setIntValue:z3];
   [zone3ThresholdStepper setIntValue:z3];
   [defaults setInteger:z3 forKey:RCBDefaultZone3Threshold];
   
   [zone4ThresholdField setIntValue:z4];
   [zone4ThresholdStepper setIntValue:z4];
   [defaults setInteger:z4 forKey:RCBDefaultZone4Threshold];
   
   [zone5ThresholdField setIntValue:z5];
   [zone5ThresholdStepper setIntValue:z5];
   [defaults setInteger:z5 forKey:RCBDefaultZone5Threshold];
   
   [self enableFields:[defaults integerForKey:RCBDefaultHRZoneMethod] == kCustom];
   [self updateRanges];
}


-(void) applyMethod
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   int method = [defaults integerForKey:RCBDefaultHRZoneMethod];
   int maxhr = [defaults integerForKey:RCBDefaultMaxHeartrate];
   int resthr = [defaults integerForKey:RCBDefaultRestingHeartrate];
   switch (method)
   {
      case kClassic:           // Classic
         [self setHRZoneRanges:(50*maxhr/100)
                         zone2:(60*maxhr/100)
                         zone3:(70*maxhr/100)
                         zone4:(80*maxhr/100)
                         zone5:(90*maxhr/100)];
         break;
      
      case kKervonen:           // Kervonen
      {
         float deltaHR = maxhr - resthr;
         [self setHRZoneRanges:(int)((deltaHR * .50) + (float)resthr)
                         zone2:(int)((deltaHR * .60) + (float)resthr)
                         zone3:(int)((deltaHR * .70) + (float)resthr)
                         zone4:(int)((deltaHR * .80) + (float)resthr)
                         zone5:(int)((deltaHR * .90) + (float)resthr)];
      }
         break;
      
      case kZoladz:           // Zoladz
         [self setHRZoneRanges:maxhr - 50
                         zone2:maxhr - 40
                         zone3:maxhr - 30
                         zone4:maxhr - 20
                         zone5:maxhr - 10];
         break;
      
      case kCustom:           // Custom
         break;
         
      default:
         break;
   }
   [self enableFields:(method == kCustom)];
}   


- (IBAction)setValueForSender:(id)sender;
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   int v;
   if (sender == maxHeartRateStepper)
   {
      v = [sender intValue];
      [maxHeartRateField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultMaxHeartrate];
      [self applyMethod];
      [self updateRanges];
   }
   else if (sender == restingHeartRateStepper)
   {
      v = [sender intValue];
      [restingHeartRateField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultRestingHeartrate];
      [self applyMethod];
      [self updateRanges];
   }
   else if (sender == estimateMaxHeartRateButton)
   {
      int ag = [ageField intValue];
      float temp = (0.685 * (float)ag);
      temp = (205.8 - temp);
      v = (int)temp;
      [maxHeartRateField setIntValue:v];
      [maxHeartRateStepper setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultMaxHeartrate];
      [self applyMethod];
      [self updateRanges];
   }
   else if (sender == zone5ThresholdStepper)
   {
      v = [sender intValue];
      [zone5ThresholdField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone5Threshold];
      [self adjustRanges];
   }
   else if (sender == zone4ThresholdStepper)
   {
      v = [sender intValue];
      [zone4ThresholdField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone4Threshold];
      [self adjustRanges];
   }
   else if (sender == zone3ThresholdStepper)
   {
      int v = [sender intValue];
      [zone3ThresholdField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone3Threshold];
      [self adjustRanges];
   }
   else if (sender == zone2ThresholdStepper)
   {
      v = [sender intValue];
      [zone2ThresholdField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone2Threshold];
      [self adjustRanges];
   }
   else if (sender == zone1ThresholdStepper)
   {
      int v = [sender intValue];
      [zone1ThresholdField setIntValue:v];
      [defaults setInteger:v forKey:RCBDefaultZone1Threshold];
      [self adjustRanges];
   }
   else if (sender == belowZoneColor)
      [defaults setColor:[sender color] forKey:RCBDefaultBelowZoneColor];
   else if (sender == zone1RangeColor)
      [defaults setColor:[sender color] forKey:RCBDefaultZone1Color];
   else if (sender == zone2RangeColor)
      [defaults setColor:[sender color] forKey:RCBDefaultZone2Color];
   else if (sender == zone3RangeColor)
      [defaults setColor:[sender color] forKey:RCBDefaultZone3Color];
   else if (sender == zone4RangeColor)
      [defaults setColor:[sender color] forKey:RCBDefaultZone4Color];
   else if (sender == zone5RangeColor)
      [defaults setColor:[sender color] forKey:RCBDefaultZone5Color];
   else if (sender == calcMethodPopup)
   {
      int method = [sender indexOfSelectedItem];
      [defaults setInteger:method forKey:RCBDefaultHRZoneMethod];
      [self applyMethod];
      [self updateRanges];
   }
   
   [defaults synchronize];
}


-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   [maxHeartRateField setIntValue:[defaults integerForKey:RCBDefaultMaxHeartrate]];
   [maxHeartRateStepper setIntValue:[defaults integerForKey:RCBDefaultMaxHeartrate]];
   [restingHeartRateField setIntValue:[defaults integerForKey:RCBDefaultRestingHeartrate]];
   [restingHeartRateStepper setIntValue:[defaults integerForKey:RCBDefaultRestingHeartrate]];
   [ageField setIntValue:[defaults integerForKey:RCBDefaultAge]];
   
   int v;
   
   v = [defaults integerForKey:RCBDefaultZone5Threshold];
   [zone5ThresholdField setIntValue:v];
   [zone5ThresholdStepper setIntValue:v];

   v = [defaults integerForKey:RCBDefaultZone4Threshold];
   [zone4ThresholdField setIntValue:v];
   [zone4ThresholdStepper setIntValue:v];
   
   v = [defaults integerForKey:RCBDefaultZone3Threshold];
   [zone3ThresholdField setIntValue:v];
   [zone3ThresholdStepper setIntValue:v];
   
   v = [defaults integerForKey:RCBDefaultZone2Threshold];
   [zone2ThresholdField setIntValue:v];
   [zone2ThresholdStepper setIntValue:v];

   v = [defaults integerForKey:RCBDefaultZone1Threshold];
   [zone1ThresholdField setIntValue:v];
   [zone1ThresholdStepper setIntValue:v];
   
   [belowZoneColor  setColor:[defaults colorForKey:RCBDefaultBelowZoneColor]];
   [zone1RangeColor setColor:[defaults colorForKey:RCBDefaultZone1Color]];
   [zone2RangeColor setColor:[defaults colorForKey:RCBDefaultZone2Color]];
   [zone3RangeColor setColor:[defaults colorForKey:RCBDefaultZone3Color]];
   [zone4RangeColor setColor:[defaults colorForKey:RCBDefaultZone4Color]];
   [zone5RangeColor setColor:[defaults colorForKey:RCBDefaultZone5Color]];

   [calcMethodPopup selectItemAtIndex:[defaults integerForKey:RCBDefaultHRZoneMethod]];
   [self enableFields:[defaults integerForKey:RCBDefaultHRZoneMethod] == kCustom];
   [self applyMethod];
   [self updateRanges];
}


@end
