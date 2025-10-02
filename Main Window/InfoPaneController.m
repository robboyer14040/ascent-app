//
//  InfoPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "InfoPaneController.h"
#import "MetricsController.h"
#import "InfoController.h"
#import "Selection.h"
#import "Track.h"

static void *kSelectionCtx = &kSelectionCtx;

@interface InfoPaneController ()
{
    NSViewController*   _currentVC;
}
@property (nonatomic, assign) BOOL observingSelection;
@property (nonatomic, assign) BOOL metricsMode;
@end

@implementation InfoPaneController
@synthesize document = _document;
@synthesize selection = _selection;
@synthesize controlsBar = _controlsBar;
@synthesize activityTitle = _activityTitle;

- (void)awakeFromNib
{
    _observingSelection = NO;
    _metricsMode = NO;
    _currentVC = nil;
    
    [super awakeFromNib];
    
    if (_controlsBar != nil) {
        _controlsBar.material = NSVisualEffectMaterialHeaderView;
        _controlsBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        _controlsBar.state = NSVisualEffectStateFollowsWindowActiveState;
    }

    _infoVC = [[InfoController alloc] initWithNibName:@"InfoController" bundle:nil];
    _metricsVC = [[MetricsController alloc] initWithNibName:@"MetricsController" bundle:nil];

    [self injectDependencies];

    [self setMode:NO];

    if (_modeToggle != nil) {
        [_modeToggle setTarget:self];
        [_modeToggle setAction:@selector(modeChanged:)];
    }
    
    [(id)self.metricsVC setValue:self.document forKey:@"document"];
    [(id)self.metricsVC setValue:self.selection forKey:@"selection"];
    [(id)self.infoVC setValue:self.document forKey:@"document"];
    [(id)self.infoVC setValue:self.selection forKey:@"selection"];

    [self.modeToggle setSelectedSegment:0];
    [self showMode:0];
}


-(void) dealloc
{
    [self _stopObservingSelection];
    [super dealloc];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


- (void)viewWillDisappear
{
    [self _stopObservingSelection];
}

- (void)viewWillAppear
{
    [self _startObservingSelection];
}

- (void)setMode:(BOOL)metricsMode
{
    _metricsMode = metricsMode;

    NSViewController *target = nil;
    if (_metricsMode) {
        target = _metricsVC;
    } else {
        target = _infoVC;
    }

    if (_currentVC == target) {
        return;
    }

    if (_currentVC != nil) {
        [[_currentVC view] removeFromSuperview];
        [_currentVC removeFromParentViewController];
    }

    _currentVC = target;

    if (_currentVC == nil) {
        return;
    }

    [self addChildViewController:_currentVC];

    NSView *v = _currentVC.view;
    [_contentContainer addSubview:v];
}


- (IBAction)modeChanged:(id)sender
{
    [self setMode:[self.modeToggle selectedSegment] == 1];
    [self showMode:_metricsMode];
}


- (void)showMode:(NSInteger)segmentIndex
{
    for (NSView *v in [[self.contentContainer subviews] copy]) {
        [v removeFromSuperview];
    }
    NSViewController *vc = (segmentIndex == 1) ? self.metricsVC : self.infoVC;
    if (!vc) {
        return;
    }
    NSView *v = [vc view];
    ///    [v setFrame:[self.contentContainer bounds]];
    ///    [v setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    v.translatesAutoresizingMaskIntoConstraints = NO; // use Auto Layout
    [self.contentContainer addSubview:v];
    
    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor],
    ]];
}


- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    if (_document) {
        [self injectDependencies];
    }
}


- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];
    [self injectDependencies];
    [self _startObservingSelection];
}


- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _metricsVC;
    if (vc != nil) {
        @try {
            [vc setValue:_document forKey:@"document"];
        }
        @catch (__unused NSException *ex) {}
        @try {
            [vc setValue:_selection forKey:@"selection"];
        }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _infoVC;
    if (vc != nil) {
        @try {
            [vc setValue:_document forKey:@"document"];
        }
        @catch (__unused NSException *ex) {}
        @try {
            [vc setValue:_selection forKey:@"selection"];
        }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
}


- (void)_startObservingSelection {
    if (!_selection)
        return;

    // Observe the key(s) on Selection you care about.
    // Replace "selectedTrack" with your actual property name(s).
    @try {
        if (_selection && !_observingSelection) {
            [_selection addObserver:self
                         forKeyPath:@"selectedTrack"
                            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                            context:kSelectionCtx];
            _observingSelection = YES;
        }
        // Add more keys if needed:
        // [_selection addObserver:self forKeyPath:@"selectedTrackRegion" options:... context:kSelectionCtx];
        // [_selection addObserver:self forKeyPath:@"selectedSegments"    options:... context:kSelectionCtx];
    } @catch (__unused NSException *ex) {
        // No-op: protects if key missing in some builds
    }
}


- (void)_stopObservingSelection {
    if (!_selection) return;

    // Remove observers defensively
    @try {
        if (_selection && _observingSelection) {
            [_selection removeObserver:self forKeyPath:@"selectedTrack" context:kSelectionCtx];
            _observingSelection = NO;
        }
    } @catch (...) {}
    // @try { [_selection removeObserver:self forKeyPath:@"selectedTrackRegion" context:kSelectionCtx]; } @catch (...) {}
    // @try { [_selection removeObserver:self forKeyPath:@"selectedSegments"    context:kSelectionCtx]; } @catch (...) {}
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != kSelectionCtx) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if ([keyPath isEqualToString:@"selectedTrack"]) {
        Track *t = [change objectForKey:NSKeyValueChangeNewKey];
        if ((id)t == (id)[NSNull null])
            t = nil;
        [self _displaySelectedTrackInfo:t];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
}


- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _displaySelectedTrackInfo:t];
}


-(void) _displaySelectedTrackInfo:(Track*)trk
{
    if (trk) {
        _activityTitle.font = [NSFont boldSystemFontOfSize:14.0];
        _activityTitle.string = trk.name;
        [_activityTitle setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, _activityTitle.string.length)];
        [_activityTitle setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, _activityTitle.string.length)];
        [self _updateVerticalCenteringForTextView:_activityTitle];
     }
}

// Call this once after outlets load (awakeFromNib / viewDidLoad)
- (void)_configureTextViewForVerticalCentering:(NSTextView *)tv
{
    tv.richText = NO;

    // Standard scrollable text view config that still allows centering:
    tv.verticallyResizable = YES;
    tv.horizontallyResizable = NO;

    NSTextContainer *tc = tv.textContainer;
    tc.widthTracksTextView = YES;
    tc.heightTracksTextView = NO;                 // let doc height grow when text is long
    tc.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);

    // Ensure doc view is at least as tall as the visible area so we can center when short.
    NSScrollView *sv = tv.enclosingScrollView;
    CGFloat visibleH = sv ? NSHeight(sv.contentView.bounds) : NSHeight(tv.bounds);
    tv.minSize = NSMakeSize(0, visibleH);         // floor at viewport height
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);

    [self _updateVerticalCenteringForTextView:tv];
}

// Recompute inset after resize or text edits
- (void)_updateVerticalCenteringForTextView:(NSTextView *)tv
{
    NSLayoutManager *lm = tv.layoutManager;
    NSTextContainer *tc = tv.textContainer;
    if (!lm || !tc) return;

    // Ensure layout is up-to-date
    (void)[lm glyphRangeForTextContainer:tc];
    NSRect used = [lm usedRectForTextContainer:tc];

    // Use the viewport height (clip view) if embedded in a scroll view
    NSScrollView *sv = tv.enclosingScrollView;
    CGFloat visibleH = sv ? NSHeight(sv.contentView.bounds) : NSHeight(tv.bounds);

    // Desired equal top/bottom inset
    CGFloat extra = visibleH - NSHeight(used);
    CGFloat insetY = (extra > 0.0) ? floor(extra / 2.0) : 0.0;

    NSSize inset = tv.textContainerInset;
    if (fabs(inset.height - insetY) > 0.5) {     // avoid churn
        tv.textContainerInset = NSMakeSize(inset.width, insetY);
    }
}


@end
