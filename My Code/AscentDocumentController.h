//
//  AscentDocumentController.h
//  Ascent
//
//  Created by Rob Boyer on 9/4/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AscentDocumentController : NSDocumentController


- (void)drainDeferredOpensWithCompletion:(void (^)(void))completion;

@end
