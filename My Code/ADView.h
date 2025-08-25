/* ADView - Activity DETAIL View */

#import <Cocoa/Cocoa.h>
#import "Defs.h"
#import "ProfileTransparentView.h"

@class Track;
@class ADTransparentView;
@class Lap;


// component ids
typedef enum
{
   kEnabledControl,              // 0
   kLineStyleControl,
   kOpacityControl,
   kColorControl,
   kFillEnabledControl,
   kShowLapsEnabledControl,      //5
   kShowMarkersEnabledControl,
   kShowPeaksEnabledControl,
   kNumPeaksControl,
   kNumPeaksTextControl,
   kPeakThresholdControl,        //10
   kPeakThresholdTextControl,
   kShowHeartrateZonesControl,
   kPeakTypeControl,
   kNumPointsToAverageControl,
   kNumPointsToAverageTextControl,  //15
   kCrosshairsEnabledControl,
   kHudEnabledControl,
   kAnimationFollowsControl,
   kHudOpacityControl,
   kZonesOpacityControl,         // 20
   
   // add more here, up to 100 total
} tControlType;


enum
{
   kMinimumPlotTag = 100
};

static int typeComponentToTag(tPlotType type, int component)
{
   return (type*100) + component;
}

static int tagToComponent(int tag)
{
   return tag % 100;
}

static tPlotType tagToPlotType(int tag)
{
   return (tPlotType)(tag/100);
}


@interface ADView : NSView
{
	Track*								track;
	Lap*								lap;
	Track*								lastTrack;
	NSView<ProfileTransparentView>*		transparentView;
	NSMutableDictionary *				tickFontAttrs; 
	NSMutableDictionary *				animFontAttrs; 
	NSMutableDictionary *				headerFontAttrs; 
	NSMutableDictionary *				textFontAttrs; 
	NSMutableArray*						plotAttributesArray;
	float                   			minalt, maxalt, mindist, maxdist, lastdist, altdif;
	float                   			maxhr, maxsp, mingr, maxgr, maxcd, maxpwr;
	float                   			maxhrGR, maxspGR, mingrGR, maxgrGR, maxcdGR, maxpwrGR, mintempGR, maxtempGR;
	float                   			minhrGR, minspGR,  mincdGR, minpwrGR;
	NSTimeInterval          			plotDuration;
	float                   			maxDurationForPlotting;
	NSColor*                			animRectColor;
	NSImage*                			altSignImage;
	NSImage*                			lapMarkerImage;
	NSImage*                			startMarkerImage;
	NSImage*                			finishMarkerImage;
	NSImage*                			peakImage;
	NSBezierPath*           			altPath;
	NSBezierPath*           			hpath;
	NSBezierPath*           			dpath;
	NSBezierPath*           			spath;   
	NSInvocation*           			mContextualMenuInvocation;
	NSInvocation*           			mSelectionUpdateInvocation;
	NSInvocation*           			dataHudUpdateInvocation;
	NSNumberFormatter*					numberFormatter;
	NSPoint                 			prevPt;
	NSRect                  			lastBounds; 
	NSRect                  			vertTickBounds;
	NSRect                  			horizTickBounds;
	int                     			currentTrackPos, numPos;
	int                     			peakType;
	int                     			dataRectType;
	int                     			numAltitudeVertTickPoints; 
	int                     			maxHorizTicks;
	int                     			maxVertTicks;
	int									posOffsetIndex;
	NSRect                  			dataRect;
	BOOL                    			firstAnim;
	BOOL                    			bypassAnim;
	BOOL                    			showHRZones;
	BOOL                    			showLaps;
	BOOL                    			showMarkers;
	BOOL                    			showPowerPeakIntervals;
	BOOL                    			showPeaks;
	BOOL                    			showCrossHairs;
	BOOL                    			showHud;
	BOOL                    			animating;
	BOOL                    			xAxisIsTime;
	BOOL                    			lastXAxisIsTime;
	BOOL                    			showPace;
	BOOL                    			isStatute;
	BOOL								selectRegionInProgress;
	BOOL								trackHasPoints;
	BOOL								drawHeader;
	BOOL								showVerticalTicks;
	BOOL								showHorizontalTicks;
	BOOL								overrideDistance;
	BOOL								dragStart;
	int                     			numPeaks;
	int                     			peakThreshold;
	int                     			numAvgPoints;
	int									selectionStartIdx;
	int									selectionEndIdx;
	float                   			zonesOpacity;
	float                   			markerRightPadding;
	float								topAreaHeight;
	float								vertPlotYOffset;
}

@property(nonatomic) BOOL drawHeader;
@property(nonatomic) BOOL dragStart;
@property(nonatomic) BOOL showVerticalTicks;
@property(nonatomic) BOOL showHorizontalTicks;
@property(nonatomic) NSTimeInterval plotDuration;
@property(nonatomic) float topAreaHeight;
@property(nonatomic, readonly) float maxdist;
@property(nonatomic, readonly) float mindist;
@property(nonatomic) BOOL overrideDistance;
@property(nonatomic) float vertPlotYOffset;
@property(nonatomic, retain) NSView<ProfileTransparentView>*	 transparentView;

- (void)setTrack:(Track*)t forceUpdate:(BOOL)force;
- (Lap *)lap;
- (void)setLap:(Lap *)value;
- (int)numPlotTypes;
- (int)plotType:(int)idx;
- (NSPoint)plotControlPosition:(int)idx;
- (void)setPlotEnabled:(tPlotType)type enabled:(BOOL)enabled updateDefaults:(BOOL)upd;
- (BOOL)plotEnabled:(tPlotType)type;
- (void)setPlotColor:(tPlotType)type color:(NSColor*) color;
- (NSColor*)plotColor:(tPlotType)type;
- (void)setPlotOpacity:(tPlotType)type opacity:(float) opac;
- (float)plotOpacity:(tPlotType)type;
- (void) updateAnimation:(NSTimeInterval)trackTime reverse:(BOOL)rev;
- (void) setAnimPos:(int) pos;
- (void) stopAnim;
- (NSMutableArray*)plotAttributesArray;
- (void) setShowHeartrateZones:(BOOL)on;
- (BOOL) showHeartrateZones;
- (void) setShowPeaks:(BOOL)sp;
- (BOOL) showPeaks;
- (void) setNumPeaks:(int)np;
- (int) numPeaks;
- (void) setPeakThreshold:(int)pt;
- (int) peakThreshold;
- (void) setPeakType:(int)type;
- (int) peakType;
- (void) setShowPowerPeakIntervals:(BOOL)spp;
- (BOOL) showPowerPeakIntervals;
- (void) setDataRectType:(int)type;
- (int) dataRectType;
- (void) setShowCrossHairs:(BOOL)show;
- (BOOL) showCrossHairs;
- (void) setShowLaps:(BOOL)sl;
- (BOOL) showLaps;
- (void) setShowMarkers:(BOOL)sm;
- (BOOL) showMarkers;
- (int) currentPointIndex;
- (void) setNumAvgPoints:(int)np;
- (int) numAvgPoints;
- (void) setXAxisIsTime:(BOOL)isTime;
- (BOOL) xAxisIsTime;
- (void) setShowPace:(BOOL)show;
- (BOOL) showPace;
-(void)setPlotDurationOverride:(NSTimeInterval)pd;
-(void)setDistanceOverride:(float)minDist max:(float)maxDist;
-(void) setContextualMenuInvocation:(NSInvocation*)inv;
-(void) setSelectionUpdateInvocation:(NSInvocation*)inv;
- (void)setDataHudUpdateInvocation:(NSInvocation *)value;
- (int)selectionStartIdx;
- (int)selectionEndIdx;
- (NSArray*)selectedPoints;
- (int)selectionPosIdxOffset;
- (NSArray*) ptsForPlot;
-(void) setZonesOpacity:(float)v;
- (float) markerRightPad;
- (void) markersChanged;

@end
