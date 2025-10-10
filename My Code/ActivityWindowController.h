//
//  ActivityWindowController.h - Activity Detail window controller.  Glue between the
//    activity view and data
//
//  Ascent
//
//  Created by Rob Boyer on 7/24/06.
//  Copyright 2006 by Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ActivityDetailView.h"


@class Track;
@class TrackPoint;
@class Lap;
@class ActivityDetailView;
@class TrackBrowserDocument;
@class ActivityDetailTransparentView;
@class ADTransparentWindow;
@class ADStatsView;
@class HUDWindow;
//@class DataHUDView;
@class EditMarkersController;
@class DataHUDWindowController;
@class ActivityWindowController;
@class ActivityDetailViewDelegate;

@protocol ActivityWindowControllerDelegate <NSObject>
@required
- (void)activityWindowControllerDidClose:(ActivityWindowController *)controller;
@end


@interface ActivityWindowController : NSWindowController <NSWindowDelegate, NSDrawerDelegate, ActivityDetailViewDelegate>
{
	IBOutlet NSDrawer*      settingsDrawer;
	IBOutlet NSWindow*      activityWindow;
	IBOutlet ActivityDetailView*        graphView;
	IBOutlet NSTextField*   numberOfPeaksField;
	IBOutlet NSStepper*     numberOfPeaksStepper;
	IBOutlet NSTextField*   peakThresholdField;
	IBOutlet NSStepper*     peakThresholdStepper;
	IBOutlet NSPopUpButton* peakTypePopup;
	IBOutlet NSPopUpButton* dataRectTypePopup;
	IBOutlet NSPopUpButton* zoneTypePopup;
	IBOutlet NSPopUpButton* activitySelectorPopup;
	IBOutlet NSPopUpButton* xAxisTypePopup;
	IBOutlet NSPopUpButton* speedPacePopup;
	IBOutlet NSPopUpButton* peakPowerIntervalsPopup;
	IBOutlet NSButton*      showPeaksButton;
	IBOutlet NSButton*      showLapsButton;
	IBOutlet NSButton*      showMarkersButton;
	IBOutlet NSButton*      showHeartrateZonesButton;
	IBOutlet NSButton*      showCrossHairsButton;
	IBOutlet NSButton*      showStatsHudButton;     
	IBOutlet NSButton*      showDataHudButton;   
	IBOutlet NSButton*		showPeakPowerIntervalsButton;
	IBOutlet NSButton*      addMarkerButton;
	IBOutlet NSStepper*     numAvgPointsStepper;
	IBOutlet NSTextField*   numAvgPointsField;
	IBOutlet NSPopUpButton*	lapsPopup;
	IBOutlet NSBox*			selectionInfoBox;
	IBOutlet NSTextField*	startSelectionField;
	IBOutlet NSTextField*	endSelectionField;
	IBOutlet NSTextField*	deltaSelectionField;
	IBOutlet NSTextField*	startTimeSelectionField;
	IBOutlet NSTextField*	endTimeSelectionField;
	IBOutlet NSTextField*	deltaTimeSelectionField;
	IBOutlet NSTextField*	startAltSelectionField;
	IBOutlet NSTextField*	endAltSelectionField;
	IBOutlet NSTextField*	deltaAltSelectionField;
	IBOutlet NSSlider*      dataHUDOpacitySlider;
	IBOutlet NSSlider*      statsHUDOpacitySlider;
	IBOutlet NSSlider*      zonesOpacitySlider;

    IBOutlet ActivityDetailTransparentView  *transparentView;
}
@property (nonatomic, assign) id<ActivityWindowControllerDelegate> customDelegate;

// actions initiated by the GUI
- (IBAction) openDrawer:(id)sender;
- (IBAction) closeDrawer:(id)sender;

- (IBAction) setPlotEnabled:(id)sender;
- (IBAction) setPlotFillEnabled:(id)sender;
- (IBAction) setPlotOpacity:(id)sender;
- (IBAction) setPlotColor:(id)sender;
- (IBAction) setPlotLineStyle:(id)sender;
- (IBAction) setShowMarkers:(id)sender;
- (IBAction) setShowPowerPeakIntervals:(id)sender;
- (IBAction) setShowLaps:(id)sender;
- (IBAction) setShowHeartrateZones:(id)sender;
- (IBAction) setShowPeaks:(id)sender;
- (IBAction) setNumberOfPeaks:(id)sender;
- (IBAction) setNumAvgPoints:(id)sender;
- (IBAction) setPeakThreshold:(id)sender;
- (IBAction) setPeakType:(id)sender;
- (IBAction) setZoneType:(id)sender;
- (IBAction) addMarker:(id)sender;
- (IBAction) editPeakPowerIntervals:(id)sender;	// note used, currently
- (IBAction) setPeakPowerIntervalEnabled:(id)sender;
- (IBAction) selectTrack:(id)sender;
- (IBAction) selectLap:(id)sender;
- (IBAction) setShowCrossHairs:(id)sender;
- (IBAction) setDataRectType:(id)sender;
- (IBAction) setXAxisType:(id)sender;
- (IBAction) setSpeedPace:(id)sender;
- (IBAction) setStatsHUDLocked:(id)sender;
- (IBAction) setShowDataHUD:(id)sender;
- (IBAction) setDataHUDOpacity:(id)sender;
- (IBAction) setStatsHUDOpacity:(id)sender;
- (IBAction) setZonesOpacity:(id)sender;

- (id)initWithDocument:(TrackBrowserDocument*)doc;
- (Track*)track;
- (void)setTrack:(Track*)t;
- (void)setLap:(Lap*)lp;
//-(void) updateDataHUD:(TrackPoint*)tpt x:(float)x y:(float)y;
-(void) updateDataHUD:(TrackPoint*)tpt x:(CGFloat)x y:(CGFloat)y altitude:(CGFloat)alt;
- (BOOL) dataHUDActive;
- (BOOL) statsHUDLocked;
- (float) dataHUDOpacity;
- (float) statsHUDOpacity;

@end
