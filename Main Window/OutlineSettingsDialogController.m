//
//  OutlineSettingsDialogController.m
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "OutlineSettingsDialogController.h"
#import "TrackPaneController.h"


@interface OutlineSettingsDialogController ()

@end

@implementation OutlineSettingsDialogController


- (void)dealloc {
    [_trackPaneController release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


- (IBAction)setOutlineStyle:(id)sender
{
    [_trackPaneController setBrowserViewMode:sender];
}

@end
