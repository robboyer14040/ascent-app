//
//  SplitActivityController.mm
//  Ascent
//
//  Created by Robert Boyer on 4/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//



#import "SplitActivityController.h"
#import "Utils.h"

NSString* RCBDefaultSplitMethod = @"DefaultSplitMethod";

@interface SplitActivityController (Private)
-(void)update;
@end


@implementation SplitActivityController

- (id) initWithInterval:(NSTimeInterval)fact
{
	self = [super initWithWindowNibName:@"SplitActivity"];
	timeInterval = fact;
	if (self) 
	{
		splitMethod = [Utils intFromDefaults:RCBDefaultSplitMethod];
		isValid = YES;
		[self update];
	}
	return self;
}


- (id) init
{
	return [self initWithInterval:0];
}


-(void)updateAutoSplit
{
	BOOL autoSplitting = (splitMethod == kSplitUsingTimeInterval);
	[intervalSlider setHidden:!autoSplitting];
	[intervalTextField setHidden:!autoSplitting];
	[sliderLabel setHidden:!autoSplitting];
	[elapsedTimeHelpLabel setHidden:autoSplitting];
}


-(void) updateTimeInterval
{
	NSString* s;
	int itv = (int) timeInterval;
	if (itv < 60)
	{
		const char* ms = itv <= 1 ? "" : "s";
		s = [NSString stringWithFormat:@"%d minute%s", itv, ms];
	}
	else 
	{
		const char* hs = itv >= 120 ? "s" : "";
		s = [NSString stringWithFormat:@"%d hour%s, %d minutes", itv/60, hs, itv % 60];
	}
	[intervalTextField setStringValue:s];
}


-(void) update
{
	if (!IS_BETWEEN(0, splitMethod, kNumSplitMethods-1)) splitMethod = kSplitUsingTimeInterval;
	[splitMethodPopup selectItemAtIndex:splitMethod];
	[intervalSlider setFloatValue:timeInterval];
	[self updateTimeInterval];
	[self updateAutoSplit];
}


-(void) awakeFromNib
{
	splitMethod = [Utils intFromDefaults:RCBDefaultSplitMethod];
	[self update];
}


- (void) dealloc
{
}


-(NSTimeInterval) timeInterval
{
	return timeInterval;
}


- (IBAction) setTimeInterval:(id)sender
{
	timeInterval = [sender intValue];
	[intervalTextField setFloatValue:timeInterval];
	[self updateTimeInterval];
}


-(IBAction) setSplitMethod:(id)sender
{
	splitMethod = [sender indexOfSelectedItem];
	[Utils setIntDefault:splitMethod
				  forKey:RCBDefaultSplitMethod];
	[self updateAutoSplit];
}

 
-(int) splitMethod
{
	return splitMethod;
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
