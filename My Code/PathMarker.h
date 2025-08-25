//
//  PathMarker.h
//  Ascent
//
//  Created by Rob Boyer on 11/11/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PathMarker : NSObject  <NSCoding, NSMutableCopying> 
{
   NSString*   name;
   NSString*   imagePath;
   NSString*   soundPath;
   float       distance;
   int         flags;
}

-(id) initWithData:(NSString*)n imagePath:(NSString*)ip distance:(float)d;
- (id)mutableCopyWithZone:(NSZone *)zone;

-(NSString*) soundPath;
-(void) setSoundPath:(NSString*)n;

-(NSString*) name;
-(void) setName:(NSString*)n;

-(NSString*) imagePath;
-(void) setImagePath:(NSString*)ip;

-(float) distance;
-(void) setDistance:(float)d;

- (BOOL)isEqual:(id)anObject;

- (NSComparisonResult)compare:(PathMarker *)ci;

@end
