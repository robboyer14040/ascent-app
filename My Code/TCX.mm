//
//  TCX.mm
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "TCX.h"
#import "Utils.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Defs.h"

#define DO_PARSING               1
#define TRACE_DEAD_ZONES         (ASCENT_DBG&&0)
#define BAD_VALUE               (-9999999.0f)

// Trim BOM/whitespace that can confuse NSXMLParser
static NSData *TCXStripLeadingJunk(NSData *data) {
    const uint8_t *b = (const uint8_t *)data.bytes;
    NSUInteger n = data.length, i = 0;

    // Skip UTF-8 BOM
    if (n >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) i = 3;

    // Skip leading whitespace
    while (i < n && (b[i] == 0x20 || b[i] == 0x09 || b[i] == 0x0D || b[i] == 0x0A)) i++;

    return (i > 0) ? [data subdataWithRange:NSMakeRange(i, n - i)] : data;
}

@interface TCX () {
    // Parse-time flags
    BOOL inHR;
    BOOL inPoint;
    BOOL inLap;
    BOOL inActivity;
    BOOL isHST;
    BOOL haveGoodAltitude;
    BOOL haveGoodDistance;
    BOOL haveGoodLatLon;
    BOOL haveGoodSpeed;
    BOOL haveGoodCadence;
    BOOL haveGoodHeartRate;
    BOOL haveGoodPower;
    BOOL isDeadMarker;
    BOOL inDeadZone;
    BOOL insertDeadZone;

    // Working model objects
    Track       *currentImportTrack;
    Lap         *currentImportLap;
    Lap         *lastLap;
    TrackPoint  *currentImportPoint;

    // Working collections
    NSMutableArray *currentImportLapArray;
    NSMutableArray *currentImportPointArray;
    NSMutableArray *currentImportTrackArray;

    // Scratch
    NSMutableString *currentStringValue;
    NSString        *currentActivity;

    // Inputs
    NSURL  *xmlURL;
    NSData *importData;

    // Timing helpers
    NSTimeInterval ignoreInterval;
    NSTimeInterval startDeadZoneWallClockDelta; // (kept for parity; not used directly here)
    NSDate *currentPointStartTime;
    NSDate *lastPointStartTime;
    NSDate *currentLapStartTime;
    NSDate *currentTrackStartTime;

    // Running stats
    float lastGoodDistance;
    float distanceSoFar;
    float lapStartDistance;
    float lapFirstDistance;
    float lastHeartRate;
    float lastCadence;
    float lastPower;
    float lastSpeed;
    float lastAltitude;
    float lastLatitude, lastLongitude;

    // Version/device metadata
    int numLapPoints;
    int numTracksWithinLap;
    int versionMajor, versionMinor, buildMajor, buildMinor;
    int tracksInLap;
}

// Setup
- (void)commonInit;

// Helpers
- (NSDate *)dateFromTimeString:(NSString *)ts;
- (void)setCurrentPointStartTime:(NSDate *)dt;
- (void)setLastPointStartTime:(NSDate *)dt;

// Export helpers
- (NSString *)utzStringFromDate:(NSDate *)dt gmtOffset:(NSTimeInterval)gmtOffset;
- (BOOL)validHR:(float)hr;
- (NSXMLElement *)TPXElement;
- (void)addTrackPoints:(Track *)track
        startTimeDelta:(NSTimeInterval)startTimeDelta
         startingIndex:(int)idx
               nextLap:(Lap *)nextLap
                  elem:(NSXMLElement *)lapElem;
- (NSXMLElement *)manufactureLap:(Track *)track;

@end

@implementation TCX

#pragma mark - Init / Dealloc

- (void)commonInit {
    importData = nil;
    xmlURL = nil;

    currentImportTrack = nil;
    currentImportLap = nil;
    lastLap = nil;
    currentImportPoint = nil;

    currentImportLapArray = nil;
    currentImportPointArray = nil;
    currentImportTrackArray = nil;

    currentStringValue = nil;
    currentActivity = nil;

    inHR = inPoint = inActivity = inLap = isHST = NO;
    haveGoodSpeed = haveGoodAltitude = haveGoodDistance = haveGoodLatLon = NO;
    haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
    isDeadMarker = inDeadZone = insertDeadZone = NO;

    distanceSoFar = 0.0f;
    lapStartDistance = 0.0f;
    lapFirstDistance = 0.0f;
    numLapPoints = 0;
    numTracksWithinLap = 0;
    versionMajor = versionMinor = buildMajor = buildMinor = 0;
    tracksInLap = 0;

    currentPointStartTime = nil;
    lastPointStartTime = nil;
    currentLapStartTime = nil;
    currentTrackStartTime = nil;

    ignoreInterval = 0.0;
    startDeadZoneWallClockDelta = 0.0;

    lastGoodDistance = 0.0f;
    lastSpeed = BAD_VALUE;
    lastAltitude = BAD_VALUE;
    lastLatitude = BAD_VALUE;
    lastLongitude = BAD_VALUE;
    lastHeartRate = BAD_VALUE;
    lastCadence = BAD_VALUE;
    lastPower = BAD_VALUE;
}

- (instancetype)initWithData:(NSData *)data {
    if ((self = [super init])) {
        [self commonInit];
        importData = [data retain];
    }
    return self;
}

- (instancetype)initWithFileURL:(NSURL *)url {
    if ((self = [super init])) {
        [self commonInit];
        xmlURL = [url copy]; // retain under MRC
    }
    return self;
}

- (void)dealloc {
    [currentImportTrack release];
    [currentImportLap release];
    [lastLap release];
    [currentImportPoint release];

    [currentImportLapArray release];
    [currentImportPointArray release];
    [currentImportTrackArray release];

    [currentStringValue release];
    [currentActivity release];

    [xmlURL release];
    [importData release];

    [currentPointStartTime release];
    [lastPointStartTime release];
    [currentLapStartTime release];
    [currentTrackStartTime release];

    [super dealloc];
}

#pragma mark - Public API

- (void)setCurrentActivity:(NSString *)a {
    if (a != currentActivity) {
        [currentActivity release];
        currentActivity = [a copy];
    }
}

- (BOOL)import:(NSMutableArray *)trackArray laps:(NSMutableArray *)lapArray {
    BOOL success = NO;

    // Fresh state for each import
    [currentImportTrackArray release]; currentImportTrackArray = nil;
    [currentImportLapArray release];   currentImportLapArray   = nil;
    [currentImportPointArray release]; currentImportPointArray = nil;

    [currentPointStartTime release]; currentPointStartTime = nil;
    [lastPointStartTime release];    lastPointStartTime    = nil;
    [currentLapStartTime release];   currentLapStartTime   = nil;
    [currentTrackStartTime release]; currentTrackStartTime = nil;

    [self setCurrentActivity:[Utils stringFromDefaults:RCBDefaultActivity]];

    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];

    NSData *bytes = importData ?: [NSData dataWithContentsOfURL:xmlURL];
    if (!bytes) { NSLog(@"TCX: no data to parse"); return NO; }

    // Reject compressed payloads (caller should decompress first)
    const uint8_t *p = (const uint8_t *)bytes.bytes;
    if (bytes.length >= 2 &&
        ((p[0] == 0x50 && p[1] == 0x4B) /* ZIP */ ||
         (p[0] == 0x1F && p[1] == 0x8B) /* GZIP */)) {
        NSLog(@"TCX appears compressed (ZIP/GZIP); decompress first.");
        return NO;
    }

    NSData *trimmed = TCXStripLeadingJunk(bytes);
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:trimmed];
    [parser setDelegate:self];
    [parser setShouldResolveExternalEntities:NO];

    BOOL ok = [parser parse];
    if (!ok) {
        NSError *err = [parser parserError];
        NSLog(@"TCX parse failed: code=%ld line=%ld col=%ld msg=%@",
              (long)err.code, (long)parser.lineNumber, (long)parser.columnNumber,
              err.localizedDescription ?: @"(no message)");
        [parser release];
        return NO;
    }
    [parser release];

    if (currentImportTrackArray) {
        [trackArray addObjectsFromArray:currentImportTrackArray];
        [currentImportTrackArray release];
        currentImportTrackArray = nil;
    }
    if (currentImportLapArray && lapArray) {
        [lapArray addObjectsFromArray:currentImportLapArray];
        [currentImportLapArray release];
        currentImportLapArray = nil;
    }
    [currentImportPointArray release]; currentImportPointArray = nil;

    success = YES;
    return success;
}

- (BOOL)export:(NSArray *)trackArray {
    NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"TrainingCenterDatabase"];
    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns"
                                        stringValue:@"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns:xsi"
                                        stringValue:@"http://www.w3.org/2001/XMLSchema-instance"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xsi:schemaLocation"
                                        stringValue:@"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd"]];

    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
    [xmlDoc setVersion:@"1.0"];
    [xmlDoc setCharacterEncoding:@"UTF-8"];

    NSUInteger count = [trackArray count];
    NSXMLElement *folders = [NSXMLNode elementWithName:@"Folders"];
    [root addChild:folders];

    NSXMLElement *activities = [NSXMLNode elementWithName:@"Activities"];
    for (NSUInteger i = 0; i < count; i++) {
        Track *track = [trackArray objectAtIndex:i];
        NSTimeInterval gmtOffset = [track secondsFromGMT];

        NSXMLElement *activity = [NSXMLNode elementWithName:@"Activity"];
        NSString *atype = @"Other";
        NSString *s = [track attribute:kActivity];

        BOOL isBiking = NO;
        if (s) {
            NSRange r;
            r = [s rangeOfString:@"Biking"];       isBiking |= (r.location != NSNotFound);
            r = [s rangeOfString:@"Bike"];         isBiking |= (r.location != NSNotFound);
            r = [s rangeOfString:@"Cycling"];      isBiking |= (r.location != NSNotFound);
            r = [s rangeOfString:@"Cyclo"];        isBiking |= (r.location != NSNotFound);
        }
        if (isBiking || [s isEqualToString:[NSString stringWithUTF8String:kCycling]]) {
            atype = @"Biking";
        } else if ([s isEqualToString:[NSString stringWithUTF8String:kRunning]]) {
            atype = @"Running";
        }

        [activity addAttribute:[NSXMLNode attributeWithName:@"Sport" stringValue:atype]];

        NSXMLElement *aid = [NSXMLNode elementWithName:@"Id"
                                           stringValue:[self utzStringFromDate:[track creationTime]
                                                                     gmtOffset:gmtOffset]];
        [activity addChild:aid];

        NSArray *lapArray = [track laps];
        NSUInteger numLaps = [lapArray count];
        NSXMLElement *elem = nil;
        int idx = 0;

        if (numLaps > 0) {
            for (NSUInteger lapIdx = 0; lapIdx < numLaps; lapIdx++) {
                Lap *lap = [lapArray objectAtIndex:lapIdx];
                Lap *nextLap = (lapIdx + 1 < numLaps) ? [lapArray objectAtIndex:(lapIdx + 1)] : nil;

                [track calculateLapStats:lap];

                NSXMLElement *lapElem = [NSXMLNode elementWithName:@"Lap"];
                [lapElem addAttribute:[NSXMLNode attributeWithName:@"StartTime"
                                                        stringValue:[self utzStringFromDate:[track lapStartTime:lap]
                                                                                  gmtOffset:gmtOffset]]];

                elem = [NSXMLNode elementWithName:@"TotalTimeSeconds"
                                       stringValue:[NSString stringWithFormat:@"%1.6f", [lap deviceTotalTime]]];
                [lapElem addChild:elem];

                float miles = [track distanceOfLap:lap];
                elem = [NSXMLNode elementWithName:@"DistanceMeters"
                                       stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers(miles)*1000.0]];
                [lapElem addChild:elem];

                // max speed in m/sec
                struct tStatData *statData = [lap getStat:kST_MovingSpeed];
                elem = [NSXMLNode elementWithName:@"MaximumSpeed"
                                       stringValue:[NSString stringWithFormat:@"%1.6f",
                                                    MilesToKilometers(statData->vals[kMax])*1000.0/3600.0]];
                [lapElem addChild:elem];

                elem = [NSXMLNode elementWithName:@"Calories"
                                       stringValue:[NSString stringWithFormat:@"%d", [lap calories]]];
                [lapElem addChild:elem];

                statData = [lap getStat:kST_Heartrate];
                float avghr = statData->vals[kAvg];
                NSXMLElement *hrElem;
                if ([self validHR:avghr]) {
                    hrElem = [NSXMLNode elementWithName:@"AverageHeartRateBpm"];
                    [hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
                                                           stringValue:@"HeartRateInBeatsPerMinute_t"]];
                    elem = [NSXMLNode elementWithName:@"Value"
                                           stringValue:[NSString stringWithFormat:@"%1.0f", avghr]];
                    [hrElem addChild:elem];
                    [lapElem addChild:hrElem];
                }

                float maxhr = statData->vals[kMax];
                if ([self validHR:maxhr]) {
                    hrElem = [NSXMLNode elementWithName:@"MaximumHeartRateBpm"];
                    [hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
                                                           stringValue:@"HeartRateInBeatsPerMinute_t"]];
                    elem = [NSXMLNode elementWithName:@"Value"
                                           stringValue:[NSString stringWithFormat:@"%1.0f", maxhr]];
                    [hrElem addChild:elem];
                    [lapElem addChild:hrElem];
                }

                elem = [NSXMLNode elementWithName:@"Intensity"
                                       stringValue:([lap intensity] == 0 ? @"Active" : @"Resting")];
                [lapElem addChild:elem];

                statData = [lap getStat:kST_Cadence];
                elem = [NSXMLNode elementWithName:@"Cadence"
                                       stringValue:[NSString stringWithFormat:@"%1.0f", statData->vals[kAvg]]];
                [lapElem addChild:elem];

                elem = [NSXMLNode elementWithName:@"TriggerMethod" stringValue:@"Manual"];
                [lapElem addChild:elem];

                // Trackpoint data for lap
                int delta = (lapIdx == 0) ? 0 : [lap startingWallClockTimeDelta];
                idx = [track findFirstPointAtOrAfterDelta:delta startAt:idx];
                [self addTrackPoints:track
                      startTimeDelta:delta
                       startingIndex:idx
                             nextLap:nextLap
                                elem:lapElem];

                [activity addChild:lapElem];
            }
        } else {
            // No laps: synthesize a single lap
            NSXMLElement *lapElem = [self manufactureLap:track];
            [self addTrackPoints:track startTimeDelta:0 startingIndex:idx nextLap:nil elem:lapElem];
            [activity addChild:lapElem];
        }

        NSString *notes = [track attribute:kNotes];
        if (notes && ![notes isEqualToString:@""]) {
            NSXMLElement *n = [NSXMLNode elementWithName:@"Notes" stringValue:notes];
            [activity addChild:n];
        }

        int deviceID = [track deviceID];
        if (deviceID != 0) {
            NSString *deviceName = [Utils deviceNameForID:deviceID];
            if (deviceName) {
                NSXMLElement *el = [NSXMLNode elementWithName:@"Creator"];
                [el addAttribute:[NSXMLNode attributeWithName:@"xsi:type" stringValue:@"Device_t"]];

                NSXMLElement *e = [NSXMLNode elementWithName:@"Name" stringValue:deviceName];
                [el addChild:e];

                e = [NSXMLNode elementWithName:@"UnitId" stringValue:[NSString stringWithFormat:@"%d", 0]];
                [el addChild:e];

                e = [NSXMLNode elementWithName:@"ProductID" stringValue:[NSString stringWithFormat:@"%d", deviceID]];
                [el addChild:e];

                NSXMLElement *vel = [NSXMLNode elementWithName:@"Version"];
                int version = [track firmwareVersion];
                e = [NSXMLNode elementWithName:@"VersionMajor" stringValue:[NSString stringWithFormat:@"%d", version/100]];
                [vel addChild:e];
                e = [NSXMLNode elementWithName:@"VersionMinor" stringValue:[NSString stringWithFormat:@"%d", version%100]];
                [vel addChild:e];
                e = [NSXMLNode elementWithName:@"BuildMajor" stringValue:@"0"];
                [vel addChild:e];
                e = [NSXMLNode elementWithName:@"BuildMinor" stringValue:@"0"];
                [vel addChild:e];

                [el addChild:vel];
                [activity addChild:el];
            }
        }

        [activities addChild:activity];
    }

    [root addChild:activities];

    NSXMLElement *auth = [NSXMLNode elementWithName:@"Author"];
    [auth addAttribute:[NSXMLNode attributeWithName:@"xsi:type" stringValue:@"Application_t"]];
    NSXMLElement *elem = [NSXMLNode elementWithName:@"Name" stringValue:@"Ascent"];
    [auth addChild:elem];

    NSXMLElement *bld = [NSXMLNode elementWithName:@"Build"];
    NSXMLElement *ver = [NSXMLNode elementWithName:@"Version"];

    NSString *vmaj = @"0", *vmin = @"0", *bmaj = @"0";
    NSString *vs = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (vs) {
        NSArray *vItems = [vs componentsSeparatedByString:@"."];
        if ([vItems count] >= 3) {
            vmaj = [vItems objectAtIndex:0];
            vmin = [vItems objectAtIndex:1];
            NSArray *bItems = [[vItems objectAtIndex:2] componentsSeparatedByString:@" "];
            if ([bItems count] > 0) bmaj = [bItems objectAtIndex:0];
        }
    }
    elem = [NSXMLNode elementWithName:@"VersionMajor" stringValue:vmaj]; [ver addChild:elem];
    elem = [NSXMLNode elementWithName:@"VersionMinor" stringValue:vmin]; [ver addChild:elem];
    elem = [NSXMLNode elementWithName:@"BuildMajor"  stringValue:bmaj];  [ver addChild:elem];
    elem = [NSXMLNode elementWithName:@"BuildMinor"  stringValue:@"0"];  [ver addChild:elem];

    [bld addChild:ver];
    elem = [NSXMLNode elementWithName:@"Type" stringValue:@"Release"]; [bld addChild:elem];
    elem = [NSXMLNode elementWithName:@"Time" stringValue:[NSString stringWithFormat:@"%s, %s", __DATE__, __TIME__]];
    [bld addChild:elem];
    elem = [NSXMLNode elementWithName:@"Builder" stringValue:@"xcode"]; [bld addChild:elem];

    [auth addChild:bld];
    elem = [NSXMLNode elementWithName:@"LangID" stringValue:@"en"]; [auth addChild:elem];
    elem = [NSXMLNode elementWithName:@"PartNumber" stringValue:@"000-00000-00"]; [auth addChild:elem];

    [root addChild:auth];

    NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLDocumentXMLKind];
    BOOL wrote = [xmlData writeToURL:xmlURL atomically:YES];
    if (!wrote) {
        NSLog(@"TCX export: Could not write document.");
        [xmlDoc release];
        return NO;
    }
    [xmlDoc release];
    return YES;
}

#pragma mark - Helpers

- (NSDate *)dateFromTimeString:(NSString *)ts {
    if ([ts length] < 20) return [NSDate date];

    NSRange r = NSMakeRange(0, 10);
    NSString *sub = [ts substringWithRange:r];
    NSMutableString *d = [NSMutableString stringWithString:sub];

    r = NSMakeRange(11, 8);
    NSString *t = [ts substringWithRange:r];

    [d appendString:@" "];
    [d appendString:t];
    [d appendString:@" +0000"];

    return [NSDate dateWithString:d];
}

- (void)setCurrentPointStartTime:(NSDate *)dt {
    if (dt != currentPointStartTime) {
        [currentPointStartTime release];
        currentPointStartTime = [dt retain];
    }
}

- (void)setLastPointStartTime:(NSDate *)dt {
    if (dt != lastPointStartTime) {
        [lastPointStartTime release];
        lastPointStartTime = [dt retain];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)err {
    NSLog(@"TCX XML parse error %ld at line %ld col %ld: %@",
          (long)err.code, (long)[parser lineNumber], (long)[parser columnNumber],
          err.localizedDescription ?: @"(no message)");
}

- (NSString *)utzStringFromDate:(NSDate *)dt gmtOffset:(NSTimeInterval)gmtOffset {
    NSDate *gmtDate = [[[NSDate alloc] initWithTimeInterval:-gmtOffset sinceDate:dt] autorelease];
    // Using deprecated 10.8 API to match legacy code. Safe in this codebase.
    NSString *s = [gmtDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ" timeZone:nil locale:nil];
    return s;
}

- (BOOL)validHR:(float)hr {
    return (hr > 1.0f && hr < 254.0f);
}

- (NSXMLElement *)TPXElement {
    NSXMLElement *tpxElem = [NSXMLNode elementWithName:@"TPX"];
    [tpxElem addAttribute:[NSXMLNode attributeWithName:@"xmlns"
                                           stringValue:@"http://www.garmin.com/xmlschemas/ActivityExtension/v2"]];
    return tpxElem;
}

#pragma mark - NSXMLParser Delegate (start)

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
    BOOL isActivity = [elementName isEqualToString:@"Activity"] || [elementName isEqualToString:@"Course"];
    if (isActivity || [elementName isEqualToString:@"Run"]) { // hst
#if DO_PARSING
        versionMajor = versionMinor = buildMajor = buildMinor = 0;
        inDeadZone = NO;
        inActivity = YES;
        inPoint = NO;
        haveGoodSpeed = haveGoodAltitude = haveGoodDistance = haveGoodLatLon = NO;
        haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
        [currentTrackStartTime release]; currentTrackStartTime = nil;
        [currentLapStartTime release];   currentLapStartTime   = nil;
        [currentPointStartTime release]; currentPointStartTime = nil;
        ignoreInterval = 0.0;
        lastGoodDistance = 0.0f;
        lastSpeed = BAD_VALUE;
        lastAltitude = lastLatitude = lastLongitude = lastHeartRate = lastCadence = lastPower = BAD_VALUE;

        if (!currentImportTrack) {
            currentImportTrack = [[Track alloc] init];
        }
        if (!currentImportTrackArray) {
            currentImportTrackArray = [[NSMutableArray alloc] init];
        }

        if (isActivity) {
            NSString *sport = [attributeDict objectForKey:@"Sport"];
            if (sport) {
                if ([sport isEqualToString:@"Biking"]) {
                    [self setCurrentActivity:[NSString stringWithFormat:@"%s", kCycling]];
                } else if ([sport isEqualToString:@"Running"]) {
                    [self setCurrentActivity:[NSString stringWithFormat:@"%s", kRunning]];
                }
            } else {
                isHST = YES;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Lap"]) {
#if DO_PARSING
        inPoint = NO;
        inLap = YES;
        insertDeadZone = NO;
        numLapPoints = 0;
        lapStartDistance = 0.0f;
        lapFirstDistance = 0.0f;
        [currentLapStartTime release]; currentLapStartTime = nil;
        numTracksWithinLap = 0;
        tracksInLap = 0;

        if (!currentImportLap) {
            currentImportLap = [[Lap alloc] init];
        }
        if (!currentImportLapArray) {
            currentImportLapArray = [[NSMutableArray alloc] init];
        }

        NSString *st = [attributeDict objectForKey:@"StartTime"];
        if (st) {
            currentLapStartTime = [[self dateFromTimeString:st] retain];
            if (!currentTrackStartTime) {
                currentTrackStartTime = [currentLapStartTime retain];
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Trackpoint"]) {
#if DO_PARSING
        [currentPointStartTime release]; currentPointStartTime = nil;
        inPoint = YES;
        isDeadMarker = YES;
        if (!currentImportPoint) currentImportPoint = [[TrackPoint alloc] init];
        if (!currentImportPointArray) currentImportPointArray = [[NSMutableArray alloc] init];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Time"]) {
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Running"]) { // hst
#if DO_PARSING
        [self setCurrentActivity:[NSString stringWithFormat:@"%s", kRunning]];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Biking"]) { // hst
#if DO_PARSING
        [self setCurrentActivity:[NSString stringWithFormat:@"%s", kCycling]];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Track"]) {
        ++tracksInLap;
        if (tracksInLap > 1) insertDeadZone = YES;
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Value"] ||
        [elementName isEqualToString:@"AltitudeMeters"] ||
        [elementName isEqualToString:@"DistanceMeters"] ||
        [elementName isEqualToString:@"LatitudeDegrees"] ||
        [elementName isEqualToString:@"LongitudeDegrees"] ||
        [elementName isEqualToString:@"Cadence"] ||
        [elementName isEqualToString:@"AvgRunCadence"] ||
        [elementName isEqualToString:@"MaxRunCadence"] ||
        [elementName isEqualToString:@"MaxBikeCadence"] ||
        [elementName isEqualToString:@"TotalTimeSeconds"] ||
        [elementName isEqualToString:@"Calories"] ||
        [elementName isEqualToString:@"Speed"] ||
        [elementName isEqualToString:@"AvgSpeed"] ||
        [elementName isEqualToString:@"ProductID"] ||
        [elementName isEqualToString:@"AverageHeartRateBpm"] ||
        [elementName isEqualToString:@"MaximumHeartRateBpm"] ||
        [elementName isEqualToString:@"Intensity"] ||
        [elementName isEqualToString:@"TriggerMethod"] ||
        [elementName isEqualToString:@"MaximumSpeed"]) {
#if DO_PARSING
        isDeadMarker = NO;
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    [currentStringValue release]; currentStringValue = nil;
}

#pragma mark - NSXMLParser Delegate (chars)

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
#if DO_PARSING
    if (!currentStringValue) currentStringValue = [[NSMutableString alloc] init];
    [currentStringValue appendString:string];
#endif
}

#pragma mark - NSXMLParser Delegate (end)

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"Activity"] ||
        [elementName isEqualToString:@"Course"] ||
        [elementName isEqualToString:@"Run"]) { // hst
#if DO_PARSING
        if (currentImportTrack) {
            NSUInteger numPoints = [currentImportPointArray count];
            if (!currentTrackStartTime) {
                currentTrackStartTime = [[NSDate date] retain];
            }
            [currentImportTrack setCreationTime:currentTrackStartTime];

            if (numPoints > 0) {
                [currentImportTrack setDistance:lastGoodDistance];
                [currentImportTrack setPoints:currentImportPointArray];
            } else {
                NSUInteger numLaps = [currentImportLapArray count];
                if (numLaps > 0) {
                    NSNumber *totalDist = [currentImportLapArray valueForKeyPath:@"@sum.distance"];
                    [currentImportTrack setDistance:[totalDist floatValue]];
                    if (!currentTrackStartTime) {
                        currentTrackStartTime = [[[currentImportLapArray objectAtIndex:0] origStartTime] retain];
                        [currentImportTrack setCreationTime:currentTrackStartTime];
                    }
                }
            }

            [currentImportTrack setFirmwareVersion:(versionMajor * 100) + (versionMinor)];
            [currentImportTrack setHasDeviceTime:YES];
            if (currentActivity) [currentImportTrack setAttribute:kActivity usingString:currentActivity];
            [currentImportTrack fixupTrack];

            if (lastLap) {
                NSTimeInterval lapWallClockDuration;
                if ([lastLap distance] == 0.0) {
                    lapWallClockDuration = [lastLap deviceTotalTime];
                } else {
                    lapWallClockDuration = [currentImportTrack duration] - [lastLap startingWallClockTimeDelta];
                }
                [lastLap setTotalTime:lapWallClockDuration];
                [lastLap release]; lastLap = nil;
            }

            [currentImportTrack setLaps:currentImportLapArray]; // fixup before adding laps (matches original semantics)

            [currentImportTrackArray addObject:currentImportTrack];
            [currentImportTrack release]; currentImportTrack = nil;

            [currentImportPointArray release]; currentImportPointArray = nil;
            [currentImportLapArray release]; currentImportLapArray = nil;

            [self setCurrentPointStartTime:nil];
            [self setLastPointStartTime:nil];
        }
#endif
        inActivity = NO;
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Lap"]) {
#if DO_PARSING
        if (currentImportLap) {
            if (!currentTrackStartTime && currentLapStartTime) {
                currentTrackStartTime = [currentLapStartTime retain];
                [currentImportTrack setCreationTime:currentTrackStartTime];
            }
            if (currentLapStartTime) {
                [currentImportLap setOrigStartTime:currentLapStartTime];
                [currentImportLap setStartingWallClockTimeDelta:[currentLapStartTime timeIntervalSinceDate:currentTrackStartTime]];
            }

            if (lastLap) {
                NSTimeInterval lapWallClockDuration;
                if ([lastLap distance] == 0.0) {
                    lapWallClockDuration = [lastLap deviceTotalTime];
                } else {
                    lapWallClockDuration = [currentImportLap startingWallClockTimeDelta] - [lastLap startingWallClockTimeDelta];
                }
                [lastLap setTotalTime:lapWallClockDuration];
                [lastLap release]; lastLap = nil;
            }

            if (inActivity) {
                [currentImportLapArray addObject:currentImportLap];
            }
            lastLap = currentImportLap; // keep (not retained additionally; we will release when replaced)
            [lastLap retain];           // balance ownership since we nil out currentImportLap
            [currentImportLap release]; currentImportLap = nil;
        }
#endif
        inLap = NO;
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Notes"]) {
#if DO_PARSING
        if (inActivity && currentStringValue) {
            [currentImportTrack setAttribute:kNotes usingString:currentStringValue];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Name"]) {
#if DO_PARSING
        if (inActivity && currentStringValue) {
            [currentImportTrack setAttribute:kName usingString:currentStringValue];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Trackpoint"]) {
#if DO_PARSING
        if ((!lastPointStartTime) || [lastPointStartTime compare:currentPointStartTime] == NSOrderedAscending) {
            if (currentImportPoint && inActivity) {
                NSTimeInterval wallClockDelta = [currentPointStartTime timeIntervalSinceDate:currentTrackStartTime];
                [currentImportPoint setActiveTimeDelta:wallClockDelta];

                if (!isDeadMarker) {
                    if (!haveGoodAltitude) {
                        float v = (lastAltitude == BAD_VALUE) ? BAD_ALTITUDE : lastAltitude;
                        [currentImportPoint setOrigAltitude:v];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingAltitude state:!haveGoodAltitude];

                    if (!haveGoodDistance) {
                        float v = (lastGoodDistance == BAD_VALUE) ? BAD_DISTANCE : lastGoodDistance;
                        [currentImportPoint setOrigDistance:v];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingDistance state:!haveGoodDistance];

                    if (!haveGoodLatLon) {
                        float v = (lastLatitude == BAD_VALUE) ? BAD_LATLON : lastLatitude;
                        [currentImportPoint setLatitude:v];
                        v = (lastLongitude == BAD_VALUE) ? BAD_LATLON : lastLongitude;
                        [currentImportPoint setLongitude:v];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingLocation state:!haveGoodLatLon];

                    [currentImportPoint setImportFlagState:kImportFlagMissingPower state:!haveGoodPower];

                    if (lastHeartRate != BAD_VALUE) {
                        [currentImportPoint setHeartrate:(int)lastHeartRate];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingHeartRate state:!haveGoodHeartRate];

                    if (lastCadence != BAD_VALUE) {
                        [currentImportPoint setCadence:(int)lastCadence];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingCadence state:!haveGoodCadence];

                    if (lastSpeed != BAD_VALUE) {
                        [currentImportPoint setSpeed:lastSpeed];
                        [currentImportPoint setSpeedOverriden:YES];
                    }
                    [currentImportPoint setImportFlagState:kImportFlagMissingSpeed state:!haveGoodSpeed];

                } else {
#if TRACE_DEAD_ZONES
                    NSLog(@" == DEAD MARKER at %@", currentPointStartTime);
#endif
                }

                ++numLapPoints;
                [currentImportPoint setWallClockDelta:wallClockDelta];

                NSTimeInterval dt = [currentPointStartTime timeIntervalSinceDate:lastPointStartTime];
#define MAX_POINT_TIME_DELTA 600.0
                if (insertDeadZone || (dt > MAX_POINT_TIME_DELTA)) {
                    if ([currentImportPointArray count] > 0) {
                        TrackPoint *lastPoint = [currentImportPointArray lastObject];
                        while ([currentImportPointArray count] && [lastPoint importFlagState:kImportFlagDeadZoneMarker]) {
                            [currentImportPointArray removeLastObject];
                            lastPoint = [currentImportPointArray lastObject];
                        }
#if TRACE_DEAD_ZONES
                        NSString *s = insertDeadZone ? @"NEW TRACK" : @"LARGE DELTA TIME BETWEEN POINTS";
                        NSLog(@"Lap %lu: %@, INSERTING DEAD ZONE (%0.1f seconds) AT %@ (%0.1f seconds)",
                              (unsigned long)[currentImportLapArray count] + 1, s, dt, currentPointStartTime, wallClockDelta);
#endif
                        // BEGIN DEAD ZONE
                        NSTimeInterval lastWCD = [lastPoint wallClockDelta];
                        NSTimeInterval lastATD = [lastPoint activeTimeDelta];
                        TrackPoint *pt = [[TrackPoint alloc] initWithDeadZoneMarker:lastWCD activeTimeDelta:lastATD];
                        [pt setBeginningOfDeadZone];
                        [pt setImportFlagState:kImportFlagDeadZoneMarker state:YES];
                        [currentImportPointArray addObject:pt];
                        [pt release];

                        // END DEAD ZONE
                        pt = [[TrackPoint alloc] initWithDeadZoneMarker:wallClockDelta activeTimeDelta:lastATD];
                        [pt setEndOfDeadZone];
                        [pt setImportFlagState:kImportFlagDeadZoneMarker state:YES];
                        [currentImportPointArray addObject:pt];
                        [pt release];
                    }
                    if (insertDeadZone) insertDeadZone = NO;
                }

                [currentImportPointArray addObject:currentImportPoint];
                [self setLastPointStartTime:currentPointStartTime];
            }
        }
        [currentImportPoint release]; currentImportPoint = nil;
        haveGoodAltitude = haveGoodDistance = haveGoodLatLon = haveGoodSpeed = NO;
        haveGoodHeartRate = haveGoodCadence = haveGoodPower = NO;
        inPoint = NO;
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Track"]) {
        if (tracksInLap > 1) insertDeadZone = YES;
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Time"]) {
#if DO_PARSING
        if (inPoint && inActivity && currentStringValue && [currentStringValue length] >= 20) {
            if (currentImportPoint) {
                NSDate *dt = [self dateFromTimeString:currentStringValue];
                [self setCurrentPointStartTime:dt];
                if (!inLap && !currentTrackStartTime) {
                    currentTrackStartTime = [currentPointStartTime retain];
                }
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"HeartRateBpm"]) {
#if DO_PARSING
        if (currentStringValue) {
            float hr = [currentStringValue intValue];
            if (currentImportPoint) {
                lastHeartRate = hr;
                haveGoodHeartRate = YES;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Speed"] || [elementName isEqualToString:@"ns3:Speed"]) {
#if DO_PARSING
        if (currentStringValue) {
            float spd = [currentStringValue floatValue];
            if (currentImportPoint) {
                spd = (MetersToMiles(spd)) * (60.0f * 60.0f);
                lastSpeed = spd;
                haveGoodSpeed = YES;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"ProductID"]) {
#if DO_PARSING
        if (currentStringValue) {
            int prodID = [currentStringValue intValue];
            [currentImportTrack setDeviceID:prodID];
            if ((prodID == PROD_ID_310XT) || (prodID == PROD_ID_FR60)) {
                [currentImportTrack setUseOrigDistance:YES];
                [currentImportTrack setHasExplicitDeadZones:YES];
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"VersionMajor"]) {
#if DO_PARSING
        if (currentStringValue) versionMajor = [currentStringValue intValue];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"VersionMinor"]) {
#if DO_PARSING
        if (currentStringValue) versionMinor = [currentStringValue intValue];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"BuildMajor"]) {
#if DO_PARSING
        if (currentStringValue) buildMajor = [currentStringValue intValue];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"BuildMinor"]) {
#if DO_PARSING
        if (currentStringValue) buildMinor = [currentStringValue intValue];
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"DistanceMeters"]) {
#if DO_PARSING
        if (currentStringValue) {
            float val = KilometersToMiles([currentStringValue floatValue] / 1000.0f);
            if (inPoint && currentImportPoint) {
                if ((numLapPoints == 0) || ((val == 0.0f) && (lastGoodDistance > 0.0f))) {
                    lapStartDistance = (val == 0.0f) ? lastGoodDistance : val;
                    lapFirstDistance = val;
                }
                ++numLapPoints;
                distanceSoFar = lapStartDistance + (val - lapFirstDistance);
                [currentImportPoint setOrigDistance:distanceSoFar];
                haveGoodDistance = YES;
                lastGoodDistance = distanceSoFar;
            } else if (inLap && currentImportLap) {
                [currentImportLap setDistance:val];
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"AltitudeMeters"]) {
#if DO_PARSING
        if (currentStringValue) {
            float val = MetersToFeet([currentStringValue floatValue]);
            if (currentImportPoint) {
                [currentImportPoint setOrigAltitude:val];
                haveGoodAltitude = YES;
                lastAltitude = val;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"LatitudeDegrees"]) {
#if DO_PARSING
        if (currentStringValue) {
            float val = [currentStringValue floatValue];
            if (currentImportPoint) {
                [currentImportPoint setLatitude:val];
                lastLatitude = val;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"LongitudeDegrees"]) {
#if DO_PARSING
        if (currentStringValue) {
            float val = [currentStringValue floatValue];
            if (currentImportPoint) {
                [currentImportPoint setLongitude:val];
                haveGoodLatLon = YES;
                lastLongitude = val;
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Watts"] || [elementName isEqualToString:@"ns3:Watts"]) {
#if DO_PARSING
        if (currentStringValue && currentImportPoint) {
#if _DEBUG
            if ([currentStringValue intValue] > MAX_REASONABLE_POWER) {
                printf("power value:%d, wtf?\n", [currentStringValue intValue]);
            }
#endif
            [currentImportPoint setPower:[currentStringValue intValue]];
            haveGoodPower = YES;
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Cadence"] || [elementName isEqualToString:@"RunCadence"]) {
#if DO_PARSING
        if (currentStringValue) {
            int val = [currentStringValue intValue];
            if (inPoint && currentImportPoint) {
                haveGoodCadence = YES;
                lastCadence = (float)val;
                if ([elementName isEqualToString:@"RunCadence"]) {
                    [currentImportPoint setImportFlagState:kImportFlagHasFootpod state:YES];
                }
            } else if (inLap && currentImportLap) {
                [currentImportLap setAverageCadence:val];
            }
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"AvgRunCadence"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setAverageCadence:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"AvgSpeed"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setAvgSpeed:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"MaxRunCadence"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setMaxCadence:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"MaxBikeCadence"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setMaxCadence:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"TotalTimeSeconds"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setDeviceTotalTime:[currentStringValue floatValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"MaximumSpeed"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            float val = [currentStringValue floatValue]; // m/s
            val = (val * 60.0f * 60.0f) / 1609.344f;     // mph
            [currentImportLap setMaxSpeed:val];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Calories"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setCalories:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"AverageHeartRateBpm"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setAvgHeartRate:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"MaximumHeartRateBpm"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setMaxHeartRate:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"Intensity"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setIntensity:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    if ([elementName isEqualToString:@"TriggerMethod"]) {
#if DO_PARSING
        if (currentStringValue && currentImportLap) {
            [currentImportLap setTriggerMethod:[currentStringValue intValue]];
        }
#endif
        [currentStringValue release]; currentStringValue = nil;
        return;
    }

    // Default: clean current string
    [currentStringValue release]; currentStringValue = nil;
}

#pragma mark - Export helpers

- (void)addTrackPoints:(Track *)track
        startTimeDelta:(NSTimeInterval)startTimeDelta
         startingIndex:(int)idx
               nextLap:(Lap *)nextLap
                  elem:(NSXMLElement *)lapElem
{
    NSArray *points = [track points];
    NSUInteger numPointsInTrack = [points count];
    BOOL hasEverHadSensorData = NO;

    if (numPointsInTrack > 0 && idx >= 0) {
        NSXMLElement *trackElem = [NSXMLNode elementWithName:@"Track"];
        while ((NSUInteger)idx < numPointsInTrack) {
            TrackPoint *pt = [points objectAtIndex:(NSUInteger)idx];

            if (!nextLap || ([pt wallClockDelta] <= [nextLap startingWallClockTimeDelta])) {
                NSXMLElement *tpElem = [NSXMLNode elementWithName:@"Trackpoint"];

                NSXMLElement *elem = [NSXMLNode elementWithName:@"Time"
                                                     stringValue:[self utzStringFromDate:[[track creationTime] addTimeInterval:[pt wallClockDelta]]
                                                                               gmtOffset:[track secondsFromGMT]]];
                [tpElem addChild:elem];

                BOOL isDeadZoneMarkerLocal = [pt importFlagState:kImportFlagDeadZoneMarker];

                if (!isDeadZoneMarkerLocal) {
                    if (([pt latitude] != BAD_LATLON) && ![pt importFlagState:kImportFlagMissingLocation]) {
                        NSXMLElement *posElem = [NSXMLNode elementWithName:@"Position"];
                        elem = [NSXMLNode elementWithName:@"LatitudeDegrees"
                                              stringValue:[NSString stringWithFormat:@"%1.6f", [pt latitude]]];
                        [posElem addChild:elem];
                        elem = [NSXMLNode elementWithName:@"LongitudeDegrees"
                                              stringValue:[NSString stringWithFormat:@"%1.6f", [pt longitude]]];
                        [posElem addChild:elem];
                        [tpElem addChild:posElem];
                    }

                    if (([pt origAltitude] != BAD_ALTITUDE) && ![pt importFlagState:kImportFlagMissingAltitude]) {
                        elem = [NSXMLNode elementWithName:@"AltitudeMeters"
                                              stringValue:[NSString stringWithFormat:@"%1.6f", FeetToMeters([pt origAltitude])]];
                        [tpElem addChild:elem];
                    }

                    if (([pt origDistance] != BAD_DISTANCE) && ![pt importFlagState:kImportFlagMissingDistance]) {
                        elem = [NSXMLNode elementWithName:@"DistanceMeters"
                                              stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([pt origDistance])*1000.0]];
                        [tpElem addChild:elem];
                    }

                    float hr = [pt heartrate];
                    if ([self validHR:hr] && ![pt importFlagState:kImportFlagMissingHeartRate]) {
                        NSXMLElement *hrElem = [NSXMLNode elementWithName:@"HeartRateBpm"];
                        [hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type"
                                                               stringValue:@"HeartRateInBeatsPerMinute_t"]];
                        elem = [NSXMLNode elementWithName:@"Value"
                                              stringValue:[NSString stringWithFormat:@"%1.0f", [pt heartrate]]];
                        [hrElem addChild:elem];
                        [tpElem addChild:hrElem];
                    }

                    BOOL hasFootpod = [pt importFlagState:kImportFlagHasFootpod];
                    BOOL missingCadence = [pt importFlagState:kImportFlagMissingCadence];
                    BOOL missingPower   = [pt importFlagState:kImportFlagMissingPower];
                    BOOL missingSpeed   = [pt importFlagState:kImportFlagMissingSpeed];

                    if (!missingCadence && !hasFootpod) {
                        elem = [NSXMLNode elementWithName:@"Cadence"
                                              stringValue:[NSString stringWithFormat:@"%1.0f", [pt cadence]]];
                        [tpElem addChild:elem];
                    }

                    BOOL hasSensorData = !missingPower || !missingSpeed || (!missingCadence && hasFootpod);
                    if (!hasSensorData && !hasEverHadSensorData) {
                        elem = [NSXMLNode elementWithName:@"SensorState" stringValue:@"Absent"];
                        [tpElem addChild:elem];
                    }

                    if (hasSensorData) {
                        hasEverHadSensorData = YES;
                        NSXMLElement *extElem = [NSXMLNode elementWithName:@"Extensions"];

                        BOOL hasCalculatedPower = [track activityIsValidForPowerCalculation];
                        if (hasCalculatedPower || [track hasDevicePower]) {
                            NSXMLElement *tpxElem = [self TPXElement];
                            elem = [NSXMLNode elementWithName:@"Watts"
                                                  stringValue:[NSString stringWithFormat:@"%1.0f", [pt power]]];
                            [tpxElem addChild:elem];
                            [extElem addChild:tpxElem];
                        }

                        if (!missingSpeed) {
                            NSXMLElement *tpxElem = [self TPXElement];
                            [tpxElem addAttribute:[NSXMLNode attributeWithName:@"CadenceSensor" stringValue:@"Bike"]];
                            elem = [NSXMLNode elementWithName:@"Speed"
                                                  stringValue:[NSString stringWithFormat:@"%1.7f",
                                                               MilesToKilometers([pt speed])*1000.0/(60.0*60.0)]];
                            [tpxElem addChild:elem];
                            [extElem addChild:tpxElem];
                        }

                        if (!missingCadence && hasFootpod) {
                            NSXMLElement *tpxElem = [self TPXElement];
                            [tpxElem addAttribute:[NSXMLNode attributeWithName:@"CadenceSensor" stringValue:@"Footpod"]];
                            elem = [NSXMLNode elementWithName:@"RunCadence"
                                                  stringValue:[NSString stringWithFormat:@"%1.0f", [pt cadence]]];
                            [tpxElem addChild:elem];
                            [extElem addChild:tpxElem];
                        }

                        [tpElem addChild:extElem];
                    }

                    [trackElem addChild:tpElem];
                }

                if (isDeadZoneMarkerLocal) {
                    int ii = idx + 1;
                    while ((NSUInteger)ii < numPointsInTrack) {
                        TrackPoint *ppt = [points objectAtIndex:(NSUInteger)ii];
                        if (![ppt importFlagState:kImportFlagDeadZoneMarker]) break;
                        ++ii;
                    }
                    idx = ii - 1;
                    if ([trackElem childCount] > 0) {
                        [lapElem addChild:trackElem];
                        if ((NSUInteger)idx < numPointsInTrack) {
                            trackElem = [NSXMLNode elementWithName:@"Track"];
                        }
                    }
                }
            } else {
                break;
            }
            ++idx;
        }
        if ([trackElem childCount] > 0) [lapElem addChild:trackElem];
    }
}

- (NSXMLElement *)manufactureLap:(Track *)track {
    NSXMLElement *lapElem = [NSXMLNode elementWithName:@"Lap"];
    [lapElem addAttribute:[NSXMLNode attributeWithName:@"StartTime"
                                            stringValue:[self utzStringFromDate:[track creationTime]
                                                                      gmtOffset:[track secondsFromGMT]]]];

    NSXMLElement *elem = [NSXMLNode elementWithName:@"TotalTimeSeconds"
                                         stringValue:[NSString stringWithFormat:@"%1.6f", [track duration]]];
    [lapElem addChild:elem];

    elem = [NSXMLNode elementWithName:@"DistanceMeters"
                           stringValue:[NSString stringWithFormat:@"%1.6f", MilesToKilometers([track distance])*1000.0]];
    [lapElem addChild:elem];

    elem = [NSXMLNode elementWithName:@"MaximumSpeed"
                           stringValue:[NSString stringWithFormat:@"%1.6f",
                                        MilesToKilometers([track maxSpeed])*1000.0/3600.0]];
    [lapElem addChild:elem];

    int cals = [track calories];
    if (IS_BETWEEN(0, cals, 65535)) {
        elem = [NSXMLNode elementWithName:@"Calories" stringValue:[NSString stringWithFormat:@"%d", cals]];
        [lapElem addChild:elem];
    }

    float avghr = [track avgHeartrate];
    if ([self validHR:avghr]) {
        NSXMLElement *hrElem = [NSXMLNode elementWithName:@"AverageHeartRateBpm"];
        [hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type" stringValue:@"HeartRateInBeatsPerMinute_t"]];
        elem = [NSXMLNode elementWithName:@"Value" stringValue:[NSString stringWithFormat:@"%1.0f", avghr]];
        [hrElem addChild:elem];
        [lapElem addChild:hrElem];
    }

    NSTimeInterval junk;
    float maxhr = [track maxHeartrate:&junk];
    if ([self validHR:maxhr]) {
        NSXMLElement *hrElem = [NSXMLNode elementWithName:@"MaximumHeartRateBpm"];
        [hrElem addAttribute:[NSXMLNode attributeWithName:@"xsi:type" stringValue:@"HeartRateInBeatsPerMinute_t"]];
        elem = [NSXMLNode elementWithName:@"Value" stringValue:[NSString stringWithFormat:@"%1.0f", maxhr]];
        [hrElem addChild:elem];
        [lapElem addChild:hrElem];
    }

    elem = [NSXMLNode elementWithName:@"Intensity" stringValue:@"Active"]; [lapElem addChild:elem];
    elem = [NSXMLNode elementWithName:@"Cadence" stringValue:[NSString stringWithFormat:@"%1.0f", [track avgCadence]]];
    [lapElem addChild:elem];
    elem = [NSXMLNode elementWithName:@"TriggerMethod" stringValue:@"Manual"]; [lapElem addChild:elem];

    return lapElem;
}

@end
