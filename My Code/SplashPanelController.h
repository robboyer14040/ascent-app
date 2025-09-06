// SplashPanelController.h  (MRC / non-ARC)

#import <Cocoa/Cocoa.h>

@interface SplashPanelController : NSWindowController <NSWindowDelegate>

// Singleton
+ (SplashPanelController *)sharedInstance;

#pragma mark - Public API (match existing interface)
// Show the panel (centered on main screen) and be visible now.
- (void)showPanel;
// Hide the panel immediately.
- (void)hidePanel;
// Update the message at the bottom of the splash.
- (void)updateMessage:(NSString *)msg;
// Update the mini progress bar within the splash pane
- (void)updateProgress:(int)current total:(int)total;
// Control whether the user can dismiss the splash by closing or clicking.
- (void)canDismiss:(BOOL)yessno;
// Fade the splash out and hide it when finished.
- (void)startFade:(id)dummy;
// Convenience: show centered on main screen, default level.
- (void)showPanelCenteredOnMainScreen;
// Same, but pick a higher level when `high` is YES.
- (void)showPanelCenteredOnMainScreenWithHighLevel:(BOOL)high;

#pragma mark - IBOutlets from SplashPanel.xib
@property(assign) IBOutlet NSImageView  *imageView;     // filled by nib
@property(assign) IBOutlet NSTextField  *messageField;  // filled by nib
@property(assign) IBOutlet NSView       *miniProgress;  // filled by nib

@end
