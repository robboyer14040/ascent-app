//
//  SplashPanelView.h
//  Ascent
//
//  Created by Rob Boyer on 1/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SplashPanelView : NSView 
{
   NSImage* backgroundImage;
   NSMutableString*   userName;
   NSMutableString*   regCode;
   NSMutableString*   email;
   NSString*   progressText;
}

- (void) updateProgress:(NSString*)msg;

@end
