#import "CustomSplitDistanceController.h"
#import "Utils.h"


@implementation CustomSplitDistanceController


-(void) awakeFromNib
{
}


- (void) dealloc
{

}



-(float) customDistance
{
	return customDistance;
}


- (void) setCustomDistance:(float)cd
{
	customDistance = cd;
	[distanceField setFloatValue:cd];
	if ([Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey])
	{
		[unitsField setStringValue:@"mi"];
	}
	else
	{
		[unitsField setStringValue:@"km"];
	}
}


- (IBAction) dismissPanel:(id)sender
{
	[[self window] makeFirstResponder:nil];
	[NSApp stopModalWithCode:isValid ? 0: -1];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[[self window] makeFirstResponder:nil];
	[NSApp stopModalWithCode:-1];
}


-(IBAction) done:(id)sender
{
	[[self window] makeFirstResponder:nil];
	isValid = YES;
	[self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
	[[self window] makeFirstResponder:nil];
	isValid = NO;
	[self dismissPanel:sender];
}


- (IBAction)setDistance:(id)sender
{
	customDistance = [sender floatValue];
	[self done:sender];
}



@end
