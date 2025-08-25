//
//   BrowserInfo.mm
//  Ascent
//
//  Created by Rob Boyer on 2/19/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "BrowserInfo.h"


static BrowserInfo *        sSingleton = nil;

@implementation BrowserInfo

- (id) initPrivate
{
   colInfoDict = [NSMutableDictionary dictionaryWithCapacity:40];
   return self;
}

+ (void) initialize
{
   if (! sSingleton)
      sSingleton = [[BrowserInfo alloc] initPrivate];
}

+ (BrowserInfo*) sharedInstance
{
   return sSingleton;
}


- (id) init
{
   //NSAssert(self != sSingleton, @"Should never send init to the singleton instance");
   
   return sSingleton;
}


- (NSMutableDictionary *)colInfoDict 
{
   return colInfoDict;
}


- (void)setColInfoDict:(NSMutableDictionary *)value 
{
   if (colInfoDict != value) 
   {
      colInfoDict = [value mutableCopy];
   }
}


- (NSMutableDictionary *)splitsColInfoDict 
{
   return splitsColInfoDict;
}


- (void)setSplitsColInfoDict:(NSMutableDictionary *)value 
{
   if (splitsColInfoDict != value) 
   {
      splitsColInfoDict = [value mutableCopy];
   }
}

@end
