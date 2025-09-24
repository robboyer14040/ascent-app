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
   self.colInfoDict = [NSMutableDictionary dictionaryWithCapacity:40];
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

- (void)dealloc
{
    [_colInfoDict release];
    [_splitsColInfoDict release];
    [super dealloc];
}


@end
