//
//  AscentPathFinder 2.h
//  Ascent
//
//  Created by Rob Boyer on 10/7/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


// AscentPathFinder.h
// MRC-safe: no instance variables or complex init/dealloc needed.

#import <Foundation/Foundation.h>
#import "Track.h"
#import "GeoHelper.h"

@interface AscentPathFinder : NSObject

// Main method to find similar tracks.
// Returns an NSArray<Track*> of tracks that match the path criteria.
// startLocation: The latitude/longitude of the starting point of the desired path.
// lengthKM: The desired length of the path segment in kilometers.
// tolerancePercent: The maximum allowed deviation (as a percentage of lengthKM) for both length and path shape.
+ (NSArray<Track*>*)findTracks:(NSArray<Track*>*)trackArray
              withPathStartingAt:(tLocation)startLocation
                        lengthKM:(float)lengthKM
              tolerancePercent:(float)tolerancePercent;

@end
