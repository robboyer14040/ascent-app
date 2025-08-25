//
//  GetPasswordController.mm
//  Ascent
//
//  Created by Rob Boyer on 3/1/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GetPasswordController.h"


@implementation GetPasswordController

-(id) initWithUser:(NSString*)nm email:(NSString*)em 
{
	self = [super initWithWindowNibName:@"GetPassword"];
	isValid = NO;
	return self;
}

-(void) awakeFromNib
{
}

-(NSString*) pw
{
	return [pwField stringValue];
}

- (IBAction) dismissPanel:(id)sender
{
	[[self window] makeFirstResponder:nil];
	[NSApp stopModalWithCode:isValid ? 0: -1];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
 	[NSApp stopModalWithCode:-1];
}


-(IBAction) ok:(id)sender
{
    [[self window] makeFirstResponder:nil];
	isValid = YES;
	[self dismissPanel:sender];
}

-(IBAction) setPw:(NSString*)pw
{
	printf("setPW...\n");
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	printf("did end editing...\n");
	[okButton setKeyEquivalent:@"\r"];
}
	 
- (BOOL)controlTextShouldBeginEditing:(NSText *)textObject
{
	printf("should begin editing...\n");
	return YES;
}

- (BOOL)controlTextShouldEndEditing:(NSText *)textObject
{
	printf("should end editing...\n");
	return YES;
}

	 
@end
