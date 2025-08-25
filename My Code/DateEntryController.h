//
//  DateEntryController.h
//  Ascent
//
//  Created by Rob Boyer on 8/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum tDateEntryStatus
{
   kDateEntryOK,
   kSkipDateEntry,
   kCancelDateEntry
};

@interface DateEntryController : NSWindowController 
{
   IBOutlet    NSDatePicker*  datePicker;
   IBOutlet    NSTextField*   trackNameField;
   NSString*                  trackName;
   NSDate*                    defaultDate;
   tDateEntryStatus           entryStatus;
}

- (id) initWithTrackName:(NSString*)name defaultDate:(NSDate*)defDate;

-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
-(IBAction) skip:(id)sender;

-(NSDate*) date;
-(tDateEntryStatus) entryStatus;


@end
