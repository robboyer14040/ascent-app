//
//  ProfileController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "ProfileController.h"

@implementation ProfileController
@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Wire up plot view, axes, data sources here.
}

- (void)injectDependencies {
    // Pull data from _document / _selection and refresh plot if view is loaded.
}

@end
