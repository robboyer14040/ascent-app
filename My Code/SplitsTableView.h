//
//  SplitsTableView.h
//  Ascent
//
//  Created by Rob Boyer on 9/22/07.
//  Copyright 2007 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ColumnHelper;

@interface SplitsTableView : NSTableView 
{
	ColumnHelper*	columnHelper;
}

- (id) init;
-(void) buildSplitGraphItemPopup:(NSPopUpButton*)p isPullDown:(BOOL)ipd;
-(void)prepareToDie;


@end
