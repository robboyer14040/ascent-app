//
//  ProgressBarController.mm
//  Ascent
//
//  Created by Rob Boyer on 8/5/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "ProgressBarController.h"


@implementation ProgressBarController


- (id) initUsingNib
{
	self = [super initWithWindowNibName:@"ProgressBar"];
	numDivisions = 0;
	curDiv = 0;
	textMessage = 0;
	cancelSelector = NULL;
	cancelObject = nil;
	[cancelButton setHidden:YES];
	return self;
}

-(void) dealloc
{
    [super dealloc];
}


-(void) awakeFromNib
{
	[textMessageField setDrawsBackground:YES];
}


- (void) begin:(NSString*)title divisions:(int)divs
{
	[cancelButton setHidden:YES];
	curDiv = 0;
	numDivisions = divs;
 	if (divs) 
	{
		[progressInd setIndeterminate:NO];
		[progressInd setUsesThreadedAnimation:NO];
		[progressInd setMinValue:0.0];
		[progressInd setMaxValue:(double)numDivisions];
		[progressInd setDoubleValue:0.0];
	}
	else
	{
		[progressInd setIndeterminate:YES];
		[progressInd setUsesThreadedAnimation:YES];
		[progressInd startAnimation:self];
	}
	[[self window] setTitle:title];
	[[self window] display];
	[self updateMessage:@""];
}


- (void) end
{
	[progressInd stopAnimation:self];
}


- (void) updateMessage:(NSString*)msg
{
   if (msg != textMessage)
   {
      textMessage = msg;
   }
   [textMessageField setStringValue:msg];
   [textMessageField displayIfNeeded];
}


- (void) incrementDiv
{
   ++curDiv;
   [progressInd incrementBy:1.0];
   [progressInd displayIfNeeded];
}


- (void) setDivs:(int)divs
{
	curDiv = divs;
	[progressInd setDoubleValue:(float)curDiv];
	[progressInd displayIfNeeded];
}

- (int) currentDivs
{
	return curDiv;
}


- (int) totalDivs
{
	return numDivisions;
}

- (void) setCancelSelector:(SEL)cs  forObject:(id)obj;
{
	cancelSelector = cs;
	cancelObject = obj;
	[cancelButton setHidden:NO];
}


-(IBAction) cancel:(id)sender
{
	if ((cancelSelector != NULL) && cancelObject)
	{
		[cancelObject performSelector:cancelSelector];
	}
}
		
@end


//------------------------------------------------------------------------------------------------

@implementation SharedProgressBar

static ProgressBarController*    pbController;

+ (void)initialize
{
   pbController = [[ProgressBarController alloc] initUsingNib];
}


-(ProgressBarController*) controller
{
   return pbController;
}

@end
