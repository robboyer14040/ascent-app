//
//  RootSplitController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// RootSplitController.m  (MRC)

@import QuartzCore;                       // if “Enable Modules” = YES

#import "RootSplitController.h"
#import "LeftSplitController.h"
#import "RightSplitController.h"
#import "TrackBrowserDocument.h"
#import "Selection.h"


@interface RootSplitController ()
@property (assign) CGFloat lastRightPaneWidth;
@end


@implementation RootSplitController {
    LeftSplitController  *_leftSplitController;
    RightSplitController *_rightSplitController;
}

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize leftSplitController  = _leftSplitController;
@synthesize rightSplitController = _rightSplitController;

- (void)dealloc {
    [_selection release];
    [_leftSplitController release];
    [_rightSplitController release];
    [super dealloc];
}

#pragma mark - Lifecycle


- (void)awakeFromNib {
    [super awakeFromNib];
    _lastRightPaneWidth = 420.0;
}


// ❗️Do NOT override -loadView. Let super create the NSSplitView.
// If you had a -loadView before, delete it entirely.

- (void)viewDidLoad {
    [super viewDidLoad];
    self.splitView.delegate = (id<NSSplitViewDelegate>)self;

    // Configure the split that super created
    NSSplitView *sv = self.splitView;
    sv.vertical     = YES; // left/right
    sv.dividerStyle = NSSplitViewDividerStyleThin;

    // Create children (code-only controllers), retain in MRC
    if (!_leftSplitController)  _leftSplitController  = [[LeftSplitController alloc] init];
    if (!_rightSplitController) _rightSplitController = [[RightSplitController alloc] init];

    // TEMP colors to prove visibility (comment out once you see it)
//     _leftSplitController.view.wantsLayer = YES;
//    _leftSplitController.view.layer.backgroundColor = [NSColor systemYellowColor].CGColor;
//    _rightSplitController.view.wantsLayer = YES;
//    _rightSplitController.view.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;

    // Add items
    NSSplitViewItem *li = [NSSplitViewItem splitViewItemWithViewController:_leftSplitController];
    NSSplitViewItem *ri = [NSSplitViewItem splitViewItemWithViewController:_rightSplitController];

    // Min sizes
    li.minimumThickness  = 420.0;
    ri.minimumThickness = 420.0;
    ri.maximumThickness = ri.minimumThickness;
    
    // Who resists resizing when the window size changes:
    // Higher holdingPriority = resists more.
    // We want LEFT to hold (stay ≥ 400), RIGHT to give way.
    li.holdingPriority  = 270;   // higher
    ri.holdingPriority = 200;   // lower

    // Allow user to fully collapse the right side (optional but nice)
    ri.canCollapse = YES;
    li.canCollapse = NO;
    ri.preferredThicknessFraction = 0.25; // where it grows back to

    [self addSplitViewItem:li];
    [self addSplitViewItem:ri];

    sv.autosaveName = @"RootSplitView";

    // Push deps now that children exist
    [self injectDependencies];

//    // Debug: confirm arranged subviews exist and have frames
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSLog(@"RootSplit items=%lu arrangedSubviews=%lu",
//              (unsigned long)self.splitViewItems.count,
//              (unsigned long)sv.arrangedSubviews.count);
//        for (NSView *sub in sv.arrangedSubviews) {
//            NSLog(@"  sub=%@ frame=%@", sub, NSStringFromRect(sub.frame));
//        }
//    });
    
}


- (void)viewDidAppear {
    [super viewDidAppear];

    NSSplitView *sv = self.splitView;

    // If autosave already has a stored position, don't override it
    NSString *key = [@"NSSplitView Subview Frames " stringByAppendingString:sv.autosaveName ?: @""];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:key])
        return;

    // Desired initial widths
    CGFloat leftDesired  = 600.0;
    ///CGFloat rightDesired = 250.0;

    // Clamp so we respect min thickness (left ≥ 400, right ≥ 0)
    CGFloat total = sv.bounds.size.width;
    CGFloat pos   = leftDesired; // divider position from the left
    CGFloat minPos = 400.0;                                  // left min
    CGFloat maxPos = total - sv.dividerThickness - 0.0;      // right min (0)

    if (maxPos < minPos) maxPos = minPos; // tiny window safety
    pos = fmax(minPos, fmin(pos, maxPos));

    [sv setPosition:pos ofDividerAtIndex:0];
}


#pragma mark - Dependency injection

- (void)setDocument:(TrackBrowserDocument *)doc {
    _document = doc; // assign on purpose
    if (self.isViewLoaded)
        [self injectDependencies];
}

- (void)setSelection:(Selection *)sel {
    if (_selection == sel)
        return;
    [_selection release];
    _selection = [sel retain];
    if (self.isViewLoaded)
        [self injectDependencies];
}

- (void)injectDependencies {
    if (_leftSplitController) {
        @try { [_leftSplitController setValue:_document  forKey:@"document"]; } @catch(__unused NSException *_) {}
        @try { [_leftSplitController setValue:_selection forKey:@"selection"]; } @catch(__unused NSException *_) {}
        if ([_leftSplitController respondsToSelector:@selector(injectDependencies)]) {
            [_leftSplitController performSelector:@selector(injectDependencies)];
        }
    }
    if (_rightSplitController) {
        @try { [_rightSplitController setValue:_document  forKey:@"document"]; } @catch(__unused NSException *_) {}
        @try { [_rightSplitController setValue:_selection forKey:@"selection"]; } @catch(__unused NSException *_) {}
        if ([_rightSplitController respondsToSelector:@selector(injectDependencies)]) {
            [_rightSplitController performSelector:@selector(injectDependencies)];
        }
    }
}


static const CGFloat kMinLeft = 160.0;
static const CGFloat kMinRight = 20.0;

- (CGFloat)splitView:(NSSplitView *)sv
constrainSplitPosition:(CGFloat)proposed
       ofSubviewAt:(NSInteger)dividerIndex
{
    if (sv.isVertical) {
        CGFloat total = NSWidth(sv.bounds);
        CGFloat maxPos = total - sv.dividerThickness - kMinRight; // keep right ≥ min
        CGFloat minPos = kMinLeft;                                // keep left  ≥ min
        return MIN(MAX(proposed, minPos), maxPos);
    } else {
        CGFloat total = NSHeight(sv.bounds);
        CGFloat maxPos = total - sv.dividerThickness - kMinRight;
        CGFloat minPos = kMinLeft;
        return MIN(MAX(proposed, minPos), maxPos);
    }
}


-(void)toggleCols
{
    NSSplitViewItem *item = self.splitViewItems.lastObject;
    if (item.isCollapsed) {
        NSSplitView* sv = self.splitView;
        CGFloat total   = sv.isVertical ? NSWidth(sv.bounds) : NSHeight(sv.bounds);
        CGFloat divider = sv.dividerThickness;
        CGFloat pos     = total - divider - _lastRightPaneWidth;
        ///[sv setPosition:pos ofDividerAtIndex:0];
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        ctx.duration = 0.45;
        ctx.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [[item animator] setCollapsed:!item.isCollapsed];
    } completionHandler:nil];
}


- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
    NSSplitView *sv = aNotification.object;
    if (sv != self.splitView || sv.subviews.count < 2) return;

    NSView *right = sv.subviews[1]; // rightmost (or bottom if horizontal)
    CGFloat w = sv.isVertical ? NSWidth(right.frame) : NSHeight(right.frame);

    // Only remember non-zero sizes so we keep a good restore width after a collapse
    if (w > 0.5) {
        NSLog(@"saving right panel width %0.1f", w);
        _lastRightPaneWidth = w;
    }
}

@end
