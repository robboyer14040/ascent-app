//
//  MainWindowController.m
//  Ascent  (NON-ARC)
//

#import "MainWindowController.h"
#import "RootSplitController.h"
#import "Selection.h"


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
    NSLog(@"MainWindowController windowDidLoad %@", self);
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

@end
