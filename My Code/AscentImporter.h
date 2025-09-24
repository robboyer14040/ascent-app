//
//  AscentImporter.h
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseDefs.h"

@class TrackBrowserData;

// ASProgress is assumed to be typedef'ed elsewhere, same as your existing code.

@interface AscentImporter : NSObject

// Loads a database at `url` (read-only) and populates `docMeta`.
// Returns YES on success. Progress (0..totalTracks-1, totalTracks) is forwarded.
- (BOOL)loadDatabaseFile:(NSURL *)url
            documentMeta:(TrackBrowserData *)docMeta
                progress:(ASProgress)prog;

@end
