/* MapPathView */

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class NDRunLoopMessenger;
@class TileInfo;
@class TransparentMapView;
@class PathPoint;
@class TrackPoint;


@interface TileFetcher : NSObject
@property (atomic) BOOL tileFetchThreadRunning;     // atomic flag
@property (atomic, strong) NSThread *tileThread;    // the worker thread
@property (atomic, strong) NSPort *keepAlivePort;   // keeps run loop alive
@property (atomic, strong) NDRunLoopMessenger *runLoopMessenger; // strong ref
@end

@interface MapPathView : NSView
{
    TileFetcher*            fetcher;
	id						transparentView;
	Track*					currentTrack;
	Lap*					selectedLap;
	Track*					lastTrack;
	NSArray*				splitArray;
	NSMutableArray*			plottedPoints;
	NSMutableDictionary*	tileCache;
	NSMutableArray*			tileFetchQueue;
	NSMutableArray*			currentMapImages;
	NSMutableArray*			averageXY;
	NSMutableDictionary *   textFontAttrs; 
	NSMutableDictionary *   mileageMarkerTextAttrs; 
	NSMutableData*			dataInProgress;
	float					mapOpacity;
	float					pathOpacity;
	int						dataType, lastDataType;
	int						scale;
	int						lastScale;
	float					tileWidth;
	float					tileHeight;
	float					initialX;     
	float					initialY;
	double					metersPerPixel;
	double					metersPerTile;
	double					utmX, utmY, utmW, utmH;    // area currently being shown in window
	double					tempX, tempY;
	double					utmEastingMin, utmEastingMax, utmNorthingMin, utmNorthingMax;    // utm bb of path
	int						leftTile, bottomTile;
	BOOL					showPath;
	BOOL					showLaps;
	BOOL					showIntervalMarkers;
	BOOL					overrideDefaults;
	BOOL					dragging;
	BOOL					animatingInPlace;
	BOOL					animatingNormally;
	BOOL					firstAnim;
	BOOL					colorizePaths;
	BOOL					moveMapDuringAnimation;
	BOOL					isDetailedMap;
	BOOL					enableMapInteraction;
	volatile BOOL			animThreadRunning;
	volatile BOOL			tileFetchThreadRunning;
	volatile BOOL			tileFetchThreadFinished;
	NSBezierPath*			trackPath;
	NSBezierPath*			lapPath;
	NSImage*				lapMarkerImage;
	NSImage*				startMarkerImage;
	NSImage*				finishMarkerImage;
	NSBitmapImageRep*		cachedImageRep;
	NSRect					lastBounds;
	NSRect					cachedRect;
	NSPoint					lastAnimPoint;
	NDRunLoopMessenger*		runLoopMessenger;
	NSURLConnection*		connection;
	NSString*				cacheFilePath;
	NSShadow *				dropShadow;
	TileInfo*				tileBeingFetched;
	PathPoint*				prevPathPoint;
	NSDate*					selectedLapEndTime;
	NSInvocation*			mContextualMenuInvocation;
	NSInvocation*			dataHudUpdateInvocation;
	int						refEllipsoid;
	double					factor;
	int						zoneMin;
	int						zoneMax;
	int						numHorizTiles;
	int						numVertTiles;
	// state info cached during detailed animation
	float					xincr;
	float					yincr;
	float					tincr;
	float					lastFps;
	BOOL					lastRev;
	BOOL					hasPoints;
	int						curSubPointIdx;
	int						numSubPoints;
	int						noDataCond;
	int						hasDataCond;
	float					intervalMarkerIncrement;
	float					scrollWheelSensitivity;
	float					totalPixelsForPath;
	// these are just used by the path-drawing routines
	double					utmEastingOfLeftTile;
	double					utmNorthingOfBottomTile;
	
}
@property (nonatomic) float scrollWheelSensitivity;
@property (nonatomic) BOOL enableMapInteraction;

-(void)setCurrentTrack:(Track*) tr;
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
-(void) setTransparentView:(id)v;
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
