//
//  ProgressBarHelper.m
//  Ascent
//
//  Created by Rob Boyer on 9/28/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ProgressBarController.h"
#import "ProgressBarHelper.h"

@interface ProgressBarHelper ()
{
    NSWindow* _window;
}
@end

@implementation ProgressBarHelper

+ (instancetype) ProgressHelper {
    static ProgressBarHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}


-(void) startProgressIndicator:(NSWindow*)window title:(NSString*)text
{
    NSRect fr = [[NSScreen mainScreen] frame];
    _window = window;
    if (_window)
    {
        fr = [_window frame];
    }
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    NSRect pbfr = [[[pb controller] window] frame];    // must call window method for NIB to load, needs to be done before 'begin' is called
    NSPoint origin;
    origin.x = fr.origin.x + fr.size.width/2.0 - pbfr.size.width/2.0;
    origin.y = fr.origin.y + fr.size.height/2.0 - pbfr.size.height/2.0;
    [[[pb controller] window] setFrameOrigin:origin];
    [[pb controller] showWindow:self];
    [[pb controller] begin:@""
                 divisions:0];
    [[pb controller] updateMessage:text];
}


- (void) updateProgressIndicator:(NSString*)msg
{
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    [[pb controller] updateMessage:msg];
}


- (void) endProgressIndicator
{
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    [[pb controller] end];
    [[[pb controller] window] orderOut:nil];
}


- (void) beginWithTitle:(NSString*)title divisions:(int)divs
{
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    [[pb controller] begin:title
                 divisions:divs];
}


- (void) beginWithTitle:(NSString*)title divisions:(int)divs centerOverWindow:(NSWindow*)w;
{
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    NSWindow *pbWin  = pb.controller.window; // loads nib
    if (w) {
            NSRect fr = w.frame, pfr = pbWin.frame;
            NSPoint origin = NSMakePoint(NSMidX(fr) - pfr.size.width/2.0,
                                     NSMidY(fr) - pfr.size.height/2.0);
            [pbWin setFrameOrigin:origin];
    }
    pbWin.collectionBehavior |= (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                 NSWindowCollectionBehaviorFullScreenAuxiliary);
    pbWin.level = NSStatusWindowLevel;
    [[pb controller] begin:title
                 divisions:divs];
    [pb.controller showWindow:self];
    [pbWin orderFrontRegardless];
    [pbWin displayIfNeeded];
}


- (void) incrementDiv
{
    SharedProgressBar* pb = [SharedProgressBar sharedInstance];
    [[pb controller] incrementDiv];
}

@end
