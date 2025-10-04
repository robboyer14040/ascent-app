//
//  IndexTagMap.h
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface IndexTagMap : NSObject

// Number of pairs currently stored.
@property (nonatomic, readonly) NSUInteger count;

// Designated inits
- (instancetype)init;
- (instancetype)initWithCapacity:(NSUInteger)capacity;

// Set or replace the mapping (enforces 1:1).
- (void)setTag:(NSInteger)tag forIndex:(NSUInteger)index;

// Lookups (return NSNotFound if missing)
- (NSInteger)tagForIndex:(NSUInteger)index;
- (NSInteger)indexForTag:(NSInteger)tag;

// Removals
- (BOOL)removeIndex:(NSUInteger)index;
- (BOOL)removeTag:(NSInteger)tag;

- (void)removeAll;

@end
