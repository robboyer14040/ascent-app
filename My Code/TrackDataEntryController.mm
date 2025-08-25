//
//  TrackDataEntryController.mm
//  Ascent
//
//  Created by Rob Boyer on 8/19/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TrackDataEntryController.h"
#import "Utils.h"
#import "Defs.h"
#import "Track.h"
#import "TrackBrowserDocument.h"


#define kPaceOverrideCBTag		999


@implementation TrackDataEntryController

- (id) initWithTrack:(Track*)trk initialDate:(NSDate*)initialDate document:(TrackBrowserDocument*)doc editExistingTrack:(BOOL)em
{
	self = [super initWithWindowNibName:@"TrackDataEntry"];
	editMode = em;
	tbDocument = doc;
	if (trk)
	{
		NSString* s = [trk attribute:kName];
		if (!s || [s isEqualToString:@""])
			trackName = [trk name];
		else 
			trackName = s;
		
		if (editMode)
		{
			track = [trk mutableCopy];
			[track setCreationTime:initialDate];
            [track setUuid:[trk uuid]];     // maintain UUID forever
		}
		else
		{
            // adding a new track.  this will result in a new track, with a UNIQUE UID
			track = [[Track alloc] init];
			// @@FIXME@@ maybe should do a mutable copy here?
			[track setCreationTime:[NSDate date]];
			[track setAttributes:[trk attributes]];
			[track setEquipmentUUIDs:[trk equipmentUUIDs]];
			[track setOverrideValue:kST_Distance index:kMax value:[trk distance]];
			[track setOverrideValue:kST_Durations index:kElapsed value:[trk duration]];
			[track setOverrideValue:kST_Durations index:kMoving  value:[trk movingDuration]];
			[track setOverrideValue:kST_ClimbDescent index:kMax value:[trk totalClimb]];
			[track setOverrideValue:kST_ClimbDescent index:kMin value:[trk totalDescent]];
			[track setOverrideValue:kST_Altitude index:kMax value:[trk maxAltitude:nil]];
			[track setOverrideValue:kST_Altitude index:kMin value:[trk minAltitude:nil]];
			[track setOverrideValue:kST_Heartrate index:kMax value:[trk maxHeartrate:nil]];
			[track setOverrideValue:kST_Heartrate index:kAvg value:[trk avgHeartrate]];
			[track setOverrideValue:kST_MovingSpeed index:kMax value:[trk maxSpeed:nil]];
			[track setOverrideValue:kST_MovingSpeed index:kAvg value:[trk avgMovingSpeed]];
			//[track setOverrideValue:kOD_PaceMin value:[trk minPace:nil]];
			//[track setOverrideValue:kOD_PaceAvg value:[trk avgMovingPace]];
			[track setOverrideValue:kST_Cadence index:kMax value:[trk maxCadence:nil]];
			[track setOverrideValue:kST_Cadence index:kAvg value:[trk avgCadence]];
			[track setOverrideValue:kST_Gradient index:kMax value:[trk maxGradient:nil]];
			[track setOverrideValue:kST_Gradient index:kMin value:[trk minGradient:nil]];
			[track setOverrideValue:kST_Gradient index:kAvg value:[trk avgGradient]];
			[track setOverrideValue:kST_Temperature index:kMax value:[trk maxTemperature:nil]];
			[track setOverrideValue:kST_Temperature index:kMin value:[trk minTemperature:nil]];
			[track setOverrideValue:kST_Temperature index:kAvg value:[trk avgTemperature]];
			[track setOverrideValue:kST_Calories index:kVal value:[trk calories]];
			[track setOverrideValue:kST_Power index:kAvg value:[trk avgPower]];
			[track setOverrideValue:kST_Power index:kMax value:[trk maxPower:nil]];
			[track setOverrideValue:kST_Power index:kWork value:[trk work]];
		}
	}
	else
	{
		track = [[Track alloc] init];
		[track setCreationTime:initialDate];
		trackName = @"";
	}
	[track setName:trackName];

	entryStatus = kTrackEntryOK;
	return self;
}


- (void) dealloc
{
}

// setup menus in the edit window

- (void) setDurationFields:(float) dur
               startingTag:(int) startingTag

{
   int hours = (int)(dur/3600.0);
   int minutes = ((int)(dur/60.0)) % 60;
   int seconds = ((int)dur) % 60;
   NSView* view = [[self window] contentView];
   [[view viewWithTag:startingTag] setStringValue:[NSString stringWithFormat:@"%03.3d", hours]];
   [[view viewWithTag:startingTag+1] setStringValue:[NSString stringWithFormat:@"%02.2d", minutes]];
   [[view viewWithTag:startingTag+2] setStringValue:[NSString stringWithFormat:@"%02.2d", seconds]];
}


// remove seconds from the date 'cause they can't be set using the picker
#if 0
- (NSDate*) sanitizeDate:(NSDate*)inDate
{
	NSCalendarDate* calDate = [inDate dateWithCalendarFormat:nil
													timeZone:nil];
	calDate = [calDate dateWithYear:[calDate yearOfCommonEra]
							  month:[calDate monthOfYear]
								day:[calDate dayOfWeek]
							   hour:[calDate hourOfDay]
							 second:0.0
						   timeZone:nil];
}
#endif	
		

-(void) updateOverridableFields
{
	//[copyFromPopupText setHidden:editMode];
	//[copyFromPopup setHidden:editMode];
	NSView* view = [[self window] contentView];
	NSTimeInterval dur = [track duration];
	[startTimePicker setDateValue:[track creationTime]];
	[[view viewWithTag:kAE_Title] setStringValue:[track attribute:kName]];
	[self setDurationFields:dur startingTag:kAE_ElapsedTimeHours];
	[self setDurationFields:(dur - [track movingDuration]) startingTag:kAE_InactiveTimeHours];
	[[view viewWithTag:kAE_Distance] setFloatValue:[Utils convertDistanceValue:[track distance]]];
	[[view viewWithTag:kAE_Climb] setFloatValue:[Utils convertClimbValue:[track totalClimb]]];
	[[view viewWithTag:kAE_Descent] setFloatValue:[Utils convertClimbValue:[track totalDescent]]];
	[[view viewWithTag:kAE_AltitudeMax] setFloatValue:[Utils convertClimbValue:[track maxAltitude:nil]]];
	[[view viewWithTag:kAE_AltitudeMin] setFloatValue:[Utils convertClimbValue:[track minAltitude:nil]]];
	[[view viewWithTag:kAE_HeartRateMax] setFloatValue:[track maxHeartrate:nil]];
	[[view viewWithTag:kAE_HeartRateAvg] setFloatValue:[track avgHeartrate]];
	[[view viewWithTag:kAE_CadenceMax] setFloatValue:[track maxCadence:nil]];
	[[view viewWithTag:kAE_CadenceAvg] setFloatValue:[track avgCadence]];
	[[view viewWithTag:kAE_GradientMax] setFloatValue:[track maxGradient:nil]];
	[[view viewWithTag:kAE_GradientMin] setFloatValue:[track minGradient:nil]];
	[[view viewWithTag:kAE_GradientAvg] setFloatValue:[track avgGradient]];
	[[view viewWithTag:kAE_TemperatureMax] setFloatValue:[Utils convertTemperatureValue:[track maxTemperature:nil]]];
	[[view viewWithTag:kAE_TemperatureMin] setFloatValue:[Utils convertTemperatureValue:[track minTemperature:nil]]];
	[[view viewWithTag:kAE_TemperatureAvg] setFloatValue:[Utils convertTemperatureValue:[track avgTemperature]]];
	[[view viewWithTag:kAE_SpeedMax] setFloatValue:[Utils convertSpeedValue:[track maxSpeed]]];
	[[view viewWithTag:kAE_SpeedAvg] setFloatValue:[Utils convertSpeedValue:[track avgMovingSpeed]]];
	[[view viewWithTag:kAE_PaceAvg] setFloatValue:[Utils convertPaceValue:[track avgMovingPace]]];
	[[view viewWithTag:kAE_PaceMin] setFloatValue:[Utils convertPaceValue:[track minPace:nil]]];
	[[view viewWithTag:kAE_Calories] setFloatValue:[track calories]];
	[[view viewWithTag:kAE_AvgPower] setFloatValue:[track avgPower]];
	[[view viewWithTag:kAE_MaxPower] setFloatValue:[track maxPower:nil]];
	[[view viewWithTag:kAE_Work] setFloatValue:[track work]];
	for (int i=0; i < kST_NumStats; i++)
	{
		id v = [view viewWithTag:STToCB(i)];
		if (v) 
		{
			[v setIntValue:[track isOverridden:(tStatType)i]];
			// special handling for pace... ugh
			if (i == kST_MovingSpeed)
			{
				id vp = [view viewWithTag:kPaceOverrideCBTag];
				[vp setIntValue:[track isOverridden:(tStatType)i]];
			}
		}
	}
	// deal with special-case creationTime
	id v = [view viewWithTag:kCreationTimeOverrideTag];
	if (v) 
	{
		if (editMode) 
			[v setIntValue:([track creationTimeOverride] != nil)];
		else
			[v setIntValue:1];		// adding an activity, always need start time
	}
	
	for (int i=1; i < kNumAttributes; i++)		// skip the "name" attribute, already handled above and has different UI tag
	{
		if (i != kWeight)		// weight is special-cased
		{
			id ctl = [view viewWithTag:i];
			if ([ctl respondsToSelector:@selector(selectItemWithTitle:)])
			{
				[ctl selectItemWithTitle:[track attribute:i]];
			}
			else
			{
				[ctl setStringValue:[track attribute:i]];
			}
		}
	}
}	


-(void) awakeFromNib
{
	NSView* view = [[self window] contentView];
	if (editMode)
	{
		[[self window] setTitle:@"Edit Activity"];
	}
	else
	{
		[[self window] setTitle:@"Add Activity"];
	}
	
	// disable fields that are not over-ridden.  User must check a field to override 
	for (int i=0; i < kST_NumStats; i++)
	{
		int aeIdx = STToAE(i);
		if (!editMode)
		{
			for (int j=0; j<3; j++)		// never more than 3 fields per stat, currently
			{
				[track setOverrideValue:(tStatType)i index:j value:0.0];
			}
		}
		BOOL enabled = [track isOverridden:(tStatType)i];
		BOOL isSpeed = (i == kST_MovingSpeed);
		int end = ((i == kST_Durations)||isSpeed) ? 6 : 3;
		for (int j=0; j<end; j++)		// never more than 3 fields per stat, currently
		{
			id v = [view viewWithTag:aeIdx+j];
			if (v) [v setEnabled:enabled];
		}
	}
	
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	useCentigradeUnits = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
	[customLabelField setStringValue:[Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
	[kw1LabelField setStringValue:[Utils stringFromDefaults:RCBDefaultKeyword1Label]];
	[kw2LabelField setStringValue:[Utils stringFromDefaults:RCBDefaultKeyword2Label]];

	[startTimePicker setDateValue:[track creationTime]];
	[startTimePicker setMaxDate:[NSDate date]];

	[self setDurationFields:[track duration]
			   startingTag:kAE_ElapsedTimeHours];
	[self setDurationFields:[track duration] - [track movingDuration]
			   startingTag:kAE_InactiveTimeHours];
	[notesView setString:[track attribute:kNotes]];
	[weightField setFloatValue:[Utils convertWeightValue:[track weight]]];
	[customField setStringValue:[track attribute:kKeyword3]];



	id tview = [view viewWithTag:kAE_Title];
	[tview setStringValue:trackName];

	[self updateOverridableFields];

	// setup popup menus
	[Utils buildPopupMenuFromItems:RCBDefaultAttrActivityList 
							popup:activityTypePopup 
				 currentSelection:[track attribute:kActivity]];
	[activityTypePopup selectItemWithTitle:[track attribute:kActivity]];
	  
	[Utils buildPopupMenuFromItems:RCBDefaultAttrEventTypeList 
							popup:eventTypePopup
				 currentSelection:[track attribute:kEventType]];
	[eventTypePopup selectItemWithTitle:[track attribute:kEventType]];

	[Utils buildPopupMenuFromItems:RCBDefaultAttrWeatherList 
							popup:weatherPopup
				 currentSelection:[track attribute:kWeather]];
	[weatherPopup selectItemWithTitle:[track attribute:kWeather]];

	[Utils buildPopupMenuFromItems:RCBDefaultAttrDispositionList 
							popup:dispositionPopup
				 currentSelection:[track attribute:kDisposition]];
	[dispositionPopup selectItemWithTitle:[track attribute:kDisposition]];

#if 0
	[Utils buildPopupMenuFromItems:RCBDefaultAttrEquipmentList 
							popup:equipmentPopup
				 currentSelection:[track attribute:kEquipment]];
	[equipmentPopup selectItemWithTitle:[track attribute:kEquipment]];
#endif
	
	[Utils buildPopupMenuFromItems:RCBDefaultAttrEffortList 
							popup:effortPopup
				 currentSelection:[track attribute:kEffort]];
	[effortPopup selectItemWithTitle:[track attribute:kEffort]];

	[Utils buildPopupMenuFromItems:RCBDefaultAttrKeyword1List 
							popup:kw1Popup
				 currentSelection:[track attribute:kKeyword1]];
	[kw1Popup selectItemWithTitle:[track attribute:kKeyword1]];

	[Utils buildPopupMenuFromItems:RCBDefaultAttrKeyword2List 
							popup:kw2Popup
				 currentSelection:[track attribute:kKeyword2]];
	[kw2Popup selectItemWithTitle:[track attribute:kKeyword2]];

	// build list of tracks to copy data from
	NSMutableArray* ta = [tbDocument trackArray];
	[copyFromPopup removeAllItems];
	int count = [ta count];
	[copyFromPopup addItemWithTitle:@"-- none selected --"];
	for (int i=count-1; i>=0; i--)
	{
		[copyFromPopup addItemWithTitle:[Utils buildTrackDisplayedName:[ta objectAtIndex:i] prePend:@""]];
	}
}


-(Track*) track
{
   return track;
}


- (void)processPopup:(id)popup  attributeID:(int)attrID
{
   BOOL changed = NO;
   if ([popup indexOfSelectedItem] >= [popup numberOfItems]-1)
   {
      NSString* prevSel = [track attribute:attrID];
      int sts = [Utils editAttributeList:popup
                             attributeID:attrID
                                      wc:self];
      
      changed = (sts == 0);
      if (changed)
      {
         [Utils buildPopupMenuFromItems:[Utils attrIDToDefaultsKey:attrID]
                                  popup:popup 
                       currentSelection:[track attribute:attrID]];
      }
      [popup selectItemWithTitle:prevSel]; 
   }
   else
   {
      NSString *newSel = [popup titleOfSelectedItem];
      if (newSel != nil)
      {
         [track setAttribute:attrID usingString:newSel];
         changed = YES;
      }
   }
}


-(IBAction) setAttributePopUpValue:(id)sender
{
	[self processPopup:sender 
		   attributeID:[sender tag]];			// tag is attribute id, obviously
}


-(IBAction) setAttributeTextField:(id)sender
{
	if ([sender tag] == kWeight)		// special handling for weight
	{
		float v = [sender floatValue];
		v = useStatuteUnits ? v : KilogramsToPounds(v);
		[track setWeight:v];
	}
	else
	{
		[track setAttribute:[sender tag] usingString:[sender stringValue]];	// tag is attribute id, obviously
	}
}


- (NSTimeInterval) getEnteredTime:(int)startingTag
{
   NSView* view = [[self window] contentView];
   return ([[view viewWithTag:startingTag] floatValue] * 3600.0) +
          ([[view viewWithTag:startingTag+1] floatValue] * 60.0) +
          ([[view viewWithTag:startingTag+2] floatValue]);
}


-(NSTimeInterval) elapsedTime
{
   return [self getEnteredTime:kAE_ElapsedTimeHours];
}


-(NSTimeInterval) inactiveTime
{
   return [self getEnteredTime:kAE_InactiveTimeHours];
}


-(NSTimeInterval) movingTime
{
   NSTimeInterval t = [self elapsedTime] - [self inactiveTime];
   if (t < 0.0) t = 0.0;
   return t;
}

-(float) paceToSpeed:(float)pace
{
	float val = 0.0;
	if (pace != 0.0)
	{
		// 60mins/hour * mile/mins = mile/hour; 
		val = (60.0)/pace;
	}
	return val;
}


-(void) processSetValueForTaggedField:(id)sender
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	useCentigradeUnits = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
	int tag = [sender tag];
	tStatType statType = (tStatType)AEToST(tag);
	switch (tag)
	{
		default:
		{
			float v = [sender floatValue];
			[track setOverrideValue:statType
							  index:tag - (STToAE(statType))
							  value:v];
			[self updateOverridableFields];
		}
		break;
		 
			
		case kAE_TemperatureAvg:
		case kAE_TemperatureMax:
		case kAE_TemperatureMin:
		{
			float v = [sender floatValue];
			[track setOverrideValue:statType
							  index:tag - (STToAE(statType))
							  value:useCentigradeUnits ? CelsiusToFahrenheight(v) : v];
			[self updateOverridableFields];
		}
		break;
			
		case kAE_Distance:
		case kAE_SpeedMax:
		case kAE_SpeedAvg:
		{
			float v = [sender floatValue];
			[track setOverrideValue:statType
							  index:tag - (STToAE(statType))
							  value:useStatuteUnits ? v : KilometersToMiles(v)];
			[self updateOverridableFields];
		}
		break;
			
		case kAE_AltitudeMax:
		case kAE_AltitudeMin:
		case kAE_Climb:
		case kAE_Descent:
		{
			float v = [sender floatValue];
			[track setOverrideValue:statType
							  index:tag - (STToAE(statType))
							  value:useStatuteUnits ? v : MetersToFeet(v)];
			[self updateOverridableFields];
		}
		break;
			
		case kAE_PaceMin:
		case kAE_PaceAvg:
		{
			float v = [sender floatValue];
			[track setOverrideValue:statType
							  index:tag - kAE_PaceMin
							  value:useStatuteUnits ? v : MPKToMPM(v)];
			[self updateOverridableFields];
		}
		break;
			
		case kAE_Title:
			[track setAttribute:kName
					usingString:[sender stringValue]];
			break;

		case kAE_ElapsedTimeHours:
		case kAE_ElapsedTimeMinutes:
		case kAE_ElapsedTimeSeconds:
		{
			NSTimeInterval elapsed = [self elapsedTime];
			[track setOverrideValue:kST_Durations
							  index:kElapsed
							  value:elapsed];
			[track setOverrideValue:kST_Durations
							  index:kMoving
							  value:elapsed];
			[self updateOverridableFields];
			break;
		}
		  
		case kAE_InactiveTimeHours:
		case kAE_InactiveTimeMinutes:
		case kAE_InactiveTimeSeconds:
			[track setOverrideValue:kST_Durations
							  index:kMoving
							  value:[self movingTime]];
			[self updateOverridableFields];
			break;
	}
}


-(void) copyDataFromActivity:(Track*)trk
{
	if (trk)
	{
		for (int i=0; i<kNumAttributes; i++)
		{
			[track setAttribute:i 
					usingString:[trk attribute:i]];
		}
		
		for (int i=0; i<kST_NumStats; i++)
		{
			for (int j=0; j<3; j++)
			{
				[track setOverrideValue:(tStatType)i 
								  index:j 
								  value:[trk stat:(tStatType)i 
											index:j 
								atActiveTimeDelta:0]];
			}
		}
		
		[track setEquipmentUUIDs:[trk equipmentUUIDs]];
		[self updateOverridableFields];
	}
}


-(IBAction) setFieldValue:(id)sender
{
   if (sender == startTimePicker)
   {
	   [[self window] makeFirstResponder:nil];
	   if (editMode)
	   {
		   [track setCreationTimeOverride:[startTimePicker dateValue]];
	   }
	   else
	   {
		   [track setCreationTime:[startTimePicker dateValue]];
	   }
	   [self updateOverridableFields];
   }
   else if (sender == copyFromPopup)
   {
	   [[self window] makeFirstResponder:nil];
	   int idx = [sender indexOfSelectedItem];
	   if (idx > 0)	// 0 is the "none" entry
	   {
		   int count = [[tbDocument trackArray] count];
		   [self copyDataFromActivity:[[tbDocument trackArray] objectAtIndex:count - idx]];
	   }
   }
   else
   {
      [self processSetValueForTaggedField:sender];
   }
}


-(IBAction) setOverrideForField:(id)sender
{
    [[self window] makeFirstResponder:nil];
	NSView* view = [[self window] contentView];
	tStatType stIdx;
	BOOL isPace = [sender tag] == kPaceOverrideCBTag;
	BOOL isSpeed = [sender tag] == STToCB(kST_MovingSpeed);
	BOOL isStartTime = [sender tag] == kCreationTimeOverrideTag;
	if (isStartTime)
	{
		[track setCreationTimeOverride:([sender intValue] == 0 ? nil : [startTimePicker dateValue])];
		[self updateOverridableFields];
		return;
	}
	else if (isPace)
	{
		stIdx = kST_MovingSpeed;
	}
	else
	{
		stIdx = (tStatType)(CBToST([sender tag]));
	}
	if (IS_BETWEEN(0, stIdx,(kST_NumStats-1)))
	{
		//printf("st idx: %d\n", stIdx);
		BOOL enabled;
		if ([sender intValue] == 0) 
		{
			[track clearOverride:stIdx];
			enabled = NO;
		}
		else
		{
			for (int j=0; j<3; j++)		// never more than 3 fields per stat, currently
			{
				[track setOverrideValue:stIdx 
								  index:j 
								  value:[track overrideValue:stIdx
													   index:j]];
			}
			enabled = YES;
		}
		int end = ((stIdx == kST_Durations)||isPace||isSpeed) ? 6 : 3;
		int aeIdx = STToAE(stIdx);
		for (int j=0; j<end; j++)		
		{
			id v = [view viewWithTag:aeIdx+j];
			if (v) [v setEnabled:enabled];
		}
		[self updateOverridableFields];
	}
}


-(IBAction) setNotes:(id)sender
{
	[track setAttribute:kNotes
			usingString:[sender stringValue]];
}


- (IBAction) dismissPanel:(id)sender
{
	BOOL ok = entryStatus == kTrackEntryOK;
	[NSApp stopModalWithCode:ok?0:-1];
}


-(IBAction) cancel:(id)sender
{
    [[self window] makeFirstResponder:nil];
	entryStatus = kCancelTrackEntry;
	[self dismissPanel:sender];
}


-(IBAction) done:(id)sender
{
	[[self window] makeFirstResponder:nil];
	NSString* notes = [[notesView textStorage] string];
	[track setAttribute:kNotes
			usingString:notes];
	entryStatus = kTrackEntryOK;
	[self dismissPanel:sender];
}


// Delegate

- (void) windowWillClose:(NSNotification *)aNotification
{
   [[self window] makeFirstResponder:nil];
   entryStatus = kCancelTrackEntry;
   [NSApp stopModalWithCode:-1];
}


@end
