//
//  AscentPathFinder.m
//  AscentTests
//
//  Created by Rob Boyer on 10/7/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "AscentPathFinder.h"
#import "TrackPoint.h"
#import "GeoHelper.h"
#include <float.h>

@implementation AscentPathFinder

// Private helper to check if two segments are similar enough based on maximum point deviation
// The check is symmetrical: deviation of trackA from trackB, and trackB from trackA.
+ (BOOL)isSegment:(NSArray<TrackPoint*>*)pointsA
            from:(int)startA to:(int)endA
       similarTo:(NSArray<TrackPoint*>*)pointsB
            from:(int)startB to:(int)endB
        maxDeviationKM:(float)maxDeviationKM
{
    // A path is defined by the segments (from point[i] to point[i+1]).
    // We check points from the first path against the segments of the second, and vice-versa.

    // 1. Check Points A against Segments B
    for (int i = startA; i <= endA; i++) {
        TrackPoint *pointA = [pointsA objectAtIndex:i];
        tLocation locA = {pointA.latitude, pointA.longitude};
        
        float minDistanceToBPath = FLT_MAX;
        
        // Find the distance from point A to the *closest* segment in path B
        for (int j = startB; j < endB; j++) {
            TrackPoint *p1B = [pointsB objectAtIndex:j];
            TrackPoint *p2B = [pointsB objectAtIndex:j+1];
            
            tLocation loc1B = {p1B.latitude, p1B.longitude};
            tLocation loc2B = {p2B.latitude, p2B.longitude};

            float dist = PointToSegmentDistance(locA, loc1B, loc2B);
            minDistanceToBPath = fminf(minDistanceToBPath, dist);
        }
        
        if (minDistanceToBPath > maxDeviationKM) {
            // Path A deviates too much from Path B
            return NO;
        }
    }

    // 2. Check Points B against Segments A (Symmetrical check is crucial for "same path")
    for (int i = startB; i <= endB; i++) {
        TrackPoint *pointB = [pointsB objectAtIndex:i];
        tLocation locB = {pointB.latitude, pointB.longitude};
        
        float minDistanceToAPath = FLT_MAX;
        
        // Find the distance from point B to the *closest* segment in path A
        for (int j = startA; j < endA; j++) {
            TrackPoint *p1A = [pointsA objectAtIndex:j];
            TrackPoint *p2A = [pointsA objectAtIndex:j+1];
            
            tLocation loc1A = {p1A.latitude, p1A.longitude};
            tLocation loc2A = {p2A.latitude, p2A.longitude};

            float dist = PointToSegmentDistance(locB, loc1A, loc2A);
            minDistanceToAPath = fminf(minDistanceToAPath, dist);
        }

        if (minDistanceToAPath > maxDeviationKM) {
            // Path B deviates too much from Path A
            return NO;
        }
    }

    return YES;
}

+ (NSArray<Track*>*)findTracks:(NSArray<Track*>*)trackArray
              withPathStartingAt:(tLocation)startLocation
                        lengthKM:(float)lengthKM
              tolerancePercent:(float)tolerancePercent
{
    // MRC: Use autorelease pool if this method is called frequently in a loop,
    // though the implementation itself avoids unnecessary object creation.
    // Since this returns an array, the caller will be responsible for releasing it (non-ARC).
    NSMutableArray<Track*>* resultTracks = [[NSMutableArray alloc] init]; // Caller must release
    
    // Safety check for input
    if (lengthKM <= 0.0 || tolerancePercent < 0.0 || [trackArray count] == 0) {
        return [resultTracks autorelease];
    }

    // 1. Calculate tolerances
    float lengthToleranceKM = lengthKM * (tolerancePercent / 100.0);
    float maxDeviationKM = lengthToleranceKM; // Use the length tolerance as the path deviation tolerance.
    float minLengthKM = lengthKM - lengthToleranceKM;
    float maxLengthKM = lengthKM + lengthToleranceKM;
    
    // Ensure minLength is not negative
    if (minLengthKM < 0.0) minLengthKM = 0.0;

    // We need at least one track to establish the reference path (Path A).
    // Use the first track that successfully yields a segment as the reference.
    Track *referenceTrack = nil;
    int refStartIdx = -1;
    int refEndIdx = -1;
    
    // Find the first valid reference segment and establish its path points
    for (Track *t in trackArray) {
        // Need to cast to use the category/internal method
        if (t && [t findSegmentStart:&refStartIdx end:&refEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            referenceTrack = t;
            // Retain the reference track to ensure it exists throughout the loop (MRC)
            // But since we are only using its pointers/data, we don't strictly need to retain it
            // if we assume the input array is retained for the duration.
            break;
        }
    }
    
    if (referenceTrack == nil) {
        // No track in the array contains the starting point and length within tolerance.
        return [resultTracks autorelease];
    }
    
    NSArray<TrackPoint*>* refPoints = [referenceTrack points]; // MRC accessor

    // 2. Iterate through all tracks and compare them to the reference path
    for (Track *currentTrack in trackArray) {
        int currentStartIdx = -1;
        int currentEndIdx = -1;
        
        // a. Find the segment for the current track
        if (![currentTrack findSegmentStart:&currentStartIdx end:&currentEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            continue; // Cannot find a suitable segment
        }
        
        NSArray<TrackPoint*>* currentPoints = [currentTrack points]; // MRC accessor
        
        // b. Check Length Tolerance
        float currentLength = TrackSegmentLength(currentPoints, currentStartIdx, currentEndIdx);

        if (currentLength < minLengthKM || currentLength > maxLengthKM) {
            continue;
        }
        
        // c. Check End Point Tolerance (The end of the segment must be near the reference end point)
        TrackPoint *refEndPoint = [refPoints objectAtIndex:refEndIdx];
        TrackPoint *currentEndPoint = [currentPoints objectAtIndex:currentEndIdx];

        tLocation refEndLoc = {refEndPoint.latitude, refEndPoint.longitude};
        tLocation currentEndLoc = {currentEndPoint.latitude, currentEndPoint.longitude};
        
        // The distance between the reference segment's end and the current segment's end must be within tolerance.
        if (GeodesicDistance(refEndLoc, currentEndLoc) > maxDeviationKM) {
            continue;
        }

        // d. Check Path Deviation (The core "same path" logic)
        // If currentTrack is the referenceTrack, it is trivially a match.
        // Otherwise, perform the full geometric check.
        if (currentTrack == referenceTrack ||
            [AscentPathFinder isSegment:refPoints from:refStartIdx to:refEndIdx
                             similarTo:currentPoints from:currentStartIdx to:currentEndIdx
                        maxDeviationKM:maxDeviationKM])
        {
            [resultTracks addObject:currentTrack];
            // MRC: The object in the array is already retained by the input array,
            // and the result array now retains it. No need to manually retain/release here.
        }
    }
    
    return [resultTracks autorelease]; // Return the result array, giving ownership to the caller.
}

@end
