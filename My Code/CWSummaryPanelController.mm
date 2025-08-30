//
//  CWSummaryPanelController.mm
//  Ascent
//
//  Created by Rob Boyer on 4/4/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "CWSummaryPanelController.h"
#import "Defs.h"
#import "Utils.h"

@implementation CWSummaryPanelController

-(void)dealloc
{
}

-(void)awakeFromNib
{
	BOOL dontShow = [Utils boolFromDefaults:RCBDefaultCompareWindowDontShowHelp];
	[alwaysShowHelpButton setState:dontShow ? NSControlStateValueOff : NSControlStateValueOn];
}

-(IBAction)setAlwaysShowHelp:(id)sender
{
	BOOL alwaysShow = [sender state] == NSControlStateValueOn;
	[Utils setBoolDefault:!alwaysShow
				   forKey:RCBDefaultCompareWindowDontShowHelp];
}


- (IBAction) dismissColumnOptionsPanel:(id)sender
{
	[NSApp stopModalWithCode:1];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp stopModalWithCode:1];
}


- (void)windowWillLoad
{
	printf("will load!\n");
}


- (void)windowDidLoad
{
	printf("did load!\n");
}


@end
