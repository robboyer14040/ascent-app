#import "Defs.h"
#import "MapPathView.h"
#import "Track.h"
#import "TrackPoint.h"
#import "LatLong-UTMconversion.h"
#import "Lap.h"
#import "Lap.h"
#import "Utils.h"
#import "NDRunLoopMessenger.h"
#import "math.h"
#import <unistd.h>
#import "TransparentMapWindow.h"
#import "TransparentMapView.h"
#import "SplitTableItem.h"
#import <stdatomic.h>


#define DATE_METHOD           activeTime
#define DURATION_METHOD       movingDuration

//----------------------------------------------------------------------------------------------------

static float sCumulativeDeltaY = 0.0;			// for scrolling/zoom



@implementation TileFetcher
- (void)startTileThread {
    if (self.tileThread) return;
    self.tileThread = [[NSThread alloc] initWithTarget:self
                                              selector:@selector(tileThreadEntry)
                                                object:nil];
    [self.tileThread start];
}

- (void)tileThreadEntry {
    @autoreleasepool {
        self.tileFetchThreadRunning = YES;

        // Must be created on the same thread that runs the run loop
        ///self.runLoopMessenger = [[NDRunLoopMessenger alloc] init];

        // Add a port (or a timer) so the run loop can actually run/sleep
        self.keepAlivePort = [NSMachPort port];
        [[NSRunLoop currentRunLoop] addPort:self.keepAlivePort
                                    forMode:NSDefaultRunLoopMode];

        NSRunLoop *rl = [NSRunLoop currentRunLoop];

        while (self.tileFetchThreadRunning) {
            @autoreleasepool {
                // Run briefly; don’t use distantFuture or it won’t wake to your flag change
                [rl runMode:NSDefaultRunLoopMode
                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
        }

        // Clean up thread-owned objects explicitly before leaving the pool
        ///self.runLoopMessenger = nil;
        ///if (self.keepAlivePort) {
        ///    [rl removePort:self.keepAlivePort forMode:NSDefaultRunLoopMode];
        ///    self.keepAlivePort = nil;
        ///}
    }
}

- (void)stopTileThread {
    if (!self.tileThread) return;

    // Schedule the stop on the worker’s run loop so it wakes immediately
    [self performSelector:@selector(_stopOnWorker)
                 onThread:self.tileThread
               withObject:nil
            waitUntilDone:NO];
}

- (void)_stopOnWorker {
    self.tileFetchThreadRunning = NO;
    // Also force the run loop to return from sleep right now
    CFRunLoopStop(CFRunLoopGetCurrent());
}
@end


@interface TileInfo : NSObject
{
   @public
	NSImage*    image;
	int         xTile;
	int         yTile;
	int         tileZone;
	int         scale;
	BOOL        isDisplayed;
	BOOL        hasBeenFetched;
	BOOL		refresh;		// force retrieval over net
};

@end

@implementation TileInfo

-(id)initWithData:(NSImage*)theImage xTile:(int)xt yTile:(int)yt tileZone:(int)tz scale:(int)s
{
	if (theImage != image)
	{
	  image = theImage;
	}
	xTile = xt;
	yTile = yt;
	tileZone = tz;
	scale = s;
	isDisplayed = NO;
	hasBeenFetched = NO;
	refresh = NO;
	return self;
}

-(id)init
{
	self = [super init];
	[self initWithData:nil xTile:0 yTile:0 tileZone:0 scale:10];
	return self;
}

- (void) dealloc
{
    [super dealloc];
}


-(void)setImage:(NSImage*)im
{
	if (im != image)
	{
		image = im;
	}
}


@end

//----------------------------------------------------------------------------------------------------

@interface PathPoint : NSObject
{
   @public
   TrackPoint* tpt;
   double   northing;
   double   easting;
   int      zone;
   NSPoint  point;
   BOOL     valid;
}
- (id) initWithData:(TrackPoint*)pt  northing:(double)n easting:(double)e zone:(int)z;
- (double) northing;
- (double) easting;
- (int) UTMzone;
- (int) heartrate;
- (NSPoint) point;
- (BOOL) valid;
- (TrackPoint*) trackPoint;
@end


@implementation PathPoint

- (id) initWithData:(TrackPoint*)pt  northing:(double)n easting:(double)e zone:(int)z;
{
   self = [super init];
   tpt = pt;
   northing = n;
   easting = e;
   zone = z;
   valid = YES;
   return self;
}

- (id) init
{
   self = [self initWithData:nil northing:0 easting:0 zone:0];
   valid = NO;
   return self;
}

- (BOOL) valid
{
   return valid;
}

- (NSTimeInterval) wallClockDelta
{
   return [tpt wallClockDelta];
}

- (NSTimeInterval) activeTimeDelta
{
   return [tpt activeTimeDelta];
}

- (int) heartrate
{
   return [tpt heartrate];
}

- (double) northing
{
   return northing;
}

- (double) easting
{
   return easting;
}

- (int) UTMzone
{
   return zone;
}

- (NSPoint) point
{
   return point;
}


- (TrackPoint*) trackPoint
{
   return tpt;
}


- (void) dealloc
{
    [super dealloc];
}


@end



@interface AvgPoint : NSObject
{
   @public
   double x, y;
}
- (id) initWithData:(double)ix y:(double)iy;
@end

@implementation AvgPoint

- (id) initWithData:(double)ix y:(double)iy
{
   self = [super init];
   x = ix;
   y = iy;
   return self;
}

@end


//----------------------------------------------------------------------------------------------------

@interface MapPathView ()
-(NSPoint)calcGraphPointFromUTMCoordinates:(double)easting northing:(double)northing;
-(void)calcUTMForPoint:(TrackPoint*)pt nextPoint:(TrackPoint*)nextPt ratio:(float)ratio eastingP:(double*)easting northingP:(double*)northing zoneP:(int*)zone;
-(void)resetUTMCoords:(double)ux utmy:(double)uy;
-(void)recalcGeometry;
@end


@implementation MapPathView

@synthesize scrollWheelSensitivity;
@synthesize enableMapInteraction ;


static int nextAvailCond = 0;


BOOL terraServerMap(int dt)
{
   return (dt <= 4);    // @@FIXME@@
}


- (NSRect) drawBounds
{
   return NSInsetRect([self bounds], 5.0, 5.0);
}

- (void)commonInit
{
    fetcher = [[TileFetcher alloc] init];
    splitArray = nil;
    transparentView = nil;
    noDataCond = nextAvailCond++;
    hasDataCond = nextAvailCond++;
    currentMapImages = [[NSMutableArray alloc] init];
    plottedPoints =[[NSMutableArray alloc] init];
    averageXY =[[NSMutableArray alloc] init];
    tileFetchQueue =[[NSMutableArray alloc] init];
    tileCache =[[NSMutableDictionary alloc] initWithCapacity:256];
    mapOpacity = [Utils floatFromDefaults:RCBDefaultMDMapTransparency];
    mapOpacity = 1.0;       /// fixme opacity
    pathOpacity = [Utils floatFromDefaults:RCBDefaultMDPathTransparency];
    pathOpacity = 1.0;      /// fixme opacity
    lastTrack = currentTrack = nil;
    selectedLap = nil;

    int mapIndex = [Utils intFromDefaults:RCBDefaultMapType];
    lastDataType = dataType = [Utils mapIndexToType:mapIndex];
    lastAnimPoint = NSZeroPoint;
    lastScale = 0;
    trackPath = [[NSBezierPath alloc] init];
    lapPath = [[NSBezierPath alloc] init];
    NSString* path = [[NSBundle mainBundle] pathForResource:@"Dot" ofType:@"png"];
    path = [[NSBundle mainBundle] pathForResource:@"LapMarker" ofType:@"png"];
    lapMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"StartMarker" ofType:@"png"];
    startMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"FinishMarker" ofType:@"png"];
    finishMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
    if (terraServerMap(dataType))
        tileWidth = tileHeight = 200.0;
    else
        tileWidth = tileHeight = 256.0;
    scrollWheelSensitivity = [Utils floatFromDefaults:RCBDefaultScrollWheelSensitivty];
    cachedImageRep = nil;
    showLaps = [Utils boolFromDefaults:RCBDefaultMDShowLaps];
    showIntervalMarkers  = [Utils boolFromDefaults:RCBDefaultShowIntervalMarkers];
    intervalMarkerIncrement = [Utils intFromDefaults:RCBDefaultIntervalMarkerIncrement];
    isDetailedMap = NO;
    overrideDefaults = NO;
    dragging = NO;
    animatingInPlace = NO;
    animatingNormally = NO;
    hasPoints = NO;
    showPath = YES;
    showLaps = YES;
    enableMapInteraction = YES;
    colorizePaths = YES;
    firstAnim = YES;
    moveMapDuringAnimation = NO;
    scale = 10;
    refEllipsoid = 23;   //WGS-84. See list with file "LatLong- UTM conversion.cpp" for id numbers
    factor = 1.0;
    zoneMin = 0;
    zoneMax = 0;
    numHorizTiles = 0;
    numVertTiles = 0;
    metersPerPixel = 1.0;
    initialX = initialY = 0.0;
    lastBounds.origin.x = lastBounds.origin.y = lastBounds.size.width = lastBounds.size.height = 0.0;
    NSFont* font = [NSFont systemFontOfSize:24];
    textFontAttrs = [[NSMutableDictionary alloc] init];
    [textFontAttrs setObject:font forKey:NSFontAttributeName];
    [textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
    font = [NSFont boldSystemFontOfSize:7.0];
    mileageMarkerTextAttrs = [[NSMutableDictionary alloc] init];
    [mileageMarkerTextAttrs setObject:font forKey:NSFontAttributeName];
    // text always black in markers, with white background
    [mileageMarkerTextAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    dataInProgress = [[NSMutableData data] retain];
    cacheFilePath = [[Utils getMapTilesPath] retain];
    connection = nil;

    dropShadow = [[NSShadow alloc] init];
    [dropShadow setShadowColor:[NSColor blackColor]];
    [dropShadow setShadowBlurRadius:5];
    [dropShadow setShadowOffset:NSMakeSize(0,-3)];

    dataHudUpdateInvocation = nil;
    ///[NSThread detachNewThreadSelector:@selector(getNonCachedMaps:) toTarget:self withObject:nil];
    [fetcher startTileThread];
}

- (instancetype)initWithFrame:(NSRect)r {
    if ((self = [super initWithFrame:r])) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super initWithCoder:c])) [self commonInit];
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}


#if 0
- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) 
	{
        fetcher = [[TileFetcher alloc] init];
		splitArray = nil;
		transparentView = nil;
		noDataCond = nextAvailCond++;
		hasDataCond = nextAvailCond++;
		currentMapImages = [[NSMutableArray alloc] init];
		plottedPoints =[[NSMutableArray alloc] init];
		averageXY =[[NSMutableArray alloc] init];
		tileFetchQueue =[[NSMutableArray alloc] init];
		tileCache =[[NSMutableDictionary alloc] initWithCapacity:256];
		mapOpacity = [Utils floatFromDefaults:RCBDefaultMDMapTransparency];
        mapOpacity = 1.0;       /// fixme opacity
		pathOpacity = [Utils floatFromDefaults:RCBDefaultMDPathTransparency];
        pathOpacity = 1.0;      /// fixme opacity
		lastTrack = currentTrack = nil;
		selectedLap = nil;

		int mapIndex = [Utils intFromDefaults:RCBDefaultMapType];
		lastDataType = dataType = [Utils mapIndexToType:mapIndex];

		lastScale = 0;
		trackPath = [[NSBezierPath alloc] init];
		lapPath = [[NSBezierPath alloc] init];
		NSString* path = [[NSBundle mainBundle] pathForResource:@"Dot" ofType:@"png"];
		path = [[NSBundle mainBundle] pathForResource:@"LapMarker" ofType:@"png"];
		lapMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
		path = [[NSBundle mainBundle] pathForResource:@"StartMarker" ofType:@"png"];
		startMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
		path = [[NSBundle mainBundle] pathForResource:@"FinishMarker" ofType:@"png"];
		finishMarkerImage = [[NSImage alloc] initWithContentsOfFile:path];
		if (terraServerMap(dataType))
			tileWidth = tileHeight = 200.0;        
		else
			tileWidth = tileHeight = 256.0;    
		scrollWheelSensitivity = [Utils floatFromDefaults:RCBDefaultScrollWheelSensitivty];
		cachedImageRep = nil;
		showLaps = [Utils boolFromDefaults:RCBDefaultMDShowLaps];
		showIntervalMarkers  = [Utils boolFromDefaults:RCBDefaultShowIntervalMarkers];
		intervalMarkerIncrement = [Utils intFromDefaults:RCBDefaultIntervalMarkerIncrement];
		isDetailedMap = NO;
		overrideDefaults = NO;
		dragging = NO;
		animatingInPlace = NO;
		animatingNormally = NO;
		hasPoints = NO;
		showPath = YES;
		showLaps = YES;
		enableMapInteraction = YES;
		colorizePaths = YES;
		firstAnim = YES;
		moveMapDuringAnimation = NO;
		scale = 10;
		refEllipsoid = 23;   //WGS-84. See list with file "LatLong- UTM conversion.cpp" for id numbers
		factor = 1.0;
		zoneMin = 0;
		zoneMax = 0;
		numHorizTiles = 0;
		numVertTiles = 0;
		metersPerPixel = 1.0;
		initialX = initialY = 0.0;
		lastBounds.origin.x = lastBounds.origin.y = lastBounds.size.width = lastBounds.size.height = 0.0;
		NSFont* font = [NSFont systemFontOfSize:24];
		textFontAttrs = [[NSMutableDictionary alloc] init];
		[textFontAttrs setObject:font forKey:NSFontAttributeName];
		[textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
		font = [NSFont boldSystemFontOfSize:7.0];
		mileageMarkerTextAttrs = [[NSMutableDictionary alloc] init];
		[mileageMarkerTextAttrs setObject:font forKey:NSFontAttributeName];
        // text always black in markers, with white background
		[mileageMarkerTextAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
		dataInProgress = [[NSMutableData data] retain];
		cacheFilePath = [[Utils getMapTilesPath] retain];
		connection = nil;

		dropShadow = [[NSShadow alloc] init];
		[dropShadow setShadowColor:[NSColor blackColor]];
		[dropShadow setShadowBlurRadius:5];
		[dropShadow setShadowOffset:NSMakeSize(0,-3)];

		dataHudUpdateInvocation = nil;
		///[NSThread detachNewThreadSelector:@selector(getNonCachedMaps:) toTarget:self withObject:nil];
        [fetcher startTileThread];
	}
	return self;
}
#endif

- (void) dealloc
{
#if DEBUG_LEAKS
    NSLog(@"destroying map path view ...");
#endif
    [cacheFilePath release];
    [dataInProgress release];
    [fetcher release];
    runLoopMessenger = nil;
    [super dealloc];
}


-(void) setTransparentView:(id)v
{
   if (v != transparentView)
   {
      transparentView = v;
   }
}


- (void) killThyself:(id)junk
{
   // this runs in the fetch thread, and makes sure everything shuts down synchronously before this
   // view is destroyed.  Otherwise, a connection method could arrive *after* the thread and this
   // view is destroyed, and we will crash.
   if (connection != nil)
   {
      [connection cancel];
   }
   tileFetchThreadRunning = NO;
    [fetcher stopTileThread];
}


- (void) prepareToDie
{
#if 0
	[runLoopMessenger target:self
			 performSelector:@selector(killThyself:) 
				  withObject:nil];
#else
    [fetcher stopTileThread];
#endif
}



-(void) killAnimThread
{
   animThreadRunning = NO;
}


- (NSString*) getTileKey:(int)tsx
                   yTile:(int)tsy
                    zone:(int)zne
                   scale:(int)is
                dataType:(int)dt
{
   NSString* key = [NSString stringWithFormat:@"%d_%d_%d_%d_%d",dt, is, tsx, tsy, zne];
   return key;
}


static NSString* tileToQuadKey(int tx, int ty, int zl)
{
   NSString* quad = @"";
   for (int i = zl; i > 0; i--)
   {
      int mask = 1 << (i - 1);
      int cell = 0;
      if ((tx & mask) != 0)
      {
         cell++;
      }
      if ((ty & mask) != 0)
      {
         cell += 2;
      }
      quad = [quad stringByAppendingFormat:@"%d",cell];
   }
   return quad;
}



-(void) queueHTTPFetch
{
    NSUInteger num = [tileFetchQueue count];
  // if ((num > 0) && tileFetchThreadRunning)
    if ((num > 0) && [fetcher tileFetchThreadRunning])
   {
      TileInfo* ti = [tileFetchQueue objectAtIndex:0]; 
      tileBeingFetched = ti;
      [tileFetchQueue removeObjectAtIndex:0];
      NSString* url;
      if (terraServerMap(dataType))
      {  
         //NSLog(@"terraserver fetch: xTile: %d  yTile: %d  scale:%d dt:%d zone: %d\n", ti->xTile, ti->yTile, ti->scale, dataType, ti->tileZone);
         url = @"http://terraserver-usa.com/tile.ashx?T=%d&S=%d&X=%d&Y=%d&Z=%d";
         url = [NSString stringWithFormat:url, dataType, ti->scale, ti->xTile, ti->yTile , ti->tileZone];
      }
      else
      {
         const char* type;
         const char* ext;
         if (dataType == 10)
         {
            type = "h";
            ext = ".jpeg";
         }
         else if (dataType == 11)
         {
            type = "r";
            ext = ".png";
         }
         else
         {
            type = "a";
            ext = ".jpeg";
         }
         NSString* quadKey = tileToQuadKey(ti->xTile, ti->yTile, ti->scale);
         NSRange range = { [quadKey length] - 1, 1 };
         NSString* s = [quadKey substringWithRange:range];
         //NSLog(@"ve fetch: xTile: %d  yTile: %d  scale:%d dt:%d\n", ti->xTile, ti->yTile, ti->scale, dataType);
         url = @"http://%s%@.ortho.tiles.virtualearth.net/tiles/%s%@%s?g=1";
         url = [NSString stringWithFormat:url, type, s, type, quadKey, ext];
		
      }
      NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:url]
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:20.0];
      // create the connection with the request and start loading the data
      // note that the connection id is stored so it can be cancelled later if the view is being destroyed
      connection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
      if (connection != nil) 
      {
         [dataInProgress setLength:0];
      } 
      else 
      {
         // inform the user that the download could not be made
      }
   }
   else
   {
      [self performSelectorOnMainThread:@selector(endMapRetrieval:) withObject:self waitUntilDone:NO];
      tileBeingFetched = nil;
   }
}

-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
   return nil;
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
   // this method is called when the server has determined that it
   // has enough information to create the NSURLResponse
   
   // it can be called multiple times, for example in the case of a 
   // redirect, so each time we reset the data.
   [dataInProgress setLength:0];
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)data
{
   // append the new data to the receivedData
   [dataInProgress appendData:data];
}


- (void)connection:(NSURLConnection *)c 
  didFailWithError:(NSError *)error
{
   // release the connection, and the data object
   connection = nil;
   // inform the user
   NSLog(@"Connection failed! Error - %@ %@",
         [error localizedDescription],
         [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
   [self queueHTTPFetch];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)c
{
  // do something with the data
   if (dataInProgress != nil)
   {
      NSSize theSize;
      theSize.width = tileWidth;
      theSize.height = tileHeight;
      NSImage* image = [[NSImage alloc] initWithData:dataInProgress];
      [image setSize:theSize];
      TileInfo* ti = tileBeingFetched;
      ti->image = image;
      if ([dataInProgress length] > 0)
      {
         NSString* fname = [NSString stringWithFormat:@"%d_%d_%d_%d_%d.jpg",dataType, ti->scale, ti->xTile, ti->yTile, ti->tileZone];
         NSString* fullPath = [cacheFilePath stringByAppendingPathComponent:fname];
         [dataInProgress writeToFile:fullPath atomically:NO];
      }
      /*if (!animatingInPlace)*/ [self performSelectorOnMainThread:@selector(kickStartDrawing:) withObject:self waitUntilDone:NO];
   }
   connection = nil;
   [self queueHTTPFetch];
}




- (NSData*)getFileDataOrQueueRetrieval:(TileInfo*)ti
{
   NSFileManager* fm = [NSFileManager defaultManager];
   NSString* fname = [NSString stringWithFormat:@"%d_%d_%d_%d_%d.jpg",dataType, ti->scale, ti->xTile, ti->yTile, ti->tileZone];
   NSString* fullPath = [cacheFilePath stringByAppendingPathComponent:fname];
   NSData *theData = nil;
   if (!ti->refresh && [fm fileExistsAtPath:fullPath])
   {
      theData = [[NSData alloc] initWithContentsOfFile:fullPath];
   }
   else if ([fetcher tileFetchThreadRunning])
   {
		if ([tileFetchQueue count] > 0) 
		{
			[tileFetchQueue insertObject:ti atIndex:0];
		}
		else
		{
			[tileFetchQueue addObject:ti];
		}
		if (tileBeingFetched == nil)
		{
			[self performSelectorOnMainThread:@selector(startMapRetrieval:) withObject:self waitUntilDone:NO];
			[self queueHTTPFetch];
		}
   }
   return theData;
}



const double earthRadius = 6378137;
const double earthCircum = earthRadius * 2.0 * M_PI;
const double earthHalfCirc = earthCircum / 2;


static double degToRad(double d)
{
      return d * M_PI / 180.0;
}



double latitudeToYMeters(double lat)
{
   double sinLat = sin(degToRad(lat));
   double metersY = earthRadius / 2 * log((1 + sinLat) / (1 - sinLat));
   return earthHalfCirc - metersY;
}

double longitudeToXMeters(double lon)
{
   double metersX = earthRadius * degToRad(lon);
   return earthHalfCirc + metersX;
}



int metersToYTileAtZoom(double metersY, int zoom)
{
   double arc = earthCircum / ((1 << zoom));     // metersPerTile
   int y = (int)((metersY) / arc);
   return y;
}

int metersToXTileAtZoom(double metersX, int zoom)
{
   double arc = earthCircum / ((1 << zoom));
   int x = (int)((metersX) / arc);			
   return x;
}


int latitudeToYTileAtZoom(double lat, int zoom)
{
      double arc = earthCircum / ((1 << zoom));
      double metersY = latitudeToYMeters(lat);
      int y = (int)((metersY) / arc);
      return y;
}

int longitudeToXTileAtZoom(double lon, int zoom)
{
      double arc = earthCircum / ((1 << zoom));
      double metersX = longitudeToXMeters(lon);
      int x = (int)((metersX) / arc);			
      return x;
}




static double getMetersPerPixel(int zoom)
{
	double arc = earthCircum / ((double)(1 << zoom) * (double)256.0);
      return arc;
}

static double getMetersPerTile(int zoom)
{
   double arc = earthCircum / (1 << zoom);
   return arc;
}

- (Lap *)selectedLap 
{
   return selectedLap ;
}

- (void)setSelectedLap:(Lap *)value 
{
   if (selectedLap != value) 
   {
      selectedLap = value;
      overrideDefaults = NO;
      lastTrack = nil;     // force redraw
      ////leftTile = -9999999;
      [self display];
   }
}


- (BOOL)colorizePaths 
{
   return colorizePaths;
}

- (void)setColorizePaths:(BOOL)value 
{
   if (colorizePaths != value) {
      colorizePaths = value;
   }
}


-(void) calcUTMForPoint:(TrackPoint*)pt nextPoint:(TrackPoint*)nextPt ratio:(float)ratio eastingP:(double*)easting northingP:(double*)northing zoneP:(int*)zone
{
	if ([pt validLatLon])
	{
		float lat = [pt latitude];
		float lon = [pt longitude];
		if (nextPt && [nextPt validLatLon])
		{
			lat = lat + (ratio * ([nextPt latitude] - lat));
			lon = lon + (ratio * ([nextPt longitude] - lon));
		}
		if (terraServerMap(dataType))
		{
			char utmZone[4];
			LLtoUTM(refEllipsoid, lat, lon, northing, easting, utmZone, zone);
		}
		else
		{
			*northing = latitudeToYMeters(lat);
			*easting  = longitudeToXMeters(lon);
			*zone = 0;   // not used;
		}
	}
}


-(void) setCurrentTrack:(Track*) tr
{
	if (currentTrack != tr)
	{
		currentTrack = tr;
	}
	hasPoints = [[currentTrack goodPoints] count] > 0;
	initialX = initialY = 0.0;
	lastTrack = nil;
	zoneMin = 0;
	zoneMax = 0;
	utmX = utmY = 0.0;
	// calculate min/max utm coords based on min/max latitudes found in track
	double minLatitude = [currentTrack minLatitude];
	double maxLatitude = [currentTrack maxLatitude];
	double minLongitude = [currentTrack minLongitude];
	double maxLongitude = [currentTrack maxLongitude];

	if (terraServerMap(dataType))
	{
		char utmZoneMin[4];
		char utmZoneMax[4];
		LLtoUTM(refEllipsoid, minLatitude, minLongitude, &utmNorthingMin, &utmEastingMin, utmZoneMin, &zoneMin);
		LLtoUTM(refEllipsoid, maxLatitude, maxLongitude, &utmNorthingMax, &utmEastingMax, utmZoneMax, &zoneMax);
	}
	else
	{
		utmEastingMin = longitudeToXMeters(minLongitude);
		utmNorthingMin = latitudeToYMeters(maxLatitude);
		utmEastingMax = longitudeToXMeters(maxLongitude);
		utmNorthingMax = latitudeToYMeters(minLatitude);
		if ((utmEastingMax - utmEastingMin) < 100.0)
		{
		   utmEastingMax += 50.0;
		   utmEastingMin -= 50.0;
		}
		if ((utmNorthingMax - utmNorthingMin) < 100.0)
		{
		   utmNorthingMax += 50.0;
		   utmNorthingMin -= 50.0;
		}
	}
	// set up display path
	[plottedPoints removeAllObjects];
	NSMutableArray* points = [currentTrack goodPoints];
    NSUInteger numPts = [points count];
	if (numPts > 2)
	{
		double northing, easting;
		int zone;
		PathPoint* mpt;
		for (int i=0; i<numPts; i++)
		{
			TrackPoint* pt = [points objectAtIndex:i];
			[self calcUTMForPoint:pt
						nextPoint:nil
							ratio:1.0
						 eastingP:&easting
						northingP:&northing
							zoneP:&zone];
			// if invalid point, use positioning from LAST good point
			mpt = [[PathPoint alloc] initWithData:pt
										  northing:northing 
										   easting:easting 
											  zone:zone];
			[plottedPoints addObject:mpt];
		}
	}
	overrideDefaults = NO;
	float maxarr[kNumPlotTypes];
	float minarr[kNumPlotTypes];
	for (int i=0; i<kNumPlotTypes; i++)
    {
        maxarr[i] = 0.0;
        minarr[i] = 0.0;
    }
	if (numPts > 1)
	{
		maxarr[kSpeed] = [[points valueForKeyPath:@"@max.speed"] floatValue];
		minarr[kSpeed] = [[points valueForKeyPath:@"@min.speed"] floatValue];
		maxarr[kHeartrate] = [[points valueForKeyPath:@"@max.heartrate"] floatValue];
		minarr[kHeartrate] = [[points valueForKeyPath:@"@min.heartrate"] floatValue];
		maxarr[kAltitude] = [[points valueForKeyPath:@"@max.altitude"] floatValue];
		minarr[kAltitude] = [[points valueForKeyPath:@"@min.altitude"] floatValue];
		maxarr[kCadence] = [[points valueForKeyPath:@"@max.cadence"] floatValue];
		minarr[kCadence] = [[points valueForKeyPath:@"@min.cadence"] floatValue];
		float maxgr = [[points valueForKeyPath:@"@max.gradient"] floatValue];
		float mingr = [[points valueForKeyPath:@"@min.gradient"] floatValue];
		if ((mingr < 0) && (-mingr > maxgr)) 
		{
			maxgr = -mingr;
			mingr = -maxgr;
		}
		maxarr[kGradient] = maxgr;
		minarr[kGradient] = mingr;
		maxarr[kDistance] = [currentTrack distance];
		minarr[kDistance] = 0.0;
	}
	[transparentView setHidden:(currentTrack == nil)||(numPts <= 1)];
	if ([transparentView respondsToSelector: @selector(setMaxMinValueArrays:min:)])
	   [transparentView setMaxMinValueArrays:(float*)maxarr min:(float*)minarr];
	[self recalcGeometry];
	[self setNeedsDisplay:YES];
}


- (void)setSplitArray:(NSArray *)value
{
	if (splitArray != value)
	{
		splitArray = value;
	}
	[self setNeedsDisplay:YES];
}


-(void)interpPointsAndCenter:(NSTimeInterval)trackTime curPt:(PathPoint*)curPt nextPt:(PathPoint*)nextPt adjx:(float*)adjxP adjy:(float*)adjyP
{
	float curPointTime = [curPt activeTimeDelta];
	NSPoint curPlotPt = [curPt point];
	NSPoint nextPlotPt = [nextPt point];
	float nextPointTime = [nextPt activeTimeDelta];
	float ratio = 0.0;
	if (nextPointTime != curPointTime) ratio = (trackTime-curPointTime)/(nextPointTime - curPointTime);
	*adjxP = (((nextPlotPt.x - curPlotPt.x)*ratio) * metersPerPixel) -  utmW/2.0;
	*adjyP = terraServerMap(dataType) ? 
		 ((((nextPlotPt.y - curPlotPt.y)*ratio) * metersPerPixel) - utmH/2.0) : 
		-((((nextPlotPt.y - curPlotPt.y)*ratio) * metersPerPixel) - utmH/2.0);
}


- (void)updateDetailedPosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim;
{
    NSUInteger totalPoints = [plottedPoints count];
	if ((totalPoints > 0) && (trackTime >= 0.0 || trackTime <= [currentTrack DURATION_METHOD]))
	{
		//NSDate* trackStartTime = [currentTrack creationTime];
		int curPointIdx = [currentTrack animIndex];
		PathPoint* curPt = nil;
		if (curPointIdx < totalPoints) curPt = [plottedPoints objectAtIndex:curPointIdx];
		if (!curPt || ![curPt valid])
		{
			curPt = prevPathPoint;
		}
      
		if ([curPt valid])
		{
			prevPathPoint = curPt;
			float adjx = 0.0;
			float adjy = 0.0;
			if (rev)
			{
				if (curPointIdx <= 0)
				{
					adjx = -utmW/2.0;
					adjy = terraServerMap(dataType) ? - utmH/2.0 : utmH/2.0;
				}
				else
				{
					PathPoint* nextPt = [plottedPoints objectAtIndex:curPointIdx-1];
					[self interpPointsAndCenter:trackTime curPt:curPt nextPt:nextPt adjx:&adjx adjy:&adjy];
				}
			}
			else
			{
				if (curPointIdx >= (totalPoints - 1))
				{
					adjx = -utmW/2.0;
					adjy = terraServerMap(dataType) ? - utmH/2.0 : utmH/2.0;
				}
				else
				{
					PathPoint* nextPt = [plottedPoints objectAtIndex:curPointIdx+1];
					[self interpPointsAndCenter:trackTime curPt:curPt nextPt:nextPt adjx:&adjx adjy:&adjy];
				}
			}
         
			double ux = ([curPt easting] ) + adjx;
			double uy = ([curPt northing]) + adjy;
			overrideDefaults = YES;
			lastTrack = nil;
			[self resetUTMCoords:ux
							utmy:uy];
			animatingInPlace =  anim;
			//[[self window] disableScreenUpdatesUntilFlush];
			[self setNeedsDisplay:YES];
			//[[self window] flushWindow];
		}
	}
	else
	{
		animatingInPlace =  anim;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AnimationEnded" object:self];
	}
}

- (void)beginAnimation
{
   animatingNormally = YES;
   //[self display];      // make anim bitmap disappear
}


- (void)cancelAnimation
{
   animatingNormally = NO;
   animatingInPlace = NO;
   //[self setNeedsDisplay:YES];
}



#define ANIM_RECT_SIZE  12.0
- (void) drawAnimationBitmap:(BOOL)cacheBackground position:(int)curPointIdx animID:(int)aid
{
	NSRect db = [self drawBounds];
   if ( ([plottedPoints count] > curPointIdx) && (db.size.width > 0.0) )
   {
      NSPoint pt;
      if (animatingInPlace)
      {
         NSRect bounds = [self drawBounds];
         pt.x = bounds.origin.x + bounds.size.width/2.0;
         pt.y = bounds.origin.y + bounds.size.height/2.0;
      }
      else
      {
         PathPoint* mpt;
         mpt = [plottedPoints objectAtIndex:curPointIdx];
         if (![mpt valid])
         {
            mpt = prevPathPoint;
         }
         if ((mpt != nil) && [mpt valid])
         {
            pt = [mpt point];
            prevPathPoint = mpt;
         }
         else pt = NSZeroPoint;
      }
      //pt.x -= 10.0;
      //pt.y -= 10.0;
	   TrackPoint* tpt = (TrackPoint*)[[currentTrack goodPoints] objectAtIndex:curPointIdx];
	   [transparentView update:pt trackPoint:tpt animID:aid];
	   if (dataHudUpdateInvocation)
	   {
		   //float alt = [self getAltitude:curPointIdx];
           CGFloat alt = (CGFloat)[currentTrack firstValidAltitudeUsingGoodPoints:curPointIdx];
		   if (alt == BAD_ALTITUDE) alt = 0.0;
		   [dataHudUpdateInvocation setArgument:&tpt 
										atIndex:2];
		   [dataHudUpdateInvocation setArgument:&pt.x 
										atIndex:3];
		   [dataHudUpdateInvocation setArgument:&pt.y 
										atIndex:4];
		   [dataHudUpdateInvocation setArgument:&alt 
										atIndex:5];
		   [dataHudUpdateInvocation invoke];
	   }
   }
}


- (void)updateTrackAnimation:(int)currentTrackPos animID:(int)aid
{
   animatingNormally = YES;
   if (hasPoints) [self drawAnimationBitmap:YES
								   position:currentTrackPos
									 animID:aid];
}


- (void)updateAnimUsingPoint:(TrackPoint*)pt nextPoint:(TrackPoint*)nextPt ratio:(float)ratio animID:(int)aid
{
	animatingNormally = YES;
	double easting, northing;
	int zone;
	[self calcUTMForPoint:pt 
				nextPoint:nextPt
					ratio:ratio
				 eastingP:&easting
				northingP:&northing
					zoneP:&zone];
	NSPoint p = [self calcGraphPointFromUTMCoordinates:easting
											  northing:northing];
	[transparentView update:p 
				 trackPoint:pt 
					 animID:aid];
}



- (NSPoint) findNearestPointToWallClockDelta:(NSTimeInterval)delta track:(Track*)trk
{
    NSUInteger num = [plottedPoints count];
	int i = 0;
	PathPoint* pt = nil;
	for (i=0; i<num; i++)
	{
		pt = [plottedPoints objectAtIndex:i];
		//NSComparisonResult res = [[pt time] compare:time];
		//if ((res == NSOrderedDescending) || (res == NSOrderedSame))
		//{
		//   break;
		//}
		if ([pt wallClockDelta] >= delta) break;
	}
	NSPoint p = NSZeroPoint;
	if (pt != nil)
	{
		p = [pt point];
	}
	return p;
}


BOOL intersectsExistingRect(NSRect* rects, int numRects, NSRect r)
{
   for (int i = 0; i<numRects; i++)
   {
      if (NSIntersectsRect(r, rects[i])) return YES;
   }
   return NO;
}


-(NSPoint)putImage:(NSImage*)img atWallTime:(float)wt
{
	NSPoint p = [self findNearestPointToWallClockDelta:wt track:currentTrack];
	NSRect r, imageRect;
	imageRect.origin = NSZeroPoint;
	imageRect.size = [img size];
	r.size = imageRect.size;
	r.origin.x = (int)(p.x - (r.size.width)/2.0) + 2;
	r.origin.y = (int)p.y - 4;
	[img drawAtPoint:r.origin
			fromRect:NSZeroRect
		   operation:NSCompositingOperationSourceOver
			fraction:1.0];
	return p;
}



- (void)drawLaps
{
	NSFont* font = [NSFont boldSystemFontOfSize:8];
	NSMutableDictionary *fontAttrs = [[NSMutableDictionary alloc] init] ;
	[fontAttrs setObject:font forKey:NSFontAttributeName];
	NSMutableArray* laps = [currentTrack laps];
    int numLaps = (int)[laps count];
	int i;
	for (i=numLaps-1; i>=0; i--)
	{
		Lap* lap = [laps objectAtIndex:i];
		float lapEndTime = [lap startingWallClockTimeDelta] + [currentTrack durationOfLap:lap];
		NSPoint p = [self putImage:lapMarkerImage 
						atWallTime:lapEndTime];
		NSRect r, imageRect;
		imageRect.origin = NSZeroPoint;
		imageRect.size = [lapMarkerImage size];
		r.size = imageRect.size;
		r.origin.x = (int)(p.x - (r.size.width)/2.0) + 2;
		r.origin.y = (int)p.y - 4;
		NSString* s = [NSString stringWithFormat:@"%d", i+1];
		NSSize size = [s sizeWithAttributes:fontAttrs];
		float lxoff = ((r.size.width - size.width)/2.0) - 1;
		float lyoff = 11.0;
		[fontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
		[s drawAtPoint:NSMakePoint((int)(r.origin.x + lxoff), (int)(r.origin.y + lyoff + 1.0)) withAttributes:fontAttrs];
	}
	
	[self putImage:startMarkerImage
		atWallTime:0];
	
	float endTime = [currentTrack durationAsFloat];
	[self putImage:finishMarkerImage
		atWallTime:endTime];
	
}




- (void)drawMapImages:(float)ix initialY:(float)iy numHoriz:(int)nht numVert:(int)nvt
{
   if ([currentMapImages count] > 0)
   {
       [[NSColor colorNamed:@"BackgroundPrimary"] set];
      NSRect arect;
      arect.origin.x = 0.0;
      arect.origin.y = 0.0;
      arect.size.width = tileWidth;
      arect.size.height = tileHeight;
      NSPoint pt;
      pt.x = (int)ix;
      pt.y = (int)iy;
      int i = 0;
      [NSBezierPath setDefaultLineWidth:1];
    NSUInteger numTiles = [currentMapImages count];
      for (int vert = 0; vert < nvt; vert++)
      {
         for (int horiz=0; horiz < nht; horiz++)
         {
            if (i < numTiles)
            {
               TileInfo* ti = [currentMapImages objectAtIndex:i];
               BOOL hasBeenFetched = ti->hasBeenFetched;
               NSImage* image = ti->image;
               if ((hasBeenFetched == YES) && (image != nil))
               {
                  if (ti->isDisplayed == NO)
                  {
					  ///printf("[%x]     draw @x:%d\n", self, ti->xTile);
                      [image drawAtPoint:pt 
                                fromRect:arect
                               operation:NSCompositingOperationCopy
                                fraction:mapOpacity];
                     ti->isDisplayed = YES;
                  }
               }
               else 
               {
                  NSRect r;
                  r.origin = pt;
                  r.size.width = tileWidth;
                  r.size.height = tileHeight;
                  [NSBezierPath fillRect:r];
               }
            }
            pt.x += tileWidth;
            i++;
         }
         pt.x = (int)ix;
         pt.y += tileHeight;
      }
   }
   // display a frame
   //[[NSColor blackColor] set];
   //[NSBezierPath strokeRect:[self drawBounds]];
}   



-(void) drawSubPath:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime color:(NSString*)clrString opac:(float)opac cpz:(int)cpz
{
	[NSBezierPath setDefaultLineWidth:4.0];
	NSColor* clr = [Utils colorFromDefaults:clrString];
	[[clr colorWithAlphaComponent:opac] set];
    NSUInteger numPts = [plottedPoints count];
	NSPoint prevPt;
	BOOL haveFirst = NO;
	for (int i=0; i<numPts; i++)
	{
		PathPoint* pt = [plottedPoints objectAtIndex:i];
		if ([pt valid])
		{
			///if (IS_BETWEEN(startTime, [pt activeTimeDelta], endTime))
            if (IS_BETWEEN(startTime, [pt wallClockDelta], endTime))
			{
				float x = initialX + ([pt easting] - utmEastingOfLeftTile)/metersPerPixel;
				float y;
				if (terraServerMap(dataType))
					y = initialY + ([pt northing] - utmNorthingOfBottomTile)/metersPerPixel;
				else
					y = initialY - ([pt northing] - utmNorthingOfBottomTile)/metersPerPixel;
				
				NSPoint p;
				p.x = x; p.y = y;
				pt->point = p;
				
				if (haveFirst)
				{
					[Utils setZoneColor:cpz 
							 trackPoint:[pt trackPoint]];
					[NSBezierPath strokeLineFromPoint:prevPt 
											  toPoint:p];
				}
				haveFirst = YES;
				prevPt = p;
			}
		}
	}
}


#define SCALE_LENGTH_IN_PIXELS		60.0
#define SCALE_X						24.0
#define SCALE_Y						15.0
#define TICK_HEIGHT					4.0
#define NUM_DIVS					3


struct tStringInfo
{
	NSString*	s;
	NSRect		r;
};


-(void)drawMapScale
{
	static const float sNiceIntervals[] = 
	{
		0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 20.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0, 0.0
	};
	if (([currentTrack distance] == 0.0) || (totalPixelsForPath == 0)) return;
	
	// find the right interval that fits within a desired length
	float pixelsPerMile = totalPixelsForPath/[Utils convertDistanceValue:[currentTrack distance]];
	int niceIndex = 0;
	float dist = sNiceIntervals[niceIndex];			
	float pixelsForDist = pixelsPerMile * dist;		// pixels for dist
	int numIntervals = sizeof(sNiceIntervals)/sizeof(float);
	while (pixelsForDist < (SCALE_LENGTH_IN_PIXELS/2.0) && (niceIndex < numIntervals))
	{
		dist = sNiceIntervals[++niceIndex];
		pixelsForDist = dist * pixelsPerMile;
	}
	
	
	// calculate the strings to be drawn above the tick marks, but don't
	// display them yet
	NSFont* font = [NSFont boldSystemFontOfSize:9.0];
	NSMutableDictionary* textAttrs = [[NSMutableDictionary alloc] init];
	[textAttrs setObject:font 
				  forKey:NSFontAttributeName];
	[textAttrs setObject:[NSColor whiteColor] 
				  forKey:NSForegroundColorAttributeName];
	NSRect r;
	int i=0;
	float v = 0.0;
	r.origin.x = SCALE_X;
	r.origin.y = SCALE_Y + (2.0*TICK_HEIGHT) - 2.0;
	const char* units = [Utils usingStatute] ? "mi" : "km";
	float x = r.origin.x;
	[[NSColor whiteColor] set];
	
	tStringInfo info[NUM_DIVS];
	while (i<NUM_DIVS)
	{
		NSString* s;
		if (dist < 0.1)
			s = [NSString stringWithFormat:@"%0.2f%s", v, units];
		else if (dist < 1.0)
			s = [NSString stringWithFormat:@"%0.1f%s", v, units];
		else
			s = [NSString stringWithFormat:@"%0.0f%s", v, units];
		info[i].s = s;
		NSSize sz = [s sizeWithAttributes:textAttrs];
		r.size.height = sz.height;
		r.size.width = sz.width;
		r.origin.x -= (sz.width/2.0);
		info[i].r = r;
		v += dist;
		x += pixelsForDist;
		r.origin.x = x;
		++i;
	}
	
	// draw a semi-transparent gray area so that the strings and line will stand out
	r.origin.x = info[0].r.origin.x - 3.0;
	r.origin.y = SCALE_Y - 5.0;
	r.size.width = (info[NUM_DIVS-1].r.origin.x + info[NUM_DIVS-1].r.size.width + 2.0) - r.origin.x ;
	r.size.height = TICK_HEIGHT + 10.0 + 9.0;
	NSBezierPath* bez = [NSBezierPath bezierPathWithRoundedRect:r
										  xRadius:5.0
										  yRadius:5.0];
	[[NSColor colorWithCalibratedRed:20.0/255.0
							   green:20.0/255.0
								blue:20.0/255.0
							   alpha:0.3] set];
	[bez fill];
	
	// now draw the lines and the strings
	NSPoint pt;
	pt.x = SCALE_X;
	pt.y = SCALE_Y;
	bez = [NSBezierPath bezierPath];
	[bez setLineWidth:2.0];
	[[NSColor whiteColor] set];
	[bez moveToPoint:pt];
	pt.x += (pixelsForDist*2.0);
	[bez lineToPoint:pt];
	
	pt.x = SCALE_X;
	pt.y = SCALE_Y;
	[bez moveToPoint:pt];
	pt.y += TICK_HEIGHT;
	[bez lineToPoint:pt];
	
	pt.x = SCALE_X + pixelsForDist;
	pt.y = SCALE_Y;
	[bez moveToPoint:pt];
	pt.y += TICK_HEIGHT;
	[bez lineToPoint:pt];
	
	pt.x = SCALE_X + pixelsForDist*2.0;
	pt.y = SCALE_Y;
	[bez moveToPoint:pt];
	pt.y += TICK_HEIGHT;
	[bez lineToPoint:pt];
	
	[bez stroke];
	
	for (int i=0; i<NUM_DIVS; i++)
	{
		[info[i].s drawInRect:info[i].r
			   withAttributes:textAttrs];
	}

}


#define MM_VERT_MARGIN		1.0
#define MM_HORIZ_MARGIN		2.0

-(void)drawIntervalMarkerForPathPoint:(PathPoint*)ppt
{
	float boxWidth;
	float distance = [Utils convertDistanceValue:[lastTrack distance]];
	if (distance < 10.0)
		boxWidth = 9.0;
	else if (distance < 100.0)
		boxWidth = 13.0;
	else if (distance < 1000.0)
		boxWidth = 17.0;
	else 
		boxWidth = 21.0;
	NSPoint p = [ppt point];
	NSString* s = [NSString stringWithFormat:@"%0.0f", [Utils convertDistanceValue:[[ppt trackPoint] distance]]];
	NSSize sz = [s sizeWithAttributes:mileageMarkerTextAttrs]; 
	NSRect r;
	float w = boxWidth;
	float h = sz.height + MM_VERT_MARGIN*2.0;
	r.origin.x = (float)((int)(p.x - (w/2.0) + 0.5));
	r.origin.y = (float)((int)(p.y - (h/2.0)));
	r.size.width = w;
	r.size.height = h;
	NSColor* col = [NSColor colorWithCalibratedRed:(255.0/255.0) green:(255.0/255.0) blue:(255.0/255.0) alpha:0.8];
	[col set];
	[NSBezierPath fillRect:r];
	[[NSColor blackColor] set];
	NSBezierPath* bez = [NSBezierPath bezierPathWithRoundedRect:r
														xRadius:2.0
														yRadius:2.0];
	[bez setLineWidth:1.0];
	[bez stroke];
	float xoff = (boxWidth - sz.width)/2.0; 
	r.size.width = sz.width;
	r.size.height = sz.height;
	r.origin.x += xoff;
	r.origin.y += MM_VERT_MARGIN + 0.5;	// no descenders
	r.origin.x = (float)((int)(r.origin.x + 0.5));
	r.origin.y = (float)((int)(r.origin.y));
	[s drawInRect:r
   withAttributes:mileageMarkerTextAttrs];
}

	 
-(NSPoint)calcGraphPointFromUTMCoordinates:(double)easting northing:(double)northing
{
	float x = initialX + (easting - utmEastingOfLeftTile)/metersPerPixel;
	float y;
	if (terraServerMap(dataType))
		y = initialY + (northing - utmNorthingOfBottomTile)/metersPerPixel;
	else
		y = initialY - (northing - utmNorthingOfBottomTile)/metersPerPixel;
	NSPoint p;
	p.x = x; p.y = y;
	return p;
}


- (NSArray*)drawTrackPath
{
	[NSBezierPath setDefaultLineJoinStyle:NSLineJoinStyleMiter];
	[NSBezierPath setDefaultLineCapStyle:NSLineCapStyleSquare];
	[NSBezierPath setDefaultLineWidth:2.5];
    NSUInteger numPts = [plottedPoints count];
	int count = 0;
	NSPoint prevPt;
	NSColor* clr = [Utils colorFromDefaults:RCBDefaultPathColor];
	[[clr colorWithAlphaComponent:pathOpacity] set];
	[NSBezierPath setDefaultLineWidth:2.5];
	int cpz = kUseDefaultPathColor;
	if (colorizePaths) cpz = [Utils intFromDefaults:RCBDefaultColorPathUsingZone];
	int tcpz = cpz;
	////if (colorizePaths && (selectedLap != nil)) tcpz = kUseBackgroundColor;
	
	
	NSMutableArray* intervalMarkers = [NSMutableArray arrayWithCapacity:32];
	float nextIntervalMarker = intervalMarkerIncrement;
	totalPixelsForPath = 0.0;
	for (int i=0; i<numPts; i++)
	{
		PathPoint* pt = [plottedPoints objectAtIndex:i];
		if ([pt valid])
		{
			NSPoint p = [self calcGraphPointFromUTMCoordinates:[pt easting]
													  northing:[pt northing]];

			// if we've exceeded the mileage interval, add to the marker array
			TrackPoint* trackPoint = [pt trackPoint];
			float distance = [trackPoint distance];
			distance = [Utils convertDistanceValue:distance];
			float incr = intervalMarkerIncrement;
			if (distance >= nextIntervalMarker)
			{
				[intervalMarkers addObject:pt];
				nextIntervalMarker += incr;
			}
			
			if (count > 0)
			{
				[Utils setZoneColor:tcpz 
						 trackPoint:[pt trackPoint]];
				[NSBezierPath strokeLineFromPoint:prevPt 
										  toPoint:p];
				float dx = p.x - prevPt.x;
				float dy = p.y - prevPt.y;
				totalPixelsForPath += sqrtf((dx*dx) + (dy*dy));
			}
			prevPt = p;
			++count;
		}
	}   

	// do selected LAP last, so it shows on top
	if (selectedLap != nil)
	{
		//NSTimeInterval startTimeDelta = [currentTrack lapActiveTimeDelta:selectedLap];
		NSTimeInterval startTimeDelta = [selectedLap startingWallClockTimeDelta];
		//NSTimeInterval lapTime = [currentTrack movingDurationOfLap:selectedLap];
		///NSTimeInterval lapTime = [selectedLap totalTime];
        NSTimeInterval lapTime = [currentTrack durationOfLap:selectedLap];
		[self drawSubPath:startTimeDelta 
				  endTime:startTimeDelta + lapTime 
					color:RCBDefaultLapColor 
					 opac:pathOpacity
					  cpz:cpz];
	}

	if (splitArray)
	{
        NSUInteger num = [splitArray count];
		for (int i=0; i<num; i++)
		{
			SplitTableItem* sti = [splitArray objectAtIndex:i];
			if (sti && [sti selected])
			{
#if 0
				NSTimeInterval start = [sti splitTime];
				[self drawSubPath:start 
						  endTime:start + [sti splitDuration] 
							color:RCBDefaultSplitColor 
							 opac:0.5
							  cpz:kUseDefaultPathColor];
#else                
                
                // fixme -- refactor this, also used in MiniProfileView.  Need
                // to get wall clock times for drawSubPath
                NSTimeInterval start = [sti splitTime];   //active time
                int idx = [currentTrack findIndexOfFirstPointAtOrAfterActiveTimeDelta:start];
                NSArray* pts = [currentTrack points];
                if (pts && [pts count] > idx)
                {
                    NSUInteger np = [pts count];
                    float d = [sti splitDuration];      // active time duration
                    NSLog(@"start: %0.1f  dur: %0.1f  next: %0.1f", start, d, start+d);
                    TrackPoint* spt = [pts objectAtIndex:idx];
                    TrackPoint* lpt = nil;
                    while (idx < np)
                    {
                        lpt = [pts objectAtIndex:idx];
                        if ([lpt activeTimeDelta] >= (start + d)) break;
                        ++idx;
                    }
                    [self drawSubPath:[spt wallClockDelta] 
                              endTime:lpt ? [lpt wallClockDelta] : [spt wallClockDelta] 
                                color:RCBDefaultSplitColor 
                                 opac:0.5
                                  cpz:kUseDefaultPathColor];
            
                 }
#endif
			}
		}
	}
	if (intervalMarkers && showIntervalMarkers)
	{
		// now draw mileage markers
		for (PathPoint* ppt in intervalMarkers)
		{
			[self drawIntervalMarkerForPathPoint:ppt];
			
		}
	}
	
	[self drawMapScale];
	return intervalMarkers;
}


- (void)drawAll
{
	[self drawMapImages:initialX
			  initialY:initialY
			  numHoriz:numHorizTiles
			   numVert:numVertTiles];

	// display the path
	NSArray* markersArray = nil;
	if ((showPath) && (terraServerMap(dataType) || (scale > 6)))
	{
		markersArray = [self drawTrackPath];
	}
   
	if (showLaps) [self drawLaps];
	

	[self drawAnimationBitmap:YES
					 position:[currentTrack animIndex]
					   animID:[currentTrack animID]];
}


-(NSRect)calcRectInMap:(NSRect)utmMapArea;
{
	float x = initialX + (utmMapArea.origin.x - utmEastingOfLeftTile)/metersPerPixel;
	float y;
	if (terraServerMap(dataType))
		y = initialY + (utmMapArea.origin.y  - utmNorthingOfBottomTile)/metersPerPixel;
	else
		y = initialY - (utmMapArea.origin.y - utmNorthingOfBottomTile)/metersPerPixel;
	
	float w = utmMapArea.size.width/metersPerPixel;
	float h = utmMapArea.size.height/metersPerPixel;
	return NSMakeRect(x, y, w, h);
}


-(void)recalcPathXY:(int)lt bottomTile:(int)bt
{
   [trackPath removeAllPoints];
   [trackPath setLineJoinStyle:NSLineJoinStyleRound];
   [trackPath setLineWidth:3.0];
   [lapPath removeAllPoints];
   [lapPath setLineJoinStyle:NSLineJoinStyleRound];
   [lapPath setLineWidth:3.0];
    NSUInteger numPts = [plottedPoints count];
#if 0
	//double utmEastingOfLeftTile;
	//double utmNorthingOfBottomTile;
   if (terraServerMap(dataType))
   {
      utmEastingOfLeftTile = (lt * factor);
      utmNorthingOfBottomTile = (bt * factor);
   }
   else
   {
      utmEastingOfLeftTile = (lt * metersPerTile);
      utmNorthingOfBottomTile = ((bt+1) * metersPerTile);
   }
#endif
	int count = 0;
   int lapCount = 0;
   for (int i=0; i<numPts; i++)
   {
      PathPoint* pt = [plottedPoints objectAtIndex:i];
      if ([pt valid])
      {
         float x = initialX + ([pt easting] - utmEastingOfLeftTile)/metersPerPixel;
         float y;
         if (terraServerMap(dataType))
            y = initialY + ([pt northing] - utmNorthingOfBottomTile)/metersPerPixel;
         else
            y = initialY - ([pt northing] - utmNorthingOfBottomTile)/metersPerPixel;
            
         NSPoint p;
         p.x = x; p.y = y;
         pt->point = p;
         if (count == 0)
            [trackPath moveToPoint:p];
         else
            [trackPath lineToPoint:p];
         ++count;
         
         if (selectedLap != nil)
         {
            //if ([currentTrack isTimeOfDayInLap:selectedLap tod:[pt time]])
			if ([selectedLap isDeltaTimeDuringLap:[pt wallClockDelta]])
            {
               if (lapCount == 0)
               {
                  [lapPath moveToPoint:p];
               }
               else
               {
                  [lapPath lineToPoint:p];
               }
               ++lapCount;
            }
         }
      }
   }   
}


-(void)startMapRetrieval:(id)obj
{
   [[NSNotificationCenter defaultCenter] postNotificationName:@"StartMapRetrieval" object:self];
}


-(void)endMapRetrieval:(id)obj
{
   [[NSNotificationCenter defaultCenter] postNotificationName:@"EndMapRetrieval" object:self];
}


- (void) kickStartDrawing:(id)obj
{
	lastTrack = nil;
	///printf("[%x] KICK START\n", self);
	//[self setNeedsDisplayInRect:[self drawBounds]];
	[self setNeedsDisplay:YES];
}  


-(void) forceRedraw
{
	lastTrack = nil;
	[self setCurrentTrack:currentTrack];
}


// NOTE: this runs in a separate thread!
-(void) getNonCachedMaps:(id)obj
{
	//NSLog(@"tile fetch run loop starting...");
	tileFetchThreadRunning = YES;
	tileFetchThreadFinished = NO;
	// NDRunLoopMessenger object *must* be allocated in same thread that runs
	// its run loop!
	///runLoopMessenger = [[NDRunLoopMessenger alloc] init];
	BOOL isRunning;
	do 
	{
		isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
											 beforeDate:[NSDate distantFuture]];
	///} while (tileFetchThreadRunning && isRunning);
    } while ([fetcher tileFetchThreadRunning] && isRunning);
	// MUST remove all notifications destined for the runLoopMessenger,
	// otherwise they may be sent after this method exits (ThreadWillExit
	// will *Definitely* be sent.  
	///[runLoopMessenger prepareToExit];
	///[runLoopMessenger release];
	runLoopMessenger = nil;
	tileFetchThreadFinished = YES;
	//NSLog(@"tile fetch run loop exiting...");
}


-(void) getATile:(TileInfo*)ti
{
	if ((ti != nil) && (ti->image == nil))
	{
		NSData* data = [self getFileDataOrQueueRetrieval:ti];
		ti->refresh = NO;
		if (data != nil)
		{
			NSImage* image = [[NSImage alloc] initWithData:data];
			NSSize theSize;
			theSize.width = tileWidth;
			theSize.height = tileHeight;
			[image setSize:theSize];
			ti->image = image;
		}
		/*if (!animatingInPlace)*/ [self performSelectorOnMainThread:@selector(kickStartDrawing:) withObject:self waitUntilDone:NO];
	}
}


-(void) getTheMaps:(BOOL)refresh
{
	BOOL getCachedOnly = dragging || [self inLiveResize];

    NSUInteger num = [currentMapImages count];
	int numCached = 0;
	for (int i=0; i<num; i++)
	{
		TileInfo* ti = [currentMapImages objectAtIndex:i];
		NSString* tileKey = [self getTileKey:ti->xTile yTile:ti->yTile zone:ti->tileZone scale:ti->scale dataType:dataType];
		TileInfo* cti = [tileCache objectForKey:tileKey];
		ti->isDisplayed = NO;
		if ((cti != nil) && (cti->image != nil))
		{
			if (ti->image != cti->image) 
			{
				ti->image = cti->image;
			}
			ti->hasBeenFetched = YES;
			///printf("[%x]       fetched tile: %d\n", self, ti->xTile);
			numCached++;
		}
		else if ((cti == nil) && (!getCachedOnly) && (ti->xTile > 0) && (ti->yTile > 0))
		{
			ti->refresh = refresh;
			ti->hasBeenFetched = NO;
			[ti setImage:nil];
			[tileCache setObject:ti forKey:tileKey];
			///printf("[%x]       getting tile: %d\n", self, ti->xTile);
			///[runLoopMessenger target:self performSelector:@selector(getATile:) withObject:ti];
            [[fetcher runLoopMessenger] target:self performSelector:@selector(getATile:) withObject:ti];
            [self performSelector:@selector(getATile:)
                         onThread:fetcher.tileThread
                       withObject:ti
                    waitUntilDone:NO
                            modes:@[NSDefaultRunLoopMode]];
            }
	}
	[self drawAll];
}


- (BOOL)isOpaque
{
   return NO;
}


-(void)refreshMaps
{
	[tileCache removeAllObjects];
	[self getTheMaps:YES];
	
}


-(void)recalcGeometry
{
	///printf("[%x] recalcGeom\n", self);
	double ux = utmX;
	double uy = utmY;
	NSRect rbounds = [self bounds];
	
	if (terraServerMap(dataType))  
	{
		if (overrideDefaults)
		{
			metersPerPixel = .25;
			factor = 50.0;         // this is all terraserver-specific!!!  fixme
			int i = scale - 8;
			while (i>0)
			{
				factor *= 2.0;
				metersPerPixel *= 2.0;
				--i;
			}
			utmW = rbounds.size.width * metersPerPixel;
			utmH = rbounds.size.height * metersPerPixel;
		}
		else
		{
			int tileXmin = 0;
			int tileXmax = 100;
			int tileYmin = 0;
			int tileYmax = 100;
			factor = 200.0;         // this is all terraserver-specific!!!  fixme
			scale = 10;
			metersPerPixel = 1.0;
			int nht = (int)(rbounds.size.width + tileWidth-1)/tileWidth;
			int nvt = (int)(rbounds.size.height + tileHeight-1)/tileHeight;
			while ((((tileXmax - tileXmin + 1) > nht) || ((tileYmax - tileYmin + 1) > nvt)) && (scale < 19))
			{
				factor *= 2.0;
				metersPerPixel *= 2.0;
				tileXmin = (int)(utmEastingMin/factor);
				tileYmin = (int)(utmNorthingMin/factor);
				tileXmax = (int)((utmEastingMax)/factor);  
				tileYmax = (int)((utmNorthingMax)/factor);
				++scale;
			}
			utmW = rbounds.size.width * metersPerPixel;
			utmH = rbounds.size.height * metersPerPixel;
			ux = ((utmEastingMax + utmEastingMin)/2.0) - (utmW/2.0);
			uy = ((utmNorthingMax + utmNorthingMin)/2.0) - (utmH/2.0);
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MapScaleChanged" object:self];
		}
	}
	else
	{
		if (overrideDefaults)
		{
			metersPerPixel = getMetersPerPixel(scale);
			utmW = rbounds.size.width * metersPerPixel;
			utmH = rbounds.size.height * metersPerPixel;
		}
		else
		{
			
			int tmpScale = 20;
			double metersW = utmEastingMax - utmEastingMin;
			double metersH = utmNorthingMax - utmNorthingMin;
			
			int tileXmin = metersToXTileAtZoom(utmEastingMin, tmpScale);
			int tileYmin = metersToYTileAtZoom(utmNorthingMin, tmpScale);
			int tileXmax = metersToXTileAtZoom(utmEastingMax, tmpScale);  
			int tileYmax = metersToYTileAtZoom(utmNorthingMax, tmpScale);
			metersPerPixel = getMetersPerPixel(tmpScale);
			float w = metersW/metersPerPixel;
			float h = metersH/metersPerPixel;
			while (((w > rbounds.size.width) || (h > rbounds.size.height)) && (tmpScale > 1))
			{
				--tmpScale;
				metersPerPixel = getMetersPerPixel(tmpScale);
				tileXmin = metersToXTileAtZoom(utmEastingMin, tmpScale);
				tileYmin = metersToYTileAtZoom(utmNorthingMin, tmpScale);
				tileXmax = metersToXTileAtZoom(utmEastingMax, tmpScale);  
				tileYmax = metersToYTileAtZoom(utmNorthingMax, tmpScale);
				w = metersW/metersPerPixel;
				h = metersH/metersPerPixel;
			}
			utmW = rbounds.size.width * metersPerPixel;
			utmH = rbounds.size.height * metersPerPixel;
			ux = ((utmEastingMax + utmEastingMin)/2.0) - (utmW/2.0);
			uy = ((utmNorthingMax + utmNorthingMin)/2.0) + (utmH/2.0);
			if (tmpScale != scale)
			{
				scale = tmpScale;
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MapScaleChanged" object:self];
			}
		}
	}
	// have a bounding box now that fits in the window and and contains the path.  center it.
	lastScale = scale;
	
	if (terraServerMap(dataType))
	{
		metersPerTile = (metersPerPixel * tileWidth);
	}
	else
	{
		metersPerTile = getMetersPerTile(scale);
	}
	if ((ux != utmX) || (uy != utmY))
	{
		[self resetUTMCoords:ux 
						utmy:uy];
	}
}


-(void)resetUTMCoords:(double)ux utmy:(double)uy
{
	///printf("[%x] resetUTM x:%0.1f y:%0.1f\n", self, ux, uy);
	utmX = ux;
	utmY = uy;
	NSRect rbounds = [self bounds];
	int nht = (int)(rbounds.size.width + tileWidth-1)/tileWidth;
	int nvt = (int)(rbounds.size.height + tileHeight-1)/tileHeight;
	double  adjWidthMeters, adjHeightMeters;
	int lt;
	if (terraServerMap(dataType))
		lt = utmX/metersPerTile;
	else
		lt = metersToXTileAtZoom(utmX, scale);
	
	if (terraServerMap(dataType))
	{
		adjWidthMeters = ((int)utmX)%(int)metersPerTile;
	}
	else
	{
		adjWidthMeters = utmX - (lt * metersPerTile);
		//lt++;
	}
	if (adjWidthMeters != 0) nht++;
	
	int bt;
	if (terraServerMap(dataType))
		bt = utmY/metersPerTile;
	else
		bt = metersToYTileAtZoom(utmY, scale);
	if (terraServerMap(dataType))
	{
		adjHeightMeters = ((int)utmY)%(int)metersPerTile;
	}
	else
	{
		adjHeightMeters = metersPerTile - (utmY - ((bt * metersPerTile)));
		//bt++;
	}
	if (adjHeightMeters != 0)  nvt++;
	
	// set up map images
	float ix = (int)-(adjWidthMeters/metersPerPixel);     
	float iy;
	if (terraServerMap(dataType))
	{
		iy = (int)-(adjHeightMeters/metersPerPixel);
	}
	else
	{
		iy = (int)-(adjHeightMeters/metersPerPixel);
	}
	initialX = ix;
	initialY = iy;
	leftTile = lt;
	bottomTile = bt;
	numHorizTiles = nht;
	numVertTiles = nvt;
	if (terraServerMap(dataType))
	{
		utmEastingOfLeftTile = (leftTile * factor);
		utmNorthingOfBottomTile = (bottomTile * factor);
	}
	else
	{
		utmEastingOfLeftTile = (leftTile * metersPerTile);
		utmNorthingOfBottomTile = ((bottomTile+1) * metersPerTile);
	}
	[self recalcPathXY:lt bottomTile:bt];
	[self setNeedsDisplay:YES];
}



- (void)drawRect:(NSRect)rect
{
	///printf("[%x] *** dr ***\n", self);
	NSRect dbounds = [self drawBounds];
	NSRect rbounds = [self bounds];
#if 0
	//[[NSColor clearColor] set];
	//NSRectFill([self bounds]);
	[[NSColor redColor] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:[self bounds]];
#endif
	if (currentTrack  && [currentTrack hasLocationData] &&  ([[currentTrack goodPoints] count] > 0))
	{
		if ((NSEqualRects(rbounds, rect) == YES))
		{
			[NSGraphicsContext saveGraphicsState];
			[dropShadow set];
            [[NSColor colorNamed:@"BackgroundPrimary"] set];
			[NSBezierPath fillRect:dbounds];
			[NSGraphicsContext restoreGraphicsState];
		}
		prevPathPoint = nil;
		lastBounds = rbounds;
		BOOL newTrack = NO;
		if (lastTrack != currentTrack)
		{
			newTrack = YES;
			lastTrack = currentTrack;
		}

		[currentMapImages removeAllObjects];
		int zne = zoneMin;
		int yt = bottomTile;
		int incr = 1;
		if (!terraServerMap(dataType)) incr = -1;
		for (int vert = 0; vert < numVertTiles; vert++)
		{
			int xt = leftTile;
			for (int horiz=0; horiz < numHorizTiles; horiz++)
			{
				///printf("[%x]   in dr, add image x:%d, s:%d\n", self, xt, scale);
				TileInfo* ti = [[TileInfo alloc] initWithData:nil xTile:xt yTile:yt tileZone:zne scale:scale];
				[currentMapImages addObject:ti];
				++xt;
			}
			yt += incr;
		}  
		[NSGraphicsContext saveGraphicsState];
		NSBezierPath* cp = [NSBezierPath bezierPathWithRect:dbounds];
		[cp setClip];
		[self getTheMaps:NO];
		[NSGraphicsContext restoreGraphicsState];
		
		if (currentTrack == nil)
		{
            [[NSColor colorNamed:@"BackgroundPrimary"] set];
			[NSBezierPath fillRect:dbounds];
		}
		///[[self window] flushWindow];
	}
	else
	{
        [[NSColor colorNamed:@"BackgroundPrimary"] set];
		[NSBezierPath fillRect:dbounds];
		NSString* s = currentTrack ? @"No Location Data" : @"No Activity Selected";
		NSSize size = [s sizeWithAttributes:textFontAttrs];
		float x = dbounds.origin.x + dbounds.size.width/2.0 - size.width/2.0;
		float y = (dbounds.size.height/2.0) - (size.height/2.0);
		[textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"]
                          forKey:NSForegroundColorAttributeName];
		[s drawAtPoint:NSMakePoint(x,y)
		withAttributes:textFontAttrs];
	}
	if (hasPoints) [self drawAnimationBitmap:YES
									position:[currentTrack animIndex]
									  animID:[currentTrack animID]];
}


- (BOOL)wantsDefaultClipping {
   return NO;
}


-(int)dataType
{
   return dataType;
}

-(void) setDataType:(int) dt
{
   if (terraServerMap(dt) != terraServerMap(dataType)) 
   {
      if (terraServerMap(dt))
      {
         tileWidth = tileHeight = 200.0;      
      }
      else
      {
         tileWidth = tileHeight = 256.0;      
      }
      dataType = dt;
      [self setCurrentTrack:currentTrack];
   }
   else
   {
      dataType = dt;
   }
   [self setNeedsDisplay:YES];
}


-(float)mapOpacity
{
   return mapOpacity;
}


-(float)pathOpacity
{
   return pathOpacity;
}


-(void) setMapOpacity:(float) op
{
   mapOpacity = op;
    mapOpacity = 1.0;       /// fixme
   [self setNeedsDisplay:YES];
   [Utils setFloatDefault:op
                   forKey:RCBDefaultMDMapTransparency];
}


-(void)setPathOpacity:(float) op
{
   pathOpacity = op;
    pathOpacity = 1.0;      // fixme opacity
   [self setNeedsDisplay:YES];
   [Utils setFloatDefault:op
                   forKey:RCBDefaultMDPathTransparency];
}


-(int) scale
{
   if (terraServerMap(dataType))
      return scale;
   else
      return 20-scale;
}

		 
-(void)setScale:(int)s
{
	double ux = utmX;
	double uy = utmY;
	switch (dataType)
	{
		case 1:
			// USGS DOQ aerial - range is [10,19]
			s = CLIP(10, s, 19);
			break;
		case 2:
			// USGS DRG Topo, range is [11,19]
			s = CLIP(11, s, 19);
			break;
		case 4:
			// USGS Urban area, range is [8,19]
			s = CLIP(8, s, 19);
			break;
		default:
			// VirtualEarth
			s = 20 - CLIP(1, s, 19);
			break;
	}
	if (s >= scale)
	{
	   // zooming OUT
	   if (terraServerMap(dataType))
		{
		  int d = s - scale;
		  while (d)
		  {
				ux -= (utmW/2.0);
				uy -= (utmH/2.0);
			  ///utmW *= 2.0;
			  ///utmH *= 2.0;
				--d;
			}
		}
		else
		{
			///printf("set scale %d was %d\n", s, scale);
			double centerX = utmX + utmW/2.0;
			double centerY = utmY - utmH/2.0;
			NSRect bounds = [self bounds];
			double mpp = getMetersPerPixel(s);
			ux = centerX - ((bounds.size.width/2.0)*mpp);
			uy = centerY + ((bounds.size.height/2.0)*mpp);
			utmW = bounds.size.width * mpp;
			utmH = bounds.size.height * mpp;
			metersPerPixel = mpp;
		}
	} 
	else if (s < scale)
	{
		if (terraServerMap(dataType))
		{
			int d = scale - s;
			while (d)
			{
				ux += (utmW/4.0);
				uy += (utmH/4.0);
				///utmW /= 2.0;
				///utmH /= 2.0;
				--d;
			}
		}
		else
		{
			///printf("set scale %d was %d\n", s, scale);
			double centerX = utmX + utmW/2.0;
			double centerY = utmY - utmH/2.0;
			NSRect bounds = [self bounds];
			double mpp = getMetersPerPixel(s);
			ux = centerX - ((bounds.size.width/2.0)*mpp);
			uy = centerY + ((bounds.size.height/2.0)*mpp);
			utmW = bounds.size.width * mpp;
			utmH = bounds.size.height * mpp;
			metersPerPixel = mpp;
		}
	}
      
	scale = s;
	overrideDefaults = YES;
	lastTrack = nil;     // force redraw
	[self recalcGeometry];
	[self resetUTMCoords:ux
					utmy:uy];
	[self setNeedsDisplay:YES];
}


-(void)moveHoriz:(int)incr
{
   utmX -= (incr * metersPerTile);
   overrideDefaults = YES;
   lastTrack = nil;     // force redraw
   [self setNeedsDisplay:YES];
}

-(void)moveVert:(int)incr
{
   utmY -= (incr * metersPerTile);
   overrideDefaults = YES;
   lastTrack = nil;     // force redraw
   [self setNeedsDisplay:YES];
}


-(BOOL)showLaps
{
   return showLaps;
}


-(void)setShowIntervalMarkers:(BOOL)show
{
	showIntervalMarkers = show;
	[self setNeedsDisplay:YES];
}


-(BOOL)showIntervalMarkers
{
	return showIntervalMarkers;
}


-(void)setIntervalIncrement:(float)incr
{
	intervalMarkerIncrement = incr;
	[self setNeedsDisplay:YES];
}

-(void)setShowLaps:(BOOL)sl
{
   if (moveMapDuringAnimation)
   {
      showLaps = sl;
      lastTrack = nil;     // force redraw
      [self setNeedsDisplay:YES];
      [Utils setBoolDefault:sl
                     forKey:RCBDefaultMDShowLaps];
   }
}


-(BOOL)showPath
{
   return showPath;
}


-(void)setShowPath:(BOOL)sp
{  
   if (moveMapDuringAnimation)
   {
      showPath = sp;
      lastTrack = nil;     // force redraw
      [self setNeedsDisplay:YES];
      [Utils setBoolDefault:sp
                     forKey:RCBDefaultMDShowPath];
   }
}


-(void)setDefaults
{
	overrideDefaults = NO;
	scale = 10;
	[self recalcGeometry];
}


-(void)centerOnPoint:(PathPoint*)pt
{
	double ux = [pt easting] - utmW/2.0;
	double uy;
	if (terraServerMap(dataType))
	{
		uy = [pt northing] - utmH/2.0;
	}
	else
	{
		uy = [pt northing] + utmH/2.0;
	}
	lastTrack = nil;     // force redraw
	overrideDefaults = YES;
	[self resetUTMCoords:ux
					utmy:uy];
	[self setNeedsDisplay:YES];
}


-(void)centerAtStart
{
    NSUInteger num = [plottedPoints count];
    if (num > 0)
   {
      for (int i=0; i<num; i++)
      {
         PathPoint* pt = [plottedPoints objectAtIndex:i];
         if ([pt valid])
         {
            [self centerOnPoint:pt];
            break;
         }
      }
   }
}


-(void)centerAtEnd
{
    NSUInteger num = [plottedPoints count];
   if (num > 0)
   {
      for (NSUInteger i=num-1; i>=0; i--)
      {
         PathPoint* pt = [plottedPoints objectAtIndex:i];
         if ([pt valid])
         {
            [self centerOnPoint:pt];
            break;
         }
      }
   }
}


-(void)viewDidEndLiveResize
{
   //NSLog(@"ending map resize...");
   [super viewDidEndLiveResize];
   lastTrack = nil;     // force redraw
   [self kickStartDrawing:self];
   
}



static NSPoint dragPoint;

- (void)mouseDown:(NSEvent*) ev
{
	if (!enableMapInteraction) return;
    NSInteger i = [ev clickCount];
	if((!isDetailedMap) &&(2==i))
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"OpenMapDetail" object:self];
	}
	else
	{
		NSPoint evLoc = [ev locationInWindow];
		evLoc = [self convertPoint:evLoc fromView:nil];
		if (NSPointInRect(evLoc, lastBounds))
		{
		  dragging = YES;
		  dragPoint = evLoc;
		}
	}
}


- (void)mouseDragged:(NSEvent*) ev
{
 	if (!enableMapInteraction) return;
	if (dragging == YES)
	{
		overrideDefaults = YES;
		NSPoint evLoc = [ev locationInWindow];
		evLoc = [self convertPoint:evLoc fromView:nil];
		float dx = evLoc.x - dragPoint.x;
		float dy = evLoc.y - dragPoint.y;
		dragPoint = evLoc;
		double ux = utmX - (dx * metersPerPixel);
		double uy;
		if (terraServerMap(dataType))
			uy = utmY - (dy * metersPerPixel);
		else
			uy = utmY + (dy * metersPerPixel);
		lastTrack = nil;
		[self resetUTMCoords:ux
						utmy:uy];
		[self setNeedsDisplay:YES];
	}
}




- (void)mouseUp:(NSEvent*) ev
{
 	if (!enableMapInteraction) return;
	if (dragging == YES)
	{
	  dragging = NO;
	  lastTrack = nil;
	  overrideDefaults = YES;
	  lastTrack = nil;     // force redraw
	  [self setNeedsDisplay:YES];
	}
}


- (void)centerOnMousePoint:(NSEvent*)ev
{
	overrideDefaults = YES;
	lastTrack = nil;
	NSPoint evLoc = [ev locationInWindow];
	evLoc = [self convertPoint:evLoc fromView:nil];
	NSRect bounds = [self bounds];
	float dx = evLoc.x - bounds.size.width/2;
	float dy = evLoc.y - bounds.size.height/2;
	double ux = utmX + (metersPerPixel * dx);
	double uy;
	if (terraServerMap(dataType))
	{
		uy = utmY + (metersPerPixel * dy);
	}
	else
	{
		uy = utmY - (metersPerPixel * dy);
	}
	[self resetUTMCoords:ux
					utmy:uy];
	[self setNeedsDisplay:YES];
}



-(int) incScaleValue:(int)s in:(BOOL)in
{
   int incr = 0;
   switch (dataType)
   {
      case 1:
      case 2:
      case 4:
         if (in) 
            incr = -1;
         else
            incr = +1;
         break;
      default:
         // VirtualEarth
         if (in)
            return (20-s)-1;
         else
            return (20-s)+1;
         break;
   }
   return s + incr;
}   



- (void)scrollWheel:(NSEvent *)theEvent
{
	///if (!enableMapInteraction) return;
	overrideDefaults = YES;
	float dy = [theEvent deltaY];
	sCumulativeDeltaY += dy;
	if ((sCumulativeDeltaY > scrollWheelSensitivity) || (sCumulativeDeltaY < -scrollWheelSensitivity)) 
	{
		sCumulativeDeltaY = 0.0;
		[self setScale:[self incScaleValue:scale in:dy > 0]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MapScaleChanged" object:self];
		lastTrack = nil;
		[self setNeedsDisplay:YES];
	}
}

-(void)zoomOneLevel:(BOOL)zoomin
{
	if (zoomin)
	{
		[self setScale:[self incScaleValue:scale in:YES]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MapScaleChanged" object:self];
	}
	else
	{
		[self setScale:[self incScaleValue:scale in:NO]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MapScaleChanged" object:self];
	}
}


- (void)keyDown:(NSEvent *)theEvent
{
	float dx = 0.0;
	float dy = 0.0;
	int kc = [theEvent keyCode];
	switch (kc)
	{
		case 49:        // SPACE
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TogglePlay" object:self];
			break;
         
		case 34:          // "I"
		   [self zoomOneLevel:YES];
			return;
         
		case 31:          // "O"
			[self zoomOneLevel:NO];
			return;
         
		case 35:          // "P"
			[self setDefaults];
			return;
         
		case 1:           // "S"
			if (!enableMapInteraction) [self centerAtStart];
			return;
         
		case 14:          // "E"
			if (!enableMapInteraction) [self centerAtEnd];
			return;
         
		case 126:
			if (!enableMapInteraction) dy = -1.0;
			break;
		case 125:
			if (!enableMapInteraction)  dy = +1.0;
			break; 
		case 124:
			if (!enableMapInteraction) dx = -1.0;
			break;
		case 123:
			if (!enableMapInteraction)  dx = +1.0;
			break;
	}
	if ((dx != 0.0) || (dy != 0.0))
	{
		overrideDefaults = YES;
		utmX -= (dx * metersPerPixel);
		if (terraServerMap(dataType))
			utmY -= (dy * metersPerPixel);
		else
			utmY += (dy * metersPerPixel);
		lastTrack = nil;
		[self setNeedsDisplay:YES];
	}
}


- (void)setMoveMapDuringAnimation:(BOOL)moveMap
{
   moveMapDuringAnimation = moveMap;
   showPath = moveMapDuringAnimation ? [Utils boolFromDefaults:RCBDefaultMDShowPath] : YES;
   showLaps = moveMapDuringAnimation ? [Utils boolFromDefaults:RCBDefaultMDShowLaps] : YES;
}

- (void)viewWillStartLiveResize
{
   //NSLog(@"starting map resize...");
   [super viewWillStartLiveResize];
}


- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
   NSMenu* menu = nil;
   if (mContextualMenuInvocation) 
   {
      [mContextualMenuInvocation setArgument:&theEvent 
                                     atIndex:2];
      [mContextualMenuInvocation invoke];
      [mContextualMenuInvocation getReturnValue:&menu];
   }
   return menu;
}



-(void) setContextualMenuInvocation:(NSInvocation*)inv
{
   if (inv != mContextualMenuInvocation)
   {
      [mContextualMenuInvocation release];
      mContextualMenuInvocation = inv;
      [mContextualMenuInvocation retain];
   }
}

-(void)forceRedisplay
{
   lastTrack= nil;
   [self setNeedsDisplay:YES];
}

- (BOOL)isDetailedMap
{
	return isDetailedMap;
}


- (void)setIsDetailedMap:(BOOL)value
{
	isDetailedMap = value;
}

-(void) setDataHudUpdateInvocation:(NSInvocation*)inv
{
   if (inv != dataHudUpdateInvocation)
   {
      dataHudUpdateInvocation = [inv retain];   // fixme added retain
   }
}


-(NSRect)utmMapArea
{
	return NSMakeRect(utmX, utmY, utmW, utmH);
}


@end
