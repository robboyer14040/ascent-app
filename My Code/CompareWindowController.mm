
//
//  CompareWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 2/27/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "CompareWindowController.h"
#import "CompareProfileViewController.h"
#import "CWTransparentView.h"
#import "CWTransparentMapView.h"
#import "CWTransparentWindow.h"
#import "CWSummaryPanelController.h"
#import "ProfilesContainerView.h"
#import "ProfilesTransparentView.h"
#import "MapPathView.h"
#import "ActivityDetailView.h"
#import "Utils.h"
#import "Track.h"
#import "TrackPoint.h"
#import "AnimTimer.h"
#import "Defs.h"
#import <QuartzCore/QuartzCore.h>

static int kMaxViews = 4;

NSString* RCBDefaultCompareWindowXAxisType		= @"DefaultCompareWindowXAxisType";
NSString* RCBDefaultCompareWindowPlotType		= @"DefaultCompareWindowPlotType";
NSString* RCBDefaultCompareWindowDontShowHelp	= @"DefaultCompareWindowDontShowHelp";
NSString* RCBDefaultCompareWindowGuideFollows	= @"DefaultCompareWindowGuideFollows";

@interface Dummy : NSObject
-(void)dismissCompareWindow:(id)sender;
@end

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
@interface NSWindowController ()
-(void)dismissCompareWindow:(id)sender;
@end

@interface CompareWindowController ()
@property(retain, nonatomic) ProfilesTransparentView* profilesTransparentView;
-(void)updateTracks;
-(void)updateLapMenu;
-(CompareProfileViewController*)pvcWithMostLaps;
-(void) updateSpeedFactorText;
-(void)setSelectedActivityToNextOrPreviousLap:(BOOL)setToNext;
-(void)doZoom:(BOOL)zoomProfiles;
-(void)zoomDetailMap:(id)sender;
-(void)zoomDetailMapOneLevel:(BOOL)zoomIn;
-(void) setupProfileContextualMenu;
-(void) prefsChanged:(NSNotification *)notification;
-(void)removeSelectedActivity:(id)sender;
@end


@implementation CompareWindowController

@synthesize profilesTransparentView;
@synthesize profileControllerArray;
@synthesize trackArray;
@synthesize xAxisIsTime;
@synthesize mapTransparentView;
@synthesize mapTransparentWindow;
@synthesize zoomMapTransparentView;
@synthesize zoomMapTransparentWindow;
@synthesize mainWindowController;
@synthesize dotColorsArray;
@dynamic startingDistance;
@synthesize numViews;



-(void)doInit:(NSArray*)ta  mainWC:(NSWindowController*)wc
{
    guideFollows = [Utils intFromDefaults:RCBDefaultCompareWindowGuideFollows];
    self.xAxisIsTime = NO;
    self.profileControllerArray = [NSMutableArray arrayWithCapacity:kMaxViews];
    self.trackArray = ta;
    self.mainWindowController = wc;
    self.dotColorsArray = [NSArray arrayWithObjects:@"Dot", @"BlueDot", @"GreenDot", @"PurpleDot", nil];
    
    for (Track* track in ta) {
        [track loadPoints:[wc.document fileURL]];
    }
    
    /// FIXME ADD TRANSPARENT VIEWS TO map and zoommap
}


-(id) initWithTracks:(NSArray*)ta mainWC:(NSWindowController*)wc
{
    
    self = [super initWithWindowNibName:@"CompareWindow"];
	if (self)
	{
		[self doInit:ta
			  mainWC:wc];
		for (Track* t in ta) [t calculatePower];
	}
	return self;
}


-(void)doCleanup
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if (pvc.track != nil)[[AnimTimer defaultInstance] unregisterForTimerUpdates:pvc];
	}
	[[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.mapTransparentView = nil;
	self.mapTransparentWindow = nil;
	self.zoomMapTransparentView = nil;
	self.zoomMapTransparentWindow = nil;
	self.profileControllerArray = nil;
	self.trackArray = nil;
}


-(void)dealloc
{
	self.profilesTransparentView = nil;
	self.dotColorsArray = nil;
	self.mainWindowController = nil;
	[self doCleanup];
    [super dealloc];
}

-(void)addTracksFromArrayOfTrackDates:(NSArray*)arr
{
	NSArray* allTracks = [self.mainWindowController trackArray];
    NSUInteger count = [allTracks count];
	NSMutableArray* newTrackArray = [NSMutableArray arrayWithArray:trackArray];
	for (NSNumber* num in arr)
	{
		if ([trackArray count] >= kMaxViews) break;
		int idx = [num intValue];
		if (IS_BETWEEN(0, idx, (count-1)))
		{
			Track* t = [allTracks objectAtIndex:idx];
			if (![newTrackArray containsObject:t])
			{
				[newTrackArray addObject:t];
				[t calculatePower];
			}
		}
	}
	self.trackArray = newTrackArray;
	self.numViews = (int)[trackArray count];
	[self updateTracks];
}
	

- (void)focusChanged:(NSNotification *)notification
{
	CompareProfileViewController* focusPVC = nil;
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if ([pvc isFocused])
		{
			focusPVC = pvc;
			break;
		}
	}
	if (focusPVC)
	{
		Track* t = focusPVC.track;
		int sc = [zoomMapView scale];
		[mapView setCurrentTrack:t];
		[zoomMapView setCurrentTrack:t];
		[zoomMapView setScale:sc];
		lastFocusedPVC = focusPVC;
	}
	[[AnimTimer defaultInstance] forceUpdate];
}


- (void)stateChanged:(NSNotification *)notification
{
	id sender = [notification object];
	if (sender != self)
	{
		NSNumber* st = [[notification userInfo] objectForKey:TransportStateChangedInfoKey];
		if (st.intValue == kStop)
		{
			[profilesTransparentView setHidePosition:NO];
			[stopButton setState:NSControlStateValueOn];
		}
		else if (st.intValue == kPlay)
		{
			[profilesTransparentView setHidePosition:YES];
			if ([[AnimTimer defaultInstance] playingInReverse])
			{
				[stopButton setState:NSControlStateValueOff];
			}
			else
			{
				[stopButton setState:NSControlStateValueOff];
			}
		}
	}					
}


- (void)awakeFromNib
{
	[[self window] setFrameAutosaveName:@"CWFrame"];
	if (![[self window] setFrameUsingName:@"CWFrame"])
	{
		[[self window] center];
	}
	[mainSplitView setAutosaveName:@"CWmainSplitView"];
	[leftSplitView setAutosaveName:@"CWLeftSplitView"];
	
	
	NSRect dummy;
	dummy.size.width = 10;
	dummy.size.height = 10;
	dummy.origin.x = 0;
	dummy.origin.y = 0;
	
	// set up map views
	self.mapTransparentView = [[CWTransparentMapView alloc] initWithFrame:dummy
																 dotColors:dotColorsArray];
	self.mapTransparentWindow = [[CWTransparentWindow alloc] initWithContentRect:dummy
																		styleMask:NSWindowStyleMaskBorderless
																		  backing:NSBackingStoreBuffered 
																			defer:NO];
//	[self.mapTransparentWindow setContentView:self.mapTransparentView];
//	[self.mapTransparentWindow setHasShadow:NO];
//	[self.mapTransparentWindow setIgnoresMouseEvents:YES];
//	[self.mapTransparentWindow setDelegate:self];
//	[[self window]  addChildWindow:(NSWindow*)self.mapTransparentWindow 
//						   ordered:NSWindowAbove];
	///[mapView setTransparentView:self.mapTransparentView];
	[mapView setIsDetailedMap:YES];
	[mapView setMoveMapDuringAnimation:NO];
	[mapView setShowIntervalMarkers:NO];
	[mapView setEnableMapInteraction:NO];
	
	self.zoomMapTransparentView = [[CWTransparentMapView alloc] initWithFrame:dummy
																	 dotColors:dotColorsArray];
	self.zoomMapTransparentWindow = [[CWTransparentWindow alloc] initWithContentRect:dummy
																			styleMask:NSWindowStyleMaskBorderless
																			  backing:NSBackingStoreBuffered
																				defer:NO];
//	[self.zoomMapTransparentWindow setContentView:self.zoomMapTransparentView];
//	[self.zoomMapTransparentWindow setHasShadow:NO];
//	[self.zoomMapTransparentWindow setIgnoresMouseEvents:YES];
//	[self.zoomMapTransparentWindow setDelegate:self];
//	[[self window]  addChildWindow:(NSWindow*)self.zoomMapTransparentWindow 
//						   ordered:NSWindowAbove];
	///[zoomMapView setTransparentView:self.zoomMapTransparentView];
	[zoomMapView setIsDetailedMap:YES];
	[zoomMapView setMoveMapDuringAnimation:YES];
	[zoomMapView setShowIntervalMarkers:NO];
	[zoomMapView setEnableMapInteraction:NO];
	
	
	// setup up profile views
	int trackCount = (int)[trackArray count];
	
	self.profilesTransparentView = [[ProfilesTransparentView alloc] initWithFrame:profilesContainerView.frame];
	
	self.numViews = trackCount > kMaxViews ? kMaxViews : trackCount; 
	for (int i=0; i<kMaxViews; i++)
	{
		Track* track = nil;
		if (i<trackCount) track = [trackArray objectAtIndex:i];
		ActivityDetailView* adv = [[ActivityDetailView alloc] initWithFrame:dummy];
		CWTransparentView* tv = [[CWTransparentView alloc] initWithFrame:dummy
																 iconFile:[self.dotColorsArray objectAtIndex:i]
																	track:track];
		CWTransparentWindow* tw = [[CWTransparentWindow alloc] initWithContentRect:dummy
																		 styleMask:NSWindowStyleMaskBorderless 
																		   backing:NSBackingStoreBuffered 
																			 defer:NO];
		[tw setContentView:tv];
		[tw setHasShadow:NO];
		[tw setIgnoresMouseEvents:YES];
		[tw setDelegate:self];
		[[self window]  addChildWindow:(NSWindow*)tw 
							   ordered:NSWindowAbove];
		CompareProfileViewController* pvc = [[CompareProfileViewController alloc] initWithTrack:track
																					 profileView:adv 
																				 transparentView:tv
																			   transparentWindow:tw];
		[adv setTransparentView:tv];
		[adv setDragStart:YES];
		[adv setDrawHeader:NO];
		[adv setShowLaps:YES];
		[adv setShowPeaks:NO];
		[adv setShowMarkers:NO];
		[adv setShowCrossHairs:NO];
		[adv setShowPowerPeakIntervals:NO];
		[adv setTopAreaHeight: 40.0];
		[adv setShowHorizontalTicks:NO];
		[adv setVertPlotYOffset:10.0];
		//[adv setShowVerticalTicks:NO];
		for (int i=0; i<kNumPlotTypes; i++)
		{
			[adv setPlotEnabled:(tPlotType)i
						enabled:NO
				 updateDefaults:NO];
		}
		[adv setPlotEnabled:kAltitude 
					enabled:YES
			 updateDefaults:NO];
		
		int pt = [Utils intFromDefaults:RCBDefaultCompareWindowPlotType];
		if (pt == 0) pt = kHeartrate;
		BOOL isPace = NO;
		if (pt == kPace)
		{
			pt = kSpeed;
			isPace = YES;
		}
		[adv setPlotEnabled:(tPlotType)pt 
					enabled:YES
			 updateDefaults:NO];
		
		[pvc.transparentView setShowingPace:isPace];
		[adv setShowPace:isPace];
		[adv setAutoresizingMask:0];
		[profilesContainerView addSubview:adv];
		[profileControllerArray addObject:pvc];
	}
	[profilesContainerView addSubview:self.profilesTransparentView
						   positioned:NSWindowAbove
						   relativeTo:nil];

	[self updateTracks];

	NSString* path;
	NSImage*  image;
	
	path = [[NSBundle mainBundle] pathForResource:@"RoundPlay" ofType:@"png"];
	image = [[NSImage alloc] initWithContentsOfFile:path];
	[stopButton setAlternateImage:image];
	path = [[NSBundle mainBundle] pathForResource:@"RoundStop" ofType:@"png"];
	image = [[NSImage alloc] initWithContentsOfFile:path];
	[stopButton setImage:image];
	
	path = [[NSBundle mainBundle] pathForResource:@"RoundRTZ" ofType:@"png"];
	image = [[NSImage alloc] initWithContentsOfFile:path] ;
	[rtzButton setImage:image];
	
	path = [[NSBundle mainBundle] pathForResource:@"RoundFF" ofType:@"png"];
	image = [[NSImage alloc] initWithContentsOfFile:path];
	[rteButton setImage:image];
	
	NSFont* font = [NSFont fontWithName:@"LCDMono Ultra" size:28.0];
	[timecodeText setFont:font];
	[timecodeText setTextColor:[NSColor blackColor]];
	[timecodeText setStringValue:@"00:00:00"];
	
	AnimTimer * at = [AnimTimer defaultInstance];
	[speedFactorSlider setFloatValue:[at speedFactor]];
	[self updateSpeedFactorText];
	
	float endTime = [at endingTime];
	if (endTime > 0.0)
	{
		[locationSlider setFloatValue:[at animTime]*100.0/endTime];
	}
	[[AnimTimer defaultInstance] registerForTimerUpdates:self];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(stateChanged:)
												 name:@"TransportStateChange"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(focusChanged:)
												 name:@"ActivityWindowFocusChanged"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChanged
											   object:nil];
	
	int plotType = [Utils intFromDefaults:RCBDefaultCompareWindowPlotType];
	if (plotType == 0) plotType = kHeartrate;
	[plotTypePopup selectItemWithTag:plotType];
	
	bool isTimePlot = [Utils boolFromDefaults:RCBDefaultCompareWindowXAxisType];
	[distanceTimePopup selectItemAtIndex:(isTimePlot ? 1 : 0)];
	
	guideFollows = [Utils intFromDefaults:RCBDefaultCompareWindowGuideFollows];
	[guideFollowsPopup selectItemAtIndex:-1];
	[guideFollowsPopup selectItemAtIndex:guideFollows];
}


-(IBAction)selectorSegmentedControlClicked:(id)sender
{
    int clickedSegment = (int)[sender selectedSegment];
    int clickedSegmentTag = (int)[[sender cell] tagForSegment:clickedSegment];
	if (clickedSegmentTag == 0)			// set start of compare region
	{
		[self.profilesTransparentView setCompareRegionStart];
	}
	else if (clickedSegmentTag == 1)	// unselect start/end compare region
	{
		[self.profilesTransparentView unselectCompareRegion];
	}
	else								// set end of compare region
	{
		[self.profilesTransparentView setCompareRegionEnd];
	}
}


-(float)startingDistance
{
	return profilesTransparentView.minDist;
}


-(void)setStartingDistance
{
}

-(float)findLapDistanceForTrack:(CompareProfileViewController*)pvc lapIndex:(int)lapIndex
{
	Track* track = pvc.track;
	float d = -1.0;
	NSArray* laps = track.laps;
	if (laps && lapIndex < (laps.count))
	{
		pvc.lapOffset = lapIndex;
		Lap* lap = [laps objectAtIndex:lapIndex];
		int pos = [track lapStartingIndex:lap];
		d = [[[track goodPoints] objectAtIndex:pos] distance];
	}
	return d;
}	


-(void)setSelectedActivityToNextOrPreviousLap:(BOOL)setToNext
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		ActivityDetailView* adv = pvc.adView;
		if (adv == [[self window] firstResponder])
		{
			int newLap = setToNext ? pvc.lapOffset+1 : pvc.lapOffset-1;
			if (newLap < 0) newLap = 0;
			float d = 0.0;
			if (newLap > 0)
			{ 
				d = [self findLapDistanceForTrack:pvc
										 lapIndex:newLap];
			}
			else
			{
				pvc.lapOffset = 0;
			}
			if (d >= 0.0)
			{
				float dist = adv.maxdist - adv.mindist;
				[adv setDistanceOverride:d
									 max:d+dist];
				[self rtz:self];
			}
		}
	}
}


-(void)setPVCToRulerPosition:(CompareProfileViewController*)pvc
{
	ActivityDetailView* adv = pvc.adView;
	float mnd = adv.mindist;
	float mxd = adv.maxdist;
	float dx = profilesTransparentView.curDist - profilesTransparentView.minDist;
	[adv setDistanceOverride:mnd+dx
						 max:mxd+dx];
}

-(void)setAllToRulerPosition
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		[self setPVCToRulerPosition:pvc];
	}
	float cd = profilesTransparentView.curDist;
	profilesTransparentView.minDist = cd;
	profilesTransparentView.curDist = profilesTransparentView.minDist;
	profilesTransparentView.maxDist += cd;
	[self rtz:self];
}



-(void)setSelectedActivityToRulerPosition
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		ActivityDetailView* adv = pvc.adView;
		if (adv == [[self window] firstResponder])
		{
			[self setPVCToRulerPosition:pvc];
		}
	}
	[self rtz:self];
}



-(IBAction)setToLap:(id)sender
{
	int idx = (int)[sender indexOfSelectedItem] - 1;		//NOTE: always returns >= 1 when selecting items in pull-down
	if (idx == 0)
	{
		[self setAllToRulerPosition];
	}
	else if (idx == 1)
	{
		[self doZoom:NO];
	}
	else if (idx > 1)
	{
		int lapIdx = idx-1;
		CompareProfileViewController* pvc = [self pvcWithMostLaps];
		Track* t = pvc.track;
		float defaultStart= 0.0;
		float dist = 0.0;
		if (t) 
		{
			defaultStart = [self findLapDistanceForTrack:pvc
												lapIndex:lapIdx];
			if (defaultStart < 0.0) defaultStart = 0.0;
			dist = [t distance] - defaultStart;
			for (CompareProfileViewController* pvc in profileControllerArray)
			{
				Track* track = pvc.track;
				float start = defaultStart;
				if (track && track != t)
				{
					start = [self findLapDistanceForTrack:pvc
												 lapIndex:lapIdx];
					if (start < 0.0) start = defaultStart;
				}
				ActivityDetailView* adv = pvc.adView;
				[adv setDistanceOverride:start
									 max:start+dist];
				[pvc.transparentView setFastestDistance:0.0
										 startingOffset:[pvc.adView mindist]];
			}
			profilesTransparentView.startRegionDist = 0.0;
			profilesTransparentView.endRegionDist = dist;
			[profilesTransparentView zoomToSelection];
			float dx = profilesTransparentView.maxDist - profilesTransparentView.minDist;
			if (dx > 0.0)
			{
				float v = origMaxDistance/dx;
				///printf("ZOOM TO: %0.1f\n", v);
				[scaleSlider setFloatValue:v];
			}
			[self rtz:self];
		}	
	}
}


-(IBAction)setScale:(id)sender
{
	float v = [sender floatValue];
	if (v > 0.0 && [profileControllerArray count] > 0)
	{
		float mx = profilesTransparentView.maxDist;
		float mn = profilesTransparentView.minDist;
		float cd = profilesTransparentView.curDist;
		float ndx = origMaxDistance/v;
		float omn = mn;
		mn = cd - ((cd-mn)*ndx/(mx-mn));
		mx = mn + ndx;
		///printf("v:%0.1f ndx:%0.1f min:%0.1f max:%0.1f cur:%01.f\n", v, ndx, mn, mx, cd);
		profilesTransparentView.minDist = mn;
		profilesTransparentView.maxDist = mx;
		for (CompareProfileViewController* pvc in profileControllerArray)
		{
			if (pvc.track != nil)
			{
				ActivityDetailView* adv = pvc.adView;
				float mn_off = 0.0;
				mn_off = mn - omn;
				float nmn = adv.mindist + mn_off;
				[adv setDistanceOverride:nmn 
									 max:nmn + ndx];
			}
		}
		[profilesTransparentView updateAll];
	}
	[[AnimTimer defaultInstance] forceUpdate];
	///[self rtz:self];
}


-(void)doZoom:(BOOL)zoomIn
{
	float delta = profilesTransparentView.startRegionDist - profilesTransparentView.minDist;
	if (zoomIn)			// set start of compare region
	{
		[profilesTransparentView zoomToSelection];
	}
	else
	{
		[profilesTransparentView zoomOut:0 
									 max:origMaxDistance];
	}
	
	float dist = profilesTransparentView.maxDist - profilesTransparentView.minDist;
	
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if (pvc.track != nil)
		{
			ActivityDetailView* adv = pvc.adView;
			float mn = zoomIn ? adv.mindist + delta : 0;
			[adv setDistanceOverride:mn
								 max:mn+dist];
			if (!zoomIn) pvc.lapOffset = 0;
		}
	}
	float dx = profilesTransparentView.maxDist - profilesTransparentView.minDist;
	if (dx > 0.0)
	{
		float v = origMaxDistance/dx;
		[scaleSlider setFloatValue:v];
	}
	[self rtz:self];
    [[AnimTimer defaultInstance] updateTimerDuration];
}


-(IBAction)zoom:(id)sender
{
	int tag = (int)[sender tag];
	[self doZoom:(tag == 1)];
}



-(IBAction)done:(id)sender
{
	[[self window]  close];
}


-(void)updateMapViewSizes
{
	///float d = [mainSplitView dividerThickness];
	// NOTE: NSSplitView has 'flipped' coordinate system (y=0 at the top)
	[leftSplitView adjustSubviews];
	// bugfix -- remove divider thickness from frame width to get proper map frames
	NSRect fr = [mapView frame];
	///fr.size.width -= d;
	[mapView setFrame:fr];
	NSRect zfr = [zoomMapView frame];
	///zfr.size.width -= d;
	[zoomMapView setFrame:zfr];
	///printf("n: [%0.1f, %0.1f] %0.1fx%0.1f\n", fr.origin.x, fr.origin.y, fr.size.width, fr.size.height);
	///printf("z: [%0.1f, %0.1f] %0.1fx%0.1f\n", zfr.origin.x, zfr.origin.y, zfr.size.width, zfr.size.height);
	NSRect rsfr = [mainSplitView frame];
	zfr.origin.x += rsfr.origin.x;
	zfr.origin.y = rsfr.origin.y;		// zoom map is always starting at y=0 within content rect
	zfr.origin = [[self window] convertBaseToScreen:zfr.origin];
	//zfr = NSInsetRect(zfr, 10.0, 10.0);
	NSRect vfr = zfr;
	vfr.origin = NSZeroPoint;
	///printf("vz: [%0.1f, %0.1f] %0.1fx%0.1f\n", zfr.origin.x, zfr.origin.y, zfr.size.width, zfr.size.height);
	[zoomMapTransparentView setFrame:vfr];
	[zoomMapTransparentView setBounds:vfr];
	[zoomMapTransparentView setNeedsDisplay:YES];
	[zoomMapTransparentWindow setFrame:zfr 
							   display:YES];
	
	
	fr.origin.x += rsfr.origin.x;
	fr.origin.y += rsfr.origin.y;
	fr.origin.y += zfr.size.height + [leftSplitView dividerThickness];
	fr.origin = [[self window] convertBaseToScreen:fr.origin];
	//fr = NSInsetRect(fr, 10.0, 10.0);
	vfr = fr;
	vfr.origin = NSZeroPoint;
	[mapTransparentView setFrame:vfr];
	[mapTransparentView setBounds:vfr];
	[mapTransparentView setNeedsDisplay:YES];
	[mapTransparentWindow setFrame:fr 
						   display:YES];
}
	
	
-(void)updateProfileViewsSizes
{
	NSRect fr = [profilesContainerView frame];
	self.profilesTransparentView.frame = profilesContainerView.bounds;
	self.profilesTransparentView.bounds = profilesContainerView.bounds;
	[self.profilesTransparentView layoutViewSublayers];
	[self.profilesTransparentView.layer setNeedsDisplay];
	NSRect sfr = [mainSplitView frame];
	NSRect cfr = [rightContentView frame];
	int numTracks = (int)[trackArray count];
	float containerH = fr.size.height - RULER_HEIGHT;
	int minViewAreas = 2;
	int nv = self.numViews >= minViewAreas ? self.numViews : minViewAreas;
	if (numTracks > 0)
	{
		float areaH = containerH/nv;
		float h = areaH;
		NSRect afr = fr;
		afr.origin.x = 0.0;
		afr.origin.y = containerH - (areaH);
		afr.size.height = h;
		fr.origin.y = fr.origin.y + containerH - (areaH );
		fr.size.height = h;
		NSRect twfr = NSInsetRect(fr, 10.0, 10.0);
		twfr.size.height += 10.0;
		twfr.origin.x += sfr.origin.x + cfr.origin.x;
		twfr.origin.y += sfr.origin.y;
		twfr.origin = [[self window] convertBaseToScreen:twfr.origin];
		NSRect tvfr = twfr;
		tvfr.origin = NSZeroPoint;
		for (CompareProfileViewController* pvc in profileControllerArray)
		{
			if (pvc.track != nil)
			{
				[pvc.adView setFrame:afr];
				[pvc.transparentView setFrame:tvfr];
				[pvc.transparentView setBounds:tvfr];
				[pvc.transparentView.layer setNeedsDisplay];
				[pvc.adView setNeedsDisplay:YES];
				[pvc.transparentView setNeedsDisplay:YES];
				[pvc.transparentWindow setFrame:twfr 
										display:YES];
				afr.origin.y -= areaH;
				twfr.origin.y -= areaH;
			}
		}
	}
}


-(void)updatePos:(id)junk
{
	[self updatePosition:0.0
				 reverse:NO
			   animating:NO];
	int scale = [mapView scale];
	scale -= 3;
	if (scale < 1) scale = 1;
	[zoomMapView setScale:scale];
}

-(void)updateTracks
{
	lastFocusedPVC = nil;
	self.trackArray = [self.trackArray sortedArrayUsingSelector:@selector(compareByMovingDuration:)];
    NSUInteger numTracks = [trackArray count];
	if (numTracks > 0)
	{
		[profilesContainerView enablePlaceholderText:NO];
		[mapView setCurrentTrack:[trackArray objectAtIndex:0]];
		[zoomMapView setCurrentTrack:[trackArray objectAtIndex:0]];
	}
	else
	{
		[profilesContainerView enablePlaceholderText:YES];
	}

	[mapTransparentView setAllDotsHidden];
	[zoomMapTransparentView setAllDotsHidden];
	
	int trackIdx = 0;
	float maxpd = 0.0;
	float maxdis = 0.0;
	///NSResponder* curResponder = profilesContainerView;
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if (trackIdx < numTracks)
		{
			[[AnimTimer defaultInstance] unregisterForTimerUpdates:pvc];
			Track* t = [trackArray objectAtIndex:trackIdx];
			[t setAnimID:trackIdx];
			[t setAnimIndex:0];
			[pvc setTrack:t];
			CWTransparentView* tv = (CWTransparentView*) pvc.adView.transparentView;
			tv.track = t;
			float pd = [pvc.adView plotDuration];
			if (pd > maxpd) maxpd = pd;
			float dis = [t distance];
			if (dis > maxdis) maxdis = dis;
			///[curResponder setNextResponder:pvc.adView];
			////curResponder = pvc.adView; 
			if (trackIdx == 0)
			{
				[[self window] makeFirstResponder:pvc.adView];
				lastFocusedPVC = pvc;
			}
		}
		else
		{
			pvc.track = nil;
			pvc.transparentView.track = nil;
		}
		++trackIdx;
	}
	///[curResponder setNextResponder:zoomMapView];
	
	self.profilesTransparentView.minDist = 0.0;
	self.profilesTransparentView.maxDist = maxdis;
	origMaxDistance = maxdis;
	[self.profilesTransparentView setNextResponder:profilesContainerView];
	
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if (pvc.track != nil)
		{
			[[AnimTimer defaultInstance] registerForTimerUpdates:pvc];
			[pvc.adView setXAxisIsTime:xAxisIsTime];
			[pvc.adView setHidden:NO];
			[pvc.adView setPlotDurationOverride:maxpd];
			[pvc.adView setDistanceOverride:0.0 
										max:maxdis];
		}
		else
		{
			[pvc.adView setHidden:YES];
		}
	}
	[self updateProfileViewsSizes];
	[self updateMapViewSizes];
	[self updatePos:nil];
	[self updateLapMenu];
	[self setupProfileContextualMenu];
    [[AnimTimer defaultInstance] updateTimerDuration];
	[[AnimTimer defaultInstance] forceUpdate];
}


-(CompareProfileViewController*)pvcWithMostLaps
{
	int maxLaps = 0;
	CompareProfileViewController* maxLapPVC = nil;
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		Track* track = pvc.track;
		NSArray* laps = track.laps;
		if (laps)
		{
			if (laps.count > maxLaps)
			{
				maxLaps = (int)laps.count;
				maxLapPVC = pvc;
			}
		}
	}
	return maxLapPVC;
}
	

-(void)updateLapMenu
{
	while( [alignToPopUpButton numberOfItems] > 1)
	{
		[alignToPopUpButton removeItemAtIndex:([alignToPopUpButton numberOfItems]-1)];
	}
	CompareProfileViewController* pvc = [self pvcWithMostLaps];
	Track* maxLapTrack = pvc ? pvc.track : nil;
	if (maxLapTrack)
	{
        NSUInteger maxLaps = maxLapTrack.laps.count;
		[alignToPopUpButton addItemWithTitle:@"Current ruler position"];
		[alignToPopUpButton addItemWithTitle:@"Activity start"];
		for (int i=0; i<(maxLaps-1); i++)
		{
			[alignToPopUpButton addItemWithTitle:[NSString stringWithFormat:@"Lap %d", i+1]];
		}
	}
}


-(IBAction)setXAxisType:(id)sender
{
	xAxisIsTime = [sender indexOfSelectedItem] > 0 ? YES : NO;
	NSLog(@"isTime: %d %@", (int)[sender indexOfSelectedItem], xAxisIsTime ? @"YES" : @"NO");
	[Utils setBoolDefault:xAxisIsTime
				   forKey:RCBDefaultCompareWindowXAxisType];
	[self updateTracks];
}	


-(IBAction)setPlotType:(id)sender
{
	NSMenuItem* selectedItem = [sender selectedItem];
	tPlotType pt = (tPlotType)[selectedItem tag];
	BOOL showPace = (pt == kPace);
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		if (pvc.track != nil)
		{
			for (int plotType = (int)kFirstPlotType; plotType < kNumPlotTypes; ++plotType)
			{
				if (plotType != kAltitude)
				{
					[pvc.adView setPlotEnabled:(tPlotType)plotType
									   enabled:NO
								updateDefaults:NO];
				}
			}
			[pvc.adView setShowPace:showPace];
			[pvc.transparentView setShowingPace:showPace];
			[pvc.adView setPlotEnabled:showPace ? kSpeed : pt
							   enabled:YES
						updateDefaults:NO];
			[pvc.adView setNeedsDisplay:YES];
		}
	}
	
	[Utils setIntDefault:(int)pt
				  forKey:RCBDefaultCompareWindowPlotType];
}


-(IBAction)setGuideFollows:(id)sender;
{
	int idx = (int)[sender indexOfSelectedItem];
	[Utils setIntDefault:idx
				  forKey:RCBDefaultCompareWindowGuideFollows];
	guideFollows = idx;
}



- (IBAction) displayHelp:(id)sender
{
	NSRect fr = [[self window] frame];
	NSRect panelRect = [[summaryPanelController window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);
	
	[[summaryPanelController window] setFrameOrigin:origin];
	[summaryPanelController showWindow:self];
	[NSApp runModalForWindow:[summaryPanelController window]];
	[[summaryPanelController window] orderOut:[self window]];
	[[self window] makeKeyAndOrderFront:self];
}


- (void)windowDidResize:(NSNotification *)aNotification
{
	///NSRect bds = [self.window frame];
	///printf("window resize: %0.1fx%0.1f\n",bds.size.width, bds.size.height); 
	////[self updateProfileViewsSizes];
	///[self updateMapViewSizes];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[self doCleanup];
	if (mainWindowController && [mainWindowController respondsToSelector:@selector(dismissCompareWindow:)])
	{
		[(id)mainWindowController dismissCompareWindow:self];
	}
}


- (void)windowDidLoad
{
	[self updateProfileViewsSizes];
	BOOL dontShowHelp = [Utils boolFromDefaults:RCBDefaultCompareWindowDontShowHelp];
	if (!dontShowHelp)
	{
		[self displayHelp:self];
	}
}


- (void)windowWillLoad
{
}


#define MIN_PROFILE_VIEW_WIDTH			543
- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (splitView == mainSplitView)
	{
		NSRect newFrame = [splitView frame];
		NSRect leftFrame = [leftContentView frame];
		NSRect rightFrame = [rightContentView frame];
		float dw = [splitView dividerThickness];
		if (rightFrame.size.width < MIN_PROFILE_VIEW_WIDTH)
		{
			float diff = MIN_PROFILE_VIEW_WIDTH - rightFrame.size.width;
			leftFrame.size.width -= diff;
		}
		leftFrame.size.height = newFrame.size.height;
		leftFrame.origin = NSMakePoint(0,0);
		rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dw;
		rightFrame.size.height = newFrame.size.height;
		rightFrame.origin.x = leftFrame.size.width + dw;
		rightContentView.frame = rightFrame;
		leftContentView.frame = leftFrame;
	}
	[splitView adjustSubviews];
}


- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	id obj = [aNotification object];
	if (obj == mainSplitView) [self updateProfileViewsSizes];
	[self updateMapViewSizes];
	[self updatePos:nil];
	[mapView setDefaults];
	[[AnimTimer defaultInstance] forceUpdate];
}



#if 0
- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	float newMin = proposedMin;
	if (splitView == mainSplitView)
	{
		printf("min MAIN proposed:%0.1f\n", proposedMin);
	}
	else if (splitView == leftSplitView)
	{
		printf("min LEFT proposed:%0.1f\n", proposedMin);
	}
	return newMin;
}


- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == mainSplitView)
	{
		printf("max MAIN proposed:%0.1f\n", proposedMax);
	}
	else if (splitView == leftSplitView)
	{
		printf("max LEFT proposed:%0.1f\n", proposedMax);
	}
	return proposedMax;
}
#endif


- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == mainSplitView)
	{
		NSRect bounds = [splitView bounds];
		///printf("pos MAIN proposed:%0.1f\n", proposedPosition);
		if (proposedPosition < 343.0) proposedPosition = 343;
		
		if ((bounds.size.width - proposedPosition) < (MIN_PROFILE_VIEW_WIDTH+8)) proposedPosition = bounds.size.width -  (MIN_PROFILE_VIEW_WIDTH+8);
	}
	else if (splitView == leftSplitView)
	{
		///printf("pos LEFT proposed:%0.1f\n", proposedPosition);
	}
	return proposedPosition;
}


-(void)resetTracks:(NSArray*)ta mainWC:(NSWindowController*)wc
{
	self.trackArray = ta;
	self.numViews = (int)[trackArray count];
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		pvc.track = nil;
		pvc.transparentView.track = nil;
	}
	[self updateTracks];
	[self focusChanged:nil];
}


- (IBAction)play:(id)sender
{
	AnimTimer* at = [AnimTimer defaultInstance];
	if ([sender intValue] == NSControlStateValueOn)
	{
		[at stop:self];
		[at play:self reverse:NO];
		[profilesTransparentView setHidePosition:YES];
		///[reverseButton setIntValue:0];
	}
	else
	{
		[at stop:self];
	}
}


- (IBAction)reverse:(id)sender
{
	AnimTimer* at = [AnimTimer defaultInstance];
	if ([sender intValue] == NSControlStateValueOn)
	{
		[at stop:self];
		[at play:self reverse:YES];
		///[playButton setIntValue:0];
	}
	else
	{
		[at stop:self];
	}
}

- (IBAction)rtz:(id)sender
{
	fastestPVC = nil;
	[[AnimTimer defaultInstance] rewind];
	///[reverseButton setIntValue:0];
}


- (IBAction)rte:(id)sender
{
	fastestPVC = nil;
	[[AnimTimer defaultInstance] fastForward];
	///[playButton setIntValue:0];
	///[reverseButton setIntValue:0];
}



- (IBAction)stop:(id)sender
{
	fastestPVC = nil;
	AnimTimer* at = [AnimTimer defaultInstance];
	if (![at animating])
	{
		[at updateTimerDuration];
	}
	[at togglePlay:nil];
	///[playButton setIntValue:0];
	///[reverseButton setIntValue:0];
}

- (NSButton*) playButton
{
	return playButton;
}


- (NSButton*) reverseButton
{
	return reverseButton;
}


- (void) updateSpeedFactorText
{
	[speedFactorText setStringValue:[NSString stringWithFormat:@"%2.0fx",[[AnimTimer defaultInstance] speedFactor]]];
}


- (IBAction)setSpeedFactor:(id)sender
{
	[[AnimTimer defaultInstance] setSpeedFactor:[sender floatValue]];
	[self updateSpeedFactorText];
}


- (IBAction)setLocation:(id)sender
{
	AnimTimer* at = [AnimTimer defaultInstance];
	[at locateToPercentage:[sender floatValue]];
	if ([at animating] && [at playingInReverse])
	{
		[at play:self
		 reverse:NO];
	}
}


-(void)zoomDetailMapOneLevel:(BOOL)zoomIn
{
	[zoomMapView zoomOneLevel:zoomIn];
	[mapTransparentView setZoomedInMapRect:[mapView calcRectInMap:[zoomMapView utmMapArea]]];
}


- (void)keyDown:(NSEvent *)theEvent
{
	int kc = [theEvent keyCode];
	switch (kc)
	{
		case 49:		// SPACE
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
			break;
			
		case 34:		// "I"
			[self zoomDetailMapOneLevel:YES];
			break;
			
		case 31:		// "O"
			[self zoomDetailMapOneLevel:NO];
			break;
			
		case 45:		// "N"
			[self setSelectedActivityToNextOrPreviousLap:YES];
			break;
			
		case 35:		// "P"
			[self setSelectedActivityToNextOrPreviousLap:NO];
			break;
			
		case 51:
			[self removeSelectedActivity:self];
			break;
			
			
	}
}

enum
{
	kCM_ZoomInAll,
	kCM_ZoomOutAll,
	kCM_AlignAllToRulerPosition,
	kCM_AlignTrackToNextLapMarker,
	kCM_AlignTrackToPreviousLapMarker,
	kCM_AlignTrackToRulerPosition,
	kCM_ZoomInDetailMap,
	kCM_ZoomOutDetailMap,
	kCM_RemoveActivity,
};

	
-(void)zoomProfiles:(id)sender
{
	int tag = (int)[sender tag];
	[self doZoom:(tag == kCM_ZoomInAll ? YES : NO)];
}


-(void)zoomDetailMap:(id)sender
{
	[self zoomDetailMapOneLevel:[sender tag] == kCM_ZoomInDetailMap];
}


-(void)alignToRulerPosition:(id)sender
{
	int tag = (int)[sender tag];
	if (tag == kCM_AlignAllToRulerPosition)
	{
		[self setAllToRulerPosition];
	}
	else if (tag == kCM_AlignTrackToRulerPosition)
	{
		[self setSelectedActivityToRulerPosition];
	}
}


-(void)alignToNextLapMarker:(id)sender
{
	int tag = (int)[sender tag];
	if (tag == kCM_AlignTrackToPreviousLapMarker)
	{
		[self setSelectedActivityToNextOrPreviousLap:NO];
	}
	else if (tag == kCM_AlignTrackToNextLapMarker)
	{
		[self setSelectedActivityToNextOrPreviousLap:YES];
	}
}


-(void)removeSelectedActivity:(id)sender
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		ActivityDetailView* adv = pvc.adView;
		if (adv == [[self window] firstResponder])
		{
			Track* t = pvc.track;
			NSMutableArray* marr = [NSMutableArray arrayWithArray:self.trackArray];
			[marr removeObjectIdenticalTo:t];
			self.trackArray = marr;
			[self updateTracks];
			break;
		}
	}
}


-(NSMenu*)buildCM
{
	NSMenu* cm = [[NSMenu alloc] init];
	NSMenuItem* mi;
	//[cm setShowsStateColumn:YES];
	
	[[cm addItemWithTitle:@"Zoom in all activities to non-shaded area"
				   action:@selector(zoomProfiles:)
			keyEquivalent:@""] setTag:kCM_ZoomInAll];
	
	[[cm addItemWithTitle:@"Zoom out all activities"
				   action:@selector(zoomProfiles:)
			keyEquivalent:@""] setTag:kCM_ZoomOutAll];
	
	[[cm addItemWithTitle:@"Align all activities to selected ruler position"
				   action:@selector(alignToRulerPosition:)
			keyEquivalent:@""] setTag:kCM_AlignAllToRulerPosition];
	
	//--------------------------------------------------------------------------
	[cm addItem:[NSMenuItem separatorItem]];
	
	mi = [cm addItemWithTitle:@"Zoom in detail map"
						action:@selector(zoomDetailMap:)
				 keyEquivalent:@"i"];
	[mi setTag:kCM_ZoomInDetailMap];
	[mi setKeyEquivalentModifierMask:0];
	
	mi = [cm addItemWithTitle:@"Zoom out detail map"
						action:@selector(zoomDetailMap:)
				keyEquivalent:@"o"];
	[mi setTag:kCM_ZoomOutDetailMap];
	[mi setKeyEquivalentModifierMask:0];
	
	//--------------------------------------------------------------------------
	[cm addItem:[NSMenuItem separatorItem]];
	
	mi = [cm addItemWithTitle:@"Align selected activity to next lap marker"
					   action:@selector(alignToNextLapMarker:)
				keyEquivalent:@"n"];
	[mi setTag:kCM_AlignTrackToNextLapMarker];
	[mi setKeyEquivalentModifierMask:0];
	
	mi = [cm addItemWithTitle:@"Align selected activity to previous lap marker"
						action:@selector(alignToNextLapMarker:)
				keyEquivalent:@"p"];
	[mi setTag:kCM_AlignTrackToPreviousLapMarker];
	[mi setKeyEquivalentModifierMask:0];
	
	mi = [cm addItemWithTitle:@"Align selected activity to selected ruler position"
						action:@selector(alignToRulerPosition:)
				keyEquivalent:@"r"];
	[mi setTag:kCM_AlignTrackToRulerPosition];
	[mi setKeyEquivalentModifierMask:0];

	unichar del = NSDeleteCharacter;
	NSString* s = [NSString stringWithCharacters:&del length:1];
	mi = [cm addItemWithTitle:@"Remove selected activity"
					   action:@selector(removeSelectedActivity:)
				keyEquivalent:s];
	[mi setTag:kCM_AlignTrackToRulerPosition];
	[mi setKeyEquivalentModifierMask:0];
	
	
	return cm;
}


-(void) setupProfileContextualMenu
{
	
	SEL sel = @selector(buildCM);
	NSMethodSignature* sig = [CompareWindowController instanceMethodSignatureForSelector:sel];
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
	[inv setSelector:sel];
	[inv setTarget:self];
	[profilesTransparentView setContextualMenuInvocation:inv];
}   


-(void) prefsChanged:(NSNotification *)notification
{
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		[pvc.transparentView prefsChanged];
	}
	[profilesTransparentView prefsChanged];
}


//---- AnimTimer protocol methods ----------------------------------------------


-(Track*) animationTrack
{
	Track* t = nil;
	if ([trackArray count] > 0)
		t = [trackArray objectAtIndex:0];
	return t;
}


-(void) beginAnimation
{
}


-(void) endAnimation
{
}



-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev  animating:(BOOL)anim
{
	NSString* s = [[NSString alloc] initWithFormat:@"%02.2d:%02.2d:%02.2d", (int)(trackTime/(60*60)), (int)((trackTime/60))%60, ((int)trackTime)%60];
	[timecodeText setStringValue:s];
	AnimTimer * at = [AnimTimer defaultInstance];
	float endTime = [at endingTime];
	if (endTime > 0.0)
	{
		[locationSlider setFloatValue:[at animTime]*100.0/endTime];
	}
	CompareProfileViewController* fastPVC = nil;
	float maxDist = -1.0;
	int focusAID = 0;
    NSUInteger num = [profileControllerArray count];
	for (int i=0; i<num; i++)
	{
		CompareProfileViewController* pvc = [profileControllerArray objectAtIndex:i];
		if ([pvc isFocused])
		{
			Track* t = pvc.track;
			if (t != nil)
			{
				focusAID = i;
				[zoomMapView updateDetailedPosition:trackTime + t.animTimeBegin
											reverse:[[AnimTimer defaultInstance] playingInReverse]
										  animating:YES];
			}
			break;
		}
	}
	int aid = 0;
	int fastestAID = 0;
	float focusDist = -1.0;
	for (CompareProfileViewController* pvc in profileControllerArray)
	{
		Track* t = pvc.track;
		int pos = 0;
		if (t != nil)
		{
            int numPoints = (int)[[t goodPoints] count];
			pos = [t animIndex];
			if (pos >= numPoints) pos = numPoints-1;
			TrackPoint* pt = [[t goodPoints] objectAtIndex:pos];
			TrackPoint* nextPt = nil;
			float ratio = 0.0;
			if (!rev && (pos < (numPoints-1)))
			{
				nextPt = [[t goodPoints] objectAtIndex:pos+1];
			}
			else if (rev && (pos > 0))
			{
				nextPt = [[t goodPoints] objectAtIndex:pos-1];
			} 
			float dist = [pt distance] - [pvc.adView mindist];
			if (nextPt)
			{
				float ptTime = [pt activeTimeDelta];
				float nextTime = [nextPt activeTimeDelta];
				if ((ptTime != 0) && (ptTime != nextTime)) 
				{
					ratio = ((trackTime + t.animTimeBegin)  - ptTime)/(nextTime - ptTime);
					dist = [pt distance] + (ratio*([nextPt distance]-[pt distance]));
					dist -= [pvc.adView mindist];
				}
			}
			if (dist > maxDist)
			{
				fastPVC = pvc;
				maxDist = dist;
				fastestAID = aid;
			}
			[mapView updateAnimUsingPoint:pt
								nextPoint:nextPt
									ratio:ratio
								   animID:aid];
			if (aid == focusAID)
			{
				focusDist = dist;
				//[zoomMapView updateDetailedPosition:trackTime + t.animTimeBegin
				//							reverse:[[AnimTimer defaultInstance] playingInReverse]
				//						  animating:YES];
			}
			else
				[zoomMapView updateAnimUsingPoint:pt
										nextPoint:nextPt
											ratio:ratio
										   animID:aid];
				
		}
		++aid;
	}
	
	[mapTransparentView setZoomedInMapRect:[mapView calcRectInMap:[zoomMapView utmMapArea]]];
	
	{
		fastestPVC = fastPVC;
		for (CompareProfileViewController* pvc in profileControllerArray)
		{
			if (pvc.track != nil)
			{
				[pvc.transparentView setFastestDistance:maxDist
										 startingOffset:[pvc.adView mindist]];
			///[pvc.transparentView.highlightLayer setNeedsDisplay];
			}
		}
		int aid = -1;
		float d = 0.0;
		if (guideFollows == kGuideFollowsFastest)
		{
			aid = fastestAID;
			d = maxDist;
		}
		else if (guideFollows == kGuideFollowsSelected)
		{
			aid = focusAID;
			d = focusDist;
		}
		[self.profilesTransparentView setFocusDistance:d
												animID:aid];
	}
}



@end
