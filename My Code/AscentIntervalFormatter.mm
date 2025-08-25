//
//  AscentIntervalFormatter.mm
//  Ascent
//
//  Created by Rob Boyer on 2/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "AscentIntervalFormatter.h"


@implementation AscentIntervalFormatter



-(id) initAsPace:(BOOL)usePace
{
   self = [super init];
   usePaceFormat = usePace;
   NSMutableParagraphStyle* paraStyle = [[NSMutableParagraphStyle alloc] init];
   [paraStyle setAlignment:NSTextAlignmentRight];
   attrs = [NSMutableDictionary dictionaryWithCapacity:1];
   [attrs setObject:paraStyle forKey:NSParagraphStyleAttributeName];
   [paraStyle autorelease];
   return self;
}

-(id) init
{
   return [self initAsPace:NO];
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
   int secs = (int)v % 60;
   if (usePaceFormat)
   {
      //NSLog(@"val:%0.1f mins:%d secs:%d", v, mins, secs);
	   return  [NSString stringWithFormat:@"%s%02d:%02d", isNeg ? "-" : "", mins, secs];
   }
   else
   {
      int hours = (int)v/3600;
      return  [NSString stringWithFormat:@"%s%02d:%02d:%02d", isNeg ? "-" : "", hours, mins, secs];
   }
}


- (NSAttributedString*)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
   ///return [[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject]
	///									   attributes:attrs];
    return [[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject]
                                            attributes:attributes];
}


- (NSNumber*) getNumberFromString:(NSString*)string
{
   int hours = 0;
   int mins = 0;
   int secs = 0;
   int temp;
   BOOL goon = YES;
   NSScanner *theScanner = [NSScanner scannerWithString:string];
   if (!usePaceFormat)
   {
      if ([theScanner scanInt:&hours] == YES)
      {
         goon = [theScanner scanString:@":" intoString:nil];
      }
   }
   if (goon)
   {
      if ([theScanner scanInt:&temp] == YES)
      {
         mins = temp;
         if ([theScanner scanString:@":" intoString:nil] == YES)
         {
            if ([theScanner scanInt:&temp] == YES)
            {
               secs = temp;
            }
         }
      }
   }
   float v = (hours*3600.0)+(mins*60.0)+secs;
   //NSLog(@"s:%@ hours:%d, mins:%d secs:%d ==> %0.1f", string, hours, mins, secs, v);
   return  [NSNumber numberWithFloat:v];
}


///-(BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string range:(inout nullable NSRange *)rangep error:(out NSError **)error;
{
    if (obj) {
        *obj = [self getNumberFromString:string];
        return YES;
    }
    NSLog(@"AscentIntervalFormatter getObjectValue is fucked");
    return NO;
}

-(NSNumber *)numberFromString:(NSString *)string
{
   return [self getNumberFromString:string];
}


-(NSString *)stringFromNumber:(NSNumber *)number
{
   return [self stringForObjectValue:number];
}

@end
