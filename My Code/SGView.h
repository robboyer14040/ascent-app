/* SGView */

#import <Cocoa/Cocoa.h>
#import "Defs.h"


@class TrackBrowserDocument;

enum
{
   kWeeks,
   kMonths
};

// graph types
enum
{
   kLineGraph,
   kBarGraph
};


@interface SGView : NSView
{
   TrackBrowserDocument*   tbDocument;

   NSMutableDictionary*    dataDict;
   NSMutableDictionary*    textAttrs; 
   NSMutableDictionary*    tickFontAttrs; 
   
   NSMutableArray*         typeInfoArray;
   BOOL                    haveData;
   int                     plotUnits;        // weeks or months, currently
   int                     graphType;
   float                   leftTickViewWidth;
   float                   rightTickViewWidth;
}

-(void)setDocument:(TrackBrowserDocument*)tbd;
-(void)enablePlotType:(int)pt on:(BOOL)isOn;
-(BOOL)plotEnabled:(int)pt;
-(void)setPlotUnits:(int)units;
-(int)plotUnits;
-(void)setGraphType:(int)gt;
-(int)graphType;
- (NSArray *)typeInfoArray;
- (unsigned)countOfTypeInfoArray;
- (id)objectInTypeInfoArrayAtIndex:(unsigned)theIndex;
- (BOOL)haveData;
- (float)leftTickViewWidth;
- (float)rightTickViewWidth;




@end
