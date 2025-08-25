//
//  StringAdditions.mm
//  Ascent
//
//  Created by Rob Boyer on 12/5/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "StringAdditions.h"


@implementation NSString(uuid)

+ (NSString *)uniqueString
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return (NSString *)uuidStr;
}

@end
