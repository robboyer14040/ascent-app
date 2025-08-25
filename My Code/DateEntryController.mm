//
//  DateEntryController.mm
//  Ascent
//
//  Created by Rob Boyer on 8/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "DateEntryController.h"


@implementation DateEntryController


- (id) initWithTrackName:(NSString*)name defaultDate:(NSDate*)defDate
{
   self = [super initWithWindowNibName:@"DateEntry"];
   trackName = [name retain];
   defaultDate = [defDate retain];
   entryStatus = kDateEntryOK;
   return self;
}


- (void) dealloc
{
   [trackName release];
   [defaultDate release];
   [super dealloc];
}


-(void) awakeFromNib
{
   [datePicker setDateValue:defaultDate];
   [datePicker setMaxDate:[NSDate date]];
   [trackNameField setStringValue:trackName];
}


-(NSDate*) date
{
   return [datePicker dateValue];
}


- (IBAction) dismissPanel:(id)sender
{
   [NSApp stopModalWithCode:(entryStatus == kDateEntryOK)?0:-1];
}


- (void) windowWillClose:(NSNotification *)aNotification
{
   entryStatus = kCancelDateEntry;
   [NSApp stopModalWithCode:-1];
}



-(IBAction) cancel:(id)sender
{
   entryStatus = kCancelDateEntry;
   [self dismissPanel:sender];
}


-(IBAction) done:(id)sender
{
   entryStatus = kDateEntryOK;
   [self dismissPanel:sender];
}


-(IBAction) skip:(id)sender;
{
   entryStatus = kSkipDateEntry;
   [self dismissPanel:sender];
}


-(tDateEntryStatus) entryStatus
{
   return entryStatus;
}


@end
