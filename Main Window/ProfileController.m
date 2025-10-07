//
//  ProfileController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ProfileController.h"
#import "MiniProfileView.h"
#import "Selection.h"
#import "Utils.h"
#import "ActivityWindowController.h"
#import "AnimTimer.h"
#import "Track.h"
#import "TransparentMapView.h"

@class track, lap;

static void *kSelectionCtx = &kSelectionCtx;

@interface ProfileController()
@property(nonatomic, assign) BOOL isExpanded;
@property(nonatomic, retain) ActivityWindowController* expandedActivityWindow;
- (void)_didSingleClick:(NSClickGestureRecognizer *)g;
- (void)_didDoubleClick:(NSClickGestureRecognizer *)g;
- (void) showActivityDetail;
@end


@implementation ProfileController
@synthesize document=_document, selection=_selection;

- (void)awakeFromNib
{
    _isExpanded = NO;
    [super awakeFromNib];
    // Wire up plot view, axes, data sources here.
}


- (void)dealloc
{
    if (self.expandedActivityWindow) {
         self.expandedActivityWindow.customDelegate = nil;
    }
    [_expandedActivityWindow release];
    [_selection release];
    [super dealloc];
}


- (void)injectDependencies
{
    // Pull data from _document / _selection and refresh plot if view is loaded.
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    ///NSClickGestureRecognizer *single = [[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(_didSingleClick:)] autorelease];
    NSClickGestureRecognizer *doubleClick = [[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(_didDoubleClick:)] autorelease];
    doubleClick.numberOfClicksRequired = 2;
    doubleClick.buttonMask = 0x1;
    // Make single wait on double to avoid firing both
    ///[single requireGestureRecognizerToFail:doubleClick];
    [self.profileView addGestureRecognizer:doubleClick];    // fixme - transparent view
    [[NSNotificationCenter defaultCenter]  addObserver:self
                                              selector:@selector(showActivityDetail)
                                                  name:OpenActivityDetailNotification
                                                object:nil];
    
    [[AnimTimer defaultInstance] registerForTimerUpdates:self];
    
    [self.profileView setTransparentView:_transparentView];
    self.expandButton.alphaValue = .6;
}


- (void)viewWillDisappear
{
    [[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
}


- (void)_didSingleClick:(NSClickGestureRecognizer *)g
{
    if (g.state == NSGestureRecognizerStateEnded) {
//        NSPoint p = [g locationInView:self.mapPathView];
//        [self _handleDoubleClickAt:p];
        
    }
}


- (void)_didDoubleClick:(NSClickGestureRecognizer *)g
{
    if (g.state == NSGestureRecognizerStateEnded) {
        [self showActivityDetail];
    }
}




#pragma mark - Selection wiring

- (void)setSelection:(Selection *)sel {
    if (sel == _selection) return;

    // Stop observing the old Selection
    [self _stopObservingSelection];

    // MRC retain new one
    [_selection release];
    _selection = [sel retain];

    // Start observing the new Selection
    [self _startObservingSelection];

    // Optional: refresh immediately based on current Selection state
    [self _selectionDidChangeCompletely];
}

- (void)_startObservingSelection {
    if (!_selection) return;

    // Observe the key(s) on Selection you care about.
    // Replace "selectedTrack" with your actual property name(s).
    @try {
        [_selection addObserver:self
                     forKeyPath:@"selectedTrack"
                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                        context:kSelectionCtx];

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
    @try { [_selection removeObserver:self forKeyPath:@"selectedTrack" context:kSelectionCtx]; } @catch (...) {}
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
        if ((id)t == (id)[NSNull null]) t = nil;
        [self _displayTrackProfile:t];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
}

#pragma mark - updates

- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try { t = [_selection valueForKey:@"selectedTrack"]; } @catch(...) {}
    [self _displayTrackProfile:t];
}

- (void)_displayTrackProfile:(Track *)track {
    [_profileView setCurrentTrack:track];
    [_profileView setNeedsDisplay:YES];
    _selection.selectedTrack.animTimeBegin = 0.0;
    _selection.selectedTrack.animTimeEnd =  _selection.selectedTrack.movingDuration;
    [[AnimTimer defaultInstance] updateTimerDuration];
}

#pragma mark - AnimTimer...

-(void) beginAnimation
{
}


-(void) endAnimation
{
}


- (Track*) animationTrack
{
    return _selection.selectedTrack;
}


- (void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev  animating:(BOOL)anim;
{
    NSUInteger pos = 0;
    Track* track = _selection.selectedTrack;
    if (track)
    {
        NSUInteger numPoints = [[track goodPoints] count];
        pos = [track animIndex];
        if (pos >= numPoints && numPoints > 0)
            pos = numPoints-1;
        [_profileView updateTrackAnimation:(int)pos];
    }
}


- (IBAction)expand:(id)sender
{
    [self showActivityDetail];
}


- (void) showActivityDetail
{
    if (!_document)
        return;
    
    Track* track = _selection.selectedTrack;
    if (track && !_isExpanded) {
        Lap* lap = _selection.selectedLap;
        if (!_expandedActivityWindow) {
            ActivityWindowController* ad = [[[ActivityWindowController alloc] initWithDocument:_document] autorelease];
            self.expandedActivityWindow = ad;
            self.expandedActivityWindow.customDelegate = self;
        }
        [_expandedActivityWindow showWindow:self];
        [_expandedActivityWindow setTrack:track];
        [_expandedActivityWindow setLap:lap];
        
        _isExpanded = YES;
        _expandButton.enabled = NO;
    }
}


#pragma mark - Window delegate
- (void)activityWindowControllerDidClose:(ActivityWindowController *)controller;
{
    _isExpanded = NO;
    _expandButton.enabled = YES;
}

@end
