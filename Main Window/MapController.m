//
//  MapController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "MapController.h"
#import "MapPathView.h"
#import "TransparentMapView.h"
#import "TransparentMapWindow.h"
#import "Selection.h"
#import "Utils.h"
#import "DMWindowController.h"

static void *kSelectionCtx = &kSelectionCtx;

@interface MapController ()
{
    TransparentMapView*         _transparentMapAnimView;
    TransparentMapWindow*       _transparentMapWindow;
    DMWindowController*         _detailedMapWC;
}
- (void)_didDoubleClick:(NSClickGestureRecognizer *)g;
- (void)_showMapDetail;
@end

@implementation MapController
@synthesize document=_document, selection=_selection;

- (void)awakeFromNib {
    [super awakeFromNib];
    NSRect dummy;
    dummy.size.width = 10;
    dummy.size.height = 10;
    dummy.origin.x = 0;
    dummy.origin.y = 0;
//    transparentMapWindow = [[[TransparentMapWindow alloc] initWithContentRect:dummy
//                                                                  styleMask:NSWindowStyleMaskBorderless
//                                                                    backing:NSBackingStoreBuffered
//                                                                      defer:NO] retain];
//    
//    transparentMapAnimView = [[TransparentMapView alloc] initWithFrame:dummy
//                                                               hasHUD:NO];
//    [transparentMapWindow setContentView:transparentMapAnimView];
    
    float opac = [Utils floatFromDefaults:@"DefaultMapTransparency"];
    [_mapPathView setMapOpacity:opac];
    [_mapPathView setDefaults];

}


- (void)dealloc {
    [_detailedMapWC release];
    [_selection release];
    [_mapPathView prepareToDie];
    [_mapPathView killAnimThread];
    // [_transparentMapWindow release]; don't need because setReleasedWhenClosed is set to "YES"
    [_transparentMapAnimView release];
    [super dealloc];
}


- (void)injectDependencies {
    // Use _document / _selection as needed.
}


- (void)viewDidLoad {
    [super viewDidLoad];
    NSClickGestureRecognizer *doubleClick = [[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(_didDoubleClick:)] autorelease];
    doubleClick.numberOfClicksRequired = 2;
    doubleClick.buttonMask = 0x1;
    // Make single wait on double to avoid firing both
    ///[single requireGestureRecognizerToFail:doubleClick];
    [self.mapPathView addGestureRecognizer:doubleClick];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showMapDetail)
                                                 name:OpenMapDetailNotification
                                               object:nil];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [self.mapPathView setCurrentTrack:_selection.selectedTrack];
    [self.mapPathView setNeedsDisplay:YES];
}


- (void)_didDoubleClick:(NSClickGestureRecognizer *)g
{
    if (g.state == NSGestureRecognizerStateEnded) {
//        NSPoint p = [g locationInView:self.mapPathView];
//        [self _handleDoubleClickAt:p];
        [self showMapDetail];
        
    }
}


- (void)showMapDetail
{
    Track* track = _selection.selectedTrack;
    if (!_document || !track)
        return;
    
    if (!_detailedMapWC)
    {
        int curDataType = [[self mapPathView] dataType];
        _detailedMapWC   = [[[DMWindowController alloc] initWithDocument:_document
                                                         initialDataType:curDataType
                                                                  mainWC:self.view.window.windowController] retain];
        [_document addWindowController:_detailedMapWC];
      }
    
    if (_detailedMapWC) {
        [_detailedMapWC setTrack:track];
        [_detailedMapWC setSelectedLap:_selection.selectedLap];
        [_detailedMapWC showWindow:self];
        [[_detailedMapWC window] makeKeyAndOrderFront:self];
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
        [self _displayTrackOnMap:t];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
}

#pragma mark - Map updates

- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _displayTrackOnMap:t];
}

- (void)_displayTrackOnMap:(Track *)track {
    [_mapPathView setCurrentTrack:track];
    [_mapPathView setNeedsDisplay:YES];
}



@end
