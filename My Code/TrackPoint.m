//
//  TrackPoint.m
//  TLP
//
//  Created by Rob Boyer on 7/13/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "Defs.h"
#import "TrackPoint.h"
#import "Utils.h"

// flags for the 'flags' field, stored persistently
enum {
    kSpeedOverriden         = 0x00000001,
    kIsFirstPointInLap      = 0x00010000,
    kPowerDataCalculated    = 0x00000020,
    kStartDeadZoneMarker    = 0x00000100,
    kEndDeadZoneMarker      = 0x00000200,
    // import-related
    kImportFlags            = 0xfff00000,
};

#define DATA_ITEM_TO_FLAG(di)   (1 << ((int)di + 20))

// Manage legacy decode base time for old archives (v1–v3)
static NSDate *sStartTime = nil;

@implementation TrackPoint

//@synthesize seq = _seq;

@synthesize wallClockDelta = _wallClockDelta;
@synthesize activeTimeDelta = _activeTimeDelta;
@synthesize latitude = _latitude;
@synthesize longitude = _longitude;
@synthesize origAltitude = _origAltitude;
@synthesize altitude = _altitude;
@synthesize heartrate = _heartrate;
@synthesize cadence = _cadence;
@synthesize temperature = _temperature;
@synthesize speed = _speed;
@synthesize power = _power;
@synthesize origDistance = _origDistance;
@synthesize distance = _distance;
@synthesize gradient = _gradient;
@synthesize flags = _flags;

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)init
{
    self = [super init];
    if (self) {
     ///   _seq             = 0;
        _wallClockDelta  = 0;
        _activeTimeDelta = 0;
        _latitude        = BAD_LATLON;
        _longitude       = BAD_LATLON;
        _altitude        = BAD_ALTITUDE;
        _origAltitude    = BAD_ALTITUDE;
        _heartrate       = 0;
        _cadence         = 0;
        _temperature     = 0;
        _speed           = 0;
        _power           = 0;
        _origDistance    = BAD_DISTANCE;
        _distance        = BAD_DISTANCE;
        _gradient        = 0;
        _flags           = 0;
        validLatLon      = NO;
        climbSoFar       = 0.0f;
        descentSoFar     = 0.0f;
    }
    return self;
}

- (id)initWithGPSData:(NSTimeInterval)wcd
           activeTime:(NSTimeInterval)atd
             latitude:(float)lat
            longitude:(float)lon
             altitude:(float)alt
            heartrate:(int)hr
              cadence:(int)cd
          temperature:(float)temp
                speed:(float)sp
             distance:(float)d
{
    self = [self init]; // centralize defaults & call super
    if (!self) return nil;

    _wallClockDelta   = wcd;
    _activeTimeDelta  = atd;
    _latitude         = lat;
    _longitude        = lon;
    validLatLon       = [Utils validateLatitude:lat longitude:lon];
    _heartrate        = (float)hr;
    _origAltitude = _altitude = alt;
    _power            = 0.0f;
    _cadence          = (cd >= 255) ? 0.0f : (float)cd;
    _temperature      = temp;
    _speed            = sp;
    _origDistance = _distance = d;
    _gradient         = 0.0f;
    _flags            = 0;

    return self;
}

- (id)initWithDeadZoneMarker:(NSTimeInterval)wcd activeTimeDelta:(NSTimeInterval)atd
{
    self = [self init]; // centralize defaults & call super
    if (!self) return nil;

    _wallClockDelta   = wcd;
    _activeTimeDelta  = atd;
    _latitude = _longitude = BAD_LATLON;
    _heartrate        = 0.0f;
    _cadence          = 0.0f;
    _altitude         = BAD_ALTITUDE;
    _origDistance = _distance = BAD_DISTANCE;
    _gradient         = 0.0f;
    _speed            = 0.0f;
    _flags            = 0;

    return self;
}

- (void)dealloc
{
    // No object ivars to release; primitives only.
    [super dealloc];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    TrackPoint *newPoint = [[TrackPoint allocWithZone:zone] init];
    [newPoint setWallClockDelta:self.wallClockDelta];
    [newPoint setActiveTimeDelta:self.activeTimeDelta];
    [newPoint setAltitude:self.altitude];
    [newPoint setOrigAltitude:self.origAltitude];
    [newPoint setLatitude:self.latitude];
    [newPoint setLongitude:self.longitude];
    [newPoint setHeartrate:self.heartrate];
    [newPoint setCadence:self.cadence];
    [newPoint setTemperature:self.temperature];
    [newPoint setSpeed:self.speed];
    [newPoint setDistance:self.distance];
    [newPoint setGradient:self.gradient];
    [newPoint setOrigDistance:self.origDistance];
    [newPoint setValidLatLon:validLatLon];
    [newPoint setClimbSoFar:climbSoFar];
    [newPoint setDescentSoFar:descentSoFar];
    [newPoint setPower:self.power];
    newPoint.flags = self.flags;
   /// newPoint.seq   = self.seq;
    return newPoint; // MRC: returned retained
}

// old school, hackish way of marking dead zones use methods below
- (BOOL)isDeadZoneMarker
{
    return (self.origDistance == BAD_DISTANCE) && (self.latitude == BAD_LATLON) && (self.longitude == BAD_LATLON);
}

- (BOOL)beginningOfDeadZone
{
    return FLAG_IS_SET(self.flags, kStartDeadZoneMarker);
}

- (BOOL)setBeginningOfDeadZone
{
    return SET_FLAG(self.flags, kStartDeadZoneMarker);
}

- (BOOL)endOfDeadZone
{
    return FLAG_IS_SET(self.flags, kEndDeadZoneMarker);
}

- (BOOL)setEndOfDeadZone
{
    return SET_FLAG(self.flags, kEndDeadZoneMarker);
}

+ (void)resetStartTime:(NSDate *)startTime   // MRC lifetime management
{
    if (startTime != sStartTime) {
        [sStartTime release];
        sStartTime = [startTime retain];
    }
}

#define CUR_VERSION         5
#define DEBUG_DECODE_POINT  0

- (id)initWithCoder:(NSCoder *)coder
{
#if DEBUG_DECODE_POINT
    printf("  decoding TrackPoint\n");
#endif
    self = [super init];
    if (!self) return nil;

    int version = 0;
    [coder decodeValueOfObjCType:@encode(int) at:&version];

    if (version > CUR_VERSION) {
        NSException *e = [NSException exceptionWithName:ExFutureVersionName
                                                 reason:ExFutureVersionReason
                                               userInfo:nil];
        @throw e;
    }

    if (version < 4) {
        NSDate *wallDate = [coder decodeObject];   // autoreleased
#if DEBUG_DECODE_POINT
        printf("    wall date\n");
#endif
        NSAssert(sStartTime != nil, @"TrackPoint decode requires sStartTime; call +resetStartTime: first.");
        _wallClockDelta  = [wallDate timeIntervalSinceDate:sStartTime];
        _activeTimeDelta = _wallClockDelta;

        if (version > 1) {
            NSDate *activeTimeDate = [coder decodeObject]; // autoreleased
            _activeTimeDelta = [activeTimeDate timeIntervalSinceDate:sStartTime];
        }
    } else {
        double dtemp = 0.0;
        [coder decodeValueOfObjCType:@encode(double) at:&dtemp];
        _wallClockDelta = dtemp;

        dtemp = 0.0;
        [coder decodeValueOfObjCType:@encode(double) at:&dtemp];
        _activeTimeDelta = dtemp;
    }

    float fval = 0.0f;
    int   ival = 0;

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // distance (legacy)
    [self setDistance:fval];
    _origDistance = fval;

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // latitude
    [self setLatitude:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // longitude
    [self setLongitude:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // altitude
    [self setAltitude:fval];
    _origAltitude = fval;

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // speed
    [self setSpeed:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // temperature
    [self setTemperature:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // power (v5)
    [self setPower:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // spare

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // heartrate
    [self setHeartrate:fval];

    [coder decodeValueOfObjCType:@encode(float) at:&fval]; // cadence
    if (fval >= 254.5f) fval = 0.0f;                        // illegal cadence value, not present
    [self setCadence:fval];

    int iTemp = 0;
    [coder decodeValueOfObjCType:@encode(int) at:&iTemp];   // flags (v3)
    _flags = iTemp;

    [coder decodeValueOfObjCType:@encode(int) at:&ival];    // spare

    validLatLon = [Utils validateLatitude:self.latitude longitude:self.longitude];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    int version = CUR_VERSION;
    [coder encodeValueOfObjCType:@encode(int) at:&version];

    // times
    double dTemp = _wallClockDelta;
    [coder encodeValueOfObjCType:@encode(double) at:&dTemp];

    dTemp = _activeTimeDelta;
    [coder encodeValueOfObjCType:@encode(double) at:&dTemp];

    // distance (legacy: historically encoded 0)
    float fTemp = 0.0f;
    [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // latitude / longitude
    fTemp = _latitude;   [coder encodeValueOfObjCType:@encode(float) at:&fTemp];
    fTemp = _longitude;  [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // altitude
    fTemp = _altitude;   [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // speed, temperature
    fTemp = _speed;        [coder encodeValueOfObjCType:@encode(float) at:&fTemp];
    fTemp = _temperature;  [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // power: if calculated, store 0.0 per legacy behavior
    float p = (!(FLAG_IS_SET(self.flags, kPowerDataCalculated)) ? _power : 0.0f);
    [coder encodeValueOfObjCType:@encode(float) at:&p];

    // spare float
    fTemp = 0.0f;
    [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // heartrate, cadence
    fTemp = _heartrate; [coder encodeValueOfObjCType:@encode(float) at:&fTemp];
    fTemp = _cadence;   [coder encodeValueOfObjCType:@encode(float) at:&fTemp];

    // flags (v3)
    int iTemp = _flags;
    [coder encodeValueOfObjCType:@encode(int) at:&iTemp];

    // spare int
    int spareInt = 0;
    [coder encodeValueOfObjCType:@encode(int) at:&spareInt];
}

- (id)copyWithZone:(NSZone *)zone
{
    TrackPoint *p = [[TrackPoint allocWithZone:zone] init];

    ///p->_seq            = _seq;

    p->_wallClockDelta  = _wallClockDelta;
    p->_activeTimeDelta = _activeTimeDelta;

    p->_latitude     = _latitude;
    p->_longitude    = _longitude;
    p->_altitude     = _altitude;
    p->_origAltitude = _origAltitude;

    p->_heartrate    = _heartrate;
    p->_cadence      = _cadence;
    p->_temperature  = _temperature;
    p->_speed        = _speed;
    p->_power        = _power;

    p->_distance     = _distance;
    p->_origDistance = _origDistance;
    p->_gradient     = _gradient;

    p->_flags        = _flags;

    p->validLatLon   = validLatLon;
    p->climbSoFar    = climbSoFar;
    p->descentSoFar  = descentSoFar;

    return p; // retained (MRC)
}

- (void)setValidLatLon:(BOOL)v { validLatLon = v; }
- (BOOL)validLatLon { return validLatLon; }

- (BOOL)validAltitude {
    // if altitude is *exactly* 0.0 assume it is a bad value. BAD_ALTITUDE values may have
    // been overridden at the beginning of activities due to a bug in 1.8.x, but they will always be 0.
    return (self.origAltitude != 0.0) && (VALID_ALTITUDE(self.origAltitude));
}

- (BOOL)validDistance { return VALID_DISTANCE(self.distance); }
- (BOOL)validOrigDistance { return VALID_DISTANCE(_origDistance); }
- (BOOL)validHeartrate { return _heartrate > 0; }

- (float)latitude { return _latitude; }
- (void)setLatitude:(float)l { _latitude = l; validLatLon = [Utils validateLatitude:_latitude longitude:_longitude]; }

- (float)longitude { return _longitude; }
- (void)setLongitude:(float)l { _longitude = l; validLatLon = [Utils validateLatitude:_latitude longitude:_longitude]; }

- (float)origAltitude { return _origAltitude; }
- (void)setOrigAltitude:(float)a { _origAltitude = a; }

- (float)altitude { return _altitude; }
- (void)setAltitude:(float)a { _altitude = a; }

- (float)heartrate { return _heartrate; }
- (void)setHeartrate:(float)h { _heartrate = h; }

- (float)cadence { return _cadence; }
- (void)setCadence:(float)c { _cadence = c; }

- (int)flags { return _flags; }
- (void)setFlags:(int)f { _flags = f; }

- (float)temperature { return _temperature; }
- (void)setTemperature:(float)t { _temperature = t; }

- (float)speed { return _speed; }
- (void)setSpeed:(float)s { _speed = s; }

- (float)pace { return (_speed > 0.0f) ? (3600.0f/_speed) : 3600.0f; }

- (float)distance { return _distance; }
- (void)setDistance:(float)d { _distance = d; }

- (float)gradient { return _gradient; }
- (void)setGradient:(float)g { _gradient = g; }

- (float)climbSoFar { return climbSoFar; }
- (void)setClimbSoFar:(float)value { if (climbSoFar != value) climbSoFar = value; }

- (float)descentSoFar { return descentSoFar; }
- (void)setDescentSoFar:(float)value { if (descentSoFar != value) descentSoFar = value; }

- (BOOL)speedOverridden { return FLAG_IS_SET(_flags, kSpeedOverriden); }
- (void)setSpeedOverriden:(BOOL)set { if (set) SET_FLAG(_flags, kSpeedOverriden); else CLEAR_FLAG(_flags, kSpeedOverriden); }

- (BOOL)isFirstPointInLap { return FLAG_IS_SET(_flags, kIsFirstPointInLap); }
- (void)setIsFirstPointInLap:(BOOL)set { if (set) SET_FLAG(_flags, kIsFirstPointInLap); else CLEAR_FLAG(_flags, kIsFirstPointInLap); }

- (void)setDistanceToOriginal { _distance = _origDistance; }
- (float)origDistance { return _origDistance; }
- (void)setOrigDistance:(float)d { _origDistance = d; }

- (NSNumber*)speedAsNumber { return [NSNumber numberWithFloat:_speed]; }
- (NSNumber*)paceAsNumber { return [NSNumber numberWithFloat:[self pace]]; }
- (NSNumber*)cadenceAsNumber { return [NSNumber numberWithFloat:_cadence]; }
- (NSNumber*)heartrateAsNumber { return [NSNumber numberWithFloat:_heartrate]; }
- (NSNumber*)powerAsNumber { return [NSNumber numberWithFloat:_power]; }

- (void)setPower:(float)p
{
    if (p < MAX_REASONABLE_POWER) {
        _power = p;
        if (p > 0.0f) CLEAR_FLAG(self.flags, kPowerDataCalculated);
    }
#if _DEBUG
    else {
        printf("power = %0.1f, wtf?\n", p);
    }
#endif
}

- (void)setCalculatedPower:(float)p
{
    if (IS_BETWEEN(0.0, p, MAX_REASONABLE_POWER)) {
        _power = p;
        SET_FLAG(self.flags, kPowerDataCalculated);
    }
}

- (BOOL)powerIsCalculated
{
    return FLAG_IS_SET(_flags, kPowerDataCalculated);
}

- (void)setImportFlagState:(int)item state:(BOOL)st
{
    int flag = DATA_ITEM_TO_FLAG(item);
    if (st) SET_FLAG(_flags, flag);
    else    CLEAR_FLAG(_flags, flag);
}

- (BOOL)importFlagState:(int)item
{
    int flag = DATA_ITEM_TO_FLAG(item);
    return FLAG_IS_SET(_flags, flag);
}

- (NSComparisonResult)compare:(TrackPoint*)anotherPoint
{
    NSTimeInterval otherPointWCD = [anotherPoint wallClockDelta];
    if  (_wallClockDelta < otherPointWCD)
        return NSOrderedAscending;
    else if (_wallClockDelta > otherPointWCD)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

@end
