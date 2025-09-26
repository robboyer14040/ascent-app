//
//  Selection.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "Selection.h"
#import "Track.h"
#import "Lap.h"


@implementation Selection

@synthesize selectedTrack = _selectedTrack;
@synthesize selectedLap = _selectedLap;
@synthesize selectedTracks = _selectedTracks;

- (void)dealloc
{
    [_selectedTrack release];
    [_selectedLap release];
    [_selectedTracks release];
    [super dealloc];
}

#pragma mark - Public helpers

- (void)setSingleSelection:(Track *)track
{
    // Update array first so observers of both keys see a coherent state.
    NSArray *arr = (track != nil) ? [NSArray arrayWithObject:track] : [NSArray array];
    [self setSelectedTracks:arr];
    [self setSelectedTrack:track];
    [self setSelectedLap:nil];
}

- (void)setMultipleSelection:(NSArray *)tracks
{
    // Primary is the array; single selection mirrors first element (if any).
    [self setSelectedTracks:tracks];

    Track *first = nil;
    if ([tracks count] > 0) {
        id obj = [tracks objectAtIndex:0];
        if ([obj isKindOfClass:[Track class]]) {
            first = (Track *)obj;
        }
    }
    [self setSelectedTrack:first];
}

#pragma mark - Property setters (KVO-compliant, MRC semantics)

- (void)setSelectedTrack:(Track *)t
{
    if (_selectedTrack == t) {
        return;
    }
    [self willChangeValueForKey:@"selectedTrack"];
    [_selectedTrack release];
    _selectedTrack = [t retain];
    [self didChangeValueForKey:@"selectedTrack"];
}


- (void)setSelectedLap:(Lap *)l
{
    if (_selectedLap == l) {
        return;
    }
    [self willChangeValueForKey:@"selecteLap"];
    [_selectedLap release];
    _selectedLap = [l retain];
    [self didChangeValueForKey:@"selecteLap"];
}


- (void)setSelectedTracks:(NSArray *)arr
{
    if (_selectedTracks == arr) {
        return;
    }
    // Store an immutable snapshot; callers may pass mutable arrays.
    [self willChangeValueForKey:@"selectedTracks"];
    [_selectedTracks release];
    _selectedTracks = [arr copy]; // nil OK; copy yields immutable NSArray
    [self didChangeValueForKey:@"selectedTracks"];
}

@end
