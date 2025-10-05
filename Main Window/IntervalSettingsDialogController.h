//
//  IntervalSettingsDialogController.h
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AnalysisPaneController;
NS_ASSUME_NONNULL_BEGIN

@interface IntervalSettingsDialogController : NSViewController

@property(nonatomic, assign) IBOutlet NSTextField   *customSplitLengthField;
@property(nonatomic, assign) IBOutlet NSBox         *splitItemBox;
@property(nonatomic, assign) IBOutlet NSBox         *splitItemVariantBox;
@property(nonatomic, assign) IBOutlet NSBox         *splitLengthBox;
@property(nonatomic, assign) IBOutlet NSButton      *avgVariantButton;
@property(nonatomic, assign) IBOutlet NSButton      *minVariantButton;
@property(nonatomic, assign) IBOutlet NSButton      *maxVariantButton;
@property(nonatomic, assign) IBOutlet NSButton      *deltaFromAvgVariantButton;
@property(nonatomic, assign) IBOutlet NSTextField   *distanceUnitsField;

@property(nonatomic, retain) AnalysisPaneController    *analysisController;


- (IBAction)setSplitItem:(id)sender;
- (IBAction)setSplitItemVariant:(id)sender;
- (IBAction)setSplitLength:(id)sender;
- (IBAction)setSplitCustomLength:(id)sender;

@end

NS_ASSUME_NONNULL_END
