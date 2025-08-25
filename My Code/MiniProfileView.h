/* MiniProfileView */

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TransparentMapView;

@interface MiniProfileView : NSView
{
	Track*					currentTrack;
	Track*					lastTrack;
	Lap*					selectedLap;
	NSBezierPath*			dpath;
	NSBezierPath*			lpath;
	float					minalt, maxalt, altdif, maxdist;
	int						numPts;
	int						currentTrackPos;
	NSMutableArray*			plottedPoints;
	NSMutableDictionary*	tickFontAttrs; 
	NSMutableDictionary*	textFontAttrs;
	int						numVertTickPoints;
	TransparentMapView*		transparentView;
	NSPoint					lastAnimPoint;
	NSArray*				splitsArray;
	BOOL					xAxisIsTime;
}
-(void) setCurrentTrack:(Track*) tr;
-(void) updateTrackAnimation:(int)currentTrackPos;
-(void) setTransparentView:(TransparentMapView*)v;
-(Lap *) selectedLap;
-(void) setSelectedLap:(Lap *)value;
-(void) setSplitArray:(NSArray *)value;


@end
