/* AppController */

#import <Cocoa/Cocoa.h>

@class ADWindowController;
@class TransportPanelController;
@class SUUpdater;
@class SyncController;
@class TrackBrowserDocument;

@interface AppController : NSObject <NSApplicationDelegate>
{ 
	IBOutlet NSView*			aboutContentView;
	IBOutlet NSPanel*			aboutPanel;
	IBOutlet SUUpdater*			suUpdater;
	IBOutlet NSMenuItem*		copyKeyword1MenuItem;
	IBOutlet NSMenuItem*		copyKeyword2MenuItem;
	TransportPanelController*	transportPanelController;
	NSDocument*					initialDocument;
	SyncController*				syncController;
}
- (IBAction)showActivityDetail:(id)sender;
- (IBAction)showActivityDataList:(id) sender;
- (IBAction)showTransportPanel:(id)sender;
- (IBAction)print:(id)sender;
- (IBAction)makeANewDocument:(id)sender;
- (IBAction)clearMapCache:(id)sender;
- (IBAction)gotoAscentWebSite:(id)sender;
- (IBAction)gotoAscentForum:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)openTheDocument:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)saveADocument:(id)sender;

- (BOOL) validateMenuItem:(NSMenuItem*) mi;
- (TrackBrowserDocument*) currentTrackBrowserDocument;

@end
