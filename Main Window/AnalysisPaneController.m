//
//  AnalysisPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "AnalysisPaneController.h"
#import "Selection.h"
#import "SegmentsController.h"
#import "GraphicalIntervalsPaneController.h"
#import "TextualIntervalsPaneController.h"
#import "IntervalSettingsDialogController.h"
#import "SplitsGraphView.h"
#import "SplitTableItem.h"
#import "IndexTagMap.h"
#import "Track.h"
#import "TrackPoint.h"
#import "Utils.h"

static void *kSelectionCtx = &kSelectionCtx;


@interface AnalysisPaneController ()
@property(nonatomic, assign) BOOL showSplitsGraphically;
@property(nonatomic, assign) BOOL showingSplits;
@property(nonatomic, assign) BOOL observingSelection;
@property(nonatomic, assign) NSViewController                   *currentIntervalsVC;
@property(nonatomic, retain) GraphicalIntervalsPaneController   *graphicalIntervalsVC;
@property(nonatomic, retain) TextualIntervalsPaneController     *textualIntervalsVC;
@property(nonatomic, retain) NSPopover                          *intervalSettingsPopover;
@property(nonatomic, retain) IndexTagMap                        *splitItemIndexToTag;  // index in sSplitsColInfo to UI settings popover tag
@property(nonatomic, retain) NSMutableArray                     *splitArray;
@property(nonatomic, retain) IntervalSettingsDialogController   *intervalSettingsDialog;
@end


@implementation AnalysisPaneController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize controlsBar = _controlsBar;
@synthesize viewModeControl = _viewModeControl;
@synthesize contentContainer = _contentContainer;
@synthesize parentSplitVC = _parentSplitVC;

- (void)awakeFromNib
{
    [super awakeFromNib];
 
    _observingSelection = NO;
    _showSplitsGraphically = YES;
    _showingSplits = YES;
    
    if (_controlsBar != nil) {
        _controlsBar.material = NSVisualEffectMaterialHeaderView;
        _controlsBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        _controlsBar.state = NSVisualEffectStateFollowsWindowActiveState;
    }
    
    SegmentsController *segments = [[SegmentsController alloc] initWithNibName:@"SegmentsController" bundle:nil];
    _segmentsVC = segments;
    
    self.graphicalIntervalsVC = [[[GraphicalIntervalsPaneController alloc] init]autorelease];
    self.textualIntervalsVC = [[[TextualIntervalsPaneController alloc] init] autorelease];
    
    
    _currentIntervalsVC = _graphicalIntervalsVC;
    
    [self injectDependencies];
    
    // Default until Segments is fully implemented
    [self showIntervals];
    
    if (_viewModeControl != nil) {
        [_viewModeControl setTarget:self];
        [_viewModeControl setAction:@selector(toggleViewMode:)];
    }
    
    _splitArray = [[NSMutableArray alloc] init];

    _splitItemIndexToTag = [[IndexTagMap alloc] init];
    
    [_splitItemIndexToTag setTag:100 + kVT_Average          forIndex:kSC_SpeedAvg];
    [_splitItemIndexToTag setTag:100 + kVT_Maximum          forIndex:kSC_SpeedMax];
    [_splitItemIndexToTag setTag:100 + kVT_DeltaFromLast    forIndex:kSC_SpeedDeltaFromLast];
    [_splitItemIndexToTag setTag:100 + kVT_DeltaFromAverage forIndex:kSC_SpeedDeltaFromAvg];
    
    [_splitItemIndexToTag setTag:200 + kVT_Average          forIndex:kSC_PowerAvg];
    [_splitItemIndexToTag setTag:200 + kVT_Maximum          forIndex:kSC_PowerMax];
    [_splitItemIndexToTag setTag:200 + kVT_DeltaFromLast    forIndex:kSC_PowerDeltaFromLast];
    [_splitItemIndexToTag setTag:200 + kVT_DeltaFromAverage forIndex:kSC_PowerDeltaFromAvg];
    
    [_splitItemIndexToTag setTag:300 + kVT_Average          forIndex:kSC_HeartRateAvg];
    [_splitItemIndexToTag setTag:300 + kVT_Maximum          forIndex:kSC_HeartRateMax];
    [_splitItemIndexToTag setTag:300 + kVT_DeltaFromLast    forIndex:kSC_HeartRateDeltaFromLast];
    [_splitItemIndexToTag setTag:300 + kVT_DeltaFromAverage forIndex:kSC_HeartRateDeltaFromAvg];
    
    [_splitItemIndexToTag setTag:400 + kVT_Average          forIndex:kSC_GradientAvg];
    [_splitItemIndexToTag setTag:400 + kVT_Maximum          forIndex:kSC_GradientMax];
    [_splitItemIndexToTag setTag:400 + kVT_Minimum          forIndex:kSC_GradientMin];
    [_splitItemIndexToTag setTag:400 + kVT_DeltaFromLast    forIndex:kSC_GradientDeltaFromLast];
    [_splitItemIndexToTag setTag:400 + kVT_DeltaFromAverage forIndex:kSC_GradientDeltaFromAvg];
    
    [_splitItemIndexToTag setTag:500 + kVT_Average          forIndex:kSC_CadenceAvg];
    [_splitItemIndexToTag setTag:500 + kVT_Maximum          forIndex:kSC_CadenceMax];
    [_splitItemIndexToTag setTag:500 + kVT_DeltaFromLast    forIndex:kSC_CadenceDeltaFromLast];
    [_splitItemIndexToTag setTag:500 + kVT_DeltaFromAverage forIndex:kSC_CadenceDeltaFromAvg];
    
    [_splitItemIndexToTag setTag:600 + kVT_Average          forIndex:kSC_Climb];
    [_splitItemIndexToTag setTag:600 + kVT_DeltaFromLast    forIndex:kSC_ClimbDeltaFromLast];
    
    [_splitItemIndexToTag setTag:800 + kVT_Average          forIndex:kSC_VAMPos];
    [_splitItemIndexToTag setTag:800 + kVT_DeltaFromLast    forIndex:kSC_VAMPosDeltaFromLast];
    
    [_splitItemIndexToTag setTag:900 + kVT_Average          forIndex:kSC_VAMNeg];
    [_splitItemIndexToTag setTag:900 + kVT_DeltaFromLast    forIndex:kSC_VAMNegDeltaFromLast];
    
    [_splitItemIndexToTag setTag:1000 + kVT_Average          forIndex:kSC_PaceAvg];
    [_splitItemIndexToTag setTag:1000 + kVT_Minimum          forIndex:kSC_PaceMin];
    [_splitItemIndexToTag setTag:1000 + kVT_DeltaFromLast    forIndex:kSC_PaceDeltaFromLast];
    [_splitItemIndexToTag setTag:1000 + kVT_DeltaFromAverage forIndex:kSC_PaceDeltaFromAvg];
}


- (void)dealloc
{
    [self _stopObservingSelection];
    self.splitArray = nil;
    [_intervalSettingsDialog release];
    [_splitItemIndexToTag release];
    [_intervalSettingsPopover release];
    [_graphicalIntervalsVC release];
    [_textualIntervalsVC release];
    [_parentSplitVC release];
    [_selection release];
    [_segmentsVC release];
    [_intervalsPaneVC release];
    [super dealloc];
}


- (void)viewWillDisappear
{
    [self _stopObservingSelection];
}



- (IBAction)setSearchOptions:(id)sender
{
    
}


- (IBAction)setSearchCriteria:(id)sender
{
    
}

- (IBAction)toggleViewMode:(id)sender
{
    NSInteger seg = 0;
    if ([sender respondsToSelector:@selector(selectedSegment)]) {
        seg = [(NSSegmentedControl *)sender selectedSegment];
    }
    _showingSplits = (seg != 0);
    if (_showingSplits) {
        [self showIntervals];
    } else {
        [self showSegments];
    }
}

- (void)showSegments
{
    [self swapTo:_segmentsVC];
}

- (void)showIntervals
{
    if (_showSplitsGraphically) {
        _intervalsPaneVC = _graphicalIntervalsVC;
    } else {
        _intervalsPaneVC = _textualIntervalsVC;
    }
    [self swapTo:_intervalsPaneVC];
}


- (void)swapTo:(NSViewController *)target
{
    if (_current == target) {
        return;
    }

    if (_current != nil) {
        [[_current view] removeFromSuperview];
        [_current removeFromParentViewController];
    }

    _current = target;

    if (_current == nil) {
        return;
    }

    [self addChildViewController:_current];

    NSView *v = _current.view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentContainer addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:_contentContainer.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:_contentContainer.bottomAnchor]
    ]];
}


- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    [self injectDependencies];
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


- (void)_selectionDidChangeCompletely {
    // Called when Selection object swapped, or if you want a full refresh.
    // Pull whatever you need off _selection and redraw.
    Track *t = nil;
    @try {
        t = [_selection valueForKey:@"selectedTrack"];
    } @catch(...) {}
    [self _displaySelectedTrackSplits:t];
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



-(void) _displaySelectedTrackSplits:(Track*)trk
{
    if (trk) {
        [self _rebuildSplitTable];
        [_graphicalIntervalsVC.contentView setNeedsDisplay:YES];
    }
}

- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _segmentsVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _graphicalIntervalsVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
    
//    vc = _textualIntervalsVC;
//    if (vc != nil) {
//        @try { [vc setValue:_document forKey:@"document"]; }
//        @catch (__unused NSException *ex) {}
//        @try { [vc setValue:_selection forKey:@"selection"]; }
//        @catch (__unused NSException *ex) {}
//        if ([vc respondsToSelector:@selector(injectDependencies)]) {
//            [vc performSelector:@selector(injectDependencies)];
//        }
//    }

}



- (IBAction)toggleSplitMode:(id)sender
{
    if (_showingSplits) {
        _showSplitsGraphically = !_showSplitsGraphically;
        [self showIntervals];
    }
}



- (void)setSplitLength:(id)sender
{
    NSInteger tag = [(NSView*)sender tag];
    [Utils setIntDefault:(int)tag
                  forKey:RCBDefaultSplitIndex];
    [self _rebuildSplitTable];
    [self.graphicalIntervalsVC.contentView setNeedsDisplay:YES];
    ///[splitsTableView reloadData];
}


- (void)setSplitItem:(id)sender
{
    BOOL minDisabled = NO;
    BOOL maxDisabled = NO;
    BOOL deltaFromAvgDisabled = NO;
    NSInteger uiBaseTag = [(NSView*)sender tag];
    NSUInteger itemIndex = kSC_Invalid;
    NSInteger varTag = [Utils intFromDefaults:RCBDefaultSplitVariant];
    NSInteger uiCombinedTag = uiBaseTag + varTag;
    
    itemIndex = [self _itemTagToIndex:uiCombinedTag
                              variant:varTag
                          minDisabled:&minDisabled
                          maxDisabled:&maxDisabled
                 deltaFromAvgDisabled:&deltaFromAvgDisabled];
    
    if (itemIndex == NSNotFound) {
        [Utils setIntDefault:kVT_Average
                      forKey:RCBDefaultSplitVariant];
        _avgVariantButton.state = YES;
        // try again - all items should support "Average"
        varTag = kVT_Average;
        uiCombinedTag = uiBaseTag + varTag;
        itemIndex = [self _itemTagToIndex:uiCombinedTag
                                 variant:kVT_Average
                             minDisabled:&minDisabled
                             maxDisabled:&maxDisabled
                    deltaFromAvgDisabled:&deltaFromAvgDisabled];

    }
    if (itemIndex != NSNotFound) {
        [Utils setIntDefault:(int)itemIndex
                      forKey:RCBDefaultSplitGraphItem];
        [Utils setIntDefault:(int)varTag
                      forKey:RCBDefaultSplitVariant];
        
        [self.graphicalIntervalsVC.contentView setGraphItem:(int)itemIndex];
        self.minVariantButton.enabled = minDisabled;
        self.maxVariantButton.enabled = maxDisabled;
        self.deltaFromAvgVariantButton.enabled = deltaFromAvgDisabled;
        [self _rebuildSplitTable];
        [self.graphicalIntervalsVC.contentView setNeedsDisplay:YES];
    }
}


- (void)setSplitVariant:(id)sender
{
    int var = (int)[sender tag];
    [Utils setIntDefault:var
                  forKey:RCBDefaultSplitVariant];

    NSUInteger currentIndex = [Utils intFromDefaults:RCBDefaultSplitGraphItem];
    NSUInteger uiCombinedTag = [_splitItemIndexToTag tagForIndex:currentIndex];
    NSUInteger uiBaseTag = (uiCombinedTag/100) * 100;
    ///NSButton* itemButton = _findRadioInView(_intervalSettingsDialog.splitItemBox, uiBaseTag);
    NSUInteger newItemIndex = [_splitItemIndexToTag indexForTag:(uiBaseTag + var)];
    if (newItemIndex != NSNotFound) {
        NSLog(@"item index %d -> %d", (int)currentIndex, (int)newItemIndex);
        [Utils setIntDefault:(int)newItemIndex
                      forKey:RCBDefaultSplitGraphItem];
        [self _rebuildSplitTable];
        [self.graphicalIntervalsVC.contentView setGraphItem:(int)newItemIndex];
        [self.graphicalIntervalsVC.contentView setNeedsDisplay:YES];
    }
}


- (void)setSplitCustomLength:(id)sender
{
    [self _rebuildSplitTable];
}


- (void)_rebuildSplitTable
{
    [_splitArray removeAllObjects];
    
    Track* track = _selection.selectedTrack;
    
    if (track)
    {
        [track calculateTrackStats];
        float splitDist = [Utils currentSplitDistance];
        struct tStatData statData[kST_NumStats];
        float totalDistance = [track distance];
        int startIdx = 0;
        SplitTableItem* lastSplitItem = nil;
        NSTimeInterval startTime = 0.0;
        if (splitDist < 0.0)        // if dist < 0, then we use laps
        {
            NSArray* laps = [track laps];
            NSUInteger numLaps = [laps count];
            NSUInteger endIdx;
            for (int i=0; i<numLaps; i++)
            {
                Lap* lap = [laps objectAtIndex:i];
                if (i < (numLaps-1))
                    endIdx = [track lapStartingIndex:[laps objectAtIndex:i+1]] - 1;
                else
                    endIdx = [[track goodPoints] count] - 1;
                
                [track calculateStats:statData
                             startIdx:[track lapStartingIndex:lap]
                               endIdx:(int)endIdx];
                
                SplitTableItem* splitItem = [[[SplitTableItem alloc] initWithData:startTime
                                                                         distance:[lap distance]
                                                                        splitData:statData
                                                                     activityData:[track statsArray]
                                                                        prevSplit:lastSplitItem] autorelease];
                [_splitArray addObject:splitItem];    // array takes ownership
                lastSplitItem = splitItem;
                startTime += [track movingDurationOfLap:lap];
            }
        }
        else if ((splitDist > 0) && ([[track goodPoints] count] > 1))
        {
            float curDist = splitDist;
            while ((curDist-splitDist) < totalDistance)
            {
                int endIdx = [track findIndexOfFirstPointAtOrAfterDistanceUsingGoodPoints:curDist
                                                                                                   startAt:startIdx];
                if (endIdx == -1) endIdx = (int)[[track goodPoints] count] - 1;
                if (endIdx > startIdx)
                {
                    [track calculateStats:statData
                                 startIdx:startIdx
                                   endIdx:endIdx];
                    
                    SplitTableItem* splitItem = [[[SplitTableItem alloc] initWithData:startTime
                                                                             distance:curDist
                                                                            splitData:statData
                                                                         activityData:[track statsArray]
                                                                            prevSplit:lastSplitItem] autorelease];
                    [_splitArray addObject:splitItem];    // array takes ownership
                    lastSplitItem = splitItem;
                    startTime = [[[track goodPoints] objectAtIndex:endIdx] activeTimeDelta];
                }
                curDist += splitDist;
                startIdx = endIdx;
            }
        }
        [self.graphicalIntervalsVC.contentView setSplitArray:_splitArray
                                                 splitsTable:nil];   // fixme splitsTableView????
        ///[miniProfileView setSplitArray:_splitArray];
        ///[mapPathView setSplitArray:_splitArray];
    }
}


- (int)numberOfSplits
{
    return (int)[_splitArray count];
}



#pragma mark - interval settings


- (IBAction)showIntervalSettings:(id)sender {
    NSButton *button = (NSButton *)sender;
    
    // Toggle if already visible
    if (self.intervalSettingsPopover && [self.intervalSettingsPopover isShown]) {
        [self.intervalSettingsPopover performClose:sender];
        return;
    }
    
    NSPopover *p = [[NSPopover alloc] init];
    [p setBehavior:NSPopoverBehaviorTransient];   // ⬅️ closes on any outside click
    [p setAnimates:YES];
    [p setDelegate:self];
    
    self.intervalSettingsDialog =
        [[[IntervalSettingsDialogController alloc] initWithNibName:@"IntervalSettingsDialogController" bundle:nil] autorelease];
    [p setContentViewController:_intervalSettingsDialog];
    [_intervalSettingsDialog setAnalysisController:self];
    

    // Optional fixed size; omit if Auto Layout sizes it
    // [p setContentSize:NSMakeSize(360.0, 200.0)];

    self.intervalSettingsPopover = p;   // retain (MRC)
    [p release];

    // Anchor under the button with the arrow pointing to it
    [self.intervalSettingsPopover showRelativeToRect:[button bounds]
                                    ofView:button
                             preferredEdge:NSRectEdgeMaxY]; // below the button
    
    [self _setupPopup:_intervalSettingsDialog];
}


-(void)_setupPopup:(IntervalSettingsDialogController*)vc
{
    NSUInteger graphItem = [Utils intFromDefaults:RCBDefaultSplitGraphItem];
    NSUInteger variant = [Utils intFromDefaults:RCBDefaultSplitVariant];
    NSUInteger length = [Utils intFromDefaults:RCBDefaultSplitIndex];

    BOOL minEnabled =  [self _splitVariant:kVT_Minimum
                       enabledForGraphItem:graphItem];
    
    BOOL maxEnabled =  [self _splitVariant:kVT_Maximum
                       enabledForGraphItem:graphItem];
    
    BOOL deltaFromAvgEnabled =  [self _splitVariant:kVT_DeltaFromAverage
                                enabledForGraphItem:graphItem];
    
    vc.minVariantButton.enabled = minEnabled;
    vc.maxVariantButton.enabled = maxEnabled;
    vc.deltaFromAvgVariantButton.enabled = deltaFromAvgEnabled;

    if ((!minEnabled && (variant == kVT_Minimum)) ||
        (!maxEnabled && (variant == kVT_Maximum)) ||
        (!deltaFromAvgEnabled && (variant == kVT_DeltaFromAverage))) {
        variant = kVT_Average;
        vc.avgVariantButton.state = NSControlStateValueOn;
        [Utils setIntDefault:kVT_Average forKey:RCBDefaultSplitVariant];
   }
    
    NSUInteger uiCombinedTag = [_splitItemIndexToTag tagForIndex:graphItem];
    NSUInteger uiBaseTag = (uiCombinedTag/100) * 100;

    NSButton* itemButton = _findRadioInView(vc.splitItemBox, uiBaseTag);
    [itemButton setState:NSControlStateValueOn];

    NSButton* varButton = _findRadioInView(vc.splitItemVariantBox, variant);
    [varButton setState:NSControlStateValueOn];

    NSButton* lengthButton = _findRadioInView(vc.splitLengthBox, length);
    [lengthButton setState:NSControlStateValueOn];
}


-(NSUInteger)_itemTagToIndex:(NSUInteger)itemCombinedUITag
                     variant:(NSUInteger)varUITag
                 minDisabled:(BOOL*)minDisabled
                 maxDisabled:(BOOL*)maxDisabled
          deltaFromAvgDisabled:(BOOL*)deltaFromAvgDisabled
{
    NSUInteger answer = [_splitItemIndexToTag indexForTag:itemCombinedUITag];
    if (answer != NSNotFound) {
        NSUInteger uiBaseTag = (itemCombinedUITag/100) * 100;
        *minDisabled = [_splitItemIndexToTag indexForTag:uiBaseTag + kVT_Minimum] != NSNotFound;
        *maxDisabled = [_splitItemIndexToTag indexForTag:uiBaseTag + kVT_Maximum] != NSNotFound;
        *deltaFromAvgDisabled = [_splitItemIndexToTag indexForTag:uiBaseTag + kVT_DeltaFromAverage] != NSNotFound;
    }
    
    return answer;
}


-(BOOL) _splitVariant:(NSUInteger)var enabledForGraphItem:(NSUInteger)index
{
    BOOL answer = NO;
    BOOL minDisabled = NO;
    BOOL maxDisabled = NO;
    BOOL deltaFromAvgDisabled = NO;

    NSUInteger uiCombinedTag = [_splitItemIndexToTag tagForIndex:index];
    
    [self _itemTagToIndex:uiCombinedTag
                  variant:var
              minDisabled:&minDisabled
              maxDisabled:&maxDisabled
     deltaFromAvgDisabled:&deltaFromAvgDisabled];
    
    if (var == kVT_Minimum)
        answer = minDisabled;
    else if (var == kVT_Maximum)
        answer = maxDisabled;
    else if (var == kVT_DeltaFromAverage)
        answer = deltaFromAvgDisabled;

    return answer;
}


// Finds a radio button (NSButtonTypeRadio) with a given tag inside a container.
static NSButton * _findRadioInView(NSView *view, NSInteger tag)
{
    for (NSView *sub in [view subviews]) {
        if ([sub isKindOfClass:[NSButton class]]) {
            NSButton *btn = (NSButton *)sub;
            ///NSButtonType type = [[btn cell] buttonType];
            if (/* type == NSButtonTypeRadio && */ [btn tag] == tag) {
                return btn; // not retainedComparison
            }
        }
        NSButton *found = _findRadioInView(sub, tag);
        if (found) return found;
    }
    return nil;
}

// Convenience for NSBox
NSButton* _radioInBoxWithTag(NSBox *box, NSInteger tag)
{
    NSView *root = [box contentView] ?: (NSView *)box;
    return _findRadioInView(root, tag);
}

#pragma mark - NSPopoverDelegate

- (void)popoverDidClose:(NSNotification *)note {
    // Clean up so it can be re-created next time
    self.intervalSettingsPopover = nil;
    self.intervalSettingsDialog = nil;
}

@end
