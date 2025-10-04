//
//  MetricsController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "MetricsController.h"
#import "Selection.h"
#import "StatDefs.h"
#import "Track.h"
#import "Utils.h"
#import "AnimTimer.h"

enum
{
    kIsPace             = 0x00000001,
    kUseNumberFormatter = 0x00000002
};

typedef float (*tConvertFunc)(float);

struct tEventInfo
{
    const char*     name;
    const char*     type;
    const char*     unitsStatute;
    const char*     unitsMetric;
    enum tStatType  statType;
    int             subIndex;
    tConvertFunc    convertFunc;
    int             flags;
};


static struct tEventInfo sEventInfo[] =
{
    { "Heart Rate",     "max", "bpm",           "bpm",              kST_Heartrate,      kMax, 0,                        kUseNumberFormatter },
    { "Heart Rate",     "avg", "bpm",           "bpm",              kST_Heartrate,      kAvg, 0,                        kUseNumberFormatter },
    { "Power",          "max", "watts",         "watts",            kST_Power,          kMax, 0,                        kUseNumberFormatter },
    { "Power",          "avg", "watts",         "watts",            kST_Power,          kAvg, 0,                        kUseNumberFormatter },
    { "Speed",          "max", "mph",           "km/h",             kST_MovingSpeed,    kMax, &MilesToKilometers,       kUseNumberFormatter },
    { "Moving Speed",   "avg", "mph",           "km/h",             kST_MovingSpeed,    kAvg, &MilesToKilometers,       kUseNumberFormatter },
    { "Pace",           "min", "min/mi",        "min/km",           kST_MovingSpeed,    kMax, 0,                        kIsPace },
    { "Gradient",       "max", "%",             "%",                kST_Gradient,       kMax, 0,                        kUseNumberFormatter },
    { "Gradient",       "min", "%",             "%",                kST_Gradient,       kMin, 0,                        kUseNumberFormatter },
    { "Altitude",       "max", "ft",            "m",                kST_Altitude,       kMax, &FeetToMeters,            kUseNumberFormatter },
    { "Altitude",       "min", "ft",            "m",                kST_Altitude,       kMin, &FeetToMeters,            kUseNumberFormatter },
    { "Cadence",        "max", "rpm",           "rpm",              kST_Cadence,        kMax, 0,                        kUseNumberFormatter },
    { "Cadence",        "avg", "rpm",           "rpm",              kST_Cadence,        kAvg, 0,                        kUseNumberFormatter },
    { "Temperature",    "max", "\xC2\xB0""F",   "\xC2\xB0""C",      kST_Temperature,    kMax, &FahrenheightToCelsius,   kUseNumberFormatter },
    { "Temperature",    "min", "\xC2\xB0""F",   "\xC2\xB0""C",      kST_Temperature,    kMin, &FahrenheightToCelsius,   kUseNumberFormatter },
};


static void *kSelectionCtx = &kSelectionCtx;


@interface ASCVCenteredTextFieldCell : NSTextFieldCell
@end

@implementation ASCVCenteredTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)rect {
    // Let super compute the text rect, then center it vertically
    NSRect r = [super drawingRectForBounds:rect];

    // Measure a single-line string for this font
    NSDictionary *attrs = @{ NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]] };
    NSSize text = [@"Ag" sizeWithAttributes:attrs];  // “Ag” gives a decent cap/x-height combo

    CGFloat dy = floor((NSHeight(r) - text.height) * 0.5);
    r.origin.y += dy;
    r.size.height -= dy; // keep baseline math happy
    return r;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:[self drawingRectForBounds:cellFrame] inView:controlView];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj
             delegate:(id)anObject event:(NSEvent *)theEvent {
    [super editWithFrame:[self drawingRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj
               delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
    [super selectWithFrame:[self drawingRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

@end



@interface MetricsController ()
@property (nonatomic, assign) BOOL observingSelection;
@end


@implementation MetricsController
@synthesize document = _document;
@synthesize selection = _selection;


- (void)awakeFromNib
{
    _observingSelection = NO;

    NSFont *font = [NSFont systemFontOfSize:13.0];

    for (NSTableColumn *col in _metricsTable.tableColumns) {
        // Start from the existing dataCell to preserve formatting settings
        NSTextFieldCell *old = (NSTextFieldCell *)col.dataCell;
        ASCVCenteredTextFieldCell *cell = [[[ASCVCenteredTextFieldCell alloc] initTextCell:@""] autorelease];

        cell.font = font;
        cell.alignment = old.alignment;
        cell.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.usesSingleLineMode = YES;
        cell.truncatesLastVisibleLine = YES;

        col.dataCell = cell;
    }

    // Pick a tidy row height; centering works even if this is larger
    NSTextFieldCell *probe = (NSTextFieldCell *)_metricsTable.tableColumns.firstObject.dataCell;
    _metricsTable.rowHeight = ceil(probe.cellSize.height) + 2.0;
    _metricsTable.intercellSpacing = NSMakeSize(2.0, 2.0);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}



- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
}


- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];
    [self _startObservingSelection];
}



- (void)_startObservingSelection {
    if (!_selection)
        return;

    // Observe the key(s) on Selection you care about.
    // Replace "selectedTrack" with your actual property name(s).
    @try {
        if (_selection && !_observingSelection) {
            [_selection addObserver:self
                         forKeyPath:@"selectedTrack"
                            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                            context:kSelectionCtx];
            _observingSelection = YES;
        }
        // Add more keys if needed:
        // [_selection addObserver:self forKeyPath:@"selectedTrackRegion" options:... context:kSelectionCtx];
        // [_selection addObserver:self forKeyPath:@"selectedSegments"    options:... context:kSelectionCtx];
    } @catch (__unused NSException *ex) {
        // No-op: protects if key missing in some builds
    }
}

- (void)_stopObservingSelection {
    if (!_selection)
        return;

    // Remove observers defensively
    @try {
        if (_selection && _observingSelection) {
            [_selection removeObserver:self forKeyPath:@"selectedTrack" context:kSelectionCtx];
            _observingSelection = NO;
        }
    } @catch (...) {}
    // @try { [_selection removeObserver:self forKeyPath:@"selectedTrackRegion" context:kSelectionCtx]; } @catch (...) {}
    // @try { [_selection removeObserver:self forKeyPath:@"selectedSegments"    context:kSelectionCtx]; } @catch (...) {}
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != kSelectionCtx) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if ([keyPath isEqualToString:@"selectedTrack"]) {
        Track *t = [change objectForKey:NSKeyValueChangeNewKey];
        if ((id)t == (id)[NSNull null])
            t = nil;
        [self _displaySelectedTrackData:t];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
}

- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _displaySelectedTrackData:t];
}


-(void) _displaySelectedTrackData:(Track*)trk
{
    if (trk) {
        [_metricsTable reloadData];
    }
}


- (id)_objectValueForEventInfoTableColumn:aTableColumn
                                      row:(int)rowIndex
{
    Track* track = _selection.selectedTrack;
    Lap* lap = _selection.selectedLap;
    id value = @"";
    if (track || lap)
    {
        BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
        struct tEventInfo* eventInfo = &sEventInfo[rowIndex];
        id ident = [aTableColumn identifier];
        if ([ident isEqualToString:@"Metric"])
        {
            value = [NSString stringWithUTF8String:eventInfo->name];
        }
        else if ([ident isEqualToString:@"Type"])
        {
            value = [NSString stringWithUTF8String:eventInfo->type];
        }
        else if ([ident isEqualToString:@"Value"])
        {
            if (FLAG_IS_SET(eventInfo->flags, kIsPace))
            {
                float val = [track minPace:0];
                value = [Utils convertPaceValueToString:val];
            }
            else
            {
                float val = 0.0;
                if (lap)
                {
                    val = [track statForLap:lap
                                   statType:eventInfo->statType
                                      index:eventInfo->subIndex
                                atActiveTimeDelta:0];
                }
                else
                {
                    val = [track statOrOverride:eventInfo->statType
                                          index:eventInfo->subIndex
                              atActiveTimeDelta:0];
                }
                if ((eventInfo->statType == kST_Temperature) && (val == 0.0))
                {
                    value = @"n/a";
                }
                else if (((eventInfo->statType == kST_Altitude)||(eventInfo->statType == kST_Gradient)) && (![track hasElevationData] || (BAD_ALTITUDE == val)))
                {
                    value = @"n/a";
                }
                else
                {
                    NSNumberFormatter* fm = [[[NSNumberFormatter alloc] init] autorelease];
                    [fm setNumberStyle:NSNumberFormatterDecimalStyle];
                    [fm setMaximumFractionDigits:1];
#if TEST_LOCALIZATION
                    [fm setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"] autorelease]];
#else
                    [fm setLocale:[NSLocale currentLocale]];
#endif
                    if (!useStatuteUnits && eventInfo->convertFunc)
                        val = eventInfo->convertFunc(val);
                    value = [fm stringFromNumber:[NSNumber numberWithFloat:val]];
                }
            }
        }
        else if ([ident isEqualToString:@"Units"])
        {
            BOOL isTemperature =  (eventInfo->statType == kST_Temperature);
            BOOL useCentigrade = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
            if (useStatuteUnits || (isTemperature && !useCentigrade))
            {
                value = [NSString stringWithUTF8String:eventInfo->unitsStatute];
            }
            else
            {
                value = [NSString stringWithUTF8String:eventInfo->unitsMetric];
            }
        }
        else
        {
            if (eventInfo->subIndex == kAvg) {
                value = @"";
            } else {
                NSTimeInterval atTime;
                if (lap)
                {
                    [track statForLap:lap
                             statType:eventInfo->statType
                                index:eventInfo->subIndex
                    atActiveTimeDelta:&atTime];
                }
                else
                {
                    [track statOrOverride:eventInfo->statType
                                    index:eventInfo->subIndex
                        atActiveTimeDelta:&atTime];
                }
                int secs = (int)atTime;
                value = [NSString stringWithFormat:@"%02d:%02d:%02d", secs/3600, (secs/60)%60, secs % 60 ];
            }
        }
    }
    return value;
}


- (void) _gotoStatTime:(int)idx
{
    Track* track = _selection.selectedTrack;
    Lap* lap = _selection.selectedLap;\
    struct tEventInfo* eventInfo = &sEventInfo[idx];
    NSTimeInterval atTime;
    if (lap)
    {
        [track statForLap:lap
                 statType:eventInfo->statType
                    index:eventInfo->subIndex
        atActiveTimeDelta:&atTime];
    }
    else
    {
        [track statOrOverride:eventInfo->statType
                        index:eventInfo->subIndex
            atActiveTimeDelta:&atTime];
    }
    [[AnimTimer defaultInstance] stop:self];
    [[AnimTimer defaultInstance] setAnimTime:atTime];
}


// TableView delegate/datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
        return sizeof(sEventInfo)/sizeof(struct tEventInfo);
}


- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    id value;
        value = [self _objectValueForEventInfoTableColumn:aTableColumn
                                                      row:rowIndex];
    return value;
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSColor* txtColor = nil;
    [aCell setFont:[NSFont boldSystemFontOfSize:10.0]];
    if (txtColor == nil)
        txtColor =  [NSColor colorNamed:@"TextPrimary"];
    [aCell setTextColor:txtColor];
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger idx = [_metricsTable selectedRow];
    if (idx != -1)
    {
        [self _gotoStatTime:(int)idx];
    }
}

@end
