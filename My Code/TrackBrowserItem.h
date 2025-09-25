//
//  TrackBrowserItem.h
//  TLP
//
//  Created by Rob Boyer on 7/22/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"

@class Track;
@class Lap;
@class TrackBrowserItem;

enum tBrowserItemType
{
   kTypeNone,
   kTypeLap,
   kTypeActivity,
   kTypeWeek,
   kTypeMonth,
   kTypeYear
} ;


@interface TrackBrowserItem : NSObject 

@property (nonatomic, retain) NSMutableDictionary* children;
@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) Track* track;
@property (nonatomic, retain) Lap* lap;
@property (nonatomic, retain) NSDate* date;
@property (nonatomic, assign) TrackBrowserItem* parentItem;
@property (nonatomic, retain) NSArray* sortedChildKeys;
@property (nonatomic) int seqno;
@property (nonatomic) tBrowserItemType type;
@property (nonatomic) int sortedChildKeysSeqno;
@property (nonatomic) BOOL expanded;

-(id) initWithData:(Track *)t lap:(Lap*)l name:(NSString*)n date:(NSDate*)d type:(int)ty parent:(TrackBrowserItem*)parentItem;
-(BOOL) isRoot;
-(NSComparisonResult) compare:(TrackBrowserItem*)item;
-(NSComparisonResult) reverseCompare:(TrackBrowserItem*)item;
-(NSComparisonResult) compareString:(TrackBrowserItem*)item;
-(NSComparisonResult) reverseCompareString:(TrackBrowserItem*)item;
- (void) invalidateCache:(BOOL)recursively;

-(float) distance;
-(float) totalClimb;
-(float) totalDescent;
-(float) rateOfClimb;
-(float) rateOfDescent;
-(float) avgSpeed;
-(float) avgPace;
-(NSString*) avgPaceAsString;
-(float) maxSpeed;
-(float) avgMovingSpeed;
-(float) avgMovingPace;
-(NSString*) avgMovingPaceAsString;
-(float) durationAsFloat;
-(float) movingDurationAsFloat;
-(float) maxHeartRate;
-(float) avgHeartRate;
-(float) maxCadence;
-(float) avgCadence;
-(float) maxPower;
-(float) avgPower;
-(float) work;
-(float) maxGradient;
-(float) minGradient;
-(float) avgGradient;
-(float) maxAltitude;
-(float) minAltitude;
-(float) avgAltitude;
-(float) maxTemperature;
-(float) minTemperature;
-(float) avgTemperature;
- (float)timeInHRZone:(int)zne;
- (float)timeInNonHRZone:(int)type zone:(int)zne;
- (float)calories;
-(NSString*) timeInHRZ1AsString;
-(NSString*) timeInHRZ2AsString;
-(NSString*) timeInHRZ3AsString;
-(NSString*) timeInHRZ4AsString;
-(NSString*) timeInHRZ5AsString;
-(float) timeInHRZ1AsFloat;
-(float) timeInHRZ2AsFloat;
-(float) timeInHRZ3AsFloat;
-(float) timeInHRZ4AsFloat;
-(float) timeInHRZ5AsFloat;
-(float) timeInALTZ1AsFloat;
-(float) timeInALTZ2AsFloat;
-(float) timeInALTZ3AsFloat;
-(float) timeInALTZ4AsFloat;
-(float) timeInALTZ5AsFloat;
-(float) timeInCDZ1AsFloat;
-(float) timeInCDZ2AsFloat;
-(float) timeInCDZ3AsFloat;
-(float) timeInCDZ4AsFloat;
-(float) timeInCDZ5AsFloat;
-(float) timeInGDZ1AsFloat;
-(float) timeInGDZ2AsFloat;
-(float) timeInGDZ3AsFloat;
-(float) timeInGDZ4AsFloat;
-(float) timeInGDZ5AsFloat;
-(float) timeInPCZ1AsFloat;
-(float) timeInPCZ2AsFloat;
-(float) timeInPCZ3AsFloat;
-(float) timeInPCZ4AsFloat;
-(float) timeInPCZ5AsFloat;
-(float) timeInSPZ1AsFloat;
-(float) timeInSPZ2AsFloat;
-(float) timeInSPZ3AsFloat;
-(float) timeInSPZ4AsFloat;
-(float) timeInSPZ5AsFloat;
-(NSString*) timeInAltitudeZ1AsString;
-(NSString*) timeInAltitudeZ2AsString;
-(NSString*) timeInAltitudeZ3AsString;
-(NSString*) timeInAltitudeZ4AsString;
-(NSString*) timeInAltitudeZ5AsString;
-(NSString*) timeInCadenceZ1AsString;
-(NSString*) timeInCadenceZ2AsString;
-(NSString*) timeInCadenceZ3AsString;
-(NSString*) timeInCadenceZ4AsString;
-(NSString*) timeInCadenceZ5AsString;
-(NSString*) timeInGradientZ1AsString;
-(NSString*) timeInGradientZ2AsString;
-(NSString*) timeInGradientZ3AsString;
-(NSString*) timeInGradientZ4AsString;
-(NSString*) timeInGradientZ5AsString;
-(NSString*) timeInSpeedZ1AsString;
-(NSString*) timeInSpeedZ2AsString;
-(NSString*) timeInSpeedZ3AsString;
-(NSString*) timeInSpeedZ4AsString;
-(NSString*) timeInSpeedZ5AsString;
-(NSString*) timeInPaceZ1AsString;
-(NSString*) timeInPaceZ2AsString;
-(NSString*) timeInPaceZ3AsString;
-(NSString*) timeInPaceZ4AsString;
-(NSString*) timeInPaceZ5AsString;
-(NSString*) durationAsString;
-(NSString*) movingTimeAsString;
-(NSTimeInterval) duration;
-(NSString*) keyword1;
-(NSString*) keyword2;
-(NSString*) custom;
-(NSString*) title;
-(NSString*) notes;
-(NSString*) device;
-(NSString*) firmwareVersion;
-(NSString*) location;
-(NSString*) computer;

- (NSString*) activity;
- (NSString*) equipment;
- (float) weight;
- (NSString*) effort;
- (NSString*) disposition;
- (NSString*) weather;
- (NSString*) eventType;


@end
