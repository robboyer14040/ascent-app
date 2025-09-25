//
//  AnalysisPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "AnalysisPaneController.h"

@interface AnalysisPaneController ()

@end

@implementation AnalysisPaneController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    // Inject deps
    [(id)self.segmentsVC setValue:self.document forKey:@"document"];
    [(id)self.segmentsVC setValue:self.selection forKey:@"selection"];
    [(id)self.intervalsVC setValue:self.document forKey:@"document"];
    [(id)self.intervalsVC setValue:self.selection forKey:@"selection"];

    [self.modeToggle setSelectedSegment:0]; // start with Segments (or Intervals if you prefer)
    [self showMode:[self.modeToggle selectedSegment]];
}

- (IBAction)modeChanged:(id)sender { [self showMode:[self.modeToggle selectedSegment]]; }

- (void)showMode:(NSInteger)segmentIndex
{
    for (NSView *v in [[self.contentContainer subviews] copy]) { [v removeFromSuperview]; }
    NSViewController *vc = (segmentIndex == 0) ? self.segmentsVC : (NSViewController *)self.intervalsVC;
    if (!vc) { return; }
    NSView *v = [vc view];
    [v setFrame:[self.contentContainer bounds]];
    [v setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.contentContainer addSubview:v];
}

- (IBAction)optionChanged:(id)sender
{
    if ([self.modeToggle selectedSegment] == 1) {
        // Only intervals respond to options
        if ([self.intervalsVC respondsToSelector:@selector(applyOptionMenuSelection:)]) {
            NSNumber *idx = [NSNumber numberWithInteger:[self.optionsPopup indexOfSelectedItem]];
            [self.intervalsVC performSelector:@selector(applyOptionMenuSelection:) withObject:idx];
        }
    }
}


@end
