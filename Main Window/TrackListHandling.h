//
//  TrackListHandling.h
//  Ascent
//
//  Created by Rob Boyer on 9/28/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "Track.h"

@protocol TrackListHandling <NSObject>
@required
- (NSMutableArray*) prepareArrayOfSelectedTracks;
- (void) selectLastImportedTrack:(Track *)lastImportedTrack;
- (void) updateAfterImport;
- (NSString*) buildSummaryTextOutput:(char)sep;
- (void) processCut:(id)sender;
- (void) processCopy:(id)sender;
- (void) processPaste:(id)sender;
- (void) processDelete:(id)sender;

@optional
@end
