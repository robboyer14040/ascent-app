//
//  MainWindowController.m
//  Ascent  (NON-ARC)
//

#import "MainWindowController.h"
#import "RootSplitController.h"
#import "LeftSplitController.h"
#import "Selection.h"
#import "TrackBrowserDocument.h"
#import "MapDetailWindowController.h"
#import "Utils.h"
#import "NSView+Spin.h"
#import "AnimTimer.h"


NSString* OpenMapDetailNotification             = @"OpenMapDetail";
NSString* OpenActivityDetailNotification        = @"OpenActivityDetail";
NSString* TrackArrayChangedNotification         = @"TrackArrayChanged";
NSString* TrackSelectionDoubleClicked           = @"SelectionDoubleClicked";
NSString* TrackFieldsChanged                    = @"TrackFieldsChanged";
NSString* SyncActivitiesKickOff                 = @"SyncActivitiesKickOffNotification";     // actually starts the sync
NSString* SyncActivitiesStartingNotification    = @"SyncActivitiesStartingNotification";       // drives the animation
NSString* SyncActivitiesStoppingNotification    = @"SyncActivitiesStopingNotification";        // drives the animation
NSString* PreferencesChanged                    = @"PreferencesChanged";
NSString* TransportStateChanged                 = @"TransportStateChanged";

NSString * const TransportStateChangedInfoKey = @"TransportStateChangedInfoKey";



static void *kSelectionCtx = &kSelectionCtx;


@interface MainWindowController ()
{
    id _keyMonitor;
}
@property(nonatomic, retain) MapDetailWindowController* detailedMapWC;
@property(nonatomic, assign) BOOL syncing;
@property(nonatomic, assign) BOOL observingSelection;
@end


@implementation MainWindowController

@dynamic document; // implemented by NSWindowController
@synthesize selection = _selection;
@synthesize reservedTopArea = _reservedTopArea;
@synthesize contentContainer = _contentContainer;


- (void)awakeFromNib
{
    _syncing = NO;
    _observingSelection = NO;
    
    NSFont* font = [NSFont fontWithName:@"LCDMono Ultra" size:30];
    [_timecodeText setFont:font];
    [_timecodeText setTextColor:[NSColor colorNamed:@"TextPrimary"]];
    [_timecodeText setStringValue:@"00:00:00"];
    
    _timecodeText.enabled = NO;
    _transportControl.enabled = NO;
}


- (void)dealloc
{
    [self _stopObservingSelection];
    [[AnimTimer defaultInstance] unregisterForTimerUpdates:self];
    if (_keyMonitor) {
        [NSEvent removeMonitor:_keyMonitor];
        _keyMonitor = nil;
    }
    [_selection release];
    [_root release];
    [super dealloc];
}

- (RootSplitController *)rootSplitController
{
    return _root;
}


- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSView *contentView = self.window.contentView;
    
    // Make sure these outlets exist and are in the window
    NSAssert(self.reservedTopArea.superview == contentView, @"reservedTopArea not in window");
    NSAssert(self.contentContainer.superview == contentView, @"contentContainer not in window");
    
    // Give the top bar a fixed frame so the container actually has height
    CGFloat topH = 44.0;
    self.reservedTopArea.frame = NSMakeRect(0,
                                            NSHeight(contentView.bounds) - topH,
                                            NSWidth(contentView.bounds),
                                            topH);
    self.reservedTopArea.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    
    // Fill the rest with the container
    self.contentContainer.frame = NSMakeRect(0,
                                             0,
                                             NSWidth(contentView.bounds),
                                             NSHeight(contentView.bounds) - topH);
    self.contentContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // Create and embed the root split controller (no xib)
    _root = [[RootSplitController alloc] init];
    
    _root.document  = (TrackBrowserDocument *)self.document;
    
    Selection* sel = [[Selection alloc] init];
    [self setSelection:sel];    // sets _selection, propogates to root, etc
    
    NSView *childView = _root.view;          // this triggers RootSplitController -loadView
    childView.frame = self.contentContainer.bounds;
    childView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentContainer addSubview:childView];
    
    TrackPaneController *tpc = _root.leftSplitController.trackPaneController;
    
    NSMenu *fileMenu = [[NSApp mainMenu] itemWithTitle:@"File"].submenu;
    NSMenu *viewMenu = [[NSApp mainMenu] itemWithTitle:@"View"].submenu;
    
    NSSet<NSString *> *belongsToTPC = [NSSet setWithObjects:
                                       @"exportGPX:", @"exportKML:", @"exportTCX:",
                                       @"exportTXT:", @"exportCSV:",
                                       @"exportSummaryTXT:", @"exportSummaryCSV:",
                                       @"exportLatLonText:",
                                       @"googleEarthFlyBy:",
                                       @"centerOnPath:", @"centerAtStart:", @"centerAtEnd:",
                                       @"zoomIn:", @"zoomOut:", @"syncStravaActivities:",
                                       nil];
    
    __block void (^retarget)(NSMenu *menu, NSSet<NSString *> *sels);
    retarget = ^(NSMenu *menu, NSSet<NSString *> *sels) {
        for (NSMenuItem *it in menu.itemArray) {
            SEL a = it.action;
            if (a && [sels containsObject:NSStringFromSelector(a)]) {
                it.target = tpc;
            }
            ///if (it.submenu)
            ///    retarget(it.submenu, sels); // recursion OK because of __block
            
        }
        for (NSString *name in sels) {
            SEL a = NSSelectorFromString(name);
            if (![tpc respondsToSelector:a]) {
                NSLog(@"TPC does NOT implement %@", name); // <-- these will be disabled
            }
        }
    };
    
    retarget(fileMenu, belongsToTPC);
    ///retarget(viewMenu, belongsToTPC);
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(_syncCompleted)
               name:SyncActivitiesStoppingNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(_syncStarted)
               name:SyncActivitiesStartingNotification
             object:nil];
    
    [nc addObserverForName:TransportStateChanged
                    object:nil
                     queue:[NSOperationQueue mainQueue]  // <- main thread
                usingBlock:^(NSNotification *note){
        
        NSNumber* num = [note.userInfo objectForKey:TransportStateChangedInfoKey];
        if (num) {
            _transportControl.selectedSegment = num.intValue;
        }
    }];

//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//       DumpWindowDiagnostics(self.window); // replace with your NSWindow *
//    });
    
    // spacebar handling
    __block __weak MainWindowController *weakSelf = self; // weak to avoid retain-cycle with block
    _keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                       handler:^NSEvent * (NSEvent *e)
    {
        MainWindowController *self = weakSelf;
        if (!self) return e;

        if (e.window == self.window) {
            NSString *s = [e charactersIgnoringModifiers];
            if ([s isEqualToString:@" "]) {
                // optional: ignore if typing in a text view
                NSResponder *r = e.window.firstResponder;
                if (![r isKindOfClass:[NSTextView class]]) {
                    [[AnimTimer defaultInstance] togglePlay];   // your action
                    return nil; // swallow the space so it doesn’t trigger anything else
                }
            }
        }
        return e; // let other keys flow
    }];
    [[AnimTimer defaultInstance] registerForTimerUpdates:self];
    


}


#pragma mark - Document override & dependency propagation


- (void)setDocument:(NSDocument *)document {
    [super setDocument:document];
    _root.document = (TrackBrowserDocument *)document;
    if ([_root respondsToSelector:@selector(injectDependencies)]) {
        [_root injectDependencies];
    }
}


#pragma mark - Selection propagation

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection)
        return;
 
    if (_selection != nil) {
        [_selection release];
    }
     _selection = [selection retain];
    
    
    if (_selection) {
        [self _startObservingSelection];
    }
    
    if (_root) {
        _root.selection = selection;
        if ([_root respondsToSelector:@selector(injectDependencies)]) {
            [_root injectDependencies];
        }
    }
}


// List the TrackPane-specific actions here
static BOOL ActionIsTrackPaneAction(SEL a) {
    return YES;
//    return (a == @selector(doThing:) ||
//            a == @selector(prevTrack:) ||
//            a == @selector(nextTrack:) ||
//            a == @selector(exportSelected:) );
}

- (id)targetForAction:(SEL)action to:(id)target from:(id)sender {
    if (ActionIsTrackPaneAction(action)) {
        TrackPaneController *tpc = _root.leftSplitController.trackPaneController;
        if (tpc && [tpc respondsToSelector:action]) {
            return tpc;
        }
    }
    return nil;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
    ///NSLog(@"MWC - validating %@", item);
    
    id tgt = [self targetForAction:item.action to:nil from:self];
    if ([tgt respondsToSelector:_cmd]) {
        return [tgt validateUserInterfaceItem:item];
    }
    return YES;
}


-(IBAction)showMapDetail:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OpenMapDetailNotification object:self];
}

- (IBAction) showActivityDetail:(id) sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OpenActivityDetailNotification object:self];
}


- (IBAction)toggleRightColumns:(id)sender {
    [_root toggleCols];
}



#pragma mark - sync activities


-(IBAction)syncActivities:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SyncActivitiesKickOff object:self];    
}


-(void)_syncStarted
{
    if (!_syncing) {
        _syncing = YES;
        [self.syncButton setEnabled:NO];
        [self.syncButton asc_startSpinningWithDuration:0.9];
    }
}


-(void)_syncCompleted
{
    if (_syncing) {
        [self.syncButton asc_stopSpinning];
        [self.syncButton setEnabled:YES];
        _syncing = NO;
    }
}


// Latest Xcode / macOS helpers

// -------- Helpers that NEVER reference enum identifiers --------

static NSString *AttrName(NSInteger a) {
    // Values are stable across AppKit; but we also fall back to "Attr(n)".
    if (a == 0)  return @"NotAnAttribute";
    if (a == 1)  return @"Left";
    if (a == 2)  return @"Right";
    if (a == 3)  return @"Top";
    if (a == 4)  return @"Bottom";
    if (a == 5)  return @"Leading";
    if (a == 6)  return @"Trailing";
    if (a == 7)  return @"Width";
    if (a == 8)  return @"Height";
    if (a == 9)  return @"CenterX";
    if (a == 10) return @"CenterY";
    if (a == 11) return @"Baseline";
    if (a == 12) return @"FirstBaseline";
    // We intentionally skip all *Margin variants.
    return [NSString stringWithFormat:@"Attr(%ld)", (long)a];
}

static NSString *RelName(NSInteger r) {
    if (r == 0) return @"<=";   // NSLayoutRelationLessThanOrEqual
    if (r == 1) return @"==";   // NSLayoutRelationEqual
    if (r == 2) return @">=";   // NSLayoutRelationGreaterThanOrEqual
    return @"?";
}

static BOOL IsWidthAffectingAttribute(NSInteger a) {
    // Don’t rely on margin attrs; check the core ones only.
    return (a == 7 /*Width*/ ||
            a == 1 /*Left*/  || a == 2 /*Right*/ ||
            a == 5 /*Leading*/ || a == 6 /*Trailing*/ ||
            a == 9 /*CenterX*/);
}

static BOOL IsWidthAffectingConstraint(NSLayoutConstraint *c) {
    return IsWidthAffectingAttribute((NSInteger)c.firstAttribute) ||
           IsWidthAffectingAttribute((NSInteger)c.secondAttribute);
}

static void DumpConstraint(NSLayoutConstraint *c) {
    NSString *first  = c.firstItem  ? NSStringFromClass([c.firstItem  class]) : @"nil";
    NSString *second = c.secondItem ? NSStringFromClass([c.secondItem class]) : @"nil";
    NSLog(@"  • %@.%@ %@ %@.%@  mult=%.3f  const=%.3f  prio=%.0f  active=%d",
          first,  AttrName((NSInteger)c.firstAttribute),
          RelName((NSInteger)c.relation),
          second, AttrName((NSInteger)c.secondAttribute),
          c.multiplier, c.constant,
          c.priority, c.isActive);
}

static void DumpViewHorizontalInfo(NSView *v, NSInteger depth) {
    NSMutableString *indent = [NSMutableString string];
    for (NSInteger i=0; i<depth; i++) [indent appendString:@"  "];

    NSSize sz = v.frame.size;
    NSLog(@"%@⟶ <%@:%p> frame=(%.1f×%.1f) hugH=%.0f compResH=%.0f ambiguous=%d",
          indent, NSStringFromClass([v class]), v, sz.width, sz.height,
          [v contentHuggingPriorityForOrientation:NSLayoutConstraintOrientationHorizontal],
          [v contentCompressionResistancePriorityForOrientation:NSLayoutConstraintOrientationHorizontal],
          v.hasAmbiguousLayout);

    for (NSLayoutConstraint *c in v.constraints) {
        if (IsWidthAffectingConstraint(c)) {
            NSLog(@"%@  (owned)", indent);
            DumpConstraint(c);
        }
    }

    NSArray *aff = [v constraintsAffectingLayoutForOrientation:NSLayoutConstraintOrientationHorizontal];
    if (aff.count) {
        NSLog(@"%@  constraintsAffectingLayout(H):", indent);
        for (NSLayoutConstraint *c in aff) DumpConstraint(c);
    }

    for (NSView *sv in v.subviews) DumpViewHorizontalInfo(sv, depth+1);
}

static void DumpSplitViewHints(NSView *root) {
    if ([root isKindOfClass:[NSSplitView class]]) {
        NSSplitView *sv = (NSSplitView *)root;
        NSLog(@"[SPLIT] <%@: %p> isVertical=%d divider=%.1f subviews=%lu",
              NSStringFromClass([sv class]), sv, sv.isVertical, sv.dividerThickness,
              (unsigned long)sv.subviews.count);
        for (NSView *svv in sv.subviews) {
            NSLog(@"[SPLIT]   subview frame=(%.1f×%.1f) minW=%.1f maxW=%.1f",
                  svv.frame.size.width, svv.frame.size.height,
                  svv.fittingSize.width, CGFLOAT_MAX);
        }
    }
    for (NSView *sv in root.subviews) DumpSplitViewHints(sv);
}

// -------- Public entry point --------

void DumpWindowDiagnostics(NSWindow *w) {
    if (!w) { NSLog(@"[Diag] Window is nil"); return; }

    NSLog(@"[Window] %@ (ptr=%p)", w.title ?: @"<untitled>", w);
    NSLog(@"[Window] styleMask=%lu resizable=%d",
          (unsigned long)w.styleMask, (w.styleMask & NSWindowStyleMaskResizable) != 0);
    NSLog(@"[Window] frame=(%.1f×%.1f) content=(%.1f×%.1f)",
          w.frame.size.width, w.frame.size.height,
          w.contentView.frame.size.width, w.contentView.frame.size.height);
    NSLog(@"[Window] minSize=%@ maxSize=%@ contentMin=%@ contentMax=%@",
          NSStringFromSize(w.minSize), NSStringFromSize(w.maxSize),
          NSStringFromSize(w.contentMinSize), NSStringFromSize(w.contentMaxSize));
    NSLog(@"[Window] resizeIncrements=%@ preservesContentDuringLiveResize=%d",
          NSStringFromSize(w.resizeIncrements), w.preservesContentDuringLiveResize);

    NSView *root = w.contentView;
    if (!root) { NSLog(@"[Diag] No contentView"); return; }

    NSLog(@"[ContentView] width-related constraints:");
    for (NSLayoutConstraint *c in root.constraints) if (IsWidthAffectingConstraint(c)) DumpConstraint(c);

    NSLog(@"[Hierarchy] Scanning…");
    DumpViewHorizontalInfo(root, 0);

    NSLog(@"[SplitView] Hints…");
    DumpSplitViewHints(root);

    NSLog(@"[End Diagnostics]");
}


#pragma mark - Transport

-(IBAction)transportButtonPushed:(id)sender
{
    
    NSSegmentedControl *seg = (NSSegmentedControl *)sender;
    NSNumber *num = [NSNumber numberWithInt: (int)seg.selectedSegment];  
    [[AnimTimer defaultInstance] requestTransportStateChange:num.intValue];
}


#pragma mark - Animation Target Protocol


-(Track*) animationTrack
{
    return _selection.selectedTrack;
}


-(void) beginAnimation
{
    _timecodeText.enabled = YES;
}


-(void) endAnimation
{
    _timecodeText.enabled = NO;
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev  animating:(BOOL)anim
{
   NSString* s = [[NSString alloc] initWithFormat:@"%02.2d:%02.2d:%02.2d",
                  (int)(trackTime/(60*60)),
                  (int)((trackTime/60))%60,
                  ((int)trackTime)%60];
   [_timecodeText setStringValue:s];
#if 0
    AnimTimer * at = [AnimTimer defaultInstance];
    float endTime = [at endingTime];
   if (endTime > 0.0)
   {
      [locationSlider setFloatValue:[at animTime]*100.0/endTime];
   }
   if (([playButton intValue] != 0) && [at playingInReverse])
   {
      [playButton setIntValue:0];
      [reverseButton setIntValue:1];
   }
   else if (([reverseButton intValue] != 0) && ![at playingInReverse])
   {
      [playButton setIntValue:1];
      [reverseButton setIntValue:0];
   }
#endif
}


#pragma mark - Selection changing


- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _selectionChanged];
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


-(void) _selectionChanged
{
    _transportControl.enabled = (_selection.selectedTrack != nil);
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
        [self _selectionChanged];
        return;
    }

    // if you added more keys:
    // if ([keyPath isEqualToString:@"selectedTrackRegion"]) { ...; return; }

    // Fallback:
    [self _selectionDidChangeCompletely];
}




@end
