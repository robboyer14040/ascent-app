//
//  ResourceLocationBridge.h
//  OmniFoundation
//
//  Created by Rob Boyer on 8/13/25.
//

#ifndef ResourceLocationBridge_h
#define ResourceLocationBridge_h

#import <Foundation/Foundation.h>  // ✅ This must be first
#import <os/log.h>   // <-- add this so os_log_t is known

NS_ASSUME_NONNULL_BEGIN

// Declare a real function that Swift can call
FOUNDATION_EXPORT os_log_t OFCreateLog(const char *subsystem, const char *category);

NS_ASSUME_NONNULL_END

#endif /* ResourceLocationBridge_h */
