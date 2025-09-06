//  ProgressBarController.mm
//  Ascent
//
//  Created by Rob Boyer on 8/5/07.
//  Updated 2025 — white label, blue bar tint (best-effort, SDK-safe)

#import "ProgressBarController.h"
#import <AppKit/AppKit.h>


@interface ProgressBarController ()
- (void)_centerOnBestScreen;
@end;


@implementation ProgressBarController

- (id)initUsingNib
{
    self = [super initWithWindowNibName:@"ProgressBar"];
    numDivisions  = 0;
    curDiv        = 0;
    cancelSelector = NULL;
    cancelObject   = nil;
    [cancelButton setHidden:YES]; // safe if nil before nib load
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

#pragma mark - Helpers

// Try to tint the progress bar blue across OS versions without compile-time deps.
- (void)_tintProgressBlueIfPossible
{
    if (!progressInd) return;

    // 1) Newer AppKit: many controls support -setContentTintColor:
    SEL tintSel = NSSelectorFromString(@"setContentTintColor:");
    if ([progressInd respondsToSelector:tintSel]) {
        NSColor *blue = nil;
        if ([NSColor respondsToSelector:@selector(systemBlueColor)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            blue = [NSColor performSelector:@selector(systemBlueColor)];
#pragma clang diagnostic pop
        }
        if (!blue) blue = [NSColor blueColor];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [progressInd performSelector:tintSel withObject:blue];
#pragma clang diagnostic pop
        return;
    }

    // 2) Older AppKit: fallback to (deprecated) control tint, but call it dynamically.
    SEL oldTintSel = NSSelectorFromString(@"setControlTint:");
    if ([progressInd respondsToSelector:oldTintSel]) {
        NSMethodSignature *sig = [progressInd methodSignatureForSelector:oldTintSel];
        if (sig) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:oldTintSel];
            [inv setTarget:progressInd];

            NSControlTint tint = NSBlueControlTint; // available on old SDKs
            [inv setArgument:&tint atIndex:2];      // first obj-c arg is index 2
            [inv invoke];
        }
    }
}

#pragma mark - NIB life cycle

- (void)awakeFromNib
{
    // White label over transparent background so it shows on top of the bar.
    if (textMessageField) {
        [textMessageField setBordered:NO];
        [textMessageField setBezeled:NO];
        [textMessageField setDrawsBackground:NO];              // fully transparent
        [textMessageField setTextColor:[NSColor whiteColor]];  // white text
        [textMessageField setLineBreakMode:NSLineBreakByTruncatingTail];
        [textMessageField setUsesSingleLineMode:YES];
        [textMessageField setStringValue:@""];                  // clear at start
    }

    // Ensure the indicator behaves as a horizontal bar (style comes from the XIB).
    if (progressInd) {
        [progressInd setIndeterminate:YES];        // XIB may override later in -begin:
        [progressInd setBezeled:NO];
        [self _tintProgressBlueIfPossible];        // best-effort blue
    }
}

#pragma mark - API

- (void)begin:(NSString*)title divisions:(int)divs
{
    [cancelButton setHidden:YES];
    curDiv       = 0;
    numDivisions = divs;

    if (divs > 0) {
        [progressInd setIndeterminate:NO];
        [progressInd setUsesThreadedAnimation:NO];
        [progressInd setMinValue:0.0];
        [progressInd setMaxValue:(double)numDivisions];
        [progressInd setDoubleValue:0.0];
    } else {
        [progressInd setIndeterminate:YES];
        [progressInd setUsesThreadedAnimation:YES];
        [progressInd startAnimation:self];
    }

    [self _centerOnBestScreen];
    [[self window] display];
    [self updateMessage:title];
}

- (void)end
{
    [progressInd stopAnimation:self];
}

- (void)updateMessage:(NSString*)msg
{
    [textMessageField setStringValue:(msg ?: @"")];
    [textMessageField displayIfNeeded];
}

- (void)incrementDiv
{
    ++curDiv;
    [progressInd incrementBy:1.0];
    [progressInd displayIfNeeded];
}

- (void)setDivs:(int)divs
{
    curDiv = divs;
    [progressInd setDoubleValue:(double)curDiv];
    [progressInd displayIfNeeded];
}

- (int)currentDivs
{
    return curDiv;
}

- (int)totalDivs
{
    return numDivisions;
}

- (void)setCancelSelector:(SEL)cs forObject:(id)obj
{
    cancelSelector = cs;
    cancelObject   = obj;
    [cancelButton setHidden:NO];
}

- (IBAction)cancel:(id)sender
{
    (void)sender;
    if ((cancelSelector != NULL) && cancelObject) {
        [cancelObject performSelector:cancelSelector];
    }
}

- (void)_centerOnBestScreen
{
    NSWindow *w = [self window]; // ensure nib loads
    NSScreen *screen = (NSApp.keyWindow ?: NSApp.mainWindow).screen;
    if (!screen) screen = [NSScreen mainScreen];
    if (!screen && NSScreen.screens.count > 0) screen = NSScreen.screens.firstObject;

    if (!screen) { [w center]; return; } // ultra fallback

    NSRect vis = screen.visibleFrame;
    NSRect fr  = w.frame;
    fr.origin.x = NSMidX(vis) - fr.size.width  * 0.5;
    fr.origin.y = NSMidY(vis) - fr.size.height * 0.5;
    [w setFrame:fr display:NO];
}

@end


//------------------------------------------------------------------------------------------------

@implementation SharedProgressBar

static ProgressBarController *pbController;

+ (void)initialize
{
    pbController = [[ProgressBarController alloc] initUsingNib];
}

- (ProgressBarController *)controller
{
    return pbController;
}

@end
