//
//  AscentDistanceFormatter.m
//  Ascent
//
//  Created by Rob Boyer on 2/6/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "AscentDistanceFormatter.h"
#import "Utils.h"
#import "Defs.h"

@implementation AscentDistanceFormatter

-(id) init
{
	if (self = [super init])
	{
		// does not seem to get called??
		[self setGroupingSize:3];
		[self setUsesGroupingSeparator:YES];
		NSString* units;
		if ([Utils usingStatute])
		{
			units = @"mi";
		}
		else
		{
			units = @"km";
		}
		[self setPositiveSuffix:units];
		[self setMaximumFractionDigits:0];
		[self setMinimumFractionDigits:0];
	}
	return self;
}



-(void) dealloc
{
    [super dealloc];
}

- (NSString *)stringForObjectValue:(id)anObject
{
#if TEST_LOCALIZATION
	[self setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
	[self setLocale:[NSLocale currentLocale]];
#endif
	NSString* units;
	if ([Utils usingStatute])
	{
		units = @"mi";
	}
	else
	{
		units = @"km";
	}
	[self setMaximumFractionDigits:0];
	[self setMinimumFractionDigits:0];
	[self setPositiveSuffix:units];
	return [super stringForObjectValue:anObject];
}

- (NSNumber*) getNumberFromString:(NSString*)string
{
	float dist = 0;
	NSScanner *theScanner = [NSScanner scannerWithString:string];
	if ([theScanner scanFloat:&dist] == YES)
	{
	}
	return  [NSNumber numberWithFloat:dist];
}



///- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string range:(inout nullable NSRange *)rangep error:(out NSError **)error;
{
    if (obj) {
        *obj = [self getNumberFromString:string];
        return YES;
    }
    NSLog(@"AscentDistanceFormatter getObjectValue is fucked");
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
