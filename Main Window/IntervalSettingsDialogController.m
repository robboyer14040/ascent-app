//
//  IntervalSettingsDialogController.m
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "IntervalSettingsDialogController.h"
#import "AnalysisPaneController.h"


@interface IntervalSettingsDialogController ()

@end

@implementation IntervalSettingsDialogController


- (void)dealloc {
    [_analysisController release];
    [super dealloc];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
}


- (void)viewDidAppear
{
    [super viewDidAppear];
    [_analysisController setMinVariantButton:_minVariantButton];
    [_analysisController setMaxVariantButton:_maxVariantButton];
    [_analysisController setAvgVariantButton:_avgVariantButton];
    [_analysisController setDeltaFromAvgVariantButton:_deltaFromAvgVariantButton];
}


- (IBAction)setSplitItem:(id)sender
{
    [_analysisController setSplitItem:sender];
}


- (IBAction)setSplitItemVariant:(id)sender
{
    [_analysisController setSplitVariant:sender];
}



- (IBAction)setSplitLength:(id)sender
{
    [_analysisController setSplitLength:sender];
}



- (IBAction)setSplitCustomLength:(id)sender
{
    
}




@end
