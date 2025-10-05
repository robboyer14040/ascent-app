//
//  Selection.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;


@interface Selection : NSObject
{
@private
    Track   *_selectedTrack;
    Lap     *_selectedLap;
    NSArray *_selectedTracks; // immutable snapshot (NSArray<Track *> *)
}

// Current single selection (convenience)
@property(nonatomic, retain) Track *selectedTrack;
@property(nonatomic, retain) Lap *selectedLap;

// Full selection (0..n). Stored as an immutable NSArray snapshot.
@property(nonatomic, retain) NSArray *selectedTracks;

// Helpers to keep both properties consistent
- (void)setSingleSelection:(Track *)track;      // sets selectedTracks = @[track] or @[]
- (void)setMultipleSelection:(NSArray *)tracks; // sets selectedTrack = first or nil
- (void)startObservingChanges:(NSObject*)observer;
- (void)stopObservingChanges:(NSObject*)observer;

@end
