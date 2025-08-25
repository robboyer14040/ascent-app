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
NSString*  RCBDefaultEquipment			  = @"DefaultEquipmentAsString";
NSString*  RCBDefaultStartingLapNumber	  = @"DefaultStartingLapNumber";
   

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
NSString*  RCBDefaultShowCrosshairs       = @"DefaultShowCrosshairs";
NSString*  RCBDefaultShowADHUD            = @"DefaultShowADHUD";
NSString*  RCBDefaultAnimationFollows     = @"DefaultAnimationFollows";
NSString*  RCBDefaultDataHUDTransparency  = @"DefaultDataHUDTransparency";
NSString*  RCBDefaultStatsHUDTransparency = @"DefaultStatsHUDTransparency";
NSString*  RCBDefaultZoneInADViewItem     = @"DefaultZoneInADViewItem";
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
NSString*  RCBDefaultShowTransportPanel  = @"DefaultShowTransportPanel";
NSString*  RCBDefaultBrowserTabView      = @"DefaultBrowserTabView";       // 0-based int
NSString*  RCBDefaultZoneTypeForStatsHUD = @"DefaultZoneTypeForStatsHUD";
NSString*  RCBDefaultSearchOptions		 = @"DefaultSearchOptions";
NSString*  RCBDefaultSplitIndex			 = @"DefaultSplitIndex";
NSString*  RCBDefaultSplitGraphItem		 = @"DefaultSplitGraphItem";
NSString*  RCBDefaultLastMainDisplay	 = @"DefaultLastMainDisplay";		// 0 = browser, 1 = calendar
NSString*  RCBDefaultCustomSplitDistance = @"DefaultCustomSplitDistance";

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
   
   [equipmentPopup removeAllItems];
   [Utils buildPopupMenuFromItems:RCBDefaultAttrEquipmentList 
                            popup:equipmentPopup
                 currentSelection:@""];
}


// work-around from crash when exiting from list editor with a field being edited.  Not sure
// why this fixes things, but changes the order of notifications to avoid the problem.  ugh.
// @@FIXME@@
+(void) doRelease:(id)obj
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


- (IBAction)setValueForSender:(id)sender;
{
	if (sender == defaultMapType)
	{
		int idx = [sender indexOfSelectedItem];
		[defaults setInteger:idx forKey:RCBDefaultMapType];
	} 
	else if (sender == doubleClickActionPopup)
	{
		[defaults setInteger:[sender indexOfSelectedItem] forKey:RCBDefaultDoubleClickAction];
	}
	else if (sender == unitsMatrix)
	{
		BOOL useEnglish = [[sender selectedCell] tag] == 0;
		[defaults setBool:useEnglish forKey:RCBDefaultUnitsAreEnglishKey];
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
   [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


- (void)valuesHaveChanged
{
   [super valuesHaveChanged];
}


#define CLIP(min,val,max)        (((val < min) ? min : (val > max) ? max : val))


-(void)updateUI
{
	[customFieldLabel setStringValue:[defaults stringForKey:RCBDefaultCustomFieldLabel]];
	[keyword1Label setStringValue:[defaults stringForKey:RCBDefaultKeyword1Label]];
	[keyword2Label setStringValue:[defaults stringForKey:RCBDefaultKeyword2Label]];
	[defaultMapType         selectItemAtIndex:[defaults integerForKey:RCBDefaultMapType]];
	[defaultXAxisType       selectItemAtIndex:([defaults integerForKey:RCBDefaultXAxisType] > 0 ? 1 : 0)];
	[doubleClickActionPopup selectItemAtIndex:[defaults integerForKey:RCBDefaultDoubleClickAction]];
	[timeFormatPopup        selectItemAtIndex:[defaults integerForKey:RCBDefaultTimeFormat]];
	[dateFormatPopup        selectItemAtIndex:[defaults integerForKey:RCBDefaultDateFormat]];
	int dayOfWeek = [defaults integerForKey:RCBDefaultWeekStartDay];
	dayOfWeek = CLIP(0, dayOfWeek, 1);     // clip to [0,1] for now (sunday or monday)
	[weekStartPopup         selectItemAtIndex:dayOfWeek];
	BOOL useEnglish = [defaults boolForKey:RCBDefaultUnitsAreEnglishKey];
	if (useEnglish)
	{
		[unitsMatrix setState:NSOnState atRow:0 column:0];
	} 
	else
	{
	  [unitsMatrix setState:NSOnState atRow:1 column:0];
	}		
	[activityPopup selectItemWithTitle:[defaults stringForKey:RCBDefaultActivity]];
	[equipmentPopup selectItemWithTitle:[defaults stringForKey:RCBDefaultEquipment]];
	[startingLapNumberPopup selectItemAtIndex:[defaults integerForKey:RCBDefaultStartingLapNumber]];
}

@end
