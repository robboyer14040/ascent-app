/* ActivityDetailView - Activity DETAIL View */

#import <Cocoa/Cocoa.h>
#import "Defs.h"
#import "ProfileTransparentView.h"

@class Track;
@class ActivityDetailTransparentView;
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

@protocol ActivityDetailViewDelegate <NSObject>
- (void)selectionComplete:(NSUInteger)startPointIndex
            endPointIndex:(NSUInteger)endPointIndex;
@end

@interface ActivityDetailView : NSView

@property(nonatomic, assign) NSView<ProfileTransparentView>     *transparentView;
@property(nonatomic, assign) id<ActivityDetailViewDelegate>     delegate; // Note: assign/weak for no retain cycle

@property(nonatomic) BOOL               drawHeader;
@property(nonatomic) BOOL               dragStart;
@property(nonatomic) BOOL               showVerticalTicks;
@property(nonatomic) BOOL               showHorizontalTicks;
@property(nonatomic) NSTimeInterval     plotDuration;
@property(nonatomic) float              topAreaHeight;
@property(nonatomic, readonly) float    maxdist;
@property(nonatomic, readonly) float    mindist;
@property(nonatomic) BOOL               overrideDistance;
@property(nonatomic) float              vertPlotYOffset;

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
-(void) prefsChanged;

@end
