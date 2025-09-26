//
//  RightSplitController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//
#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument, Selection;
@class MapController, ProfileController, InfoPaneController;

@interface RightSplitController : NSSplitViewController
{
@private
    TrackBrowserDocument *_document;  // assign
    Selection *_selection;            // retained
    MapController *_mapController;
    ProfileController *_profileController;
    InfoPaneController *_infoPaneController;
}

/// Dependencies
@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;

/// Children (stacked top→bottom: Map, Profile, Info)
@property(nonatomic, retain) MapController      *mapController;
@property(nonatomic, retain) ProfileController  *profileController;
@property(nonatomic, retain) InfoPaneController *infoPaneController;

/// Push current dependencies into the subtree (idempotent/safe)
- (void)injectDependencies;

@end
