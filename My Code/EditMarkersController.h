//
//  EditMarkersController.h
//  Ascent
//
//  Created by Rob Boyer on 11/12/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class TrackBrowserDocument;
@class ActivityDetailView;

@interface EMCTableView : NSTableView
{
   
}

@end



@interface EditMarkersController : NSWindowController 
{
   IBOutlet EMCTableView*     markerTable;
   IBOutlet NSTextField*      activityText;
   IBOutlet NSPanel*          panel;
   IBOutlet NSSlider*         opacitySlider;
   NSMutableArray*            markers;
   Track*                     track;
   ActivityDetailView*                    adView;
   float                      currentDistance;
   float                      panelOpacity;
   BOOL                       isValid;
}


-(IBAction) newMarker:(id)sender;
-(IBAction) deleteSelectedMarkers:(id)sender;
-(IBAction) deleteAllMarkers:(id)sender;
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
-(IBAction) setPanelOpacity:(id)sender;

- (id) initWithTrack:(Track*)track
              adView:(ActivityDetailView*)adView;
- (void) reset;
- (void) resetMarkers;
-(NSMutableArray*) markers;
-(BOOL) isValid;


@end
