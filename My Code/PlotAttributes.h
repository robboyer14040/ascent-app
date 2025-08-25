//
//  PlotAttributes.h
//  TLP
//
//  Created by Rob Boyer on 8/6/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlotAttributes : NSObject 
{
   NSString*      name;
   NSString*      defaultsKey;
   NSColor*       color;
   float          opacity;
   int            lineStyle;
   BOOL           enabled;
   BOOL           fillEnabled;
   BOOL           showLaps;
   BOOL           showMarkers;
   BOOL           showPeaks;
   BOOL           isAverage;
   int            averageType;   // tPlotType of average plot, kReserved if none
   int            numPeaks;
   int            peakThreshold;
}

- (id) initWithAttributes:(NSString*)name 
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
              averageType:(int)avg
                isAverage:(BOOL)ia;

- (NSString*)        name;
- (NSColor*)         color;
- (void)             setColor:(NSColor*)c;
- (float)            opacity;
- (void)             setOpacity:(float)o;
- (BOOL)             enabled;
- (void)             setEnabled:(BOOL)en;
- (BOOL)             fillEnabled;
- (void)             setFillEnabled:(BOOL)fen;
- (int)              lineStyle;
- (void)             setLineStyle:(int)ls;
- (BOOL)             showLaps;
- (void)             setShowLaps:(BOOL)sl;
- (BOOL)             showPeaks;
- (void)             setShowPeaks:(BOOL)sp;
- (int)              numPeaks;
- (void)             setNumPeaks:(int)n;
- (int)              peakThreshold;
- (void)             setPeakThreshold:(int)n;
- (BOOL)             showMarkers;
- (void)             setShowMarkers:(BOOL)sm;
- (int)              averageType;
- (void)             setAverageType:(int)at;
- (BOOL)             isAverage;
- (void)             setAverage:(BOOL)ia;
- (NSString *)defaultsKey;
- (void)setDefaultsKey:(NSString *)value;

@end
