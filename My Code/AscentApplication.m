// AscentApplication.m
#import "AscentApplication.h"
#import "SplashPanelController.h"
#import "AscentDocumentController.h"

@implementation AscentApplication

- (id)init
{
    self = [super init];
    return self;
}

- (void)finishLaunching
{
    // 1) Ensure the subclass is loaded & becomes the shared instance
    [AscentDocumentController class];                 // force class to load/link
    id dc = [NSDocumentController sharedDocumentController];
    NSLog(@"Shared DC class (pre): %@", NSStringFromClass([dc class])); // should log AscentDocumentController

    // 2) Put the splash up *before* AppKit processes open AppleEvents
    ///[[SplashPanelController sharedInstance] showPanelCenteredOnMainScreenWithHighLevel:YES];
    ///[[SplashPanelController sharedInstance].window displayIfNeeded];
    ///CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);

    // 3) Now hand over to AppKit (it will deliver kAEOpenDocuments, etc.)
    [super finishLaunching];
}

@end
