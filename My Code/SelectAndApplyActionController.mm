//
//  SelectAndApplyActionController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SelectAndApplyActionController.h"
#import "Defs.h"
#import "Track.h"
#import "TrackPoint.h"
#import "Utils.h"
#import "AscentIntervalFormatter.h"


//---- TopDataPointFilterItem --------------------------------------------------

@interface TopDataPointFilterItem : NSObject
{
	NSString*				name;
	NSString*				dictKey;
	SEL						getSelector;
	SEL						setSelector;
	NSMutableDictionary*	selItems;
	NSMutableDictionary*	actItems;
	int						lastSelItemIdx;
	int						lastActItemIdx;
	int						flags;
}
-(TopDataPointFilterItem*)initWithName:(NSString*)nm dictKey:(NSString*)dk getSelector:(SEL)gs setSelector:(SEL)ss 
							  selItems:(NSMutableDictionary*)si actItems:(NSMutableDictionary*)ai flags:(int)fl;
-(NSString*)name;
-(NSString*)dictKey;
-(NSMutableDictionary*)selItems;
-(NSMutableDictionary*)actItems;
-(SEL)getSelector;
-(SEL)setSelector;
-(int)flags;
-(NSComparisonResult) compare:(TopDataPointFilterItem*)item;
@end


@implementation TopDataPointFilterItem 

-(TopDataPointFilterItem*)initWithName:(NSString*)nm dictKey:(NSString*)dk getSelector:(SEL)gs setSelector:(SEL)ss 
							  selItems:(NSMutableDictionary*)si actItems:(NSMutableDictionary*)ai flags:(int)fl
{
	self = [super init];
	name = nm;
	dictKey = dk;
	getSelector = gs;
	setSelector = ss;
	selItems = si;
	actItems = ai;
	lastSelItemIdx = lastActItemIdx = 0;
	flags = fl;
	return self;
}

-(void)dealloc
{
}

-(NSString*)name
{
	return name;
}


-(NSComparisonResult) compare:(TopDataPointFilterItem*)item
{
	return [name compare:[item name]];
}


-(NSString*)dictKey
{
	return dictKey;
}

-(NSMutableDictionary*)selItems
{
	return selItems;
}


-(NSMutableDictionary*)actItems
{
	return actItems;
}


-(int)lastSelItemIdx
{
	return lastSelItemIdx;
}

-(void)setLastSelItemIdx:(int)idx
{
	lastSelItemIdx = idx;
}

-(int)lastActItemIdx
{
	return lastActItemIdx;
}

-(void)setLastActItemIdx:(int)idx
{
	lastActItemIdx = idx;
}

-(SEL)getSelector
{
	return getSelector;
}

-(SEL)setSelector
{
	return setSelector;
}

-(int)flags
{
	return flags;
}

@end


//---- Item --------------------------------------------------------------------

@interface DataPointFilterItem : NSObject
{
	NSString*	name;
	NSString*	dictKey;
	NSArray*	choiceItems;		// if nil, then the next column is either a value or not there
									// if not nil, then assumed to be an array of Items
	SEL			filterOrActionSelector;
	float		lastValue;
	int			flags;
	int			lastChoiceIdx;
}
-(DataPointFilterItem*)initWithName:(NSString*)nm dictKey:(NSString*)dk filter:(SEL)fs choiceItems:(NSArray*)ci flags:(int)flgs;
-(NSString*)name;
-(NSString*)dictKey;
-(NSArray*)choiceItems;
-(int)flags;
-(NSComparisonResult) compare:(DataPointFilterItem*)item;

@end


@implementation DataPointFilterItem 

-(DataPointFilterItem*)initWithName:(NSString*)nm  dictKey:(NSString*)dk filter:(SEL)fs choiceItems:(NSArray*)ci flags:(int)flgs
{
	self = [super init];
	name = nm;
	dictKey = dk;
	choiceItems = ci;
	filterOrActionSelector = fs;
	lastChoiceIdx = 0;
	lastValue = 0.0;
	flags = flgs;
	return self;
}

-(void)dealloc
{
}

-(NSString*)name
{
	return name;
}


-(NSComparisonResult) compare:(DataPointFilterItem*)item
{
	return [name compare:[item name]];
}

-(NSString*)dictKey
{
	return dictKey;
}

-(NSArray*)choiceItems
{
	return choiceItems;
}

-(int)flags
{
	return flags;
}

-(int)lastChoiceIdx
{
	return lastChoiceIdx;
}

-(void)setLastChoiceIdx:(int)idx
{
	lastChoiceIdx = idx;
}

-(float)lastValue
{
	return lastValue;
}

-(void)setLastValue:(float)v
{
	lastValue = v;
}

-(SEL)filterOrActionSelector
{
	return filterOrActionSelector;
}

@end



//---- SelectAndApplyActionController implementation  --------------------------

@implementation SelectAndApplyActionController

-(NSMutableArray*)copyPoints:(NSArray*)pts
{
	int num = [pts count];
	NSMutableArray* outArr = [NSMutableArray arrayWithCapacity:num];
	for (int i=0; i<num; i++)
	{
		TrackPoint* np = [[pts objectAtIndex:i] mutableCopyWithZone:nil];
		[outArr addObject:np];
	}
	return outArr;
}
	

// key componets for accessing last values for selection/action components
// example keys: HR-GT-V1, HR-SetTo-V1, HR-GTMXHR, HR-RANGE-V1, HR-RANGE-V2

//static NSString* sDK_LastItem		= @"LASTITEM";	// hr, or speed, or altitude, etc (index in topItems)

static NSString* sDK_HeartRate		= @"HR";
static NSString* sDK_Speed			= @"SPD";
static NSString* sDK_Altitude		= @"ALT";
static NSString* sDK_Cadence		= @"CAD";
static NSString* sDK_Temperature	= @"TEMP";
static NSString* sDK_Power			= @"POW";

static NSString*  sDK_LastFilt		= @"LASTFILT";
static NSString*  sDK_LastAct		= @"LASTACT";

static NSString*  sDK_FiltGT		= @"GT";
static NSString*  sDK_FiltLT		= @"LT";
//static NSString*  sDK_FiltEQ		= @"EQ";
static NSString*  sDK_FiltGTMaxHR	= @"GTMXHR";
//static NSString*  sDK_FiltLTMinHR	= @"LTMNHR";
//static NSString* sDK_FiltRange	= @"RANGE";

static NSString*  sDK_ActSetPrev	= @"SetPrev";
static NSString*  sDK_ActSetTo		= @"SetTo";
static NSString*  sDK_ActInterp		= @"Interp";

static NSString*  sDK_Val1			= @"V1";
//static NSString*  sDK_Val2		= @"V2";

 -(void)buildDefaultsDict
{
	defaultsDict = [NSMutableDictionary dictionaryWithCapacity:16];
	NSString* key = [NSString stringWithFormat:@"%@-%@", sDK_HeartRate, sDK_LastFilt];
	[defaultsDict setObject:sDK_FiltGT
					 forKey:key];
	[defaultsDict setObject:sDK_ActSetTo
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_HeartRate, sDK_LastAct]];
	[defaultsDict setObject:[NSNumber numberWithFloat:200.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_HeartRate, sDK_FiltGT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:50.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_HeartRate, sDK_FiltLT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:100.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_HeartRate, sDK_ActSetTo, sDK_Val1]];
	
	
	[defaultsDict setObject:sDK_FiltGT
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Speed, sDK_LastFilt]];
	[defaultsDict setObject:sDK_ActSetTo
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Speed, sDK_LastAct]];
	[defaultsDict setObject:[NSNumber numberWithFloat:40.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Speed, sDK_FiltGT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:0.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Speed, sDK_ActSetTo, sDK_Val1]];

	
	[defaultsDict setObject:sDK_FiltGT
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Altitude, sDK_LastFilt]];
	[defaultsDict setObject:sDK_ActSetTo
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Altitude, sDK_LastAct]];
	[defaultsDict setObject:[NSNumber numberWithFloat:10000.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Altitude, sDK_FiltGT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:-1000.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Altitude, sDK_FiltLT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:0.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Altitude, sDK_ActSetTo, sDK_Val1]];
	
	
	[defaultsDict setObject:sDK_FiltGT
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Cadence, sDK_LastFilt]];
	[defaultsDict setObject:sDK_ActSetTo
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Cadence, sDK_LastAct]];
	[defaultsDict setObject:[NSNumber numberWithFloat:200.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Cadence, sDK_FiltGT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:200.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Cadence, sDK_ActSetTo, sDK_Val1]];


	[defaultsDict setObject:sDK_FiltGT
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Power, sDK_LastFilt]];
	[defaultsDict setObject:sDK_ActSetTo
					 forKey:[NSString stringWithFormat:@"%@-%@", sDK_Power, sDK_LastAct]];
	[defaultsDict setObject:[NSNumber numberWithFloat:600.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Power, sDK_FiltGT, sDK_Val1]];
	[defaultsDict setObject:[NSNumber numberWithFloat:150.0]
					 forKey:[NSString stringWithFormat:@"%@-%@-%@", sDK_Power, sDK_ActSetTo, sDK_Val1]];
	
	[Utils setObjectDefault:defaultsDict forKey:RCBDefaultDataFilterDict];

}


- (id) initWithTrack:(Track*)tr selected:(NSIndexSet*)spi displayingPace:(BOOL)dp
{
    [super init];
	self = [super initWithWindowNibName:@"SelectAndApplyAction"];
	trackPoints = [self copyPoints:[tr points]];
	topItems = [[NSMutableDictionary alloc] initWithCapacity:5];
	NSDictionary* tmpDict = [Utils objectFromDefaults:RCBDefaultDataFilterDict];
	if (!tmpDict) 
	{
		[self buildDefaultsDict];
	}
	else
	{
		// make *sure* it's mutable!
		defaultsDict = [NSMutableDictionary dictionaryWithDictionary:tmpDict];
	}
	selectedPointIndices = spi;
	isValid = YES;
	applyToSelected = [spi count] > 0;
	useStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	useCentigrade = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
	displayingPace = dp;
	lastTopItemKey = [Utils stringFromDefaults:RCBDefaultDataFilterLastTopItemKey];
	if (!lastTopItemKey) lastTopItemKey = sDK_HeartRate;
	return self;
}



- (id) init
{
	return [self initWithTrack:nil selected:nil displayingPace:NO];
}



- (void) dealloc
{
}





-(NSString*)lastDefaultsTypeKey:(NSString*)typeKeyComponent
{
	NSString* key = [NSString stringWithFormat:@"%@-%@", [topItem dictKey], typeKeyComponent];
	return key;
}

-(NSString*)lastDefaultsVal1Key:(NSString*)typeKeyComponent		// sDK_LastFilt or sDK_LastAct
{
	NSString* selKey = [defaultsDict objectForKey:[self lastDefaultsTypeKey:typeKeyComponent]];
	NSString* valKey = [NSString stringWithFormat:@"%@-%@-%@", [topItem dictKey], selKey, sDK_Val1];
	return valKey;
}

-(NSString*)lastTypeKey:(NSString*)typeKeyComponent
{
	NSString* key = [defaultsDict objectForKey:[self lastDefaultsTypeKey:typeKeyComponent]];
	return key;
}




static const int kRequiresValue					=	0x00000001;
static const int kIsSpeedPaceValue				=	0x00010000;
static const int kIsAltitudeValue				=	0x00020000;
static const int kIsTemperatureValue			=	0x00040000;

typedef float (*tAccessor)(id, SEL);
typedef float (*tSetter)(id, SEL, float);


-(float)fieldValue:(NSTextField*)tf
{
	float v = [tf floatValue];
	BOOL isp = FLAG_IS_SET([topItem flags], kIsSpeedPaceValue) && displayingPace;
	if (isp)
	{
		v = PaceToSpeed(v);
	}
	return v;
}


-(void)setTo:(TrackPoint*)pt
{
	float v = [self fieldValue:actionValueField];
	int flags = [topItem flags];
	BOOL isp = FLAG_IS_SET(flags, kIsSpeedPaceValue);
	if (!useStatute)
	{
		if (isp)
		{
			v = KilometersToMiles(v);
		}
		else if (FLAG_IS_SET(flags, kIsSpeedPaceValue))
		{
			v = MPKToMPM(v);
		}
		else if (FLAG_IS_SET(flags, kIsAltitudeValue))
		{
			v = MetersToFeet(v);
		}
	}
	if (useCentigrade)
	{
		if (FLAG_IS_SET(flags, kIsTemperatureValue))
		{
			v = CelsiusToFahrenheight(v);
		}
	}
	//printf("setting point value to %0.1f\n", v);
	tSetter func = (tSetter)[TrackPoint instanceMethodForSelector:[topItem setSelector]];
	if (isp) [pt setSpeedOverriden:YES];
	func(pt, nil, v);
}


-(TrackPoint*) findPreviousGoodPoint:(int)startingIdx
{
	int idx = startingIdx;
	while (idx >= 0)
	{
		TrackPoint* prevPt = [trackPoints objectAtIndex:idx];
		if (![prevPt isDeadZoneMarker]) return prevPt;
		--idx;
	}
	return nil;
}


-(void)setToPrev:(TrackPoint*)pt
{
	int flags = [topItem flags];
	BOOL isp = FLAG_IS_SET(flags, kIsSpeedPaceValue);
	tAccessor gfunc = (tAccessor)[TrackPoint instanceMethodForSelector:[topItem getSelector]];
	tSetter sfunc = (tSetter)[TrackPoint instanceMethodForSelector:[topItem setSelector]];
	int idx = [trackPoints indexOfObjectIdenticalTo:pt];
	if (idx != NSNotFound)
	{
		TrackPoint* prevPt = [self findPreviousGoodPoint:--idx];
		if (prevPt)
		{
			float v = gfunc(prevPt, nil);
			//printf("setting point value to previous pt value:%0.1f\n", v);
			if (isp) [pt setSpeedOverriden:YES];
			sfunc(pt, nil, v);
		}
	}
}


-(TrackPoint*)findNextGoodPointUsingFilter:(int)startingIdx
{
	DataPointFilterItem* filterItem = [[topItem selItems] objectForKey:[self lastTypeKey:sDK_LastFilt]];
	int count = [trackPoints count];
	int idx = startingIdx;
	while (idx < count)
	{
		// find next point that is valid
		TrackPoint* nxtGoodPt = [trackPoints objectAtIndex:idx];
		if (![nxtGoodPt isDeadZoneMarker] && 
			![self performSelector:[filterItem filterOrActionSelector]
						withObject:nxtGoodPt])
		{
			return nxtGoodPt;
		}
		++idx;
	}
	return nil;
}


-(void)interpolate:(TrackPoint*)pt
{
	int flags = [topItem flags];
	BOOL isp = FLAG_IS_SET(flags, kIsSpeedPaceValue);
	tAccessor gfunc = (tAccessor)[TrackPoint instanceMethodForSelector:[topItem getSelector]];
	tSetter sfunc = (tSetter)[TrackPoint instanceMethodForSelector:[topItem setSelector]];
	int idx = [trackPoints indexOfObjectIdenticalTo:pt];
	TrackPoint* prevPt = [self findPreviousGoodPoint:idx-1];
	TrackPoint* nextPt = [self findNextGoodPointUsingFilter:idx+1];
	float v = gfunc(pt, nil);	// what to do here?
	if (!prevPt)
	{
		if (nextPt)
		{
			v = gfunc(nextPt, nil);
		}
	}
	else
	{
		if (!nextPt)
		{
			v = gfunc(prevPt, nil);
		}
		else
		{
			float prevPtTime = [prevPt activeTimeDelta];
			float nextPtTime = [nextPt activeTimeDelta];
			float ratio = 0.0;
			if (nextPtTime > prevPtTime)
			{
				ratio = ([pt activeTimeDelta] - prevPtTime)/(nextPtTime - prevPtTime);
			}
			float prevVal = gfunc(prevPt, nil);
			float nextVal = gfunc(nextPt, nil);
			v = prevVal + (ratio * (nextVal - prevVal));
		}
	}
	//printf("interpolating point value to:%0.1f\n", v);
	if (isp) [pt setSpeedOverriden:YES];
	sfunc(pt, nil, v);
}


-(float) convertValue:(float)v flags:(int)flags
{
	if (FLAG_IS_SET(flags, kIsAltitudeValue) && !useStatute) v = FeetToMeters(v);
	else if (FLAG_IS_SET(flags, kIsTemperatureValue) && useCentigrade) v = FahrenheightToCelsius(v);
	else if (FLAG_IS_SET(flags, kIsSpeedPaceValue) && !useStatute)
	{
		if (displayingPace) v = MPMToMPK(v);
		else v = MilesToKilometers(v);
	}
	return v;
}


-(BOOL)doGreaterThan:(TrackPoint*)pt maxValue:(float)maxValue
{
	tAccessor func = (tAccessor)[TrackPoint instanceMethodForSelector:[topItem getSelector]];
	float v = func(pt, nil);
	v = [self convertValue:v
					 flags:[topItem flags]];
	return (v > maxValue);
}



-(BOOL)doLessThan:(TrackPoint*)pt minValue:(float)minValue
{
	tAccessor func = (tAccessor)[TrackPoint instanceMethodForSelector:[topItem getSelector]];
	float v = func(pt, nil);
	v = [self convertValue:v
					 flags:[topItem flags]];
	return (v < minValue);
}


-(BOOL)greaterThan:(TrackPoint*)pt
{
	BOOL isp = FLAG_IS_SET([topItem flags], kIsSpeedPaceValue) && displayingPace;
	if (isp)
	{
		return [self doLessThan:pt
					   minValue:[self fieldValue:selectionValueField]];
	}
	else
	{
		return [self doGreaterThan:pt
						  maxValue:[self fieldValue:selectionValueField]];
	}
}


-(BOOL)lessThan:(TrackPoint*)pt
{
	BOOL isp = FLAG_IS_SET([topItem flags], kIsSpeedPaceValue) && displayingPace;
	if (isp)
	{
		return [self doGreaterThan:pt
						  maxValue:[self fieldValue:selectionValueField]];
	}
	else
	{
		return [self doLessThan:pt
					   minValue:[self fieldValue:selectionValueField]];
	}
}


-(BOOL)greaterThanMaxHR:(TrackPoint*)pt
{
	return [self doGreaterThan:pt
					  maxValue:(float)[Utils intFromDefaults:RCBDefaultMaxHeartrate]];
}


-(BOOL)lessThanMinHR:(TrackPoint*)pt
{
	return [self doLessThan:pt
				   minValue:(float)[Utils intFromDefaults:RCBDefaultZone5Threshold]];
}



-(void)pointSurgery:(TrackPoint*)pt pointIndex:(int)idx actionSelector:(SEL)as
{
	currentPointIndex = idx;
	[self performSelector:as
			   withObject:pt];
}

-(void)setSelectedPointIndices:(NSIndexSet*)is
{
	if (is != selectedPointIndices)
	{
		selectedPointIndices = is;
	}
}


-(void)applyFilter:(BOOL)changeValues
{
	if (topItem)
	{
		DataPointFilterItem* filterItem = [[topItem selItems] objectForKey:[self lastTypeKey:sDK_LastFilt]];
		DataPointFilterItem* actionItem = [[topItem actItems] objectForKey:[self lastTypeKey:sDK_LastAct]];
		if (filterItem && actionItem)
		{
			NSMutableIndexSet* newIS = [NSMutableIndexSet indexSet];
			int numChanging = 0;
			// special case when apply interpolation to selected points.  In this case, get the starting and end
			// value, and interpolate points in-between...
			int numSel = [selectedPointIndices count];
			if (applyToSelected && (selectedPointIndices != nil) && (numSel > 0) &&
				([[actionItem dictKey] isEqualToString:sDK_ActInterp]))
			{
				tAccessor gfunc = (tAccessor)[TrackPoint instanceMethodForSelector:[topItem getSelector]];
				tSetter sfunc = (tSetter)[TrackPoint instanceMethodForSelector:[topItem setSelector]];
				int start = [selectedPointIndices firstIndex] - 1;
				int last = [selectedPointIndices lastIndex] + 1;
				int numPoints = [trackPoints count];
				if ((IS_BETWEEN(0, start, (numPoints-1))) &&
					(IS_BETWEEN(0, last,  (numPoints-1))))
				{
					TrackPoint* pt = [trackPoints objectAtIndex:start];
					TrackPoint* lastPt = [trackPoints objectAtIndex:last];
					float sv = gfunc(pt, nil);
					float lv = gfunc(lastPt, nil);
					float startTime = [pt activeTimeDelta];
					float deltaTime = [lastPt activeTimeDelta] - startTime;
					float deltaValue = lv - sv;
					if (deltaTime > 0.0)
					{
						int flags = [topItem flags];
						BOOL isp = FLAG_IS_SET(flags, kIsSpeedPaceValue);
						int idx = [selectedPointIndices indexGreaterThanIndex:start];
						while (idx < last)
						{
							pt = [trackPoints objectAtIndex:idx];
							float v = sv + (deltaValue * (([pt activeTimeDelta] - startTime)/deltaTime));
							++numChanging;
							if (changeValues)
							{
								sfunc(pt, nil, v);
								if (isp) [pt setSpeedOverriden:YES];
							}
							idx = [selectedPointIndices indexGreaterThanIndex:idx];
						}
					}
				}
			}
			else
			{
				for (int i=0; i<[trackPoints count]; i++)
				{
					TrackPoint* pt = [trackPoints objectAtIndex:i];
					if (![pt isDeadZoneMarker] && 
						[self performSelector:[filterItem filterOrActionSelector]
								   withObject:pt])
					{
						if (!applyToSelected || (selectedPointIndices == nil) ||
							([selectedPointIndices containsIndex:[trackPoints indexOfObjectIdenticalTo:pt]]))
						{
							[newIS addIndex:i];
							++numChanging;
							if (changeValues)
							{
								[self pointSurgery:pt
										pointIndex:i
									actionSelector:[actionItem filterOrActionSelector]];
							}
						}
					}
				}
			}
			NSString* s = @"s";
			if (numChanging == 1) s = @"";
			[descriptionField setStringValue:[NSString stringWithFormat:@"%d data point%@ out of %d will be modified", numChanging, s, [trackPoints count]]];
			[applyButton setEnabled:(numChanging > 0)];
			//[self setSelectedPointIndices:newIS];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"DataFilterChanged" object:newIS];
		}
	}
}



-(void)buildMenuFromItems:(NSPopUpButton*)pb items:(NSMutableDictionary*)itemDict selectKey:(NSString*)sk
{
	[pb removeAllItems];
	NSArray* arr = [itemDict keysSortedByValueUsingSelector:@selector(compare:)];
	int selIdx = 0;
	for (int i=0; i<[arr count]; i++)
	{
		DataPointFilterItem* fi = [itemDict objectForKey:[arr objectAtIndex:i]];
		[pb addItemWithTitle:[fi name]];
		if ([[fi dictKey] isEqualToString:sk])
		{
			selIdx = i;
		}
	}
	[pb selectItemAtIndex:selIdx];
}


-(void)setFormatterForField:(NSTextField*)tf isSpeedPace:(BOOL)isp
{
	if (isp)
	{
		AscentIntervalFormatter* fm =[[AscentIntervalFormatter alloc] initAsPace:YES];
		[tf setFormatter:fm];
		[fm autorelease];
	}
	else
	{
		NSNumberFormatter* fm =[[NSNumberFormatter alloc] init];
		[fm setFormat:[NSString stringWithFormat:@"#0.0"]];
		[tf setFormatter:fm];
		[fm autorelease];
	}
}



-(void)buildFilter:(BOOL)apply
{
	int idx = [fieldTypePopup indexOfSelectedItem];
	if (idx < [topItems count])
	{
		[self buildMenuFromItems:selectionCriteriaPopup
						   items:[topItem selItems]
					   selectKey:[self lastTypeKey:sDK_LastFilt]];
		DataPointFilterItem* selItem = [[topItem selItems] objectForKey:[self lastTypeKey:sDK_LastFilt]];
		if (FLAG_IS_SET([selItem flags], kRequiresValue))
		{
			[selectionValueField setHidden:NO];
			BOOL isp = FLAG_IS_SET([selItem flags], kIsSpeedPaceValue) && displayingPace;
			[self setFormatterForField:selectionValueField
						   isSpeedPace:isp];
			float v =[[defaultsDict objectForKey:[self lastDefaultsVal1Key:sDK_LastFilt]] floatValue];
			if (isp && displayingPace)
			{
				v = SpeedToPace(v);
			}
			[selectionValueField setFloatValue:v];
		}
		else
		{
			[selectionValueField setHidden:YES];
		}
		
		[self buildMenuFromItems:actionTypePopup
						   items:[topItem actItems]
					   selectKey:[self lastTypeKey:sDK_LastAct]];
		DataPointFilterItem* actItem = [[topItem actItems] objectForKey:[self lastTypeKey:sDK_LastAct]];
		if (FLAG_IS_SET([actItem flags], kRequiresValue))
		{
			[actionValueField setHidden:NO];
			BOOL isp = FLAG_IS_SET([actItem flags], kIsSpeedPaceValue) && displayingPace;
			[self setFormatterForField:actionValueField
						   isSpeedPace:isp];
			float v =[[defaultsDict objectForKey:[self lastDefaultsVal1Key:sDK_LastAct]] floatValue];
			if (isp && displayingPace)
			{
				v = SpeedToPace(v);
			}
			[actionValueField setFloatValue:v];
		}
		else
		{
			[actionValueField setHidden:YES];
		}
	}	
	[self applyFilter:apply];
}





-(void) awakeFromNib
{
	NSMutableDictionary* selItems;
	NSMutableDictionary* actItems;
	
	// build up the arrays describing the filtering GUI
	
	// heart rate filtering .....................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than maximum heart rate"
														   dictKey:sDK_FiltGTMaxHR
															filter:@selector(greaterThanMaxHR:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_FiltGTMaxHR];
	
#if 0
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than minimum heart rate"
														   dictKey:sDK_FiltLTMinHR
															filter:@selector(lessThanMinHR:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_FiltLTMinHR];
#endif
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than"
														   dictKey:sDK_FiltGT
															filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than"
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltLT];
	 
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set heart rate to previous value"
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set heart rate to"
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"interpolate heart rate from surrounding values"
														   dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActInterp];
	  
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:@"heart rate"
															  dictKey:sDK_HeartRate
														  getSelector:@selector(heartrate)
														  setSelector:@selector(setHeartrate:)
															 selItems:selItems 
															 actItems:actItems
																flags:0]
				 forKey:sDK_HeartRate];
		
						
	// speed/pace filtering .....................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	NSString* speedOrPaceString = displayingPace ? @"pace" : @"speed";
	
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than"
														   dictKey:sDK_FiltGT
														filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsSpeedPaceValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than"
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsSpeedPaceValue]
				 forKey:sDK_FiltLT];
	
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:[NSString stringWithFormat:@"set %@ to previous value", speedOrPaceString]
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:kIsSpeedPaceValue]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:[NSString stringWithFormat:@"set %@ to", speedOrPaceString]
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsSpeedPaceValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:[NSString stringWithFormat:@"interpolate %@ from surrounding values", speedOrPaceString]
														   dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:kIsSpeedPaceValue]
				 forKey:sDK_ActInterp];
	
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:speedOrPaceString
															  dictKey:sDK_Speed
														  getSelector:@selector(speed)
														  setSelector:@selector(setSpeed:)
															 selItems:selItems 
															 actItems:actItems
																flags:kIsSpeedPaceValue]
				 forKey:sDK_Speed];

	// altitude filtering .......................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than"
														   dictKey:sDK_FiltGT
															filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsAltitudeValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than"
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsAltitudeValue]
				 forKey:sDK_FiltLT];
	
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set altitude to previous value"
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:kIsAltitudeValue]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set altitude to"
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsAltitudeValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"interpolate altitude from surrounding values"
														   dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:kIsAltitudeValue]
				 forKey:sDK_ActInterp];
	
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:@"altitude"
															  dictKey:sDK_Altitude
														  getSelector:@selector(origAltitude)
														  setSelector:@selector(setOrigAltitude:)
															 selItems:selItems 
															 actItems:actItems
																flags:kIsAltitudeValue]
				 forKey:sDK_Altitude];
	
	// cadence filtering ........................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than "
														   dictKey:sDK_FiltGT
															filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than "
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltLT];
	
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set to previous value"
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set cadence to  "
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"interpolate cadence from surrounding values"
                                                          dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActInterp];
	
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:@"cadence"
															  dictKey:sDK_Cadence
														  getSelector:@selector(cadence)
														  setSelector:@selector(setCadence:)
															 selItems:selItems 
															 actItems:actItems
																flags:0]
				 forKey:sDK_Cadence];
	
	// power filtering ........................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than "
														   dictKey:sDK_FiltGT
															filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than "
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_FiltLT];
	
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set to previous value"
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set power to  "
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"interpolate power from surrounding values"
														   dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:0]
				 forKey:sDK_ActInterp];
	
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:@"power"
															  dictKey:sDK_Power
														  getSelector:@selector(power)
														  setSelector:@selector(setPower:)
															 selItems:selItems 
															 actItems:actItems
																flags:0]
				 forKey:sDK_Power];
	
	// temperature filtering ....................................................
	selItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"greater than "
														   dictKey:sDK_FiltGT
															filter:@selector(greaterThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsTemperatureValue]
				 forKey:sDK_FiltGT];
	[selItems setObject:[[DataPointFilterItem alloc] initWithName:@"less than "
														   dictKey:sDK_FiltLT
															filter:@selector(lessThan:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsTemperatureValue]
				 forKey:sDK_FiltLT];
	
	actItems = [NSMutableDictionary dictionaryWithCapacity:5];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set to previous value"
														   dictKey:sDK_ActSetPrev
															filter:@selector(setToPrev:)
													   choiceItems:nil
															 flags:kIsTemperatureValue]
				 forKey:sDK_ActSetPrev];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"set temperature to  "
														   dictKey:sDK_ActSetTo
															filter:@selector(setTo:)
													   choiceItems:nil
															 flags:kRequiresValue|kIsTemperatureValue]
				 forKey:sDK_ActSetTo];
	[actItems setObject:[[DataPointFilterItem alloc] initWithName:@"interpolate temperature from surrounding values"
														   dictKey:sDK_ActInterp
															filter:@selector(interpolate:)
													   choiceItems:nil
															 flags:kIsTemperatureValue]
				 forKey:sDK_ActInterp];
	
	[topItems setObject:[[TopDataPointFilterItem alloc] initWithName:@"temperature"
															  dictKey:sDK_Temperature
														  getSelector:@selector(temperature)
														  setSelector:@selector(setTemperature:)
															 selItems:selItems 
															 actItems:actItems
																flags:kIsTemperatureValue]
				 forKey:sDK_Temperature];
	
	//...........................................................................
	
	[fieldTypePopup removeAllItems];
	NSArray* topArr = [topItems keysSortedByValueUsingSelector:@selector(compare:)];
	int selIdx = 0;
	for (int i=0; i<[topArr count]; i++)
	{
		NSString* key = [topArr objectAtIndex:i];
		[fieldTypePopup addItemWithTitle:[[topItems objectForKey:key] name]];
		if ([key isEqualToString:lastTopItemKey])
		{
			selIdx = i;
		}
	}
	[fieldTypePopup selectItemAtIndex:selIdx];
	topItem = [topItems objectForKey:lastTopItemKey];
	[self buildFilter:NO];
	[applyOnlyToSelectedButton setEnabled:[selectedPointIndices count] > 0];
}


-(void)setLastTopItemKey:(NSString*)s
{
	if (s != lastTopItemKey)
	{
		lastTopItemKey = s;
	}
}


-(IBAction)setPopUpValue:(id)sender
{
	int idx = [sender indexOfSelectedItem];
	if (sender == fieldTypePopup)
	{
		NSString* topKey = [[topItems keysSortedByValueUsingSelector:@selector(compare:)] objectAtIndex:idx];
		topItem = [topItems objectForKey:topKey];
		[self setLastTopItemKey:topKey];
		[Utils setStringDefault:lastTopItemKey 
						  forKey:RCBDefaultDataFilterLastTopItemKey];
	}
	else if (sender == selectionCriteriaPopup)
	{
		NSString* selKey = [[[topItem selItems] keysSortedByValueUsingSelector:@selector(compare:)] objectAtIndex:idx];
		[defaultsDict setObject:selKey
						 forKey:[self lastDefaultsTypeKey:sDK_LastFilt]];
	}
	else if (sender == actionTypePopup)
	{
		NSString* actKey = [[[topItem actItems] keysSortedByValueUsingSelector:@selector(compare:)] objectAtIndex:idx];
		[defaultsDict setObject:actKey
						 forKey:[self lastDefaultsTypeKey:sDK_LastAct]];
	}
	[self buildFilter:NO];
	[Utils setObjectDefault:defaultsDict forKey:RCBDefaultDataFilterDict];
}



-(IBAction)setTextFieldValue:(id)sender
{
	if (sender == selectionValueField)
	{
		float v = [sender floatValue];
		if (FLAG_IS_SET([topItem flags], kIsSpeedPaceValue) && displayingPace)
		{
			v = PaceToSpeed(v);
		}
		[defaultsDict setObject:[NSNumber numberWithFloat:v]
						 forKey:[self lastDefaultsVal1Key:sDK_LastFilt]];
	}
	else if (sender == actionValueField)
	{
		float v = [sender floatValue];
		if (FLAG_IS_SET([topItem flags], kIsSpeedPaceValue) && displayingPace)
		{
			v = PaceToSpeed(v);
		}
		[defaultsDict setObject:[NSNumber numberWithFloat:v]
						 forKey:[self lastDefaultsVal1Key:sDK_LastAct]];
	}
	[self buildFilter:NO];
	[Utils setObjectDefault:defaultsDict forKey:RCBDefaultDataFilterDict];
}


- (IBAction) dismissPanel:(id)sender
{
	[NSApp stopModalWithCode:isValid ? 0: -1];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp stopModalWithCode:-1];
}


-(IBAction)applyOnlyToSelected:(id)sender
{
	applyToSelected = [sender intValue] != 0;
	[self applyFilter:NO];
}

-(IBAction) apply:(id)sender
{
    [[self window] makeFirstResponder:nil];
	isValid = YES;
	[self applyFilter:YES];
	[self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
	isValid = NO;
	[self dismissPanel:sender];
}

- (NSMutableArray*) newPoints
{
	return trackPoints;
}

@end
