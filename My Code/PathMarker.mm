//
//  PathMarker.mm
//  Ascent
//
//  Created by Rob Boyer on 11/11/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "PathMarker.h"
#import "Defs.h"

@implementation PathMarker


-(id) initWithData:(NSString*)n imagePath:(NSString*)ip distance:(float)d
{
   self = [super init];
   [self setName:n];
   [self setImagePath:ip];
   _soundPath = nil;
   _distance = d;
    return self;
}


-(id) init
{
   return [self initWithData:nil
                   imagePath:nil
                    distance:0.0];
}


#define CUR_VERSION 1

- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE
	printf("decoding PathMarker\n");
#endif
	self = [super init];
	float fval;
	int ival;
	int version;

	[coder decodeValueOfObjCType:@encode(int) at:&version];
	if (version > CUR_VERSION)
	{
	  NSException *e = [NSException exceptionWithName:ExFutureVersionName
											   reason:ExFutureVersionReason
											 userInfo:nil];			  
	  @throw e;
	}

	[self setName:[coder decodeObject]];
	[self setImagePath:[coder decodeObject]];
	NSString* spareString = [coder decodeObject];
	spareString = [coder decodeObject];
	spareString = [coder decodeObject];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];
	[self setDistance:fval];

	[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
	[coder decodeValueOfObjCType:@encode(float) at:&fval];      // spare
	[coder decodeValueOfObjCType:@encode(int) at:&ival];        // spare
	[coder decodeValueOfObjCType:@encode(int) at:&ival];        // spare
	return self;
}   


- (void)encodeWithCoder:(NSCoder *)coder
{
	int version = CUR_VERSION;
	float spareFloat = 0.0f;
	int spareInt = 0;
	[coder encodeValueOfObjCType:@encode(int) at:&version];
	[coder encodeObject:_name];
	[coder encodeObject:_imagePath];
	[coder encodeObject:_soundPath];
	[coder encodeObject:@""];     // spare string
	[coder encodeObject:@""];     // spare string
	[coder encodeValueOfObjCType:@encode(float) at:&_distance];

	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
}


- (void)dealloc
{
    [_name release];
    [_imagePath release];
    [_soundPath release];
    [super dealloc];
}


- (id)mutableCopyWithZone:(NSZone *)zone
{
	PathMarker* newMarker = [[PathMarker allocWithZone:zone] init];
    newMarker.name = _name;
	newMarker.distance = _distance;
    newMarker.imagePath = _imagePath;
    newMarker.soundPath = _soundPath;
	return newMarker;
}


- (BOOL)isEqual:(id)anObject
{
   BOOL eq = (_distance == [anObject distance]) &&
      ([_name compare:[anObject name]] == NSOrderedSame) &&
      ([_imagePath compare:[anObject imagePath]] == NSOrderedSame);
   
   return eq;
}


- (NSComparisonResult)compare:(PathMarker *)pm
{
   return (_distance < [pm distance]) ? NSOrderedAscending : NSOrderedDescending;
}


@end
