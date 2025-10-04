//
//  IndexTagMap.m
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


#import "IndexTagMap.h"

@implementation IndexTagMap {
    // index -> tag
    NSMutableDictionary *_indexToTag;  // key: NSNumber(index), value: NSNumber(tag)
    // tag -> index
    NSMutableDictionary *_tagToIndex;  // key: NSNumber(tag),   value: NSNumber(index)
}

static inline NSNumber *NumIndex(NSUInteger i)   { return [NSNumber numberWithUnsignedLong:i]; }
static inline NSNumber *NumTag(NSInteger t)      { return [NSNumber numberWithLong:t]; }

- (instancetype)init {
    self = [super init];
    if (self) {
        _indexToTag = [[NSMutableDictionary alloc] init];
        _tagToIndex = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self) {
        _indexToTag = [[NSMutableDictionary alloc] initWithCapacity:capacity];
        _tagToIndex = [[NSMutableDictionary alloc] initWithCapacity:capacity];
    }
    return self;
}

- (void)dealloc {
    [_indexToTag release];
    [_tagToIndex release];
    [super dealloc];
}

- (NSUInteger)count {
    return [_indexToTag count];
}

- (void)setTag:(NSInteger)tag forIndex:(NSUInteger)index {
    NSNumber *kIndex = NumIndex(index);
    NSNumber *vTag   = NumTag(tag);

    // If index already had a tag, remove reverse mapping
    NSNumber *oldTag = [_indexToTag objectForKey:kIndex];
    if (oldTag && ![oldTag isEqualToNumber:vTag]) {
        [_tagToIndex removeObjectForKey:oldTag];
    }

    // If tag was already bound to a different index, remove that forward mapping
    NSNumber *oldIndex = [_tagToIndex objectForKey:vTag];
    if (oldIndex && ![oldIndex isEqualToNumber:kIndex]) {
        [_indexToTag removeObjectForKey:oldIndex];
    }

    // Set both directions
    [_indexToTag setObject:vTag forKey:kIndex];
    [_tagToIndex setObject:kIndex forKey:vTag];
}

- (NSInteger)tagForIndex:(NSUInteger)index {
    NSNumber *kIndex = NumIndex(index);
    NSNumber *vTag = [_indexToTag objectForKey:kIndex];
    return vTag ? [vTag integerValue] : NSNotFound;
}

- (NSInteger)indexForTag:(NSInteger)tag {
    NSNumber *kTag = NumTag(tag);
    NSNumber *vIndex = [_tagToIndex objectForKey:kTag];
    return vIndex ? (NSInteger)[vIndex unsignedLongValue] : NSNotFound;
}

- (BOOL)removeIndex:(NSUInteger)index {
    NSNumber *kIndex = NumIndex(index);
    NSNumber *vTag = [[_indexToTag objectForKey:kIndex] retain];
    if (!vTag) {
        return NO;
    }
    [_indexToTag removeObjectForKey:kIndex];
    [_tagToIndex removeObjectForKey:vTag];
    [vTag release];
    return YES;
}

- (BOOL)removeTag:(NSInteger)tag {
    NSNumber *kTag = NumTag(tag);
    NSNumber *vIndex = [[_tagToIndex objectForKey:kTag] retain];
    if (!vIndex) {
        return NO;
    }
    [_tagToIndex removeObjectForKey:kTag];
    [_indexToTag removeObjectForKey:vIndex];
    [vIndex release];
    return YES;
}

- (void)removeAll {
    [_indexToTag removeAllObjects];
    [_tagToIndex removeAllObjects];
}

@end
