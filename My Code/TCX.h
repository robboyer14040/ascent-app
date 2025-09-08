//
//  TCX.h
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class Lap;
@class TrackPoint;

@interface TCX : NSObject <NSXMLParserDelegate>

// Designated initializers
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithFileURL:(NSURL *)url;

// Import / Export
- (BOOL)import:(NSMutableArray *)trackArray laps:(NSMutableArray *)lapArray;
- (BOOL)export:(NSArray *)trackArray;

// Optional override of activity string (e.g., @"Running", @"Biking", etc.)
- (void)setCurrentActivity:(NSString *)activity;

@end
