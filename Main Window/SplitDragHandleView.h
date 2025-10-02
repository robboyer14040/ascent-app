//
//  SplitDragHandleView.h
//  Ascent
//
//  Created by Rob Boyer on 10/2/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SplitDragHandleView;

@protocol SplitDragHandleViewDelegate <NSObject>
- (void)splitDragHandleDidBeginDragging:(SplitDragHandleView *)handle
                              startYInSplit:(CGFloat)startY;
- (void)splitDragHandle:(SplitDragHandleView *)handle
         didDragToYInSplit:(CGFloat)currentY;
- (void)splitDragHandleDidEndDragging:(SplitDragHandleView *)handle;
- (void)splitDragHandleDidToggleCollapse:(SplitDragHandleView *)handle;
@optional
- (NSSplitView *)splitViewForDragHandle:(SplitDragHandleView *)handle; // if not set, you must set .splitView property
@end

@interface SplitDragHandleView : NSView
@property(nonatomic, assign) id<SplitDragHandleViewDelegate> delegate;
@property(nonatomic, assign) NSSplitView *splitView; // optional if delegate provides it
@end
