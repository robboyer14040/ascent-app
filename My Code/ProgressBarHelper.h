//
//  ProgressBarHelper.h
//  Ascent
//
//  Created by Rob Boyer on 9/28/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
#import <Cocoa/Cocoa.h>


@interface ProgressBarHelper : NSObject
{
}
+ (instancetype)ProgressHelper;
- (void) startProgressIndicator:(NSWindow*)window title:(NSString*)text;
- (void) updateProgressIndicator:(NSString*)msg;
- (void) endProgressIndicator;
- (void) beginWithTitle:(NSString*)title divisions:(int)divs;
- (void) beginWithTitle:(NSString*)title divisions:(int)divs centerOverWindow:(NSWindow*)w;
- (void) incrementDiv;

@end
