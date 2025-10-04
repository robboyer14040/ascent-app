//
//  GraphicalIntervalsPaneController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Selection;
@class SplitsGraphView;


NS_ASSUME_NONNULL_BEGIN

@interface GraphicalIntervalsPaneController : NSViewController

@property(nonatomic, assign) IBOutlet SplitsGraphView   *contentView;

@property(nonatomic, assign) TrackBrowserDocument   *document;
@property(nonatomic, retain) Selection              *selection;


@end

NS_ASSUME_NONNULL_END
