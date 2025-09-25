#import "MainWindowController.h"
#import "TrackBrowserDocument.h"
#import "Selection.h"
#import "RootSplitController.h"

@implementation MainWindowController

@synthesize rootSplitController = _rootSplitController;
@synthesize selection = _selection;

- (void)dealloc
{
    [_selection release];
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    if (self.rootSplitController != nil) {
        [[self window] setContentViewController:self.rootSplitController];
    }

    // 2) Create & inject Selection / document as usual
    Selection *sel = [[Selection alloc] init];
    self.selection = sel;
    [sel release];

    RootSplitController *root = (RootSplitController *)self.rootSplitController;
    [root setDocument:(TrackBrowserDocument *)[self document]];
    [root setSelection:self.selection];
    if ([root respondsToSelector:@selector(injectDependencies)]) {
        [root injectDependencies];
    }
}


@end

