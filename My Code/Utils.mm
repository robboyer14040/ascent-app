//
//  Utils.mm
//  TLP
//
//  Created by Rob Boyer on 9/23/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "Utils.h"
#import "Defs.h"
#import "ItemList.h"
#import "Track.h"
#import "TrackPoint.h"
#import "ListEditorController.h"
#import "ColumnInfo.h"

#import <OmniFoundation/OFPreference.h>
/// #import <OmniAppKit/NSUserDefaults-OAExtensions.h>

#include <math.h>

static const char* const theActivityItems[] = 
{
   kCycling,
   kRunning,
   kHiking,
   kSkiing,
   kSnowboarding,
   kDriving,
   kPaddling,
   kWalking,
   0
};

static const char* const theEquipmentItems[] = 
{
   kRoadBike,
   kMountainBike,
   kNoEqupiment,
   0
};

static const char* const theEventTypeItems[] = 
{
   kTraining,
   kRace,
   kEndurance,
   kCommute,
   0
};

const char * const theWeatherItems[] = 
{
   kSunny,
   kSunnyHot,
   kSunnyHotHumid,
   kSunnyCold,
   kOvercast,
   kOvercastHot,
   kOvercastHotHumid,
   kRain,
   kRainCold,
   kSnow,
   kWind,
   kIndoor,
   0
};

static const char * const  theDispositionItems[] = 
{
   kOK,
   kEnergized,
   kTired,
   0
};

static const char* const theEffortItems[] =
{
   kEasy,
   kMedium,
   kDifficult,
   kEpic,
   0
};

#define kHighAnimRate      "High (uses more CPU)"
#define kMediumAnimRate    "Medium (moderate CPU use)"
#define kLowAnimRate       "Low (uses less CPU)"


static const char* const theAnimFrameRateItems[] =
{
   kHighAnimRate,
   kMediumAnimRate,
   kLowAnimRate,
   0
};


typedef struct 
{
   float       thresh;
   NSString*   colorKey;
   NSColor*    color;
} HRThreshInfo;


@interface ReleaseHelper : NSObject
-(void)doRelease:(id)obj;
@end

@implementation ReleaseHelper
-(void)doRelease:(id)obj
{
    [obj autorelease];
    [self autorelease];
}
@end


@interface NSString(compareAsNumbers)
- (NSComparisonResult)compareAsNumbers:(NSString *)aString;
@end

@implementation NSString(compareAsNumbers)

- (NSComparisonResult)compareAsNumbers:(NSString *)aString
{
	NSNumber* left = [NSNumber numberWithInt:[self intValue]];
	NSNumber* right = [NSNumber numberWithInt:[aString intValue]];
	return [left compare:right];
}

@end;




@implementation Utils

+ (const char* const*) defaultActivityItems
{
   return theActivityItems;
}


+ (const char* const*) defaultEquipmentItems
{
   return theEquipmentItems;
}


+ (const char* const*) defaultEventTypeItems
{
   return theEventTypeItems;
}



+ (const char* const*) defaultWeatherItems
{
   return theWeatherItems;
}


+ (const char* const*) defaultDispositionItems
{
   return theDispositionItems;
}


+ (const char* const*) defaultEffortItems
{
   return theEffortItems;
}


+ (NSMutableArray*) buildArrayFromCStrings:(const char* const*)items
{
   NSMutableArray* arr = [NSMutableArray arrayWithCapacity:8];
   int idx = 0;
   while (items[idx] != 0)
   {
      [arr addObject:[NSString stringWithUTF8String:items[idx]]];
      ++idx;
   }
   return arr;
}



+ (NSMutableArray*) attributeArray:(NSString*)attrKey
{
   BOOL mustSet = NO;
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   NSMutableArray* arr = [NSMutableArray arrayWithArray:[defaults stringArrayForKey:attrKey]];
   if (arr == nil)
   {
      if ([attrKey isEqualToString:RCBDefaultAttrActivityList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultActivityItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrEquipmentList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultEquipmentItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrDispositionList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultDispositionItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrWeatherList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultWeatherItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrEventTypeList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultEventTypeItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrEffortList])
      {
         arr = [Utils buildArrayFromCStrings:[Utils defaultEffortItems]]; mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrKeyword1List])
      {
         arr = [NSArray array];
         mustSet = YES;
      }
      else if ([attrKey isEqualToString:RCBDefaultAttrKeyword2List])
      {
         arr = [NSArray array];
         mustSet = YES;
      }
      else
      {
         arr = [NSArray array];
      }
   }
   if (mustSet) [Utils setAttributeListDefaults:attrKey
                                    stringArray:arr];
   return arr;
}



+ (void) setAttributeListDefaults:(NSString*)attrKey stringArray:(NSArray*)sa
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   [defaults setObject:sa
                forKey:attrKey];
   [defaults synchronize];
}



+ (NSString*) attributeName:(int)attr
{
   NSString* s;
   switch (attr)
   {
      case kName:
         s = @"Title";
         break;
         
      case kActivity:
         s = @"Activity";
         break;
         
      case kDisposition:
         s = @"Disposition";
         break;
         
      case kEffort:
         s = @"Effort";
         break;
         
      case kEventType:
         s = @"Event Type";
         break;
         
      case kWeather:
         s = @"Weather";
         break;
         
      case kEquipment:
         s = @"Equipment";
         break;
         
      case kWeight:
         s = @"Weight";
         break;
         
      case kNotes:
         s = @"Notes";
         break;
         
      case kKeyword1:
         s = @"Keyword 1";
         break;
         
      case kKeyword2:
         s = @"Keyword 2";
         break;
         
      case  kKeyword3:
         s = @"Keyword 3";
         break;
         
      case kKeyword4:
         s = @"Keyword 4";
         break;
         
      default:
         s = @"Unknown attribute";
   }
   return s;
}


+ (const char* const*) animFrameRateItems
{
   return theAnimFrameRateItems;
}


+ (const char*) getNthItem:(const char* const*)iarr nth:(int)n
{
   int count = 0;
   while (iarr[count] != 0) ++count;
   if (IS_BETWEEN(0, n, (count-1)))
   {
      n = CLIP(0,n,count-1);
      return iarr[n];
   }
   else
   {
      return "";
   }
}


+ (void) buildPopupMenuFromItems:(NSString*)attrKey popup:(NSPopUpButton*)p currentSelection:(NSString*)curSel
{
   NSMutableArray * itemArray = [Utils attributeArray:attrKey];
   [p removeAllItems];
   int count = [itemArray count];
   for (int i=0; i<count; i++)
   {
      [p addItemWithTitle:[itemArray objectAtIndex:i]];
   }
   if (![curSel isEqualToString:@""])
   {
      id mi = [p itemWithTitle:curSel];
      if (mi == nil)
      {
         [p addItemWithTitle:curSel];
      }
      if ([itemArray indexOfObject:curSel] == NSNotFound)
      {
         [itemArray addObject:curSel];
         [Utils setAttributeListDefaults:attrKey
                             stringArray:itemArray];
      }
   }
   NSMenu* menu = [p menu];
   [menu addItem:[NSMenuItem separatorItem]];
   [p addItemWithTitle:@"Edit List..."];
}


+ (NSString*) attrIDToDefaultsKey:(int)attrID
{
   NSString* s;
   switch (attrID)
   {
       case kActivity:
         s = RCBDefaultAttrActivityList;
         break;
         
      case kDisposition:
         s = RCBDefaultAttrDispositionList;
         break;
         
      case kEffort:
         s = RCBDefaultAttrEffortList;
         break;
         
      case kEventType:
         s = RCBDefaultAttrEventTypeList;
         break;
         
      case kWeather:
         s = RCBDefaultAttrWeatherList;
         break;
         
      case kEquipment:
         s = RCBDefaultAttrEquipmentList;
         break;
         
      case kKeyword1:
         s = RCBDefaultAttrKeyword1List;
         break;
         
      case kKeyword2:
         s = RCBDefaultAttrKeyword2List;
         break;
         
#if 0
      case kWeight:
         s = @"Weight";
         break;
         
      case kNotes:
         s = @"Notes";
         break;
         
      case  kKeyword3:
      case kKeyword4:
         s = RDBDefaultKeywordList;
         break;
#endif         
      default:
         s = @"Unknown attribute";
   }    
   return s;
}


// work-around from crash when exiting from list editor with a field being edited.  Not sure
// why this fixes things, but changes the order of notifications to avoid the problem.  ugh.
// @@FIXME@@


+ (int) editAttributeList:(id)popup
              attributeID:(int)attrID
                       wc:(NSWindowController*)wc;
{
   int ret = -1;
   NSString* attrKey = [Utils attrIDToDefaultsKey:attrID];
   ListEditorController* lec = [[ListEditorController alloc] initWithStringArray:[Utils attributeArray:attrKey]
                                                                            name:[Utils attributeName:attrID]];
   NSRect lfr = [[lec window] frame];
   NSRect fr = [[wc window] frame];
   NSPoint origin = fr.origin;
   origin.x += (fr.size.width - (lfr.size.width+20.0));
   origin.y += 20.0;
   [[lec window] setFrameOrigin:origin];
   //[[lec window] setTitle:@"Edit List"];
   [lec showWindow:wc];
   int ok = [NSApp runModalForWindow:[lec window]];
   if (ok == 0) 
   {
      NSArray* s = [lec stringArray];
      [Utils setAttributeListDefaults:attrKey
                          stringArray:s];
      ret = 0;
   }
   [[lec window] orderOut:[wc window]];
   [[wc window] makeKeyAndOrderFront:[lec window]];
    ReleaseHelper* rh = [[ReleaseHelper alloc] init];
    
   [rh performSelectorOnMainThread:@selector(doRelease:)
                        withObject:lec
                     waitUntilDone:NO];
    return ret;
}


+(NSString*)applicationSupportPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [NSMutableString stringWithString:[paths objectAtIndex:0]];
	path = [path stringByAppendingPathComponent:PROGRAM_NAME];
	[Utils verifyDirAndCreateIfNecessary:path];
	return path;
}


+(NSString*)tempPath
{
	NSString *path = [self applicationSupportPath];
	path = [path stringByAppendingPathComponent:@"Temp"];
	[Utils verifyDirAndCreateIfNecessary:path];
	return path;
}


+ (void)verifyDirAndCreateIfNecessary:(NSString*) path
{
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL isDir;
	NSError* error;
	if ( [fm fileExistsAtPath:path isDirectory:&isDir] )
	{
		if (!isDir)
		{
			[fm removeItemAtPath:path error:&error];
			[fm createDirectoryAtPath:path 
		  withIntermediateDirectories:YES
						   attributes:nil
								error:&error];
		}
	}
	else
	{
		[fm createDirectoryAtPath:path 
	  withIntermediateDirectories:YES
					   attributes:nil
							error:&error];
	}
}


+ (float) floatFromDefaults:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   return [defaults floatForKey:key];
}

+ (void) setFloatDefault:(float)val forKey:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   [defaults setFloat:val forKey:key];
   [defaults synchronize];
}


+ (NSDictionary*) dictFromDefaults:(NSString*)key;
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   return [defaults dictionaryForKey:key];
}


+ (id) objectFromDefaults:(NSString*)key
{
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	return [defaults objectForKey:key];
}


+ (void) setObjectDefault:(id)obj forKey:(NSString*)key
{
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	[defaults setObject:obj forKey:key];
	[defaults synchronize];
}


+ (int) intFromDefaults:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   return [defaults integerForKey:key];
}

+ (void) setIntDefault:(int)val forKey:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   [defaults setInteger:val forKey:key];
   [defaults synchronize];
}

+ (BOOL)  boolFromDefaults:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   return [defaults boolForKey:key];
}



+ (void) setBoolDefault:(BOOL)b forKey:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   [defaults setBool:b forKey:key];
   [defaults synchronize];
}

+ (NSString*)  stringFromDefaults:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   NSString* s = [defaults stringForKey:key];
    if (s == nil)
    {
        s = [NSString stringWithUTF8String:"notset FIXME"];
        [s retain];     /// rcb CHECK FIXME
    }
    return s;
}


+ (void) setStringDefault:(NSString*)s forKey:(NSString*)key
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   [defaults setObject:s forKey:key];
   [defaults synchronize];
}



static HRThreshInfo        sThreshZoneInfo[kMaxZoneType+1][kNumNonHRZones+1];
static BOOL                sThreshZoneInited[kMaxZoneType+1] = { NO, NO, NO, NO };


+ (void) initialize
{
   for (int zt=0; zt<=kMaxZoneType; zt++)
   {
      sThreshZoneInited[zt] = NO;
      for (int zn=0; zn<kNumNonHRZones; zn++)
      {
         sThreshZoneInfo[zt][zn].color = nil;
      }
   }
}


+ (void) resetZoneCache
{
   for (int zt=0; zt<=kMaxZoneType; zt++)
   {
      sThreshZoneInited[zt] = NO;
   }
}


+ (NSColor*)colorForZoneType:(int)znType dict:(NSDictionary*)dict value:(float)v
{
   if (!sThreshZoneInited[znType])
   {
      sThreshZoneInfo[znType][0].thresh = [[dict objectForKey:RCBDefaultZone5Threshold] floatValue];
      [sThreshZoneInfo[znType][0].color release];
      sThreshZoneInfo[znType][0].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone5Color]] retain];
      
      sThreshZoneInfo[znType][1].thresh = [[dict objectForKey:RCBDefaultZone4Threshold] floatValue];
      [sThreshZoneInfo[znType][1].color release];
      sThreshZoneInfo[znType][1].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone4Color]] retain];
      
      sThreshZoneInfo[znType][2].thresh = [[dict objectForKey:RCBDefaultZone3Threshold] floatValue];
      [sThreshZoneInfo[znType][2].color release];
      sThreshZoneInfo[znType][2].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone3Color]] retain];
      
      sThreshZoneInfo[znType][3].thresh = [[dict objectForKey:RCBDefaultZone2Threshold] floatValue];
      [sThreshZoneInfo[znType][3].color release];
      sThreshZoneInfo[znType][3].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone2Color]] retain];
      
      sThreshZoneInfo[znType][4].thresh = [[dict objectForKey:RCBDefaultZone1Threshold] floatValue];
      [sThreshZoneInfo[znType][4].color release];
      sThreshZoneInfo[znType][4].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultZone1Color]] retain];

      sThreshZoneInfo[znType][5].thresh = -99999999.0;
      [sThreshZoneInfo[znType][5].color release];
      sThreshZoneInfo[znType][5].color = [[Utils colorForRGBAString:[dict objectForKey:RCBDefaultBelowZoneColor]] retain];
      
      sThreshZoneInited[znType] = YES;
   }
   if (znType == kPaceDefaults)
   {
      for (int i=0; i<kNumNonHRZones; i++)
      {
         if (v <= sThreshZoneInfo[znType][i].thresh)
         {
            return sThreshZoneInfo[znType][i].color;
         }
      }
   }
   else
   {
      for (int i=0; i<kNumNonHRZones; i++)
      {
         if (v >= sThreshZoneInfo[znType][i].thresh)
         {
            return sThreshZoneInfo[znType][i].color;
         }
      }
   }
   return sThreshZoneInfo[znType][kNumNonHRZones].color;
}

+ (NSString*) getZoneThresholdKey:(int)zn
{
   NSString* key;
   switch (zn)
   {
      default:
      case 0:
         key = RCBDefaultZone1Threshold;
         break;
         
      case 1:
         key = RCBDefaultZone2Threshold;
         break;
         
      case 2:
         key = RCBDefaultZone3Threshold;
         break;
         
      case 3:
         key = RCBDefaultZone4Threshold;
         break;
         
      case 4:
         key = RCBDefaultZone5Threshold;
         break;
         
   }
   return key;
}


+ (NSString*) getZoneColorKey:(int)zn
{
   NSString* key;
   switch (zn)
   {
      default:
         key = RCBDefaultBelowZoneColor;    
         break;
         
      case 0:
         key = RCBDefaultZone1Color;
         break;
         
      case 1:
         key = RCBDefaultZone2Color;
         break;
         
      case 2:
         key = RCBDefaultZone3Color;
         break;
         
      case 3:
         key = RCBDefaultZone4Color;
         break;
         
      case 4:
         key = RCBDefaultZone5Color;
         break;
   }
   return key;
}


+ (NSArray*) rangeStringsForHeartrate
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:kNumHRZones];
	int v;
	int top;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	v = [defaults integerForKey:RCBDefaultZone5Threshold];
	[arr addObject:[NSString stringWithFormat:@"≥%d", v]];
	
	top = v;
	v = [defaults integerForKey:RCBDefaultZone4Threshold];
	[arr addObject:[NSString stringWithFormat:@"%d➔%d", v, top-1 ]];
	
	top = v;
	v = [defaults integerForKey:RCBDefaultZone3Threshold];
	[arr addObject:[NSString stringWithFormat:@"%d➔%d", v, top-1 ]];
	
	top = v;
	v = [defaults integerForKey:RCBDefaultZone2Threshold];
	[arr addObject:[NSString stringWithFormat:@"%d➔%d", v, top-1 ]];
	
	top = v;
	v = [defaults integerForKey:RCBDefaultZone1Threshold];
	[arr addObject:[NSString stringWithFormat:@"%d➔%d", v, top-1  ]];
	
	[arr addObject:[NSString stringWithFormat:@"<%d",   v  ]];
	return arr;
}



+ (NSArray*) rangeStringsForPace
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:kNumHRZones];
	int v;
	int top;
	NSDictionary* dict = nil;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	dict = [defaults dictionaryForKey:RCBDefaultPaceZones];
	if (dict)
	{
		v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone5Threshold] floatValue]] + 0.5;
		[arr addObject:[NSString stringWithFormat:@"≤%02d:%02d", v/60, v%60]];
		
		top = v+1;
		v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone4Threshold] floatValue]] + 0.5;
		[arr addObject:[NSString stringWithFormat:@"%02d:%02d➔%02d:%02d", top/60, top % 60 , v/60, v%60 ]];
		
		top = v+1;
		v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone3Threshold] floatValue]] + 0.5;
		[arr addObject:[NSString stringWithFormat:@"%02d:%02d➔%02d:%02d", top/60, top % 60 , v/60, v%60 ]];
		
		top = v+1;
		v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone2Threshold] floatValue]] + 0.5;
		[arr addObject:[NSString stringWithFormat:@"%02d:%02d➔%02d:%02d", top/60, top % 60, v/60, v%60 ]];
		
		top = v+1;
		v = [Utils convertPaceValue:[[dict objectForKey:RCBDefaultZone1Threshold] floatValue]] + 0.5;
		[arr addObject:[NSString stringWithFormat:@"%02d:%02d➔%02d:%02d",    top/60, top % 60, v/60, v%60  ]];
		
		[arr addObject:[NSString stringWithFormat:@">%02d:%02d",   v/60, v%60  ]];
	}
	return arr;
}


typedef float (*tConvFunc)(float v);

+ (NSArray*) rangeStringsUsingDictKey:(NSString*)key fractionalDigits:(int)fd conversionFunc:(tConvFunc)convFunc
{
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:kNumHRZones];
	NSDictionary* dict = nil;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	if (key != nil) dict = [defaults dictionaryForKey:key];
	if (dict)
	{
		BOOL useStatute = [self boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		float v, top;
		v = [[dict objectForKey:RCBDefaultZone5Threshold] floatValue];
		if (!useStatute) v = convFunc(v);
		[arr addObject:[NSString stringWithFormat:@"≥%0.0f", v]];
		
		top = v;
		v = [[dict objectForKey:RCBDefaultZone4Threshold] floatValue];
		if (!useStatute) v = convFunc(v);
		[arr addObject:[NSString stringWithFormat:@"%0.0f➔%0.0f",  v, top-1.0]];
		
		top = v;
		v = [[dict objectForKey:RCBDefaultZone3Threshold] floatValue];
		if (!useStatute) v = convFunc(v);
		[arr addObject:[NSString stringWithFormat:@"%0.0f➔%0.0f",  v, top-1.0]];
		
		top = v;
		v = [[dict objectForKey:RCBDefaultZone2Threshold] floatValue];
		if (!useStatute) v = convFunc(v);
		[arr addObject:[NSString stringWithFormat:@"%0.0f➔%0.0f", v, top-1.0]];
		
		top = v;
		v = [[dict objectForKey:RCBDefaultZone1Threshold] floatValue];
		if (!useStatute) v = convFunc(v);
		[arr addObject:[NSString stringWithFormat:@"%0.0f➔%0.0f", v, top-1.0]];
		
		[arr addObject:[NSString stringWithFormat:@"<%0.0f", v]];
	}
	return arr;
}


static float nullConversion(float v) { return v; }

+ (NSArray*)rangeStringsForZoneType:(int)zoneType
{
	NSArray* strings = nil;
	switch (zoneType)
	{
		case kUseHRZColorsForPath:
			strings = [Utils rangeStringsForHeartrate];
			break;
			
		case kUseSpeedZonesForPath:
			strings = [Utils rangeStringsUsingDictKey:RCBDefaultSpeedZones
									 fractionalDigits:1
									   conversionFunc:MilesToKilometers];
			break;
			
		case kUsePaceZonesForPath:
			strings = [Utils rangeStringsForPace];
			break;
			
		case kUseGradientZonesForPath:
			strings = [Utils rangeStringsUsingDictKey:RCBDefaultGradientZones
									 fractionalDigits:1
									   conversionFunc:nullConversion];
			break;
			
		case kUseCadenceZonesForPath:
			strings = [Utils rangeStringsUsingDictKey:RCBDefaultCadenceZones
									 fractionalDigits:0
									   conversionFunc:nullConversion];
			break;
			
		case kUsePowerZonesForPath:
			strings = [Utils rangeStringsUsingDictKey:RCBDefaultPowerZones
									 fractionalDigits:0
									   conversionFunc:nullConversion];
		break;
			
		case kUseAltitudeZonesForPath:
			strings = [Utils rangeStringsUsingDictKey:RCBDefaultAltitudeZones
									 fractionalDigits:0
									   conversionFunc:FeetToMeters];
			break;
			
	}
	return strings;
}


+ (NSColor*) colorForZoneUsingZone:(int)cpz zone:(int)zn
{
	NSColor* clr = nil;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSString* colorKey = [Utils getZoneColorKey:zn];
	NSDictionary* dict = nil;
	switch (cpz)
	{
		case kUseHRZColorsForPath:
		   clr = [Utils colorFromDefaults:colorKey];
		   break;
		 
		case kUseSpeedZonesForPath:
		   dict = [defaults objectForKey:RCBDefaultSpeedZones];
		   break;
		 
		case kUsePaceZonesForPath:
		   dict = [defaults objectForKey:RCBDefaultPaceZones];
		   break;
		 
		case kUseGradientZonesForPath:
		   dict = [defaults objectForKey:RCBDefaultGradientZones];
		   break;
		 
		case kUseCadenceZonesForPath:
		   dict = [defaults objectForKey:RCBDefaultCadenceZones];
		   break;

		case kUsePowerZonesForPath:
			dict = [defaults objectForKey:RCBDefaultPowerZones];
			break;
			
		case kUseAltitudeZonesForPath:
		   dict = [defaults objectForKey:RCBDefaultAltitudeZones];
		   break;
		   
	   default:
         clr = [NSColor blackColor];
	}
	if (clr == nil)
	{
		clr = [Utils colorForRGBAString:[dict objectForKey:colorKey]];
		if (clr == nil) clr = [NSColor blackColor];
	}
	return clr;
}


+ (float) thresholdForZoneUsingZone:(int)cpz zone:(int)zn
{
	float v = 0.0;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSString* threshKey = [Utils getZoneThresholdKey:zn];
	NSDictionary* dict = nil;
	switch (cpz)
	{
		case kUseHRZColorsForPath:
			v = (float)[Utils intFromDefaults:threshKey];
			break;
		 
		case kUseSpeedZonesForPath:
			dict = [defaults objectForKey:RCBDefaultSpeedZones];
			break;
		 
		case kUsePaceZonesForPath:
			dict = [defaults objectForKey:RCBDefaultPaceZones];
			break;
		 
		case kUseGradientZonesForPath:
			dict = [defaults objectForKey:RCBDefaultGradientZones];
			break;
		 
		case kUseCadenceZonesForPath:
			dict = [defaults objectForKey:RCBDefaultCadenceZones];
			break;
		 
		case kUsePowerZonesForPath:
			dict = [defaults objectForKey:RCBDefaultPowerZones];
			break;
			
		case kUseAltitudeZonesForPath:
			dict = [defaults objectForKey:RCBDefaultAltitudeZones];
			break;
	}
	if (dict != nil)
	{
	   v = [[dict objectForKey:threshKey] floatValue];
	}
	return v;
}



+ (NSColor*) colorForZoneUsingTrackPoint:(int)cpz trackPoint:(TrackPoint*)tpt
{
	NSColor* clr = nil;
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	switch (cpz)
	{
		case kUseHRZColorsForPath:
		   clr = [Utils colorFromDefaults:[Utils getHeartrateColorKey:[tpt heartrate]]];
		   break;
		 
		case kUseSpeedZonesForPath:
		   clr = [Utils colorForZoneType:kSpeedDefaults 
									dict:[defaults objectForKey:RCBDefaultSpeedZones] 
								   value:[tpt speed]];
		 break;
		 
		case kUsePaceZonesForPath:
		   clr = [Utils colorForZoneType:kPaceDefaults  
									dict:[defaults objectForKey:RCBDefaultPaceZones] 
								   value:[tpt pace]];
		   break;	
		 
		case kUseGradientZonesForPath:
		   clr = [Utils colorForZoneType:kGradientDefaults 
									dict:[defaults objectForKey:RCBDefaultGradientZones] 
								   value:[tpt gradient]];
		   break;
		 
		case kUseCadenceZonesForPath:
		   clr = [Utils colorForZoneType:kCadenceDefaults  
									dict:[defaults objectForKey:RCBDefaultCadenceZones] 
								   value:[tpt cadence]];
		   break;
		 
		case kUsePowerZonesForPath:
			clr = [Utils colorForZoneType:kPowerDefaults  
									 dict:[defaults objectForKey:RCBDefaultPowerZones] 
									value:[tpt power]];
			break;
			
		case kUseAltitudeZonesForPath:
		   clr = [Utils colorForZoneType:kAltitudeDefaults  
									dict:[defaults objectForKey:RCBDefaultAltitudeZones] 
								   value:[tpt altitude]];
		   break;
		   
	}
	return clr;
}



+(void) setZoneColor:(int)cpz trackPoint:(TrackPoint*)tpt
{
	NSColor* zoneClr = nil;
	switch (cpz)
	{
		case kUseHRZColorsForPath:
			zoneClr = [Utils colorFromDefaults:[Utils getHeartrateColorKey:[tpt heartrate]]] ;
			break;
		 
		case kUseSpeedZonesForPath:
		case kUsePaceZonesForPath:
		case kUseGradientZonesForPath:
		case kUseCadenceZonesForPath:
		case kUsePowerZonesForPath:
		case kUseAltitudeZonesForPath:
			zoneClr = [Utils colorForZoneUsingTrackPoint:cpz 
											  trackPoint:tpt];
			break;
         
	   case kUseDefaultPathColor:
			break;
         
	   case kUseBackgroundColor:
	   default:
			//zoneClr = [Utils colorFromDefaults:RCBDefaultBackgroundColor];
			zoneClr = [NSColor colorWithCalibratedRed:(152.0/255.0) green:(152.0/255.0) blue:(152.0/255.0) alpha:0.9];
			break;
	}
   
	if (zoneClr != nil) [zoneClr set];
}

+ (NSColor *)colorForRGBAString:(NSString *)defaultName;
{
   //NSString *value;
   float r = 0.0, g = 0.0, b = 0.0, a = 1.0;
   
   //value = [self stringForKey:defaultName];
   if ([defaultName length] > 1) {
      sscanf([defaultName UTF8String], "%f%f%f%f", &r, &g, &b, &a);
      return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
   } else
      return nil;
}


+ (NSString*)RGBAStringForColor:(NSColor *)color;
{
   NSString *value;
   CGFloat r, g, b, a;
   
   if (!color) 
   {
      return @"0 0 0";
   }
   
   [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
   if (a == 1.0)
      value = [NSString stringWithFormat:@"%g %g %g", r, g, b];
   else
      value = [NSString stringWithFormat:@"%g %g %g %g", r, g, b, a];
   return value;
}



+ (NSColor*) colorFromDefaults:(NSString*)key
{
    OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
    NSColor* color = [defaults colorForKey:key];
    if (color == nil)
    {
        if (key == RCBDefaultPathColor)
        {
            color = [NSColor redColor];
        }
        else if (key == RCBDefaultBackgroundColor)
        {
            color = [NSColor whiteColor];
        }
        else
        {
            color = [NSColor blueColor];
        }
        /// NSLog(@"Defaults color not found, using a default RED FIXME");
    }
    return color;
}

+ (NSString*) defaultColorKey:(int)tag
{
      switch (tag)
      {
         case kAltitude:
            return RCBDefaultAltitudeColor;
            break;
            
         case kAvgHeartrate:
         case kHeartrate:
            return RCBDefaultHeartrateColor;
            break;
            
         case kAvgSpeed:
         case kSpeed:
            return RCBDefaultSpeedColor;
            break;

         case kAvgPace:
            return RCBDefaultPaceColor;
            break;
            
         case kAvgMovingSpeed:
            return RCBDefaultMovingSpeedColor;
            break;

         case kAvgMovingPace:
            return RCBDefaultMovingPaceColor;
            break;
            
            
         case kAvgCadence:
         case kCadence:
            return RCBDefaultCadenceColor;
            break;
            
          case kAvgPower:
		  case kPower:
			  return RCBDefaultPowerColor;
			  break;
			  
		  case kAvgGradient:
         case kGradient:
            return RCBDefaultGradientColor;
            break;
            
         case kAvgTemperature:
         case kTemperature:
            return RCBDefaultTemperatureColor;
            break;
            
         case kPath:
            return RCBDefaultPathColor;
            break;
            
         case kDistance:
            return RCBDefaultDistanceColor;
            break;
            
         case kBackground:
            return RCBDefaultBackgroundColor;
            break;
            
         case kDuration:
            return RCBDefaultDurationColor;
            break;
            
         case kMovingDuration:
            return RCBDefaultMovingDurationColor;
            break;
            
         case kLap:
            return RCBDefaultLapColor;
            break;
            
         case kWeightPlot:
            return RCBDefaultWeightColor;
            break;
         
         case kCalories:
            return RCBDefaultCaloriesColor;
            break;
            
         case kBrowserYearText:
            return RCBDefaultBrowserYearColor;
            break;

         case kBrowserMonthText:
            return RCBDefaultBrowserMonthColor;
            break;
            
         case kBrowserWeekText:
            return RCBDefaultBrowserWeekColor;
            break;
            
         case kBrowserActivityText:
            return RCBDefaultBrowserActivityColor;
            break;
            
         case kBrowserLapText:
            return RCBDefaultBrowserLapColor;
            break;
			 
		 case kSplitColorTag:
			 return RCBDefaultSplitColor;
			 break;
            
      }
      return @"";
}


+ (int) mapIndexToType:(int)idx       // converts 0-based index, to data type required by TerraServer
{
   switch (idx)
   {
      default:
      case 0:
         return 10;
      case 1: 
         return 12;
      case 2:
         return 11;
	  case 3:
		 return 1;
	  case 4:
		 return 4;
	  case 5:
		 return 2;
   }
}

+ (int) dataTypeToIndex:(int)dt
{
	switch (dt)
	{
		case 1:
			return 3;
		case 2:
			return 5;
		case 4:
			return 4;
		case 10:
		default:
			return 0;
		case 11:
			return 2;
		case 12:
			return 1;
	}
}


static ItemList* sGraphItemList = nil;

+ (ItemList*) graphItemList
{
	if (sGraphItemList == nil)
	{
		sGraphItemList = [[ItemList alloc] init];
		[sGraphItemList addItem:@"Altitude" tag:kAltitude];
		[sGraphItemList addItem:@"Heart rate" tag:kHeartrate];
		[sGraphItemList addItem:@"Speed/Pace" tag:kSpeed];
		[sGraphItemList addItem:@"Cadence" tag:kCadence];
		[sGraphItemList addItem:@"Power" tag:kPower];
		[sGraphItemList addItem:@"Gradient" tag:kGradient];
		[sGraphItemList addItem:@"Temperature" tag:kTemperature];
	}
	return sGraphItemList;
}


+ (void) buildPopupMenuFromItemList:(ItemList*)itemList popup:(NSPopUpButton*)p
{
   [p removeAllItems];
   int num = [itemList numItems];
   for (int i=0; i<num; i++)
   {
      [p addItemWithTitle:[itemList nameOfItemAtIndex:i]];
      [[p itemAtIndex:i] setTag:[itemList tagOfItemAtIndex:i]];
   }
}

+ (void) buildDataTypePopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd
{
	[p removeAllItems];
	if (ipd) [p addItemWithTitle:@" "];		// pull-down fills this with selected entry
	[p addItemWithTitle:@"Hybrid (VirtualEarth)"];
	[p addItemWithTitle:@"Aerial (VirtualEarth)"];
	[p addItemWithTitle:@"Road (VirtualEarth)"];
	[p addItemWithTitle:@"(USGS) Aerial"];
	[p addItemWithTitle:@"(USGS) Urban"];
	[p addItemWithTitle:@"(USGS) Topo"];
}


+ (void) buildBrowserOptionsPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd
{
	[p removeAllItems];
	if (ipd) [p addItemWithTitle:@" "];		// pull-down fills this with selected entry
	[p addItemWithTitle:@"Normal view"];
	[p addItemWithTitle:@"All activities"];
	[p addItemWithTitle:@"All weeks"];
	[p addItemWithTitle:@"All months"];
	[p addItemWithTitle:@"All years"];
}


#define MAX_SPLIT_DIST		50.0

static const float sSplitValues[] = 
{
	.25,
	.50,
	1.0,
	2.0,
	5.0,
	10.0,
	20.0,
	25.0
};

static const int sNumSplitValues = sizeof(sSplitValues)/sizeof(float);

// returns current split distance, in MILES
+ (float) currentSplitDistance
{
	float ret;
	int splitIndex = [self intFromDefaults:RCBDefaultSplitIndex];
	BOOL usingLaps(NO);
	if (IS_BETWEEN(0, splitIndex, (sNumSplitValues-1)))
	{
		ret = sSplitValues[splitIndex];
	}
	else if (splitIndex == sNumSplitValues)
	{
		ret = [self floatFromDefaults:RCBDefaultCustomSplitDistance];
	}
	else
	{
		ret = -1;
		usingLaps = YES;
	}
	if (!usingLaps)
	{
		BOOL useStatute = [self boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
		if (!useStatute)
		{
			ret = KilometersToMiles(ret);
		}
		if (!IS_BETWEEN(0.0, ret, MAX_SPLIT_DIST)) ret = 1.0;
	}
	return ret;
}


+ (NSMenu*) buildSplitOptionsMenu:(NSMenu**)lsm graphSubMenu:(NSMenu**)gsm
{
	BOOL useStatute = [self boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	NSMenu* topMenu = [[[NSMenu alloc] initWithTitle:@"Split Options"] autorelease];
	
	[topMenu addItemWithTitle:@"Hide Split Table"
					   action:@selector(expandOrCollapseSplits:)
				keyEquivalent:@""];
	
	NSMenuItem* parent = [topMenu addItemWithTitle:@"Split Length"
												 action:nil
										  keyEquivalent:@""];
	
	NSMenu* subMenu = [[[NSMenu alloc] init] autorelease];
	if (lsm) *lsm = subMenu;
	const char* units = useStatute ? "miles" : "kilometers";
	for (int i=0; i<sNumSplitValues; i++)
	{
		float v = sSplitValues[i];
		NSString* frm = (v < 1.0) ? @"%0.2f %s" : @"%0.1f %s";
		
		[[subMenu addItemWithTitle:[NSString stringWithFormat:frm, sSplitValues[i], units]
						action:@selector(setSplitLength:)
					keyEquivalent:@""] setTag:i];
	}
	// add menu items for special split lengths: custom, or "use laps"
	float v = [Utils floatFromDefaults:RCBDefaultCustomSplitDistance];
	NSString* frm = (v < 1.0) ? @"Custom (%0.2f %s)..." : @"Custom (%0.1f %s)...";
	[[subMenu addItemWithTitle:[NSString stringWithFormat:frm, v, units]
					action:@selector(getCustomSplitDistance:)
				keyEquivalent:@""] setTag:sNumSplitValues];
	
	[[subMenu addItemWithTitle:@"Use Laps"
						action:@selector(setSplitLength:)
				 keyEquivalent:@""] setTag:sNumSplitValues+1];
	
	
	int selIdx = [Utils intFromDefaults:RCBDefaultSplitIndex];
	[[subMenu itemWithTag:selIdx] setState:NSControlStateValueOn];

	
	[topMenu setSubmenu:subMenu
					 forItem:parent];

	parent = [topMenu addItemWithTitle:@"Split Graph Item"
								action:nil
						 keyEquivalent:@""];
	subMenu = [[[NSMenu alloc] init] autorelease];
	if (gsm) *gsm = subMenu;
	SplitsTableStaticColumnInfo* stci = [[[SplitsTableStaticColumnInfo alloc] init] autorelease];
	int num = [stci numPossibleColumns];
	int ctr = 0;
	for (int i=0; i<num; i++)
	{
		tColInfo* colInfo = [stci nthPossibleColumnInfo:i];
		if (!FLAG_IS_SET(colInfo->flags, kNotAValidSplitGraphItem))
		{
			[[subMenu addItemWithTitle:[NSString stringWithUTF8String:colInfo->menuLabel]
								action:@selector(setSplitGraphItem:)
						 keyEquivalent:@""] setTag:i];
			++ctr;
		}
	}
	selIdx = [Utils intFromDefaults:RCBDefaultSplitGraphItem];
	[[subMenu itemWithTag:selIdx] setState:NSControlStateValueOn];
	[topMenu setSubmenu:subMenu
				forItem:parent];
	
	return topMenu;
}
	
	
+ (void) buildSplitOptionsPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd
{
	BOOL useStatute = [self boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	[p removeAllItems];
	if (ipd) [p addItemWithTitle:@" "];		// pull-down fills this with selected entry
	const char* units = useStatute ? "miles" : "kilometers";
	for (int i=0; i<sNumSplitValues; i++)
	{
		float v = sSplitValues[i];
		NSString* frm = (v < 1.0) ? @"%0.2f %s" : @"%0.1f %s";
		[p addItemWithTitle:[NSString stringWithFormat:frm, sSplitValues[i], units]];
	}
	[p addItemWithTitle:@"Custom..."];
	[p addItemWithTitle:@"Ues Laps"];
}


+ (NSString*) buildTrackDisplayedName:(Track*)track  prePend:(NSString*)prepend;
{
	NSDate* ct = [track creationTime];
	NSString* title = @"Track with no creation time";
	if (ct)
	{
		NSString* name = [track attribute:kName];
		title = [NSString stringWithString:prepend];
		title = [title stringByAppendingString:name];
		int timeFormat = [Utils intFromDefaults:RCBDefaultTimeFormat];
		NSString* defFmt;
		NSString* nameFmt;
		if (timeFormat == 0)
		{
		  defFmt = @"%A, %B %d, %Y at %I:%M%p";
		  nameFmt = @"  (%A, %B %d, %Y at %I:%M%p)";
		}
		else
		{
		  defFmt = @"%A, %B %d, %Y at %H:%M";
		  nameFmt = @"  (%A, %B %d, %Y at %H:%M)";
		}
		NSString* format =  ([name length] != 0) ? nameFmt : defFmt;
		NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
		title = [title stringByAppendingString:[ct descriptionWithCalendarFormat:format
																	   timeZone:tz
																		 locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
	}
	return title;
}



+ (NSString*) getMapTilesPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [NSMutableString stringWithString:[paths objectAtIndex:0]];
	path = [path stringByAppendingPathComponent:PROGRAM_NAME];
	[Utils verifyDirAndCreateIfNecessary:path];
	path = [path stringByAppendingPathComponent:@"Map Cache"];
	[Utils verifyDirAndCreateIfNecessary:path];
	return path;
}

static HRThreshInfo        sThreshInfo[kNumHRZones];
static BOOL                sThreshInited = NO;

+(NSString*) getHeartrateColorKey:(float)hr
{
   if (!sThreshInited)
   {
      sThreshInfo[0].thresh = [Utils floatFromDefaults:RCBDefaultZone5Threshold];
      sThreshInfo[0].colorKey = RCBDefaultZone5Color;
      sThreshInfo[1].thresh = [Utils floatFromDefaults:RCBDefaultZone4Threshold];
      sThreshInfo[1].colorKey = RCBDefaultZone4Color;
      sThreshInfo[2].thresh = [Utils floatFromDefaults:RCBDefaultZone3Threshold];
      sThreshInfo[2].colorKey = RCBDefaultZone3Color;
      sThreshInfo[3].thresh = [Utils floatFromDefaults:RCBDefaultZone2Threshold];
      sThreshInfo[3].colorKey = RCBDefaultZone2Color;
      sThreshInfo[4].thresh = [Utils floatFromDefaults:RCBDefaultZone1Threshold];
      sThreshInfo[4].colorKey = RCBDefaultZone1Color;
      sThreshInited = YES;
   }
   for (int i=0; i<kNumHRZones; i++)
   {
      if (hr >= sThreshInfo[i].thresh)
      {
         return sThreshInfo[i].colorKey;
      }
   }
   return RCBDefaultBelowZoneColor;
}


+(BOOL)usingStatute
{
	return [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
}


+ (float) convertDistanceValue:(float)dval
{
   BOOL useStatute = [self usingStatute];
   if (useStatute)
   {
      return dval;
   }
   else
   {
      return MilesToKilometers(dval);
   }
}

+ (float) convertTemperatureValue:(float)tval
{
	BOOL useCentigrade = [self boolFromDefaults:RCBDefaultUseCentigrade];
	if (!useCentigrade)
	{
		return tval;
	}
	else
	{
		return FahrenheightToCelsius(tval);
	}
}



+ (float) convertClimbValue:(float)cval
{
   BOOL useStatute = [self usingStatute];
   if (useStatute)
   {
      return cval;
   }
   else
   {
      return FeetToMeters(cval);
   }
}


+ (float) convertSpeedValue:(float)sval
{
   BOOL useStatute = [self usingStatute];
   if (useStatute)
   {
      return sval;
   }
   else
   {
      return MilesToKilometers(sval);
   }
}


+ (float) convertWeightValue:(float)wval
{
   BOOL useStatute = [self usingStatute];
   if (useStatute)
   {
      return wval;
   }
   else
   {
      return PoundsToKilograms(wval);  
   }
}

+ (float) convertPaceValue:(float)pval
{
   BOOL useStatute = [self usingStatute];
   if (!useStatute)
   {
      if (pval != 0)
         pval = 1.0/(MilesToKilometers(1.0/pval));
   }
   return pval;
}


+ (NSString*) convertPaceValueToString:(float)pval
{
   BOOL useStatute = [self boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
   if (!useStatute)
   {
      if (pval != 0)
         pval = 1.0/(MilesToKilometers(1.0/pval));
   }
   pval *= 60.0;     // to seconds
   int hrs = (int)(pval/(60.0*60));
   int mins = (int)(pval/60.0) % 60;
   int secs = (int)pval % 60;
   NSMutableString* s = [NSMutableString stringWithString:@""];
   if (hrs > 0)
   {
      [s appendString:[NSString stringWithFormat:@"%02d:", hrs]];
   }
   [s appendString:[NSString stringWithFormat:@"%02d:%02d", mins, secs]];
   return s;
}



// if an important data element is out of range, return 'NO', otherwise 'YES'
+ (BOOL) checkDataSanity:(time_t) creationTime
                latitude:(float) latitude
               longitude:(float) longitude
                altitude:(float) altitude
               heartrate:(int) heartrate
                 cadence:(int) cadence
             temperature:(float) temperature
                   speed:(float) speed
                distance:(float) distance
{
   //return IS_BETWEEN(kMinPossibleSpeed,      speed,      kMaxPossibleSpeed) &&
   //       IS_BETWEEN(kMinPossibleAltitude,   altitude,   kMaxPossibleAltitude);
   return YES;
}


+ (BOOL) validateLatitude:(float)lat longitude:(float)lon
{
   return IS_BETWEEN(kMinPossibleLatitude,   lat,  kMaxPossibleLatitude) &&
          IS_BETWEEN(kMinPossibleLongitude,  lon,  kMaxPossibleLongitude);
}


+ (float) latLonToDistanceInMiles:(float)lat1 lon1:(float)lon1 
                             lat2:(float)lat2 lon2:(float)lon2
{
   double v = sin(((double)(lat1))/(double)57.2958) * sin(((double)(lat2))/(double)57.2958) + 
      cos(((double)(lat1))/(double)57.2958) * cos(((double)(lat2))/(double)57.2958) * cos(((double)(lon2))/(double)57.2958 - ((double)(lon1))/(double)57.2958);
   if ((v > 1.0) || (v < -1.0))
   {
      return 0.0;
   }
   return (float)(((double)3963.0) * acos(v));
}


+ (NSString*) dateFormat
{
   OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
   switch ([defaults integerForKey:RCBDefaultDateFormat])
   {
      default:
      case 0:        // dd-mmm-yy
         return @"%d-%b-%y";
         break;
      case 1:        // mmm dd, yy
         return @"%B %d, %Y";
         break;
      case 2:        // mm/dd/yy
         return @"%m/%d/%y";
         break;
      case 3:        // dd/mm/yy
         return @"%d/%m/%y";
   
   }
}


+ (NSString*) activityNameFromDate:(Track*)track alternateStartTime:(NSDate*)altStartTime
{
   NSString* dt;
	NSDate* startTime = (altStartTime == nil) ? [track creationTime] : altStartTime;
   NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
   int timeFormat = [Utils intFromDefaults:RCBDefaultTimeFormat];
	if (timeFormat == 0)
   {
      dt = [startTime 
            descriptionWithCalendarFormat:@"%A, %B %d, %Y at %I:%M%p"
                                 timeZone:tz 
                                   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
   }
   else
   {
      dt = [startTime
            descriptionWithCalendarFormat:@"%A, %B %d, %Y at %H:%M"
                                 timeZone:tz 
                                   locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
   }
   return dt;
}   


+ (int) calculateAge:(NSDate*)birthDate
{
	NSCalendarDate* bd = [birthDate dateWithCalendarFormat:nil
												  timeZone:nil];
	NSCalendarDate* now = [NSCalendarDate calendarDate];
	NSInteger junk;
	NSInteger years;
	[now years:&years
		months:&junk
		  days:&junk
		 hours:&junk
	   minutes:&junk
	   seconds:&junk
	 sinceDate:bd];
	return years;
}



+ (void) selectMenuItem:(int)itemTag forMenu:(NSMenu*)menu
{
	int numMenuItems = [menu numberOfItems];
	for (int i=0; i<numMenuItems; i++)
	{
		NSMenuItem* mi = [menu itemAtIndex:i];
		[mi setState:([mi tag] == itemTag) ? NSControlStateValueOn : NSControlStateValueOff];
	}
}


+ (void)setBackupDefaults
{
	int v = [Utils intFromDefaults:RCBDefaultLocalBackupFrequency];
	if (!IS_BETWEEN(1,v,10)) 
	{
		v = 10;	
		[Utils setIntDefault:v 
					  forKey:RCBDefaultLocalBackupFrequency];
	}
	
	v = [Utils intFromDefaults:RCBDefaultLocalBackupRetainCount];
	if (!IS_BETWEEN(2,v,10)) 
	{
		v = 10;	
		[Utils setIntDefault:v 
					  forKey:RCBDefaultLocalBackupRetainCount];
	}
	
	v = [Utils intFromDefaults:RCBDefaultMobileMeBackupFrequency];
	if (!IS_BETWEEN(1,v,10)) 
	{
		v = 10;	
		[Utils setIntDefault:v 
					  forKey:RCBDefaultMobileMeBackupFrequency];
	}
	
	NSString* localBackupFolder = [Utils stringFromDefaults:RCBDefaultLocalBackupFolder];
	if (localBackupFolder == nil || [localBackupFolder isEqualToString:@""])
	{
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString *localBackupFolder = [NSMutableString stringWithString:[paths objectAtIndex:0]];
		[Utils setStringDefault:localBackupFolder 
						 forKey:RCBDefaultLocalBackupFolder];
	}
}


+ (NSString*) friendlySizeAsString:(int)sz
{
	if (sz < 1024)
	{
		return [NSString stringWithFormat:@"%d bytes", sz];
	}
	else if (sz < 1024*1024)
	{
		return [NSString stringWithFormat:@"%1.1fKB", (float)sz/1024.0];
	}
	else
	{
		return [NSString stringWithFormat:@"%1.1fMB", (float)sz/(1024.0*1024.0)];
	}
}


//---- Peak Power Interval support ---------------------------------------------

		


static int sPeakIntervals[] = { 5, 10, 20, 30, 60, 5*60, 10*60, 20*60, 30*60, 60*60 };


+(NSDictionary*)peakPowerIntervalInfoDict
{
	OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSDictionary* dict = [defaults objectForKey:RCBDefaultPowerPeakIntervals];
	int num = sizeof(sPeakIntervals)/sizeof(int);
	if (!dict || ([dict count] < num))
	{
		NSMutableDictionary* mdict = [NSMutableDictionary dictionaryWithCapacity:num];
		for (int i=0; i<num; i++)
		{
			[mdict setObject:[NSNumber numberWithBool:(i==5) ? YES : NO]
					  forKey:[NSString stringWithFormat:@"%d",sPeakIntervals[i]]];
		}
		dict = [NSDictionary dictionaryWithDictionary:mdict];
		[defaults setObject:dict
					 forKey:RCBDefaultPowerPeakIntervals];
	}
	return dict;
}


+(int)numPeakIntervals
{
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	return [dict count];
}


+(int)nthPeakInterval:(int)n
{
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	NSArray* keys = [[dict allKeys] sortedArrayUsingSelector:@selector(compareAsNumbers:)];
	NSString* k = [keys objectAtIndex:n];
	return [k intValue];
}


		
+(int)numPeakDataTypes
{
	return kPDT_Count;
}


+ (NSString*) friendlyIntervalAsString:(int)iv
{
	if (iv < 60)
	{
		return [NSString stringWithFormat:@"%d seconds", iv];
	}
	else if (iv < (60*60))
	{
		int rem = iv % 60;
		if (rem)
			return [NSString stringWithFormat:@"%d minutes, %d seconds", iv/60, rem];
		else
			return [NSString stringWithFormat:@"%d minute%s", iv/60, iv/60 == 1 ? "" : "s"];
	}
	else
	{	
		int hours = iv/(60*60);
		int seconds = iv % (60*60);
		int minutes = seconds/60;
		seconds = seconds % 60;
		if (seconds)
		{
			return [NSString stringWithFormat:@"%d hours, %d minutes, %d seconds", hours, minutes, seconds];
		}
		else if (minutes)
		{
			return [NSString stringWithFormat:@"%d hours, %d minutes", hours, minutes];
		}
		else
		{
			return [NSString stringWithFormat:@"%d hour%s", hours, hours > 1 ? "s" : ""];
		}
	}
}


+ (void) updateEnabledPeaks:(NSPopUpButton*)p dict:(NSDictionary*)dict sortedKeys:(NSArray*)sortedKeys
{
	int num = [sortedKeys count];
	NSMutableArray* enabledArr = [NSMutableArray arrayWithCapacity:num];
	for (int i=0; i<num; i++)
	{
		NSString* k = [sortedKeys objectAtIndex:i];
		NSNumber* intervalNum = [NSNumber numberWithInt:[k intValue]];
		NSNumber* enabledNum = [dict objectForKey:k];
		NSMenuItem* item = [p itemAtIndex:i+1];
		BOOL enabled = [enabledNum boolValue];
		[item setState:enabled];
		if (enabled) [enabledArr addObject:intervalNum];
	}
	int numEnabled = [enabledArr count];
	NSMenuItem* item = [p itemAtIndex:0];
	if (numEnabled == 0)
	{
		[item setTitle:@"none selected"];
	}
	else if (numEnabled == 1)
	{
		NSNumber* n = [enabledArr objectAtIndex:0];
		[item setTitle:[NSString stringWithString:[Utils friendlyIntervalAsString:[n intValue]]]];
	}
	else
	{
		[item setTitle:@"<multiple>"];
	}
}


+ (void) buildPeakIntervalsPopup:(NSPopUpButton*)p 
{
	[p removeAllItems];
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	if (dict)
	{
		[p addItemWithTitle:@""];		// pull-down fills this with selected entry
		NSArray* keys = [dict allKeys];
		keys = [keys sortedArrayUsingSelector:@selector(compareAsNumbers:)];
		int num = [keys count];
		for (int i=0; i<num; i++)
		{
			NSString* k = [keys objectAtIndex:i];
			NSNumber* intervalNum = [NSNumber numberWithInt:[k intValue]];
			[p addItemWithTitle:[Utils friendlyIntervalAsString:[intervalNum intValue]]];
		}
		[Utils updateEnabledPeaks:p
							 dict:dict
					   sortedKeys:keys];
	}
}



+ (BOOL) peakPowerIntervalAtIndexEnabled:(int)idx
{
	BOOL enabled = NO;
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	NSMutableDictionary* mdict = [NSMutableDictionary dictionaryWithDictionary:dict];
	NSArray* keys = [dict allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(compareAsNumbers:)];
	if (idx < [keys count])
	{
		NSString* k = [keys objectAtIndex:idx];
		NSNumber* enabledNum = [mdict objectForKey:k];
		if (enabledNum) enabled = [enabledNum boolValue];
	}
	return enabled;
}


+ (void) setPeakPowerIntervalAtIndexEnabled:(int)idx enabled:(BOOL)en
{
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	NSMutableDictionary* mdict = [NSMutableDictionary dictionaryWithDictionary:dict];
	NSArray* keys = [dict allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(compareAsNumbers:)];
	if (idx < [keys count])
	{
		NSString* k = [keys objectAtIndex:idx];
		[mdict setObject:[NSNumber numberWithBool:en] 
				  forKey:k];
		OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
		[defaults setObject:mdict
					 forKey:RCBDefaultPowerPeakIntervals];
	}
}



+ (void) togglePeakPowerIntervalAtIndex:(int)idx popup:(NSPopUpButton*)p 
{
	BOOL en = [Utils peakPowerIntervalAtIndexEnabled:idx];
	[Utils setPeakPowerIntervalAtIndexEnabled:idx
									  enabled:!en];
	if (p) 
	{
		NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
		[Utils updateEnabledPeaks:p
							 dict:dict
					   sortedKeys:[[dict allKeys] sortedArrayUsingSelector:@selector(compareAsNumbers:)]];
	}
}


+ (NSString*)imagePathFromBundleWithName:(NSString*)imageName
{
	NSString* path = [[NSBundle mainBundle] pathForResource:imageName 
													 ofType:@"png"];
	if (!path)
		path = [[NSBundle mainBundle] pathForResource:imageName 
											   ofType:@"jpg"];
	return path;
}


+(NSImage*)imageFromBundleWithName:(NSString*)imageName
{
	NSImage* img = nil;
	NSString* path = [self imagePathFromBundleWithName:imageName];
	if (path) img = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	return img;
}


+(void)createPowerActivityArrayIfDoesntExist
{	
	NSArray* arr = [Utils objectFromDefaults:RCBDefaultCalculatePowerActivities];
	if (arr == nil)
	{
		NSMutableArray* powerActs = [NSMutableArray arrayWithCapacity:2];
		NSArray * itemArray = [Utils attributeArray:RCBDefaultAttrActivityList];
		for (NSString* act in itemArray)
		{
			NSRange rng = [act rangeOfString:@"cycling"
									 options:NSCaseInsensitiveSearch];
			if (rng.location == NSNotFound)
			{
				rng = [act rangeOfString:@"biking"
								 options:NSCaseInsensitiveSearch];
			}
			if (rng.location != NSNotFound)
			{
				[powerActs addObject:act];
			}
		}
		[Utils setObjectDefault:powerActs 
						 forKey:RCBDefaultCalculatePowerActivities];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
	}
}	


+(void)maxMinAlt:(NSArray*)pts max:(NSNumber**)mxn min:(NSNumber**)mnn
{
	float max = -10000;
	float min = +10000;
	for (TrackPoint* pt in pts)
	{
		float alt = [pt altitude];
		if (alt != BAD_ALTITUDE)
		{
			if (alt > max) max = alt;
			if (alt < min) min = alt;
		}
	}
	if (mxn) *mxn = [NSNumber numberWithFloat:max];
	if (mnn) *mnn = [NSNumber numberWithFloat:min];
}

#import "fit.h"

+(NSString*)deviceNameForID:(int)did
{
	NSString* name = nil;
	static NSMutableDictionary* sDeviceDict = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
	if ([sDeviceDict count] == 0)
	{
		///[sDeviceDict setObject:@"Garmin FR405"
		///				forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_FR405]];
		[sDeviceDict setObject:@"Garmin FR405 CX"
						forKey:[NSNumber numberWithInt:1039]];
		///[sDeviceDict setObject:@"Garmin FR50"
		///				forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_FR50]];
		///[sDeviceDict setObject:@"Garmin 310XT"
		///				forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_FR310XT]];
		[sDeviceDict setObject:@"Garmin Edge 500"
						forKey:[NSNumber numberWithInt:1036]];
		[sDeviceDict setObject:@"Garmin Edge 705"
						forKey:[NSNumber numberWithInt:625]];
		[sDeviceDict setObject:@"Garmin Edge 305"
						forKey:[NSNumber numberWithInt:450]];
		///[sDeviceDict setObject:@"Garmin FR60"
		///				forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_FR60]];
		[sDeviceDict setObject:@"Garmin FR301"
						forKey:[NSNumber numberWithInt:383]];
		[sDeviceDict setObject:@"Garmin FR205"
						forKey:[NSNumber numberWithInt:484]];
		[sDeviceDict setObject:@"Garmin FR110"
						forKey:[NSNumber numberWithInt:1124]];
		[sDeviceDict setObject:@"Garmin Edge 800"
						forKey:[NSNumber numberWithInt:1169]];
		[sDeviceDict setObject:@"Garmin FR210"
						forKey:[NSNumber numberWithInt:1264]];
		[sDeviceDict setObject:@"Garmin 410"
						forKey:[NSNumber numberWithInt:1250]];
		[sDeviceDict setObject:@"Garmin 610"
						forKey:[NSNumber numberWithInt:1345]];
		[sDeviceDict setObject:@"Garmin 910XT"
						forKey:[NSNumber numberWithInt:1328]];
//		[sDeviceDict setObject:@"SDM4 Footpod"
//						forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_SDM4]];
//		[sDeviceDict setObject:@"Garmin Connect"
//						forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_CONNECT]];
//		[sDeviceDict setObject:@"Garmin Training Center"
//						forKey:[NSNumber numberWithInt:FIT_GARMIN_PRODUCT_TRAINING_CENTER]];
	}
	if (did > 0)
	{
		name = [sDeviceDict objectForKey:[NSNumber numberWithInt:did]];
	}
	return name;
}



@end
