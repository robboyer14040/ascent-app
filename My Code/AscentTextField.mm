//
//  AscentTextField.mm
//  Ascent
//
//  Created by Robert Boyer on 4/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AscentTextField.h"


@implementation AscentTextField

-(void)setEnabled:(BOOL)flag
{
	[super setEnabled:flag];
	
	if (flag == NO) {
		[self setTextColor:[NSColor disabledControlTextColor]];
	} else {
		[self setTextColor:[NSColor controlTextColor]];
	}    
}
@end
