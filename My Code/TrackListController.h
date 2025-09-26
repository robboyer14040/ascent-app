//
//  TrackListController.h
//  Ascent
//
//  Created by Rob Boyer on 9/24/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Track;
@class Lap;
@class ActivityOutlineView;
@class Selection;

@interface TrackListController : NSViewController
<NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSPasteboardItemDataProvider>
{
    NSIndexSet *_dragRows;
    BOOL        reverseSort;
@private
    TrackBrowserDocument *_document;   // assign semantics
    Selection *_selection;             // retained
}

/// IB outlets
@property(nonatomic, assign) IBOutlet ActivityOutlineView *outlineView;
@property(nonatomic, assign) IBOutlet NSScrollView  *outlineScrollView; // optional, but handy


@property(nonatomic, assign) TrackBrowserDocument *document;
@property(nonatomic, retain) Selection *selection;
@property(nonatomic, retain) NSArray                      *tracks;    // your current list
@property(nonatomic, retain) NSArray                      *topSortedKeys;

- (void)injectDependencies;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;
- (void)expandFirstItem;
- (void)expandLastItem;
- (NSMutableArray*) prepareArrayOfSelectedTracks;
- (NSMutableArray*) prepareArrayOfSelectedBrowserItemsWithTracks;
- (void)buildBrowser:(BOOL)expandLastItem;
- (NSString*)searchCriteria;
- (int)searchOptions;
- (void)resetSelectedTrack:(Track*)trk lap:(Lap*)lap;
- (void)selectBrowserRowsForTracks:(NSArray*)trks;
- (void) storeExpandedState;
- (void) restoreExpandedState;
- (void)rebuildBrowserAndRestoreState:(Track*)track selectLap:(Lap*)lap;

@end
