//
//  TrackCalendarController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//

#import "TrackCalendarController.h"

@implementation TrackCalendarController
@synthesize document=_document, selection=_selection;

- (void)dealloc {
    [_selection release];
    [super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // set up calendar UI, data sources, etc.
}

- (void)injectDependencies {
    // use _document / _selection as needed
}

@end
