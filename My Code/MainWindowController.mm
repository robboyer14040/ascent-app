//
//  MainWindowController.m
//  Ascent  (NON-ARC)
//

#import "MainWindowController.h"
#import "RootSplitController.h"

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

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Optional: configure the visual effect header
    if (self.reservedTopArea) {
        self.reservedTopArea.material = NSVisualEffectMaterialHeaderView;
        self.reservedTopArea.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        self.reservedTopArea.state = NSVisualEffectStateFollowsWindowActiveState;
    }

    NSView *container = _contentContainer ?: self.window.contentView;
    NSAssert(container != nil, @"MainWindowController: content container is nil.");

    // Create and retain the root split controller (code-only)
    _root = [[RootSplitController alloc] init];

    // Push current deps before embedding
    _root.document  = (TrackBrowserDocument *)self.document;
    _root.selection = _selection;
    if ([_root respondsToSelector:@selector(injectDependencies)]) {
        [_root injectDependencies];
    }

    // Embed RootSplitController.view
    NSView *childView = _root.view;
    childView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:childView];
    [NSLayoutConstraint activateConstraints:@[
        [childView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [childView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [childView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [childView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
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
