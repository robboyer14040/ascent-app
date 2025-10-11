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


// [Existing isSegment:from:similarTo:from:maxDeviationKM: implementation is assumed to be here]

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


// *** MODIFIED METHOD ***
+ (NSArray<Track*>*)findTracks:(NSArray<Track*>*)trackArray
           withPathStartingAt:(tLocation)startLocation
                     lengthKM:(float)lengthKM
             tolerancePercent:(float)tolerancePercent
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray<Track*>* resultTracks = [[NSMutableArray alloc] init]; // Caller must release
    
    // Safety check for input
    if (lengthKM <= 0.0 || tolerancePercent < 0.0 || [trackArray count] == 0) {
        [pool release];
        return [resultTracks autorelease];
    }

    // 1. Calculate tolerances
    float lengthToleranceKM = lengthKM * (tolerancePercent / 100.0);
    float maxDeviationKM = lengthToleranceKM; // Use the length tolerance as the path deviation tolerance.
    float minLengthKM = lengthKM - lengthToleranceKM;
    float maxLengthKM = lengthKM + lengthToleranceKM;
    
    if (minLengthKM < 0.0) minLengthKM = 0.0;

    // We need at least one track to establish the reference path (Path A).
    Track *referenceTrack = nil;
    int refStartIdx = -1;
    int refEndIdx = -1;
    
    // Find the first valid reference segment
    for (Track *t in trackArray) {
        // Find segment start/end indices using the desired logic within the Track object
        if (t && [t findSegmentStart:&refStartIdx end:&refEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            referenceTrack = t;
            break;
        }
    }
    
    if (referenceTrack == nil) {
        // No track in the array contains the starting point and length within tolerance.
        [pool release];
        return [resultTracks autorelease];
    }
    
    // *** MODIFICATION: Use 'goodPoints' for the reference track ***
    NSArray<TrackPoint*>* refPoints = [referenceTrack goodPoints];

    // 2. Iterate through all tracks and compare them to the reference path
    for (Track *currentTrack in trackArray) {
        int currentStartIdx = -1;
        int currentEndIdx = -1;
        
        // a. Find the segment for the current track
        if (![currentTrack findSegmentStart:&currentStartIdx end:&currentEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            continue; // Cannot find a suitable segment
        }
        
        // *** MODIFICATION: Use 'goodPoints' for the current track ***
        NSArray<TrackPoint*>* currentPoints = [currentTrack goodPoints];
        
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
            // The resultTracks array retains the Track object
            [resultTracks addObject:currentTrack];
        }
    }
    
    [pool release];
    // Return the result array, giving ownership to the caller (MRC convention).
    return [resultTracks autorelease];
}


#pragma mark - Shortest Track Finder

+ (NSArray *)findShortestTracks:(NSArray<Track*>*)trackArray
           withSegmentStartingAt:(tLocation)startLocation
                        lengthKM:(float)lengthKM
                           count:(int)count
                           error:(NSError * __autoreleasing *)error
{
    // Autorelease Pool used for the method execution (MRC convention)
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Safety checks
    if (lengthKM <= 0.0 || count <= 0 || [trackArray count] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"AscentPathFinderErrorDomain"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid input: length must be positive, count must be > 0, and track array cannot be empty."}];
        }
        [pool release];
        return nil;
    }
    
    // --- 1. Prepare filtering and collection parameters ---
    
    // Array to hold temporary dictionaries/objects for sorting purposes.
    NSMutableArray *collectableData = [[NSMutableArray alloc] init];
    
    // Define the geometrical tolerance (assuming a default tolerance)
    float tolerancePercent = 5.0;
    float lengthToleranceKM = lengthKM * (tolerancePercent / 100.0);
    float maxDeviationKM    = lengthToleranceKM;
    
    float minLengthKM = lengthKM - lengthToleranceKM;
    float maxLengthKM = lengthKM + lengthToleranceKM;
    if (minLengthKM < 0.0) minLengthKM = 0.0;
    
    // Find the first valid reference segment and establish its path points (for 'isSegment' logic)
    Track *referenceTrack = nil;
    int refStartIdx = -1;
    int refEndIdx = -1;
    
    for (Track *t in trackArray) {
        // NOTE: findSegmentStart/end must use the goodPoints array internally
        if (t && [t findSegmentStart:&refStartIdx end:&refEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            referenceTrack = t;
            break;
        }
    }
    
    if (referenceTrack == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"AscentPathFinderErrorDomain"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"No track in the array contains a segment matching the specified criteria."}];
        }
        [collectableData release];
        [pool release];
        return [[[NSArray alloc] init] autorelease];
    }
    
    // *** MODIFICATION: Use 'goodPoints' ***
    NSArray<TrackPoint*>* refPoints = [referenceTrack goodPoints];

    // --- 2. Iterate, Filter, and Collect Time Data ---
    
    for (Track *currentTrack in trackArray)
    {
        int currentStartIdx = -1;
        int currentEndIdx = -1;
        
        // a. Find the segment for the current track
        if (![currentTrack findSegmentStart:&currentStartIdx end:&currentEndIdx forStartLocation:startLocation length:lengthKM tolerance:tolerancePercent]) {
            continue;
        }
        
        // *** MODIFICATION: Use 'goodPoints' for current track ***
        NSArray<TrackPoint*>* currentPoints = [currentTrack goodPoints];
        float currentLength = TrackSegmentLength(currentPoints, currentStartIdx, currentEndIdx);

        // b. Check Length Tolerance
        if (currentLength < minLengthKM || currentLength > maxLengthKM) {
            continue;
        }
        
        // c. Check Path Deviation (Symmetrical check)
        BOOL isSimilar = NO;
        if (currentTrack == referenceTrack) {
            isSimilar = YES;
        } else {
            isSimilar = [AscentPathFinder isSegment:refPoints from:refStartIdx to:refEndIdx
                                         similarTo:currentPoints from:currentStartIdx to:currentEndIdx
                                    maxDeviationKM:maxDeviationKM];
        }

        if (isSimilar) {
            
            NSTimeInterval segmentTime = [currentTrack movingDurationBetweenGoodPoints:currentStartIdx end:currentEndIdx];
            
            float trackDeviation = 0.0f; // Assumed calculated elsewhere or placeholder
            
            // Create a dictionary to hold data for the sorting/output step
            NSDictionary *tempDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                      currentTrack,      @"track",
                                      [NSNumber numberWithInt:currentStartIdx], @"start_index",
                                      [NSNumber numberWithInt:currentEndIdx],   @"end_index",
                                      [NSNumber numberWithDouble:segmentTime], @"time_duration",
                                      [NSNumber numberWithFloat:trackDeviation], @"deviation",
                                      nil];
            
            [collectableData addObject:tempDict];
        }
    }
    
    // --- 3. Sort and Select Top 'N' Tracks ---
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"time_duration" ascending:YES];
    NSArray *sortedData = [collectableData sortedArrayUsingDescriptors:
                           [NSArray arrayWithObject:sortDescriptor]];
    [sortDescriptor release];
    [collectableData release];
    
    NSUInteger tracksToReturn = MIN([sortedData count], (NSUInteger)count);
    NSArray *topNTracks = [sortedData subarrayWithRange:NSMakeRange(0, tracksToReturn)];

    // --- 4. Format Final Output Array ---
    
    NSMutableArray *finalArray = [[NSMutableArray alloc] initWithCapacity:tracksToReturn];
    
    for (NSDictionary *tempDict in topNTracks)
    {
        Track *t = [tempDict objectForKey:@"track"];
        int startIdx = [[tempDict objectForKey:@"start_index"] intValue];
        int endIdx = [[tempDict objectForKey:@"end_index"] intValue];
        
        // Retrieve the points array for start/end time access
        NSArray<TrackPoint*>* points = [t goodPoints];
        
        // Retrieve the specific TrackPoint objects
        // *** MODIFICATION: Use 'goodPoints' to retrieve the point objects ***
        TrackPoint *startPoint = [points objectAtIndex:startIdx];
        TrackPoint *endPoint = [points objectAtIndex:endIdx];
        
        // Build the final dictionary
        NSDictionary *resultDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                     t, @"track",
                                     [NSNumber numberWithInt:startIdx], @"start_index",
                                     [NSNumber numberWithInt:endIdx], @"end_index",
                                     
                                     // *** MODIFICATION: Use movingTime property ***
                                     [NSNumber numberWithDouble:startPoint.activeTimeDelta], @"start",
                                     [NSNumber numberWithDouble:endPoint.activeTimeDelta], @"end",
                                     
                                     [tempDict objectForKey:@"deviation"], @"deviation",
                                     nil];
        
        [finalArray addObject:resultDict];
    }

    [pool release];
    return [finalArray autorelease];
}

@end
