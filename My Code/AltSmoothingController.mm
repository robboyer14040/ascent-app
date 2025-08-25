//
//  AltSmoothingController.mm
//  Ascent
//
//  Created by Rob Boyer on 3/18/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AltSmoothingController.h"


@implementation AltSmoothingController

- (id) initWithFactor:(float)fact
{
	self = [super init];
	factor = fact;
	self = [super initWithWindowNibName:@"AltSmoothingFactor"];
	isValid = YES;
	return self;
}

- (id) init
{
	return [self initWithFactor:0];
}

-(void) awakeFromNib
{
	[factorTextField setFloatValue:factor];
	[factorSlider setFloatValue:factor];
}


- (void) dealloc
{
}


-(float) factor
{
	return factor;
}


- (IBAction) setFactor:(id)sender
{
	factor = [sender intValue];
	[factorTextField setFloatValue:factor];
	[factorSlider setFloatValue:factor];
}


- (IBAction) dismissPanel:(id)sender
{
	[NSApp stopModalWithCode:isValid ? 0: -1];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp stopModalWithCode:-1];
}


-(IBAction) done:(id)sender
{
	isValid = YES;
	[self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
	isValid = NO;
	[self dismissPanel:sender];
}

@end
