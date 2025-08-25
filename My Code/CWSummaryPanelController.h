//
//  CWSummaryPanelController.h
//  Ascent
//
//  Created by Rob Boyer on 4/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CWSummaryPanelController : NSWindowController 
{
	IBOutlet NSButton*		alwaysShowHelpButton;
	IBOutlet NSTextView*	helpTextView;
}
-(IBAction)setAlwaysShowHelp:(id)sender;

@end
