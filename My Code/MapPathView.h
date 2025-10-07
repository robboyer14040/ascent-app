/* MapPathView */

#import <Cocoa/Cocoa.h>


@class Track;
@class Lap;
@class NDRunLoopMessenger;
@class TileInfo;
@class PathPoint;
@class TrackPoint;
@class TransparentMapView;


@interface TileFetcher : NSObject
@property (atomic) BOOL tileFetchThreadRunning;     // atomic flag
@property (atomic, strong) NSThread *tileThread;    // the worker thread
@property (atomic, strong) NSPort *keepAlivePort;   // keeps run loop alive
@property (atomic, strong) NDRunLoopMessenger *runLoopMessenger; // strong ref
@end


@interface MapPathView : NSView
@property (nonatomic) float scrollWheelSensitivity;
@property (nonatomic) BOOL enableMapInteraction;

-(void) setTransparentView:(TransparentMapView*) v;
-(void) setCurrentTrack:(Track*) tr;
-(Lap *)selectedLap;
-(void)setSelectedLap:(Lap *)value;
-(int)dataType;
-(void)setDataType:(int) dt;
-(float)mapOpacity;
-(void)setMapOpacity:(float) op;
-(float)pathOpacity;
-(void)setPathOpacity:(float) op;
-(void)updateTrackAnimation:(int)currentTrackPos animID:(int)aid;
-(void)updateDetailedPosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim;
-(void)cancelAnimation;
-(void)beginAnimation;
-(int) scale;
-(void)setScale:(int)s;
-(void)moveHoriz:(int)incr;
-(void)moveVert:(int)incr;
-(BOOL)showLaps;
-(void)setShowLaps:(BOOL)sl;
-(void)setShowPath:(BOOL)sp;
-(void)setShowIntervalMarkers:(BOOL)show;
-(BOOL)showIntervalMarkers;
-(void)setIntervalIncrement:(float)incr;
-(BOOL)showPath;
-(void)setDefaults;
-(void)centerAtStart;
-(void)centerAtEnd;
- (void)setMoveMapDuringAnimation:(BOOL)moveMap;
-(void) getNonCachedMaps:(id)obj;
-(void) killAnimThread;
-(void) getATile:(TileInfo*)ti;
-(void) prepareToDie;
-(void) setContextualMenuInvocation:(NSInvocation*)inv;
- (void)setDataHudUpdateInvocation:(NSInvocation *)value;
- (void)centerOnMousePoint:(NSEvent*)ev;
- (void)forceRedisplay;
- (BOOL)colorizePaths;
- (void)setColorizePaths:(BOOL)value;
- (void)setSplitArray:(NSArray *)value;
- (BOOL)isDetailedMap;
- (void)setIsDetailedMap:(BOOL)value;
- (void) kickStartDrawing:(id)obj;
- (void) forceRedraw;
-(void)refreshMaps;
- (void)updateAnimUsingPoint:(TrackPoint*)pt nextPoint:(TrackPoint*)nextPt ratio:(float)ratio animID:(int)aid;
-(void)zoomOneLevel:(BOOL)zoomin;
-(NSRect)utmMapArea;
-(NSRect)calcRectInMap:(NSRect)utmMapArea;

@end
