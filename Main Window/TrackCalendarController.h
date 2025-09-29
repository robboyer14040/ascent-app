//
//  TrackCalendarController.h
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TrackListHandling.h"

@class TrackBrowserDocument, Selection;

@interface TrackCalendarController : NSViewController<TrackListHandling>
@property(nonatomic, assign) TrackBrowserDocument *document; // assign on purpose (document owns controller)
@property(nonatomic, retain) Selection *selection;
- (void)injectDependencies; // optional hook
- (NSMutableArray*) prepareArrayOfSelectedTracks;
- (void) selectLastImportedTrack:(Track *)lastImportedTrack;
- (void) updateAfterImport;
- (NSString*) buildSummaryTextOutput:(char)sep;
- (void) processCut:(id)sender;
- (void) processCopy:(id)sender;
- (void) processPaste:(id)sender;
- (void) processDelete:(id)sender;
@end
