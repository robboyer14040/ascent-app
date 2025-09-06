// SplashPanelController.m  (MRC / non-ARC)
// Uses SplashPanel.xib. File’s Owner = SplashPanelController, outlets connected.
// Image is in an NSImageView, message in an NSTextField, and miniProgress is a custom NSView.
// No custom drawing subclasses required; we use CALayer sublayers.

#import "SplashPanelController.h"
#import <QuartzCore/QuartzCore.h> // CALayer, CATransaction

static SplashPanelController *gShared = nil;

@interface SplashPanelController () {
    // Fade state
    NSTimer   *_fadeTimer;
    CGFloat    _fadeAlpha;
    BOOL       _canDismiss;

    // Keep-on-top helpers
    NSInteger  _originalLevel;
    BOOL       _keepOnTop;

    // Mini progress (created lazily on first updateProgress:total:)
    CALayer   *_mpBorderLayer;
    CALayer   *_mpFillLayer;
}

// Internal helpers
- (void)_showCenteredWithHighLevel:(BOOL)high;
- (void)_forceOnScreenNow;
- (void)_reassertFront:(NSNotification *)n;
- (NSRect)_centeredFrameForSize:(NSSize)sz;

// Mini progress helpers
- (void)_ensureMiniProgressLayers;
- (void)_updateMiniProgressFraction:(CGFloat)f;

@end

@implementation SplashPanelController

#pragma mark - Singleton

+ (SplashPanelController *)sharedInstance
{
    if (gShared == nil) {
        gShared = [[self alloc] initWithWindowNibName:@"SplashPanel"];
        // Nib/window loads lazily on first access
    }
    return gShared;
}

#pragma mark - NSWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];

    NSWindow *w = [self window];
    w.delegate = self;
    w.hidesOnDeactivate = NO;
    w.opaque = YES;
    w.collectionBehavior |= (NSWindowCollectionBehaviorCanJoinAllSpaces |
                             NSWindowCollectionBehaviorFullScreenAuxiliary);

    // Message field appearance
    if (self.messageField) {
        [self.messageField setBezeled:NO];
        [self.messageField setDrawsBackground:NO];
        [self.messageField setEditable:NO];
        [self.messageField setSelectable:NO];
        [self.messageField setAlignment:NSTextAlignmentCenter];
    }

    // We do not create progress layers yet. Nothing should be visible
    // until -updateProgress:total: is actually called.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_fadeTimer) {
        [_fadeTimer invalidate];
        [_fadeTimer release];
        _fadeTimer = nil;
    }

    // Mini progress layers cleanup (they are retained by superlayer when attached)
    if (_mpFillLayer) {
        [_mpFillLayer removeFromSuperlayer];
        [_mpFillLayer release];
        _mpFillLayer = nil;
    }
    if (_mpBorderLayer) {
        [_mpBorderLayer removeFromSuperlayer];
        [_mpBorderLayer release];
        _mpBorderLayer = nil;
    }

    [super dealloc];
}

#pragma mark - Public API

- (void)showPanel
{
    [self showPanelCenteredOnMainScreen];
}

- (void)hidePanel
{
    NSWindow *w = [self window];
    _keepOnTop = NO;
    if (_fadeTimer) { [_fadeTimer invalidate]; [_fadeTimer release]; _fadeTimer = nil; }
    [w orderOut:nil];
    [w setAlphaValue:1.0];
}

- (void)updateMessage:(NSString *)msg
{
    if (self.messageField) {
        [self.messageField setStringValue:(msg ?: @"")];
        [self.messageField displayIfNeeded];
    }
    // Push pending CA transactions & give the runloop a fast tick
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0]];
}

// New mini-progress API: draws a 1px black border and a black left-fill.
// Nothing is created/rendered until the first time this is called.
- (void)updateProgress:(int)current total:(int)total
{
    if (!self.miniProgress) return;
    if (total <= 0) return; // undefined fraction; skip (also keeps it invisible)

    // Clamp fraction [0,1]
    CGFloat f = (CGFloat)current / (CGFloat)total;
    if (f < 0.f) f = 0.f;
    if (f > 1.f) f = 1.f;

    [self _ensureMiniProgressLayers];
    [self _updateMiniProgressFraction:f];

    // Force an immediate visual update
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0]];
}

- (void)canDismiss:(BOOL)yessno
{
    _canDismiss = yessno ? YES : NO;
}

- (void)startFade:(id)dummy
{
    (void)dummy;
    if (_fadeTimer) {
        [_fadeTimer invalidate];
        [_fadeTimer release];
        _fadeTimer = nil;
    }
    _fadeAlpha = 1.0;
    _fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05
                                                   target:self
                                                 selector:@selector(_fadeStep:)
                                                 userInfo:nil
                                                  repeats:YES] retain];
}

- (void)showPanelCenteredOnMainScreen
{
    [self _showCenteredWithHighLevel:NO];
}

- (void)showPanelCenteredOnMainScreenWithHighLevel:(BOOL)high
{
    [self _showCenteredWithHighLevel:high];
}

#pragma mark - Fade

- (void)_fadeStep:(NSTimer *)__unused t
{
    NSWindow *w = [self window];
    _fadeAlpha -= 0.05;
    if (_fadeAlpha <= 0.0) {
        [_fadeTimer invalidate];
        [_fadeTimer release];
        _fadeTimer = nil;

        [w orderOut:nil];
        [w setAlphaValue:1.0];
        _keepOnTop = NO;
        return;
    }
    [w setAlphaValue:MAX(0.0, _fadeAlpha)];
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(id)__unused sender
{
    if (!_canDismiss) return NO;
    [self hidePanel];
    return NO;
}

#pragma mark - Internal helpers

- (void)_showCenteredWithHighLevel:(BOOL)high
{
    [self window]; // ensure nib loaded

    NSWindow *w = [self window];

    // Center on main/first screen
    [w setFrame:[self _centeredFrameForSize:w.frame.size] display:NO];

    _originalLevel = w.level;
    w.level = high ? (NSPopUpMenuWindowLevel + 1) : NSFloatingWindowLevel;

    [NSApp activateIgnoringOtherApps:YES];

    if ([w canBecomeKeyWindow]) {
        [w makeKeyAndOrderFront:nil];
    } else {
        [w orderFrontRegardless];
    }

    _keepOnTop = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_reassertFront:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_reassertFront:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:nil];

    [self _forceOnScreenNow];
}

- (void)_forceOnScreenNow
{
    NSWindow *w = [self window];
    [w displayIfNeeded];
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0]];
}

- (void)_reassertFront:(NSNotification *)__unused n
{
    if (_keepOnTop) {
        [[self window] orderFrontRegardless];
    }
}

- (NSRect)_centeredFrameForSize:(NSSize)sz
{
    NSScreen *scr = [NSScreen mainScreen];
    if (!scr) {
        NSArray *screens = [NSScreen screens];
        if (screens.count) scr = [screens objectAtIndex:0];
    }
    NSRect vis = scr ? scr.visibleFrame : NSMakeRect(0, 0, 800, 600);
    NSRect f;
    f.size = sz;
    f.origin.x = NSMidX(vis) - sz.width  * 0.5;
    f.origin.y = NSMidY(vis) - sz.height * 0.5;
    return f;
}

#pragma mark - Mini progress (CALayer-based)

- (void)_ensureMiniProgressLayers
{
    if (!self.miniProgress) return;

    // Ensure the view has a hosting layer
    if (![self.miniProgress wantsLayer]) {
        [self.miniProgress setWantsLayer:YES];
    }
    CALayer *host = self.miniProgress.layer;
    host.masksToBounds = YES;
    host.contentsScale = [self.window backingScaleFactor];

    if (_mpBorderLayer == nil) {
        _mpBorderLayer = [[CALayer layer] retain];
        _mpBorderLayer.frame = host.bounds;
        _mpBorderLayer.backgroundColor = [[NSColor clearColor] CGColor];
        _mpBorderLayer.borderColor = [[NSColor blackColor] CGColor];
        _mpBorderLayer.borderWidth = 0.0;
        _mpBorderLayer.contentsScale = host.contentsScale;
        [host addSublayer:_mpBorderLayer];

        // Keep border crisp if the view resizes
        // (we update frames in _updateMiniProgressFraction:)
    }

    if (_mpFillLayer == nil) {
        _mpFillLayer = [[CALayer layer] retain];
        _mpFillLayer.frame = NSMakeRect(0, 0, 0, host.bounds.size.height);
        _mpFillLayer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] CGColor]; // 25% opacity
        _mpFillLayer.anchorPoint = CGPointMake(0.0, 0.5);
        _mpFillLayer.position = CGPointMake(0.0, host.bounds.size.height * 0.5);
        _mpFillLayer.contentsScale = host.contentsScale;
        [host addSublayer:_mpFillLayer];
    }
}

- (void)_updateMiniProgressFraction:(CGFloat)f
{
    if (!self.miniProgress) return;
    if (!_mpBorderLayer || !_mpFillLayer) return;

    CALayer *host = self.miniProgress.layer;

    // Update to current bounds (in case of resize)
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _mpBorderLayer.frame = host.bounds;

    CGFloat w = host.bounds.size.width;
    CGFloat h = host.bounds.size.height;
    CGFloat fillW = floor(w * f);

    _mpFillLayer.bounds = CGRectMake(0, 0, fillW, h);
    _mpFillLayer.position = CGPointMake(0.0, h * 0.5); // anchored left

    [CATransaction commit];
}

@end
