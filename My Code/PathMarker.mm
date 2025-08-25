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
   soundPath = @"";
   distance = d;
   flags = 0;
   return self;
}

-(id) init
{
   return [self initWithData:@""
                   imagePath:@""
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
	[coder encodeObject:name];
	[coder encodeObject:imagePath];
	[coder encodeObject:soundPath];
	[coder encodeObject:@""];     // spare string
	[coder encodeObject:@""];     // spare string
	[coder encodeValueOfObjCType:@encode(float) at:&distance];

	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
	[coder encodeValueOfObjCType:@encode(int) at:&spareInt];
}


- (void)dealloc
{
    [name release];
    [imagePath release];
    [super dealloc];
}


- (id)mutableCopyWithZone:(NSZone *)zone
{
	PathMarker* newMarker = [[PathMarker allocWithZone:zone] init];
	[newMarker setName:[name copy]];
	[newMarker setDistance:distance];
	[newMarker setImagePath:[imagePath copy]];
	// @@FIXME@@ sound path?
	return newMarker;
}


-(NSString*) name
{
   return name;
}



-(void) setName:(NSString*)n
{
   if (n != name)
   {
      name = [n retain];
   }
}



-(NSString*) soundPath
{
   return soundPath;
}



-(void) setSoundPath:(NSString *)n
{
   if (n != soundPath)
   {
       soundPath = [n retain];
   }
}



-(NSString*) imagePath
{
   return imagePath;
}


-(void) setImagePath:(NSString*)ip
{
   if (ip != imagePath)
   {
      imagePath = [ip retain];
   }
}



-(float) distance
{
   return distance;
}


-(void) setDistance:(float)d
{
   distance = d;
}


- (BOOL)isEqual:(id)anObject
{
   BOOL eq = (distance == [anObject distance]) &&
      ([name compare:[anObject name]] == NSOrderedSame) &&
      ([imagePath compare:[anObject imagePath]] == NSOrderedSame);
   
   return eq;
}

- (NSComparisonResult)compare:(PathMarker *)pm
{
   return (distance < [pm distance]) ? NSOrderedAscending : NSOrderedDescending;
}



@end
