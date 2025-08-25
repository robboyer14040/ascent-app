//
//  ALWindowController.h - controls Activity Data List view
//  TLP
//
//  Created by Rob Boyer on 9/30/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class Track;

@interface ADListTableView : NSTableView
{
}
@end


@interface ALWindowController : NSWindowController <NSTableViewDelegate>
{
	IBOutlet ADListTableView*   tableView;
	IBOutlet NSButton*			displayPaceButton;
	TrackBrowserDocument*		tbDocument;
	Track*						track;
	NSTimer*					fadeTimer;
	BOOL						displayPace;
	BOOL						trackHasDistance;
	BOOL						updatingLocation;
}

-(IBAction)delete:(id)sender;
-(IBAction)postAdvanced:(id)sender;
-(IBAction)done:(id)sender;
-(IBAction)update:(id)sender;
-(IBAction)displayPaceInsteadOfSpeed:(id)sender;

- (id)initWithDocument:(TrackBrowserDocument*)doc;
- (Track*)track;
- (void)setTrack:(Track*)t;

@end
