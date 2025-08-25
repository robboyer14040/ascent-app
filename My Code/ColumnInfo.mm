//
//  ColumnInfo.mm
//  Ascent
//
//  Created by Rob Boyer on 2/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "ColumnInfo.h"
#import "AscentIntervalFormatter.h"
#import "Defs.h"
#import "SplitDefs.h"
#import "Utils.h"


//---- ColumnInfo implementation ---------------------------------------------------------------------
@implementation MainBrowserStaticColumnInfo

static tColInfo sColInfo[] = 
{
	{ "Date/Time",       "Date/Time",					kCT_Name,         "",         kMT_DateTime,        180,   kUT_IsText,			kCantRemove |  kDefaultField | kLeftAlignment},
	{ "Title",           "Title",						kCT_Title,        "",         kMT_Title,           124,   kUT_IsText,			kDefaultField | kUseStringComparator  | kLeftAlignment},
	{ "Distance",        "Distance",					kCT_Distance,     "#,##0.00", kMT_Distance,        80,    kUT_IsDistance,		kDefaultField | kUseNumberFormatter },
	{ "Duration",        "Duration",					kCT_Duration,     "",         kMT_TotalDuration,   72,    kUT_IsTime,			kUseIntervalFormatter },
	{ "AvgSpd",          "Average Speed",				kCT_AvgSpeed,     "#0.0",    kMT_AvgSpeed,        50,    kUT_IsSpeed,			kUseNumberFormatter },
	{ "MaxSpd",          "Maximum Speed",				kCT_MaxSpeed,     "#0.0",    kMT_MaxSpeed,        50,    kUT_IsSpeed,			kUseNumberFormatter },
	{ "MovSpd",          "Average Moving Speed",		kCT_MovSpeed,     "#0.0",    kMT_AvgMovingSpeed,  50,    kUT_IsSpeed,			kDefaultField | kUseNumberFormatter },
	{ "Climb",           "Total Climb",					kCT_Climb,        "##,##0",  kMT_Climb,           82,	 kUT_IsClimb,			kDefaultField | kUseNumberFormatter },
	{ "Descent",         "Total Descent",				kCT_Descent,      "##,##0",  kMT_Descent,         82,    kUT_IsClimb,			kUseNumberFormatter },
	{ "+VAM",			 "Rate of Climb",				kCT_RateOfClimb,  "##,##0",  kMT_RateOfClimb,     82,	 kUT_IsVAM,				kUseNumberFormatter },
	{ "-VAM",			 "Rate of Descent",				kCT_RateOfDescent,"##,##0",  kMT_RateOfDescent,   82,	 kUT_IsVAM,				kUseNumberFormatter },
	{ "Keyword 1",       "Keyword 1",					kCT_Keyword1,     "",         kMT_Keyword1,        90,    kUT_IsText,			kDefaultField | kUseStringComparator  | kLeftAlignment},
	{ "Keyword 2",       "Keyword 2",					kCT_Keyword2,     "",         kMT_Keyword2,        90,    kUT_IsText,			kDefaultField | kUseStringComparator  | kLeftAlignment},
	{ "Custom",          "Custom",						kCT_Custom,       "",         kMT_Custom,          90,    kUT_IsText,			kDefaultField | kUseStringComparator  | kLeftAlignment},
	{ "ActiveTime",      "Moving (Active) Time",		kCT_ActivityTime, "",         kMT_MovingDuration,  72,    kUT_IsTime,			kDefaultField | kUseIntervalFormatter },
	{ "MaxHR",           "Maximum Heart Rate",			kCT_MaxHR,        "##0",      kMT_MaxHR,           46,    kUT_IsHeartRate,		kDefaultField | kUseNumberFormatter },
	{ "AvgHR",           "Average Heart Rate",			kCT_AvgHR,        "##0",      kMT_AvgHR,           46,    kUT_IsHeartRate,		kUseNumberFormatter },
	{ "MaxCad",          "Maximum Cadence",				kCT_MaxCadence,   "##0",      kMT_MaxCadence,      46,    kUT_IsCadence,		kUseNumberFormatter },
	{ "AvgCad",          "Average Cadence",				kCT_AvgCadence,   "##0",      kMT_AvgCadence,      46,    kUT_IsCadence,		kUseNumberFormatter },
	{ "MaxPwr",          "Maximum Power",				kCT_MaxPower,	  "#,##0",   kMT_MaxPower,        46,    kUT_IsPower,			kUseNumberFormatter },
	{ "AvgPwr",          "Average Moving Power",		kCT_AvgPower,	  "#,##0",   kMT_AvgPower,        46,    kUT_IsPower,			kDefaultField | kUseNumberFormatter },
	{ "Work(KJ)",        "KJoules of Work",				kCT_Work,		  "#,##0",   kMT_Work,			   46,    kUT_IsWork,			kUseNumberFormatter },
	{ "MaxGrd",          "Maximum Gradient",			kCT_MaxGradient,  "#0.0",     kMT_MaxGradient,     46,	  kUT_IsGradient,		kUseNumberFormatter },
	{ "MinGrd",          "Minimum Gradient",			kCT_MinGradient,  "#0.0",     kMT_MinGradient,     46,    kUT_IsGradient,		kUseNumberFormatter },
	{ "AvgGrd",          "Average Gradient",			kCT_AvgGradient,  "#0.0",     kMT_AvgGradient,     46,    kUT_IsGradient,		kUseNumberFormatter },
	{ "MaxAlt",          "Maximum Altitude",			kCT_MaxAlt,       "#,##0",      kMT_MaxAlt,		   46,    kUT_IsClimb,			kUseNumberFormatter },
	{ "MinAlt",          "Minimum Altitude",			kCT_MinAlt,       "#,##0",      kMT_MinAlt,          46,    kUT_IsClimb,			kUseNumberFormatter },
	{ "AvgAlt",          "Average Altitude",			kCT_AvgAlt,       "#,##0",      kMT_AvgAlt,          46,    kUT_IsClimb,			kUseNumberFormatter },
	{ "HR Zone1 Time",   "Time in Heart Rate Zone 1",	kCT_TimeInHRZ1,   "",         kMT_TimeInHRZ1,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "HR Zone2 Time",   "Time in Heart Rate Zone 2",	kCT_TimeInHRZ2,   "",         kMT_TimeInHRZ2,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "HR Zone3 Time",   "Time in Heart Rate Zone 3",	kCT_TimeInHRZ3,   "",         kMT_TimeInHRZ3,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "HR Zone4 Time",   "Time in Heart Rate Zone 4",	kCT_TimeInHRZ4,   "",         kMT_TimeInHRZ4,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "HR Zone5 Time",   "Time in Heart Rate Zone 5",	kCT_TimeInHRZ5,   "",         kMT_TimeInHRZ5,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Alt Zone1 Time",  "Time in Altitude Zone 1",		kCT_TimeInALTZ1,  "",         kMT_TimeInALTZ1,     64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Alt Zone2 Time",  "Time in Altitude Zone 2",		kCT_TimeInALTZ2,  "",         kMT_TimeInALTZ2,     64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Alt Zone3 Time",  "Time in Altitude Zone 3",		kCT_TimeInALTZ3,  "",         kMT_TimeInALTZ3,     64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Alt Zone4 Time",  "Time in Altitude Zone 4",		kCT_TimeInALTZ4,  "",         kMT_TimeInALTZ4,     64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Alt Zone5 Time",  "Time in Altitude Zone 5",		kCT_TimeInALTZ5,  "",         kMT_TimeInALTZ5,      4,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Cad Zone1 Time",  "Time in Cadence Zone 1",		kCT_TimeInCDZ1,   "",         kMT_TimeInCDZ1,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Cad Zone2 Time",  "Time in Cadence Zone 2",		kCT_TimeInCDZ2,   "",         kMT_TimeInCDZ2,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Cad Zone3 Time",  "Time in Cadence Zone 3",		kCT_TimeInCDZ3,   "",         kMT_TimeInCDZ3,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Cad Zone4 Time",  "Time in Cadence Zone 4",		kCT_TimeInCDZ4,   "",         kMT_TimeInCDZ4,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Cad Zone5 Time",  "Time in Cadence Zone 5",		kCT_TimeInCDZ5,   "",         kMT_TimeInCDZ5,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Grd Zone1 Time",  "Time in Gradient Zone 1",		kCT_TimeInGDZ1,   "",         kMT_TimeInGDZ1,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Grd Zone2 Time",  "Time in Gradient Zone 2",		kCT_TimeInGDZ2,   "",         kMT_TimeInGDZ2,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Grd Zone3 Time",  "Time in Gradient Zone 3",		kCT_TimeInGDZ3,   "",         kMT_TimeInGDZ3,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Grd Zone4 Time",  "Time in Gradient Zone 4",		kCT_TimeInGDZ4,   "",         kMT_TimeInGDZ4,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Grd Zone5 Time",  "Time in Gradient Zone 5",		kCT_TimeInGDZ5,   "",         kMT_TimeInGDZ5,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Pace Zone1 Time", "Time in Pace Zone 1",			kCT_TimeInPCZ1,   "",         kMT_TimeInPCZ1,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Pace Zone2 Time", "Time in Pace Zone 2",			kCT_TimeInPCZ2,   "",         kMT_TimeInPCZ2,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Pace Zone3 Time", "Time in Pace Zone 3",			kCT_TimeInPCZ3,   "",         kMT_TimeInPCZ3,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Pace Zone4 Time", "Time in Pace Zone 4",			kCT_TimeInPCZ4,   "",         kMT_TimeInPCZ4,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Pace Zone5 Time", "Time in Pace Zone 5",			kCT_TimeInPCZ5,   "",         kMT_TimeInPCZ5,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Spd Zone1 Time",  "Time in Speed Zone 1",		kCT_TimeInSPZ1,   "",         kMT_TimeInSPZ1,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Spd Zone2 Time",  "Time in Speed Zone 2",		kCT_TimeInSPZ2,   "",         kMT_TimeInSPZ2,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Spd Zone3 Time",  "Time in Speed Zone 3",		kCT_TimeInSPZ3,   "",         kMT_TimeInSPZ3,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Spd Zone4 Time",  "Time in Speed Zone 4",		kCT_TimeInSPZ4,   "",         kMT_TimeInSPZ4,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Spd Zone5 Time",  "Time in Speed Zone 5",		kCT_TimeInSPZ5,   "",         kMT_TimeInSPZ5,      64,    kUT_IsTime,			kUseIntervalFormatter },
	{ "Activity",        "Activity",					kCT_Activity,     "",         kMT_Activity,        60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment },
	{ "Equipment",       "Equipment",					kCT_Equipment,    "",         kMT_Equipment,       60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment},
	{ "Event Type",      "Event Type",					kCT_EventType,    "",         kMT_EventType,       60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment},
	{ "Wt",              "Weight",						kCT_Weight,       "#0.0",     kMT_Weight,          46,    kUT_IsWeight,			kUseNumberFormatter },
	{ "Disposition",     "Disposition",					kCT_Disposition,  "",         kMT_Disposition,     60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment},
	{ "Effort",          "Effort",						kCT_Effort,       "",         kMT_Effort,          60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment},
	{ "Weather",         "Weather",						kCT_Weather,      "",         kMT_Weather,         60,    kUT_IsText,			kUseStringComparator  | kLeftAlignment},
	{ "AvgPce",          "Average Pace",				kCT_AvgPace,      "",         kMT_AvgPace,         50,    kUT_IsPace,			kUsePaceFormatter },
	{ "MovPce",          "Average Moving Pace",			kCT_AvgMovingPace,"",         kMT_AvgMovingPace,   50,    kUT_IsPace,			kUsePaceFormatter },
	{ "Calories",        "Calories",					kCT_Calories,     "#,##0",    kMT_Calories,        54,    kUT_IsCalories,		kUseNumberFormatter },
	{ "Notes",           "Notes",						kCT_Notes,        "",         kMT_Notes,           124,   kUT_IsText,			kUseStringComparator  | kLeftAlignment },
	{ "Device",          "Device",						kCT_Device,        "",        kMT_Device,		   100,   kUT_IsText,			kUseStringComparator  | kLeftAlignment },
	{ "Firmware",		 "Firmware Version",			kCT_FirmWareVersion, "",      kMT_FirmwareVersion, 100,   kUT_IsText,			kUseStringComparator  | kLeftAlignment },
	{ "AvgTemp",		 "Average Temperature",			kCT_AvgTemperature, "#0.0",   kMT_AvgTemperature,  46,    kUT_IsTemperature,	kUseNumberFormatter },
	{ "MaxTemp",		 "Maximum Temperature",			kCT_MaxTemperature, "#0.0",   kMT_MaxTemperature,  46,    kUT_IsTemperature,	kUseNumberFormatter },
	{ "MinTemp",		 "Minimum Temperature",			kCT_MinTemperature, "#0.0",   kMT_MinTemperature,  46,    kUT_IsTemperature,	kUseNumberFormatter },
};

- (id) init
{
	return [super init];
}


- (int) numPossibleColumns
{
   return sizeof(sColInfo)/sizeof(tColInfo);
}

- (tColInfo*) nthPossibleColumnInfo:(int)nth
{
   return &sColInfo[nth];
}

@end

@implementation StaticColumnInfo

- (id) init
{
	return [super init];
}


- (int) numPossibleColumns
{
	return 0;
}

- (tColInfo*) nthPossibleColumnInfo:(int)nth
{
	return nil;
}


@end


@implementation SplitsTableStaticColumnInfo

static tColInfo sSplitsColInfo[] = 
{
	{ "SplitDist",		"Split Distance",					kSPLC_Distance,					"#,##0.00", kSPLM_Distance,					50,    kUT_IsDistance,	kUseNumberFormatter | kNotAValidSplitGraphItem},
	{ "Distance",       "Cumulative Distance",				kSPLC_DistSoFar,				"#,##0.00", kSPLM_DistSoFar,				60,    kUT_IsDistance,	kDefaultField | kUseNumberFormatter | kNotAValidSplitGraphItem },
	{ "SplitStart",		"Split Start Time",					kSPLC_StartTime,				"",         kSPLM_StartTime,				72,    kUT_IsTime,		kDefaultField | kUseIntervalFormatter | kNotAValidSplitGraphItem },
	{ "Duration",       "Split Duration",					kSPLC_Duration,					"",         kSPLM_Duration,					72,    kUT_IsTime,		kDefaultField | kUseIntervalFormatter | kNotAValidSplitGraphItem },
	{ "AvgSpd",         "Average Speed",					kSPLC_AvgSplitSpeed,			"#0.0",    kSPLM_AvgSplitSpeed,			50,    kUT_IsSpeed,		kUseNumberFormatter },
	{ "MaxSpd",         "Maximum Speed",					kSPLC_MaxSplitSpeed,			"#0.0",    kSPLM_MaxSplitSpeed,			50,    kUT_IsSpeed,		kUseNumberFormatter },
	{ "∆Spd",			"∆ Speed From Last",				kSPLC_DeltaSpeedFromLast,		"#0.0",    kSPLM_DeltaSpeedFromLast,		50,    kUT_IsSpeed,		kUseNumberFormatter | KIsDeltaValue},
	{ "∆AvgSpd",		"∆ Speed From Average",				kSPLC_DeltaSpeedFromAvg,		"#0.0",    kSPLM_DeltaSpeedFromAvg,		50,    kUT_IsSpeed,		kUseNumberFormatter | KIsDeltaValue },
	{ "AvgPce",         "Average Pace",						kSPLC_AvgPace,					"#0.00",    kSPLM_AvgPace,					50,    kUT_IsPace,		kDefaultField | kUsePaceFormatter },
	{ "MinPce",         "Minimum Pace",						kSPLC_MinPace,					"#0.00",    kSPLM_MinPace,					50,    kUT_IsPace,		kDefaultField | kUsePaceFormatter },
	{ "∆Pace",			"∆ Pace From Last",					kSPLC_DeltaPaceFromLast,		"#0.00",    kSPLM_DeltaPaceFromLast,		50,    kUT_IsPace,		kDefaultField | kUsePaceFormatter | KIsDeltaValue },
	{ "∆AvgPce",		"∆ Pace From Average",				kSPLC_DeltaPaceFromAvg,			"#0.00",    kSPLM_DeltaPaceFromAvg,			50,    kUT_IsPace,		kDefaultField | kUsePaceFormatter | KIsDeltaValue },
	{ "AvgHR",          "Average Heart Rate",				kSPLC_AvgHeartRate,				"##0",      kSPLM_AvgHeartRate,				46,    kUT_IsHeartRate,	kUseNumberFormatter },
	{ "MaxHR",          "Maximum Heart Rate",				kSPLC_MaxHeartRate,				"##0",      kSPLM_MaxHeartRate,				46,    kUT_IsHeartRate,	kUseNumberFormatter },
	{ "∆HR",			"∆ Heart Rate From Last",			kSPLC_DeltaHeartRateFromLast,	"##0",      kSPLM_DeltaHeartRateFromLast,	46,    kUT_IsHeartRate,	kUseNumberFormatter | KIsDeltaValue },
	{ "∆AvgHR",         "∆ Heart Rate From Average",		kSPLC_DeltaHeartRateFromAvg,	"##0",      kSPLM_DeltaHeartRateFromAvg,	46,    kUT_IsHeartRate,	kUseNumberFormatter | KIsDeltaValue },
	{ "AvgCad",         "Average Cadence",					kSPLC_AvgCadence,				"##0",      kSPLM_AvgCadence,				46,    kUT_IsCadence,	kUseNumberFormatter },
	{ "MaxCad",         "Maximum Cadence",					kSPLC_MaxCadence,				"##0",      kSPLM_MaxCadence,				46,    kUT_IsCadence,	kUseNumberFormatter },
	{ "∆Cad",			"∆ Cadence From Last",				kSPLC_DeltaCadenceFromLast,		"##0",      kSPLM_DeltaCadenceFromLast,		46,    kUT_IsCadence,	kUseNumberFormatter | KIsDeltaValue },
	{ "∆AvgCad",        "∆ Cadence From Average",			kSPLC_DeltaCadenceFromAvg,		"##0",      kSPLM_DeltaCadenceFromAvg,		46,    kUT_IsCadence,	kUseNumberFormatter | KIsDeltaValue },
	{ "AvgPwr",         "Average Power",					kSPLC_AvgPower,					"#,##0",   kSPLM_AvgPower,					46,    kUT_IsPower,		kUseNumberFormatter },
	{ "MaxPwr",         "Maximum Power",					kSPLC_MaxPower,					"#,##0",   kSPLM_MaxPower,					46,    kUT_IsPower,		kUseNumberFormatter },
	{ "∆Pwr",			"∆ Power From Last",				kSPLC_DeltaPowerFromLast,		"#,##0",   kSPLM_DeltaPowerFromLast,		46,    kUT_IsPower,		kUseNumberFormatter | KIsDeltaValue },
	{ "∆AvgPwr",        "∆ Power From Average",				kSPLC_DeltaPowerFromAvg,		"#,##0",   kSPLM_DeltaPowerFromAvg,		46,    kUT_IsPower,		kUseNumberFormatter | KIsDeltaValue },
	{ "AvgGrd",         "Average Gradient",					kSPLC_AvgGradient,				"#0.0",     kSPLM_AvgGradient,				46,    kUT_IsGradient,	kUseNumberFormatter },
	{ "MaxGrd",         "Maximum Gradient",					kSPLC_MaxGradient,				"#0.0",     kSPLM_MaxGradient,				46,    kUT_IsGradient,	kUseNumberFormatter },
	{ "MinGrd",         "Minimum Gradient",					kSPLC_MinGradient,				"#0.0",     kSPLM_MinGradient,				46,    kUT_IsGradient,	kUseNumberFormatter },
	{ "∆Grd",			"∆ Gradient From Last",				kSPLC_DeltaGradientFromLast,	"#0.0",		kSPLM_DeltaGradientFromLast,	46,    kUT_IsGradient,	kUseNumberFormatter | KIsDeltaValue },
	{ "∆AvgGrd",        "∆ Gradient From Average",			kSPLC_DeltaGradientFromAvg,		"#0.0",     kSPLM_DeltaGradientFromAvg,		46,    kUT_IsGradient,	kUseNumberFormatter | KIsDeltaValue },
	{ "Calories",       "Calories",							kSPLC_Calories,					"##0",      kSPLM_Calories,					54,    kUT_IsCalories,	kUseNumberFormatter },
	{ "∆Calories",      "∆ Calories From Last",				kSPLC_DeltaCaloriesFromLast,	"##0",      kSPLM_DeltaCaloriesFromLast,	54,    kUT_IsCalories,	kUseNumberFormatter | KIsDeltaValue },
	{ "Climb",          "Climb",							kSPLC_Climb,					"#,##0",	kSPLM_Climb,					82,    kUT_IsClimb,		kDefaultField | kUseNumberFormatter },
	{ "∆Climb",			"∆ Climb From Last",				kSPLC_DeltaClimbFromLast,		"#,##0",	kSPLM_DeltaClimbFromLast,		82,    kUT_IsClimb,		kDefaultField | kUseNumberFormatter | KIsDeltaValue },
	{ "+VAM",			"Rate Of Climb (+VAM)",				kSPLC_RateOfClimb,				"#,##0",	kSPLM_RateOfClimb,			    82,    kUT_IsVAM,		kDefaultField | kUseNumberFormatter },
	{ "∆+VAM",			"∆ Rate Of Climb (+VAM) From Last",	kSPLC_DeltaRateOfClimbFromLast,	"#,##0",	kSPLM_DeltaRateOfClimbFromLast,	82,    kUT_IsVAM,		kUseNumberFormatter | KIsDeltaValue },
	{ "-VAM",			"Rate Of Descent (-VAM)",			kSPLC_RateOfDescent,			"#,##0",	kSPLM_RateOfDescent,			82,    kUT_IsVAM,		kUseNumberFormatter },
	{ "∆-VAM",			"∆ Rate Of Descent (-VAM) From Last",kSPLC_DeltaRateOfDescentFromLast,"#,##0",	kSPLM_DeltaRateOfDescentFromLast,82,   kUT_IsVAM,		kUseNumberFormatter | KIsDeltaValue },
};




- (id) init
{
	return [super init];
}

- (int) numPossibleColumns
{
   return sizeof(sSplitsColInfo)/sizeof(tColInfo);
}

- (tColInfo*) nthPossibleColumnInfo:(int)nth
{
   return &sSplitsColInfo[nth];
}

@end



@implementation ColumnInfo

- (ColumnInfo*) initWithInfo:(tColInfo*)info
{
	self = [super init];
	if (0 != info)
	{
		colInfo = info;
		NSString* label = [self columnLabel];
		int flags = info->flags;
		if ((flags & kUseNumberFormatter) != 0)
		{
			NSNumberFormatter* fm =[[NSNumberFormatter alloc] init];
			NSString* fms = [NSString stringWithFormat:@"%s", info->format];
			[fm setFormat:fms];
			[fm setGroupingSize:3];
#if TEST_LOCALIZATION
			[fm setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
			[fm setLocale:[NSLocale currentLocale]];
#endif			
			[self setFormatter:fm];
		}
		else if ((flags & kUseIntervalFormatter) != 0)
		{
			AscentIntervalFormatter* fm =[[AscentIntervalFormatter alloc] initAsPace:NO];
			[self setFormatter:fm];
		}
		else if ((flags & kUsePaceFormatter) != 0)
		{
			AscentIntervalFormatter* fm =[[AscentIntervalFormatter alloc] initAsPace:YES];
			[self setFormatter:fm];
		}
        if (!label) {
            NSLog(@"label is nil, check Defaults initialization in Preferences FIXME");
            label = [NSString stringWithUTF8String:"not set"];
        }
		[self setTitle:label];
		[self setWidth:info->width];
		[self setOrder:((info->flags & kDefaultField) == 0) ? kNotInBrowser : 0];
	}
	return self;
}


-(void) dealloc
{
    [super dealloc];
}




- (id)mutableCopyWithZone:(NSZone *)zone
{
   ColumnInfo* ci = [[ColumnInfo allocWithZone:zone] initWithInfo:[self colInfo]];
   [ci setOrder:[self order]];
   [ci setFormatter:[self formatter]];
   [ci setWidth:[self width]];
   [ci setTitle:[self title]];
   return ci;
}

- (id)copyWithZone:(NSZone *)zone
{
   return [self mutableCopyWithZone:zone];
}

- (id) copy
{
   return [self copyWithZone:nil];
}

- (id) mutableCopy
{
   return [self copyWithZone:nil];
}


- (tColInfo*) colInfo
{
   return colInfo;
}


#define CUR_VERSION 1
// only store and retrieve things that will be stored persistently in the doc object
- (void)encodeWithCoder:(NSCoder *)coder
{
   int version = CUR_VERSION;
   float spareFloat = 0.0f;
   [coder encodeValueOfObjCType:@encode(int) at:&version];
   [coder encodeValueOfObjCType:@encode(int) at:&order];
   [coder encodeValueOfObjCType:@encode(float) at:&width];
   [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
   [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
}

- (id)initWithCoder:(NSCoder *)coder
{
   self = [super init];
   float fval;
   int version;
   [coder decodeValueOfObjCType:@encode(int) at:&version];
   if (version > CUR_VERSION)
   {
	   NSException *e = [NSException exceptionWithName:ExFutureVersionName
												reason:ExFutureVersionReason
											  userInfo:nil];			  
	   @throw e;
   }
   [coder decodeValueOfObjCType:@encode(int) at:&order];
   [coder decodeValueOfObjCType:@encode(float) at:&width];
   [coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
   [coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
   return self;
}      


- (NSString *)title 
{
   return title;
}


- (NSString *)menuLabel;
{
   switch (colInfo->tag)
   {
      default:
         return [NSString stringWithUTF8String:colInfo->menuLabel];
         
      case kMT_Keyword1:
         return [Utils stringFromDefaults:RCBDefaultKeyword1Label];
         break;
         
      case kMT_Keyword2:
         return [Utils stringFromDefaults:RCBDefaultKeyword2Label];
         break;
         
      case kMT_Custom:
         return [Utils stringFromDefaults:RCBDefaultCustomFieldLabel];
         break;
         
   }
}


- (NSString *)columnLabel;
{
   switch (colInfo->tag)
   {
      default:
		  return [NSString stringWithUTF8String:colInfo->columnLabel];
         
      case kMT_Keyword1:
         return [Utils stringFromDefaults:RCBDefaultKeyword1Label];
         break;

      case kMT_Keyword2:
         return [Utils stringFromDefaults:RCBDefaultKeyword2Label];
         break;

      case kMT_Custom:
         return [Utils stringFromDefaults:RCBDefaultCustomFieldLabel];
         break;

   }
}


- (NSString *)ident
{
   return [NSString stringWithFormat:@"%s", colInfo->ident];
}


- (void)setTitle:(NSString *)value 
{
    if (value == nil)
    {
        int wtf;
        wtf = 0;
        wtf *= 2;
    }
   if (title != value)
   {
      title = value;
   }
}


- (NSFormatter *)formatter 
{
   return formatter;
}


- (void)setFormatter:(NSFormatter *)value {
   if (formatter != value) 
   {
      formatter = value;
   }
}


- (float)width 
{
   return width;
}


- (void)setWidth:(float)value 
{
   if (width != value) 
   {
      width = value;
   }
}


- (int)order 
{
   return order;
}


- (void)setOrder:(int)value 
{
   if (order != value) 
   {
      order = value;
   }
}


- (int)tag 
{
   return colInfo->tag;
}

- (int)flags {
   return colInfo->flags;
}


- (NSComparisonResult)compare:(ColumnInfo *)ci
{
   if (order < [ci order])
      return NSOrderedAscending;
   else if (order > [ci order])
      return NSOrderedDescending;
   else
      return NSOrderedSame;
}


- (NSComparisonResult)compareUsingMenuName:(ColumnInfo *)ci
{
   return [[self menuLabel] caseInsensitiveCompare:[ci menuLabel]]; 
}


- (NSComparisonResult)compareUsingTitle:(ColumnInfo *)ci
{
   return [title caseInsensitiveCompare:[ci title]]; 
}


struct tLegendInfo
{
	const char*		statuteLegend;
	const char*		metricLegend;
};

static const tLegendInfo sLegendInfo[] = {
	{	"bpm",		"bpm"		},	// hr
	{	"",			""			},	// time
	{	"rpm",		"rpm"		},	// cadence
	{	"%",		"%"			},	// gradient
	{	"cal",		"cal"		},	// calories
	{	"ft",		"m"			},	// climb
	{	"mph",		"km/h"		},	// speed
	{	"min/mi",	"min/km"	},	// pace
	{	"mi",		"km"		},	// dist
	{	"ft/hr",	"m/hr"		},	// VAM
	{	"lbs",		"kg"		},	// Weight
	{	"°F",		"°C"		},	// Temperature
	{	"watts",	"watts"		},	// Power
	{	"",			""			},	// Text
};




- (NSString*)getLegend
{
	BOOL useStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	return [NSString stringWithUTF8String:useStatute ? sLegendInfo[colInfo->unitType].statuteLegend : sLegendInfo[colInfo->unitType].metricLegend];
}




@end


