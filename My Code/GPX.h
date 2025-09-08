//
//  GPX.h
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface GPX : NSObject <NSXMLParserDelegate>

// Designated initializer
- (instancetype)initGPXWithFileURL:(NSURL *)url windowController:(NSWindowController *)wc;

// Import / Export
- (BOOL)import:(NSMutableArray *)trackArray laps:(NSMutableArray *)lapArray;
- (BOOL)exportTrack:(Track *)track;

@end
