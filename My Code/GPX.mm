//
//  GPX.mm
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software.
//

#import "GPX.h"
#import "Utils.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Defs.h"
#import "ImportDateEntryController.h"

typedef void (*tLapAvgMaxSetter)(id, SEL, int);

@interface GPX ()
// Parsing state (non-retained where noted)
{
    BOOL inPoint;
    BOOL inLap;
    BOOL inActivity;
    BOOL inTrack;
    BOOL pointsHaveTime;
    BOOL haveActivityStartTime;
    BOOL skipTrack;
    BOOL distanceExtensionFound;

    tLapAvgMaxSetter summarySetter;

    // Assigned (not retained)
    NSArray *importTrackArray;
    NSWindowController *parentWindowController;
}

// Retained properties for MRC
@property (nonatomic, retain) NSURL *xmlURL;
@property (nonatomic, retain) NSXMLParser *parser;

@property (nonatomic, retain) Track *currentImportTrack;
@property (nonatomic, retain) Lap *currentImportLap;
@property (nonatomic, retain) TrackPoint *currentImportPoint;

@property (nonatomic, retain) NSMutableArray *currentImportLapArray;
@property (nonatomic, retain) NSMutableArray *currentImportPointArray;
@property (nonatomic, retain) NSMutableArray *currentImportTrackArray;

@property (nonatomic, retain) NSMutableString *currentStringValue;
@property (nonatomic, retain) NSString *currentTrackName;
@property (nonatomic, retain) NSString *currentActivity;

@property (nonatomic, retain) NSDate *activityStartDate;
@property (nonatomic, retain) NSDate *pointStartDate;
@property (nonatomic, retain) NSDate *lapStartTime;

// Helpers
- (void)processLapData:(NSMutableArray *)laps;
- (NSDate *)dateFromTimeString:(NSString *)ts;
- (void)setActivityStartDateIfNeeded:(NSDate *)dt;
- (void)resetCurrentString;
- (NSDate *)getStartTime;
- (void)startTrack;

@end

@implementation GPX

#pragma mark - Lifecycle

- (instancetype)initGPXWithFileURL:(NSURL *)url windowController:(NSWindowController *)wc
{
    self = [super init];
    if (self) {
        self.xmlURL = url;                // retained by property
        parentWindowController = wc;      // assigned (not retained)

        inPoint = inActivity = inLap = inTrack = NO;
        pointsHaveTime = NO;
        haveActivityStartTime = NO;
        skipTrack = NO;
        distanceExtensionFound = NO;

        summarySetter = (tLapAvgMaxSetter)[[self class] instanceMethodForSelector:@selector(doNothing:)];

        self.currentImportTrack = nil;
        self.currentImportLap = nil;
        self.currentImportPoint = nil;

        self.currentImportPointArray = nil;
        self.currentImportLapArray = nil;
        self.currentImportTrackArray = nil;

        self.currentTrackName = nil;
        self.currentActivity = nil;
        self.currentStringValue = nil;

        self.activityStartDate = nil;
        self.pointStartDate = nil;
        self.lapStartTime = nil;
    }
    return self;
}

- (void)dealloc
{
    // Use setters to release once; avoid double-release
    self.parser = nil;
    self.xmlURL = nil;

    self.currentImportTrack = nil;
    self.currentImportLap = nil;
    self.currentImportPoint = nil;

    self.currentImportLapArray = nil;
    self.currentImportPointArray = nil;
    self.currentImportTrackArray = nil;

    self.currentStringValue = nil;
    self.currentActivity = nil;
    self.currentTrackName = nil;

    self.activityStartDate = nil;
    self.pointStartDate = nil;
    self.lapStartTime = nil;

    [super dealloc];
}

#pragma mark - Small helpers

- (void)doNothing:(int)v { (void)v; }

- (void)resetCurrentString
{
    self.currentStringValue = nil;
}

- (void)setActivityStartDateIfNeeded:(NSDate *)dt
{
    if (!self.activityStartDate) {
        self.activityStartDate = dt; // retained by property
    }
}

- (NSDate *)dateFromTimeString:(NSString *)ts
{
    // Expected ISO-ish "YYYY-MM-DDTHH:MM:SSZ"
    if (ts.length < 19) return [NSDate date];

    NSRange r; r.length = 10; r.location = 0;
    NSString *sub = [ts substringWithRange:r];
    NSMutableString *d = [NSMutableString stringWithString:sub];
    r.length = 8; r.location = 11;
    NSString *t = [ts substringWithRange:r];

    [d appendString:@" "];
    [d appendString:t];
    [d appendString:@" +0000"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSDate dateWithString:d];
#pragma clang diagnostic pop
}

#pragma mark - Track stitching (unchanged behavior)

- (void)processLapData:(NSMutableArray *)laps
{
    NSUInteger lapCount = [laps count];
    NSUInteger numTracks = [self.currentImportTrackArray count];
    if ((numTracks > 0) && (lapCount > 0))
    {
        int lapIndex = 0;
        NSDate *earliestTrackDate = [[self.currentImportTrackArray objectAtIndex:0] creationTime];
        int trackIndex = (int)[self.currentImportTrackArray count] - 1;
        Lap *lap = [laps objectAtIndex:lapIndex];
        while ((trackIndex >= 0) && (lapIndex < lapCount))
        {
            if ([[lap origStartTime] compare:earliestTrackDate] == NSOrderedAscending) break;
            Track *track = [self.currentImportTrackArray objectAtIndex:trackIndex];
            BOOL lapIsInTrack = [track isDateDuringTrack:[lap origStartTime]];

            while (!lapIsInTrack &&
                   ([[lap origStartTime] compare:[track creationTime]] == NSOrderedDescending) &&
                   (lapIndex < (lapCount-1)))
            {
                ++lapIndex;
                lap = [laps objectAtIndex:lapIndex];
                lapIsInTrack = [track isDateDuringTrack:[lap origStartTime]];
            }
            while ((lapIndex < lapCount) &&
                   ([track isDateDuringTrack:[lap origStartTime]] ||
                    [lap isOrigDateDuringLap:[track creationTime]]))
            {
                [lap setStartingWallClockTimeDelta:[[lap origStartTime] timeIntervalSinceDate:[track creationTime]]];
                [track addLapInFront:lap];
                if ([[lap origStartTime] compare:[track creationTime]] == NSOrderedAscending) {
                    [track setCreationTime:[lap origStartTime]];
                }
                ++lapIndex;
                if ((lapIndex >= 0) && (lapIndex < [laps count])) {
                    lap = [laps objectAtIndex:lapIndex];
                } else {
                    break;
                }
            }
            --trackIndex;
        }
    }
}

#pragma mark - Public Import

- (BOOL)import:(NSMutableArray *)trackArray laps:(NSMutableArray *)lapArray
{
    importTrackArray = trackArray; // assigned only

    self.activityStartDate = nil;
    skipTrack = NO;
    pointsHaveTime = NO;
    haveActivityStartTime = NO;

    summarySetter = (tLapAvgMaxSetter)[[self class] instanceMethodForSelector:@selector(doNothing:)];

    self.currentImportTrackArray = nil;
    self.currentImportLapArray = nil;

    // retain via property; no extra retain
    self.currentActivity = [Utils stringFromDefaults:RCBDefaultActivity];

    // Create parser with the standard MRC pattern (assign then release the temp)
    NSXMLParser *p = [[NSXMLParser alloc] initWithContentsOfURL:self.xmlURL];
    self.parser = p;
    [p release];

    [self.parser setDelegate:self];
    [self.parser setShouldResolveExternalEntities:YES];

    BOOL parsed = [self.parser parse];

    if (self.currentImportLapArray) {
        [self.currentImportTrackArray sortUsingSelector:@selector(compareByDate:)];
        [self.currentImportLapArray sortUsingSelector:@selector(reverseCompareByOrigStartTime:)];
        [self processLapData:self.currentImportLapArray];
    }

    if (parsed && self.currentImportTrackArray.count > 0) {
        [trackArray addObjectsFromArray:self.currentImportTrackArray];
    }

    // Clean transient containers after handing off to caller
    self.currentImportLapArray   = nil;
    self.currentImportTrackArray = nil;
    self.currentImportPointArray = nil;

    // Release parser and transient activity string
    self.parser          = nil;
    self.currentActivity = nil;

    return parsed;
}

#pragma mark - Start helpers

- (void)startTrack
{
    inActivity = YES;
    inPoint = NO;

    if (!self.currentImportTrack) {
        Track *trk = [[Track alloc] init];
        self.currentImportTrack = trk;
        [trk release];
    }
    if (!self.currentImportTrackArray) {
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        self.currentImportTrackArray = arr;
        [arr release];
    }
    if (!self.currentImportLapArray) {
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        self.currentImportLapArray = arr;
        [arr release];
    }
}

#pragma mark - NSXMLParserDelegate (start)

- (void)parser:(NSXMLParser *)p
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
    (void)p; (void)namespaceURI; (void)qName;

    if ([elementName isEqualToString:@"trk"] ||
        [elementName isEqualToString:@"rte"])
    {
        skipTrack = NO;
        inTrack = YES;
        inLap = NO;
        pointsHaveTime = NO;
        haveActivityStartTime = NO;
        self.activityStartDate = nil;

        if ([elementName isEqualToString:@"rte"]) {
            [self startTrack];
        }
        return;
    }

    if ([elementName isEqualToString:@"trkseg"]) {
        [self startTrack];
        return;
    }

    if ([elementName isEqualToString:@"trkpt"] ||
        [elementName isEqualToString:@"rtept"])
    {
        distanceExtensionFound = NO;
        inPoint = YES;
        inLap = NO;
        self.pointStartDate = nil;

        if (!self.currentImportPoint) {
            TrackPoint *pt = [[TrackPoint alloc] init];
            self.currentImportPoint = pt;
            [pt release];
        }
        if (!self.currentImportPointArray) {
            NSMutableArray *arr = [[NSMutableArray alloc] init];
            self.currentImportPointArray = arr;
            [arr release];
        }

        NSString *s = [attributeDict objectForKey:@"lat"];
        if (s) {
            float lat = [s floatValue];
            s = [attributeDict objectForKey:@"lon"];
            if (s) {
                float lon = [s floatValue];
                [self.currentImportPoint setLatitude:lat];
                [self.currentImportPoint setLongitude:lon];
            }
        }
        return;
    }

    if ([elementName isEqualToString:@"gpxdata:lap"])
    {
        inPoint = NO;
        inLap = YES;

        if (!self.currentImportLap) {
            Lap *lap = [[Lap alloc] init];
            self.currentImportLap = lap;
            [lap release];
        }
        if (!self.currentImportLapArray) {
            NSMutableArray *arr = [[NSMutableArray alloc] init];
            self.currentImportLapArray = arr;
            [arr release];
        }
        return;
    }

    if ([elementName isEqualToString:@"startPoint"])
    {
        if (inLap && self.currentImportLap) {
            NSString *s = [attributeDict objectForKey:@"lat"];
            if (s) [self.currentImportLap setBeginLatitude:[s floatValue]];
            s = [attributeDict objectForKey:@"lon"];
            if (s) [self.currentImportLap setBeginLongitude:[s floatValue]];
        }
        return;
    }

    if ([elementName isEqualToString:@"endPoint"])
    {
        if (inLap && self.currentImportLap) {
            NSString *s = [attributeDict objectForKey:@"lat"];
            if (s) [self.currentImportLap setEndLatitude:[s floatValue]];
            s = [attributeDict objectForKey:@"lon"];
            if (s) [self.currentImportLap setEndLongitude:[s floatValue]];
        }
        return;
    }

    if ([elementName isEqualToString:@"summary"])
    {
        if (inLap && self.currentImportLap) {
            summarySetter = (tLapAvgMaxSetter)[[self class] instanceMethodForSelector:@selector(doNothing:)];
            NSString *kind = [attributeDict objectForKey:@"kind"];
            NSString *name = [attributeDict objectForKey:@"name"];
            if ([kind isEqualToString:@"avg"]) {
                if ([name isEqualToString:@"cadence"]) {
                    summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAverageCadence:)];
                } else if ([name isEqualToString:@"hr"]) {
                    summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAvgHeartRate:)];
                } else if ([name isEqualToString:@"power"]) {
                    // summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setAvgPower:)];
                }
            } else if ([kind isEqualToString:@"max"]) {
                if ([name isEqualToString:@"speed"]) {
                    summarySetter = (tLapAvgMaxSetter)[Lap instanceMethodForSelector:@selector(setMaxSpeed:)];
                }
            }
        }
        return;
    }

    if ([elementName isEqualToString:@"trigger"])
    {
        if (inLap && self.currentImportLap) {
            int val = 0;
            NSString *s = [attributeDict objectForKey:@"kind"];
            if ([s isEqualToString:@"manual"])        val = 0;
            else if ([s isEqualToString:@"distance"]) val = 1;
            else if ([s isEqualToString:@"location"]) val = 2;
            else if ([s isEqualToString:@"time"])     val = 3;
            else if ([s isEqualToString:@"heart_rate"]) val = 4;
            [self.currentImportLap setTriggerMethod:val];
        }
        return;
    }

    // Elements that carry character data
    if ([elementName isEqualToString:@"time"] ||
        [elementName isEqualToString:@"ele"]  ||
        [elementName isEqualToString:@"name"] ||
        [elementName isEqualToString:@"desc"])
    {
        [self resetCurrentString];
        return;
    }

    [self resetCurrentString];
}

- (void)parser:(NSXMLParser *)p foundCharacters:(NSString *)string
{
    (void)p;
    if (!self.currentStringValue) {
        NSMutableString *s = [[NSMutableString alloc] initWithCapacity:64];
        self.currentStringValue = s;
        [s release];
    }
    [self.currentStringValue appendString:string];
}

#pragma mark - Date prompt

- (NSDate *)getStartTime
{
    NSDate *dt = [NSDate date];
    NSString *tn = self.currentTrackName;
    if (!tn || [tn isEqualToString:@""]) tn = @"unknown";
    if (!self.activityStartDate) self.activityStartDate = [NSDate date];

    ImportDateEntryController *dec =
        [[ImportDateEntryController alloc] initWithTrackName:tn defaultDate:self.activityStartDate];

    NSRect fr = [[parentWindowController window] frame];
    NSRect dfr = [[dec window] frame];
    NSPoint origin;
    origin.x = fr.origin.x + fr.size.width/2.0 - dfr.size.width/2.0;
    origin.y = fr.origin.y + fr.size.height/2.0 - dfr.size.height/2.0;
    [[dec window] setFrameOrigin:origin];
    [dec showWindow:parentWindowController];

    BOOL contains = YES;
    while (contains)
    {
        [NSApp runModalForWindow:[dec window]];
        tDateEntryStatus sts = [dec entryStatus];
        if (sts == kCancelDateEntry)
        {
            [self.currentImportTrackArray removeAllObjects];
            [self.parser abortParsing];
            break;
        }
        else if (sts == kSkipDateEntry)
        {
            skipTrack = YES;
            break;
        }
        else
        {
            dt = [dec date];
            [self.currentImportTrack setCreationTime:dt];
            contains = ([self.currentImportTrackArray containsObject:self.currentImportTrack] ||
                        [importTrackArray containsObject:self.currentImportTrack]);
            if (contains)
            {
                NSString *nm = nil;
                NSUInteger idx = [self.currentImportTrackArray indexOfObject:self.currentImportTrack];
                if (idx != NSNotFound) {
                    nm = [[self.currentImportTrackArray objectAtIndex:idx] name];
                } else {
                    idx = [importTrackArray indexOfObject:self.currentImportTrack];
                    if (idx != NSNotFound) {
                        nm = [[importTrackArray objectAtIndex:idx] name];
                    }
                }
                NSString *msg = nm
                    ? [NSString stringWithFormat:@"An activity named %@ already exists with this date and time in the current document", nm]
                    : @"An activity already exists with this date and time in the current document";

                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Re-enter Date and Time"];
                [alert setMessageText:@"Invalid Activity Time"];
                [alert setInformativeText:msg];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert runModal];
                [alert release];
            }
        }
    }

    [[dec window] orderOut:[parentWindowController window]];
    [[parentWindowController window] makeKeyAndOrderFront:[dec window]];
    [dec release];

    return dt;
}

#pragma mark - NSXMLParserDelegate (end)

- (void)parser:(NSXMLParser *)p
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    (void)p; (void)namespaceURI; (void)qName;

    if ([elementName isEqualToString:@"trk"] ||
        [elementName isEqualToString:@"rte"])
    {
        if (self.currentImportTrack)
        {
            NSUInteger numPoints = [self.currentImportPointArray count];
            if ((numPoints > 0) && !skipTrack)
            {
                TrackPoint *pt = [self.currentImportPointArray objectAtIndex:numPoints-1];
                [self.currentImportTrack setCreationTime:self.activityStartDate];
                [self.currentImportTrack setDistance:[pt distance]];
                [self.currentImportTrack setPoints:self.currentImportPointArray];
                [self.currentImportTrack fixupTrack];

                if (self.currentActivity) {
                    [self.currentImportTrack setAttribute:kActivity usingString:self.currentActivity];
                }
                if (self.currentTrackName) {
                    [self.currentImportTrack setName:self.currentTrackName];
                    [self.currentImportTrack setAttribute:kName usingString:self.currentTrackName];
                }
                [self.currentImportTrackArray addObject:self.currentImportTrack];
            }

            // Clear for next segment
            self.currentImportPointArray = nil;
            self.currentImportTrack = nil;
        }

        inTrack = NO;
        self.currentTrackName = nil;
        return;
    }

    if ([elementName isEqualToString:@"trkseg"]) {
        return;
    }

    if ([elementName isEqualToString:@"trkpt"] ||
        [elementName isEqualToString:@"rtept"])
    {
        if (self.currentImportPoint)
        {
            if (inActivity)
            {
                NSUInteger num = [self.currentImportPointArray count];
                if (num > 1)
                {
                    TrackPoint *prevPt = [self.currentImportPointArray objectAtIndex:num-1];
                    float distance;

                    if (!distanceExtensionFound)
                    {
                        float ptDist = [Utils latLonToDistanceInMiles:[self.currentImportPoint latitude]
                                                                 lon1:[self.currentImportPoint longitude]
                                                                 lat2:[prevPt latitude]
                                                                 lon2:[prevPt longitude]];
                        distance = [prevPt distance] + ptDist;
                        [self.currentImportPoint setDistance:distance];
                        [self.currentImportPoint setOrigDistance:distance];
                    }
                    else
                    {
                        distance = [self.currentImportPoint distance];
                    }

                    float speed = [prevPt speed];
                    if (!pointsHaveTime)
                    {
                        [self.currentImportPoint setWallClockDelta:0.0];
                        [self.currentImportPoint setActiveTimeDelta:0.0];
                    }
                    NSTimeInterval now  = [self.currentImportPoint wallClockDelta];
                    NSTimeInterval prev = [prevPt wallClockDelta];
                    if (now > prev) {
                        speed = (distance) / ((now - prev) / (60.0 * 60.0));
                    }
                    [self.currentImportPoint setSpeed:speed];
                }
                else
                {
                    if (!pointsHaveTime)
                    {
                        if (!haveActivityStartTime)
                        {
                            NSDate *st = [self getStartTime];
                            [self setActivityStartDateIfNeeded:st];
                            haveActivityStartTime = YES;
                        }
                        [self.currentImportPoint setWallClockDelta:0.0];
                        [self.currentImportPoint setActiveTimeDelta:0.0];
                    }
                    [self.currentImportPoint setSpeed:0.0];
                    [self.currentImportPoint setDistance:0.0];
                }

                if ([Utils checkDataSanity:0.0
                                   latitude:(float)[self.currentImportPoint latitude]
                                  longitude:(float)[self.currentImportPoint longitude]
                                   altitude:(float)[self.currentImportPoint origAltitude]
                                  heartrate:(int)[self.currentImportPoint heartrate]
                                    cadence:(int)[self.currentImportPoint cadence]
                                temperature:(float)[self.currentImportPoint temperature]
                                      speed:(float)[self.currentImportPoint speed]
                                   distance:(float)[self.currentImportPoint distance]])
                {
                    float speed = [self.currentImportPoint speed];
                    if (!(IS_BETWEEN(kMinPossibleSpeed, speed, kMaxPossibleSpeed)))
                        [self.currentImportPoint setSpeed:0.0];

                    float altitude = [self.currentImportPoint origAltitude];
                    if (!(IS_BETWEEN(kMinPossibleAltitude, altitude, kMaxPossibleAltitude)))
                        [self.currentImportPoint setOrigAltitude:0.0];

                    [self.currentImportPointArray addObject:self.currentImportPoint];
                }
            }

            self.currentImportPoint = nil;
        }

        inPoint = NO;
        return;
    }

    if ([elementName isEqualToString:@"time"])
    {
        if (inPoint && inActivity && self.currentStringValue && (self.currentStringValue.length >= 20))
        {
            if (self.currentImportPoint)
            {
                pointsHaveTime = YES;
                NSDate *dt = [self dateFromTimeString:self.currentStringValue];
                if (!haveActivityStartTime) {
                    [self setActivityStartDateIfNeeded:dt];
                    haveActivityStartTime = YES;
                }
                [self.currentImportPoint setWallClockDelta:[dt timeIntervalSinceDate:self.activityStartDate]];
                [self.currentImportPoint setActiveTimeDelta:[dt timeIntervalSinceDate:self.activityStartDate]];
            }
        }
        [self resetCurrentString]; // keep style minimal; equivalent to [self resetCurrentString]
        return;
    }

    if ([elementName isEqualToString:@"ele"])
    {
        if (self.currentStringValue)
        {
            float val = MetersToFeet([self.currentStringValue floatValue]);
            if (self.currentImportPoint) {
                [self.currentImportPoint setOrigAltitude:val];
            }
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"gpxdata:hr"] ||
        [elementName isEqualToString:@"gpxtpx:hr"])
    {
        if (self.currentStringValue && self.currentImportPoint) {
            [self.currentImportPoint setHeartrate:[self.currentStringValue floatValue]];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"gpxdata:cadence"] ||
        [elementName isEqualToString:@"gpxtpx:cad"])
    {
        if (self.currentStringValue && self.currentImportPoint) {
            [self.currentImportPoint setCadence:[self.currentStringValue floatValue]];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"power"])
    {
        if (self.currentStringValue && self.currentImportPoint) {
            [self.currentImportPoint setPower:[self.currentStringValue floatValue]];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"gpxtpx:atemp"])
    {
        if (self.currentStringValue && self.currentImportPoint) {
            [self.currentImportPoint setTemperature:CelsiusToFahrenheight([self.currentStringValue floatValue])];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"gpxdata:distance"])
    {
        if (self.currentStringValue && self.currentImportPoint)
        {
            distanceExtensionFound = YES;
            float val = KilometersToMiles([self.currentStringValue floatValue] / 1000.0f);
            [self.currentImportPoint setDistance:val];
            [self.currentImportPoint setOrigDistance:val];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"name"])
    {
        if (self.currentStringValue)
        {
            if (inTrack && !inPoint)
            {
                NSRange r = [self.currentStringValue rangeOfString:@"![CDATA["];
                NSString *parsed = nil;
                if (r.location != NSNotFound) {
                    NSInteger len = (NSInteger)self.currentStringValue.length;
                    r.location += 8; r.length = len - 10;
                    parsed = [self.currentStringValue substringWithRange:r];
                } else {
                    parsed = self.currentStringValue;
                }
                self.currentTrackName = parsed; // property retains; no manual copy/retain
            }
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"gpxdata:lap"])
    {
        if (self.currentImportLap)
        {
            [self.currentImportLapArray addObject:self.currentImportLap];
            self.currentImportLap = nil;
        }
        inLap = NO;
        return;
    }

    if ([elementName isEqualToString:@"startTime"])
    {
        if (inLap && self.currentStringValue && (self.currentStringValue.length >= 20) && self.currentImportLap)
        {
            NSDate *dt = [self dateFromTimeString:self.currentStringValue];
            [self.currentImportLap setOrigStartTime:dt];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"elapsedTime"])
    {
        if (inLap && self.currentStringValue && self.currentImportLap)
        {
            [self.currentImportLap setTotalTime:[self.currentStringValue floatValue]];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"calories"])
    {
        if (inLap && self.currentStringValue && self.currentImportLap)
        {
            [self.currentImportLap setCalories:[self.currentStringValue intValue]];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"distance"])
    {
        if (inLap && self.currentStringValue && self.currentImportLap)
        {
            float val = KilometersToMiles([self.currentStringValue floatValue] / 1000.0f);
            [self.currentImportLap setDistance:val];
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"summary"])
    {
        if (inLap && self.currentStringValue && self.currentImportLap)
        {
            summarySetter(self.currentImportLap, nil, [self.currentStringValue intValue]);
        }
        [self resetCurrentString];
        return;
    }

    if ([elementName isEqualToString:@"trigger"] ||
        [elementName isEqualToString:@"intensity"])
    {
        if ([elementName isEqualToString:@"intensity"] &&
            inLap && self.currentStringValue && self.currentImportLap)
        {
            int val =  [self.currentStringValue isEqualToString:@"active"] ? 1 : 0;
            [self.currentImportLap setIntensity:val];
        }
        [self resetCurrentString];
        return;
    }
}

#pragma mark - Export (unchanged behavior, with correct releases)

- (NSString *)stringValueForTriggerMethod:(int)meth
{
    switch (meth) {
        case 1: return @"distance";
        case 2: return @"location";
        case 3: return @"time";
        case 4: return @"heart_rate";
        default: return @"manual";
    }
}

- (BOOL)exportTrack:(Track *)track
{
    NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"gpx"];
    NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSMutableString *me = [NSMutableString stringWithString:@"Ascent "];
    [me appendString:v ?: @""];

    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns" stringValue:@"http://www.topografix.com/GPX/1/1"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"version" stringValue:@"1.1"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"creator" stringValue:me]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns:xsi" stringValue:@"http://www.w3.org/2001/XMLSchema-instance"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns:gpxdata" stringValue:@"http://www.cluetrust.com/XML/GPXDATA/1/0"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xsi:schemaLocation"
                                         stringValue:@"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd"]];

    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
    [xmlDoc setVersion:@"1.0"];
    [xmlDoc setCharacterEncoding:@"UTF-8"];

    NSXMLElement *trk = [NSXMLNode elementWithName:@"trk"];

    NSString *s = [track attribute:kName];
    if (!s || [s isEqualToString:@""]) {
        NSMutableString *nm = [NSMutableString stringWithString:@"Activity on "];
        [nm appendString:[[track creationTime] description]];
        s = nm;
    }
    NSXMLElement *name = [NSXMLNode elementWithName:@"name" stringValue:s];
    [trk addChild:name];

    NSString *ds = [track name];
    if (ds && ![ds isEqualToString:@""]) {
        NSXMLElement *desc = [NSXMLNode elementWithName:@"desc" stringValue:ds];
        [trk addChild:desc];
    }

    NSXMLElement *trkseg = [NSXMLNode elementWithName:@"trkseg"];
    NSArray *pts = [track goodPoints];
    NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSUInteger num = [pts count];
    for (NSUInteger i = 0; i < num; i++)
    {
        TrackPoint *pt = [pts objectAtIndex:i];
        if ([pt validLatLon])
        {
            NSXMLElement *trkpt = [NSXMLNode elementWithName:@"trkpt"];
            [trkpt addAttribute:[NSXMLNode attributeWithName:@"lat"
                                                 stringValue:[NSString stringWithFormat:@"%1.8f",[pt latitude]]]];
            [trkpt addAttribute:[NSXMLNode attributeWithName:@"lon"
                                                 stringValue:[NSString stringWithFormat:@"%1.8f",[pt longitude]]]];

            float alt = FeetToMeters([pt origAltitude]);
            NSXMLElement *ele = [NSXMLNode elementWithName:@"ele"
                                               stringValue:[NSString stringWithFormat:@"%1.1f", alt]];
            [trkpt addChild:ele];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSString *dt = [[[track creationTime] addTimeInterval:[pt wallClockDelta]]
                            descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ"
                            timeZone:tz
                            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
#pragma clang diagnostic pop
            NSXMLElement *time = [NSXMLNode elementWithName:@"time" stringValue:dt];
            [trkpt addChild:time];

            // Extensions
            NSXMLElement *ext = [NSXMLNode elementWithName:@"extensions"];

            NSXMLElement *extChild = [NSXMLNode elementWithName:@"gpxdata:hr"
                                                     stringValue:[NSString stringWithFormat:@"%d", (int)([pt heartrate] + 0.5)]];
            [ext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"gpxdata:cadence"
                                       stringValue:[NSString stringWithFormat:@"%d", (int)([pt cadence] + 0.5)]];
            [ext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"gpxdata:distance"
                                       stringValue:[NSString stringWithFormat:@"%1.6f", (MilesToKilometers([pt distance]) * 1000.0)]];
            [ext addChild:extChild];

            [trkpt addChild:ext];
            [trkseg addChild:trkpt];
        }
    }
    [trk addChild:trkseg];
    [root addChild:trk];

    NSArray *laps = [track laps];
    NSUInteger numLaps = [laps count];
    if (numLaps > 0)
    {
        NSXMLElement *ext = [NSXMLNode elementWithName:@"extensions"];
        for (NSUInteger i = 0; i < numLaps; i++)
        {
            Lap *lap = [laps objectAtIndex:i];
            NSXMLElement *lapext = (NSXMLElement *)[NSXMLNode elementWithName:@"gpxdata:lap"];
            [lapext addAttribute:[NSXMLNode attributeWithName:@"xmlns"
                                                   stringValue:@"http://www.cluetrust.com/XML/GPXDATA/1/0"]];

            NSXMLElement *extChild = [NSXMLNode elementWithName:@"index"
                                                    stringValue:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"startPoint"];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"lat"
                                                     stringValue:[NSString stringWithFormat:@"%1.8f",[lap beginLatitude]]]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"lon"
                                                     stringValue:[NSString stringWithFormat:@"%1.8f",[lap beginLongitude]]]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"endPoint"];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"lat"
                                                     stringValue:[NSString stringWithFormat:@"%1.8f",[lap endLatitude]]]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"lon"
                                                     stringValue:[NSString stringWithFormat:@"%1.8f",[lap endLongitude]]]];
            [lapext addChild:extChild];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSString *st = [[lap origStartTime] descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ"
                                                                     timeZone:tz
                                                                       locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
#pragma clang diagnostic pop
            extChild = [NSXMLNode elementWithName:@"startTime" stringValue:st];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"elapsedTime"
                                       stringValue:[NSString stringWithFormat:@"%1.4f", [lap totalTime]]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"calories"
                                       stringValue:[NSString stringWithFormat:@"%1.0f", [track caloriesForLap:lap]]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"distance"
                                       stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track distanceOfLap:lap]) * 1000.0]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"summary"
                                       stringValue:[NSString stringWithFormat:@"%d", (int)[track avgHeartrateForLap:lap]]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"kind" stringValue:@"avg"]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:@"hr"]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"summary"
                                       stringValue:[NSString stringWithFormat:@"%d", (int)[track maxHeartrateForLap:lap atActiveTimeDelta:nil]]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"kind" stringValue:@"max"]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:@"hr"]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"summary"
                                       stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track maxSpeedForLap:lap atActiveTimeDelta:nil]) * 1000.0 / 3600.0]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"kind" stringValue:@"max"]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:@"speed"]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"summary"
                                       stringValue:[NSString stringWithFormat:@"%1.1f", [track avgCadenceForLap:lap]]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"kind" stringValue:@"avg"]];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:@"cadence"]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"trigger"];
            [extChild addAttribute:[NSXMLNode attributeWithName:@"kind"
                                                     stringValue:[self stringValueForTriggerMethod:[lap triggerMethod]]]];
            [lapext addChild:extChild];

            extChild = [NSXMLNode elementWithName:@"intensity"
                                       stringValue:[lap intensity] > 0 ? @"rest" : @"active"];
            [lapext addChild:extChild];

            [ext addChild:lapext];
        }
        [root addChild:ext];
    }

    NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
    BOOL ok = [xmlData writeToURL:self.xmlURL atomically:YES];
    if (!ok) {
        NSLog(@"Could not write GPX document out…");
    }
    [xmlDoc release];
    return ok;
}

@end
