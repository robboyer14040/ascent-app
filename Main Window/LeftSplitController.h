//
//  LeftSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class TrackBrowserDocument, Selection, TrackPaneController;

@interface LeftSplitController : NSSplitViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;
@property(nonatomic, assign) IBOutlet TrackPaneController *trackPaneController;
@property(nonatomic, assign) IBOutlet NSViewController *analysisPaneController;

- (void)injectDependencies; // call from MainWindowController after setting document/selection
@end

NS_ASSUME_NONNULL_END
