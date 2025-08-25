//
//  WeightValueTransformer.m
//  Ascent
//
//  Created by Rob Boyer on 1/14/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "WeightValueTransformer.h"
#import "Utils.h"

@implementation WeightValueTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation
{
    return YES;
}


- (id)transformedValue:(id)value
{
    float statuteValue;
    float transformedValue;
	
    if (value == nil) return nil;
	
    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(floatValue)]) {
		// handles NSString and NSNumber
        statuteValue = [value floatValue];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -floatValue.",
		 [value class]];
    }
	
     transformedValue = [Utils usingStatute] ? statuteValue : PoundsToKilograms(statuteValue);
	
    return [NSNumber numberWithFloat:transformedValue];
}


- (id)reverseTransformedValue:(id)value
{
	float statuteValue;
    float transformedValue;
    if (value == nil) return nil;
	
    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(floatValue)]) {
		// handles NSString and NSNumber
        transformedValue = [value floatValue];
    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -floatValue.",
		 [value class]];
    }
	
 	statuteValue = [Utils usingStatute] ? transformedValue : KilogramsToPounds(transformedValue);
	
    return [NSNumber numberWithDouble: statuteValue];
}


@end
