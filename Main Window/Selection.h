//
//  Selection.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface Selection : NSObject
{
@private
    Track   *_selectedTrack;
    NSArray *_selectedTracks; // immutable snapshot (NSArray<Track *> *)
}

// Current single selection (convenience)
@property(nonatomic, retain) Track *selectedTrack;

// Full selection (0..n). Stored as an immutable NSArray snapshot.
@property(nonatomic, retain) NSArray *selectedTracks;

// Helpers to keep both properties consistent
- (void)setSingleSelection:(Track *)track;      // sets selectedTracks = @[track] or @[]
- (void)setMultipleSelection:(NSArray *)tracks; // sets selectedTrack = first or nil

@end
