//
//  CompareWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 2/27/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentAnimationTargetProtocol.h"

@class MapPathView;
@class ActivityDetailView;
@class ProfilesContainerView;           // remove
@class ProfilesTransparentView;         // remove
@class CWTransparentView;
@class CWTransparentMapView;
@class CompareProfileViewController;        // remove
@class CWSummaryPanelController;
@class Track;

enum
{
	kGuideFollowsFastest,
	kGuideFollowsSelected,
	kGuideFollowsNothing
};

@interface CompareWindowController : NSWindowController <AscentAnimationTarget, NSWindowDelegate>
{
	IBOutlet MapPathView                *mapView;
	IBOutlet MapPathView                *zoomMapView;
    IBOutlet ActivityDetailView         *adView;
    CWTransparentMapView                *mapTransparentView;
    CWTransparentMapView                *zoomMapTransparentView;
    CWTransparentMapView                *adViewTransparentView;
    
	IBOutlet NSButton*					playButton;
	IBOutlet NSButton*					stopButton;
	IBOutlet NSButton*					reverseButton;
	IBOutlet NSButton*					rtzButton;
	IBOutlet NSButton*					rteButton;
	IBOutlet NSTextField*				speedFactorText;
	IBOutlet NSSlider*					speedFactorSlider;
	IBOutlet NSSlider*					locationSlider;
	IBOutlet NSTextField*				timecodeText;
	IBOutlet NSView*					transportAreaView;
	IBOutlet NSView*					leftContentView;
	IBOutlet NSView*					rightContentView;
	IBOutlet NSSplitView*				leftSplitView;
	IBOutlet NSSplitView*				mainSplitView;
	IBOutlet ProfilesContainerView*		profilesContainerView;      // remove
	IBOutlet NSPopUpButton*				plotTypePopup;
	IBOutlet NSPopUpButton*				distanceTimePopup;
	IBOutlet NSPopUpButton*				guideFollowsPopup;
	IBOutlet CWSummaryPanelController*	summaryPanelController;
	IBOutlet NSSegmentedControl*		selectorSegmentedControl;
	IBOutlet NSSlider*					scaleSlider;
	IBOutlet NSPopUpButton*				alignToPopUpButton;
	ProfilesTransparentView*			profilesTransparentView;        // remove
	CompareProfileViewController*		fastestPVC;		// only used during animation remove
	CompareProfileViewController*		lastFocusedPVC;     // remove
	NSMutableArray*						profileControllerArray; // remove
	NSArray*							trackArray;
	NSArray*							dotColorsArray;
	__unsafe_unretained id		        mainWindowController;
	BOOL								xAxisIsTime;
	float								startingDistance;
	float								origMaxDistance;
	int									numViews;
	int									guideFollows;
}
@property(retain, nonatomic) NSMutableArray* profileControllerArray;
@property(retain, nonatomic) NSArray* trackArray;
@property(retain, nonatomic) NSArray* dotColorsArray;
@property(retain, nonatomic) CWTransparentMapView* mapTransparentView;
@property(retain, nonatomic) CWTransparentMapView* zoomMapTransparentView;
@property(assign, nonatomic) id mainWindowController;		// don't retain
@property(nonatomic) BOOL xAxisIsTime;
@property(nonatomic) float startingDistance;
@property(nonatomic) int numViews;

-(id) initWithTracks:(NSArray*)trackArray  mainWC:(NSWindowController*)wc;
-(void)resetTracks:(NSArray*)trackArray  mainWC:(NSWindowController*)wc;
-(void)addTracksFromArrayOfTrackDates:(NSArray*)arr;
-(IBAction)done:(id)sender;
-(IBAction)play:(id)sender;
-(IBAction)reverse:(id)sender;
-(IBAction)rtz:(id)sender;
-(IBAction)rte:(id)sender;
-(IBAction)stop:(id)sender;
-(IBAction)setToLap:(id)sender;
-(IBAction)setSpeedFactor:(id)sender;
-(IBAction)setXAxisType:(id)sender;
-(IBAction)setLocation:(id)sender;
-(IBAction)setPlotType:(id)sender;
-(IBAction)setGuideFollows:(id)sender;
-(IBAction)selectorSegmentedControlClicked:(id)sender;
-(IBAction)setScale:(id)sender;
-(IBAction)zoom:(id)sender;
-(IBAction)displayHelp:(id)sender;
@end
