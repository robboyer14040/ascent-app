//
//  ProfileController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;
@class MiniProfileView;

@interface ProfileController : NSViewController
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;
@property(nonatomic, assign) IBOutlet MiniProfileView *profileView;

- (void)injectDependencies;
@end
