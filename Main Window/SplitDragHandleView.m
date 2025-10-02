//
//  SplitDragHandleView.m
//  Ascent
//
//  Created by Rob Boyer on 10/2/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import "SplitDragHandleView.h"

@implementation SplitDragHandleView {
    BOOL _dragging;
    NSPoint _downInWindow;
    CGFloat _startYInSplit;
}

+ (BOOL)isOpaque { return NO; }

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)resetCursorRects {
    [super resetCursorRects];
    // Show the up-down resize cursor over the blank area
    [self addCursorRect:self.bounds cursor:[NSCursor resizeUpDownCursor]];
}

- (NSSplitView *)_splitView {
    if (self.splitView != nil) {
        return self.splitView;
    }
    if ([self.delegate respondsToSelector:@selector(splitViewForDragHandle:)]) {
        return [self.delegate splitViewForDragHandle:self];
    }
    return nil;
}

- (void)mouseDown:(NSEvent *)event {
    // Double-click in the grip toggles collapse/expand
    if (event.clickCount == 2) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(splitDragHandleDidToggleCollapse:)]) {
            [self.delegate splitDragHandleDidToggleCollapse:self];
        }
        return;
    }

    NSSplitView *sv = [self _splitView];
    if (!sv) {
        [super mouseDown:event];
        return;
    }

    _dragging = YES;
    _downInWindow = [event locationInWindow];

    // Compute starting divider Y (in split view coords)
    NSPoint downInSelf = [self convertPoint:_downInWindow fromView:nil];
    NSPoint downInSplit = [sv convertPoint:downInSelf fromView:self];
    _startYInSplit = downInSplit.y;

    if (self.delegate) {
        [self.delegate splitDragHandleDidBeginDragging:self startYInSplit:_startYInSplit];
    }

    // Track drag until mouseUp
    NSEventMask mask = (NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp);
    while (YES) {
        NSEvent *e = [self.window nextEventMatchingMask:mask];
        if (e.type == NSEventTypeLeftMouseUp) {
            _dragging = NO;
            if (self.delegate) {
                [self.delegate splitDragHandleDidEndDragging:self];
            }
            break;
        } else if (e.type == NSEventTypeLeftMouseDragged) {
            NSPoint pSelf = [self convertPoint:e.locationInWindow fromView:nil];
            NSPoint pSplit = [[self _splitView] convertPoint:pSelf fromView:self];
            if (self.delegate) {
                [self.delegate splitDragHandle:self didDragToYInSplit:pSplit.y];
            }
        }
    }
}

@end
