//
//  ADStatsView.h
//  Ascent
//
//  Created by Robert Boyer on 4/17/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Defs.h"

static const int kNumSEDLines		= 5;
static const int kNumAMMLines		= 6;
static const float statsHUDW		= 330.0;
static const float statsHUDH		= 429.0;		// was 415 before power
static const int hudTH				= 14.0;
static const int yHR				= 24.0;										// bottom of 'hr zone' data
static const int yAMM				= yHR + ((kNumHRZones+1)*hudTH) + 20.0;		// bottom of 'avg/min/max' data
static const int ySED				= yAMM + (kNumAMMLines*hudTH) + 20.0;		// bottom of 'start/end/delta' data
static const int xCOL0				= 17.0;
static const int col0W				= 78.0;
static const int xCOL1				= col0W + xCOL0 + 2.0;
static const int xVAM				= 50.0;
static const int yVAM				= ySED + (kNumSEDLines*hudTH) + 18.0;		// bottom of VAM line
static const int wVAM				= 140.0;
static const int wSED				= 80.0;
static const int wAMM				= 48.0;
static const int wHR				= 140.0;
static const int startX				= xCOL1;
static const int endX				= xCOL1 + (1*wSED);
static const int deltaX				= xCOL1 + (2*wSED);
static const int avgX				= xCOL1;
static const int maxX				= xCOL1 + (1*wAMM);
static const int minX				= xCOL1 + (2*wAMM);
static const int tdX				= xCOL1 + (3*wAMM);
static const int hrzX				= xCOL1;
static const int hrzXPercentColX	= statsHUDW - 66.0;
static const int hrzXRangeColX		= 20.0;
static const float hrzGraphH		= 10.0;

@interface ADStatsView : NSView 
{
   NSArray*    points;
   float       minAlt, maxAlt, minDist, maxDist;
   float       zoneTimes[kNumHRZones+1];        // out-of-zone time is at index 0
   NSString*   zoneTypeKey;
   float       totalTime;
   int         zoneType;
}
- (NSArray *)points;
- (void)setPlotData:(NSArray *)value minDist:(float)mnd maxDist:(float)mxd minAlt:(float)mna maxAlt:(float)mxa hrz:(float*)zoneTimes  zoneType:(int)ztype;



@end
