//
//  RegController.h
//  Ascent
//
//  Created by Rob Boyer on 1/27/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define CHECK_REGISTRATION       activityFileExists


@interface RegController : NSWindowController
{
	IBOutlet NSButton*      notYetButton;
	IBOutlet NSButton*      purchaseButton;
	IBOutlet NSButton*      enterCodeButton;
	IBOutlet NSButton*      doneEnteringInfoButton;
	IBOutlet NSWindow*      enterCodePanel;
	IBOutlet NSTextField*   userNameField;
	IBOutlet NSTextField*   emailAddressField;
	IBOutlet NSTextField*   codeField;
	IBOutlet NSTextField*   blurbText1;
	IBOutlet NSTextField*   blurbText2;
}

- (id) init;
- (IBAction) buyIt:(id)sender;
- (IBAction) enterCode:(id)sender;
- (IBAction) notYet:(id)sender;
- (IBAction) doneEnteringInfo:(id)sender;
- (IBAction) cancelEnteringInfo:(id)sender;
+ (BOOL) CHECK_REGISTRATION;
+(BOOL) gi:(NSMutableString*)nm a2:(NSMutableString*)em a3:(NSMutableString*)tt;



@end
