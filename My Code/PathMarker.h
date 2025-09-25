//
//  PathMarker.h
//  Ascent
//
//  Created by Rob Boyer on 11/11/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PathMarker : NSObject  <NSCoding, NSMutableCopying> 

@property(nonatomic, retain) NSString* name;
@property(nonatomic, retain) NSString* imagePath;
@property(nonatomic, retain) NSString* soundPath;
@property(nonatomic) float distance;

- (id) initWithData:(NSString*)n imagePath:(NSString*)ip distance:(float)d;
- (id)mutableCopyWithZone:(NSZone *)zone;
- (BOOL)isEqual:(id)anObject;

- (NSComparisonResult)compare:(PathMarker *)ci;

@end
