//
//  NSDocumentController+AscentForceSubclass.m
//  Ascent
//
//  Created by Rob Boyer on 9/4/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "AscentDocumentController.h"   // your subclass

static NSDocumentController *_ASCForcedSharedDC = nil;

@implementation NSDocumentController (AscentForceSubclass)

// Our replacement for +sharedDocumentController
+ (NSDocumentController *)asc_sharedDocumentController
{
    @synchronized(self) {
        if (!_ASCForcedSharedDC) {
            _ASCForcedSharedDC = (NSDocumentController *)[[AscentDocumentController alloc] init];
#ifdef DEBUG
            NSLog(@"[Ascent] Forced shared document controller = %@",
                  NSStringFromClass([_ASCForcedSharedDC class]));
#endif
        }
        return _ASCForcedSharedDC;
    }
}

// Swizzle at load time (runs before main/NSApplicationMain)
+ (void)load
{
    // Ensure the subclass object file is pulled in (prevents dead-stripping)
    [AscentDocumentController class];

    Class meta = object_getClass((id)self); // meta-class for class methods
    Method orig = class_getClassMethod(meta, @selector(sharedDocumentController));
    Method repl = class_getClassMethod(meta, @selector(asc_sharedDocumentController));
    if (orig && repl) {
        method_exchangeImplementations(orig, repl);
#ifdef DEBUG
        NSLog(@"[Ascent] Swizzled +[NSDocumentController sharedDocumentController]");
#endif
    }
}

// Extra belt-and-suspenders: run pre-main to guarantee the file is linked and +load fires.
__attribute__((constructor))
static void ASCForceDCConstructor(void) {
    // Touch the class so the object file is definitely loaded even in Release.
    [AscentDocumentController class];
}

@end
