//
//  DMWindowController.h
//  TLP
//
//  Created by Rob Boyer on 10/14/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentAnimationTargetProtocol.h"

@class MapPathView;
@class TrackBrowserDocument;
@class Track;
@class Lap;
@class MiniProfileView;
@class TransparentMapView;
@class TransparentMapWindow;
@class DataHUDWindowController;

@interface DMWindowController : NSWindowController  <AscentAnimationTarget, NSWindowDelegate, NSDrawerDelegate>
{
	IBOutlet NSDrawer*				settingsDrawer;
	IBOutlet MapPathView*			mapView;
	IBOutlet NSPopUpButton*			activitySelectorPopup;
	IBOutlet NSPopUpButton*			mapDataTypePopup;
	IBOutlet NSButton*				showPathButton;
	IBOutlet NSButton*				showHudButton;
	IBOutlet NSButton*				showLapsButton;
	IBOutlet NSSlider*				zoomSlider;
	IBOutlet NSButton*				moveLeftButton;
	IBOutlet NSButton*				moveRightButton;
	IBOutlet NSButton*				moveUpButton;
	IBOutlet NSButton*				moveDownButton;
	IBOutlet NSButton*				applyDefaultsButton;
	IBOutlet NSProgressIndicator*	progressIndicator;
	IBOutlet NSTextField*			progressText;
	IBOutlet NSSlider*				mapTransparencySlider;
	IBOutlet NSSlider*				pathTransparencySlider;
	IBOutlet NSSlider*				hudOpacitySlider;
	IBOutlet NSButton*				showIntervalMarkersButton;
	IBOutlet NSTextField*			intervalIncrementTextField;
	IBOutlet NSStepper*				intervalIncrementStepper;
	IBOutlet NSTextField*			intervalIncrementUnitsLabel;
	IBOutlet TransparentMapView*    transparentMapAnimView;
	IBOutlet TransparentMapWindow*  transparentMapWindow;
	IBOutlet NSPopUpButton*			colorPathPopup;
	IBOutlet NSPopUpButton*			selectedLapPopup;

	DataHUDWindowController*	dataHUDWC;
	NSTimer*					fadeTimer;
	Track*						track;
	int							dataType;
	int							numPos;
	NSRect						windowFrameBeforeOpeningDrawer;
}
@property(retain, nonatomic) id mainWC;
@property(retain, nonatomic) id tbDocument;

- (IBAction) openDrawer:(id) sender;
- (IBAction) closeDrawer:(id) sender;
- (IBAction)setMapDataType:(id)sender;
- (IBAction)setShowPath:(id)sender;
- (IBAction)setShowHud:(id)sender;
- (IBAction)setHudOpacity:(id)sender;
- (IBAction)setShowLaps:(id)sender;
- (IBAction)setShowIntervalMarkers:(id)sender;
- (IBAction)setIntervalIncrement:(id)sender;
- (IBAction)moveLeft:(id)sender;
- (IBAction)moveRight:(id)sender;
- (IBAction)moveUp:(id)sender;
- (IBAction)moveDown:(id)sender;
- (IBAction)zoom:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)applyDefaults:(id)sender;
- (IBAction)centerAtEnd:(id)sender;
- (IBAction)centerAtStart:(id)sender;
- (IBAction)centerOnPath:(id)sender;
- (IBAction)setMapTransparency:(id)sender;
- (IBAction)setPathTransparency:(id)sender;
- (IBAction)selectActivity:(id)sender;
- (IBAction)selectLap:(id)sender;
- (IBAction)setColorPath:(id)sender;
- (Track*) animationTrack;

- (id)initWithDocument:(TrackBrowserDocument*)doc initialDataType:(int)dt mainWC:(NSWindowController*)wc;
- (void)setDataType:(int)dt;
- (Track*)track;
- (void)setTrack:(Track*)t;
- (void)setSelectedLap:(Lap*)lap;
@end
