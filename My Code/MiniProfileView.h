/* MiniProfileView */

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TransparentMapView;


@interface MiniProfileView : NSView
-(void) setCurrentTrack:(Track*) tr;
-(void) updateTrackAnimation:(int)currentTrackPos;
-(Lap *) selectedLap;
-(void) setSelectedLap:(Lap *)value;
-(void) setSplitArray:(NSArray *)value;
-(void) setTransparentView:(TransparentMapView*) v;


@end
