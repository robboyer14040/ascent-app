//
//  ColumnInfo.h
//  Ascent
//
//  Created by Rob Boyer on 2/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct _colInfo
{
	const char* columnLabel;      // what the user sees at the top of the column
	const char* menuLabel;        // what the user sees in the popup menu
	const char* ident;            // identifier set in IB
	const char* format;
	int         tag;              // menu tag in column popup
	int         width;            // default col width
	int			unitType;			// see enum below
	int         flags;
} tColInfo;

enum
{
	kCantRemove					= 0x00000001,
	kDefaultField				= 0x00000002,
	kUseStringComparator		= 0x00000004,
	kLeftAlignment				= 0x00000008,
	kNotAValidSplitGraphItem	= 0x00000010,		// split-related columns only
	KIsDeltaValue				= 0x00000020,		// split-related columns only
	kUseNumberFormatter			= 0x00001000,
	kUseIntervalFormatter		= 0x00010000,		// implies it's a time field
	kUsePaceFormatter			= 0x00100000,
};


enum
{
	kUT_IsHeartRate = 0,
	kUT_IsTime, 
	kUT_IsCadence,
	kUT_IsGradient,
	kUT_IsCalories,
	kUT_IsClimb,
	kUT_IsSpeed,
	kUT_IsPace,
	kUT_IsDistance,		
	kUT_IsVAM,
	kUT_IsWeight,
	kUT_IsTemperature,
	kUT_IsPower,
	kUT_IsWork,
	kUT_IsText,
    kUT_IsJustANumber,
};


enum
{
   kNotInBrowser = -1
};



@interface StaticColumnInfo : NSObject
{
}
- (int) numPossibleColumns;
- (tColInfo*) nthPossibleColumnInfo:(int)nth;
@end

@interface MainBrowserStaticColumnInfo : StaticColumnInfo
{
}
- (int) numPossibleColumns;
- (tColInfo*) nthPossibleColumnInfo:(int)nth;
@end

@interface SplitsTableStaticColumnInfo : StaticColumnInfo
{
}
- (int) numPossibleColumns;
- (tColInfo*) nthPossibleColumnInfo:(int)nth;
@end



@interface ColumnInfo : NSObject <NSCopying, NSMutableCopying>
{
    NSString*      title;
    NSFormatter*   formatter;
    tColInfo*      colInfo;
    float          width;
    int            order;
}


- (NSString*)getLegend;

- (ColumnInfo*) initWithInfo:(tColInfo*)colInfo;

- (id)mutableCopyWithZone:(NSZone *)zone;

- (NSString *)menuLabel;
- (NSString *)columnLabel;

- (NSString *)title;
- (void)setTitle:(NSString *)value;

- (NSFormatter *)formatter;
- (void)setFormatter:(NSFormatter *)value;

- (float)width;
- (void)setWidth:(float)value;

- (int)order;
- (void)setOrder:(int)value;

- (int) flags;

- (int) tag;

- (NSString*)ident;

- (NSComparisonResult)compare:(ColumnInfo *)ci;

- (tColInfo*) colInfo;

@property (nonatomic, copy) NSString *menuName;
- (NSComparisonResult)compareUsingMenuName:(ColumnInfo *)other;

@end

