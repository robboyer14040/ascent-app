//
//  LeftSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
// LeftSplitController.m  (MRC)
#import "LeftSplitController.h"
#import "TrackPaneController.h"     // top (outline/calendar)
#import "AnalysisPaneController.h"      // bottom (segments/intervals)

@interface LeftSplitController ()
{
    CGFloat _lastNonCollapsedDividerPos; // in splitView coords (y from bottom)
    BOOL    _dragging;
    CGFloat _dividerPosAtDragStart;
}
@property(nonatomic, assign) CGFloat minUpperHeight;   // e.g. 160.0
@property(nonatomic, assign) CGFloat minLowerHeight;   // e.g. 0.0 allows true collapse
@property(nonatomic, retain) IBOutlet NSSplitViewItem *upperItem;
@property(nonatomic, retain) IBOutlet NSSplitViewItem *lowerItem;
@end


@implementation LeftSplitController

@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_upperItem release];
    [_lowerItem release];
    [_selection release];
    [_trackPaneController release];
    [_analysisPaneController release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSSplitView *sv = self.splitView;      // created by super
    sv.vertical     = NO;                  // top/bottom
    sv.dividerStyle = NSSplitViewDividerStyleThin;
 
    // Create children (XIB-backed)
    if (!_trackPaneController)
        _trackPaneController = [[TrackPaneController alloc] initWithNibName:@"TrackPaneController" bundle:nil];
    if (!_analysisPaneController)
        _analysisPaneController  = [[AnalysisPaneController  alloc] initWithNibName:@"AnalysisPaneController"  bundle:nil];

    self.upperItem = [NSSplitViewItem splitViewItemWithViewController:_trackPaneController];
    _upperItem.minimumThickness = 220.0;
    _upperItem.holdingPriority = 260;

    self.lowerItem = [NSSplitViewItem splitViewItemWithViewController:_analysisPaneController];
    _lowerItem.minimumThickness = 0.0;
    _lowerItem.holdingPriority = 250;

    [self addSplitViewItem:_upperItem];
    [self addSplitViewItem:_lowerItem];

    _upperItem.canCollapse = NO;
    _lowerItem.canCollapse = YES;
    
    sv.autosaveName = @"LeftSplitView";

    [self injectDependencies];
    
    _lastNonCollapsedDividerPos = [self _currentDividerY];
    _dragging = NO;
}


- (void)setDocument:(TrackBrowserDocument *)doc { _document = doc; if (self.isViewLoaded) [self injectDependencies]; }

- (void)setSelection:(Selection *)sel { if (sel==_selection) return; [_selection release]; _selection=[sel retain]; if (self.isViewLoaded) [self injectDependencies]; }

- (void)injectDependencies
{
    for (NSViewController *vc in @[(id)_trackPaneController ?: (id)NSNull.null, (id)_analysisPaneController ?: (id)NSNull.null]) {
        if ((id)vc == (id)NSNull.null)
            continue;
        
        @try {
            [vc setValue:_document
                  forKey:@"document"];
        } @catch(...) {}
        
        @try {
            [vc setValue:_selection
                  forKey:@"selection"];
        } @catch(...) {}
        
        @try {
            [vc setValue:self
                  forKey:@"parentSplitVC"];
        } @catch(...) {}
        
        if ([vc respondsToSelector:@selector(injectDependencies)])
            [vc performSelector:@selector(injectDependencies)];
    }
}



- (void)toggleLowerSplit
{
    if (self.lowerItem.isCollapsed) {
        [self _expandLowerItemRestoringDivider];
    } else {
        [self _collapseLowerItemRememberingDivider];
    }
}


#pragma mark - Split sizing helpers

- (CGFloat)_currentDividerY {
    // With 2 subviews and horizontal split, divider Y == height of upper subview from bottom?
    // The public API is get/set via setPosition:ofDividerAtIndex:
    // We can compute it from current frames to be robust:
    NSView *upperView = self.splitView.subviews.count > 0 ? [self.splitView.subviews objectAtIndex:0] : nil;
    if (!upperView) {
        return 0.0;
    }
    // Divider Y is upperView’s maxY in split coords
    NSRect f = upperView.frame;
    return NSMaxY(f);
}


- (CGFloat)_clampedDividerYForProposed:(CGFloat)proposed {
    CGFloat totalH = NSHeight(self.splitView.bounds);

    // Respect item minimums:
    CGFloat minUpper = MAX(self.minUpperHeight, self.upperItem.minimumThickness);
    CGFloat minLower = MAX(self.minLowerHeight, self.lowerItem.minimumThickness);

    CGFloat minY = minUpper;                 // divider cannot go below upper’s minimum height
    CGFloat maxY = totalH - minLower;        // divider cannot go above (total - lower min)

    if (maxY < minY) {
        // Degenerate (e.g. window too small). Force into something sane.
        maxY = minY;
    }
    if (proposed < minY) proposed = minY;
    if (proposed > maxY) proposed = maxY;
    return proposed;
}


- (void)_setDividerY:(CGFloat)y animated:(BOOL)animated {
    CGFloat clamped = [self _clampedDividerYForProposed:y];
    if (animated) {
        // Animate by resizing the subviews inside an animation group
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            context.duration = 0.18;
            [self.splitView.animator setPosition:clamped ofDividerAtIndex:0];
        } completionHandler:^{}];
    } else {
        [self.splitView setPosition:clamped ofDividerAtIndex:0];
    }
}


- (void)_collapseLowerItemRememberingDivider {
    if (!self.lowerItem.isCollapsed) {
        _lastNonCollapsedDividerPos = [self _currentDividerY];
        // Ensure the remembered value is clamped to today’s bounds
        _lastNonCollapsedDividerPos = [self _clampedDividerYForProposed:_lastNonCollapsedDividerPos];
    }
    [[self.lowerItem animator] setCollapsed:YES];
}


- (void)_expandLowerItemRestoringDivider {
    [[self.lowerItem animator] setCollapsed:NO];

    // After the expand animation begins, set the divider back (slight async lets layout settle)
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat target = _lastNonCollapsedDividerPos;
        if (target <= 0.0) {
            // Fallback: 75% upper height by default
            target = NSHeight(self.splitView.bounds) * 0.75;
        }
        [self _setDividerY:target animated:YES];
    });
}



#pragma mark - SplitDragHandleViewDelegate

- (NSSplitView *)splitViewForDragHandle:(SplitDragHandleView *)handle
{
    return self.splitView;
}


- (void)splitDragHandleDidBeginDragging:(SplitDragHandleView *)handle
                          startYInSplit:(CGFloat)startY {
    _dragging = YES;
    _dividerPosAtDragStart = [self _currentDividerY];

    // If lower was collapsed, expand first and keep the divider where it was.
    if (self.lowerItem.isCollapsed) {
        [self _expandLowerItemRestoringDivider];
    }
}


- (void)splitDragHandle:(SplitDragHandleView *)handle
       didDragToYInSplit:(CGFloat)currentY {

    // Compute delta in split coords relative to where the mouse went down in the split view
    // but apply to the divider’s original location so it feels solid.
    CGFloat totalH = NSHeight(self.splitView.bounds);
    (void)totalH; // not strictly needed, but often useful for debugging

    // currentY is the cursor Y within split view during drag. We want how far it moved since mouseDown.
    // However, our handle already gives us absolute position each time; easiest is to map drag delta
    // to divider change assuming a 1:1 relationship:
    // newDividerY = clamped(currentY), but this would “snap” to mouse; many prefer delta from start:
    // For a nicer feel use delta:
    //   delta = currentY - startYInSplit;  (We didn't store startYInSplit here; but the divider tracks fine
    //   without it by just snapping to cursor Y.)
    // Snap-to-cursor variant (simple and works well):
    [self _setDividerY:currentY animated:NO];

    // Remember last non-collapsed as we drag
    _lastNonCollapsedDividerPos = [self _currentDividerY];
}


- (void)splitDragHandleDidEndDragging:(SplitDragHandleView *)handle {
    _dragging = NO;
}


- (void)splitDragHandleDidToggleCollapse:(SplitDragHandleView *)handle {
    [self toggleLowerSplit];
}



@end
