//
//  SplitsGraphView.h
//  Ascent
//
//  Created by Robert Boyer on 9/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SplitsTableView;

@interface SplitsGraphView : NSView
@property(nonatomic, retain) NSArray    *splitArray;
@property(nonatomic, assign) int        graphItem;
@end
