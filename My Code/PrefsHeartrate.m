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

static inline NSInteger pct(NSInteger v, NSInteger mx)
{
    if (mx != 0)
        return ((v * 100) + (mx - 1)) / mx;
    else
        return 0;
}

- (void)updateRanges
{
    NSInteger maxhr = [maxHeartRateField integerValue];

    NSInteger top = 100;
    NSInteger v = [zone5ThresholdField integerValue];
    [zone5RangeField setStringValue:[NSString stringWithFormat:@"%ld-%ld%%", (long)pct(v, maxhr), (long)top]];

    top = v;
    v = [zone4ThresholdField integerValue];
    [zone4RangeField setStringValue:[NSString stringWithFormat:@"%ld-%ld%%", (long)pct(v, maxhr), (long)pct(top, maxhr)]];

    top = v;
    v = [zone3ThresholdField integerValue];
    [zone3RangeField setStringValue:[NSString stringWithFormat:@"%ld-%ld%%", (long)pct(v, maxhr), (long)pct(top, maxhr)]];

    top = v;
    v = [zone2ThresholdField integerValue];
    [zone2RangeField setStringValue:[NSString stringWithFormat:@"%ld-%ld%%", (long)pct(v, maxhr), (long)pct(top, maxhr)]];

    top = v;
    v = [zone1ThresholdField integerValue];
    [zone1RangeField setStringValue:[NSString stringWithFormat:@"%ld-%ld%%", (long)pct(v, maxhr), (long)pct(top, maxhr)]];

    [belowZoneRangeField setStringValue:[NSString stringWithFormat:@"< %ld%%", (long)pct(v, maxhr)]];
}

- (void)adjustRanges
{
    /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
     OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];

    NSInteger maxhr = [maxHeartRateField integerValue];
    NSInteger v = [zone5ThresholdField integerValue];
    if (v > maxhr)
    {
        v = maxhr;
        [zone5ThresholdField setIntegerValue:v];
        [zone5ThresholdStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone5Threshold];
    }
    //----
    maxhr = v;
    v = [zone4ThresholdField integerValue];
    if (v > maxhr)
    {
        v = maxhr;
        [zone4ThresholdField setIntegerValue:v];
        [zone4ThresholdStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone4Threshold];
    }
    //----
    maxhr = v;
    v = [zone3ThresholdField integerValue];
    if (v > maxhr)
    {
        v = maxhr;
        [zone3ThresholdField setIntegerValue:v];
        [zone3ThresholdStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone3Threshold];
    }
    //----
    maxhr = v;
    v = [zone2ThresholdField integerValue];
    if (v > maxhr)
    {
        v = maxhr;
        [zone2ThresholdField setIntegerValue:v];
        [zone2ThresholdStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone2Threshold];
    }
    //----
    maxhr = v;
    v = [zone1ThresholdField integerValue];
    if (v > maxhr)
    {
        v = maxhr;
        [zone1ThresholdField setIntegerValue:v];
        [zone1ThresholdStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone1Threshold];
    }
    [self updateRanges];
}

- (void)enableFields:(BOOL)enabled
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

- (void)setHRZoneRanges:(int)z1
                  zone2:(int)z2
                  zone3:(int)z3
                  zone4:(int)z4
                  zone5:(int)z5
{
    NSUserDefaults *defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];

    [self enableFields:YES];

    [zone1ThresholdField setIntegerValue:z1];
    [zone1ThresholdStepper setIntegerValue:z1];
    [defaults setInteger:z1 forKey:RCBDefaultZone1Threshold];

    [zone2ThresholdField setIntegerValue:z2];
    [zone2ThresholdStepper setIntegerValue:z2];
    [defaults setInteger:z2 forKey:RCBDefaultZone2Threshold];

    [zone3ThresholdField setIntegerValue:z3];
    [zone3ThresholdStepper setIntegerValue:z3];
    [defaults setInteger:z3 forKey:RCBDefaultZone3Threshold];

    [zone4ThresholdField setIntegerValue:z4];
    [zone4ThresholdStepper setIntegerValue:z4];
    [defaults setInteger:z4 forKey:RCBDefaultZone4Threshold];

    [zone5ThresholdField setIntegerValue:z5];
    [zone5ThresholdStepper setIntegerValue:z5];
    [defaults setInteger:z5 forKey:RCBDefaultZone5Threshold];

    [self enableFields:[defaults integerForKey:RCBDefaultHRZoneMethod] == kCustom];
    [self updateRanges];
}

- (void)applyMethod
{
    NSUserDefaults *defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];

    NSInteger method = [defaults integerForKey:RCBDefaultHRZoneMethod];
    NSInteger maxhr  = [defaults integerForKey:RCBDefaultMaxHeartrate];
    NSInteger resthr = [defaults integerForKey:RCBDefaultRestingHeartrate];

    switch (method)
    {
        case kClassic:           // Classic
            [self setHRZoneRanges:(int)(50 * maxhr / 100)
                             zone2:(int)(60 * maxhr / 100)
                             zone3:(int)(70 * maxhr / 100)
                             zone4:(int)(80 * maxhr / 100)
                             zone5:(int)(90 * maxhr / 100)];
            break;

        case kKervonen:           // Kervonen
        {
            CGFloat deltaHR = (CGFloat)(maxhr - resthr);
            [self setHRZoneRanges:(int)((deltaHR * 0.50) + (CGFloat)resthr)
                             zone2:(int)((deltaHR * 0.60) + (CGFloat)resthr)
                             zone3:(int)((deltaHR * 0.70) + (CGFloat)resthr)
                             zone4:(int)((deltaHR * 0.80) + (CGFloat)resthr)
                             zone5:(int)((deltaHR * 0.90) + (CGFloat)resthr)];
        }
            break;

        case kZoladz:           // Zoladz
            [self setHRZoneRanges:(int)(maxhr - 50)
                             zone2:(int)(maxhr - 40)
                             zone3:(int)(maxhr - 30)
                             zone4:(int)(maxhr - 20)
                             zone5:(int)(maxhr - 10)];
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
    /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
     OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];

    NSInteger v;
    if (sender == maxHeartRateStepper)
    {
        v = [sender integerValue];
        [maxHeartRateField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultMaxHeartrate];
        [self applyMethod];
        [self updateRanges];
    }
    else if (sender == restingHeartRateStepper)
    {
        v = [sender integerValue];
        [restingHeartRateField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultRestingHeartrate];
        [self applyMethod];
        [self updateRanges];
    }
    else if (sender == estimateMaxHeartRateButton)
    {
        NSInteger ag = [ageField integerValue];
        CGFloat temp = (0.685f * (CGFloat)ag);
        temp = (205.8f - temp);
        v = (NSInteger)lrintf((float)temp);
        [maxHeartRateField setIntegerValue:v];
        [maxHeartRateStepper setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultMaxHeartrate];
        [self applyMethod];
        [self updateRanges];
    }
    else if (sender == zone5ThresholdStepper)
    {
        v = [sender integerValue];
        [zone5ThresholdField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone5Threshold];
        [self adjustRanges];
    }
    else if (sender == zone4ThresholdStepper)
    {
        v = [sender integerValue];
        [zone4ThresholdField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone4Threshold];
        [self adjustRanges];
    }
    else if (sender == zone3ThresholdStepper)
    {
        v = [sender integerValue];
        [zone3ThresholdField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone3Threshold];
        [self adjustRanges];
    }
    else if (sender == zone2ThresholdStepper)
    {
        v = [sender integerValue];
        [zone2ThresholdField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone2Threshold];
        [self adjustRanges];
    }
    else if (sender == zone1ThresholdStepper)
    {
        v = [sender integerValue];
        [zone1ThresholdField setIntegerValue:v];
        [defaults setInteger:v forKey:RCBDefaultZone1Threshold];
        [self adjustRanges];
    }
    else if (sender == belowZoneColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultBelowZoneColor];
    }
    else if (sender == zone1RangeColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultZone1Color];
    }
    else if (sender == zone2RangeColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultZone2Color];
    }
    else if (sender == zone3RangeColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultZone3Color];
    }
    else if (sender == zone4RangeColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultZone4Color];
    }
    else if (sender == zone5RangeColor)
    {
        [defaults setColor:[sender color] forKey:RCBDefaultZone5Color];
    }
    else if (sender == calcMethodPopup)
    {
        NSInteger method = [sender indexOfSelectedItem];
        [defaults setInteger:method forKey:RCBDefaultHRZoneMethod];
        [self applyMethod];
        [self updateRanges];
    }

    [defaults synchronize];
}

- (void)updateUI
{
    /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
     OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];

    [maxHeartRateField setIntegerValue:[defaults integerForKey:RCBDefaultMaxHeartrate]];
    [maxHeartRateStepper setIntegerValue:[defaults integerForKey:RCBDefaultMaxHeartrate]];
    [restingHeartRateField setIntegerValue:[defaults integerForKey:RCBDefaultRestingHeartrate]];
    [restingHeartRateStepper setIntegerValue:[defaults integerForKey:RCBDefaultRestingHeartrate]];
    [ageField setIntegerValue:[defaults integerForKey:RCBDefaultAge]];

    NSInteger v;

    v = [defaults integerForKey:RCBDefaultZone5Threshold];
    [zone5ThresholdField setIntegerValue:v];
    [zone5ThresholdStepper setIntegerValue:v];

    v = [defaults integerForKey:RCBDefaultZone4Threshold];
    [zone4ThresholdField setIntegerValue:v];
    [zone4ThresholdStepper setIntegerValue:v];

    v = [defaults integerForKey:RCBDefaultZone3Threshold];
    [zone3ThresholdField setIntegerValue:v];
    [zone3ThresholdStepper setIntegerValue:v];

    v = [defaults integerForKey:RCBDefaultZone2Threshold];
    [zone2ThresholdField setIntegerValue:v];
    [zone2ThresholdStepper setIntegerValue:v];

    v = [defaults integerForKey:RCBDefaultZone1Threshold];
    [zone1ThresholdField setIntegerValue:v];
    [zone1ThresholdStepper setIntegerValue:v];

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

