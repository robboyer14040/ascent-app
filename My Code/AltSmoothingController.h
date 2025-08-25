//
//  AltSmoothingController.h
//  Ascent
//
//  Created by Rob Boyer on 3/18/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AltSmoothingController : NSWindowController 
{
	IBOutlet NSSlider*		factorSlider;
	IBOutlet NSTextField*   factorTextField;
	float					factor;
	BOOL                    isValid;
}
	
-(id) initWithFactor:(float)f;
-(float) factor;

-(IBAction) setFactor:(id)sender;
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
	

@end
