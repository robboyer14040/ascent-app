//
//  PlotAttributes.m
//  TLP
//
//  Created by Rob Boyer on 8/6/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "PlotAttributes.h"
#import "Defs.h"

@implementation PlotAttributes


- (id) init
{
   return [self initWithAttributes:@""
                       defaultsKey:@""
                             color:[NSColor blackColor]
                           opacity:(float)1.0
                         lineStyle:0
                           enabled:NO
                       fillEnabled:NO
                          showLaps:NO
                       showMarkers:NO
                         showPeaks:NO
                          numPeaks:0
                     peakThreshold:0
                       averageType:kReserved
                         isAverage:NO];
}


   
- (id) initWithAttributes:(NSString*)nm 
              defaultsKey:(NSString*)dk
                    color:(NSColor*)clr
                  opacity:(float)opac
                lineStyle:(int)ls
                  enabled:(BOOL)en
              fillEnabled:(BOOL)fen
                 showLaps:(BOOL)sl
              showMarkers:(BOOL)sm
                showPeaks:(BOOL)sp
                 numPeaks:(int)np
            peakThreshold:(int)pt
              averageType:(int)at
                isAverage:(BOOL)ia
{
   self = [super init];
   name = nm;
   defaultsKey = dk;
   color = [clr retain];
   opacity = opac;
   enabled = en;
   lineStyle = ls;
   fillEnabled = fen;
   showLaps = sl;
   showMarkers = sm;
   showPeaks = sp;
   numPeaks = np;
   peakThreshold = pt;
   isAverage = ia;
   averageType = at;
   return self;
}


-(void)dealloc
{
    [color autorelease];
    [super dealloc];
}



- (NSString*) name
{
   return name;
}


- (NSColor*) color
{ 
   return color;
}

- (void) setColor:(NSColor*)c
{
   color = [[c colorWithAlphaComponent:opacity] retain];    /// fixme added retain
}

- (float) opacity
{
   return opacity;
}


- (void) setOpacity:(float)o
{
   opacity = o;
   [self setColor:color];
}


- (BOOL) enabled
{
   return enabled;
}


- (void) setEnabled:(BOOL)en
{
   enabled = en;
}


- (BOOL) fillEnabled
{
   return fillEnabled;
}


- (void) setFillEnabled:(BOOL)fen
{
   fillEnabled = fen;
}


- (int) lineStyle
{
   return lineStyle;
}

- (void) setLineStyle:(int)ls
{
   lineStyle = ls;
}


- (BOOL) showLaps
{
   return showLaps;
}


- (void) setShowLaps:(BOOL)sl
{
   showLaps = sl;
}


- (BOOL)  showPeaks
{
   return showPeaks;
}


- (void) setShowPeaks:(BOOL)sp
{
   showPeaks = sp;
}


- (int) numPeaks
{
   return numPeaks;
}


- (void) setNumPeaks:(int)n
{
   numPeaks = n;
}


- (int) peakThreshold
{
   return peakThreshold;
}


- (void) setPeakThreshold:(int)n
{
   peakThreshold = n;
}

   
- (BOOL) showMarkers
{
   return showMarkers;
}

- (void)  setShowMarkers:(BOOL)sm
{
   showMarkers = sm;
}

- (int)             averageType
{
   return averageType;
}


- (void)             setAverageType:(int)at
{
   averageType = at;
}

- (BOOL)             isAverage
{
   return isAverage;
}


- (void)             setAverage:(BOOL)ia
{
   isAverage = ia;
}


- (NSString *)defaultsKey {
   return defaultsKey;
}

- (void)setDefaultsKey:(NSString *)value {
      defaultsKey = value;
}



@end
