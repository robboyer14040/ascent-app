//
//  OverrideData.h
//  Ascent
//
//  Created by Rob Boyer on 8/20/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import <Cocoa/Cocoa.h>

enum
{
    kNumValsPerOverrideEntry    = 3,
};



@interface OverrideData : NSObject <NSMutableCopying>
{
	int			    numStats;
	int			    overrideBits;		// if bit is set, then value is overridden
	struct tORData*	data;
}

-(id) mutableCopyWithZone:(NSZone *)zone;
-(void) setValue:(int)stat index:(int)idx value:(float)v;
-(float) value:(int)data index:(int)idx;
-(void) clearOverride:(int)stat;
-(BOOL) isOverridden:(int)stat;

@end

