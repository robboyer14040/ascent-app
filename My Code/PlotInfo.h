//
//  PlotInfo.h
//  Ascent
//
//  Created by Rob Boyer on 10/9/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "Defs.h"

static const int kBadSpeed = -9999.99;

typedef struct _tPlotInfo
{
   int         type;
   const char* name;
   NSString*   defaultsKey;
   int         colorTag;
   NSPoint     pos;
   float       opacityDefault;
   int         lineStyleDefault;
   int         numPeaksDefault;
   int         peakThresholdDefault;
   BOOL        enabledDefault;
   BOOL        fillEnabledDefault;
   BOOL        showLapsDefault;
   BOOL        showPeaksDefault;
   BOOL        showMarkersDefault;
   int         averageType;
   BOOL        isAverage;
   
} tPlotInfo;

#define     Col1X    228
#define     Col2X    503
#define        Col3X     776
#define     AltLineY 131
#define     Line1Y   131
#define     Line2Y   108
#define     Line3Y   85
#define     Line4Y   62
#define     Line5Y   39
#define     Line6Y   16

tPlotInfo plotInfoArray[] =
{
   {
        kAltitude,
        "Altitude",
        @"RCBDefaultsPlotAlt",
        kAltitude,
        { Col3X, AltLineY},
        0.25,
        0,
        3,
        25,
        YES,
        YES,
        YES,
        NO,
        YES,
        kReserved,
        NO
    },
    {
        kHeartrate,
        "Heart rate",
        @"RCBDefaultsPlotHR",
        kHeartrate,
        { Col1X, Line1Y},
        1.0,
        0,
        3,
        25,
        YES,
        NO,
        NO,
        NO,
        NO,
        kAvgHeartrate,
        NO
    },
    {
        kSpeed,
        "Speed",
        @"RCBDefaultsPlotSpd",
        kSpeed,
        { Col1X, Line2Y},
        1.0,
        0,
        3,
        25,
        YES,
        NO,
        NO,
        NO,
        NO,
        kAvgSpeed,
        NO
    },
    {
        kCadence,
        "Cadence",
        @"RCBDefaultsPlotCad",
        kCadence,
        { Col1X, Line3Y},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kAvgCadence,
        NO
    },
    {
        kPower,
        "Power",
        @"RCBDefaultsPlotPwr",
        kPower,
        { Col1X, Line4Y},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kAvgPower,
        NO
    },
    {
        kTemperature,
        "Temperature",
        @"RCBDefaultsPlotTmp",
        kTemperature,
        { Col1X, Line6Y},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kAvgTemperature,
        NO
    },
    {
        kGradient,
        "Gradient",
        @"RCBDefaultsPlotGrd",
        kGradient,
        { Col1X, Line5Y},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kAvgGradient
    },
    {
        kAvgHeartrate,
        "Heartrate",
        @"RCBDefaultsPlotAvgHR",
        kHeartrate,
        { Col2X, Line1Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
    },
    {
        kAvgSpeed,
        "Speed",
        @"RCBDefaultsPlotAvgSpd",
        kSpeed,
        { Col2X, Line2Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
    },
    {
        kAvgCadence,
        "Cadence",
        @"RCBDefaultsPlotAvgCad",
        kCadence,
        { Col2X, Line3Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
    },
    {
        kAvgPower,
        "Power",
        @"RCBDefaultsPlotAvgPwr",
        kPower,
        { Col2X, Line4Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
    },
    {
        kAvgTemperature,
        "Temperature",
        @"RCBDefaultsPlotAvgTmp",
        kTemperature,
        { Col2X, Line6Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
    },
    {
        kAvgGradient,
        "Gradient",
        @"RCBDefaultsPlotAvgGrd",
        kGradient,
        { Col2X, Line5Y},
        1.0,
        1,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        YES
   },
#if 1
   {
        kReserved,
        "Background",
        @"RCBDefaultsPlotBck",
        kBackground,
        { 844, Line1Y},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        NO
    },
#endif
    {
        kReserved,
        "kReserved",
        @"RCBDefaultsPlotRsvd",
        kBackground,
        { 0, 0},
        1.0,
        0,
        3,
        25,
        NO,
        NO,
        NO,
        NO,
        NO,
        kReserved,
        NO
   }
};

