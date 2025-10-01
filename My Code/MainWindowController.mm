//
//  MainWindowController.m
//  Ascent  (NON-ARC)
//

#import "MainWindowController.h"
#import "RootSplitController.h"
#import "LeftSplitController.h"
#import "Selection.h"
#import "TrackBrowserDocument.h"
#import "DMWindowController.h"
#import "Utils.h"


NSString* OpenMapDetailNotification         = @"OpenMapDetail";
NSString* OpenActivityDetailNotification    = @"OpenActivityDetail";
NSString* TrackArrayChangedNotification     = @"TrackArrayChanged";
NSString* TrackSelectionDoubleClicked       = @"SelectionDoubleClicked";
NSString* TrackFieldsChanged                = @"TrackFieldsChanged";

@interface MainWindowController ()
{
}
@property(nonatomic, retain) DMWindowController* detailedMapWC;
@end


@implementation MainWindowController

@dynamic document; // implemented by NSWindowController
@synthesize selection = _selection;
@synthesize reservedTopArea = _reservedTopArea;
@synthesize contentContainer = _contentContainer;

- (void)dealloc
{
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
    
    _selection = [[Selection alloc] init];
    _root.selection = _selection;

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
    if (selection == _selection) return;
    [_selection release];
    _selection = [selection retain];

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

@end
