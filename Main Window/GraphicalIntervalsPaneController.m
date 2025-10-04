//
//  GraphicalIntervalsPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "GraphicalIntervalsPaneController.h"
#import "SplitsGraphView.h"
#import "Selection.h"
#import "Utils.h"
#
static void *kSelectionCtx = &kSelectionCtx;

@interface GraphicalIntervalsPaneController ()
@property (nonatomic, assign) BOOL observingSelection;
@end



@implementation GraphicalIntervalsPaneController
@synthesize document = _document;
@synthesize selection = _selection;

- (void)awakeFromNib
{
    _observingSelection = NO;
    NSMenu* lengthSubMenu = nil;
    NSMenu* graphSubMenu = nil;
    [_contentView setGraphItem:[Utils intFromDefaults:RCBDefaultSplitGraphItem]];

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
        [self _displaySelectedTrackSplits:t];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
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



- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _displaySelectedTrackSplits:t];
}


-(void) _displaySelectedTrackSplits:(Track*)trk
{
}


@end
