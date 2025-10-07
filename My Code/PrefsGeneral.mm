//
//  PrefsGeneral.mm
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsGeneral.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "Utils.h"
#import "ListEditorController.h"

NSString*  RCBDefaultUnitsAreEnglishKey   = @"DefaultUnitsAreEnglish";
NSString*  RCBDefaultUseCentigrade		  = @"DefaultUseCentigrade";
NSString*  RCBDefaultMapType              = @"DefaultMapType";
NSString*  RCBDefaultDoubleClickAction    = @"DefaultDoubleClickAction";
NSString*  RCBDefaultXAxisType            = @"DefaultXAxisType";
NSString*  RCBDefaultBrowserSortInReverse = @"DefaultBrowserSortInReverse";
NSString*  RCBDefaultDisplayPace          = @"DefaultDisplayPace";
NSString*  RCBDefaultTimeFormat           = @"DefaultTimeFormat";
NSString*  RCBDefaultDateFormat           = @"DefaultDateFormat";
NSString*  RCBDefaultWeekStartDay         = @"DefaultWeekStartDay";        // 0 = sunday, 1 = monday

NSString*  RCBDefaultSumPlotTypesEnabled  = @"DefaultSumPlotTypesEnabled";
NSString*  RCBDefaultBrowserViewType      = @"DefaultBrowserViewType";

NSString*  RCBDefaultCustomFieldLabel     = @"DefaultCustomFieldLabel";
NSString*  RCBDefaultKeyword1Label        = @"DefaultKeyword1Label";
NSString*  RCBDefaultKeyword2Label        = @"DefaultKeyword2Label";
NSString*  RCBDefaultActivity			  = @"DefaultActivityAsString";  
NSString*  RCBDefaultEventType			  = @"DefaultEventType";  
NSString*  RCBDefaultEquipment			  = @"DefaultEquipmentAsString";
NSString*  RCBDefaultStartingLapNumber	  = @"DefaultStartingLapNumber";
   
NSString*  RCBDefaultScrollWheelSensitivty	= @"DefaultScrollWheelSensitivity";

// defaults in the activity detail view
NSString*  RCBDefaultNumPointsToAverage   = @"DefaultNumPointsToAverage";  
NSString*  RCBDefaultFillAltitudePlot     = @"DefaultFillAltitudePlot";
NSString*  RCBDefaultShowLaps             = @"DefaultShowLaps";
NSString*  RCBDefaultShowPeaks            = @"DefaultShowPeaks";
NSString*  RCBDefaultNumPeaks             = @"DefaultNumPeaks";
NSString*  RCBDefaultPeakThreshold        = @"DefaultPeakThreshold";
NSString*  RCBDefaultPeakItem             = @"DefaultPeakItem";
NSString*  RCBDefaultShowHRZones          = @"DefaultShowHRZones";
NSString*  RCBDefaultShowMarkers          = @"DefaultShowMarkers";
NSString*  RCBDefaultShowPowerPeakIntervals  = @"DefaultShowPowerPeakIntervals";
NSString*  RCBDefaultPowerPeakIntervals   = @"DefaultPowerPeakIntervals";
NSString*  RCBDefaultShowCrosshairs       = @"DefaultShowCrosshairs";
NSString*  RCBDefaultShowADHUD            = @"DefaultShowADHUD";
NSString*  RCBDefaultAnimationFollows     = @"DefaultAnimationFollows";
NSString*  RCBDefaultDataHUDTransparency  = @"DefaultDataHUDTransparency";
NSString*  RCBDefaultStatsHUDTransparency = @"DefaultStatsHUDTransparency";
NSString*  RCBDefaultZoneInActivityDetailViewItem     = @"DefaultZoneInActivityDetailViewItem";
NSString*  RCBDefaultZonesTransparency    = @"DefaultZonesTransparency"; 

// defaults in the map detail view
NSString*  RCBDefaultShowMDHUD            = @"DefaultShowMDHUD";
NSString*  RCBDefaultMDHUDTransparency    = @"DefaultMDHUDTransparency";
NSString*  RCBDefaultMDShowLaps           = @"DefaultMDShowLaps";
NSString*  RCBDefaultMDShowPath           = @"DefaultMDShowPath";
NSString*  RCBDefaultMDPathTransparency   = @"DefaultMDPathTransparency";
NSString*  RCBDefaultMDMapTransparency    = @"DefaultMDMapTransparency";
NSString*  RCBDefaultColorPathUsingZone   = @"DefaultColorPathUsingZone";

// defaults in the data detail view
NSString*  RCBDefaultDataDetailShowsPace  = @"DefaultDataDetailShowsPace";
NSString*  RCBDefaultDataFilterLastTopItemKey = @"DefaultDataFilterLastTopItemKey";		
NSString*  RCBDefaultDataFilterDict		  = @"DefaultDataFilterDict";

// defaults in the summary graph view
NSString* RCBDefaultSummaryGraphStyle		= @"DefaultSummaryGraphStyle";
NSString* RCBDefaultSummaryGraphGranularity	= @"DefaultSummaryGraphGranularity";		// 0=weeks, 1=months, etc

// other defaults;
NSString*	RCBDefaultShowTransportPanel	= @"DefaultShowTransportPanel";
NSString*	RCBDefaultBrowserTabView		= @"DefaultBrowserTabView";       // 0-based int
NSString*	RCBDefaultZoneTypeForStatsHUD	= @"DefaultZoneTypeForStatsHUD";
NSString*	RCBDefaultSearchOptions			= @"DefaultSearchOptions";
NSString*	RCBDefaultSplitIndex			= @"DefaultSplitIndex";
NSString*	RCBDefaultSplitGraphItem		= @"DefaultSplitGraphItem";
NSString*   RCBDefaultSplitVariant          = @"RCBDefaultSplitVariant";
NSString*	RCBDefaultLastMainDisplay		= @"DefaultLastMainDisplay";		// 0 = browser, 1 = calendar
NSString*	RCBDefaultCustomSplitDistance	= @"DefaultCustomSplitDistance";
NSString*	RCBDefaultShowIntervalMarkers	= @"DefaultShowIntervalMarkers";
NSString*	RCBDefaultIntervalMarkerIncrement		= @"DefaultIntervalMarkerIncrement";

// attribute defaults -- these resolve to arrays of strings
NSString* RCBDefaultAttrActivityList      = @"DefaultAttrActivityList";
NSString* RCBDefaultAttrEquipmentList     = @"DefaultAttrEquipmentList";
NSString* RCBDefaultAttrDispositionList   = @"DefaultAttrDispositionList";
NSString* RCBDefaultAttrWeatherList       = @"DefaultAttrWeatherList";
NSString* RCBDefaultAttrEventTypeList     = @"DefaultAttrEventTypeList";
NSString* RCBDefaultAttrEffortList        = @"DefaultAttrEffortList";
NSString* RCBDefaultAttrKeyword1List      = @"DefaultAttrKeyword1List";
NSString* RCBDefaultAttrKeyword2List      = @"DefaultAttrKeyword2List";


NSString* TerraServerTopoMap     = @"USGS Topo";
NSString* TerraServerAerialMap   = @"USGS Aerial";
NSString* TerraServerUrbanMap    = @"USGS Urban";

@implementation PrefsGeneral


-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	[defaultMapType removeAllItems];
	[Utils buildDataTypePopup:defaultMapType isPullDown:NO];

	[doubleClickActionPopup removeAllItems];
	[doubleClickActionPopup addItemWithTitle:@"Open Activity Detail"];
	[doubleClickActionPopup addItemWithTitle:@"Open Map Detail"];
	[doubleClickActionPopup addItemWithTitle:@"Open Data Detail"];

	[activityPopup removeAllItems];
	[Utils buildPopupMenuFromItems:RCBDefaultAttrActivityList 
							popup:activityPopup
				 currentSelection:@""];

	[defaultEventTypePopup removeAllItems];
	[Utils buildPopupMenuFromItems:RCBDefaultAttrEventTypeList 
							 popup:defaultEventTypePopup
				  currentSelection:@""];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChanged
											   object:nil];
}


// work-around from crash when exiting from list editor with a field being edited.  Not sure
// why this fixes things, but changes the order of notifications to avoid the problem.  ugh.
// @@FIXME@@
-(void) doRelease:(id)obj
{
	[obj release];
}



- (int) editAttributeList:(id)popup
              attributeID:(int)attrID
{
	int ret = -1;
	NSString* attrKey =[Utils attrIDToDefaultsKey:attrID];
	ListEditorController* lec = [[ListEditorController alloc] initWithStringArray:[Utils attributeArray:attrKey]
																			 name:[Utils attributeName:attrID]];
	NSWindowController* wc = [[[self controlBox] window] windowController];
	NSRect lfr = [[lec window] frame];
	NSRect fr = [[equipmentPopup window] frame];
	NSPoint origin;
	origin.x = fr.origin.x + fr.size.width/2.0 - lfr.size.width/2.0;
	origin.y = fr.origin.y + fr.size.height/2.0 - lfr.size.height/2.0;  
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
	[self performSelectorOnMainThread:@selector(doRelease:)
						   withObject:lec
						waitUntilDone:NO];
	//[lec autorelease];
	return ret;
}


- (void) setAttributeDefaultPopup:(id)sender attrID:(int)attrID defaultsKey:(NSString*)defKey
{
    /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
     OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	BOOL changed = NO;
	if ([sender indexOfSelectedItem] >= [sender numberOfItems]-1)
	{
		NSString* prevSel = [defaults stringForKey:defKey];
		int sts = [self editAttributeList:sender
							  attributeID:attrID];
		changed = (sts == 0);
		if (changed)
		{
			[Utils buildPopupMenuFromItems:[Utils attrIDToDefaultsKey:attrID]
									 popup:sender 
						  currentSelection:prevSel];
		}
		[sender selectItemWithTitle:prevSel]; 
	}
	else
	{
		[defaults setObject:[sender titleOfSelectedItem] forKey:defKey];
	}
}

#define MAX_SENS		20.0
#define MIN_SENS		0.1
- (IBAction)setScrollingSensitivity:(id)sender;
{
    /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
     OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	float v = [sender floatValue];
	v = MAX_SENS - (v * ((MAX_SENS-MIN_SENS)/100.0));
	[Utils setFloatDefault:v
					forKey:RCBDefaultScrollWheelSensitivty];
	[[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChanged object:self];
	[defaults synchronize];
}


- (IBAction)setShowIntervalMarkers:(id)sender
{
	int state = [sender state];
	BOOL on = (state == NSControlStateValueOn) ? YES : NO;
	[Utils setBoolDefault:on 
				   forKey:RCBDefaultShowIntervalMarkers];
	[intervalIncrementTextField setEnabled:on];
	[intervalIncrementStepper setEnabled:on];
	[intervalIncrementUnitsLabel setEnabled:on];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChanged object:self];
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[defaults synchronize];
}


- (IBAction)setIntervalIncrement:(id)sender
{
	float v = 0.0;
	v = [sender floatValue];
	v = CLIP(1.0, v, MAX_MARKER_INCREMENT);
	[intervalIncrementStepper setFloatValue:v];
	[intervalIncrementTextField setFloatValue:v];
	[Utils setFloatDefault:v
					forKey:RCBDefaultIntervalMarkerIncrement];
	[[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChanged object:nil];
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[defaults synchronize];
}



- (IBAction)setValueForSender:(id)sender;
{
   /// NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
    OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
	if (sender == defaultMapType)
	{
		NSInteger idx = [sender indexOfSelectedItem];
		[defaults setInteger:idx forKey:RCBDefaultMapType];
	} 
	else if (sender == doubleClickActionPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultDoubleClickAction];
	}
	else if (sender == unitsPopup)
	{
		BOOL useEnglish = [sender indexOfSelectedItem] == 0;
		[intervalIncrementUnitsLabel setStringValue:useEnglish ? @"mi" : @"km"];
		[defaults setBool:useEnglish forKey:RCBDefaultUnitsAreEnglishKey];
	}
	else if (sender == temperatureUnitsPopup)
	{
		BOOL useCentigrade = [sender indexOfSelectedItem] == 1;
		[defaults setBool:useCentigrade forKey:RCBDefaultUseCentigrade];
	}
	else if (sender == defaultXAxisType)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultXAxisType];
	}
	else if (sender == timeFormatPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultTimeFormat];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildBrowser" object:nil];
	}
	else if (sender == dateFormatPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultDateFormat];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildBrowser" object:nil];
	}
	else if (sender == weekStartPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultWeekStartDay];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildBrowser" object:nil];
	}
	else if (sender == customFieldLabel)
	{
		[defaults setObject:[sender stringValue] forKey:RCBDefaultCustomFieldLabel];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildOutlineView" object:nil];
	}
	else if (sender == keyword1Label)
	{
		[defaults setObject:[sender stringValue] forKey:RCBDefaultKeyword1Label];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildOutlineView" object:nil];
	}
	else if (sender == keyword2Label)
	{
		[defaults setObject:[sender stringValue] forKey:RCBDefaultKeyword2Label];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildOutlineView" object:nil];
	}
	else if (sender == activityPopup)
	{
		[self setAttributeDefaultPopup:sender
								attrID:kActivity
						   defaultsKey:RCBDefaultActivity];
	}
	else if (sender == defaultEventTypePopup)
	{
		[self setAttributeDefaultPopup:sender
								attrID:kEventType
						   defaultsKey:RCBDefaultEventType];
	}
	else if (sender == equipmentPopup)
	{
		[self setAttributeDefaultPopup:sender
								attrID:kEquipment
						   defaultsKey:RCBDefaultEquipment];
	}
	else if (sender == startingLapNumberPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultStartingLapNumber];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"RebuildBrowser" object:nil];
	}
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChanged object:nil];
}


- (void)prefsChanged:(NSNotification *)notification
{
	if ([notification object] != self)
	{
		float v = [Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement];
		[intervalIncrementStepper setFloatValue:v];
		[intervalIncrementTextField setFloatValue:v];
		BOOL on = [Utils boolFromDefaults:RCBDefaultShowIntervalMarkers];
		[showIntervalMarkersButton setState:on ? NSControlStateValueOn : NSControlStateValueOff];
		[intervalIncrementTextField setEnabled:on];
		[intervalIncrementStepper setEnabled:on];
		[intervalIncrementUnitsLabel setEnabled:on];
	}
}

- (void)valuesHaveChanged
{
   [super valuesHaveChanged];
}


#define CLIP(min,val,max)        (((val < min) ? min : (val > max) ? max : val))


-(void)updateUI
{
    ///NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
    OFPreferenceWrapper* defaults = [OFPreferenceWrapper sharedPreferenceWrapper];

    ///NSString* s = [defaults stringForKey:RCBDefaultCustomFieldLabel];
    ///NSString* s1 = [ defaults stringForKey:RCBDefaultMapType];

	[customFieldLabel setStringValue:[defaults stringForKey:RCBDefaultCustomFieldLabel]];
	[keyword1Label setStringValue:[defaults stringForKey:RCBDefaultKeyword1Label]];
	[keyword2Label setStringValue:[defaults stringForKey:RCBDefaultKeyword2Label]];
	[defaultMapType         selectItemAtIndex:[defaults integerForKey:RCBDefaultMapType]];
	[defaultXAxisType       selectItemAtIndex:([defaults integerForKey:RCBDefaultXAxisType] > 0 ? 1 : 0)];
	[doubleClickActionPopup selectItemAtIndex:[defaults integerForKey:RCBDefaultDoubleClickAction]];
	[timeFormatPopup        selectItemAtIndex:[defaults integerForKey:RCBDefaultTimeFormat]];
	[dateFormatPopup        selectItemAtIndex:[defaults integerForKey:RCBDefaultDateFormat]];
	int dayOfWeek = (int)[defaults integerForKey:RCBDefaultWeekStartDay];
	dayOfWeek = CLIP(0, dayOfWeek, 1);     // clip to [0,1] for now (sunday or monday)
	[weekStartPopup         selectItemAtIndex:dayOfWeek];
	BOOL usingStatute = [defaults boolForKey:RCBDefaultUnitsAreEnglishKey];
	[unitsPopup				selectItemAtIndex:usingStatute ? 0 : 1];
	[temperatureUnitsPopup  selectItemAtIndex:[defaults boolForKey:RCBDefaultUseCentigrade] ? 1 : 0];
	[activityPopup selectItemWithTitle:[defaults stringForKey:RCBDefaultActivity]];
	[defaultEventTypePopup selectItemWithTitle:[defaults stringForKey:RCBDefaultEventType]];
	[equipmentPopup selectItemWithTitle:[defaults stringForKey:RCBDefaultEquipment]];
	[startingLapNumberPopup selectItemAtIndex:[defaults integerForKey:RCBDefaultStartingLapNumber]];
	BOOL on = [Utils boolFromDefaults:RCBDefaultShowIntervalMarkers];
	[showIntervalMarkersButton setIntValue:on ? 1 : 0];
	[intervalIncrementTextField setEnabled:on];
	[intervalIncrementStepper setEnabled:on];
	[intervalIncrementUnitsLabel setEnabled:on];
	[intervalIncrementTextField setFloatValue:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	[intervalIncrementStepper setFloatValue:[Utils floatFromDefaults:RCBDefaultIntervalMarkerIncrement]];
	[intervalIncrementUnitsLabel setStringValue:[Utils usingStatute] ? @"mi" : @"km"];
	float v = [Utils floatFromDefaults:RCBDefaultScrollWheelSensitivty];	// [MIN_SENS,MAX_SENS]
	v = 100.0 * (MAX_SENS-v)/(MAX_SENS-MIN_SENS);
	[scrollingSensitivitySlider setFloatValue:v];
}

@end
