//
//  InfoController.m
//  Ascent
//
//  Created by Rob Boyer on 9/30/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "InfoController.h"
#import "Selection.h"
#import "TrackBrowserDocument.h"
#import "Track.h"
#import "FullImageBrowserWindowController.h"


static void *kSelectionCtx = &kSelectionCtx;
static void *kImgChangeCtx = &kImgChangeCtx;



static NSString * const kStravaRootBookmarkKey = @"StravaRootBookmarkData";

static inline NSRect ASCImageRectForImageView(NSImageView *iv)
{
    NSRect b = iv.bounds;
    NSImage *img = iv.image;
    if (!img) return NSZeroRect;

    NSSize isz = img.size;
    if (isz.width <= 0.0 || isz.height <= 0.0) return NSZeroRect;

    // Determine draw size from scaling
    NSSize draw = isz;
    switch (iv.imageScaling) {
        case NSImageScaleAxesIndependently:
            draw = b.size;
            break;

        case NSImageScaleProportionallyDown: {
            CGFloat sx = b.size.width  / isz.width;
            CGFloat sy = b.size.height / isz.height;
            CGFloat s = MIN(1.0, MIN(sx, sy)); // don’t scale up
            draw.width  = floor(isz.width  * s);
            draw.height = floor(isz.height * s);
            break;
        }

        case NSImageScaleProportionallyUpOrDown: {
            CGFloat sx = b.size.width  / isz.width;
            CGFloat sy = b.size.height / isz.height;
            CGFloat s = MIN(sx, sy);           // fit inside
            draw.width  = floor(isz.width  * s);
            draw.height = floor(isz.height * s);
            break;
        }

        case NSImageScaleNone:
        default:
            // draw = isz
            break;
    }

    // Align inside the bounds
    CGFloat dx = 0.0, dy = 0.0;
    switch (iv.imageAlignment) {
        case NSImageAlignCenter:
            dx = (b.size.width  - draw.width)  * 0.5;
            dy = (b.size.height - draw.height) * 0.5;
            break;
        case NSImageAlignTop:
            dx = (b.size.width  - draw.width)  * 0.5;
            dy =  b.size.height - draw.height;
            break;
        case NSImageAlignTopLeft:
            dx = 0.0; dy = b.size.height - draw.height;
            break;
        case NSImageAlignTopRight:
            dx = b.size.width - draw.width; dy = b.size.height - draw.height;
            break;
        case NSImageAlignLeft:
            dx = 0.0; dy = (b.size.height - draw.height) * 0.5;
            break;
        case NSImageAlignRight:
            dx = b.size.width - draw.width; dy = (b.size.height - draw.height) * 0.5;
            break;
        case NSImageAlignBottom:
            dx = (b.size.width - draw.width) * 0.5; dy = 0.0;
            break;
        case NSImageAlignBottomLeft:
            dx = 0.0; dy = 0.0;
            break;
        case NSImageAlignBottomRight:
            dx = b.size.width - draw.width; dy = 0.0;
            break;
        default:
            dx = (b.size.width  - draw.width)  * 0.5;
            dy = (b.size.height - draw.height) * 0.5;
            break;
    }

    return NSIntegralRect(NSMakeRect(b.origin.x + dx, b.origin.y + dy, draw.width, draw.height));
}


@interface InfoController ()
{
    NSTrackingArea *_imageTracking;
    NSButton *_leftButton;
    NSButton *_rightButton;
    NSClickGestureRecognizer *_imageClickGR;
}
@property (nonatomic, assign) BOOL observingSelection;
@property (nonatomic, assign) NSUInteger pictureIndex;
@property (nonatomic, assign) NSUInteger pictureButtonSize;     // for w and h
@property (nonatomic, retain) FullImageBrowserWindowController *imageBrowser;
- (void)_setButtonsHidden:(BOOL)hidden;
@end


@implementation InfoController
@synthesize document = _document;
@synthesize selection = _selection;


- (void)awakeFromNib
{
    _observingSelection = NO;
    _pictureIndex = 0;
    _pictureButtonSize = 16;
    [self _installHoverButtonsIfNeeded];

    if (_picture && !_imageTracking) {
        _imageTracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                      options:(NSTrackingMouseEnteredAndExited |
                                                               NSTrackingActiveAlways |
                                                               NSTrackingInVisibleRect)
                                                        owner:self
                                                     userInfo:nil];
        [_picture addTrackingArea:_imageTracking];
    }

    if (_picture && !_imageClickGR) {
        _imageClickGR = [[NSClickGestureRecognizer alloc] initWithTarget:self
                                                                  action:@selector(_onImageClicked:)];
        _imageClickGR.delegate = self;
        [_picture addGestureRecognizer:_imageClickGR];
    }

    // observe image changes to re-position overlays
    [_picture addObserver:self forKeyPath:@"image" options:0 context:kImgChangeCtx];

    [self _setButtonsHidden:YES];
    [self _updateOverlayButtonFrames];
}


-(void) dealloc
{
    [self _stopObservingSelection];
    if (_imageTracking && _picture) {
        [_picture removeTrackingArea:_imageTracking];
    }
    [_imageTracking release];

    if (_imageClickGR && _picture) {
        [_picture removeGestureRecognizer:_imageClickGR];
    }
    [_imageClickGR release];

    @try {
        [_picture removeObserver:self forKeyPath:@"image" context:kImgChangeCtx];
    }
    @catch (__unused NSException *ex) {}

    [_leftButton removeFromSuperview];  [_leftButton release];
    [_rightButton removeFromSuperview]; [_rightButton release];

    [super dealloc];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_trackFieldsChanged)
                                                 name:TrackFieldsChanged
                                               object:nil];
}


- (void)viewDidLayout {
    [super viewDidLayout];
    [self _updateOverlayButtonFrames];
}


- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
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
    [self _startObservingSelection];
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
    if (!_selection)
        return;

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
    if (context == kImgChangeCtx) {
        [self _updateOverlayButtonFrames];
        return;
    }

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
        _notes.string = [trk attribute:kNotes];
        _weather.string = [trk attribute:kWeather];
        _location.string = [trk attribute:kLocation];
        _pictureIndex = 0;

        [self _displayPicture:trk
                        index:_pictureIndex];
    }
}


-(void) _trackFieldsChanged
{
    Track* track = _selection.selectedTrack;
    if (track) {
        [self _displaySelectedTrackInfo:track];
    }
}


- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer
shouldAttemptToRecognizeWithEvent:(NSEvent *)event
{
    if (gestureRecognizer != _imageClickGR)
        return YES;

    // Point in imageView coords
    NSPoint p = [_picture convertPoint:event.locationInWindow fromView:nil];

    // If buttons are hidden or nil, nothing to filter
    if (!_leftButton.hidden && NSPointInRect(p, _leftButton.frame))
        return NO;
    if (!_rightButton.hidden && NSPointInRect(p, _rightButton.frame))
        return NO;

    // (Optional) If buttons have subviews, you can also check isDescendantOf, but the
    // frame check above already handles normal buttons.
    return YES; // treat as an image click
}



- (void)_onImageClicked:(NSClickGestureRecognizer *)gr {
    if (gr.state == NSGestureRecognizerStateEnded) {
        [self _showImageBrowser:nil];
    }
}

-(NSArray*) _filteredPictureArray:(Track*)track
{
    if (!track)
        return nil;
    NSSet<NSString *> *imageExts = [NSSet setWithArray:@[
        @"jpg", @"jpeg", @"png", @"gif", @"tif", @"tiff", @"bmp", @"heic", @"heif", @"webp"
    ]];
    
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
        NSString *ext = nil;
        if ([obj isKindOfClass:NSString.class]) {
            ext = [(NSString *)obj pathExtension].lowercaseString;
        } else if ([obj isKindOfClass:NSURL.class]) {
            ext = [(NSURL *)obj pathExtension].lowercaseString;
        }
        BOOL isImage = (ext.length > 0) && [imageExts containsObject:ext];
        return isImage;
    }];
    return  [track.localMediaItems filteredArrayUsingPredicate:pred];
}


-(void) _displayPicture:(Track*)track index:(NSUInteger)tentativeNewIndex
{
    if (!track)
        return;
    
    NSImage* img = nil;
    NSArray* filteredArray = [self _filteredPictureArray:track];
    NSUInteger numPictures = filteredArray.count;
    if (tentativeNewIndex < 0 || tentativeNewIndex >= numPictures) {
        return;
    }
    
    _pictureIndex = tentativeNewIndex;
    NSString* picName = filteredArray[_pictureIndex];
    NSError* err = nil;
    img = [self _imageUnderStravaRootForRelativePath:picName
                                               error:&err];
    _picture.imageScaling = NSImageScaleProportionallyUpOrDown;
    _picture.image = img; // if nil, should erase image
    [self _updateOverlayButtonFrames];
    _leftButton.enabled = (_pictureIndex > 0);
    _rightButton.enabled = (_pictureIndex < (numPictures-1));
    [_picture setNeedsDisplay:YES];
}


- (NSImage *)_imageUnderStravaRootForRelativePath:(NSString *)relPath error:(NSError **)error {
    
    NSURL* root = [self getRootMediaURL];
    
    BOOL ok = [root startAccessingSecurityScopedResource];
    NSURL *child = [root URLByAppendingPathComponent:relPath];
    NSImage *img = [[NSImage alloc] initWithContentsOfURL:child];
    if (ok)
        [root stopAccessingSecurityScopedResource];
    return img;
}


- (void)_showImageBrowser:(id)sender {
    Track* track = _selection.selectedTrack;
    if (!track)
        return;
    
    // Supply your filenames array (e.g. from the currently selected track)
    NSArray<NSString *> *filenames = [self _filteredPictureArray:track];
#if 0
    NSError *error = nil;
    
    NSData *bm = [[NSUserDefaults standardUserDefaults] objectForKey:kStravaRootBookmarkKey];
    if (!bm) { if (error) error = [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:@"No saved folder permission"}]; return; }
    
    BOOL stale = NO;
    NSError *err = nil;
    NSURL *root = [NSURL URLByResolvingBookmarkData:bm
                                            options:NSURLBookmarkResolutionWithSecurityScope
                                      relativeToURL:nil
                                bookmarkDataIsStale:&stale
                                              error:&err];
    if (!root) { if (error) error = err; return; }
    if (stale) {
        NSData *nbm = [root bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&err];
        if (nbm) [[NSUserDefaults standardUserDefaults] setObject:nbm forKey:kStravaRootBookmarkKey];
    }
#endif
    NSURL* root = [self getRootMediaURL];
    
    if (filenames.count == 0 || !root)
        return;
    
    // Determine which image is currently shown in the thumbnail (optional)
    // If you know the filename, compute its index; otherwise just start at 0
    
    if (!self.imageBrowser) {
         FullImageBrowserWindowController *wc =
             [[FullImageBrowserWindowController alloc] initWithBaseURL:root
                                                            mediaNames:filenames
                                                            startIndex:_pictureIndex
                                                                 title:nil];
         self.imageBrowser = wc;          // retain (MRC)
         [wc release];

         [[NSNotificationCenter defaultCenter] addObserver:self
                                                  selector:@selector(imageBrowserWillClose:)
                                                      name:NSWindowWillCloseNotification
                                                    object:[self.imageBrowser window]];
         [self.imageBrowser showWindow:self];
     } else {
         [self.imageBrowser showMediaAtIndex:_pictureIndex];
     }
}


- (void)imageBrowserWillClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:NSWindowWillCloseNotification
                                                   object:[self.imageBrowser window]];

     // Defer destruction until AppKit finishes closing
     FullImageBrowserWindowController *wc = [self.imageBrowser retain];
     self.imageBrowser = nil;

     dispatch_async(dispatch_get_main_queue(), ^{
         [wc release];
     });
}


- (NSURL*) getRootMediaURL
{
    Track* track = _selection.selectedTrack;
    if (!track)
        return nil;
    
    ///NSArray<NSString *> *filenames = track.localMediaItems ?: @[];
    NSError *error = nil;
    
    NSData *bm = [[NSUserDefaults standardUserDefaults] objectForKey:kStravaRootBookmarkKey];
    if (!bm) { if (error) error = [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:@"No saved folder permission"}]; return nil; }

    BOOL stale = NO;
    NSError *err = nil;
    NSURL *root = [NSURL URLByResolvingBookmarkData:bm
                                            options:NSURLBookmarkResolutionWithSecurityScope
                                      relativeToURL:nil
                                bookmarkDataIsStale:&stale
                                              error:&err];
    if (!root) { if (error) error = err; return nil; }
    if (stale) {
        NSData *nbm = [root bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                       includingResourceValuesForKeys:nil
                                        relativeToURL:nil
                                                error:&err];
        if (nbm) [[NSUserDefaults standardUserDefaults] setObject:nbm forKey:kStravaRootBookmarkKey];
    }
    return root;
}


- (NSString *)filenameShownInThumbnailIfKnown {
    // If you keep the current filename, return it here; otherwise return nil.
    // For example, if you just showed the first image from localMediaItems:
    // return _selection.selectedTrack.localMediaItems.firstObject;
    return nil;
}



#pragma mark - Setup

- (void)_installHoverButtonsIfNeeded {
    if (!_picture) return;

    if (!_leftButton) {
        _leftButton = [[NSButton alloc] initWithFrame:NSMakeRect(0,0,_pictureButtonSize,_pictureButtonSize)];
        _leftButton.translatesAutoresizingMaskIntoConstraints = YES; // we set frames
        _leftButton.bordered = YES;
        _leftButton.bezelStyle = NSBezelStyleShadowlessSquare;
        _leftButton.title = @"←";
        _leftButton.font = [NSFont systemFontOfSize:10.0];
        _leftButton.alignment = NSTextAlignmentCenter;
        _leftButton.target = self;
        _leftButton.action = @selector(onLeftButton:);
        [_picture addSubview:_leftButton positioned:NSWindowAbove relativeTo:nil];
    }

    if (!_rightButton) {
        _rightButton = [[NSButton alloc] initWithFrame:NSMakeRect(0,0,_pictureButtonSize,_pictureButtonSize)];
        _rightButton.translatesAutoresizingMaskIntoConstraints = YES;
        _rightButton.bordered = YES;
        _rightButton.bezelStyle = NSBezelStyleShadowlessSquare;
        _rightButton.title = @"→";
        _rightButton.font = [NSFont systemFontOfSize:10.0];
        _rightButton.alignment = NSTextAlignmentCenter;
        _rightButton.target = self;
        _rightButton.action = @selector(onRightButton:);
        [_picture addSubview:_rightButton positioned:NSWindowAbove relativeTo:nil];
    }
}

- (void)_setButtonsHidden:(BOOL)hidden {
    _leftButton.hidden  = hidden;
    _rightButton.hidden = hidden;
}

#pragma mark - Tracking (owner = self)

- (void)mouseEntered:(NSEvent *)event {
    if (event.trackingArea == _imageTracking) {
        [self _setButtonsHidden:NO];
    }
}

- (void)mouseExited:(NSEvent *)event {
    if (event.trackingArea == _imageTracking) {
        [self _setButtonsHidden:YES];
    }
}

#pragma mark - Actions (stubs)

- (IBAction)onLeftButton:(id)sender {
    Track* track = _selection.selectedTrack;
    if (track && _pictureIndex > 0) {
       [self _displayPicture:track
                        index:_pictureIndex - 1];
    }
}

- (IBAction)onRightButton:(id)sender {
    Track* track = _selection.selectedTrack;
    if (track) {
         [self _displayPicture:track
                        index:_pictureIndex + 1];
    }
}


- (void)_updateOverlayButtonFrames
{
    if (!_leftButton || !_rightButton || !_picture)
        return;

    const CGFloat pad = 8.0;
    const CGFloat sz  = _pictureButtonSize;

    NSRect imgRect = ASCImageRectForImageView(_picture);

    // If there’s no image or it resolves to zero rect, fall back to the view bounds.
    if (NSIsEmptyRect(imgRect)) {
        NSRect b = _picture.bounds;
        CGFloat y = NSMidY(b) - sz/2.0;
        _leftButton.frame  = NSMakeRect(NSMinX(b) + pad,      y, sz, sz);
        _rightButton.frame = NSMakeRect(NSMaxX(b) - pad - sz, y, sz, sz);
        return;
    }

    CGFloat y = NSMidY(imgRect) - sz/2.0;
    NSRect left  = NSMakeRect(NSMinX(imgRect) - pad - sz,  y, sz, sz);
    NSRect right = NSMakeRect(NSMaxX(imgRect) + pad,       y, sz, sz);

    // Clamp inside the image view for very small images
    NSRect bounds = _picture.bounds;
    if (NSMaxX(left)  > NSMaxX(bounds)) left.origin.x  = NSMaxX(bounds) - sz;
    if (NSMinX(left)  < NSMinX(bounds)) left.origin.x  = NSMinX(bounds);
    if (NSMaxX(right) > NSMaxX(bounds)) right.origin.x = NSMaxX(bounds) - sz;
    if (NSMinX(right) < NSMinX(bounds)) right.origin.x = NSMinX(bounds);
    if (NSMinY(left)  < NSMinY(bounds)) left.origin.y  = NSMinY(bounds);
    if (NSMinY(right) < NSMinY(bounds)) right.origin.y = NSMinY(bounds);
    if (NSMaxY(left)  > NSMaxY(bounds)) left.origin.y  = NSMaxY(bounds) - sz;
    if (NSMaxY(right) > NSMaxY(bounds)) right.origin.y = NSMaxY(bounds) - sz;

    _leftButton.frame  = NSIntegralRect(left);
    _rightButton.frame = NSIntegralRect(right);
}


@end
