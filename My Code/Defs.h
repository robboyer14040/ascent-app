/*
 *  Defs.h
 *  TLP
 *
 *  Created by Rob Boyer on 9/9/06.
 *  Copyright 2006 rcb Construction. All rights reserved.
 *
 */
#define DEBUG_LEAKS				ASCENT_DBG&&0
#define TEST_LOCALIZATION		ASCENT_DBG&&0

#define ASCENT_DOCUMENT_EXTENSION	@"tlp"

#define USE_KEYED_ENCODING       0
#define USE_KEYED_DECODING       0

#define ACTIVITY_VIEW_TOP_AREA_HEIGHT       160

#define kMinPossibleSpeed			0.0
#define kMaxPossibleSpeed			70.0
#define kMinPossibleAltitude		-10000.0
#define kMaxPossibleAltitude		20000.0
#define kMinPossibleHeartRate		0
#define kMaxPossibleHeartRate		300
#define kMinPossibleDistance		0.0
#define kMaxPossibleDistance		2000.0
#define kMinPossibleCadence			-60
#define kMaxPossibleCadence			300
#define kMinPossibleLongitude		-180.0
#define kMaxPossibleLongitude		+180.0
#define kMinPossibleLatitude		-90.0
#define kMaxPossibleLatitude		+90.0
// max reasonable power, in watts
#define MAX_REASONABLE_POWER		2400

#define IS_BETWEEN(min,x,max)		(((min) <= (x)) && ((x) <= (max)))
#define FLAG_IS_SET(flags, val)		(((flags & val) != 0))
#define SET_FLAG(flags, val)		((flags |= val))
#define CLEAR_FLAG(flags, val)		((flags &= ~val))
#define CLIP(min,val,max)			(((val < min) ? min : (val > max) ? max : val))

#define PROGRAM_NAME				@"Ascent"
#define kNumUnregisteredTracks		10
#define kNumHRZones					5

#define kCycling           "Cycling"
#define kRunning           "Running"
#define kHiking            "Hiking"
#define kSkiing            "Skiing"
#define kSnowboarding      "Snowboarding"
#define kPaddling          "Paddling"
#define kWalking           "Walking"
#define kDriving           "Driving"
#define kTraining          "Training"
#define kCommute           "Commute"
#define kRace              "Race"
#define kEndurance         "Endurance"
#define kSunny             "Sunny"
#define kSunnyHot          "Sunny, Hot"
#define kSunnyHotHumid     "Sunny, Hot, Humid"
#define kSunnyCold         "Sunny, Cold"
#define kOvercast          "Overcast"
#define kOvercastHot       "Overcast, Hot"
#define kOvercastHotHumid  "Overcast, Hot, Humid"
#define kRain              "Rain"
#define kRainCold          "Rain, Cold"
#define kSnow              "Snow"
#define kWind              "Wind"
#define kIndoor            "Indoor"
#define kOK                "OK"
#define kEnergized         "Energized"
#define kTired             "Tired"
#define kEasy              "Easy"
#define kMedium            "Medium"
#define kDifficult         "Difficult"
#define kEpic              "Epic"
#define kRoadBike          "Road Bike"
#define kMountainBike      "Mountain Bike"
#define kNoEqupiment       "None"

// tags for browser columns, also set in interface builder, so make sure you change them in BOTH places
// ALSO must be the same as names of accessors in TrackBrowserItem class
#define kCT_Name			"name"
#define kCT_Title			"title"
#define kCT_Distance		"distance"
#define kCT_Duration		"durationAsFloat"
#define kCT_ActivityTime	"movingDurationAsFloat"
#define kCT_AvgSpeed		"avgSpeed"
#define kCT_MaxSpeed		"maxSpeed"
#define kCT_MovSpeed		"avgMovingSpeed"
#define kCT_Climb			"totalClimb"
#define kCT_Descent			"totalDescent"
#define kCT_RateOfClimb		"rateOfClimb"
#define kCT_RateOfDescent	"rateOfDescent"
#define kCT_Keyword1		"keyword1"
#define kCT_Keyword2		"keyword2"
#define kCT_Custom			"custom"
#define kCT_MaxHR			"maxHeartRate"
#define kCT_AvgHR			"avgHeartRate"
#define kCT_MaxAlt			"maxAltitude"
#define kCT_MinAlt			"minAltitude"
#define kCT_AvgAlt			"avgAltitude"
#define kCT_MaxCadence		"maxCadence"
#define kCT_AvgCadence		"avgCadence"
#define kCT_MaxGradient		"maxGradient"
#define kCT_MinGradient		"minGradient"
#define kCT_AvgGradient		"avgGradient"
#define kCT_TimeInHRZ1		"timeInHRZ1AsFloat"
#define kCT_TimeInHRZ2		"timeInHRZ2AsFloat"
#define kCT_TimeInHRZ3		"timeInHRZ3AsFloat"
#define kCT_TimeInHRZ4		"timeInHRZ4AsFloat"
#define kCT_TimeInHRZ5		"timeInHRZ5AsFloat"
#define kCT_TimeInALTZ1		"timeInALTZ1AsFloat"
#define kCT_TimeInALTZ2		"timeInALTZ2AsFloat"
#define kCT_TimeInALTZ3		"timeInALTZ3AsFloat"
#define kCT_TimeInALTZ4		"timeInALTZ4AsFloat"
#define kCT_TimeInALTZ5		"timeInALTZ5AsFloat"
#define kCT_TimeInCDZ1		"timeInCDZ1AsFloat"
#define kCT_TimeInCDZ2		"timeInCDZ2AsFloat"
#define kCT_TimeInCDZ3		"timeInCDZ3AsFloat"
#define kCT_TimeInCDZ4		"timeInCDZ4AsFloat"
#define kCT_TimeInCDZ5		"timeInCDZ5AsFloat"
#define kCT_TimeInGDZ1		"timeInGDZ1AsFloat"
#define kCT_TimeInGDZ2		"timeInGDZ2AsFloat"
#define kCT_TimeInGDZ3		"timeInGDZ3AsFloat"
#define kCT_TimeInGDZ4		"timeInGDZ4AsFloat"
#define kCT_TimeInGDZ5		"timeInGDZ5AsFloat"
#define kCT_TimeInPCZ1		"timeInPCZ1AsFloat"
#define kCT_TimeInPCZ2		"timeInPCZ2AsFloat"
#define kCT_TimeInPCZ3		"timeInPCZ3AsFloat"
#define kCT_TimeInPCZ4		"timeInPCZ4AsFloat"
#define kCT_TimeInPCZ5		"timeInPCZ5AsFloat"
#define kCT_TimeInSPZ1		"timeInSPZ1AsFloat"
#define kCT_TimeInSPZ2		"timeInSPZ2AsFloat"
#define kCT_TimeInSPZ3		"timeInSPZ3AsFloat"
#define kCT_TimeInSPZ4		"timeInSPZ4AsFloat"
#define kCT_TimeInSPZ5		"timeInSPZ5AsFloat"
#define kCT_Activity		"activity"
#define kCT_Equipment		"equipment"
#define kCT_Weight			"weight"
#define kCT_Disposition		"disposition"
#define kCT_EventType		"eventType"
#define kCT_Effort			"effort"
#define kCT_AvgPace			"avgPace"
#define kCT_AvgMovingPace	"avgMovingPace"
#define kCT_Calories		"calories"
#define kCT_MaxPower		"maxPower"
#define kCT_AvgPower		"avgPower"
#define kCT_Notes			"notes"
#define kCT_Weather			"weather"
#define kCT_Work			"work"
#define kCT_Device			"device"
#define kCT_FirmWareVersion	"firmwareVersion"
#define kCT_AvgTemperature	"avgTemperature"
#define kCT_MaxTemperature  "maxTemperature"
#define kCT_MinTemperature	"minTemperature"

enum tColMenuTags
{
	kMT_DateTime,
	kMT_Title,
	kMT_Distance,
	kMT_TotalDuration,
	kMT_MovingDuration,
	kMT_AvgSpeed,
	kMT_MaxSpeed,
	kMT_AvgMovingSpeed,
	kMT_Climb,
	kMT_Descent,
	kMT_AvgGradient,
	kMT_MaxGradient,
	kMT_MinGradient,
	kMT_Keyword1,
	kMT_Keyword2,
	kMT_MaxHR,
	kMT_AvgHR,
	kMT_MaxCadence,
	kMT_AvgPower,
	kMT_MaxPower,
	kMT_AvgCadence,
	kMT_TimeInHRZ1,
	kMT_TimeInHRZ2,
	kMT_TimeInHRZ3,
	kMT_TimeInHRZ4,
	kMT_Activity,
	kMT_Equipment,
	kMT_Weight,
	kMT_Disposition,
	kMT_Effort,
	kMT_AvgPace,
	kMT_AvgMovingPace,
	kMT_Calories,
	kMT_Notes,
	kMT_EventType,
	kMT_Weather,
	kMT_TimeInHRZ5,
	kMT_TimeInCDZ1,
	kMT_TimeInCDZ2,
	kMT_TimeInCDZ3,
	kMT_TimeInCDZ4,
	kMT_TimeInCDZ5,
	kMT_TimeInGDZ1,
	kMT_TimeInGDZ2,
	kMT_TimeInGDZ3,
	kMT_TimeInGDZ4,
	kMT_TimeInGDZ5,
	kMT_TimeInPCZ1,
	kMT_TimeInPCZ2,
	kMT_TimeInPCZ3,
	kMT_TimeInPCZ4,
	kMT_TimeInPCZ5,
	kMT_TimeInSPZ1,
	kMT_TimeInSPZ2,
	kMT_TimeInSPZ3,
	kMT_TimeInSPZ4,
	kMT_TimeInSPZ5,
	kMT_Custom,
	kMT_RateOfClimb,
	kMT_RateOfDescent,
	kMT_MaxAlt,
	kMT_MinAlt,
	kMT_AvgAlt,
	kMT_TimeInALTZ1,
	kMT_TimeInALTZ2,
	kMT_TimeInALTZ3,
	kMT_TimeInALTZ4,
	kMT_TimeInALTZ5,
	kMT_Work,
	kMT_Device,
	kMT_FirmwareVersion,
	kMT_AvgTemperature,
	kMT_MaxTemperature,
	kMT_MinTemperature,
	// add new tags here!
	kMT_Last,
};



// don't change these enums -- there are controls defined in Interface Builder
// that use them as tags.  Add new types to the END.
typedef enum 
{
	kFirstPlotType,
	kReserved = kFirstPlotType,       
	kHeartrate,         // 1
	kCadence,           // 2
	kSpeed,             // 3
	kGradient,          // 4
	kTemperature,       // 5
	kAvgHeartrate,      // 6
	kAvgCadence,        // 7
	kAvgSpeed,          // 8
	kAvgGradient,       // 9
	kAvgTemperature,    // 10
	kBackground,        // 11
	kAltitude,          // 12
	kPath,              // 13
	kDuration,          // 14
	kDistance,          // 15
	kLap,               // 16
	kWeightPlot,        // 17
	kAvgMovingSpeed,    // 18
	kMovingDuration,    // 19
	kAvgPace,			// 20
	kAvgMovingPace,		// 21
	kCalories,          // 22
	kPower,				// 23
	kAvgPower,			// 24
	kPace,				// 25
	// ADD NEW TYPES HERE
	kNumPlotTypes,
} tPlotType;


// browser view types
enum 
{
    kViewTypeBad = -1,
    kViewTypeCurrent = 0,
    kViewTypeActvities,
    kViewTypeWeeks,
    kViewTypeMonths,
    kViewTypeYears,
    kNumViewTypes
};



typedef enum
{
   kBrowserYearText =    1000,
   kBrowserMonthText,            // 1001
   kBrowserWeekText,             // 1002
   kBrowserActivityText,         // 1003
   kBrowserLapText               // 1004
} tBrowserTextColor;


enum
{
	kSplitColorTag = 2000		// for use in IB
};

enum tAttribute
{
	kBadAttr		= -1,
	kName = 0,	
	kActivity,
	kDisposition,
	kEffort,
	kEventType,
	kWeather,		// 5
	kEquipment,
	kWeight,
	kNotes,
	kKeyword1,
	kKeyword2,		// 10
	kKeyword3,				
	kCustom1 = kKeyword3,
	kKeyword4,
	kNumAttributes
};


enum tMapTypes
{
   kTerraServerUSGSAerial,
   kTerraServerUSGSTopo,
   kTerraServerUSGSUrban,
   kNumMapTypes
};


enum tDoubleClickActionsInBrowser
{
   kOpenActivityDetail,
   kOpenMapDetail,
   kOpenDataDetail,
   kNumDoubleClickActionsInBrowser
};


enum tPathColorTypes
{
	kUseHRZColorsForPath,
	kUseSpeedZonesForPath,
	kUsePaceZonesForPath,
	kUseGradientZonesForPath,
	kUseCadenceZonesForPath,
	kUseAltitudeZonesForPath,
	kUsePowerZonesForPath,
	kUseDefaultPathColor,
	kUseBackgroundColor,
};



enum tPeakDataType
{
	kPDT_Power,
	// add more peak data types here
	kPDT_Count
};

// must correspond to order of items in "Zone Type" pref pane popup menu
enum
{
	kSpeedDefaults,
	kPaceDefaults,
	kGradientDefaults,
	kCadenceDefaults,
	kAltitudeDefaults,
	kPowerDefaults,
	kMaxZoneType = kPowerDefaults
};

enum
{
   kNumNonHRZones       = 5
};


@class NSString;
@class NSColor;


// keys for general prefs
extern NSString*  RCBDefaultUnitsAreEnglishKey;
extern NSString*  RCBDefaultUseCentigrade;
extern NSString*  RCBDefaultMapType;
extern NSString*  RCBDefaultDoubleClickAction;
extern NSString*  RCBDefaultXAxisType;
extern NSString*  RCBDefaultDisplayPace;
extern NSString*  RCBDefaultTimeFormat;
extern NSString*  RCBDefaultDateFormat;
extern NSString*  RCBDefaultWeekStartDay;
extern NSString*  RCBDefaultCustomFieldLabel;
extern NSString*  RCBDefaultKeyword1Label;
extern NSString*  RCBDefaultKeyword2Label;
extern NSString*  RCBDefaultStartingLapNumber;

// keys for appearance prefs
extern NSString*  RCBDefaultAltitudeColor;
extern NSString*  RCBDefaultSpeedColor;
extern NSString*  RCBDefaultMovingSpeedColor;
extern NSString*  RCBDefaultPaceColor;
extern NSString*  RCBDefaultMovingPaceColor;
extern NSString*  RCBDefaultHeartrateColor;
extern NSString*  RCBDefaultCadenceColor;
extern NSString*  RCBDefaultPowerColor;
extern NSString*  RCBDefaultGradientColor;
extern NSString*  RCBDefaultTemperatureColor;
extern NSString*  RCBDefaultPathColor;
extern NSString*  RCBDefaultDistanceColor;
extern NSString*  RCBDefaultLapColor;
extern NSString*  RCBDefaultWeightColor;
extern NSString*  RCBDefaultBackgroundColor;
extern NSString*  RCBDefaultDurationColor;
extern NSString*  RCBDefaultMovingDurationColor;
extern NSString*  RCBDefaultCaloriesColor;
extern NSString*  RCBDefaultMapTransparency;
extern NSString*  RCBDefaultPathTransparency;
extern NSString*  RCBDefaultAnimPanelTransparency;
extern NSString*  RCBDefaultMarkersPanelTransparency;
extern NSString*  RCBDefaultSplitColor;
extern NSString*  RCBDefaultCustomSplitDistance;

// keys for browser prefs
extern NSString*  RCBDefaultBrowserYearColor;
extern NSString*  RCBDefaultBrowserMonthColor;
extern NSString*  RCBDefaultBrowserWeekColor;
extern NSString*  RCBDefaultBrowserActivityColor;
extern NSString*  RCBDefaultBrowserLapColor;

// keys for heartrate prefs
extern NSString*  RCBDefaultAge;
extern NSString*  RCBDefaultHRZoneMethod;
extern NSString*  RCBDefaultRestingHeartrate;
extern NSString*  RCBDefaultMaxHeartrate;
extern NSString*  RCBDefaultZone1Threshold;
extern NSString*  RCBDefaultZone2Threshold;
extern NSString*  RCBDefaultZone3Threshold;
extern NSString*  RCBDefaultZone4Threshold;
extern NSString*  RCBDefaultZone5Threshold;
extern NSString*  RCBDefaultZone1Color;
extern NSString*  RCBDefaultZone2Color;
extern NSString*  RCBDefaultZone3Color;
extern NSString*  RCBDefaultZone4Color;
extern NSString*  RCBDefaultZone5Color;
extern NSString*  RCBDefaultBelowZoneColor;

// keys for user prefs
extern NSString*  RCBDefaultGender;
extern NSString*  RCBDefaultVO2Max;
extern NSString*  RCBDefaultWeight;
extern NSString*  RCBDefaultHeight;
extern NSString*  RCBDefaultBirthday;
extern NSString*  RCBDefaultActivity;
extern NSString*  RCBDefaultEventType;
extern NSString*  RCBDefaultEquipment;

// keys for advanced prefs
extern NSString*  RCBDefaultMapCacheEnabled;
extern NSString*  RCBDefaultAnimFrameRate;
extern NSString*  RCBDefaultMinSpeed;
extern NSString*  RCBDefaultMinDistance;
extern NSString*  RCBDefaultAltitudeFilter;
extern NSString*  RCBDefaultAutoSplitEnabled;
extern NSString*  RCBDefaultAutoSplitMinutes;
extern NSString*  RCBCheckForUpdateAtStartup;
extern NSString*  RCBDefaultUseDistanceDataEnabled;
extern NSString*  RCBDefaultAltitudeSmoothingPercentage;
extern NSString*  RCBDefaultMaxAltitude;
extern NSString*  RCBDefaultCalculatePowerIfAbsent;
extern NSString*  RCBDefaultCalculatePowerActivities;

//keys for zones prefs
extern NSString*  RCBDefaultZoneType;
extern NSString*  RCBDefaultSpeedZones;
extern NSString*  RCBDefaultPaceZones;
extern NSString*  RCBDefaultGradientZones;
extern NSString*  RCBDefaultCadenceZones;
extern NSString*  RCBDefaultPowerZones;
extern NSString*  RCBDefaultAltitudeZones;

// keys for "Sharing" prefs
extern NSString*  RCBDefaultSharingAccountName;
extern NSString*  RCBDefaultSharingAccountPassword;
extern NSString*  RCBDefaultSharingAccountEmail;

// keys for "Backup" prefs
extern NSString*  RCBDefaultDoLocalBackup;
extern NSString*  RCBDefaultDoMobileMeBackup;
extern NSString*  RCBDefaultLocalBackupFrequency;
extern NSString*  RCBDefaultLocalBackupFolder;
extern NSString*  RCBDefaultLocalBackupRetainCount;
extern NSString*  RCBDefaultMobileMeBackupFrequency;

// keys for "Sync" prefs
extern NSString*  RCBDefaultEnableWiFiSync;
extern NSString*  RCBDefaultEnableWeeksOrMonthsSync;
extern NSString*  RCBDefaultNumWeeksOrMonthsToSync;
extern NSString*  RCBDefaultWeeksOrMonthsSync;
extern NSString*  RCBDefaultGarminUSBSync;
extern NSString*  RCBDefaultGarminANTSync;
extern NSString*  RCBDefaultGarminMassStorageSync;

// keys for prefs not settable in prefs dialogs
extern NSString*  RCBDefaultNumPointsToAverage;
extern NSString*  RCBDefaultBrowserSortInReverse;
extern NSString*  RCBDefaultSumPlotTypesEnabled;
extern NSString*  RCBDefaultBrowserViewType;
extern NSString*  RCBDefaultFillAltitudePlot;
extern NSString*  RCBDefaultShowLaps;
extern NSString*  RCBDefaultShowPeaks;
extern NSString*  RCBDefaultNumPeaks;
extern NSString*  RCBDefaultPeakThreshold;
extern NSString*  RCBDefaultPeakItem;
extern NSString*  RCBDefaultShowHRZones;
extern NSString*  RCBDefaultShowMarkers;
extern NSString*  RCBDefaultShowPowerPeakIntervals;
extern NSString*  RCBDefaultPowerPeakIntervals;
extern NSString*  RCBDefaultShowCrosshairs;
extern NSString*  RCBDefaultShowADHUD;
extern NSString*  RCBDefaultDataHUDTransparency;
extern NSString*  RCBDefaultStatsHUDTransparency;
extern NSString*  RCBDefaultAnimationFollows;
extern NSString*  RCBDefaultShowMDHUD;
extern NSString*  RCBDefaultMDHUDTransparency;
extern NSString*  RCBDefaultMDShowLaps;
extern NSString*  RCBDefaultMDShowPath;
extern NSString*  RCBDefaultMDPathTransparency;
extern NSString*  RCBDefaultMDMapTransparency;
extern NSString*  RCBDefaultShowTransportPanel;
extern NSString*  RCBDefaultBrowserTabView;
extern NSString*  RCBDefaultColorPathUsingZone;
extern NSString*  RCBDefaultZoneTypeForStatsHUD;
extern NSString*  RCBDefaultZoneInADViewItem;
extern NSString*  RCBDefaultZonesTransparency;
extern NSString* RCBDefaultAttrActivityList;
extern NSString* RCBDefaultAttrEquipmentList;
extern NSString* RCBDefaultAttrDispositionList;
extern NSString* RCBDefaultAttrWeatherList;
extern NSString* RCBDefaultAttrEventTypeList;
extern NSString* RCBDefaultAttrEffortList;
extern NSString* RCBDefaultAttrKeyword1List;
extern NSString* RCBDefaultAttrKeyword2List;
extern NSString* RCBDefaultSearchOptions;
extern NSString* RCBDefaultSplitIndex;
extern NSString* RCBDefaultSplitGraphItem;
extern NSString* RCBDefaultLastMainDisplay;
extern NSString* RCBDefaultSummaryGraphStyle;
extern NSString* RCBDefaultSummaryGraphGranularity;	// 0=weeks, 1=months, etc
extern NSString* RCBDefaultDataFilterLastTopItemKey;		
extern NSString* RCBDefaultDataFilterDict;
extern NSString* RCBDefaultDataDetailShowsPace;
extern NSString* RCBDefaultSplitMethod;
extern NSString* RCBDefaultShowBackupNagDialog;
extern NSString* RCBDefaultShowIntervalMarkers;
extern NSString* RCBDefaultIntervalMarkerIncrement;
extern NSString* RCBDefaultScrollWheelSensitivty;
// Compare Window
extern NSString* RCBDefaultCompareWindowXAxisType;
extern NSString* RCBDefaultCompareWindowPlotType;
extern NSString* RCBDefaultCompareWindowDontShowHelp;




// other global strings
extern NSString* TerraServerTopoMap;
extern NSString* TerraServerAerialMap;
extern NSString* TerraServerUrbanMap;


// pasteboard types
extern NSString* TrackPBoardType;
extern NSString* ActivityDragType;


#define RegistrationInfoDictionaryKey     @"AscentInternal"
#define RegNameKey                     @"145"
#define RegEmailKey                    @"52"
#define RegCodeKey                     @"76"
#define RegDummyKey1                   @"53"
#define RegDummyKey2                   @"966"
#define RegDummyKey3                   @"71"
#define RegDummyKey4                   @"812"
#define RegDummyKey5                   @"36"
#define RegDummyKey6                   @"11"

// exceptions
#define ExFutureVersionName				@"FutureVersion"
#define ExFutureVersionReason			@"This activity document was created with a future version of Ascent and is not compatible with the current version of the program.  In order to succesfully open this document, please download the most recent version."

// device IDs returned from Garmin GPS units
#define kGarminEdgeDeviceID			405
#define kGarminForerunnerDeviceID	484

// default equipment weight used for power calcs, in pounds
#define kDefaultEquipmentWeight		25.0

#define MAX_MARKER_INCREMENT		(25.0)

// 310XT requires special handling
#define PROD_ID_310XT   1018
#define PROD_ID_FR60    988
