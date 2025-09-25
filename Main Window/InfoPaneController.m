//
//  InfoPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "InfoPaneController.h"

@interface InfoPaneController ()

@end

@implementation InfoPaneController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [(id)self.metricsVC setValue:self.document forKey:@"document"];
    [(id)self.metricsVC setValue:self.selection forKey:@"selection"];
    [(id)self.summaryPhotoVC setValue:self.document forKey:@"document"];
    [(id)self.summaryPhotoVC setValue:self.selection forKey:@"selection"];

    [self.modeToggle setSelectedSegment:0];
    [self showMode:0];
}

- (IBAction)modeChanged:(id)sender { [self showMode:[self.modeToggle selectedSegment]]; }

- (void)showMode:(NSInteger)segmentIndex
{
    for (NSView *v in [[self.contentContainer subviews] copy]) { [v removeFromSuperview]; }
    NSViewController *vc = (segmentIndex == 0) ? self.metricsVC : self.summaryPhotoVC;
    if (!vc) { return; }
    NSView *v = [vc view];
    [v setFrame:[self.contentContainer bounds]];
    [v setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.contentContainer addSubview:v];
}



@end
