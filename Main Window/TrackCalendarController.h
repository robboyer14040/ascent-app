//
//  TrackCalendarController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TrackBrowserDocument, Selection;

@interface TrackCalendarController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document; // assign on purpose (document owns controller)
@property(nonatomic, retain) Selection *selection;
- (void)injectDependencies; // optional hook
@end
