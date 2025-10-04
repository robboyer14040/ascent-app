//
//  OutlineSettingsDialogController.h
//  Ascent
//
//  Created by Rob Boyer on 10/3/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackPaneController;

NS_ASSUME_NONNULL_BEGIN

@interface OutlineSettingsDialogController : NSViewController

@property(nonatomic, assign) IBOutlet NSBox      *outlineStyleBox;

@property(nonatomic, retain) TrackPaneController     *trackPaneController;


- (IBAction)setOutlineStyle:(id)sender;


@end

NS_ASSUME_NONNULL_END
