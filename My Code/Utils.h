//
//  Utils.h
//  TLP
//
//  Created by Rob Boyer on 9/23/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"

@class TrackPoint;
@class Track;

#define VALID_ALTITUDE(a)     ((a < (1000.0 * 1000.0)))
#define VALID_DISTANCE(d)     ((d < (1000.0 * 1000.0)))

#define BAD_DISTANCE    (1000.0*1000.0)
#define BAD_ALTITUDE    (1000.0*1000.0)
#define BAD_LATLON      (999.0)

#define PWR_WATTHOURS_TO_KJ		((60.0*0.06))

static inline float PowerDurationToWork(float iPowerInWatts, float iSecs)
{
	return iPowerInWatts*iSecs*PWR_WATTHOURS_TO_KJ/(60.0*60.0);
}

static inline float CelsiusToFahrenheight(float iCelsius)
{
	return ((9.0/5.0)*iCelsius) + 32.0;
}

static inline float FahrenheightToCelsius(float iFahRen)
{
	return (5.0/9.0)*(iFahRen - 32.0);
}



static inline float FeetToMeters(float feet)
{
   return feet * 0.3048;
}

static inline float MetersToFeet(float meters)
{
   return meters * 3.2808399;
}


static inline float MetersToMiles(float meters)
{
   return MetersToFeet(meters)/5280.0f;
}


static inline float MilesToKilometers(float miles)
{
   return miles * 1.609344;
}

static inline float KilometersToMiles(float km)
{
   return km * 0.621371192;
}

static inline float MPKToMPM(float mpk)
{
   return mpk/0.621371192;
}

static inline float MPMToMPK(float mpm)
{
   return mpm * 1.609344;
}

static inline float KilogramsToPounds(float kg)
{
   return kg * 2.20462262;
}

static inline float PoundsToKilograms(float lbs)
{
   return lbs * 0.45359237;
}

// does not do any unit conversion! + RETURNS seconds/mile (NOT mins/mile!)
static inline float SpeedToPace(float spd)
{
   float v = spd;
   if (v != 0.0)
   {
      // hours/mile * mins/hour * secs/min = secs/mile; 
      v = (1.0*60.0*60.0)/spd;
   }
   return v;
}

// input: SECONDS/mile
static inline float PaceToSpeed(float pace)
{
	float val = 0.0;
	if (pace != 0.0)
	{
		// 60mins/hour * 60secs/min * mile/secs = mile/hour; 
		val = (60.0 * 60.0)/pace;
	}
	return val;
}

static  BOOL ShiftKeyIsDown(void) {
    NSEventModifierFlags flags = [NSEvent modifierFlags];
    return (flags & NSEventModifierFlagShift) != 0;   // (use NSShiftKeyMask on very old SDKs)
}


@class ItemList;
@class Track;

@interface Utils : NSObject 
{

}

+ (NSString*)applicationSupportPath;
+ (NSString*)tempPath;
+ (NSImage*)imageFromBundleWithName:(NSString*)imageName;
+ (NSString*)imagePathFromBundleWithName:(NSString*)imageName;
+ (void)verifyDirAndCreateIfNecessary:(NSString*) path;
+ (NSColor*) colorFromDefaults:(NSString*)key;
+ (float) floatFromDefaults:(NSString*)key;
+ (void)  setFloatDefault:(float)val forKey:(NSString*)key;
+ (int)  intFromDefaults:(NSString*)key;
+ (void) setIntDefault:(int)val forKey:(NSString*)key;
+ (BOOL)  boolFromDefaults:(NSString*)key;
+ (void) setBoolDefault:(BOOL)b forKey:(NSString*)key;
+ (NSString*)  stringFromDefaults:(NSString*)key;
+ (void) setStringDefault:(NSString*)s forKey:(NSString*)key;
+ (NSString*) defaultColorKey:(int)tag;
+ (NSDictionary*) dictFromDefaults:(NSString*)key;
+ (id) objectFromDefaults:(NSString*)key;
+ (void) setObjectDefault:(id)obj forKey:(NSString*)key;

+ (int) mapIndexToType:(int)idx;       // converts 0-based index, to data type required by TerraServer
+ (int) dataTypeToIndex:(int)dt;
+ (const char* const*) defaultActivityItems;
+ (const char* const*) defaultEquipmentItems;
+ (const char* const*) defaultEventTypeItems;
+ (const char* const*) defaultWeatherItems;
+ (const char* const*) defaultDispositionItems;
+ (const char* const*) defaultEffortItems;
+ (const char* const*) animFrameRateItems;
+ (NSString*) attributeName:(int)attr;

+ (NSMutableArray*) attributeArray:(NSString*)attrKey;
+ (void) setAttributeListDefaults:(NSString*)attrKey stringArray:(NSArray*)sa;
+ (int) editAttributeList:(id)sender
             attributeID:(int)attrID
                       wc:(NSWindowController*)wc;
+ (NSString*) attrIDToDefaultsKey:(int)attrID;

+ (const char*) getNthItem:(const char* const*)iarr nth:(int)n;
+ (void) buildPopupMenuFromItems:(NSString*)attrKey popup:(NSPopUpButton*)p  currentSelection:(NSString*)curSel;

+ (ItemList*) graphItemList;
+ (void) buildPopupMenuFromItemList:(ItemList*)itemList popup:(NSPopUpButton*)p;

+ (void) buildDataTypePopup:(NSPopUpButton*)p  isPullDown:(BOOL)ipd;
+ (void) buildSplitOptionsPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd;
+ (void) buildBrowserOptionsPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd;
+ (NSMenu*) buildSplitOptionsMenu:(NSMenu**)lsm graphSubMenu:(NSMenu**)gsm;
+ (void) selectMenuItem:(int)itemTag forMenu:(NSMenu*)menu;

+ (NSString*) buildTrackDisplayedName:(Track*)track prePend:(NSString*)prepend;

+ (NSString*) getMapTilesPath;
+ (NSString*) getHeartrateColorKey:(float)hr;
+ (NSColor*) colorForZoneUsingZone:(int)cpz zone:(int)zn;
+ (float) thresholdForZoneUsingZone:(int)cpz zone:(int)zn;
+ (NSColor*) colorForZoneUsingTrackPoint:(int)cpz trackPoint:(TrackPoint*)tpt;
+ (void) setZoneColor:(int)cpz trackPoint:(TrackPoint*)tpt;
+ (void) resetZoneCache;
+ (NSColor *)colorForRGBAString:(NSString *)defaultName;
+ (NSString*)RGBAStringForColor:(NSColor *)color;
+ (NSArray*)rangeStringsForZoneType:(int)zoneType;

+(BOOL)usingStatute;

// input args to conversion routines are ALWAYS in miles, mph, lbs, etc.
// the conversion routines convert (or not) based on the 'units' preference
+ (float) convertTemperatureValue:(float)tval;
+ (float) convertDistanceValue:(float)dval;
+ (float) convertClimbValue:(float)cval;
+ (float) convertSpeedValue:(float)sval;
+ (float) convertPaceValue:(float)pval;      // hrs/mile input
+ (float) convertWeightValue:(float)wval;
+ (NSString*) convertPaceValueToString:(float)pval;

+ (BOOL) checkDataSanity:(time_t) creationTime
                latitude:(float) latitude
               longitude:(float) longitude
                altitude:(float) altitude
               heartrate:(int) heartrate
                 cadence:(int) cadence
             temperature:(float) temperature
                   speed:(float) speed
                distance:(float) distance;

+ (float) latLonToDistanceInMiles:(float)lat1 lon1:(float)lon1 
                             lat2:(float)lat2 lon2:(float)lon2;

+ (BOOL) validateLatitude:(float)lat longitude:(float)lon;

+ (NSString*) dateFormat;

+ (NSString*) activityNameFromDate:(Track*)track alternateStartTime:(NSDate*)altStartTime;

+ (int) calculateAge:(NSDate*)birthDate;

+ (float) currentSplitDistance;
+ (void)setBackupDefaults;
+ (NSString*) friendlySizeAsString:(int)sz;

+(int)numPeakIntervals;
+(int)nthPeakInterval:(int)n;
+(int)numPeakDataTypes;
+(void) buildPeakIntervalsPopup:(NSPopUpButton*)p;
+(NSDictionary*)peakPowerIntervalInfoDict;
+(void)togglePeakPowerIntervalAtIndex:(int)idx  popup:(NSPopUpButton*)p;
+(BOOL)peakPowerIntervalAtIndexEnabled:(int)idx;
+(void)setPeakPowerIntervalAtIndexEnabled:(int)idx enabled:(BOOL)en;
+(NSString*)friendlyIntervalAsString:(int)iv;
+(void)createPowerActivityArrayIfDoesntExist;
+(void)maxMinAlt:(NSArray*)pts max:(NSNumber**)mxn min:(NSNumber**)mnn;
+(NSString*)deviceNameForID:(int)did;

@end
