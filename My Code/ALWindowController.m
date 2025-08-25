//
//  ALWindowController.m
//  TLP
//
//  Created by Rob Boyer on 9/30/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "ALWindowController.h"
#import "Track.h"
#import "TrackPoint.h"
#import "TrackBrowserDocument.h"
#import "Utils.h"
#import "Defs.h"


@implementation ALWindowController

- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"DataListView"];
	track = nil;
	updatingLocation = NO;
	tbDocument = doc;
	return self;
}


- (void)dealloc
{
   //NSLog(@"Data List controller dealloc...rc:%d", [self retainCount]);
   [[NSNotificationCenter defaultCenter] removeObserver:self];
   [track release];
   [super dealloc];
}


- (void)trackChanged:(NSNotification *)notification
{
	if (track == [notification object])
	{
		[tableView reloadData];
		trackHasDistance = [track hasDistance];
	}
}


- (void)prefsChanged:(NSNotification *)notification
{
	[tableView reloadData];
}


-(void) awakeFromNib
{
   //NSLog(@"data list window awakening..\n");
   [[self window] center];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(trackChanged:)
                                                name:@"TrackChanged"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(prefsChanged:)
                                                name:@"PreferencesChanged"
                                              object:nil];
}


- (Track*)track
{
   return track;
}


- (void)setTrack:(Track*)t
{
	if (t != track)
	{
		[track release];
		track = t;
		[track retain];
		[tableView reloadData];
		trackHasDistance = [track hasDistance];
	}
}



-(IBAction)delete:(id)sender;
{
   if ((nil != tableView) && (nil != track))
   {
      [tbDocument removePointsAtIndices:track selected:[tableView selectedRowIndexes]];
   }
}


// ----------------------------------------------------------------------------------------------
// tableview datasource methods


- (NSMutableArray*) getPointsForTable:(Track*) t
{
#if ASCENT_DBG
   return [t points];       // for debugging
#else
   return [t goodPoints];
#endif
}



- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
   id retVal = nil;
   if (track != nil)
   {
      id point = [[self getPointsForTable:track] objectAtIndex:rowIndex];
      if (point != nil)
      {
         id ident = [aTableColumn identifier];
         if ([ident isEqualToString:@"date"])
         {
              retVal = [[point date] descriptionWithCalendarFormat:@"%H:%M:%S"
                                                          timeZone:[NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]] 
                                                            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
         }
         else if ([ident isEqualToString:@"activeTime"])
         {
            NSDate* at = [point activeTime];
            NSTimeInterval ti = [at timeIntervalSinceDate:[track creationTime]];
            int hours = (int)ti/3600;
            int mins = (int)(ti/60.0) % 60;
            int secs = (int)ti % 60;
            retVal = [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
         }
         else if ([ident isEqualToString:@"distance"])
         {
			 float d = trackHasDistance ? 
            retVal = [NSNumber numberWithFloat:[Utils convertDistanceValue:[point distance]]];
         }
         else if ([ident isEqualToString:@"speed"])
         {
            retVal = [NSNumber numberWithFloat:[Utils convertSpeedValue:[point speed]]];
         }
         else if ([ident isEqualToString:@"altitude"])
         {
            retVal = [NSNumber numberWithFloat:[Utils convertClimbValue:[point altitude]]];
         }
         else
         {
            retVal = [point valueForKey:ident];
         }
      }
   }
   return retVal;
}


- (void)tableView:(NSTableView *)aTableView
   setObjectValue:anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(int)rowIndex
{
   if (track != nil)
   {
      id point = [[self getPointsForTable:track] objectAtIndex:rowIndex];
      if (point != nil)
      {
         id ident = [aTableColumn identifier];
         id obj = anObject;
         BOOL usingStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
         if (!usingStatuteUnits)
         {
            if ([ident isEqualToString:@"distance"])
            {
               obj = [NSNumber numberWithFloat:KilometersToMiles([anObject floatValue])];
            }
            else if ([ident isEqualToString:@"speed"])
            {
               obj = [NSNumber numberWithFloat:KilometersToMiles([anObject floatValue])];
            }
            else if ([ident isEqualToString:@"altitude"])
            {
               obj = [NSNumber numberWithFloat:MetersToFeet([anObject floatValue])];
            }
         }
          if ([ident isEqualToString:@"speed"]) [point setSpeedOverriden:YES];
         [tbDocument setTrackPointItem:track point:point key:ident value:obj];
      }
   }
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
   if (track != nil)
   {
      return [[self getPointsForTable:track] count];
   }
   else
   {
      return 0;
   }
}

// ----------------------------------------------------------------------------------------------




@end
