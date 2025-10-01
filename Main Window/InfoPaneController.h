//
//  InfoPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;
@class MetricsController;
@class InfoController;

NS_ASSUME_NONNULL_BEGIN

@interface InfoPaneController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument   *document;
@property(nonatomic, retain) Selection              *selection;

@property(nonatomic, assign) IBOutlet NSSegmentedControl    *modeToggle; 
@property(nonatomic, assign) IBOutlet NSView                *contentContainer;
@property(nonatomic, assign) IBOutlet NSVisualEffectView    *controlsBar;
@property(nonatomic, assign) IBOutlet NSTextView            *activityTitle;

@property(nonatomic, retain) MetricsController  *metricsVC;
@property(nonatomic, retain) InfoController     *infoVC;

- (IBAction)modeChanged:(id)sender;

- (void)showMode:(NSInteger)segmentIndex;
@end

NS_ASSUME_NONNULL_END
