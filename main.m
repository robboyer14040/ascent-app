//
//  main.m
//  Ascent
//
//  Created by Rob Boyer on 1/27/13.
//  Copyright (c) 2013 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppController.h"

static id appDelegate; // retain for MRR; ARC will hold it strongly too

#import "AscentApplication.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // This guarantees NSApp is an AscentApplication instance.
        [AscentApplication sharedApplication];
        return NSApplicationMain(argc, argv);
    }
}
