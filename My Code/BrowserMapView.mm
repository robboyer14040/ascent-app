#import "BrowserMapView.h"
#import "Track.h"
#import "TrackPoint.h"
#import "LatLong-UTMconversion.h"

@implementation BrowserMapView

- (id)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName
{
	if ((self = [super initWithFrame:frameRect frameName:frameName groupName:groupName]) != nil) {
		// Add initialization code here
      currentTrack = nil;
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
   [super drawRect:rect];
   NSMutableArray* points = [currentTrack points];
   
   double minLat = [[points valueForKeyPath:@"@min.latitude"] doubleValue];
   double maxLat = [[points valueForKeyPath:@"@max.latitude"] doubleValue];
   double minLong = [[points valueForKeyPath:@"@min.longitude"] doubleValue];
   double maxLong = [[points valueForKeyPath:@"@max.longitude"] doubleValue];
   
   double utmNorthingMin, utmEastingMin;
   double utmNorthingMax, utmEastingMax;
   char utmZoneMin[4];
   char utmZoneMax[4];
	int refEllipsoid = 23;//WGS-84. See list with file "LatLong- UTM conversion.cpp" for id numbers
   LLtoUTM(refEllipsoid, minLat, minLong, &utmNorthingMin, &utmEastingMin, utmZoneMin);
   LLtoUTM(refEllipsoid, maxLat, maxLong, &utmNorthingMax, &utmEastingMax, utmZoneMax);
   double factor = 200.0;
   int tsXMin, tsXMax, tsYMin, tsYMax;
   tsXMin = 0; tsXMax = 100; tsYMin = 0; tsYMax = 100;
   int scale = 10;
   while ((((tsXMax - tsXMin) > 1.0) || ((tsYMax - tsYMin) > 1.0)) && (scale < 19))
   {
      factor *= 2.0;
      tsXMin = (int)(utmEastingMin/factor);
      tsYMin = (int)(utmNorthingMin/factor);
      tsXMax = (int)(utmEastingMax/factor);
      tsYMax = (int)(utmNorthingMax/factor);
      ++scale;
   }
   
   if (tsXMin == tsXMax) tsXMax = tsXMin + 1;
   if (tsYMin == tsYMax) tsYMax = tsYMin + 1;
   
   
   // now plot the path
   utmEastingMin = tsXMin * factor;    // current values shown in maps
   utmEastingMax = (tsXMax+1) * factor;
   utmNorthingMin = tsYMin * factor;
   utmNorthingMax = (tsYMax+1) * factor;
   
   UTMtoLL(refEllipsoid, utmNorthingMin, utmEastingMin, utmZoneMin, &minLat, &minLong);
   UTMtoLL(refEllipsoid, utmNorthingMax, utmEastingMax, utmZoneMax, &maxLat, &maxLong);
   
   float deltaLat = (float)(maxLat - minLat);
   float deltaLong = (float)(maxLong - minLong);
   float minLatFloat = (float)minLat;
   float minLongFloat = (float)minLong;
   
   NSRect bounds = [self bounds];
   
   int numPts = [points count];
   if ((numPts > 2) && (0.0 != deltaLat) && (0.0 != deltaLong))
   {
      NSBezierPath* dpath = [[NSBezierPath alloc] init];
      [[NSColor redColor] set];
      [dpath setLineWidth:3.0];
      NSPoint p;
      int i;
      for (i=0; i<numPts; i++)
      {
         TrackPoint* pt = [points objectAtIndex:i];
         float lat = [pt latitude];
         float lon = [pt longitude];
         p.x = 540.0 + (((lat - minLatFloat)/deltaLat) * bounds.size.width);
         p.y = 20.0 + (((lon - minLongFloat)/deltaLong) * bounds.size.height);
         if (i == 0)
            [dpath moveToPoint:p];
         else
            [dpath lineToPoint:p];
      }
      [dpath stroke];
      [dpath release];
   }
}


-(void) setCurrentTrack:(Track*) tr
{
   currentTrack = tr;
}



@end
