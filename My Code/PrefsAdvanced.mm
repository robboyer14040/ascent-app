//
//  PrefsAdvanced.mm
//  Ascent
//
//  Created by Rob Boyer on 11/4/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PrefsAdvanced.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
#import "Utils.h"
#import "Defs.h"

// max alt filter, in feet
#define MAX_ALT_FILTER					25			

NSString*  RCBDefaultCheckForUpdatesAtStartup		= @"DefaultMapCacheEnabled";
NSString*  RCBDefaultCheckForUpdatesFrequency		= @"DefaultMapCacheEnabled";
NSString*  RCBDefaultMapCacheEnabled				= @"DefaultMapCacheEnabled";
NSString*  RCBDefaultAnimFrameRate					= @"DefaultAnimFrameRate";
NSString*  RCBDefaultMinSpeed						= @"DefaultMinSpeed";
NSString*  RCBDefaultMinDistance					= @"DefaultMinDistance";
NSString*  RCBDefaultAltitudeFilter					= @"DefaultAltitudeFilter";
NSString*  RCBDefaultAutoSplitEnabled				= @"DefaultAutoSplitEnabled";
NSString*  RCBDefaultAutoSplitMinutes				= @"DefaultAutoSplitThresholdMinutes";
NSString*  UserDefaultCheckForUpdateFrequency		= @"SUScheduledCheckInterval";
NSString*  RCBCheckForUpdateAtStartup				= @"DefaultCheckForUpdateAtStartup";
NSString*  RCBDefaultUseDistanceDataEnabled			= @"DefaultUseDistanceDataEnabled";
NSString*  RCBDefaultAltitudeSmoothingPercentage	= @"DefaultAltitudeSmoothingPercentage";
NSString*  RCBDefaultMaxAltitude					= @"DefaultMaxAltitude";
NSString*  RCBDefaultCalculatePowerIfAbsent			= @"CalculatePowerIfAbsent";
NSString*  RCBDefaultCalculatePowerActivities		= @"CalculatePowerActivities";



@interface PrefsAdvanced ()
-(void)rebuildPowerActivitiesMenu;
-(void)checkPowerActivitiesMenu;
-(void)togglePowerActivity:(int)idx;
@end

@implementation PrefsAdvanced


- (void)awakeFromNib
{
	[super awakeFromNib];
}


-(void) setUpdateFrequency:(id)sender
{
	BOOL enabled = [checkForUpdatesPeriodicallyButton state];
	int seconds;
	if (enabled)
	{
		NSString* s = [[checkForUpdatesFrequencyPopup selectedItem] title];
		seconds = 60*60*24;
		if ([s compare:@"hourly"] == NSOrderedSame)
		{
			seconds = 60*60;
		}
		else if ([s compare:@"weekly"] == NSOrderedSame)
		{
			seconds *= 7;
		}
		else if ([s compare:@"monthly"] == NSOrderedSame)
		{
			seconds *= 30;
		}
	}
	else
	{
		seconds = 0;
	}
	[[NSUserDefaults standardUserDefaults] setInteger:seconds forKey:UserDefaultCheckForUpdateFrequency];
	[checkForUpdatesFrequencyPopup setEnabled:enabled];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


-(void) altSmoothingSliderDone:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	float v = [sender floatValue];
	[defaults setFloat:v 
				forKey:RCBDefaultAltitudeSmoothingPercentage];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


-(void) altFilterSliderDone:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	float v = [sender floatValue];
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	if (!useStatuteUnits) v = MetersToFeet(v);
	[defaults setFloat:v 
				forKey:RCBDefaultAltitudeFilter];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


-(void) minSpeedSliderDone:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	float v = [sender floatValue];
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	if (!useStatuteUnits) v = KilometersToMiles(v);
	[defaults setFloat:v forKey:RCBDefaultMinSpeed];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


-(void) autoSplitTimeSliderDone:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	float v = [sender floatValue];
	[defaults setFloat:v forKey:RCBDefaultAutoSplitMinutes];
	[defaults synchronize];
	//no need to do this [[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


-(void) defaultMaxAltSliderDone:(id)sender
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	float v = [sender floatValue];
	int cv = v;	
	int d = 100;
	cv = (cv/d) * d;
	if (!useStatuteUnits)
	{
		cv = MetersToFeet((float)cv);			// always store as feet
	}
	[defaults setFloat:(float)cv forKey:RCBDefaultMaxAltitude];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"PreferencesChanged" object:nil];
}


-(void)updateDefaultMaxAltTextField:(float)v		// incoming value is in ft or meters
{
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	int cv = v;	
	int d = 100;
	cv = (cv/d) * d;
	if (cv > 0)
	{
		const char* units = useStatuteUnits ? "ft" : "m";
		NSString* s = [NSString stringWithFormat:@"%d %s", cv, units];
		[defaultMaxAltitudeTextField setStringValue:s];
	}
	else
	{
		[defaultMaxAltitudeTextField setStringValue:@"no default"];
	}
}


-(void)updateAutoSplitTextField:(float)v		// incoming value is in ft or meters
{
	int cv = v;	
	int d = 10;
	cv = (cv/d) * d;
	NSString* s = [NSString stringWithFormat:@"%d minutes", cv];
	[autoSplitThresholdField setStringValue:s];
}


-(void)updateAltitudeFilterField:(float)v		// incoming value is in ft or meters
{
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	const char* units = useStatuteUnits ? "ft" : "m";
	NSString* s = [NSString stringWithFormat:@"%0.1f %s", v, units];
	[altitudeFilterField setStringValue:s];
}


-(void)updateMinSpeedForMovingTime:(float)v		// incoming value is in ft or meters
{
	BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	const char* units = useStatuteUnits ? "mph" : "km/h";
	NSString* s = [NSString stringWithFormat:@"%0.1f %s", v, units];
	[minSpeedField setStringValue:s];
}


- (IBAction)setValueForSender:(id)sender;
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	if (sender == checkForUpdatesAtStartupButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBCheckForUpdateAtStartup];
		[defaults synchronize];
	}
	else if (sender == checkForUpdatesPeriodicallyButton)
	{
		[self setUpdateFrequency:sender];
		if ([sender state] == NSControlStateValueOn) 
		{
			[checkForUpdatesAtStartupButton setState:NO];
			[checkForUpdatesAtStartupButton setEnabled:NO];
			[defaults setBool:NO forKey:RCBCheckForUpdateAtStartup];
			[defaults synchronize];
		}
		else
		{
			[checkForUpdatesAtStartupButton setEnabled:YES];
		}
	}
	else if (sender == checkForUpdatesFrequencyPopup)
	{
		[self setUpdateFrequency:sender];
	}
	else if (sender == enableAutoSplitButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultAutoSplitEnabled];
		[defaults synchronize];
		BOOL enabled = [sender state] == NSControlStateValueOn;
		NSColor* clr = (enabled ? [NSColor blackColor] : [NSColor lightGrayColor]);
		[autoSplitThresholdText setTextColor:clr];
		[autoSplitThresholdField setTextColor:clr];
		[autoSplitThresholdSlider setEnabled:enabled];
	}
	else if (sender == minSpeedSlider)
	{
		float v = [sender floatValue];
		[self updateMinSpeedForMovingTime:v];
		SEL sel = @selector(minSpeedSliderDone:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:sel 
												   object:sender];
		[self performSelector:sel 
				   withObject:sender
				   afterDelay:0.0];
	}
	else if (sender == useDistanceDataButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultUseDistanceDataEnabled];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
	}
	else if (sender == altitudeFilterSlider)
	{
		float v = [sender floatValue];
		[self updateAltitudeFilterField:v];
		SEL sel = @selector(altFilterSliderDone:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:sel 
												   object:sender];
		[self performSelector:sel 
				   withObject:sender
				   afterDelay:0.0];
	}
	else if (sender == autoSplitThresholdSlider)
	{
		float v = [sender floatValue];
		[self updateAutoSplitTextField:v];
		SEL sel = @selector(autoSplitTimeSliderDone:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:sel 
												   object:sender];
		[self performSelector:sel 
				   withObject:sender
				   afterDelay:0.0];
	}
	else if (sender == altitudeAverageWindowSlider)
	{
		float v = [sender floatValue];
		[altitudeAverageWindowTextField setFloatValue:v];
		SEL sel = @selector(altSmoothingSliderDone:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:sel 
												   object:sender];
		[self performSelector:sel 
				   withObject:sender
				   afterDelay:0.0];
	}
	else if (sender == defaultMaxAltitudeSlider)
	{
		float v = [sender floatValue];
		[self updateDefaultMaxAltTextField:v];
		SEL sel = @selector(defaultMaxAltSliderDone:);
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:sel 
												   object:sender];
		[self performSelector:sel 
				   withObject:sender
				   afterDelay:0.0];
	}
	else if (sender == calculatePowerIfAbsentButton)
	{
		[defaults setBool:[sender state] == NSControlStateValueOn ? YES : NO forKey:RCBDefaultCalculatePowerIfAbsent];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
	}
	else if (sender == powerActvitiesPopup)
	{
		[self togglePowerActivity:[sender indexOfSelectedItem]];	
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MustFixupTrack" object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
	}
}


-(void)togglePowerActivity:(int)idx
{
	if (idx == 0) return;
	NSArray * itemArray = [Utils attributeArray:RCBDefaultAttrActivityList];
	NSString* act = [itemArray objectAtIndex:idx-1];
	NSMutableArray* powerActs = [NSMutableArray arrayWithArray:[Utils objectFromDefaults:RCBDefaultCalculatePowerActivities]];
	if (powerActs)
	{
		if ([powerActs containsObject:act])
			[powerActs removeObject:act];
		else
			[powerActs addObject:act];
		
		[Utils setObjectDefault:powerActs
						 forKey:RCBDefaultCalculatePowerActivities];
	}
	[self rebuildPowerActivitiesMenu];
	
}



-(void)updateUI
{
    NSUserDefaults* defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	BOOL useEnglish = [defaults boolForKey:RCBDefaultUnitsAreEnglishKey];
	[checkForUpdatesAtStartupButton setState:[defaults boolForKey:RCBCheckForUpdateAtStartup]];
	int updateFreq = [[NSUserDefaults standardUserDefaults] integerForKey:UserDefaultCheckForUpdateFrequency];
	[checkForUpdatesPeriodicallyButton setState:updateFreq > 0];
	NSString* s;
	BOOL enabled = true;
	if (updateFreq >= (60*60*24*30))
	{
		s = @"monthly";
	}
	else if (updateFreq >= (60*60*24*7))
	{
		s = @"weekly";
	}
	else if (updateFreq >= (60*60*24))
	{
		s = @"daily";
	}
	else if (updateFreq >= (60*60))
	{
		s = @"hourly";
	}
	else
	{
		s = @"weekly";
		enabled = false;
	}
	[checkForUpdatesFrequencyPopup setEnabled:enabled];
	[checkForUpdatesFrequencyPopup selectItemWithTitle:s];
	[checkForUpdatesAtStartupButton setEnabled:!enabled];

	enabled = [defaults boolForKey:RCBDefaultAutoSplitEnabled];
	NSColor* clr = enabled ? [NSColor blackColor] : [NSColor grayColor];
	[enableAutoSplitButton setState: enabled ? NSControlStateValueOn : NSControlStateValueOff];
	[autoSplitThresholdText setTextColor:clr];
	[autoSplitThresholdSlider setEnabled:enabled];

	enabled = [defaults boolForKey:RCBDefaultUseDistanceDataEnabled];
	[useDistanceDataButton setState: enabled ? NSControlStateValueOn : NSControlStateValueOff];

	enabled = [defaults boolForKey:RCBDefaultCalculatePowerIfAbsent];
	[calculatePowerIfAbsentButton setState: enabled ? NSControlStateValueOn : NSControlStateValueOff];
	
	float v = [Utils convertSpeedValue:[defaults floatForKey:RCBDefaultMinSpeed]];
	[self updateMinSpeedForMovingTime:v];
	[minSpeedSlider setFloatValue:v];

	v = [Utils convertClimbValue:[defaults floatForKey:RCBDefaultAltitudeFilter]];
	float mx = [Utils convertClimbValue:MAX_ALT_FILTER];
	if (v > mx) v = mx;
	[self updateAltitudeFilterField:v];
	[altitudeFilterSlider setMaxValue:mx];
	[altitudeFilterSlider setFloatValue:v];

	v = [defaults floatForKey:RCBDefaultAltitudeSmoothingPercentage];
	if (!IS_BETWEEN(0.0, v, 100.0)) v = 0.0;
	[altitudeAverageWindowSlider setFloatValue:v];
	[altitudeAverageWindowTextField setFloatValue:v];
	
	v = [defaults integerForKey:RCBDefaultAutoSplitMinutes];
	[autoSplitThresholdSlider setFloatValue:v];
	[self updateAutoSplitTextField:v];
	
	if (useEnglish)
	{
		[defaultMaxAltitudeSlider setMaxValue:20000.0];
	}
	else
	{
		[defaultMaxAltitudeSlider setMaxValue:10000.0];
	}	
	
	v = [defaults floatForKey:RCBDefaultMaxAltitude];	// always in feet
	v = [Utils convertClimbValue:v];					// now feet or meters
	[self updateDefaultMaxAltTextField:v];				// controls work in native units, different than others above
	[defaultMaxAltitudeSlider setFloatValue:v];
	
	[self checkPowerActivitiesMenu];
}


-(void)rebuildPowerActivitiesMenu
{
	NSArray * itemArray = [Utils attributeArray:RCBDefaultAttrActivityList];
	NSArray* powerActs = [Utils objectFromDefaults:RCBDefaultCalculatePowerActivities];
	[powerActvitiesPopup removeAllItems];
	
	NSMutableString* theMenuTitle =  [NSMutableString stringWithString:@"Enable auto-power and work calculations for:"];
	[powerActvitiesPopup addItemWithTitle:theMenuTitle];
	 
	for (NSString* act in itemArray)
	{
		[powerActvitiesPopup addItemWithTitle:act];
		if ([powerActs containsObject:act])
		{
			NSMenuItem* mi = [powerActvitiesPopup itemWithTitle:act];
			[mi setState:NSControlStateValueOn];
		}
	}
	NSMenuItem* mi = [powerActvitiesPopup itemWithTitle:theMenuTitle];
	[mi setState:NSControlStateValueOff];
}


-(void)checkPowerActivitiesMenu
{
	[Utils createPowerActivityArrayIfDoesntExist];
	[self rebuildPowerActivitiesMenu];
	
}

@end
