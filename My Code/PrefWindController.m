//
//  PrefWindController.m
//  TLP
//
//  Created by Rob Boyer on 9/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "PrefWindController.h"
#import "Defs.h"
#import "DrawingUtilities.h"
#import "Utils.h"


NSString* RCBDefaultUnitsAreEnglishKey = @"DefaultUnitsAreEnglish";
NSString* RCBDefaultAltitudeColor      = @"DefaultAltitudeColor";
NSString* RCBDefaultSpeedColor         = @"DefaultSpeedColor";
NSString* RCBDefaultHeartrateColor     = @"DefaultHeartrateColor";
NSString* RCBDefaultGradientColor      = @"DefaultGradientColor";
NSString* RCBDefaultTemperatureColor   = @"DefaultTemperatureColor";
NSString* RCBDefaultCadenceColor       = @"DefaultCadenceColor";
NSString* RCBDefaultDistanceColor      = @"DefaultDistanceColor";
NSString* RCBDefaultPathColor          = @"DefaultPathColor";
NSString* RCBDefaultLapColor           = @"DefaultLapColor";
NSString* RCBDefaultWeightColor        = @"DefaultWeightColor";
NSString* RCBDefaultBackgroundColor    = @"DefaultBackgroundColor";
NSString* RCBDefaultDurationColor      = @"DefaultDurationColor";


void setRGBColorDefault(NSUserDefaults* defs,
                        NSString* theKey,
                        float r, float g, float b, float a)
{
   NSData* colorAsData = [NSKeyedArchiver archivedDataWithRootObject:
      [NSColor colorWithCalibratedRed:r 
                                green:g 
                                 blue:b
                                alpha:a]];
   [defs setObject:colorAsData forKey:theKey];
}


@implementation PrefWindController

- (id)init
{
   self = [super initWithWindowNibName:@"Preferences"];
   return self;
}


- (NSColor*) colorFromDefaults:(NSString*)key
{
   NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
   NSData* colorAsData = [defaults objectForKey:key];
   return [NSKeyedUnarchiver unarchiveObjectWithData:colorAsData];
}


- (void)windowDidLoad
{
   NSLog(@"Preferences NIB file loaded");
   NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
   BOOL useEnglish = [defaults boolForKey:RCBDefaultUnitsAreEnglishKey];
   if (useEnglish)
   {
      [unitsMatrix setState:NSOnState atRow:0 column:0];
   } 
   else
   {
      [unitsMatrix setState:NSOnState atRow:1 column:0];
   }   

   NSArray* subviews = [[[self window] contentView] subviews];
   int num = [subviews count];
   int i;
   for (i=0; i<num; i++)
   {
      id view = [subviews objectAtIndex:i];
      int tag = [view tag];
      NSString* key = [Utils defaultColorKey:tag];
      if (![key isEqualToString:@""])
      {
         NSColorWell* colorView = (NSColorWell*) view;
         [colorView setColor:[self colorFromDefaults:key]];
      }    
   }
}


- (BOOL)defaultUnitsAreEnglish
{
   NSUserDefaults* defaults;
   defaults = [NSUserDefaults standardUserDefaults];
   return [defaults boolForKey:RCBDefaultUnitsAreEnglishKey];
}




- (IBAction) setColor:(id)sender
{
   int tag = [sender tag];
   NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
   NSColorWell* colorView = (NSColorWell*) sender;
   NSColor* color = [colorView color];
   NSString* key = [Utils defaultColorKey:tag];
   if (key != @"")
   {
      float r, g, b, a;
      [color getRed:&r green:&g blue:&b alpha:&a];
      setRGBColorDefault(defaults, key,  r, g, b, a);
   }
}


- (IBAction) setDefaultColors:(id)sender
{
}


- (IBAction) changeDefaultUnits:(id)sender
{
   NSLog(@"Default Units Changed");
   BOOL useEnglish = [[sender selectedCell] tag] == 0;
   [[NSUserDefaults standardUserDefaults] setBool:useEnglish forKey:RCBDefaultUnitsAreEnglishKey];
}

         
@end
