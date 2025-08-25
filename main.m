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

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        appDelegate = [[AppController alloc] init];   // retained (MRR-safe)
        [NSApp setDelegate:appDelegate];
        return NSApplicationMain(argc, argv);
    }
}
