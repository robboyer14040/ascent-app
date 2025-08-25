//
//  SGWindowController.h
//  TLP
//
//  Created by Rob Boyer on 9/24/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class TrackBrowserDocument;
@class SGView;
@class ColorBoxView;
@class VertTicView;

@interface SGWindowController :  NSWindowController
{
    TrackBrowserDocument*   tbDocument;
    IBOutlet SGView*        sgView;
    IBOutlet VertTicView*   vertTicViewLeft;
    IBOutlet VertTicView*   vertTicViewRight;
    IBOutlet NSMatrix*      unitsMatrix;
    IBOutlet ColorBoxView*  totalDistanceColorBox;
    IBOutlet ColorBoxView*  totalDurationColorBox;
    IBOutlet ColorBoxView*  totalMovingDurationColorBox;
    IBOutlet ColorBoxView*  totalClimbColorBox;
    IBOutlet ColorBoxView*  avgSpeedColorBox;
    IBOutlet ColorBoxView*  avgMovingSpeedColorBox;
    IBOutlet ColorBoxView*  avgPaceColorBox;
    IBOutlet ColorBoxView*  avgMovingPaceColorBox;
    IBOutlet ColorBoxView*  avgHeartrateColorBox;
    IBOutlet ColorBoxView*  avgCadenceColorBox;
    IBOutlet ColorBoxView*  avgWeightColorBox;
    IBOutlet ColorBoxView*  caloriesColorBox;
    IBOutlet NSPopUpButton* graphTypePopup;
    __unsafe_unretained NSWindowController*     mainWC;
    NSTimer*                fadeTimer;
}
@property(unsafe_unretained) id mainWC;		// don't retain

- (id)initWithDocument:(TrackBrowserDocument*)doc mainWC:(NSWindowController*)wc;
- (IBAction) enablePlotType:(id)sender;
- (IBAction) changeUnits:(id)sender;
- (IBAction) setGraphType:(id)sender;


@end
