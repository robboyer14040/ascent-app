//
//  GeoHelper.h
//  Ascent
//
//  Created by Rob Boyer on 10/7/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Defs.h"


@class TrackPoint;


// Helper functions for geospatial calculations (in GeoHelper.m)
float GeodesicDistance(tLocation p1, tLocation p2);
float TrackSegmentLength(NSArray<TrackPoint*>* points, int startIndex, int endIndex);
int FindPointIndexNearLocation(NSArray<TrackPoint*>* points, tLocation location, float maxDistanceTolerance);
float PointToSegmentDistance(tLocation p, tLocation a, tLocation b);
