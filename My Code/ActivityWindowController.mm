//
//  ActivityWindowController.mm
//  TLP
//
//  Created by Rob Boyer on 7/24/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "ActivityWindowController.h"
#import "TrackBrowserDocument.h"
#import "ActivityDetailView.h"
#import "Track.h"
#import "TrackPoint.h"
#import "PlotAttributes.h"
#import "ColorBoxView.h"
#import "Utils.h"
#import "ItemList.h"
#import "EditMarkersController.h"
#import "AnimTimer.h"
#import "ActivityDetailTransparentView.h"
#import "ADStatsView.h"
#import "DataHUDWindowController.h"
#import "HUDWindow.h"
#import "StatDefs.h"
#import "TrackPoint.h"
#import "Lap.h"

// contextual menu ("CM") menu item identifiers - these must not conflict with 
// tPlotType enums, because they are also used to tag contextual menu items
enum
{
	kCM_AddMarker = 2000,      
	kCM_ToggleHRZones,
	kCM_ShowHUD,
	kCM_ShowStatsHUD,
	kCM_ShowMarkers,
	kCM_ShowLaps,
	kCM_ShowCrossHairs,
	kCM_ShowPeaks,
	kCM_InsertLapMarker,
	kCM_RemoveLapMarker,
	kCM_SplitActivity,
};

@interface ActivityWindowController ()
{
    id<ActivityWindowControllerDelegate> __unsafe_unretained _customDelegate;
    
    NSTimer*                    _fadeTimer;
    id                          _keyMonitor;
    ADStatsView                 *statsView;           // view for "statistics" HUD
    DataHUDWindowController     *dataHUDWC;
    HUDWindow                   *statsHUDWindow;
    EditMarkersController       *editMarkersController;
    NSMutableArray              *colorBoxes;
    Track                       *track;
    TrackBrowserDocument        *tbDocument;
    NSMutableDictionary         *hudTextAttrs;
    NSString                    *altFormat;
    NSString                    *speedFormat;
    NSString                    *paceFormat;
    NSString                    *distanceFormat;
    NSNumberFormatter           *numberFormatter;
    int                         currentFrame;
    BOOL                        regionSelected;
    BOOL                        useStatuteUnits;
    BOOL                        drawerColorBoxesCreated;
    //DataHUDView*            dataHUDView;         // view for "data" HUD
    //HUDWindow*              dataHUDWindow;
}
@property(nonatomic, retain) NSTimer* fadeTimer;
-(void) rebuildActivitySelectorPopup;
-(void) trackChanged:(NSNotification *)notification;
-(void) trackEdited:(NSNotification *)notification;
-(void) markersChanged:(NSNotification *)notification;
-(void) HUDClosed:(NSNotification *)notification;
-(void) trackArrayChanged:(NSNotification *)notification;
-(void) prefsChanged:(NSNotification *)notification;
-(void) updateStatsHUDPrompts;

@end



@implementation ActivityWindowController
@synthesize customDelegate = _customDelegate;
@synthesize fadeTimer = _fadeTimer;



- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"ActivityWindowController"];
	track = nil;
	activitySelectorPopup = nil;
	statsView = nil;
	statsHUDWindow = nil;
	tbDocument = doc;
	colorBoxes = [[NSMutableArray alloc] initWithCapacity:kNumAttributes];
	currentFrame = 0;
	regionSelected = NO;
	drawerColorBoxesCreated = NO;
	// transparent window+view are positoned over the window for drawing optimization
	NSRect dummy;
	dummy.size.width = 10;
	dummy.size.height = 10;
	dummy.origin.x = 0;
	dummy.origin.y = 0;
	numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[numberFormatter setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
	[numberFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
	[numberFormatter setLocale:[NSLocale currentLocale]];
#endif
    [doc addWindowController:self];
	return self;
}




- (void)dealloc
{
    if (_keyMonitor) {
        [NSEvent removeMonitor:_keyMonitor];
        _keyMonitor = nil;
    }
    [_fadeTimer release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (editMarkersController != nil) [editMarkersController release];
   [super dealloc];
}


- (void)endAnimation:(NSNotification *)notification
{
   id obj = [notification object];
   if (obj == graphView)
   {
      currentFrame = 0;
   }
}

-(void) editMarkers:(NSMutableArray*)newMarkers
{
   NSUndoManager* undo = [tbDocument undoManager];
   NSMutableArray* prevMarkers = [NSMutableArray arrayWithArray:[track markers]];
   [[undo prepareWithInvocationTarget:self] editMarkers:prevMarkers];
   if (![undo isUndoing])
   {
      [undo setActionName:@"Edit markers"];
   }
   [track setMarkers:newMarkers];
   [editMarkersController resetMarkers];
   [graphView markersChanged];
}


-(void) setFormatsForDataHUD
{
	[dataHUDWC setFormatsForDataHUD];
}


-(void) updatePlotEnabledState:(id)sender
{
	NSInteger tag = [sender tag];
	tPlotType pt = (tPlotType)tag;
	BOOL newState = [graphView plotEnabled:pt] ? NSControlStateValueOff : NSControlStateValueOn;
	[sender setState:newState];
	tag = typeComponentToTag(pt,kEnabledControl);
	[sender setTag:tag];
	[self setPlotEnabled:sender];
	[[[settingsDrawer contentView] viewWithTag:tag] setIntValue:newState];
}


-(void)insertLapMarker:(id)sender
{
	if ([tbDocument insertLapMarker:[[AnimTimer defaultInstance] animTime] inTrack:track])
	{
		[[self window] setDocumentEdited:YES];
		[tbDocument updateChangeCount:NSChangeDone];
	}
}


-(void)removeLapMarker:(id)sencer
{
	// removes the NEXT lap marker after the current location
	NSTimeInterval activeTimeDelta = [[AnimTimer defaultInstance] animTime];
	int idx = [track findIndexOfFirstPointAtOrAfterActiveTimeDelta:activeTimeDelta];
	if (idx > 0)
	{
		NSTimeInterval wcd = [[[track points] objectAtIndex:idx] wallClockDelta];
		
		NSArray* laps = [track laps];
        NSUInteger numLaps = [laps count];
		Lap* lap = nil;
		for (int i=0; i<numLaps; i++)
		{
			if ([[laps objectAtIndex:i] startingWallClockTimeDelta] > wcd)
			{
				lap = [laps objectAtIndex:i];
				break;
			}
		}
		if (lap)
		{
			if ([tbDocument deleteLap:lap fromTrack:track])
			{
				[[self window] setDocumentEdited:YES];
				[tbDocument updateChangeCount:NSChangeDone];
			}
		}
	}
}


-(void)splitActivity:(id)sender
{
	NSTimeInterval timeDelta = [[AnimTimer defaultInstance] animTime];
	if ((timeDelta > 0.0) && (timeDelta < [track movingDuration]))
	{
		[tbDocument splitTrack:track
			 atActiveTimeDelta:timeDelta];
	}
}


-(void)contextualMenuAction:(id)sender
{
   NSInteger tag = [sender tag];
   switch (tag)
   {
	   case kCM_InsertLapMarker:
		   [self insertLapMarker:sender];
		   break;
	   
	   case kCM_SplitActivity:
		   [self splitActivity:sender];
		   break;
		   
	   case kCM_RemoveLapMarker:
		   [self removeLapMarker:sender];
		   break;
		   
	   case kCM_AddMarker:
		   [self addMarker:sender];
		   break;
		 
		case kCM_ToggleHRZones:
			[sender setState:![graphView showHeartrateZones]];
			[self setShowHeartrateZones:sender];
			[showHeartrateZonesButton setState:[graphView showHeartrateZones]];
			break;
		 
		case kCM_ShowHUD:
			[sender setState:![self dataHUDActive]];
			[self setShowDataHUD:sender];
			[showDataHudButton setState:[self dataHUDActive]];
			break;
		 
		case kCM_ShowStatsHUD:
			{
				BOOL on = ![self statsHUDLocked];
				[sender setState:on];
				[self setStatsHUDLocked:sender];
				[showStatsHudButton setState:on];
			}
			break;
		 
		case kCM_ShowMarkers:
			[sender setState:![graphView showMarkers]];
			[self setShowMarkers:sender];
			[showMarkersButton setState:[graphView showMarkers] ? NSControlStateValueOn : NSControlStateValueOff];
			break;
		 
		case kCM_ShowLaps:
			[sender setState:![graphView showLaps]];
			[self setShowLaps:sender];
			[showLapsButton setState:[graphView showLaps] ? NSControlStateValueOn : NSControlStateValueOff];
			break;
		 
		case kCM_ShowCrossHairs:
			[sender setState:![graphView showCrossHairs]];
			[self setShowCrossHairs:sender];
			[showCrossHairsButton setState:[graphView showCrossHairs]];
			break;
		 
		case kCM_ShowPeaks:
			[sender setState:![graphView showPeaks]];
			[self setShowPeaks:sender];
			[showPeaksButton setState:[graphView showPeaks] ? NSControlStateValueOn : NSControlStateValueOff];
			break;
		 
		case kSpeed:
		case kHeartrate:
		case kGradient:
		case kCadence:
	    case kPower:
		case kAvgSpeed:
		case kAvgHeartrate:
		case kAvgGradient:
		case kAvgCadence:
	    case kAvgPower:
			[self updatePlotEnabledState:sender];
			break;
	}
}


- (NSMenu*) buildContextualMenu
{
	NSMenu* cm = [[[NSMenu alloc] init] autorelease];
	NSString* s;

	[[cm addItemWithTitle:@"Insert Lap Marker"
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@"I"] setTag:kCM_InsertLapMarker];

	[[cm addItemWithTitle:@"Remove Next Lap Marker"
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@"R"] setTag:kCM_RemoveLapMarker];

	//----
	[cm addItem:[NSMenuItem separatorItem]];
	//----

	[[cm addItemWithTitle:@"Split Activity"
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kCM_SplitActivity];
	
	//----
	[cm addItem:[NSMenuItem separatorItem]];
	//----
	
	if ((editMarkersController == nil) ||
		![[editMarkersController window] isVisible])
	{
		s = @"Show Markers Panel...";
	}
	else
	{
		s = @"Hide Markers panel...";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kCM_AddMarker];


	//----
	[cm addItem:[NSMenuItem separatorItem]];

	//----
	if ([Utils boolFromDefaults:RCBDefaultShowADHUD])
	{
		s = @"Hide Data HUD";
	}
	else
   {
      s = @"Show Data HUD";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowHUD];
   
   //----
   if ([self statsHUDLocked])
   {
      s = @"Unlock Statistics HUD";
   }
   else
   {
      s = @"Lock Statistics HUD";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowStatsHUD];
   
   //----
   if ([graphView showCrossHairs])
   {
      s = @"Hide Crosshairs";
   }
   else
   {
      s = @"Show Crosshairs";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowCrossHairs];
   
   //----
   if ([graphView showPeaks])
   {
      s = @"Hide Peaks";
   }
   else
   {
      s = @"Show Peaks";
   }
   [[cm addItemWithTitle:s
                  action:@selector(contextualMenuAction:)
           keyEquivalent:@""] setTag:kCM_ShowPeaks];
   
	//----
	if ([graphView showLaps])
	{
	  s = @"Hide Laps";
	}
	else
	{
	  s = @"Show Laps";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kCM_ShowLaps];

	//----
	if ([graphView showMarkers])
	{
	  s = @"Hide Markers";
	}
	else
	{
	  s = @"Show Markers";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kCM_ShowMarkers];

	//----
	if ([graphView showHeartrateZones])
	{
	  s = @"Hide Heart Rate Zones";
	}
	else
	{
	  s = @"Show Heart Rate Zones";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kCM_ToggleHRZones];

	//----
	[cm addItem:[NSMenuItem separatorItem]];

	//----
	if ([graphView plotEnabled:kHeartrate])
	{
	  s = @"Hide Heart Rate Graph";
	}
	else
	{
		s = @"Show Heart Rate Graph";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kHeartrate];
	
	//----
	if ([graphView plotEnabled:kSpeed])
	{
	  s = @"Hide Speed Graph";
	}
	else
	{
	  s = @"Show Speed Graph";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kSpeed];

	//----
	if ([graphView plotEnabled:kCadence])
	{
	  s = @"Hide Cadence Graph";
	}
	else
	{
	  s = @"Show Cadence Graph";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kCadence];

	//----
	if ([graphView plotEnabled:kPower])
	{
		s = @"Hide Power Graph";
	}
	else
	{
		s = @"Show Power Graph";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kPower];
	
	//----
	if ([graphView plotEnabled:kGradient])
	{
	  s = @"Hide Gradient Graph";
	}
	else
	{
	  s = @"Show Gradient Graph";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kGradient];

	//----
	[cm addItem:[NSMenuItem separatorItem]];

	//----
	if ([graphView plotEnabled:kAvgHeartrate])
	{
	  s = @"Hide Average Heart Rate Graph";
	}
	else
	{
	  s = @"Show Average Heart Rate Graph";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kAvgHeartrate];

	//----
	if ([graphView plotEnabled:kAvgSpeed])
	{
	  s = @"Hide Average Speed Graph";
	}
	else
	{
	  s = @"Show Average Speed Graph";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kAvgSpeed];
   
	//----
	if ([graphView plotEnabled:kAvgCadence])
	{
	  s = @"Hide Average Cadence Graph";
	}
	else
	{
	  s = @"Show Average Cadence Graph";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kAvgCadence];

	//----
	if ([graphView plotEnabled:kAvgPower])
	{
		s = @"Hide Average Power Graph";
	}
	else
	{
		s = @"Show Average Power Graph";
	}
	[[cm addItemWithTitle:s
				   action:@selector(contextualMenuAction:)
			keyEquivalent:@""] setTag:kAvgPower];
	
	//----
	if ([graphView plotEnabled:kAvgGradient])
	{
	  s = @"Hide Average Gradient Graph";
	}
	else
	{
	  s = @"Show Average Gradient Graph";
	}
	[[cm addItemWithTitle:s
				  action:@selector(contextualMenuAction:)
		   keyEquivalent:@""] setTag:kAvgGradient];


	return cm;
   
}   


- (void) positionEverything
{
   NSRect fr = [graphView frame];
   fr = NSInsetRect(fr, 10, 10);
   fr.origin = NSZeroPoint;
   [transparentView setFrame:fr];
   [transparentView setBounds:fr];
   [transparentView setNeedsDisplayInRect:fr];
   [transparentView setHidden:NO];
   [graphView setNeedsDisplay:YES];
}


-(void) buildLapPopUp
{
	[lapsPopup removeAllItems];
	if (track != nil)
	{
		NSArray* laps = [track laps];
        NSUInteger nl = [laps count];
		[lapsPopup addItemWithTitle:@"all laps"];
		if (nl > 0) 
		{
			Lap* lap = [laps objectAtIndex:0];
			float lapEndTime = [lap startingWallClockTimeDelta] + [track durationOfLap:lap];
			if (lapEndTime < [track duration])
			{
				for (int i=0; i<nl; i++)
				{
					NSString* s;
					if (i == (nl-1))
					{
						s = [NSString stringWithFormat:@"End of lap %d to finish", i];
					}
					else
					{
						s = [NSString stringWithFormat:@"Lap %d", i+1];
					}
					[lapsPopup addItemWithTitle:s];
				}
			}
		}
	}
}


-(void) setRegionSelected:(BOOL)yn
{
	regionSelected = yn;
	if (yn)
	{	
      [statsHUDWindow orderFront:self];
	}
	else
	{
      if ([showStatsHudButton state] == NSControlStateValueOff)
      {
         [statsHUDWindow orderOut:self];
      }
	}
}



#define kVAMTag		999

-(void)setHUDField:(NSTextField*)tf value:(float)v
{
	if (tf)
	{
		NSString* dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:v]];
		[tf setStringValue:[NSString stringWithFormat:@"%@", dispString]];
	}
}

	
-(void) updateStatsHUD
{
	if (!statsHUDWindow) return;
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	NSView* view = [statsHUDWindow contentView];
	///NSRect bounds = [view bounds];
	NSArray* pts = [graphView selectedPoints];
	NSTextField* tf;
	if ([pts count] > 0)
	{
		NSString* dispString;
		struct tStatData  statsArray[kST_NumStats];
		int offset = [graphView selectionPosIdxOffset];
		int startIdx = [graphView selectionStartIdx] + offset;
		int endIdx = [graphView selectionEndIdx] + offset;
		[track calculateStats:statsArray startIdx:startIdx endIdx:endIdx];

		TrackPoint* spt = [pts objectAtIndex:0];
		TrackPoint* ept = [pts objectAtIndex:[pts count]-1];
		//---- time
		//NSDate* sdate = [track creationTime];
		//NSTimeInterval stime = [[spt activeTime] timeIntervalSinceDate:sdate];
		//NSTimeInterval etime = [[ept activeTime] timeIntervalSinceDate:sdate];
		NSTimeInterval stime = [spt activeTimeDelta];
		NSTimeInterval etime = [ept activeTimeDelta];
		NSTimeInterval dtime = etime - stime;
		tf = [view viewWithTag:(340+0)];
		[tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d", ((int)stime)/3600, (((int)stime)/60) % 60, ((int)stime) % 60]]; 
		tf = [view viewWithTag:(340+1)];
		[tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d", ((int)etime)/3600, (((int)etime)/60) % 60, ((int)etime) % 60]]; 
		tf = [view viewWithTag:(340+2)];
		[tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d", ((int)dtime)/3600,  (((int)dtime)/60) % 60,((int)dtime) % 60]]; 

		//---- distance
		[numberFormatter setMaximumFractionDigits:1];
		float sd = [spt distance];
		float ed = [ept distance];
		[self setHUDField:[view viewWithTag:(330+0)]
					value:[Utils convertDistanceValue:sd]];
		[self setHUDField:[view viewWithTag:(330+1)]
					value:[Utils convertDistanceValue:ed]];
		[self setHUDField:[view viewWithTag:(330+2)]
					value:[Utils convertDistanceValue:ed-sd]];

		//---- altitude
		[numberFormatter setMaximumFractionDigits:0];
		float sa = [spt altitude];
		float ea = [ept altitude];
		[self setHUDField:[view viewWithTag:(320+0)]
					value:[Utils convertClimbValue:sa]];
		[self setHUDField:[view viewWithTag:(320+1)]
					value:[Utils convertClimbValue:ea]];
		[self setHUDField:[view viewWithTag:(320+2)]
					value:[Utils convertClimbValue:ea-sa]];

		// NOTE!!! ASSUMPTION HERE IS THAT THERE ARE THE SAME NUMBER OF NON-HR and HR ZONES 
		float zoneTimes[kNumHRZones+1];    // deadZone time is stored at index 0
		float totalZoneTime = 0.0;
		int zoneForHUD = [Utils intFromDefaults:RCBDefaultZoneTypeForStatsHUD];
		for (int i=0; i<kNumHRZones; i++)
		{
			if (zoneForHUD == 0)    // hr
			{
				zoneTimes[i+1] = [track timeInHRZoneForInterval:i start:startIdx end:endIdx];
			}
			else
			{
				zoneTimes[i+1] = [track timeInNonHRZoneForInterval:(zoneForHUD-1) zone:i start:startIdx end:endIdx];
			}
			totalZoneTime += zoneTimes[i+1];
		}
		float deadZoneTime = dtime - totalZoneTime;
		if (deadZoneTime < 0.0) deadZoneTime = 0.0;
		zoneTimes[0] = deadZoneTime;
		tStatData& aData = statsArray[kST_Altitude];
		[statsView setPlotData:pts 
					   minDist:sd
					   maxDist:ed
						minAlt:aData.vals[kMin]
						maxAlt:aData.vals[kMax]
						   hrz:zoneTimes
					  zoneType:zoneForHUD];
         
		float mxtime = 0.0;
	   
		//---- speed
		tStatData& spdData = statsArray[kST_Speed];

		float v = 0.0;
		int off = [graphView selectionPosIdxOffset];
		float dur = [track movingDurationBetweenGoodPoints:[graphView selectionStartIdx]+off
													   end:[graphView selectionEndIdx]+off]/(60.0 * 60.0);
		[numberFormatter setMaximumFractionDigits:1];
		if (dur != 0) v = (ed-sd)/dur;
		[self setHUDField:[view viewWithTag:(150+0)]
					value:[Utils convertSpeedValue:v]];
		[self setHUDField:[view viewWithTag:(150+1)]
					value:[Utils convertSpeedValue:spdData.vals[kMax]]];
		[self setHUDField:[view viewWithTag:(150+2)]
					value:[Utils convertSpeedValue:spdData.vals[kMin]]];
	   
		
		if (spdData.atActiveTimeDelta[kMax] != 0.0)
		{
			tf = [view viewWithTag:(150+3)];
			mxtime = spdData.atActiveTimeDelta[kMax];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:[Utils convertDistanceValue:spdData.vals[kDistanceAtMax]]]];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@", 
										((int)mxtime)/3600,  (((int)mxtime)/60) % 60, ((int)mxtime) % 60, dispString]]; 
		}

		//---- pace
		float avp, mxp, mnp;
		avp = mxp = mnp = -999.0;
		NSString *sav, *smx, *smn;
		sav = smx = smn = @"--";
		if (spdData.vals[kAvg] > 0.0) avp = (60.0*60)/[Utils convertSpeedValue:v];
		if (spdData.vals[kMax] > 0.0) mxp = (60.0*60)/[Utils convertSpeedValue:spdData.vals[kMax]];
		if (spdData.vals[kMin] > 0.0) mnp = (60.0*60)/[Utils convertSpeedValue:spdData.vals[kMin]];
		tf = [view viewWithTag:(140+0)];
		if (tf) [tf setStringValue:((avp == -999) ?  @"---" : [NSString stringWithFormat:@"%02d:%02d", ((int)(avp/60)) % 60, ((int)avp)%60])];
		tf = [view viewWithTag:(140+1)];
		if (tf) [tf setStringValue:((mxp == -999) ?  @"---" : [NSString stringWithFormat:@"%02d:%02d", ((int)(mxp/60)) % 60, ((int)mxp)%60])];
		tf = [view viewWithTag:(140+2)];
		if (tf) [tf setStringValue:((mnp == -999) ?  @"---" : [NSString stringWithFormat:@"%02d:%02d", ((int)(mnp/60)) % 60, ((int)mnp)%60])];
		if (spdData.atActiveTimeDelta[kMax] != 0.0)
		{
			tf = [view viewWithTag:(140+3)];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:[Utils convertDistanceValue:spdData.vals[kDistanceAtMax]]]];
            if (tf) {
                [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@",
                                    ((int)mxtime)/3600,
                                    (((int)mxtime)/60) % 60,
                                    ((int)mxtime) % 60,
                                    dispString]];
            }
		}

		//---- heart rate
		[numberFormatter setMaximumFractionDigits:0];
		tStatData& hrData = statsArray[kST_Heartrate];
		[self setHUDField:[view viewWithTag:(130+0)]
					value:hrData.vals[kAvg]];
		[self setHUDField:[view viewWithTag:(130+1)]
					value:hrData.vals[kMax]];
		[self setHUDField:[view viewWithTag:(130+2)]
					value:hrData.vals[kMin]];

		if (hrData.atActiveTimeDelta[kMax] != 0.0)
		{
			mxtime = hrData.atActiveTimeDelta[kMax];
			tf = [view viewWithTag:(130+3)];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat: [Utils convertDistanceValue:hrData.vals[kDistanceAtMax]]]];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@", 
										((int)mxtime)/3600,  (((int)mxtime)/60) % 60, ((int)mxtime) % 60,  dispString]]; 
		}

		//---- cadence
		[numberFormatter setMaximumFractionDigits:0];
		tStatData& cadData = statsArray[kST_Cadence];
		[self setHUDField:[view viewWithTag:(120+0)]
					value:cadData.vals[kAvg]];
		[self setHUDField:[view viewWithTag:(120+1)]
					value:cadData.vals[kMax]];
		[self setHUDField:[view viewWithTag:(120+2)]
					value:cadData.vals[kMin]];

		if (cadData.atActiveTimeDelta[kMax] != 0.0)
		{
			mxtime = cadData.atActiveTimeDelta[kMax];
			tf = [view viewWithTag:(120+3)];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat: [Utils convertDistanceValue:cadData.vals[kDistanceAtMax]]]];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@", 
										((int)mxtime)/3600,  (((int)mxtime)/60) % 60, ((int)mxtime) % 60,  dispString]]; 
		}

		//---- power
		[numberFormatter setMaximumFractionDigits:0];
		tStatData& pwrData = statsArray[kST_Power];
		[self setHUDField:[view viewWithTag:(110+0)]
					value:pwrData.vals[kAvg]];
		[self setHUDField:[view viewWithTag:(110+1)]
					value:pwrData.vals[kMax]];
		[self setHUDField:[view viewWithTag:(110+2)]
					value:pwrData.vals[kMin]];
		
		if (pwrData.atActiveTimeDelta[kMax] != 0.0)
		{
			mxtime = pwrData.atActiveTimeDelta[kMax];
			tf = [view viewWithTag:(110+3)];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat: [Utils convertDistanceValue:pwrData.vals[kDistanceAtMax]]]];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@", 
									   ((int)mxtime)/3600,  (((int)mxtime)/60) % 60, ((int)mxtime) % 60,  dispString]]; 
		}

		//---- gradient
		tStatData& grData = statsArray[kST_Gradient];
		[numberFormatter setMaximumFractionDigits:1];
		[self setHUDField:[view viewWithTag:(100+0)]
					value:grData.vals[kAvg]];
		[self setHUDField:[view viewWithTag:(100+1)]
					value:grData.vals[kMax]];
		[self setHUDField:[view viewWithTag:(100+2)]
					value:grData.vals[kMin]];
		if (grData.atActiveTimeDelta[kMax] != 0.0)
		{
			mxtime = grData.atActiveTimeDelta[kMax];
			tf = [view viewWithTag:(100+3)];
			[numberFormatter setMaximumFractionDigits:1];
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:[Utils convertDistanceValue:grData.vals[kDistanceAtMax]]]];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d/%@", 
										((int)mxtime)/3600,  (((int)mxtime)/60) % 60, ((int)mxtime) % 60,  dispString]]; 
		}

		//---- zones
		NSTimeInterval hztime;
		for (int i=0; i<=kNumHRZones; i++)
		{
			hztime = zoneTimes[i];
			tf = [view viewWithTag:(200 + (i*10))];
			if (tf) [tf setStringValue:[NSString stringWithFormat:@"%02.2d:%02.2d:%02.2d", ((int)hztime)/3600, (((int)hztime)/60) % 60, ((int)hztime) % 60]]; 
			tf = [view viewWithTag:(400 + (i*10))];
			if (tf) 
			{
				if (dtime > 0.0)
					[tf setStringValue:[NSString stringWithFormat:@"%3.0f%%", (hztime*100.0)/dtime]]; 
				else
					[tf setStringValue:@""]; 
			}
		}

		//---- climb/descent
		[numberFormatter setMaximumFractionDigits:0];
		[track calculateStats:statsArray startIdx:0 endIdx:endIdx];
		tStatData& altData = statsArray[kST_ClimbDescent];
		float eclimb = [Utils convertClimbValue:altData.vals[kMax]];
		float edescent = [Utils convertClimbValue:altData.vals[kMin]];

		[self setHUDField:[view viewWithTag:(310+1)]
					value:eclimb];
		[self setHUDField:[view viewWithTag:(300+1)]
					value:edescent];

		[track calculateStats:statsArray startIdx:0 endIdx:startIdx];
		float sclimb = [Utils convertClimbValue:altData.vals[kMax]];
		float sdescent = [Utils convertClimbValue:altData.vals[kMin]];
		[self setHUDField:[view viewWithTag:(310+0)]
					value:sclimb];
		[self setHUDField:[view viewWithTag:(300+0)]
					value:sdescent];
		[self setHUDField:[view viewWithTag:(310+2)]
					value:eclimb-sclimb];
		[self setHUDField:[view viewWithTag:(300+2)]
					value:edescent-sdescent];
	

		// update VAM
		float vam = 0.0;
		tf = [view viewWithTag:kVAMTag];
		if (tf) 
		{
			int digits = useStatuteUnits ? 0 : 1;
			[numberFormatter setMaximumFractionDigits:digits];
			if (dtime > 0.0) vam = (eclimb-sclimb)*(60.0*60.0)/dtime;
			NSString* units = (useStatuteUnits ? @"ft/hr" : @"m/hr");
			dispString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:vam]];
			[tf setStringValue:[NSString stringWithFormat:@"%@ %@", dispString, units]];
		}
   }
}


-(void) updateSelectionInfo:(int)ptIdx
{
	if (ptIdx == -1)
	{
		if (regionSelected)
			[self setRegionSelected:NO];
	}
	else
	{
		if (!regionSelected)
		{
			[self setRegionSelected:YES];
		}
	}
   [self updateStatsHUD];
}


struct tHUDStringInfo
{
   const char*       text;
   tPlotType         pt;
   NSTextAlignment   align;
   float             colw;
   float             x, y;
};

#define kTimeInZoneTextFieldBaseTag			200
#define kPercentInZoneTextFieldBaseTag		400
#define kZoneRangeTextFieldBaseTag			600
#define kStatsHUDRowNamesBaseTag			2000

static tHUDStringInfo sHUDStringInfo[] = 
{
	{ "avg rate of climb (VAM):", kReserved,  NSTextAlignmentRight,         wVAM,    xVAM,				  yVAM             },
	{ "start",                    kReserved,  NSTextAlignmentLeft,          wSED,    xCOL1,               ySED + (5*hudTH) },
	{ "end",                      kReserved,  NSTextAlignmentLeft,          wSED,    xCOL1 + (1*wSED),    ySED + (5*hudTH) },
	{ "\xE2\x88\x86",             kReserved,  NSTextAlignmentLeft,          wSED,    xCOL1 + (2*wSED),    ySED + (5*hudTH) },
	{ "time:",                    kReserved,  NSTextAlignmentRight,         col0W,   xCOL0,               ySED + (4*hudTH) },
	{ "distance",                 kDistance,  NSTextAlignmentRight,         col0W,   xCOL0,               ySED + (3*hudTH) },
	{ "altitude",                 kAltitude,  NSTextAlignmentRight,         col0W,   xCOL0,               ySED + (2*hudTH) },
	{ "climb",                    kAltitude,  NSTextAlignmentRight,         col0W,   xCOL0,               ySED + (1*hudTH) },
	{ "descent",                  kAltitude,  NSTextAlignmentRight,         col0W,   xCOL0,               ySED + (0*hudTH) },
	{ "avg",                      kReserved,  NSTextAlignmentLeft,          wAMM,    xCOL1,               yAMM + (6*hudTH) },
	{ "max",                      kReserved,  NSTextAlignmentLeft,          wAMM,    xCOL1 + (1*wAMM),    yAMM + (6*hudTH) },
	{ "min",                      kReserved,  NSTextAlignmentLeft,          wAMM,    xCOL1 + (2*wAMM),    yAMM + (6*hudTH) },
	{ "max time/dist",            kReserved,  NSTextAlignmentLeft,          100.0,   xCOL1 + (3*wAMM),    yAMM + (6*hudTH) },
	{ "speed",                    kAvgSpeed,  NSTextAlignmentRight,         col0W,   xCOL0,               yAMM + (5*hudTH) },
	{ "pace",                     kAvgPace,   NSTextAlignmentRight,         col0W,   xCOL0,               yAMM + (4*hudTH) },
	{ "heart rate:",              kHeartrate, NSTextAlignmentRight,         col0W,   xCOL0,               yAMM + (3*hudTH) },
	{ "cadence:",                 kCadence,   NSTextAlignmentRight,         col0W,   xCOL0,               yAMM + (2*hudTH) },
    { "power:",                   kPower,     NSTextAlignmentRight,         col0W,   xCOL0,               yAMM + (1*hudTH) },
	{ "gradient:",                kGradient,  NSTextAlignmentRight,         col0W,   xCOL0,               yAMM },
	{ "time in ",                 kReserved,  NSTextAlignmentLeft,          150.0,   xCOL1,               yHR + (6*hudTH)  },
    { "5",							kReserved,  NSTextAlignmentLeft,         13.0,   7.0,               yHR + (5*hudTH)  },
	{ "4",							kReserved,  NSTextAlignmentLeft,         13.0,   7.0,               yHR + (4*hudTH)  },
	{ "3",							kReserved,  NSTextAlignmentLeft,         13.0,   7.0,               yHR + (3*hudTH)  },
	{ "2",							kReserved,  NSTextAlignmentLeft,         13.0,   7.0,               yHR + (2*hudTH)  },
	{ "1",							kReserved,  NSTextAlignmentLeft,         13.0,   7.0,               yHR + (1*hudTH)  },
#if 0
	{ "Below Zone 1:",            kReserved,  NSTextAlignmentRight,         col0W,   xCOL0,               yHR              },
#endif
    { "option-drag with mouse to select region",  kReserved,  NSTextAlignmentCenter, statsHUDW,   0.0,    2.0              }
};
      

-(void)changeZoneTypeInStatsHUD:(id)sender
{
	int zoneType = (int)[sender indexOfSelectedItem];
	[Utils setIntDefault:zoneType
				  forKey:RCBDefaultZoneTypeForStatsHUD];
	NSArray* rangeStrings = [Utils rangeStringsForZoneType:zoneType];
	for (int i=0; i<=kNumHRZones; i++)
	{
		NSTextField* textField = [[statsHUDWindow contentView] viewWithTag:(kZoneRangeTextFieldBaseTag + (i*10))];
		[textField setStringValue:[rangeStrings objectAtIndex:(kNumHRZones- i)]];
	}
	[self updateStatsHUD];
}

#define MENU_BAR_HEIGHT		64
-(void)updateStatsHUDPrompts
{
	if (!statsHUDWindow) return;
	int num = sizeof(sHUDStringInfo)/sizeof(tHUDStringInfo);
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	NSView* cv = [statsHUDWindow contentView];
	NSFont* font = [NSFont systemFontOfSize:10];
	for (int i=0; i<num; i++)
	{
		const tHUDStringInfo& hinfo = sHUDStringInfo[i];
		int tag = kStatsHUDRowNamesBaseTag+i;
		NSTextField *textField = [cv viewWithTag:tag];
		if (!textField) 
		{
			textField = [[NSTextField alloc] initWithFrame:NSMakeRect(hinfo.x, hinfo.y,
																	   hinfo.colw, hudTH)];
			[cv addSubview:textField];
			[textField setEditable:NO];
			[textField setTextColor:[[NSColor colorNamed:@"TextPrimary"] colorWithAlphaComponent:0.7]];
			[textField setDrawsBackground:NO];
			[textField setBordered:NO];
			[textField setAlignment:hinfo.align];
			[textField setFont:font];
			[textField setTag:tag];
		}
		const char* units;
		switch (hinfo.pt)
		{
			case kAvgSpeed:
				units = useStatuteUnits ? "mph" : "km/h";
				break;
				
			case kAvgPace:
				units = useStatuteUnits ? "min/mi" : "min/km";
				break;
				
			case kAltitude:
				units = useStatuteUnits ? "ft" : "m";
				break;
				
			case kDistance:
				units = useStatuteUnits ? "mi" : "km";
				break;
                
            default:
                units = 0;
                break;
		}
        NSMutableString* s = [NSMutableString stringWithCapacity:8];
        [s appendString:[NSString stringWithUTF8String:hinfo.text]];
		if (units != 0)
		{
			[s appendString:[NSString stringWithFormat:@"(%s)", units]];
		}
        [s appendString:@":"];
        [textField setStringValue:s];
	}
}


-(void) createStatsHUD
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	NSFont* font = [NSFont systemFontOfSize:10];
	hudTextAttrs = [[NSMutableDictionary alloc] init];
	[hudTextAttrs setObject:font forKey:NSFontAttributeName];
	// Make a rect to position the window at the top-right of the screen.
	NSSize windowSize = NSMakeSize(statsHUDW, statsHUDH);
	NSSize screenSize = [[NSScreen mainScreen] frame].size;
	NSRect windowFrame = NSMakeRect(screenSize.width - windowSize.width - 10.0, 
								   screenSize.height - windowSize.height - MENU_BAR_HEIGHT - 10.0, 
								   windowSize.width, windowSize.height);

	// Create a HUDWindow.
	// Note: the styleMask is ignored; NSWindowStyleMaskBorderless is always used.
	statsHUDWindow = [[HUDWindow alloc] initWithContentRect:windowFrame 
										 styleMask:NSWindowStyleMaskBorderless 
										   backing:NSBackingStoreBuffered 
											 defer:NO];

	NSRect statsViewFrame = windowFrame;
	statsViewFrame.origin = NSMakePoint(0,0);
	statsView = [[ADStatsView alloc] initWithFrame:statsViewFrame];
	[statsHUDWindow setContentView:statsView];
	[statsHUDWindow addCloseWidget];
	[statsHUDWindow setAlphaValue:[Utils floatFromDefaults:RCBDefaultStatsHUDTransparency]];

	// Add some text to the window.
	[self updateStatsHUDPrompts];
	
	// add empty text fields for start/end/delta data
	for (int col=0; col<3; col++)
	{
	  for (int row=0; row<5; row++)
	  {
		 NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(startX+(col*wSED), ySED+(row*hudTH),
																				wSED, hudTH)];
		 [[statsHUDWindow contentView] addSubview:textField];
		 [textField setEditable:NO];
		 [textField setTextColor:[NSColor  colorNamed:@"TextPrimary"]];
		 [textField setDrawsBackground:NO];
		 [textField setBordered:NO];
		 [textField setAlignment:NSTextAlignmentLeft];
		 [textField setStringValue:@""];
		 [textField setTag:300+(row*10)+col];
		 [textField setFont:font];
	  }
	}

	int ctags[6];
	ctags[4] = ctags[5] = kSpeed;
	ctags[3] = kHeartrate;
	ctags[2] = kCadence;
	ctags[1] = kPower;
	ctags[0] = kGradient;

	// add empty text fields for avg/max/min data
	for (int row=0; row<6; row++)
	{
	  NSRect r;
	  r.size.width = 11.0;
	  r.size.height = 11.0;
	  r.origin = NSMakePoint(7.0, yAMM+(row*hudTH) + 2.0);
	  ColorBoxView* cb = [[ColorBoxView alloc] initWithFrame:r];
	  r.origin.x = r.origin.y = 0.0;
	  [cb setBounds:r];
	  [cb setTag:ctags[row]];
	  [cb setAlpha:0.5];
	  [[statsHUDWindow contentView] addSubview:cb];
	  [cb setNeedsDisplay:YES];
	  
	  for (int col=0; col<4; col++)
	  {
		 NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(avgX+(col*wAMM), yAMM+(row*hudTH),
																				(col==3) ? 100.0 : wAMM, hudTH)];
		 [[statsHUDWindow contentView] addSubview:textField];
		 [textField setEditable:NO];
		 [textField setTextColor:[NSColor colorNamed:@"TextPrimary"]];
		 [textField setDrawsBackground:NO];
		 [textField setBordered:NO];
		 [textField setAlignment:NSTextAlignmentLeft];
		 [textField setStringValue:@""];
		 [textField setTag:(100 + (row*10))+col];
		 [textField setFont:font];
	  }
	}

	int zoneType = [Utils intFromDefaults:RCBDefaultZoneTypeForStatsHUD];
	NSArray* rangeStrings = [Utils rangeStringsForZoneType:zoneType];
	
	// add empty text fields for hrzone data + 1 more for dead time
	for (int row=0; row<=kNumHRZones; row++)
	{
		// TimeInZone text field
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(hrzX, yHR+(row*hudTH),
																			 wHR, hudTH)];
		[[statsHUDWindow contentView] addSubview:textField];
		[textField setEditable:NO];
		[textField setTextColor:[NSColor colorNamed:@"TextPrimary"]];
		[textField setDrawsBackground:NO];
		[textField setBordered:NO];
		[textField setAlignment:NSTextAlignmentLeft];
		[textField setStringValue:@""];
		[textField setTag:(kTimeInZoneTextFieldBaseTag + (row*10))];
		[textField setFont:font];

		// now for the %in hr zone text
		textField = [[NSTextField alloc] initWithFrame:NSMakeRect(hrzXPercentColX, yHR+(row*hudTH),
																  50.0, hudTH)];
		[[statsHUDWindow contentView] addSubview:textField];
		[textField setEditable:NO];
		[textField setTextColor:[NSColor whiteColor]];
		[textField setDrawsBackground:NO];
		[textField setBordered:NO];
		[textField setAlignment:NSTextAlignmentRight];
		[textField setTag:(kPercentInZoneTextFieldBaseTag + (row*10))];
		[textField setFont:font];
		
		// Zone Range text field
		textField = [[NSTextField alloc] initWithFrame:NSMakeRect(20.0, yHR+(row*hudTH),
																  col0W-8.0, hudTH)];
		[[statsHUDWindow contentView] addSubview:textField];
		[textField setEditable:NO];
		[textField setTextColor:[NSColor colorNamed:@"TextPrimary"]];
		[textField setDrawsBackground:NO];
		[textField setBordered:NO];
		[textField setAlignment:NSTextAlignmentRight];
		[textField setStringValue:[rangeStrings objectAtIndex:(kNumHRZones - row)]];
		[textField setTag:(kZoneRangeTextFieldBaseTag + (row*10))];
		[textField setFont:font];
	}

	// add text field for VAM
	NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(xVAM+wVAM+2.0, yVAM,
																		  80.0, hudTH)];
	[[statsHUDWindow contentView] addSubview:textField];
	[textField setEditable:NO];
	[textField setTextColor:[NSColor colorNamed:@"TextPrimary"]];
	[textField setDrawsBackground:NO];
	[textField setBordered:NO];
	[textField setAlignment:NSTextAlignmentLeft];
	[textField setStringValue:@""];
	[textField setTag:kVAMTag];
	[textField setFont:font];


	// add popup for zone type
	NSPopUpButton *ztpopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(154.0, yHR+(6*hudTH), 80.0, hudTH)];
	float fontSize = [NSFont systemFontSizeForControlSize:NSControlSizeMini];
	NSCell *theCell = [ztpopup cell];
	NSFont *theFont = [NSFont fontWithName:[[theCell font] fontName] size:fontSize];
	[theCell setFont:theFont];   
	[theCell setControlSize:NSControlSizeMini];
	[ztpopup addItemWithTitle:@"Heart Rate Zones"];
	[ztpopup addItemWithTitle:@"Speed Zones"];
	[ztpopup addItemWithTitle:@"Pace Zones"];
	[ztpopup addItemWithTitle:@"Gradient Zones"];
	[ztpopup addItemWithTitle:@"Cadence Zones"];
	[ztpopup addItemWithTitle:@"Altitude Zones"];
	[ztpopup addItemWithTitle:@"Power Zones"];
	[ztpopup sizeToFit];
	[ztpopup selectItemAtIndex:zoneType];
	[ztpopup setAction:@selector(changeZoneTypeInStatsHUD:)];
			
	[[statsHUDWindow contentView] addSubview:ztpopup];
	  
	// Set the window's title and display it.
	[statsHUDWindow setTitle:@"Activity Statistics HUD"];
	[statsHUDWindow setFloatingPanel:YES];
	[statsHUDWindow setHasShadow:YES];
	[statsHUDWindow orderOut:self];
}


// update the Data HUD during animation or as the user drags the HUD over the view
-(void) updateDataHUD:(TrackPoint*)tpt x:(CGFloat)x y:(CGFloat)y altitude:(CGFloat)alt
{
	NSPoint p = NSMakePoint(x,y);
	NSPoint cp = [graphView convertPoint:p toView:nil];      // to window coords
	cp.x += 10.0;
	cp.y += 20.0;
	[dataHUDWC updateDataHUD:[[graphView window] convertPointToScreen:cp]
				  trackPoint:tpt
					altitude:alt];
}


-(void) createDataHUD
{
	dataHUDWC = [[DataHUDWindowController alloc] initWithSize:NSMakeSize(0.0, 0.0)];
}


- (IBAction) setStatsHUDLocked:(id) sender
{
   if ([sender state] == NSControlStateValueOn)
   {
      [statsHUDWindow orderFront:self];
   }
   else
   {
      [statsHUDWindow orderOut:self];
   }
   [self updateStatsHUD];
}


- (BOOL) statsHUDLocked
{
   return [showStatsHudButton state] == NSControlStateValueOn;
}


- (IBAction) setDataHUDOpacity:(id) sender
{
	float v = [sender floatValue];
	[[dataHUDWC window] setAlphaValue:v];
	[[dataHUDWC window] display];
	[Utils setFloatDefault:v forKey:RCBDefaultDataHUDTransparency];
}


- (IBAction) setStatsHUDOpacity:(id) sender
{
   float v = [sender floatValue];
   [statsHUDWindow setAlphaValue:v];
   [statsHUDWindow display];
   [Utils setFloatDefault:v forKey:RCBDefaultStatsHUDTransparency];
}


- (IBAction) setZonesOpacity:(id) sender
{
   float v = [sender floatValue];
   [graphView setZonesOpacity:v];
   [Utils setFloatDefault:v forKey:RCBDefaultZonesTransparency];
}


- (float) dataHUDOpacity
{
   return [Utils floatFromDefaults:RCBDefaultDataHUDTransparency];
}


- (float) statsHUDOpacity
{
   return [Utils floatFromDefaults:RCBDefaultStatsHUDTransparency];
}


- (BOOL) dataHUDActive
{
   return [Utils boolFromDefaults:RCBDefaultShowADHUD];
}


- (IBAction) setShowDataHUD:(id) sender
{
   BOOL on = [sender state] == NSControlStateValueOn;
   if (on)
   {
      [[self window] addChildWindow:(NSWindow*)[dataHUDWC window] ordered:NSWindowAbove];
   }
   else
   {
      [[self window] removeChildWindow:[dataHUDWC window] ];
      [[dataHUDWC window]  orderOut:self];
   }
   [graphView setNeedsDisplay:YES];
   [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowADHUD];
}



-(void) awakeFromNib
{
	useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"ADWindowFrame"];
	if (![[self window] setFrameUsingName:@"ADWindowFrame"])
	{
		[[self window] center];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(endAnimation:)
												name:@"ADAnimationEnded"
											  object:nil];
	[settingsDrawer setDelegate:self];


	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(trackChanged:)
												 name:@"TrackChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(trackChanged:)
												 name:@"TrackEdited"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(markersChanged:)
												 name:@"MarkersChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChanged
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(HUDClosed:)
												 name:@"HUDClosed"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(trackArrayChanged:)
												 name:TrackArrayChangedNotification
											   object:nil];
	[[AnimTimer defaultInstance] registerForTimerUpdates:self];

	[graphView setTransparentView:transparentView];
	BOOL xAxisIsTime = [Utils intFromDefaults:RCBDefaultXAxisType] > 0 ? YES : NO;
	[graphView setXAxisIsTime:xAxisIsTime];

	[graphView setShowCrossHairs:[graphView showCrossHairs]];
	[xAxisTypePopup selectItemAtIndex:([graphView xAxisIsTime] ? 1 : 0)];
	[speedPacePopup selectItemAtIndex:([graphView showPace] ? 1 : 0)];
	[self positionEverything];
	[self rebuildActivitySelectorPopup];
	
	SEL sel = @selector(buildContextualMenu);
	NSMethodSignature* sig = [ActivityWindowController instanceMethodSignatureForSelector:sel];
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[graphView setContextualMenuInvocation:inv];

	sel = @selector(updateSelectionInfo:);
	sig = [ActivityWindowController instanceMethodSignatureForSelector:sel];
	inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[graphView setSelectionUpdateInvocation:inv];

	sel = @selector(updateDataHUD:x:y:altitude:);
	sig = [ActivityWindowController instanceMethodSignatureForSelector:sel];
	inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[graphView setDataHudUpdateInvocation:inv];
   
	[self buildLapPopUp];
	[self createStatsHUD];
	[self createDataHUD];
	[self setFormatsForDataHUD];
   
	[dataHUDOpacitySlider  setFloatValue:[Utils floatFromDefaults:RCBDefaultDataHUDTransparency]];
	[statsHUDOpacitySlider setFloatValue:[Utils floatFromDefaults:RCBDefaultStatsHUDTransparency]];
	if ([graphView acceptsFirstResponder])
	{
		[[self window] makeFirstResponder:graphView];
	}
	
}


- (void)windowDidMove:(NSNotification *)aNotification
{
   [self positionEverything];
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
   //[dataHUDWindow orderOut:self];
   [transparentView  setHidden:YES];
   return proposedFrameSize;
}


- (void)windowDidResize:(NSNotification *)aNotification
{
   [self positionEverything];
}


- (void)windowWillMove:(NSNotification *)aNotification
{
   //[dataHUDWindow orderOut:self];
}


- (IBAction) selectTrack:(id) sender
{
    [self setTrack:[[tbDocument trackArray] objectAtIndex:[sender indexOfSelectedItem]]]; 
	[self buildLapPopUp];
	[lapsPopup selectItemAtIndex:0];
    [[AnimTimer defaultInstance] updateTimerDuration];
    [self updateStatsHUD];
}


- (IBAction) selectLap:(id) sender
{
	int idx = (int)[sender indexOfSelectedItem];
	Lap* lap = nil;
	if ((idx > 0) && (track != nil) && (idx <= [[track laps] count]))
	{
		lap = [[track laps] objectAtIndex:idx-1];
	}
	[graphView setLap:lap];
   [self updateStatsHUD];
}


- (void)setLap:(Lap*)lp
{
	int idx = [track findLapIndex:lp];
	if (idx >= 0)
	{
		[lapsPopup selectItemAtIndex:idx+1];
		[graphView setLap:lp];
	}
}


- (void) updatePeakControls:(BOOL)on
{
   [peakThresholdField setEnabled:on];
   [peakThresholdStepper setEnabled:on];
   [numberOfPeaksField setEnabled:on];
   [numberOfPeaksStepper setEnabled:on];
   [peakTypePopup setEnabled:on];
   [peakTypePopup selectItemWithTag:[graphView peakType]];
}

#define kStartingPeakPowerCheckboxTag		10000

- (void)drawerWillOpen:(NSNotification *)notification
{
   // update controls in the drawer
   NSArray* subviews = [[settingsDrawer contentView] subviews];
    NSUInteger num = [subviews count];
   for (int i=0; i<num; i++)
   {
      id view = [subviews objectAtIndex:i];
      int tag = (int)[view tag];
      if (tag >= kMinimumPlotTag && (tag < kStartingPeakPowerCheckboxTag))
      {
         tPlotType type = tagToPlotType(tag);
         int component = tagToComponent(tag);
         PlotAttributes* pa = [[graphView plotAttributesArray] objectAtIndex:(int)type];
         if (pa != nil) 
         {
            switch (component)
            {
               case kEnabledControl:
                  [view setIntValue:[pa enabled] ? 1 : 0];
                  break;
                  
               case kFillEnabledControl:
                  [view setIntValue:[pa fillEnabled] ? 1 : 0];
                  break;
                  
               case kLineStyleControl:
               {
                  NSPopUpButton* button = view;
                  [button removeAllItems];
                  [button addItemWithTitle:@""];
                  [button addItemWithTitle:@""];
                  [button addItemWithTitle:@""];
                  NSString* path = [[NSBundle mainBundle] pathForResource:@"line_solid_1" ofType:@"png"];
				   NSImage* img = [[NSImage alloc] initWithContentsOfFile:path];
                  [[button itemAtIndex:0] setImage:img];
                  path = [[NSBundle mainBundle] pathForResource:@"line_solid_2" ofType:@"png"];
                  img = [[NSImage alloc] initWithContentsOfFile:path];
                  [[button itemAtIndex:1] setImage:img];
                  path = [[NSBundle mainBundle] pathForResource:@"line_solid_3" ofType:@"png"];
                  img = [[NSImage alloc] initWithContentsOfFile:path];
                  [[button itemAtIndex:2] setImage:img];
                  [view selectItemAtIndex:[pa lineStyle]];
                  break;
               }
               case kOpacityControl:
                  [view setFloatValue:[pa opacity]];
                  break;
                  
               case kColorControl:
                  [view setColor:[pa color]];
                  break;
                  
               default:
                  break;
            }
         }
      }
   }
   // draw color boxes showing current color prefs for each graph type and background, etc
   if (!drawerColorBoxesCreated)
   {
      int numPlots = [graphView numPlotTypes];
      for (int i=0; i < numPlots; i++)
      {
         int type = [graphView plotType:i];
         if (type != kReserved)
         {
            NSPoint pt = [graphView plotControlPosition:i];
            ColorBoxView* cb = [[[ColorBoxView alloc] init] autorelease];
            NSRect r;
            r.size.width = 14.0;
            r.size.height = 14.0;
            r.origin = pt;
            [cb setFrame:r];
            r.origin.x = r.origin.y = 0.0;
            [cb setBounds:r];
            [cb setTag:type];
            [colorBoxes addObject:cb];
            [[settingsDrawer contentView] addSubview:cb];
            [cb setNeedsDisplay:YES];
         }
      }
      drawerColorBoxesCreated = YES;
	}
	// update control pointers that exist in the settings drawer, they may not exist until the drawer first opens
	numberOfPeaksStepper = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kNumPeaksControl)];
	numberOfPeaksField = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kNumPeaksTextControl)];
	peakThresholdStepper = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kPeakThresholdControl)];
	peakThresholdField = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kPeakThresholdTextControl)];
	peakTypePopup = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kPeakTypeControl)];
	showMarkersButton = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kShowMarkersEnabledControl)];
	showLapsButton = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kShowLapsEnabledControl)];
	showPeaksButton = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kShowPeaksEnabledControl)];
	showHeartrateZonesButton = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kShowHeartrateZonesControl)];
	numAvgPointsStepper = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kNumPointsToAverageControl)];
	numAvgPointsField = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kNumPointsToAverageTextControl)];
	showCrossHairsButton =  [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kCrosshairsEnabledControl)];
	zonesOpacitySlider =  [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kAltitude,kZonesOpacityControl)];

	[Utils buildPopupMenuFromItemList:[Utils graphItemList] popup:peakTypePopup];
	[Utils buildPopupMenuFromItemList:[Utils graphItemList] popup:dataRectTypePopup];
	//[Utils buildPeakIntervalsPopup:peakPowerIntervalsPopup];
	int tag = kStartingPeakPowerCheckboxTag;
	NSDictionary* dict = [Utils peakPowerIntervalInfoDict];
	if (dict)
	{
		NSArray* keys = [dict allKeys];
		keys = [keys sortedArrayUsingSelector:@selector(compareAsNumbers:)];
        NSUInteger numIntervals = [keys count];
		int i = 0;
		NSButton* v;
		BOOL canShowPower = [track activityIsValidForPowerCalculation];
		while ((v = [[settingsDrawer contentView] viewWithTag:tag]) && (i<numIntervals))
		{
			NSString* k = [keys objectAtIndex:i]; 
			NSNumber* enabledNum = [dict objectForKey:k];
			BOOL enabled = [enabledNum boolValue];
			[v setTitle:[Utils friendlyIntervalAsString:[k intValue]]];
			[v setState:enabled ? NSControlStateValueOn : NSControlStateValueOff];
			[v setEnabled:canShowPower];
			 ++tag;
			 ++i;
		}
	}
}


- (void)drawerDidOpen:(NSNotification *)notification
{
	[showLapsButton setState:[graphView showLaps] ? NSControlStateValueOn : NSControlStateValueOff];
	[showMarkersButton setState:[graphView showMarkers] ? NSControlStateValueOn : NSControlStateValueOff];
	[showPeaksButton setState:[graphView showPeaks] ? NSControlStateValueOn : NSControlStateValueOff];
	[showPeakPowerIntervalsButton setState:[graphView showPowerPeakIntervals] ? NSControlStateValueOn : NSControlStateValueOff];
	[numberOfPeaksStepper setIntValue:[graphView numPeaks]];   
	[numberOfPeaksField setIntValue:[graphView numPeaks]];   
	[numAvgPointsField setIntValue:[graphView numAvgPoints]];   
	[numAvgPointsStepper setIntValue:[graphView numAvgPoints]];   
	[peakThresholdStepper setIntValue:[graphView peakThreshold]];   
	[peakThresholdField setIntValue:[graphView peakThreshold]];   
	[showHeartrateZonesButton setState:[graphView showHeartrateZones]];
	[showCrossHairsButton setState:[graphView showCrossHairs]];
	[self updatePeakControls:[graphView showPeaks]];
	[dataRectTypePopup selectItemWithTag:[graphView dataRectType]];
	[zoneTypePopup selectItemWithTag:[Utils intFromDefaults:RCBDefaultZoneInActivityDetailViewItem]];
	[zonesOpacitySlider setFloatValue:[Utils floatFromDefaults:RCBDefaultZonesTransparency]];
}


- (void)windowDidLoad
{
    BOOL show = [Utils boolFromDefaults:RCBDefaultShowADHUD];
    if (show)
    {
        [[self window] addChildWindow:(NSWindow*)[dataHUDWC window] ordered:NSWindowAbove];
    }
    else
    {
        [[dataHUDWC window] orderOut:self];
    }
    [showDataHudButton setState:show];
    
    // spacebar handling
    __block __weak ActivityWindowController *weakSelf = self; // weak to avoid retain-cycle with block
    _keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                       handler:^NSEvent * (NSEvent *e)
    {
        ActivityWindowController *self = weakSelf;
        if (!self) return e;

        if (e.window == self.window) {
            NSString *s = [e charactersIgnoringModifiers];
            if ([s isEqualToString:@" "]) {
                // optional: ignore if typing in a text view
                NSResponder *r = e.window.firstResponder;
                if (![r isKindOfClass:[NSTextView class]]) {
                    [[AnimTimer defaultInstance] togglePlay];   // your action
                    return nil; // swallow the space so it doesn’t trigger anything else
                }
            }
        }
        return e; // let other keys flow
    }];

}


- (void)fade:(NSTimer *)theTimer
{
    if ([[self window] alphaValue] > 0.0) {
        // If window is still partially opaque, reduce its opacity.
        [[self window]  setAlphaValue:[[self window]  alphaValue] - 0.2];
    } else {
        // Otherwise, if window is completely transparent, destroy the timer and close the window.
        [_fadeTimer invalidate];
        self.fadeTimer = nil;

        if ([self.customDelegate respondsToSelector:@selector(activityWindowControllerDidClose:)]) {
            [self.customDelegate activityWindowControllerDidClose:self];
        }
        [[self window]  close];

        // Make the window fully opaque again for next time.
        [[self window]  setAlphaValue:1.0];
    }
}


- (BOOL)windowShouldClose:(id)sender
{
    // Set up our timer to periodically call the fade: method.
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                      target:self
                                                    selector:@selector(fade:)
                                                    userInfo:nil repeats:YES];
   
    return NO;
}


- (void)windowWillClose:(NSNotification *)aNotification
{

    [statsHUDWindow orderOut:self];
    [[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
    if (editMarkersController != nil)
    {
        [[editMarkersController window] orderOut:[self window]];
    }
    if ([self document])
    {
        // 1. Get a safe reference to the document (no retain necessary, it's a weak/assign property)
        NSDocument *theDocument = [self document];

        // 2. Remove self from the NSDocument's list of window controllers
        [theDocument removeWindowController:self];

        // 3. Since the NSDocument is no longer retaining the NSWindowController (self),
        // and assuming this controller does not own any other object retaining it,
        // the NSWindowController will be deallocated after this method returns
        // and the autorelease pool drains.
    }
}


- (IBAction) openDrawer:(id) sender
{
   [settingsDrawer toggle:self];
}


- (IBAction) closeDrawer:(id) sender
{
   [settingsDrawer toggle:self];
}


- (Track*)track
{
   return track;
}
 
 
- (void)setTrack:(Track*)t
{
	if (t != track)
	{
		[track release]; 
		track = t;
		[track retain];
	}
	[self buildLapPopUp];
	if ((activitySelectorPopup != nil) && (track != nil))
	{
		//[activitySelectorPopup setTitle:[Utils buildTrackDisplayedName:track prePend:@""]]; 
		NSUInteger idxOfSelected = [[tbDocument trackArray] indexOfObjectIdenticalTo:track];
		if (idxOfSelected != NSNotFound)
		{
			[activitySelectorPopup selectItemAtIndex:idxOfSelected];
			NSString* title = [activitySelectorPopup itemTitleAtIndex:idxOfSelected];
			[activitySelectorPopup setTitle:title];
		}
		[[self window] setTitle:[Utils buildTrackDisplayedName:track prePend:@"Activity Detail - "]];
	}
	[t calculatePower];
	
	if (![t hasDistanceData])
	{
		[graphView setXAxisIsTime:YES];
		[xAxisTypePopup selectItemAtIndex:1];
	}
	[graphView setTrack:t
			forceUpdate:YES];
	[graphView setNeedsDisplay:YES];
	NSArray* pts = [track goodPoints];
	NSTimeInterval atime = 0.0;
    NSUInteger np = [pts count];
	if (np > 0)
	{
		TrackPoint* lastPoint = [pts objectAtIndex:(np-1)];
		TrackPoint* firstPoint = [pts objectAtIndex:0];
		//NSTimeInterval mx = [[lastPoint activeTime] timeIntervalSinceDate:[firstPoint activeTime]];
		NSTimeInterval mx = [lastPoint activeTimeDelta] - [firstPoint activeTimeDelta];
		NSTimeInterval cur = [[AnimTimer defaultInstance] animTime];
		if (cur <= mx)
		{
			atime = cur;
		}
	}
	[[AnimTimer defaultInstance] setAnimTime:atime];
}


- (IBAction) setPlotEnabled:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
     int type = (int)tagToPlotType((int)[sender tag]);
   [graphView setPlotEnabled:(tPlotType)type
					 enabled:on
			  updateDefaults:YES];
}


- (IBAction) setPlotFillEnabled:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
    int type = (int)tagToPlotType((int)[sender tag]);
   PlotAttributes* pa = [[graphView plotAttributesArray] objectAtIndex:type];
   [pa setFillEnabled:on];
   [graphView setNeedsDisplay:YES];
}


- (IBAction) setPlotOpacity:(id) sender
{
   [graphView setPlotOpacity:tagToPlotType((int)[sender tag]) opacity:[sender floatValue]];
}


- (IBAction) setPlotColor:(id) sender
{
   [graphView setPlotColor:tagToPlotType((int)[sender tag]) color:[sender color]];
}


- (IBAction) setPlotLineStyle:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL state = (btn.state  == NSControlStateValueOn) ? YES : NO;
   int type = tagToPlotType((int)[sender tag]);
   PlotAttributes* pa = [[graphView plotAttributesArray] objectAtIndex:type];
   [pa setLineStyle:state];
   [graphView setNeedsDisplay:YES];
   NSMutableString* key = [NSMutableString stringWithString:[pa defaultsKey]];
   [key appendString:@"LineStyle"];
   [Utils setIntDefault:state
                 forKey:key];
}


- (IBAction) setShowMarkers:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
    [graphView setShowMarkers:on];
    [graphView setNeedsDisplay:YES];
    [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowMarkers];
}


- (IBAction) setShowPowerPeakIntervals:(id)sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
	[graphView setShowPowerPeakIntervals:on];
	[graphView setNeedsDisplay:YES];
	[Utils setBoolDefault:on 
				   forKey:RCBDefaultShowPowerPeakIntervals];
}


- (IBAction) setShowLaps:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
   [graphView setShowLaps:on];
   [graphView setNeedsDisplay:YES];
   [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowLaps];
}


- (IBAction) setShowPeaks:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
   [graphView setShowPeaks:on];
   [graphView setNeedsDisplay:YES];
   [self updatePeakControls:on];
   [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowPeaks];
}


- (IBAction) setShowHeartrateZones:(id) sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
   [graphView setShowHeartrateZones:on];
   [graphView setNeedsDisplay:YES];
   [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowHRZones];
}


- (IBAction) setPeakType:(id) sender
{
   int idx = (int)[sender indexOfSelectedItem];
   int type = [[Utils graphItemList] tagOfItemAtIndex:idx];
   [graphView setPeakType:type];
   [graphView setNeedsDisplay:YES];
   [Utils setIntDefault:type 
                 forKey:RCBDefaultPeakItem];
}


- (IBAction) setNumberOfPeaks:(id) sender
{
    NSStepper *stepper = (NSStepper *)sender;
    int v = stepper.intValue;
    [numberOfPeaksField setIntValue:v];
    [graphView setNumPeaks:v];
    [graphView setNeedsDisplay:YES];
    [Utils setIntDefault:v
                  forKey:RCBDefaultNumPeaks];
}


- (IBAction) setZoneType:(id) sender
{
	int idx = (int)[[sender selectedItem] tag];
	switch (idx)
	{
		case kUseHRZColorsForPath:
		{
			if (![graphView plotEnabled:kHeartrate] && ![graphView plotEnabled:kAvgHeartrate])
			{
				[graphView setPlotEnabled:kHeartrate 
								  enabled:YES
						   updateDefaults:YES];
				NSButton* button = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kHeartrate, kEnabledControl)];
				[button setIntValue:1];
			}
		}
		break;

		case kUsePaceZonesForPath:
		case kUseSpeedZonesForPath:
		{
			if (![graphView plotEnabled:kSpeed] && ![graphView plotEnabled:kAvgSpeed])
			{
				[graphView setPlotEnabled:kSpeed 
								  enabled:YES
						   updateDefaults:YES];
				NSButton* button = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kSpeed, kEnabledControl)];
				[button setIntValue:1];
			}
		}
		break;
		 
		case kUseGradientZonesForPath:
		 {
			if (![graphView plotEnabled:kGradient] && ![graphView plotEnabled:kAvgGradient])
			{
				[graphView setPlotEnabled:kGradient 
								  enabled:YES
						   updateDefaults:YES];
				NSButton* button = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kGradient, kEnabledControl)];
				[button setIntValue:1];
			}
		 }
		 break;
		 
		case kUseCadenceZonesForPath:
		{
			if (![graphView plotEnabled:kCadence] && ![graphView plotEnabled:kAvgCadence])
			{
				[graphView setPlotEnabled:kCadence 
								  enabled:YES
						   updateDefaults:YES];
				NSButton* button = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kCadence, kEnabledControl)];
				[button setIntValue:1];
			}
		}
		break;

		case kUsePowerZonesForPath:
		{
			if (![graphView plotEnabled:kPower] && ![graphView plotEnabled:kAvgPower])
			{
				[graphView setPlotEnabled:kPower 
								  enabled:YES
						   updateDefaults:YES];
				NSButton* button = [[settingsDrawer contentView] viewWithTag:typeComponentToTag(kPower, kEnabledControl)];
				[button setIntValue:1];
			}
		}
			break;
			
	}

	[graphView setNeedsDisplay:YES];
	[Utils setIntDefault:idx 
				  forKey:RCBDefaultZoneInActivityDetailViewItem];
}	


- (IBAction) setNumAvgPoints:(id) sender
{
   int state = [sender intValue];
   [numAvgPointsField setIntValue:state];
   [graphView setNumAvgPoints:state];
   [graphView setNeedsDisplay:YES];
   [Utils setIntDefault:state 
                 forKey:RCBDefaultNumPointsToAverage];
}

- (IBAction) setPeakThreshold:(id) sender
{
   int state = [sender intValue];
   [peakThresholdField setIntValue:state];
   [graphView setPeakThreshold:state];
   [graphView setNeedsDisplay:YES];
   [Utils setIntDefault:state 
                 forKey:RCBDefaultPeakThreshold];
}


- (IBAction) setShowCrossHairs:(id)sender
{
    NSButton *btn = (NSButton *)sender;                   // since this action is wired from a button
    BOOL on = (btn.state  == NSControlStateValueOn) ? YES : NO;
   [graphView setShowCrossHairs:on];
   [graphView setNeedsDisplay:YES];
   [Utils setBoolDefault:on 
                  forKey:RCBDefaultShowCrosshairs];
}




- (IBAction) setDataRectType:(id)sender
{
   int idx = (int)[sender indexOfSelectedItem];
   int type = [[Utils graphItemList] tagOfItemAtIndex:idx];
   [graphView setDataRectType:type];
   [graphView setNeedsDisplay:YES];
   [Utils setIntDefault:type
                 forKey:RCBDefaultAnimationFollows];
}


- (IBAction) setXAxisType:(id)sender
{
	int typ = ( [sender indexOfSelectedItem] != 0 ) ? 1 : 0;
	/// set in prefs [Utils setIntDefault:typ
	/// set in prefs 			   forKey:RCBDefaultXAxisType]; 
	[graphView setXAxisIsTime:typ == 1];
	[graphView setNeedsDisplay:YES];
}

- (IBAction) setSpeedPace:(id) sender
{
   [graphView setShowPace:([sender indexOfSelectedItem] != 0)];
   [graphView setNeedsDisplay:YES];
}


-(void) beginAnimation
{
}


-(void) endAnimation
{
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim
{
   [graphView updateAnimation:trackTime reverse:rev];
}


- (IBAction) addMarker:(id)sender
{
	if (editMarkersController == nil)
	{
	  // we implicitly "retain" the controller here. When it is closed, it is removed from the window controllers list,
	  // and when this controller exits, we do the final release.
	  editMarkersController = [[EditMarkersController alloc] initWithTrack:track
																	adView:graphView];
	  [tbDocument addWindowController:editMarkersController];
	}
	else
	{
		[editMarkersController reset];
	}
	if (![[editMarkersController window] isVisible])
		[editMarkersController showWindow:self];
	else
		[[editMarkersController window] orderOut:sender];
}


- (IBAction) editPeakPowerIntervals:(id)sender
{
}


- (IBAction) setPeakPowerIntervalEnabled:(id)sender
{
	int intervalIndex = (int)[sender tag] - kStartingPeakPowerCheckboxTag;
	BOOL enabled = [sender state] == NSControlStateValueOn;
	[Utils setPeakPowerIntervalAtIndexEnabled:intervalIndex
									  enabled:enabled];
	 if (enabled)
	 {
		 [self setShowPowerPeakIntervals:sender];
	 }
	 [graphView setNeedsDisplay:YES];
}


- (Track*) animationTrack
{
   return track;
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
   return [tbDocument undoManager];
}




- (void)trackChanged:(NSNotification *)notification
{
   if (track == [notification object])
   {
      [self setTrack:track];
   }
}


- (void)trackEdited:(NSNotification *)notification
{
   [[self window] setDocumentEdited:YES];
}


- (void) rebuildActivitySelectorPopup
{
	NSArray* ta = [tbDocument trackArray];
	[activitySelectorPopup removeAllItems];
    NSUInteger count = [ta count];
	for (int i=0; i<count; i++)
	{
		NSString* title = [Utils buildTrackDisplayedName:[ta objectAtIndex:i] prePend:@""];
		// NOTE: can't use NSPopupButton methods here to add items, because it checks for duplicates and this causes
		// problems if we manufacture 2 or more track names that are the same.
		[[activitySelectorPopup menu] addItemWithTitle:title
												action:0
										 keyEquivalent:@""];
	}
	if (track != nil) [[self window] setTitle:[Utils buildTrackDisplayedName:track prePend:@"Activity Detail - "]];
}


- (void)markersChanged:(NSNotification *)notification
{
	if (editMarkersController != nil)
	{
		[self editMarkers:[editMarkersController markers]];
		[graphView setShowMarkers:YES];
		[graphView setNeedsDisplay:YES];
		[[self window] setDocumentEdited:YES];
	}
}


-(void) HUDClosed:(NSNotification *)notification
{
	if ([notification object] == statsHUDWindow)
	{
		[showStatsHudButton setState:NSControlStateValueOff];
	}
}


-(void) trackArrayChanged:(NSNotification *)notification
{
	[self rebuildActivitySelectorPopup];
	NSArray* arr = [tbDocument trackArray];
	if (track != nil)
	{
		if ([arr indexOfObjectIdenticalTo:track] == NSNotFound)
		{
			NSInteger idx = [arr indexOfObject:track];
			if (idx != NSNotFound)
			{
				[self setTrack:[arr objectAtIndex:idx]];
			}
		}
	}
}


- (void)prefsChanged:(NSNotification *)notification
{
    [graphView prefsChanged];
	[graphView setTrack:track
			forceUpdate:YES];
	[graphView setNeedsDisplay:YES];
	[transparentView prefsChanged];
	[self setFormatsForDataHUD];
	[self updateStatsHUDPrompts];
	[self updateStatsHUD];
}


@end

