//
//  AscentLongIntervalFormatter.m
//  Ascent
//
//  Created by Rob Boyer on 12/22/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "AscentLongIntervalFormatter.h"


@implementation AscentLongIntervalFormatter


-(id) init
{
	if (self = [super init])
	{
	}
	return self;
}



-(void) dealloc
{
    [super dealloc];
}


- (NSString *)stringForObjectValue:(id)anObject
{
	float v = [anObject floatValue];
	BOOL isNeg = v < 0.0;
	if (isNeg) v *= -1.0;
	int mins = (int)(v/60.0) % 60;
	//int secs = (int)v % 60;
	int hours = (int)v/3600;
	return  [NSString stringWithFormat:@"%01d hrs", (mins >= 30.0) ? hours + 1 : hours];
}


- (NSNumber*) getNumberFromString:(NSString*)string
{
	int hours = 0;
	//int mins = 0;
	//int temp;
	//BOOL goon = YES;
	NSScanner *theScanner = [NSScanner scannerWithString:string];
	if ([theScanner scanInt:&hours] == YES)
	{
	}
	float v = (hours*3600.0);
	return  [NSNumber numberWithFloat:v];
}



- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string range:(inout nullable NSRange *)rangep error:(out NSError **)error;
{
    if (obj) {
        *obj = [self getNumberFromString:string];
        return YES;
    }
    NSLog(@"AscentLongIntervalFormatter getObjectValue is fucked");
    return NO;
}


- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
	NSMutableAttributedString* attrStr = [[NSMutableAttributedString alloc] initWithString:[self stringForObjectValue:anObject]
																				 attributes:nil];
	NSMutableParagraphStyle *mutParaStyle=[[NSMutableParagraphStyle alloc] init];
	[mutParaStyle setAlignment:NSTextAlignmentRight];
	[attrStr addAttributes:[NSDictionary dictionaryWithObject:mutParaStyle 
													   forKey:NSParagraphStyleAttributeName] 
					 range:NSMakeRange(0,[attrStr length])];
	return attrStr;
}


@end
