//
//  FullImageBrowserWindowController.m
//  Ascent
//
//  Manual Retain/Release (MRC)
//

#import "FullImageBrowserWindowController.h"

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static void *kKVOContextPresentationSize = &kKVOContextPresentationSize;

#pragma mark - Key Relay View

@interface ASCKeyRelayView : NSView
{
    id _target; // assign
}
@property (assign) id target;
@end

@implementation ASCKeyRelayView
@synthesize target = _target;

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder  { return YES; }
- (BOOL)resignFirstResponder  { return YES; }

- (void)keyDown:(NSEvent *)event
{
    if (!_target) { [super keyDown:event]; return; }
    switch (event.keyCode) {
        case 123: if ([_target respondsToSelector:@selector(goPrev)])  { [_target goPrev];  return; } break; // ←
        case 124: if ([_target respondsToSelector:@selector(goNext)])  { [_target goNext];  return; } break; // →
        case 49:  if ([_target respondsToSelector:@selector(togglePlayPause)]) { [_target togglePlayPause]; return; } break; // space
        case 53:  if ([_target respondsToSelector:@selector(close)])   { [_target close];   return; } break; // esc
        default: break;
    }
    [super keyDown:event];
}
@end


#pragma mark - Controller

@interface FullImageBrowserWindowController () <NSWindowDelegate>
{
    // Media source
    NSURL       *_baseURL;          // security-scoped directory URL (resolved from bookmark)
    NSArray     *_mediaNames;       // NSArray<NSString *>
    NSInteger    _index;

    // Security-scoped access
    BOOL         _baseScopeStarted;
    NSURL       *_scopedItemURL;    // held when base scope not available

    // UI
    ASCKeyRelayView *_content;      // accepts first responder
    NSImageView     *_imageView;

    // Video
    AVPlayerView *_playerView;
    AVPlayer     *_player;
    AVPlayerItem *_observedItem;    // KVO: presentationSize

    id           _localMonitor;     // optional: local key monitor
    BOOL         _isMovieShowing;
}

// Build / sizing
- (void)buildWindowIfNeeded;
- (void)applyWindowLimitsForVisibleFrame;
- (NSSize)targetContentSizeForPixelSize:(NSSize)pxSize;

// Media location
- (NSURL *)URLForName:(NSString *)name;
- (BOOL)isMovieURL:(NSURL *)url;

// Display media
- (void)showMediaAtIndex:(NSInteger)idx;
- (void)showImageAtURL:(NSURL *)url title:(NSString *)title;
- (void)showMovieAtURL:(NSURL *)url title:(NSString *)title;

// Player helpers
- (void)cleanupPlayerKVO;
- (void)teardownPlayer;

// Scoped access helpers
- (void)beginBaseScopeIfNeeded;
- (void)releasePerItemScopeIfNeeded;
- (void)holdPerItemScopeForURLIfNeeded:(NSURL *)url;

// Navigation
- (void)goNext;
- (void)goPrev;
- (void)togglePlayPause;

@end


@implementation FullImageBrowserWindowController

- (id)initWithBaseURL:(NSURL *)baseURL
           mediaNames:(NSArray *)names
           startIndex:(NSInteger)start
                title:(NSString *)title
{
    NSRect r = NSMakeRect(0, 0, 900, 600);
    NSWindow *win = [[[NSWindow alloc] initWithContentRect:r
                                                 styleMask:(NSWindowStyleMaskTitled |
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskMiniaturizable |
                                                            NSWindowStyleMaskResizable)
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO] autorelease];

    if ((self = [super initWithWindow:win])) {
        [self setShouldCascadeWindows:NO];
        [self setWindowFrameAutosaveName:@"FullImageBrowserWindow"];
        self.window.titleVisibility = NSWindowTitleVisible;
        self.window.releasedWhenClosed = NO;
        self.window.delegate = self;

        _baseURL        = [baseURL copy];
        _mediaNames     = [names copy];
        _index          = (start >= 0 && start < (NSInteger)[_mediaNames count]) ? start : 0;
        _baseScopeStarted = NO;
        _scopedItemURL  = nil;

        if (title.length) self.window.title = title;

        [self beginBaseScopeIfNeeded];
        [self buildWindowIfNeeded];
        [self applyWindowLimitsForVisibleFrame];

        // Make the window key and ensure our relay view becomes first responder
        [self.window makeKeyAndOrderFront:nil];
        [self.window makeFirstResponder:_content];

        // Optional: also keep a local key monitor (works even if first responder changes)
        __block typeof(self) bself = self;
        _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                              handler:^NSEvent * (NSEvent *event) {
            if ([NSApp keyWindow] != bself.window) return event;
            switch (event.keyCode) {
                case 123: [bself goPrev];  return nil;
                case 124: [bself goNext];  return nil;
                case 49:  [bself togglePlayPause]; return nil;
                case 53:  [bself close];   return nil;
                default: return event;
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    if (_localMonitor) { [NSEvent removeMonitor:_localMonitor]; _localMonitor = nil; }

    [self cleanupPlayerKVO];
    [self teardownPlayer];

    [self releasePerItemScopeIfNeeded];
    if (_baseScopeStarted && _baseURL) {
        [_baseURL stopAccessingSecurityScopedResource];
        _baseScopeStarted = NO;
    }

    [_imageView release]; _imageView = nil;
    [_playerView release]; _playerView = nil;
    [_content release]; _content = nil;

    [_mediaNames release]; _mediaNames = nil;
    [_baseURL release]; _baseURL = nil;

    [super dealloc];
}

#pragma mark - Scoped Access Helpers

- (void)beginBaseScopeIfNeeded
{
    if (!_baseURL || ![_baseURL isFileURL]) return;
    BOOL ok = [_baseURL startAccessingSecurityScopedResource];
    _baseScopeStarted = ok;
}

- (void)releasePerItemScopeIfNeeded
{
    if (_scopedItemURL) {
        @try { [_scopedItemURL stopAccessingSecurityScopedResource]; } @catch (__unused id e) {}
        [_scopedItemURL release];
        _scopedItemURL = nil;
    }
}

- (void)holdPerItemScopeForURLIfNeeded:(NSURL *)url
{
    if (_baseScopeStarted) { [self releasePerItemScopeIfNeeded]; return; }
    [self releasePerItemScopeIfNeeded];
    if (url && [url isFileURL]) {
        if ([url startAccessingSecurityScopedResource]) {
            _scopedItemURL = [url retain];
        }
    }
}

#pragma mark - Build UI

- (void)buildWindowIfNeeded
{
    if (_content) return;

    _content = [[ASCKeyRelayView alloc] initWithFrame:self.window.contentView.bounds];
    _content.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _content.target = self;
    [self.window setContentView:_content];

    _imageView = [[NSImageView alloc] initWithFrame:_content.bounds];
    _imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    _imageView.imageAlignment = NSImageAlignCenter;
    _imageView.editable = NO;
    _imageView.animates = YES;
    _imageView.hidden = YES;
    [_content addSubview:_imageView];

    _playerView = [[AVPlayerView alloc] initWithFrame:_content.bounds];
    _playerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _playerView.controlsStyle = AVPlayerViewControlsStyleInline;
    _playerView.videoGravity = AVLayerVideoGravityResizeAspect;
    _playerView.hidden = YES;
    [_content addSubview:_playerView];

    // Initial media
    [self showMediaAtIndex:_index];
}

#pragma mark - Window / Sizing

- (void)applyWindowLimitsForVisibleFrame
{
    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    if (!screen) return;

    NSRect vis = screen.visibleFrame;
    if (vis.size.width <= 0 || vis.size.height <= 0) return;

    CGFloat maxW = floor(vis.size.width  * 0.96);
    CGFloat maxH = floor(vis.size.height * 0.96);
    self.window.contentMinSize = NSMakeSize(320, 240);
    self.window.contentMaxSize = NSMakeSize(MAX(320, maxW), MAX(240, maxH));
}

- (NSSize)targetContentSizeForPixelSize:(NSSize)pxSize
{
    if (pxSize.width <= 0 || pxSize.height <= 0) return NSMakeSize(900, 600);

    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    NSRect vis = screen.visibleFrame;
    CGFloat maxW = floor(vis.size.width  * 0.96);
    CGFloat maxH = floor(vis.size.height * 0.96);

    double sx = maxW / pxSize.width;
    double sy = maxH / pxSize.height;
    double s  = MIN(1.0, MIN(sx, sy)); // do not upscale on open

    NSSize out = NSMakeSize((CGFloat)floor(pxSize.width * s),
                            (CGFloat)floor(pxSize.height * s));
    if (out.width < 320 || out.height < 240) {
        double sm = MAX(320.0/out.width, 240.0/out.height);
        out.width  = (CGFloat)floor(out.width * sm);
        out.height = (CGFloat)floor(out.height * sm);
        out.width  = MIN(out.width,  maxW);
        out.height = MIN(out.height, maxH);
    }
    return out;
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification *)n
{
    // Ensure we keep focus for arrow keys
    if (self.window.firstResponder != _content) {
        [self.window makeFirstResponder:_content];
    }
}

#pragma mark - Navigation

- (void)goNext
{
    if ([_mediaNames count] == 0) return;
    NSInteger next = (_index + 1) % (NSInteger)[_mediaNames count];
    [self showMediaAtIndex:next];
}

- (void)goPrev
{
    if ([_mediaNames count] == 0) return;
    NSInteger prev = _index - 1;
    if (prev < 0) prev = (NSInteger)[_mediaNames count] - 1;
    [self showMediaAtIndex:prev];
}

- (void)togglePlayPause
{
    if (!_isMovieShowing || !_player) return;
    if (_player.rate > 0.0) [_player pause];
    else [_player play];
}

#pragma mark - Media Dispatch

- (void)showMediaAtIndex:(NSInteger)idx
{
    if (idx < 0 || idx >= (NSInteger)[_mediaNames count]) return;
    _index = idx;

    NSString *name = [_mediaNames objectAtIndex:(NSUInteger)_index];
    NSURL *url = [self URLForName:name];
    if (!url) return;

    NSString *title = [name lastPathComponent];

    // Hold per-file scope if base scope isn't active
    [self holdPerItemScopeForURLIfNeeded:url];

    if ([self isMovieURL:url]) {
        [self showMovieAtURL:url title:title];
    } else {
        [self showImageAtURL:url title:title];
    }
}

- (NSURL *)URLForName:(NSString *)name
{
    if (name.length == 0) return nil;

    // Absolute URL strings supported
    if ([name hasPrefix:@"file:/"] || [name hasPrefix:@"http://"] || [name hasPrefix:@"https://"]) {
        NSURL *u = [NSURL URLWithString:name];
        if (u) return u;
    }

    // Strip "media/" prefix like in Strava dumps
    NSString *leaf = name;
    if ([leaf hasPrefix:@"media/"]) leaf = [leaf substringFromIndex:6];

    if (_baseURL && [_baseURL isFileURL]) {
        return [_baseURL URLByAppendingPathComponent:leaf];
    }
    if ([leaf hasPrefix:@"/"]) {
        return [NSURL fileURLWithPath:leaf];
    }
    return nil;
}

- (BOOL)isMovieURL:(NSURL *)url
{
    NSString *ext = [[url pathExtension] lowercaseString];
    static NSSet *movies = nil;
    if (!movies) movies = [[NSSet alloc] initWithObjects:@"mp4",@"mov",@"m4v",@"avi",@"mkv",@"mpeg",@"mpg", nil];
    return [movies containsObject:ext];
}

#pragma mark - Image

- (void)showImageAtURL:(NSURL *)url title:(NSString *)title
{
    _isMovieShowing = NO;

    // Tear down any player first
    [self teardownPlayer];

    // Load image (scoped access already active)
    NSImage *img = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
    if (!img) {
        _imageView.image = nil;
        _imageView.hidden = NO;
        _playerView.hidden = YES;
        self.window.title = [NSString stringWithFormat:@"%@ (unreadable)", title ?: @"Image"];
        return;
    }

    // Determine pixel size
    NSSize px = [img size];
    if (px.width <= 0 || px.height <= 0) {
        NSBitmapImageRep *rep = (NSBitmapImageRep *)[img bestRepresentationForRect:NSMakeRect(0,0,INT_MAX,INT_MAX)
                                                                           context:nil
                                                                             hints:nil];
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            px.width  = rep.pixelsWide;
            px.height = rep.pixelsHigh;
        }
    }

    [self applyWindowLimitsForVisibleFrame];
    NSSize target = [self targetContentSizeForPixelSize:px];
    [self.window setContentSize:target];

    _imageView.image = img;
    _imageView.hidden = NO;
    _playerView.hidden = YES;

    if (title.length) self.window.title = title;

    // Make sure we keep key focus for arrow keys
    if ([NSApp keyWindow] != self.window) [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:_content];
}

#pragma mark - Movie

- (void)cleanupPlayerKVO
{
    if (_observedItem) {
        @try {
            [_observedItem removeObserver:self
                               forKeyPath:@"presentationSize"
                                  context:kKVOContextPresentationSize];
        } @catch (__unused id e) {}
        [_observedItem release];
        _observedItem = nil;
    }
}

- (void)teardownPlayer
{
    [self cleanupPlayerKVO];

    if (_playerView) {
        [_playerView setPlayer:nil];
    }
    if (_player) {
        [_player pause];
        [_player release];
        _player = nil;
    }
}

- (void)showMovieAtURL:(NSURL *)url title:(NSString *)title
{
    _isMovieShowing = YES;

    [self teardownPlayer];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    _player = [[AVPlayer alloc] initWithPlayerItem:item];
    [_playerView setPlayer:_player];
    _playerView.hidden = NO;
    _imageView.hidden = YES;

    // KVO presentationSize
    _observedItem = [item retain];
    [_observedItem addObserver:self
                    forKeyPath:@"presentationSize"
                       options:NSKeyValueObservingOptionNew
                       context:kKVOContextPresentationSize];

    // Reasonable default content size before we know the real one
    [self applyWindowLimitsForVisibleFrame];
    [self.window setContentSize:NSMakeSize(960, 540)];

    if (title.length) self.window.title = title;

    // Keep key focus for arrow keys
    if ([NSApp keyWindow] != self.window) [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:_content];

    [_player play];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == kKVOContextPresentationSize) {
        NSValue *v = [change objectForKey:NSKeyValueChangeNewKey];
        if (![v isKindOfClass:[NSValue class]]) return;
#if TARGET_OS_IPHONE
        CGSize cg = [v CGSizeValue];
        NSSize ps = NSMakeSize(cg.width, cg.height);
#else
        NSSize ps = [v sizeValue];
#endif
        if (ps.width > 0.0 && ps.height > 0.0) {
            [self applyWindowLimitsForVisibleFrame];
            NSSize target = [self targetContentSizeForPixelSize:ps];
            [self.window setContentSize:target];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - NSWindow actions

- (void)close
{
    // calling super ensures proper teardown/dealloc later
    [super close];
}

@end
