//
//  MetricsController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;

NS_ASSUME_NONNULL_BEGIN

@interface MetricsController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

@property(nonatomic, assign) IBOutlet NSTableView   *metricsTable;
@end


NS_ASSUME_NONNULL_END
