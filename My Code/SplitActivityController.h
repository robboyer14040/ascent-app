//
//  SplitActivityController.h
//  Ascent
//
//  Created by Rob Boyer on 3/18/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentTextField.h"

enum 
{
	kSplitUsingTimeInterval,
	kSplitAtCurrentTime,
	kNumSplitMethods
};


@interface SplitActivityController : NSWindowController 
{
	IBOutlet NSSlider*			intervalSlider;
	IBOutlet NSPopUpButton*		splitMethodPopup;
	IBOutlet AscentTextField*   intervalTextField;
	IBOutlet AscentTextField*	sliderLabel;
	IBOutlet AscentTextField*	elapsedTimeHelpLabel;
	NSTimeInterval				timeInterval;
	int							splitMethod;
	BOOL						isValid;
}	
	
-(id) initWithInterval:(NSTimeInterval)intervalInSeconds;

-(IBAction) setTimeInterval:(id)sender;
-(IBAction) setSplitMethod:(id)sender;
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
	
-(NSTimeInterval) timeInterval;
-(int) splitMethod;

@end
