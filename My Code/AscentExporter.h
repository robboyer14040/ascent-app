//
//  ActivityExporter.h
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseDefs.h"

@class DocumentMetaData;
@class DatabaseManager;
@class ActivityStore;
@class TrackPointStore;
@class IdentifierStore;


@interface AscentExporter : NSObject

- (instancetype)initWithURL:(NSURL *)dbURL;

- (NSURL *)exportDocumentToTemporaryURLWithProgress:(ASProgress)progress
                                           metaData:(DocumentMetaData*)docMeta
                                              error:(NSError **)outError;

- (BOOL)performIncrementalExportWithMetaData:(DocumentMetaData *)docMeta
                            databaseManager:(DatabaseManager *)dbm
                              activityStore:(ActivityStore *)actStore
                           trackPointStore:(TrackPointStore *)tpStore
                          identifierStore:(IdentifierStore *)identStore
                                       error:(NSError **)outError;


@end
