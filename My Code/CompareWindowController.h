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
    CWTransparentMapView                *mapTransparentView;
    CWTransparentMapView                *zoomMapTransparentView;
    CWTransparentMapView                *adViewTransparentView;
    
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

@property(nonatomic, assign) IBOutlet MapPathView           *mapView;
@property(nonatomic, assign) IBOutlet MapPathView           *zoomMapView;
@property(nonatomic, assign) IBOutlet ActivityDetailView    *adView;
@property(nonatomic, assign) IBOutlet NSButton              *analysisButton;
@property(nonatomic, assign) IBOutlet NSTextField           *dot1Label;
@property(nonatomic, assign) IBOutlet NSTextField           *dot2Label;
@property(nonatomic, assign) IBOutlet NSTextField           *dot3Label;
@property(nonatomic, assign) IBOutlet NSTextField           *dot4Label;
@property(nonatomic, assign) IBOutlet NSImageView           *dot1Image;
@property(nonatomic, assign) IBOutlet NSImageView           *dot2Image;
@property(nonatomic, assign) IBOutlet NSImageView           *dot3Image;
@property(nonatomic, assign) IBOutlet NSImageView           *dot4Image;

//@property(nonatomic, assign) IBOutlet NSButton*                    playButton;
//@property(nonatomic, assign) IBOutlet NSButton*                    stopButton;
//@property(nonatomic, assign) IBOutlet NSButton*                    reverseButton;
//@property(nonatomic, assign) IBOutlet NSButton*                    rtzButton;
//@property(nonatomic, assign) IBOutlet NSButton*                    rteButton;
//@property(nonatomic, assign) IBOutlet NSTextField*                speedFactorText;
//@property(nonatomic, assign) IBOutlet NSSlider*                    speedFactorSlider;
//@property(nonatomic, assign) IBOutlet NSSlider*                    locationSlider;
//@property(nonatomic, assign) IBOutlet NSTextField*                timecodeText;
//@property(nonatomic, assign) IBOutlet NSView*                    transportAreaView;
//@property(nonatomic, assign) IBOutlet NSView*                    leftContentView;
//@property(nonatomic, assign) IBOutlet NSView*                    rightContentView;
//@property(nonatomic, assign) IBOutlet NSSplitView*                leftSplitView;
//@property(nonatomic, assign) IBOutlet NSSplitView*                mainSplitView;
//@property(nonatomic, assign) IBOutlet ProfilesContainerView*        profilesContainerView;      // remove
//@property(nonatomic, assign) IBOutlet NSPopUpButton*                plotTypePopup;
//@property(nonatomic, assign) IBOutlet NSPopUpButton*                distanceTimePopup;
//@property(nonatomic, assign) IBOutlet NSPopUpButton*                guideFollowsPopup;
//@property(nonatomic, assign) IBOutlet CWSummaryPanelController*    summaryPanelController;
//@property(nonatomic, assign) IBOutlet NSSegmentedControl*        selectorSegmentedControl;
//@property(nonatomic, assign) IBOutlet NSSlider*                    scaleSlider;
//@property(nonatomic, assign) IBOutlet NSPopUpButton*                alignToPopUpButton;



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
