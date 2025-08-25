//
//  TransparentMapViewProtocol.h
//  Ascent
//
//  Created by Rob Boyer on 3/27/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>



@class TrackPoint;


@protocol TransparentMapViewProtocol
-(void) update:(NSPoint)pos trackPoint:(TrackPoint*)tpt animID:(int)aid;
-(void) prefsChanged;
@end




