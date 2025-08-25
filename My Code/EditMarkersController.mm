//
//  EditMarkersController.mm
//  Ascent
//
//  Created by Rob Boyer on 11/12/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "EditMarkersController.h"
#import "Track.h"
#import "PathMarker.h"
#import "Utils.h"
#import "Defs.h"
#import "ADView.h"

@implementation EMCTableView

- (void)textDidEndEditing:(NSNotification *)aNotification
{
   BOOL doEdit = YES;
   
   [super textDidEndEditing:aNotification];
   
   switch ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] 
      intValue]) {
      case NSReturnTextMovement:        // return
      {
         doEdit = NO;
         break;
      }
      case NSBacktabTextMovement:    // shift tab
      {
         doEdit = YES;
         break;
      }
         //case NSTabTextMovement:        // tab
      default:
      {
         doEdit = YES;
      }
   } // switch
   
   if (!doEdit) {
      [self validateEditing];
      [self abortEditing];
      // do something else ...
   }
}

@end


@implementation EditMarkersController


-(float) getCurrentDistance
{
   NSArray* pts = [track goodPoints];
   int idx = [adView currentPointIndex];
   return [[pts objectAtIndex:idx] distance];
}


- (id) initWithTrack:(Track*)tr
              adView:(ADView*)adv;
{
   self = [super initWithWindowNibName:@"EditMarkers"];
   track = tr ;
   adView = adv;
   currentDistance = [self getCurrentDistance];
   [self resetMarkers];
   isValid = YES;
   [self reset];
   return self;
}

- (void) reset
{
	BOOL useStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
	NSString* s;
	if (useStatute)
	{
		s = @"Distance (mi)";
	}
	else
	{
		s = @"Distance (km)";
	}
	NSTableColumn* col = [markerTable tableColumnWithIdentifier:@"distance"];
	[[col headerCell] setStringValue:s];
}


- (id) init
{
   return [self initWithTrack:nil adView:nil];
}

-(void) awakeFromNib
{
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"MarkersPanelFrame"];
	if (![[self window] setFrameUsingName:@"MarkersPanelFrame"])
	{
		[[self window] center];
	}
   NSString* dt = [Utils activityNameFromDate:track alternateStartTime:nil];
   [activityText setStringValue:[NSString stringWithFormat:@"Markers for activity starting on:\n%@", dt]]; 
   [panel setFloatingPanel:YES];
   panelOpacity = [Utils floatFromDefaults:RCBDefaultMarkersPanelTransparency];
   if (panelOpacity < 0.3) panelOpacity = 0.3;
   [opacitySlider setFloatValue:panelOpacity];
   [panel setAlphaValue:panelOpacity];
   [self reset];
}


- (void) dealloc
{
    [markers release];
    [super dealloc];
}


- (void) resetMarkers
{
   [markers autorelease];
   markers = [[NSMutableArray arrayWithArray:[track markers]] retain];
   [markerTable reloadData];
}



-(IBAction) newMarker:(id)sender
{
   PathMarker* marker = [[PathMarker alloc] initWithData:@"" 
                                               imagePath:@""
                                                distance:[self getCurrentDistance]];
   [markers addObject:marker];
   // now sort, then edit the item we just added
   [markers sortUsingSelector:@selector(compare:)];
   [markerTable reloadData];
   int idx = [markers indexOfObjectIdenticalTo:marker];
   if ((idx >= 0) && (idx < [markers count]))
   {
      NSIndexSet* is = [NSIndexSet indexSetWithIndex:idx];
      [markerTable selectRowIndexes:is
               byExtendingSelection:NO];
      [markerTable editColumn:0
                          row:idx
                    withEvent:nil
                       select:YES];
   }
}


-(IBAction) deleteSelectedMarkers:(id)sender
{
   [[self window] makeFirstResponder:nil];
   [markers removeObjectsAtIndexes:[markerTable selectedRowIndexes]];
   [markerTable reloadData];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"MarkersChanged" object:self];
}


-(IBAction) deleteAllMarkers:(id)sender
{
   [[self window] makeFirstResponder:nil];
   [markers removeAllObjects];
   [markerTable reloadData];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"MarkersChanged" object:self];
}

- (IBAction) dismissPanel:(id)sender
{
   [[self window] makeFirstResponder:nil];
   [self close];
}


-(IBAction) done:(id)sender
{
   [self dismissPanel:sender];
}


-(IBAction) cancel:(id)sender
{
   isValid = NO;
   [self dismissPanel:sender];
}

-(BOOL) isValid
{
   return isValid;
}


- (void)windowWillClose:(NSNotification *)aNotification
{
}


- (void) setMarkerItem:(PathMarker*)marker key:(id)ident value:(id)val
{
   [marker setValue:val forKey:ident];
   [markerTable reloadData];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"MarkersChanged" object:self];
   [[self window] makeFirstResponder:nil];
}



- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
   id retVal = nil;
   if (markers != nil)
   {
      id marker = [markers objectAtIndex:rowIndex];
      if (marker != nil)
      {
         id ident = [aTableColumn identifier];
         if ([ident isEqualToString:@"distance"])
         {
            retVal = [NSNumber numberWithFloat:[Utils convertDistanceValue:[marker distance]]];
         }
         else
         {
            retVal = [marker valueForKey:ident];
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
	if (markers != nil)
	{
		if (rowIndex < [markers count])
		{
			id marker = [markers objectAtIndex:rowIndex];
			if (marker != nil)
			{
				id ident = [aTableColumn identifier];
				BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
				if (!useStatuteUnits && [ident isEqualToString:@"distance"])
				{
					float v = KilometersToMiles([anObject floatValue]);
					[self setMarkerItem:marker key:ident value:[NSNumber numberWithFloat:v]];
				}
				else
				{
					[self setMarkerItem:marker key:ident value:anObject];
				}
			}
		}
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
   if (markers != nil)
   {
      return [markers count];
   }
   else
   {
      return 0;
   }
}


-(NSMutableArray*) markers
{
   return markers;
}


- (IBAction) setPanelOpacity:(id)sender
{
   panelOpacity = [sender floatValue];
   [[self window] setAlphaValue:panelOpacity];
   [Utils setFloatDefault:panelOpacity forKey:RCBDefaultMarkersPanelTransparency];
}


@end
