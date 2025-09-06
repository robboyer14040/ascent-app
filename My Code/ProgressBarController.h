//
//  ProgressBarController.h
//  Ascent
//
//  Created by Rob Boyer on 8/5/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SingletonBase.h"


@interface ProgressBarController : NSWindowController 
{
	IBOutlet NSProgressIndicator*   progressInd;
	IBOutlet NSTextField*           textMessageField;
	IBOutlet NSButton*				cancelButton;
	int                             numDivisions;
	int                             curDiv;
	SEL								cancelSelector;
	id								cancelObject;
}

- (void) begin:(NSString*)title divisions:(int)divs;
- (void) setCancelSelector:(SEL)cs forObject:(id)obj;
- (void) end;
- (void) updateMessage:(NSString*)msg;
- (void) incrementDiv;
- (void) setDivs:(int)divs;
- (int) currentDivs;
- (int) totalDivs;

-(IBAction) cancel:(id)sender;

@end


@interface SharedProgressBar : SingletonBase
{
}

-(ProgressBarController*) controller;


@end
