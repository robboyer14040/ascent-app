//
//  MainWindowController.h
//  TLP
//
//  Created by Rob Boyer on 7/25/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;

@class NSSplitViewController;
@class LeftSplitController;
@class RightSplitController;
@class TrackPaneController;
@class AnalysisPaneController;
@class InfoPaneController;

@interface TBWindowController : NSWindowController
{
@private
    Selection *_selection; // shared per document
}

// Top controls
@property(nonatomic, assign) IBOutlet NSSegmentedControl *leftTopToggle;     // Outline/Calendar
@property(nonatomic, assign) IBOutlet NSSegmentedControl *leftBottomToggle;  // Segments/Intervals
@property(nonatomic, assign) IBOutlet NSSegmentedControl *rightBottomToggle; // Metrics/Summary

// Split controllers
@property(nonatomic, assign) IBOutlet NSSplitViewController *rootSplitController;
@property(nonatomic, assign) IBOutlet LeftSplitController   *leftSplitController;
@property(nonatomic, assign) IBOutlet TrackPaneController   *trackPaneController;
@property(nonatomic, assign) IBOutlet AnalysisPaneController *analysisPaneController;

@property(nonatomic, assign) IBOutlet RightSplitController  *rightSplitController;
@property(nonatomic, assign) IBOutlet InfoPaneController    *infoPaneController;

// Shared selection (retained here, injected into children)
@property(nonatomic, retain) Selection *selection;

// Actions
- (IBAction)toggleLeftTop:(id)sender;
- (IBAction)toggleLeftBottom:(id)sender;
- (IBAction)toggleRightBottom:(id)sender;

// Examples of “open window” buttons in the top bar (optional)
- (IBAction)showPreferences:(id)sender;
- (IBAction)showPhotoBrowser:(id)sender;

@end

#if 0


#import "Defs.h"
#import "AnimTimer.h"

@class TrackBrowserDocument;
@class MiniProfileView;
@class MapPathView;
@class Track;
@class Lap;
@class ActivityOutlineView;
@class TransparentMapView;
@class TransparentMapWindow;
@class BrowserColumnsWindowController;
@class CustomSplitDistanceController;
//@class EditNotesController;
@class TransparentView;
@class ColorBoxView;
@class TrackBrowserItem;
@class RBSplitView;
@class RBSplitSubview;
@class CalendarView;
@class SplitsGraphView;
@class SplitsTableView;
@class EquipmentListWindowController;
@class CompareWindowController;
@class DMWindowController;
@class SGWindowController;
@class EquipmentBoxView;
@class TextViewWithPlaceholder;
@class EditNotesController;
@class TrackListController;

enum
{
	kTagSearchTitles		= 10,
	kTagSearchNotes			= 11,
	kTagSearchKeywords		= 12,
	kTagSearchActivityType	= 13,
	kTagSearchEquipment		= 14,
	kTagSearchEventType		= 15,
};


enum
{
    kLeftSplitView = 0x0001,
    kRightSplitView = 0x0002,
    kMainSplitView = 0x0003
};


struct tControlToAttrMap
{
	id					editControl;
	int					attributeID;
	int					flags;
	NSString*			placeholderText;
	TransparentView*	transparentView;	// on top of TextView
} ;

// labels in "Info" dialog that can be set in preferences
enum
{
   kLID_Custom,
   kLID_Keyword1,
   kLID_Keyword2
};


@interface FixedSegmentedControl : NSSegmentedControl
@end

//@interface EditNotesField : NSTextView
//@end


@interface TBWindow : NSWindow
{
    bool mouseIsDown;
}
-(BOOL) isMouseDown;
@end


@interface TBSplitView : NSSplitView
{
    BOOL    mouseIsDown;
}
-(BOOL) isMouseDown;
@end


@interface MainWindowController : NSWindowController <AnimationTarget, NSToolbarDelegate, NSWindowDelegate>
{
	// "toolbar" area
    NSMutableDictionary*            toolbarItems;
	IBOutlet NSView*				calOrBrowView;
	IBOutlet NSView*				leftOptionsView;
	IBOutlet NSView*				splitOptionsView;
	IBOutlet NSView*				summaryButtonView;
	IBOutlet NSView*				activityDetailButtonView;
	IBOutlet NSView*				detailedMapButtonView;
	IBOutlet NSView*				compareActivitiesButtonView;
	IBOutlet NSView*				searchView;
	IBOutlet NSSegmentedControl*	calOrBrowControl;
	IBOutlet NSSegmentedControl*	leftOptionsControl;
	IBOutlet NSSegmentedControl*	splitOptionsControl;
	IBOutlet NSSegmentedControl*	activityDetailButton;
	IBOutlet NSSegmentedControl*	detailedMapButton;
	IBOutlet NSSegmentedControl*	compareActivitiesButton;
	IBOutlet NSSegmentedControl*	summaryButton;
	IBOutlet NSSearchField*         searchField;
	IBOutlet NSMenu*                searchCategoryMenu;
	NSMenu*							cogMenu;
	NSMenu*							splitOptionsMenu;
	NSMenu*							mapViewDataTypeSubMenu;
	NSMenu*							browserViewSubMenu;
	NSMenu*							splitLengthSubMenu;
	NSMenu*							splitGraphSubMenu;
	NSMenu*							searchMenu;
	//IBOutlet NSSegmentedControl*			rightOptionsControl;
	
	// info pane
	IBOutlet NSPopUpButton*		activityPopup;
	IBOutlet NSPopUpButton*		eventTypePopup;
	IBOutlet NSPopUpButton*		weatherPopup;
	IBOutlet NSPopUpButton*		dispositionPopup;
	IBOutlet NSPopUpButton*		effortPopup;
	IBOutlet NSPopUpButton*		keyword1Popup;
	IBOutlet NSPopUpButton*		keyword2Popup;
	IBOutlet NSTextField*		customTextField;
	IBOutlet NSTextField*		editWeightField;
	IBOutlet NSTextField*		weightUnitsField;
	IBOutlet NSTextField*		editActivityName;
	IBOutlet TextViewWithPlaceholder*		notesTextView;
	IBOutlet NSTextField*		customTextFieldLabel;
	IBOutlet NSTextField*		keyword1PopupLabel;
	IBOutlet NSTextField*		keyword2PopupLabel;
	IBOutlet NSButton*			setEquipmentButton;
	IBOutlet EquipmentBoxView*	equipmentBox;
	// metrics events pane
	IBOutlet NSTableView*		metricsEventTable;
 
 	IBOutlet TBSplitView*		mainSplitView;
	IBOutlet TBSplitView*		leftSplitView;
	IBOutlet NSView*            outlineSplitSubview;
	IBOutlet NSView*            splitsTableSubView;
	IBOutlet NSView*            splitsGraphSubView;
	IBOutlet TBSplitView*		rightSplitView;
	IBOutlet NSView*            statsInfoSplitSubView;
	IBOutlet NSView*            miniProfileSplitSubView;
	IBOutlet NSView*            mapPathSplitSubView;
   
	// other member data
	IBOutlet MiniProfileView*		miniProfileView;
	IBOutlet MapPathView*			mapPathView;
	IBOutlet SplitsGraphView*		splitsGraphView;
	IBOutlet SplitsTableView*		splitsTableView;
	IBOutlet ActivityOutlineView*   trackTableView;

	IBOutlet BrowserColumnsWindowController*  browserColumnsWC;
	IBOutlet CustomSplitDistanceController*	  customSplitDistanceWC;
	IBOutlet EditNotesController*    editNotesWC;
	  
	IBOutlet NSTabView*             mainBrowserTabView;
	IBOutlet NSTabView*             infoStatsTabView;
	
	IBOutlet CalendarView*			calendarView;

	int                             currentTrackPos, numPos;
	TransparentMapView*				transparentMapAnimView;
	TransparentMapView*				transparentMiniProfileAnimView;
	TransparentMapWindow*			transparentMapWindow;
	TransparentMapWindow*			transparentMiniProfileWindow;
	EquipmentListWindowController*	equipmentListWC;
	CompareWindowController*		compareWC;
	DMWindowController*             dmWC;
    SGWindowController*             sgWC;
	NSMutableArray*                 editWindowMenus;
	NSMutableArray*					splitArray;
	NSWindow*                       tbWindow;
	NSFont*                         lineFont;
	NSFont*                         boldLineLargeFont;
	NSFont*                         boldLineMediumFont;
	NSFont*                         boldLineSmallFont;
	TrackBrowserDocument*           tbDocument;
	NSTableColumn*                  sortColumn;
	NSTimer*                        fadeTimer;
	Track*                          currentlySelectedTrack;
	Lap*                            currentlySelectedLap;
	struct tControlToAttrMap        attrMap[kNumAttributes];
	BOOL                            isRegistered;
}

@property(nonatomic, assign) IBOutlet TrackListController *trackListController; // IB retains it via nib
@property (weak) IBOutlet NSImageView *trackPicImageView;

- (IBAction)setMapDataType:(id)sender;
- (IBAction)setSplitLength:(id)sender;
- (IBAction)setSplitGraphItem:(id)sender;
- (IBAction)setBrowserOptions:(id)sender;
- (IBAction)setMapOpacity:(id)sender;
- (IBAction)setInfoPopupItem:(id)sender;
- (IBAction)setInfoTextField:(id)sender;
- (IBAction)setWeight:(id)sender;
- (IBAction)setSearchCriteria:(id)sender;
- (IBAction)setSearchOptions:(id)sender;
- (IBAction)showActivityDetail:(id)sender;
- (IBAction)showMapDetail:(id)sender;
- (IBAction)showSummaryGraph:(id)sender;
- (IBAction)showCompareWindow:(id)sender;
- (IBAction)setViewType:(id)sender;
- (IBAction)setColorPathType:(id)sender;
- (IBAction)setSplitOptions:(id)sender;

//- (IBAction) editNotes:(id)sender;
- (IBAction) setFieldLabel:(int)lableID label:(NSString*)label;
- (IBAction) toggleMainBrowser:(id)sender;
- (IBAction) expandOrCollapseSplits:(id)sender;
- (IBAction)showGarminSync:(id) sender;
- (IBAction)showEquipmentSelector:(id)sender;
- (IBAction)showEquipmentList:(id) sender;
- (IBAction)linkStravaActivitiesFromCSV:(id)sender;

- (void)dismissEquipmentList:(id)wc;


- (NSOutlineView*) trackTable;
- (MapPathView*) mapPathView;
- (id)initWithDocument:(TrackBrowserDocument*)doc;
- (void)stopAnimations;
- (Track*) animationTrack;
- (void)syncTrackToAttributesAndEditWindow:(Track*)track;
- (int)viewType;
- (void) postNeedRegDialog:(NSString*)msg;
- (void) doTCXImportWithProgress:(NSArray*)files;
- (void) doTCXImportWithoutProgress:(NSArray*)files;

- (void) simpleUpdateBrowserTrack:(Track*)track;
- (NSArray*)trackArray;
- (void)addStravaActivities:(NSArray<NSDictionary*> *) arr;
- (BOOL)applyStravaActivitiesCSVAtURL:(NSURL *)csvURL
                             toTracks:(NSArray<Track *> *)tracks;

@end
#endif


