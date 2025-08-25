//
//  PrefsZones.mm
//  Ascent
//
//  Created by Rob Boyer on 5/6/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "PrefsZones.h"
#import "Defs.h"
#import "Utils.h"
#import "AscentIntervalFormatter.h"


NSString*  RCBDefaultZoneType			= @"DefaultZoneType";
NSString*  RCBDefaultSpeedZones			= @"DefaultSpeedZones";
NSString*  RCBDefaultPaceZones			= @"DefaultPaceZones";
NSString*  RCBDefaultGradientZones		= @"DefaultGradientZones";
NSString*  RCBDefaultCadenceZones		= @"DefaultCadenceZones";
NSString*  RCBDefaultPowerZones			= @"DefaultPowerZones";
NSString*  RCBDefaultAltitudeZones		= @"DefaultAltitudeZones";
NSString*  RCBDefaultAboveZoneColor		= @"DefaultAboveZoneColor";


@implementation PrefsZones



- (void) adjustRanges:(NSMutableDictionary*) mdict isRevType:(BOOL)isRevType
{
   float max = 999999999;
   float min = -9999999;
   
   float v = [[mdict objectForKey:RCBDefaultZone5Threshold] floatValue];
   if ((isRevType && (v < min)) || (!isRevType && (v > max)))
   {
      v = isRevType ? min : max;
      [zone5ThresholdField setFloatValue:v];
      [zone5ThresholdStepper setFloatValue:v];
      [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone5Threshold];
   }
   
   //----
   max = min = v;
   v = [[mdict objectForKey:RCBDefaultZone4Threshold] floatValue];
   if ((isRevType && (v < min)) || (!isRevType && (v > max)))
   {
      v = isRevType ? min : max;
      [zone4ThresholdField setFloatValue:v];
      [zone4ThresholdStepper setFloatValue:v];
      [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone4Threshold];
   }
   
   //----
   max = min = v;
   v = [[mdict objectForKey:RCBDefaultZone3Threshold] floatValue];
   if ((isRevType && (v < min)) || (!isRevType && (v > max)))
   {
      v = isRevType ? min : max;
      [zone3ThresholdField setFloatValue:v];
      [zone3ThresholdStepper setFloatValue:v];
      [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone3Threshold];
   }
   
   //----
   max = min = v;
   v = [[mdict objectForKey:RCBDefaultZone2Threshold] floatValue];
   if ((isRevType && (v < min)) || (!isRevType && (v > max)))
   {
      v = isRevType ? min : max;
      [zone2ThresholdField setFloatValue:v];
      [zone2ThresholdStepper setFloatValue:v];
      [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone2Threshold];
   }
   
   //----
   max = min = v;
   v = [[mdict objectForKey:RCBDefaultZone1Threshold] floatValue];
   if ((isRevType && (v < min)) || (!isRevType && (v > max)))
   {
      v = isRevType ? min : max;
      [zone1ThresholdField setFloatValue:v];
      [zone1ThresholdStepper setFloatValue:v];
      [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone1Threshold];
   }
}


-(void) updatePaceFields:(NSDictionary*)dict
{
   AscentIntervalFormatter* fmt = [[[AscentIntervalFormatter alloc] initAsPace:YES] autorelease];
   
   int v;
   int top;
   v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]] + 0.5;
   [zone5ThresholdField setFormatter:fmt];
   [zone5ThresholdField setIntValue:v];
   [zone5RangeField setStringValue:[NSString stringWithFormat:@"≤%02d:%02d", v/60, v%60]];

   top = v+1.0;
   v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]] + 0.5;
   [zone4ThresholdField setFormatter:fmt];
   [zone4ThresholdField setIntValue:v];
   [zone4RangeField setStringValue:[NSString stringWithFormat:@"%02d:%02d ➔%02d:%02d", top/60, top % 60 , v/60, v%60 ]];

   top = v+1.0;
   v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]] + 0.5;
   [zone3ThresholdField setFormatter:fmt];
   [zone3ThresholdField setIntValue:v];
   [zone3RangeField setStringValue:[NSString stringWithFormat:@"%02d:%02d ➔%02d:%02d", top/60, top % 60 , v/60, v%60 ]];
   
   top = v+1.0;
   v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]] + 0.5;
   [zone2ThresholdField setFormatter:fmt];
   [zone2ThresholdField setIntValue:v];
   [zone2RangeField setStringValue:[NSString stringWithFormat:@"%02d:%02d ➔%02d:%02d", top/60, top % 60, v/60, v%60 ]];
   
   top = v+1.0;
   v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]] + 0.5;
   [zone1ThresholdField setFormatter:fmt];
   [zone1ThresholdField setIntValue:v];
   [zone1RangeField setStringValue:[NSString stringWithFormat:@"%02d:%02d ➔%02d:%02d",    top/60, top % 60, v/60, v%60  ]];

   [belowZoneRangeField setStringValue:[NSString stringWithFormat:@">%02d:%02d",   v/60, v%60  ]];
}


-(void) updateAltitudeFields:(NSDictionary*)dict
{
	NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
	[fmt setMaximumFractionDigits:0];
	[fmt setFormat:@"####0"];
	
	float v, top;
	v = [Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]];
	[zone5ThresholdField setFormatter:fmt];
	[zone5ThresholdField setFloatValue:v];
	[zone5RangeField setStringValue:[NSString stringWithFormat:@"≥%0.0f", v]];
	
	top = v-1.0;
	v = [Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]];
	[zone4ThresholdField setFormatter:fmt];
	[zone4ThresholdField setFloatValue:v];
	[zone4RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f",  v, top]];
	
	top = v-1.0;
	v = [Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]];
	[zone3ThresholdField setFormatter:fmt];
	[zone3ThresholdField setFloatValue:v];
	[zone3RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f",  v, top]];
	
	top = v-1.0;
	v = [Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]];
	[zone2ThresholdField setFormatter:fmt];
	[zone2ThresholdField setFloatValue:v];
	[zone2RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f", v, top]];
	
	top = v-1.0;
	v = [Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]];
	[zone1ThresholdField setFormatter:fmt];
	[zone1ThresholdField setFloatValue:v];
	[zone1RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f", v, top]];
	
	[belowZoneRangeField setStringValue:[NSString stringWithFormat:@"<%0.0f", v]];
}


-(void) updateSpeedFields:(NSDictionary*)dict
{
   NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
   [fmt setMaximumFractionDigits:0];
   [fmt setFormat:@"##0"];
   
   float v, top;
   v = [Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]];
   [zone5ThresholdField setFormatter:fmt];
   [zone5ThresholdField setFloatValue:v];
   [zone5RangeField setStringValue:[NSString stringWithFormat:@"≥%0.0f", v]];

   top = v-1.0;
   v = [Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]];
   [zone4ThresholdField setFormatter:fmt];
   [zone4ThresholdField setFloatValue:v];
   [zone4RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f",  v, top]];

   top = v-1.0;
   v = [Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]];
   [zone3ThresholdField setFormatter:fmt];
   [zone3ThresholdField setFloatValue:v];
   [zone3RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f",  v, top]];

   top = v-1.0;
   v = [Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]];
   [zone2ThresholdField setFormatter:fmt];
   [zone2ThresholdField setFloatValue:v];
   [zone2RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f", v, top]];

   top = v-1.0;
   v = [Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]];
   [zone1ThresholdField setFormatter:fmt];
   [zone1ThresholdField setFloatValue:v];
   [zone1RangeField setStringValue:[NSString stringWithFormat:@"%0.0f ➔%0.0f", v, top]];

   [belowZoneRangeField setStringValue:[NSString stringWithFormat:@"<%0.0f", v]];
}


-(void) updateGradientFields:(NSDictionary*)dict
{
   NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
   [fmt setMaximumFractionDigits:1];
   [fmt setFormat:@"#0.0;0.0;-#0.0"];

   float v, top;
   top = v;
   v = [[dict objectForKey:RCBDefaultZone5Threshold] floatValue];
   [zone5ThresholdField setFormatter:fmt];
   [zone5ThresholdField setFloatValue:v];
   [zone5RangeField setStringValue:[NSString stringWithFormat:@"≥%0.1f", v]];

   top = v-0.1;
   v = [[dict objectForKey:RCBDefaultZone4Threshold] floatValue];
   [zone4ThresholdField setFormatter:fmt];
   [zone4ThresholdField setFloatValue:v];
   [zone4RangeField setStringValue:[NSString stringWithFormat:@"%0.1f ➔%0.1f",  v, top]];

   top = v;
   v = [[dict objectForKey:RCBDefaultZone3Threshold] floatValue];
   [zone3ThresholdField setFormatter:fmt];
   [zone3ThresholdField setFloatValue:v];
   [zone3RangeField setStringValue:[NSString stringWithFormat:@"%0.1f ➔%0.1f", v, top]];

   top = v;
   v = [[dict objectForKey:RCBDefaultZone2Threshold] floatValue];
   [zone2ThresholdField setFormatter:fmt];
   [zone2ThresholdField setFloatValue:v];
   [zone2RangeField setStringValue:[NSString stringWithFormat:@"%0.1f ➔%0.1f", v, top]];

   top = v;
   v = [[dict objectForKey:RCBDefaultZone1Threshold] floatValue];
   [zone1ThresholdField setFormatter:fmt];
   [zone1ThresholdField setFloatValue:v];
   [zone1RangeField setStringValue:[NSString stringWithFormat:@"%0.1f ➔%0.1f", v, top]];

   [belowZoneRangeField setStringValue:[NSString stringWithFormat:@"<%0.1f", v]];
}


-(void) updateCadenceFields:(NSDictionary*)dict
{
   NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
   [fmt setMaximumFractionDigits:0];
   [fmt setFormat:@"##0"];

   int v, top;
   v = [[dict objectForKey:RCBDefaultZone5Threshold] intValue];
   [zone5ThresholdField setFormatter:fmt];
   [zone5ThresholdField setFloatValue:v];
   [zone5RangeField setStringValue:[NSString stringWithFormat:@"≥%d", v]];

   top = v-1;
   v = [[dict objectForKey:RCBDefaultZone4Threshold] intValue];
   [zone4ThresholdField setFormatter:fmt];
   [zone4ThresholdField setFloatValue:v];
   [zone4RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d",  v, top]];

   top = v-1;
   v = [[dict objectForKey:RCBDefaultZone3Threshold] intValue];
   [zone3ThresholdField setFormatter:fmt];
   [zone3ThresholdField setFloatValue:v];
   [zone3RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d",  v, top]];
   top = v;

   top = v-1;
   v = [[dict objectForKey:RCBDefaultZone2Threshold] intValue];
   [zone2ThresholdField setFormatter:fmt];
   [zone2ThresholdField setFloatValue:v];
   [zone2RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d", v, top]];
 
   top = v-1;
   v = [[dict objectForKey:RCBDefaultZone1Threshold] intValue];
   [zone1ThresholdField setFormatter:fmt];
   [zone1ThresholdField setFloatValue:v];
   [zone1RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d", v, top]];

   [belowZoneRangeField setStringValue:[NSString stringWithFormat:@"<%d", v]];
 }


-(void) updatePowerFields:(NSDictionary*)dict
{
	NSNumberFormatter* fmt = [[[NSNumberFormatter alloc] init] autorelease];
	[fmt setMaximumFractionDigits:0];
	[fmt setFormat:@"##0"];
	
	int v, top;
	v = [[dict objectForKey:RCBDefaultZone5Threshold] intValue];
	[zone5ThresholdField setFormatter:fmt];
	[zone5ThresholdField setFloatValue:v];
	[zone5RangeField setStringValue:[NSString stringWithFormat:@"≥%d", v]];
	
	top = v-1.0;
	v = [[dict objectForKey:RCBDefaultZone4Threshold] intValue];
	[zone4ThresholdField setFormatter:fmt];
	[zone4ThresholdField setFloatValue:v];
	[zone4RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d",  v, top]];
	
	top = v-1.0;
	v = [[dict objectForKey:RCBDefaultZone3Threshold] intValue];
	[zone3ThresholdField setFormatter:fmt];
	[zone3ThresholdField setFloatValue:v];
	[zone3RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d",  v, top]];
	top = v;
	
	top = v-1.0;
	v = [[dict objectForKey:RCBDefaultZone2Threshold] intValue];
	[zone2ThresholdField setFormatter:fmt];
	[zone2ThresholdField setFloatValue:v];
	[zone2RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d", v, top]];
	
	top = v-1.0;
	v = [[dict objectForKey:RCBDefaultZone1Threshold] intValue];
	[zone1ThresholdField setFormatter:fmt];
	[zone1ThresholdField setFloatValue:v];
	[zone1RangeField setStringValue:[NSString stringWithFormat:@"%d ➔%d", v, top]];
	
	[belowZoneRangeField setStringValue:[NSString stringWithFormat:@"<%d", v]];
}


- (void) updateAltitudeSteppers:(NSDictionary*)dict
{
	double max = [Utils convertClimbValue:20000.0];
	double min = [Utils convertClimbValue:-1000.0];
	double incr = [Utils convertClimbValue: 10.0];
	[zone1ThresholdStepper setMaxValue:max];
	[zone1ThresholdStepper setMinValue:min];
	[zone1ThresholdStepper setIncrement:incr];
	[zone1ThresholdStepper setFloatValue:[Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]]];
	[zone2ThresholdStepper setMaxValue:max];
	[zone2ThresholdStepper setMinValue:min];
	[zone2ThresholdStepper setIncrement:incr];
	[zone2ThresholdStepper setFloatValue:[Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]]];
	[zone3ThresholdStepper setMaxValue:max];
	[zone3ThresholdStepper setMinValue:min];
	[zone3ThresholdStepper setIncrement:incr];
	[zone3ThresholdStepper setFloatValue:[Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]]];
	[zone4ThresholdStepper setMaxValue:max];
	[zone4ThresholdStepper setMinValue:min];
	[zone4ThresholdStepper setIncrement:incr];
	[zone4ThresholdStepper setFloatValue:[Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]]];
	[zone5ThresholdStepper setMaxValue:max];
	[zone5ThresholdStepper setMinValue:min];
	[zone5ThresholdStepper setIncrement:incr];
	[zone5ThresholdStepper setFloatValue:[Utils convertClimbValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]]];
}


- (void) updateSpeedSteppers:(NSDictionary*)dict
{
   double max = [Utils convertSpeedValue:100.0];
   double min = [Utils convertSpeedValue:0.0];
   double incr = [Utils convertSpeedValue:1.0];
   [zone1ThresholdStepper setMaxValue:max];
   [zone1ThresholdStepper setMinValue:min];
   [zone1ThresholdStepper setIncrement:incr];
   [zone1ThresholdStepper setFloatValue:[Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]]];
   [zone2ThresholdStepper setMaxValue:max];
   [zone2ThresholdStepper setMinValue:min];
   [zone2ThresholdStepper setIncrement:incr];
   [zone2ThresholdStepper setFloatValue:[Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]]];
   [zone3ThresholdStepper setMaxValue:max];
   [zone3ThresholdStepper setMinValue:min];
   [zone3ThresholdStepper setIncrement:incr];
   [zone3ThresholdStepper setFloatValue:[Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]]];
   [zone4ThresholdStepper setMaxValue:max];
   [zone4ThresholdStepper setMinValue:min];
   [zone4ThresholdStepper setIncrement:incr];
   [zone4ThresholdStepper setFloatValue:[Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]]];
   [zone5ThresholdStepper setMaxValue:max];
   [zone5ThresholdStepper setMinValue:min];
   [zone5ThresholdStepper setIncrement:incr];
   [zone5ThresholdStepper setFloatValue:[Utils convertSpeedValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]]];
}

- (void) updatePaceSteppers:(NSDictionary*)dict
{
   double max = [Utils convertPaceValue:(30*60)];  // 30 minutes/mile
   double min = [Utils convertPaceValue:0.0];
   BOOL isStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
   double incr = 1.0;
   if (isStatute)
   {
      incr = MPMToMPK(1.0);
   }
   [zone1ThresholdStepper setMaxValue:max];
   [zone1ThresholdStepper setMinValue:min];
   [zone1ThresholdStepper setIncrement:incr];
   [zone1ThresholdStepper setFloatValue:[Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]]];
   [zone2ThresholdStepper setMaxValue:max];
   [zone2ThresholdStepper setMinValue:min];
   [zone2ThresholdStepper setIncrement:incr];
   [zone2ThresholdStepper setFloatValue:[Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]]];
   [zone3ThresholdStepper setMaxValue:max];
   [zone3ThresholdStepper setMinValue:min];
   [zone3ThresholdStepper setIncrement:incr];
   [zone3ThresholdStepper setFloatValue:[Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]]];
   [zone4ThresholdStepper setMaxValue:max];
   [zone4ThresholdStepper setMinValue:min];
   [zone4ThresholdStepper setIncrement:incr];
   [zone4ThresholdStepper setFloatValue:[Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]]];
   [zone5ThresholdStepper setMaxValue:max];
   [zone5ThresholdStepper setMinValue:min];
   [zone5ThresholdStepper setIncrement:incr];
   [zone5ThresholdStepper setFloatValue:[Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]]];
}


- (void) updateCadenceSteppers:(NSDictionary*)dict
{
   double max = 200;
   double min = 0;
   double incr = 1;
   [zone1ThresholdStepper setMaxValue:max];
   [zone1ThresholdStepper setMinValue:min];
   [zone1ThresholdStepper setIncrement:incr];
   [zone1ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]];
   [zone2ThresholdStepper setMaxValue:max];
   [zone2ThresholdStepper setMinValue:min];
   [zone2ThresholdStepper setIncrement:incr];
   [zone2ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]];
   [zone3ThresholdStepper setMaxValue:max];
   [zone3ThresholdStepper setMinValue:min];
   [zone3ThresholdStepper setIncrement:incr];
   [zone3ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]];
   [zone4ThresholdStepper setMaxValue:max];
   [zone4ThresholdStepper setMinValue:min];
   [zone4ThresholdStepper setIncrement:incr];
   [zone4ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]];
   [zone5ThresholdStepper setMaxValue:max];
   [zone5ThresholdStepper setMinValue:min];
   [zone5ThresholdStepper setIncrement:incr];
   [zone5ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]];
}

- (void) updatePowerSteppers:(NSDictionary*)dict
{
	double max = 1000.0;
	double min = 0.0;
	double incr = 1;
	[zone1ThresholdStepper setMaxValue:max];
	[zone1ThresholdStepper setMinValue:min];
	[zone1ThresholdStepper setIncrement:incr];
	[zone1ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]];
	[zone2ThresholdStepper setMaxValue:max];
	[zone2ThresholdStepper setMinValue:min];
	[zone2ThresholdStepper setIncrement:incr];
	[zone2ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]];
	[zone3ThresholdStepper setMaxValue:max];
	[zone3ThresholdStepper setMinValue:min];
	[zone3ThresholdStepper setIncrement:incr];
	[zone3ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]];
	[zone4ThresholdStepper setMaxValue:max];
	[zone4ThresholdStepper setMinValue:min];
	[zone4ThresholdStepper setIncrement:incr];
	[zone4ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]];
	[zone5ThresholdStepper setMaxValue:max];
	[zone5ThresholdStepper setMinValue:min];
	[zone5ThresholdStepper setIncrement:incr];
	[zone5ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]];
}

- (void) updateGradientSteppers:(NSDictionary*)dict
{
   double max = 30.0;
   double min = -30.0;
   double incr = .1;
   [zone1ThresholdStepper setMaxValue:max];
   [zone1ThresholdStepper setMinValue:min];
   [zone1ThresholdStepper setIncrement:incr];
   [zone1ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]];
   [zone2ThresholdStepper setMaxValue:max];
   [zone2ThresholdStepper setMinValue:min];
   [zone2ThresholdStepper setIncrement:incr];
   [zone2ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]];
   [zone3ThresholdStepper setMaxValue:max];
   [zone3ThresholdStepper setMinValue:min];
   [zone3ThresholdStepper setIncrement:incr];
   [zone3ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]];
   [zone4ThresholdStepper setMaxValue:max];
   [zone4ThresholdStepper setMinValue:min];
   [zone4ThresholdStepper setIncrement:incr];
   [zone4ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]];
   [zone5ThresholdStepper setMaxValue:max];
   [zone5ThresholdStepper setMinValue:min];
   [zone5ThresholdStepper setIncrement:incr];
   [zone5ThresholdStepper setFloatValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]];
}



-(void) updateZoneThreshold:(NSDictionary*)dict zone:(int)zn value:(float)v key:(NSString*)key isRevType:(BOOL)isRevType
{
	NSMutableDictionary* mdict = [NSMutableDictionary dictionaryWithDictionary:dict];
	BOOL isStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	if (!isStatute)
	{
		if ([key isEqualToString:RCBDefaultSpeedZones])
		{
			v = KilometersToMiles(v);
		}
		else if ([key isEqualToString:RCBDefaultPaceZones])
		{
			v = MPKToMPM(v);
		}
		else if ([key isEqualToString:RCBDefaultAltitudeZones])
		{
			v = MetersToFeet(v);
		}
	}
	switch (zn)
	{
	  case 1:
		 [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone1Threshold];
		 break;
		 
	  case 2:
		 [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone2Threshold];
		 break;
		 
	  case 3:
		 [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone3Threshold];
		 break;
	  
	  case 4:
		 [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone4Threshold];
		 break;
	  
	  case 5:
		 [mdict setObject:[NSNumber numberWithFloat:v] forKey:RCBDefaultZone5Threshold];
		 break;
	}
	[self adjustRanges:mdict isRevType:isRevType];
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[defaults setObject:mdict forKey:key];
}


- (NSDictionary*) zoneTypeStuff:(int)type fieldUpdaterSel:(SEL*)fus stepperUpdaterSel:(SEL*)sus dictKey:(NSString**)keyPtr
{
	NSString* key = nil;
	switch (type)
	{
		case kSpeedDefaults:
			key = RCBDefaultSpeedZones;
			if (fus) *fus = @selector(updateSpeedFields:);
			if (sus) *sus = @selector(updateSpeedSteppers:);
			break;
		case kPaceDefaults:
			 key = RCBDefaultPaceZones;
			 if (fus) *fus  = @selector(updatePaceFields:);
			 if (sus) *sus = @selector(updatePaceSteppers:);
			 break;
		case kGradientDefaults:
			key = RCBDefaultGradientZones;
			if (fus) *fus  = @selector(updateGradientFields:);
			if (sus) *sus = @selector(updateGradientSteppers:);
			break;
		case kCadenceDefaults:
			key = RCBDefaultCadenceZones;
			if (fus) *fus  = @selector(updateCadenceFields:);
			if (sus) *sus = @selector(updateCadenceSteppers:);
			break;
		case kPowerDefaults:
			key = RCBDefaultPowerZones;
			if (fus) *fus  = @selector(updatePowerFields:);
			if (sus) *sus = @selector(updatePowerSteppers:);
			break;
		case kAltitudeDefaults:
			key = RCBDefaultAltitudeZones;
			if (fus) *fus  = @selector(updateAltitudeFields:);
			if (sus) *sus = @selector(updateAltitudeSteppers:);
			break;
		default:
			break;
   }
   
   NSDictionary* dict = nil;
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   if (key != nil) dict = [defaults dictionaryForKey:key];
   if (keyPtr != nil) *keyPtr = key;
   return dict;
}


- (void) updateColorForZone:(int)zn color:(NSColor*)clr dict:(NSDictionary*)dict dictKey:(NSString*)dictKey
{
   NSMutableDictionary* mdict = [NSMutableDictionary dictionaryWithDictionary:dict];
   switch (zn)
   {
      case 0:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultBelowZoneColor];
         break;

      case 1:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultZone1Color];
         break;
         
      case 2:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultZone2Color];
         break;
         
      case 3:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultZone3Color];
         break;
         
      case 4:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultZone4Color];
         break;
         
      case 5:
         [mdict setObject:[Utils RGBAStringForColor:clr] forKey:RCBDefaultZone5Color];
         break;
         
         
   }
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   [defaults setObject:mdict forKey:dictKey];
}





- (IBAction)setValueForSender:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
   int tg = [sender tag];
   int znType = [zoneTypePopup indexOfSelectedItem];
   if (sender == zoneTypePopup)
   {
      [defaults setInteger:znType forKey:RCBDefaultZoneType];
      SEL sel;
      NSDictionary* dict = [self zoneTypeStuff:znType fieldUpdaterSel:nil stepperUpdaterSel:&sel dictKey:nil];
      [self performSelector:sel withObject:dict];
      [self updateUI];
   }
   else if (tg >= 2)
   {
      int zn = tg/10;
      int ctl = tg % 10;
      
      switch (ctl)
      {
         case 0:        // threshold
         {
            SEL sel, updFieldsSel;
            NSString* key;
            NSDictionary* dict = [self zoneTypeStuff:znType fieldUpdaterSel:&updFieldsSel stepperUpdaterSel:&sel dictKey:&key];
            [self updateZoneThreshold:dict zone:zn value:[sender floatValue] key:key isRevType:(znType == kPaceDefaults)];
            [self performSelector:sel withObject:[defaults objectForKey:key]];
            [self performSelector:updFieldsSel withObject:[defaults objectForKey:key]];
            break;
         }
            
         case 1:        // threshold stepper
         {
            SEL sel;
            NSString* key;
            NSDictionary* dict = [self zoneTypeStuff:znType fieldUpdaterSel:&sel stepperUpdaterSel:nil dictKey:&key];
            [self updateZoneThreshold:dict zone:zn value:[sender floatValue] key:key isRevType:(znType == kPaceDefaults)];
            [self performSelector:sel withObject:[defaults objectForKey:key]];
            break;
         }
            
         case 2:        // color
         {
            NSString* key;
            NSDictionary* dict = [self zoneTypeStuff:znType fieldUpdaterSel:nil stepperUpdaterSel:nil  dictKey:&key];
            [self updateColorForZone:zn color:[sender color] dict:dict dictKey:key];
            break;
         }
            
         case 3:        // range
            break;
      }
   }
   [defaults synchronize];
   [Utils resetZoneCache];
}



-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	int zoneType = [defaults integerForKey:RCBDefaultZoneType];
	if (!IS_BETWEEN(0, zoneType, kMaxZoneType))
	{
		zoneType = kSpeedDefaults;
	}
	NSDictionary* dict = nil;
	switch (zoneType)
	{
		case kSpeedDefaults:
			dict = [defaults dictionaryForKey:RCBDefaultSpeedZones];
			[self updateSpeedFields:dict];
			[self updateSpeedSteppers:dict];
			break;
		 
		case kPaceDefaults:
			dict = [defaults dictionaryForKey:RCBDefaultPaceZones];
			[self updatePaceFields:dict];
			[self updatePaceSteppers:dict];
			break;
		 
		case kGradientDefaults:
			dict = [defaults dictionaryForKey:RCBDefaultGradientZones];
			[self updateGradientFields:dict];
			[self updateGradientSteppers:dict];
			break;
		 
		case kCadenceDefaults:
			dict = [defaults dictionaryForKey:RCBDefaultCadenceZones];
			[self updateCadenceFields:dict];
			[self updateCadenceSteppers:dict];
			break;

		case kPowerDefaults:
			dict = [defaults dictionaryForKey:RCBDefaultPowerZones];
			[self updatePowerFields:dict];
			[self updatePowerSteppers:dict];
			break;
			
		case kAltitudeDefaults:
		   dict = [defaults dictionaryForKey:RCBDefaultAltitudeZones];
		   [self updateAltitudeFields:dict];
		   [self updateAltitudeSteppers:dict];
		   break;
		   
	   default:
			break;
	}

	[zoneTypePopup selectItemAtIndex:zoneType];
		 
	[belowZoneColor      setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultBelowZoneColor]]];
	[zone1RangeColor     setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone1Color]]];
	[zone2RangeColor     setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone2Color]]];
	[zone3RangeColor     setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone3Color]]];
	[zone4RangeColor     setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone4Color]]];
	[zone5RangeColor     setColor:[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone5Color]]];
}


@end
