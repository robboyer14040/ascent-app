//
//  TrackDataEntryController.h
//  Ascent
//
//  Created by Rob Boyer on 8/19/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StatDefs.h"


enum tTrackEntryStatus
{
   kTrackEntryOK,
   kCancelTrackEntry
};

@class Track;
@class TrackBrowserDocument;

// date entry field tag to override index conversion
#define STToAE(st)      (100+(10*st))
#define AEToST(ae)      ((ae-100)/10)

// checkbox field tag to override index conversion
#define STToCB(st)      ((100+(10*st))+9)
#define CBToST(cb)      (((cb-100)/10))

enum
{
	kCreationTimeOverrideTag = 4242,	// special handling of creation time
};

// GUI tags for fields in the Add/Edit activity panel.  Note, within a stat,
// the enums must be arranged max, min, avg.  If 'min' is missing but 'avg'
// avg is present, then need to skip an enum
enum
{
	kAE_Title					= 99,
	kAE_ElapsedTimeHours		= STToAE(kST_Durations), 
	kAE_ElapsedTimeMinutes,
	kAE_ElapsedTimeSeconds,
	kAE_InactiveTimeHours,    
	kAE_InactiveTimeMinutes,  
	kAE_InactiveTimeSeconds,
	kAE_Distance				= STToAE(kST_Distance),        
	kAE_Climb					= STToAE(kST_ClimbDescent),
	kAE_Descent,
	kAE_AltitudeMax				= STToAE(kST_Altitude),
	kAE_AltitudeMin,             
	kAE_HeartRateMax			= STToAE(kST_Heartrate),
	kAE_HeartRateAvg			= kAE_HeartRateMax + 2,
	kAE_SpeedMax				= STToAE(kST_MovingSpeed),
	kAE_SpeedAvg				= kAE_SpeedMax + 2,			
	kAE_PaceMin,                  
	kAE_PaceAvg					= kAE_PaceMin + 2,
	kAE_CadenceMax				= STToAE(kST_Cadence),
	kAE_CadenceAvg				= kAE_CadenceMax + 2,
	kAE_GradientMax				= STToAE(kST_Gradient),
	kAE_GradientMin,              
	kAE_GradientAvg,
	kAE_TemperatureMax			= STToAE(kST_Temperature),
	kAE_TemperatureMin,
	kAE_TemperatureAvg, 
	kAE_Calories				= STToAE(kST_Calories),
	kAE_MaxPower				= STToAE(kST_Power),
	kAE_Work,
	kAE_AvgPower,
   // add new field tags here
};


@interface TrackDataEntryController : NSWindowController 
{
	IBOutlet NSTextField*		weightField;
	IBOutlet NSTextField*		kw1LabelField;
	IBOutlet NSTextField*		kw2LabelField;
	IBOutlet NSTextField*		customField;
	IBOutlet NSTextField*		customLabelField;
	IBOutlet NSTextField*		distanceLabelField;
	IBOutlet NSTextField*		weightLabelField;
	IBOutlet NSTextField*		copyFromPopupText;
	IBOutlet NSTextView*		notesView;
	IBOutlet NSDatePicker*		startTimePicker;
	IBOutlet NSPopUpButton*		activityTypePopup;
	IBOutlet NSPopUpButton*		equipmentPopup;
	IBOutlet NSPopUpButton*		dispositionPopup;
	IBOutlet NSPopUpButton*		eventTypePopup;
	IBOutlet NSPopUpButton*		weatherPopup;
	IBOutlet NSPopUpButton*		effortPopup;
	IBOutlet NSPopUpButton*		kw1Popup;
	IBOutlet NSPopUpButton*		kw2Popup;
	IBOutlet NSPopUpButton*		copyFromPopup;
	IBOutlet NSBox*				elevationBox;
	IBOutlet NSBox*				speedBox;
	IBOutlet NSBox*				paceBox;
	IBOutlet NSBox*				temperatureBox;
	IBOutlet NSBox*				powerWorkBox;
	IBOutlet NSBox*				energyBox;
	
	TrackBrowserDocument*		tbDocument;
	Track*						track;
	NSString*					trackName;
	tTrackEntryStatus			entryStatus;
	BOOL						useStatuteUnits;
	BOOL						useCentigradeUnits;
	BOOL						editMode;
}

- (id) initWithTrack:(Track*)trk initialDate:(NSDate*)initialDate document:(TrackBrowserDocument*)doc editExistingTrack:(BOOL)em;

-(IBAction) setFieldValue:(id)sender;
-(IBAction) setAttributePopUpValue:(id)sender;
-(IBAction) setAttributeTextField:(id)sender;
-(IBAction) setOverrideForField:(id)sender;
-(IBAction) setNotes:(id)sender;

-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;

-(Track*) track;

@end
