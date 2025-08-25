


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
#import "SelectAndApplyActionController.h"
#import "Utils.h"
#import "Defs.h"
#import "AscentIntervalFormatter.h"
#import "AnimTimer.h"

@implementation ALWindowController

- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"DataListView"];
	track = nil;
	displayPace = NO;		// @@FIXME DEFAULTS
	trackHasDistance = NO;
	tbDocument = doc;
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


- (void)trackChanged:(NSNotification *)notification
{
	if (track == [notification object])
	{
		trackHasDistance = [track hasDistance];
		[tableView reloadData];
	}
}


- (void)prefsChanged:(NSNotification *)notification
{
   [tableView reloadData];
}


- (void)dataFilterChanged:(NSNotification *)notification
{
	NSIndexSet* is = [notification object];
	//printf("selecting %d rows\n", [is count]);
	[tableView selectRowIndexes:is byExtendingSelection:NO];
}


-(void)setPaceOrSpeedColumn
{
	id ident = @"speed";
	if (!displayPace) ident = @"pace";
	NSTableColumn* col = [tableView tableColumnWithIdentifier:ident];
	if (col)
	{
		if (displayPace)
		{
			[col setIdentifier:@"pace"];
			[[col headerCell] setStringValue:@"Pace"];
			AscentIntervalFormatter* fm =[[AscentIntervalFormatter alloc] initAsPace:YES];
			[[col dataCell] setFormatter:fm];
		}
		else
		{
			[col setIdentifier:@"speed"];
			[[col headerCell] setStringValue:@"Speed"];
			NSNumberFormatter* fm =[[NSNumberFormatter alloc] init];
			[fm setFormat:[NSString stringWithFormat:@"#0.0"]];
			[[col dataCell] setFormatter:fm];
		}
		[tableView reloadData];
	}
}




-(void) awakeFromNib
{
   //NSLog(@"data list window awakening..\n");
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"DataDetailWindowFrame"];
	if (![[self window] setFrameUsingName:@"DataDetailWindowFrame"])
	{
		[[self window] center];
	}
	[[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(trackChanged:)
                                                name:@"TrackChanged"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(prefsChanged:)
                                                name:@"PreferencesChanged"
                                              object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(dataFilterChanged:)	// for advanced option
												 name:@"DataFilterChanged"
											   object:nil];
	
	displayPace = [Utils boolFromDefaults:RCBDefaultDataDetailShowsPace];
	[displayPaceButton setIntValue:displayPace ? 1 : 0];
	[self setPaceOrSpeedColumn];
	[tableView setDelegate:self];
	[[AnimTimer defaultInstance] registerForTimerUpdates:self];
}


- (Track*)track
{
   return track;
}


- (void)setTrack:(Track*)t
{
	if (t != track)
	{
		track = t;
		trackHasDistance = [track hasDistance];
		[track calculatePower];
		[tableView reloadData];
	}
}



-(IBAction)delete:(id)sender;
{
	if ((nil != tableView) && (nil != track))
	{
		NSIndexSet* is = [tableView selectedRowIndexes];
		if ([is count] > 0)
		{
			NSUInteger first = [is firstIndex];
			if (first != NSNotFound)
			{
				[tbDocument removePointsAtIndices:track 
										 selected:is];
                NSUInteger row = first - 1;
                NSInteger numTableRows = [tableView numberOfRows];
				if (numTableRows > 0)
				{
					if (row > numTableRows)
					{
						row = numTableRows - 1;
					}
					else if (row < 0)
					{
						row = 0;
					}
					[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                           byExtendingSelection:NO];
				}
			}
		}
   }
}



-(IBAction)update:(id)sender
{
	[track fixupTrack];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TrackChanged" object:track];
}



- (IBAction) postAdvanced:(id)sender
{
	SelectAndApplyActionController* wc = [[SelectAndApplyActionController alloc] initWithTrack:track
																					  selected:[tableView selectedRowIndexes]
																				displayingPace:displayPace];
	NSRect fr = [[self window] frame];
	NSRect panelRect = [[wc window] frame];
	NSPoint origin = fr.origin;
	origin.x += (fr.size.width/2.0) - (panelRect.size.width/2.0);
	origin.y += (fr.size.height/2.0)  - (panelRect.size.height/2.0);

	[[wc window] setFrameOrigin:origin];
	[wc showWindow:self];
    NSModalResponse ok = [NSApp runModalForWindow:[wc window]];
	if (ok == 0)
	{
		[tbDocument changeTrackPoints:track newPointArray:[wc newPoints] updateTrack:YES];
	}
	[[wc window] orderOut:[self window]];
	[[self window] makeKeyAndOrderFront:self];
}



-(IBAction)displayPaceInsteadOfSpeed:(id)sender
{
	displayPace = [sender intValue] != 0;
	[Utils setBoolDefault:displayPace forKey:RCBDefaultDataDetailShowsPace];
	[self setPaceOrSpeedColumn];
}



- (void)fade:(NSTimer *)theTimer
{
	if ([[self window] alphaValue] > 0.0) {
		// If window is still partially opaque, reduce its opacity.
		[[self window]  setAlphaValue:[[self window]  alphaValue] - 0.2];
	} else {
		// Otherwise, if window is completely transparent, destroy the timer and close the window.
		[fadeTimer invalidate];
		fadeTimer = nil;
		
		[[self window]  close];
		
		// Make the window fully opaque again for next time.
		[[self window]  setAlphaValue:1.0];
	}
}


- (void)windowWillClose:(NSNotification *)aNotification
{
}


- (BOOL)windowShouldClose:(id)sender
{
	// Set up our timer to periodically call the fade: method.
	fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
	
	// Don't close just yet.
	return NO;
}


-(IBAction)done:(id)sender
{
	fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
}




#if 0
- (IBAction)copy:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSString* s = [track buildTextOutput:'\t'];
	[pb setString:s
		  forType:NSTabularTextPboardType];
	[pb setString:s 
		  forType:NSStringPboardType];
}
#else
- (IBAction)copy:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *s = [track buildTextOutput:'\t']; // tab-separated rows

    [pb clearContents]; // optional but recommended

    // Provide both representations so more apps can paste it properly
    [pb setString:s forType:NSPasteboardTypeString];
    [pb setString:s forType:NSPasteboardTypeTabularText];
}
#endif

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger idx = [tableView selectedRow];
    NSInteger ct = [[track points] count];	// 'count' returns unsigned int
	if (IS_BETWEEN(0,idx, (ct-1)))
	{
		TrackPoint* pt = [[track points] objectAtIndex:idx];
		updatingLocation = YES;
		[[AnimTimer defaultInstance] setAnimTime:[pt activeTimeDelta]];
		updatingLocation = NO;

	}
}


-(void) updatePosition:(NSTimeInterval)trackTime reverse:(BOOL)rev animating:(BOOL)anim
{
	if (!updatingLocation)
	{
		int idx = [track findIndexOfFirstPointAtOrAfterActiveTimeDelta:trackTime];
		if (idx >= 0)
		{
			[tableView scrollRowToVisible:idx];
			[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx]
				   byExtendingSelection:YES];
		}
	}
}


- (Track*) animationTrack
{
	return track;
}

-(void) beginAnimation
{
}


-(void) endAnimation
{
}

// ----------------------------------------------------------------------------------------------
// tableview datasource methods


- (NSMutableArray*) getPointsForTable:(Track*) t
{
   return [t points];
}



- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
	id retVal = nil;
	if (track != nil)
	{
		TrackPoint* point = [[self getPointsForTable:track] objectAtIndex:rowIndex];
		if (point != nil)
		{
			id ident = [aTableColumn identifier];
			if ([ident isEqualToString:@"date"])
            {
#if 0
                retVal = [[[track creationTime] addTimeInterval:[point wallClockDelta]] descriptionWithCalendarFormat:@"%H:%M:%S"
                                                                                                             timeZone:[NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]]
                                                                                                               locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
#else
                // thanks AI
                NSDate *base     = [track creationTime];                       // NSDate (or NSCalendarDate subclass)
                NSTimeInterval d = [point wallClockDelta];

                NSDate *adjusted = [base dateByAddingTimeInterval:d];         // ✅ replace addTimeInterval:
                NSDateFormatter *fmt = [NSDateFormatter new];
                fmt.locale   = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // stable for fixed pattern
                fmt.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
                fmt.dateFormat = @"HH:mm:ss";                                  // replaces descriptionWithCalendarFormat

                NSString *retVal = [fmt stringFromDate:adjusted];
#endif
            }
			else if ([ident isEqualToString:@"lap"])
			{
#if ASCENT_DBG
				retVal = [NSString stringWithFormat:@"%d-%d", [track lapIndexOfPoint:point]+1, rowIndex];
#else
				retVal = [NSString stringWithFormat:@"%d", [track lapIndexOfPoint:point]+1];
#endif
			}
			else if ([ident isEqualToString:@"activeTime"])
			{
				//NSDate* at = [point activeTime];
				//NSTimeInterval ti = [at timeIntervalSinceDate:[track creationTime]];
				NSTimeInterval ti = [point activeTimeDelta];
				int hours = (int)ti/3600;
				int mins = (int)(ti/60.0) % 60;
				int secs = (int)ti % 60;
#if ASCENT_DBG
				float lastWCD = 0.0;
				if (rowIndex > 0)
				{
					id lastPoint = [[self getPointsForTable:track] objectAtIndex:rowIndex-1];
					lastWCD = [lastPoint wallClockDelta];
				}
				float wcd = [point wallClockDelta];
				retVal = [NSString stringWithFormat:@"%02d:%02d:%02d  delta:%0.2f", hours, mins, secs, wcd - lastWCD];
				lastWCD = wcd;
#else
				retVal = [NSString stringWithFormat:@"%02d:%02d:%02d", hours, mins, secs];
#endif				
			
			}
			else if ([ident isEqualToString:@"temperature"])
			{
				float t = [Utils convertTemperatureValue:[point temperature]];
				retVal = [NSNumber numberWithFloat:t];
			}
			else if ([ident isEqualToString:@"distance"] || [ident isEqualToString:@"origDistance"])
			{
				float d = trackHasDistance ? [point origDistance] : [point distance];
				retVal = [NSNumber numberWithFloat:[Utils convertDistanceValue:d]];
			}
			else if ([ident isEqualToString:@"speed"])
			{
				retVal = [NSNumber numberWithFloat:[Utils convertSpeedValue:[point speed]]];
			}
			else if ([ident isEqualToString:@"pace"])
			{
				retVal = [NSNumber numberWithFloat:[Utils convertPaceValue:[point pace]]];
			}
			else if ([ident isEqualToString:@"power"])
			{
				retVal = [NSNumber numberWithFloat:[point power]];
			}
			else if ([ident isEqualToString:@"altitude"] || [ident isEqualToString:@"origAltitude"])
			{
				retVal = [NSNumber numberWithFloat:[Utils convertClimbValue:[point origAltitude]]];
			}
			else if ([ident isEqualToString:@"latitude"] || [ident isEqualToString:@"longitude"])
			{
				retVal = [point valueForKey:ident];
			}
			else
			{
				retVal = [point valueForKey:ident];
			}
		}
	}
	return retVal;
}


-(void) updateCellUsingValidity:(NSCell*)aCell isValid:(BOOL)isValid
{
	if (isValid)
	{
		[aCell setEnabled:true];
	}
	else
	{
		[aCell setStringValue:@"<missing>"];
		[aCell setEnabled:false];
	}
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	id ident = [aTableColumn identifier];
	id point = [[self getPointsForTable:track] objectAtIndex:rowIndex];
	if (point)
	{
		if ([ident isEqualToString:@"distance"] || [ident isEqualToString:@"origDistance"])
		{	
			[self updateCellUsingValidity:aCell
								  isValid:[point validDistance]];
		}
		else if ([ident isEqualToString:@"altitude"] || [ident isEqualToString:@"origAltitude"])
		{
			[self updateCellUsingValidity:aCell
								  isValid:[point validAltitude]];
		}
		else if ([ident isEqualToString:@"latitude"] || [ident isEqualToString:@"longitude"])
		{
			[self updateCellUsingValidity:aCell
								  isValid:[point validLatLon]];
		}
	}
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
			id key = ident;
			id obj = anObject;
			BOOL usingStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
			BOOL usingCentigrade = [Utils boolFromDefaults:RCBDefaultUseCentigrade];
			if ([ident isEqualToString:@"pace"])
			{
				ident = @"speed";
				float v = [obj floatValue];
				v = PaceToSpeed(v);
				obj = [NSNumber numberWithFloat:v];
			}
			else if ([ident isEqualToString:@"altitude"] || [ident isEqualToString:@"origAltitude"])
			{
				key = @"origAltitude";		// must change ORIGINAL altitude
				if (!usingStatuteUnits) obj = [NSNumber numberWithFloat:MetersToFeet([anObject floatValue])];
			}
			else if ([ident isEqualToString:@"distance"] || [ident isEqualToString:@"origDistance"])
			{
				key = @"origDistance";		// must change ORIGINAL distance
				if (!usingStatuteUnits) obj = [NSNumber numberWithFloat:KilometersToMiles([anObject floatValue])];
			}
			
			if ([ident isEqualToString:@"speed"])
			{
				if (!usingStatuteUnits) obj = [NSNumber numberWithFloat:KilometersToMiles([anObject floatValue])];
			}
			
			if (usingCentigrade)
			{
				if ([ident isEqualToString:@"temperature"])
				{
					obj = [NSNumber numberWithFloat:CelsiusToFahrenheight([anObject floatValue])];
				}
			}
			float ov = [[point valueForKey:ident] floatValue];
			if (obj && (fabsf([obj floatValue] - ov) >= 0.1))
			{
				TrackPoint* newPoint = [point mutableCopyWithZone:nil];
				if ([ident isEqualToString:@"speed"])
				{
					[newPoint setSpeedOverriden:YES];
				}
				[newPoint setValue:obj forKey:key];
				//NSLog(@"updated point with new value:%0.1f (old:%0.1f) for %@\n", [obj floatValue], ov, key);
				[tbDocument replaceTrackPoint:track point:point newPoint:newPoint key:ident updateTrack:NO];
			}
		}	
	}
}


- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView
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


	
@implementation ADListTableView

// this is necessary to over-ride leopard behavior -- hitting return no longer selects the same
// column in the next row.  ugh
#if 0
- (void)textDidEndEditing:(NSNotification *)aNotification
{
	if ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement) 
	{
		int row = [self editedRow] + 1;
		int col = [self editedColumn];
		NSMutableDictionary *ui = [NSMutableDictionary dictionaryWithDictionary:[aNotification userInfo]];
		[ui setObject:[NSNumber numberWithInt:NSDownTextMovement] forKey:@"NSTextMovement"];
		aNotification = [NSNotification notificationWithName:[aNotification name] object:[aNotification object] userInfo:ui];
		[super textDidEndEditing:aNotification];
		if (row < [self numberOfRows]) 
		{
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
              byExtendingSelection:NO];
			[self editColumn:col row:row withEvent:nil select:YES];
		}
	} 
	else 
	{
		[super textDidEndEditing:aNotification];
	}
}
#else
/// AI Fix
// NSTableView subclass (or your table's delegate)
- (BOOL)control:(NSControl *)control
      textView:(NSTextView *)textView
doCommandBySelector:(SEL)command
{
    if (command == @selector(insertNewline:)) {
        NSInteger row = self.editedRow;
        NSInteger col = self.editedColumn;

        // Commit the current edit
        [self.window makeFirstResponder:self];

        // Move to next row and begin editing same column
        row += 1;
        if (row < self.numberOfRows) {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
              byExtendingSelection:NO];
            [self editColumn:col row:row withEvent:nil select:YES];
        }
        return YES; // we've handled Return
    }
    return NO; // let the system handle other commands
}


#endif
    
@end
