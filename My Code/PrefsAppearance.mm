//
//  PrefsAppearance.mm
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsAppearance.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "Utils.h"

NSString* RCBDefaultAltitudeColor      = @"DefaultAltitudeColor";
NSString* RCBDefaultSpeedColor         = @"DefaultSpeedColor";
NSString* RCBDefaultMovingSpeedColor   = @"DefaultMovingSpeedColor";
NSString* RCBDefaultPaceColor          = @"DefaultPaceColor";
NSString* RCBDefaultMovingPaceColor    = @"DefaultMovingPaceColor";
NSString* RCBDefaultHeartrateColor     = @"DefaultHeartrateColor";
NSString* RCBDefaultGradientColor      = @"DefaultGradientColor";
NSString* RCBDefaultTemperatureColor   = @"DefaultTemperatureColor";
NSString* RCBDefaultCadenceColor       = @"DefaultCadenceColor";
NSString* RCBDefaultPowerColor			= @"DefaultPowerColor";
NSString* RCBDefaultDistanceColor      = @"DefaultDistanceColor";
NSString* RCBDefaultPathColor          = @"DefaultPathColor";
NSString* RCBDefaultLapColor           = @"DefaultLapColor";
NSString* RCBDefaultWeightColor        = @"DefaultWeightColor";
NSString* RCBDefaultBackgroundColor    = @"DefaultBackgroundColor";
NSString* RCBDefaultDurationColor      = @"DefaultDurationColor";
NSString* RCBDefaultMovingDurationColor = @"DefaultMovingDurationColor";
NSString* RCBDefaultCaloriesColor      = @"DefaultCaloriesColor";
NSString* RCBDefaultMapTransparency    = @"DefaultMapTransparency";
NSString* RCBDefaultPathTransparency   = @"DefaultPathTransparency";
NSString* RCBDefaultAnimPanelTransparency   = @"DefaultAnimPanelTransparency";
NSString* RCBDefaultMarkersPanelTransparency   = @"DefaultMarkersPanelTransparency";

NSString*  RCBDefaultBrowserYearColor       = @"DefaultBrowserYearColor";
NSString*  RCBDefaultBrowserMonthColor      = @"DefaultBrowserMonthColor";
NSString*  RCBDefaultBrowserWeekColor       = @"DefaultBrowserWeekColor";
NSString*  RCBDefaultBrowserActivityColor   = @"DefaultBrowserActivityColor";
NSString*  RCBDefaultBrowserLapColor        = @"DefaultBrowserLapColor";
NSString*  RCBDefaultSplitColor				= @"DefaultSplitColor";

@implementation PrefsAppearance

- (IBAction)setValueForSender:(id)sender;
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	int tag = (int) [sender tag];
   if (tag > 0)
   {
      NSString* key = [Utils defaultColorKey:tag];
       if (![key isEqualToString:@""])
      {
         [defaults setColor:[sender color] forKey:key];
      }
   }
   else if (sender == pathTransparencySlider)
   {
      [defaults setFloat:[sender floatValue] forKey:@"DefaultPathTransparency"];
   }
   else if (sender == mapTransparencySlider)
   {
      [defaults setFloat:[sender floatValue] forKey:@"DefaultMapTransparency"];
   }
   [[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChanged object:nil];
   [defaults synchronize];
}




-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController]  defaults];
   NSArray* subviews = [self.controlBox subviews];
   int num = [subviews count];
   int i;
   for (i=0; i<num; i++)
   {
      id view = [subviews objectAtIndex:i];
      int tag = [view tag];
      if (tag > 0)
      {
         NSString* key = [Utils defaultColorKey:tag];
         if (![key isEqualToString:@""])
         {
            NSColorWell* colorView = (NSColorWell*) view;
            [colorView setColor:[defaults colorForKey:key]];
         }
      }
   }  
   [pathTransparencySlider setFloatValue:[defaults floatForKey:@"DefaultPathTransparency"]];
   [mapTransparencySlider  setFloatValue:[defaults floatForKey:@"DefaultMapTransparency" ]];
}

@end
