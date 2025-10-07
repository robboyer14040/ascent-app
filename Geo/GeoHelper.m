//
//  GeoHelper.m
//  Ascent
//
//  Created by Rob Boyer on 10/7/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#include <math.h>

#import "GeoHelper.h"
#import "TrackPoint.h" // To use TrackPoint for path comparison

#define EARTH_RADIUS_KM 6371.0
#define PI 3.14159265358979323846

// Helper to convert degrees to radians
static inline double degreesToRadians(double degrees) {
    return degrees * PI / 180.0;
}

// Haversine formula for Geodesic Distance in Kilometers
float GeodesicDistance(tLocation p1, tLocation p2)
{
    double lat1 = degreesToRadians(p1.latitude);
    double lon1 = degreesToRadians(p1.longitude);
    double lat2 = degreesToRadians(p2.latitude);
    double lon2 = degreesToRadians(p2.longitude);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(lat1) * cos(lat2) *
               sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return (float)(EARTH_RADIUS_KM * c);
}

// Simplified function to estimate the length of a track segment in KM
float TrackSegmentLength(NSArray<TrackPoint*>* points, int startIndex, int endIndex)
{
    float totalDistance = 0.0;
    if (startIndex < 0 || endIndex >= [points count] || startIndex > endIndex) {
        return 0.0;
    }

    for (int i = startIndex; i < endIndex; i++) {
        TrackPoint *p1 = [points objectAtIndex:i];
        TrackPoint *p2 = [points objectAtIndex:i+1];
        
        tLocation loc1 = {p1.latitude, p1.longitude};
        tLocation loc2 = {p2.latitude, p2.longitude};

        totalDistance += GeodesicDistance(loc1, loc2);
    }
    return totalDistance;
}

// Finds the index of the point closest to a given location, within a tolerance
int FindPointIndexNearLocation(NSArray<TrackPoint*>* points, tLocation location, float maxDistanceTolerance)
{
    float minDistance = FLT_MAX;
    int closestIndex = -1;

    for (int i = 0; i < [points count]; i++) {
        TrackPoint *p = [points objectAtIndex:i];
        tLocation pointLoc = {p.latitude, p.longitude};
        
        float distance = GeodesicDistance(location, pointLoc);

        if (distance <= maxDistanceTolerance && distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
        }
    }
    return closestIndex;
}


// --- Point to Segment Distance Helpers (Simplified for Lat/Lon comparison) ---

// Calculates the closest point on the line passing through 'a' and 'b' to point 'p'.
// Returns the point, and updates the t parameter (which dictates if the closest point is on the segment).
// Note: For simplicity and to avoid complex 3D geodesic math, this uses a Euclidean approximation
// in a localized coordinate system. This is a common simplification for short segments.
tLocation ClosestPointOnLine(tLocation p, tLocation a, tLocation b, float *t)
{
    // Localized vectors for approximation
    float ax = a.longitude;
    float ay = a.latitude;
    float bx = b.longitude;
    float by = b.latitude;
    float px = p.longitude;
    float py = p.latitude;

    float dx = bx - ax;
    float dy = by - ay;

    if (dx == 0.0 && dy == 0.0) { // a and b are the same point
        *t = 0.0;
        return a;
    }
    
    // t is the projection of vector AP onto vector AB, scaled by the length of AB
    float lengthSq = dx * dx + dy * dy;
    *t = ((px - ax) * dx + (py - ay) * dy) / lengthSq;

    if (*t < 0.0) {
        return a; // Closest point is A
    } else if (*t > 1.0) {
        return b; // Closest point is B
    }
    
    // Closest point is on the line segment
    tLocation result = {
        .latitude = ay + *t * dy,
        .longitude = ax + *t * dx
    };
    return result;
}

// Distance from point p to line segment ab.
float PointToSegmentDistance(tLocation p, tLocation a, tLocation b)
{
    float t;
    tLocation closestPoint = ClosestPointOnLine(p, a, b, &t);
    
    // If t is between 0 and 1, the closest point is on the segment.
    // Otherwise, the closest point is one of the endpoints.
    if (t >= 0.0 && t <= 1.0) {
        return GeodesicDistance(p, closestPoint);
    } else if (t < 0.0) {
        return GeodesicDistance(p, a);
    } else { // t > 1.0
        return GeodesicDistance(p, b);
    }
}
