//
//  ResourceLocationBridge.m
//  OmniFoundation
//
//  Created by Rob Boyer on 8/13/25.
//

#import "ResourceLocationBridge.h"
#import <OmniBase/OBUtilities.h>

os_log_t OFCreateLog(const char *subsystem, const char *category) {
    return OBLogCreate(subsystem, category);  // The macro call — still legal in Obj-C
}
