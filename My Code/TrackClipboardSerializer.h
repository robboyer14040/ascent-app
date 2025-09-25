//
//  TrackClipboardSerializer.h
//  Ascent
//
//  Created by Rob Boyer on 9/24/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#ifndef TrackClipboardSerializer_h
#define TrackClipboardSerializer_h

#import <Foundation/Foundation.h>

@class Track;

NS_ASSUME_NONNULL_BEGIN

@interface TrackClipboardSerializer : NSObject

/// Serialize an array of Track* (including points/laps/markers/attributes/localMediaItems) to a JSON string.
/// Returns nil and sets *error on failure.
+ (NSString *)serializeTracksToJSONString:(NSArray /* of Track* */ *)tracks
                                    error:(NSError * __autoreleasing *)error;

/// Parse a JSON string created by the serializer and return autoreleased Track* objects.
/// Returns nil and sets *error on failure.
+ (NSArray /* of Track* */ *)deserializeTracksFromJSONString:(NSString *)json
                                                       error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END

#endif /* TrackClipboardSerializer_h */
