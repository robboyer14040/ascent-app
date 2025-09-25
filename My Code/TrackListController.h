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


@interface TrackListController : NSViewController
<NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSPasteboardItemDataProvider>
{
    NSIndexSet *_dragRows;
    BOOL        reverseSort;
}

@property(nonatomic, assign) IBOutlet ActivityOutlineView *outlineView;   // ActivityOutlineView
@property(nonatomic, assign) TrackBrowserDocument         *document;  // set by WindowController
@property(nonatomic, retain) NSArray                      *tracks;    // your current list
@property(nonatomic, retain) NSArray                      *topSortedKeys;

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
