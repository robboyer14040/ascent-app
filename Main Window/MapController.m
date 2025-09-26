//
//  MapController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

// MapController.m  (NON-ARC)
#import "MapController.h"

@implementation MapController
@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Set up map layers, renderer hooks, etc.
}

- (void)injectDependencies {
    // Use _document / _selection as needed.
}

@end
