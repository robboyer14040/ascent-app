//
//  OverrideData.m
//  Ascent
//
//  Created by Rob Boyer on 8/20/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


// OverrideData is a utility class that provides a mechanism to override individual data items (or
// enter them manually if no trackpoints are present).  Data to store the override values is only 
// allocated if one more 'statistic' items have been overriden

#import "OverrideData.h"
#import "Defs.h"
#import "StatDefs.h"

// indices used in the 'vals' array of tORData struct...

struct tORData
{
    float vals[kNumValsPerOverrideEntry];        // usually max, min, avg
};



@implementation OverrideData

- (id)init
{
	self = [super init];
	numStats = 0;
	data = 0;
	overrideBits = 0;
	return self;
}

#define OVERRIDE_DATA_CUR_VERSION  0
- (id)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	numStats = 0;
	data = 0;
	overrideBits = 0;
	int version;
	[coder decodeValueOfObjCType:@encode(int) at:&numStats];		
	[coder decodeValueOfObjCType:@encode(int) at:&overrideBits];			
	[coder decodeValueOfObjCType:@encode(int) at:&version];					
	if (version > OVERRIDE_DATA_CUR_VERSION)
	{
		NSException *e = [NSException exceptionWithName:ExFutureVersionName
												 reason:ExFutureVersionReason
											   userInfo:nil];			  
		@throw e;
	}
	// CODE HERE ASSUMES that we always add new stats, never remove old ones!!
	//if (IS_BETWEEN(1, numStats, kST_NumStats))
	{
		data = (struct tORData*)calloc(kST_NumStats, sizeof(struct tORData));
		for (int i=0; i<numStats; i++)
		{
			for (int j=0; j<kNumValsPerOverrideEntry; j++)
			{
				float v = 0.0;
				[coder decodeValueOfObjCType:@encode(float) 
										  at:&v];
				if (i < kST_NumStats) data[i].vals[j] = v;
			}
		}
		if (numStats > kST_NumStats) numStats = kST_NumStats;
	}
	//else
	//{
		// CORRUPT FILE!! post message to the user
	//}
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
	int version = OVERRIDE_DATA_CUR_VERSION;
	if (data) numStats = kST_NumStats;
	[coder encodeValueOfObjCType:@encode(int) at:&numStats];		
	[coder encodeValueOfObjCType:@encode(int) at:&overrideBits];
	[coder encodeValueOfObjCType:@encode(int) at:&version];		
	if (data)
	{
		for (int i=0; i<kST_NumStats; i++)
		{
			for (int j=0; j<kNumValsPerOverrideEntry; j++)
			{
				[coder encodeValueOfObjCType:@encode(float) at:&data[i].vals[j]];
			}
		}
	}
}

-(void) dealloc
{
	free(data);
    [super dealloc];
}


- (id)mutableCopyWithZone:(NSZone *)zone
{
	OverrideData* newOD = [[OverrideData allocWithZone:zone] init];
	newOD->numStats = numStats;
	if (data)
	{
		newOD->data = (struct tORData*) malloc(sizeof(struct tORData)*numStats);
		memcpy(newOD->data, data, (sizeof(struct tORData)*numStats));
	}
	else
	{
		newOD->data = 0;
	}
	newOD->overrideBits = overrideBits;
	return newOD;
}


-(void) setValue:(int)stat index:(int)idx value:(float)v
{
	if (numStats <= 0)
	{
		numStats = kST_NumStats;
		data = (struct tORData*)calloc(kST_NumStats, sizeof(struct tORData));
	}
	if (idx < kST_NumStats) 
	{
		assert(stat < kST_NumStats);		
		assert(idx < kNumValsPerOverrideEntry);		
		data[stat].vals[idx] = v;
		assert(stat < (sizeof(int)*8));		// can only override up to 31 fields!
		SET_FLAG(overrideBits, (1<<stat));
	}
}


-(BOOL) isOverridden:(int)stat
{
	assert(stat < (sizeof(int)*8));		// can only override up to 31 fields!
	return FLAG_IS_SET(overrideBits, (1<<stat));
}


-(void) clearOverride:(int)stat
{
	assert(stat < (sizeof(int)*8));		// can only override up to 31 fields!
	CLEAR_FLAG(overrideBits, (1<<stat));
}


-(float) value:(int)stat index:(int)idx
{
	float val = 0.0;
	if (data)
	{
		assert(stat < kST_NumStats);		
		assert(idx < kNumValsPerOverrideEntry);		
		val = data[stat].vals[idx];
	}
	return val;
}
	
@end


