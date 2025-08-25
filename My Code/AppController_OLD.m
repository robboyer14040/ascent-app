#import "AppController.h"
#import "ADWindowController.h"
#import "ALWindowController.h"
#import "DMWindowController.h"
#import "SGWindowController.h"
#import "TrackBrowserDocument.h"
#import "TBWindowController.h"
#import "Track.h"
#import "Defs.h"
#import "SplashPanelController.h"
#import "TransportPanelController.h"
#import "RegController.h"
#import "MapPathView.h"
#import <OmniAppKit/OAPreferenceClient.h>
#import "Utils.h"
#import <Quartz/Quartz.h>
#import "SUUpdater.h"
#import "KagiGenericACG.h"


SUUpdater* gSUUpdater = nil;

@implementation AppController


NSString* TrackPBoardType = @"TrackPBoardType";

void setColorDefault(NSMutableDictionary* dict,
                     NSString* theKey,
                     float r, float g, float b, float a)
{
   NSData* colorAsData = [NSKeyedArchiver archivedDataWithRootObject:
      [NSColor colorWithCalibratedRed:r/255.0 
                                green:g/255.0 
                                 blue:b/255.0 
                                alpha:a]];
   [dict setObject:colorAsData forKey:theKey];
   
}

+ (void) initialize
{
   NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];

   NSLog(@"This machine has %u processor(s).", OFNumberOfProcessors());
   [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
   
   //NSLog(@"registered default prefs: %@", defaultValues);
   NSPasteboard* pb = [NSPasteboard generalPasteboard];
   NSArray *types = [NSArray arrayWithObjects:TrackPBoardType, NSStringPboardType, nil];
   [pb declareTypes:types owner:self];
   NSString *fontsFolder = [[[NSBundle mainBundle] resourcePath] 
      stringByAppendingPathComponent:@"Fonts"];
   if (fontsFolder) {
      NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
      if (fontsURL) {
         FSRef fsRef;
         FSSpec fsSpec;
         (void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
         OSStatus status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, 
                                            NULL, &fsSpec, NULL);
         if (noErr == status) {
            ATSGeneration generationCount = ATSGetGeneration();
            ATSFontContainerRef container;
            status = ATSFontActivateFromFileSpecification(&fsSpec, kATSFontContextLocal, kATSFontFormatUnspecified, NULL, kATSOptionFlagsDefault, &container);
            generationCount = ATSGetGeneration() - generationCount;
            if (generationCount) {
              // NSLog(@"app - %@ added %u font file%s", @"", generationCount, 
              //      (generationCount == 1 ? "" : "s"));
               ItemCount count;
               status = ATSFontFindFromContainer (container, 
                                                    kATSOptionFlagsDefault, 0, NULL,&count);
               ATSFontRef *ioArray=(ATSFontRef *)malloc(count * sizeof(ATSFontRef));
               status = ATSFontFindFromContainer (container, 
                                                    kATSOptionFlagsDefault, count, ioArray,&count);
               int i;
               for (i=0; i<count; i++)
               {
                  CFStringRef fontName=NULL;
                  status = ATSFontGetName (ioArray[i], kATSOptionFlagsDefault, 
                                          &fontName);
                  //if (fontName) f = [NSFont fontWithName:(NSString*)fontName size:24];
                  // NSLog(@"added %@", (NSString*) fontName);
               }
            }
         }
      }
   }
}


- (id)init
{
   [super init];
   transportPanelController = nil;
   fileURLData = nil;
   initialDocument = nil;
   return self;
}


- (void)dealloc
{
   //NSLog(@"AppController dealloc");
   [transportPanelController release];
   [fileURLData release];
   [super dealloc];
}

- (void)didCloseAllFunc:(NSDocumentController *)docController  didCloseAll: (BOOL)didCloseAll contextInfo:(void *)contextInfo
{
   //volatile int f = 42;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
   NSDocumentController *dc = [NSDocumentController sharedDocumentController];
   [dc closeAllDocumentsWithDelegate:self 
                 didCloseAllSelector:@selector(didCloseAllFunc:didCloseAll:contextInfo:)
                         contextInfo:nil];
}


- (BOOL)application:(NSApplication *)theApplication
           openFile:(NSString *)filename
{
   NSDocumentController *dc;
   id doc;
   
   dc = [NSDocumentController sharedDocumentController];
   doc = [dc openDocumentWithContentsOfFile:filename display:YES];
   NSURL* url = [[NSURL alloc] initFileURLWithPath:filename];
   [[[NSUserDefaultsController sharedUserDefaultsController] values]  
   setValue:[NSArchiver archivedDataWithRootObject:url] 
     forKey:@"lastFileURL"];
   //NSLog(@"opened file %@, lastFileURL:%@\n", filename, url);
   return ( doc != nil);
}





- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *) sender
{
   if ([[NSUserDefaults standardUserDefaults]  objectForKey:@"lastFileURL"])
      return NO;
   return YES;
}


- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
   NSDocumentController *dc;
   dc = [NSDocumentController sharedDocumentController];
   [dc newDocument:self];
   return YES;
}

- (IBAction)makeANewDocument:(id)sender
{
   NSDocumentController *dc;
   dc = [NSDocumentController sharedDocumentController];
   [dc newDocument:self];
}


- (IBAction) showActivityDetail:(id) sender
{
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)
      [[NSDocumentController sharedDocumentController] currentDocument];
   TBWindowController* sc = [tbd windowController];
   [sc stopAnimations];
   Track* track = [tbd currentlySelectedTrack];
   if (nil != track)
   {
		Lap* lap = [tbd selectedLap];
      ADWindowController* adWindowController = [[ADWindowController alloc] initWithDocument:tbd];
      [tbd addWindowController:adWindowController];
      [adWindowController autorelease];
      [adWindowController showWindow:self];
      [adWindowController setTrack:track];
		[adWindowController setLap:lap];
   }
}


- (IBAction) showActivityDataList:(id) sender
{
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)
      [[NSDocumentController sharedDocumentController] currentDocument];
   TBWindowController* sc = [tbd windowController];
   [sc stopAnimations];
   Track* track = [tbd currentlySelectedTrack];
   if (nil != track)
   {
      ALWindowController* alWindowController = [[ALWindowController alloc] initWithDocument:tbd];
      [tbd addWindowController:alWindowController];
      [alWindowController autorelease];
      NSWindow* wind = [alWindowController window];
      [alWindowController setTrack:track];
      NSDate* ct = [track creationTime];
      NSString* name = [track attribute:kName];
      NSString* title = [NSString stringWithString:@"Activity Data - "];
      title = [title stringByAppendingString:name];
      NSString* format = [NSString stringWithString:@"%A, %B %d  %I:%M%p"];
      if ([name length] != 0)
      {
         format = [NSString stringWithString:@"  (%A, %B %d  %I:%M%p)"];
      }
      NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
      title = [title stringByAppendingString:[ct descriptionWithCalendarFormat:format
                                                                      timeZone:tz
                                                                        locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
      [wind setTitle:title];
      [alWindowController showWindow:self];
   }
}


- (IBAction) showDetailedMap:(id) sender
{
   id wc = (TBWindowController*)[NSDocumentController sharedDocumentController];
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)[wc currentDocument];
   Track* track = [tbd currentlySelectedTrack];
   if (nil != track)
   {
      TBWindowController* sc = [tbd windowController];
      //[sc stopAnimations];
      int curDataType = [[sc mapPathView] dataType];
      DMWindowController* dmWindowController = [[DMWindowController alloc] initWithDocument:tbd initialDataType:curDataType];
      [tbd addWindowController:dmWindowController];
      [dmWindowController autorelease];
      [dmWindowController showWindow:self];
      [dmWindowController setTrack:track];
   }
}



- (IBAction) showSummaryGraph:(id) sender
{
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)
      [[NSDocumentController sharedDocumentController] currentDocument];
   TBWindowController* sc = [tbd windowController];
   [sc stopAnimations];
   SGWindowController* sgWindowController = [[SGWindowController alloc] initWithDocument:tbd];
   [tbd addWindowController:sgWindowController];
   [sgWindowController autorelease];
   NSWindow* wind = [sgWindowController window];
   NSString* title = @"Summary Info";
   [wind setTitle:title];
   [sgWindowController showWindow:self];
}


- (void)selectionDoubleClickedInOutlineView:(NSNotification *)notification
{
   int defaultAction = [Utils intFromDefaults:RCBDefaultDoubleClickAction];
   switch (defaultAction)
   {
      default:
      case 0:
         [self showActivityDetail:self];
         break;
      case 1:
         [self showDetailedMap:self];
         break;
      case 2:
         [self showActivityDataList:self];
         break;
   }
}



-(void) openLastDoc:(id)junk
{
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
   sleep(1);
   [[NSNotificationCenter defaultCenter] postNotificationName:@"AfterDocOpened" object:self];
   [pool release];
}   


- (void)afterDocOpened:(NSNotification *)notification
{
   NSError *error;
   if (([notification object] == self) && (fileURLData != nil))
   {
      NSURL *fileURL=[NSUnarchiver unarchiveObjectWithData:  fileURLData];
      [fileURLData autorelease];
      fileURLData = nil;
      initialDocument = [[NSDocumentController sharedDocumentController]  
         openDocumentWithContentsOfURL: fileURL
                               display: NO
                                 error: &error];
      [[SplashPanelController sharedInstance] canDismiss:YES];
      [[SplashPanelController sharedInstance] updateProgress:@"data loaded"];
   }
 }


- (void)transportPanelClosed:(NSNotification *)notification
{
   //[transportPanelController release];
   //transportPanelController = nil;
}




- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
   NSDictionary* d = [[NSBundle mainBundle] infoDictionary];
   NSString* s = [d objectForKey:@"SUFeedURL"];
   NSLog(@"Feed URL: %@", s);
   
   
   /************ BEGIN QUARTZ COMPOSER *************/
	
	// If we were to load the composition from the application's resources into the QCView of the about window...
	[aboutView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"AboutBox" ofType:@"qtz"]];
   NSString	*value;
   
   value = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
   if (value != nil)
   {
      value = [@"Version " stringByAppendingString : value];
   }
	// Set the parameters of the composition played by the QCView in the about window
	[aboutView setValue:PROGRAM_NAME forInputKey:@"ProgramName"];
	[aboutView setValue:value forInputKey:@"Version"];
	[aboutView setValue:@"Programming:\n\nRob Boyer" forInputKey:@"ProgrammingBy"];
	[aboutView setValue:@"Interface Design:\n\nRob Boyer\nChris Konovaliv" forInputKey:@"InterfaceBy"];
	[aboutView setValue:@"Testing:\n\nChris Konovaliv\nMichael Gould\nByron Sheppard\nRon Goodman\nScott Ruda\nKevin Ohler" forInputKey:@"TestingBy"];
	[aboutView setValue:@"Maps courtesy of Microsoft\nGPS I/O courtesy of GPSBabel" forInputKey:@"MapsBy"];
	[aboutView setValue:@"Special thanks to:\n\nAndy Matuschak for Sparkle\n(http://andymatuschak.org/)\nMatt Gemmell for HUDWindow\n(http://mattgemmell.com/)\nThe Omni Group for OmniFoundation" forInputKey:@"ThanksTo"];
   [[aboutView window] center];
	//[qcView setValue:[NSApp applicationIconImage] forInputKey:@"Image"];
	//[qcView setValue:[NSColor redColor] forInputKey:@"Color"];
	
   /************* END QUARTZ COMPOSER **************/
   
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(afterSplashPanelDone:)
                                                name:@"AfterSplashPanelDone"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(afterDocOpened:)
                                                name:@"AfterDocOpened"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(showActivityDetail:)
                                                name:@"OpenActivityDetail"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(showDetailedMap:)
                                                name:@"OpenMapDetail"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(showActivityDataList:)
                                                name:@"OpenDataDetail"
                                              object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(transportPanelClosed:)
                                                name:@"TransportPanelClosed"
                                              object:nil];
   
   
   [[SplashPanelController sharedInstance] showPanel];
   [[SplashPanelController sharedInstance] updateProgress:@"initializing..."];
   initialDocument = nil;
   if ([[[NSDocumentController sharedDocumentController] documents]  count]==0)
   {
      fileURLData=[[NSUserDefaults standardUserDefaults]  objectForKey:@"lastFileURL"];
      [fileURLData retain];
      if (fileURLData)
      {
         [[SplashPanelController sharedInstance] updateProgress:@"loading activity data..."];
         [NSThread detachNewThreadSelector:@selector(openLastDoc:) toTarget:self withObject:nil];
      }
      else
      {
         [[SplashPanelController sharedInstance] canDismiss:YES];
      }
   }
   else
   {
      [[SplashPanelController sharedInstance] canDismiss:YES];
   }
   
   gSUUpdater = suUpdater;
   
   NSString* title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field", 
      [Utils stringFromDefaults:RCBDefaultKeyword1Label],
      [Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
   [copyKeyword1MenuItem setTitle:title];
   
   title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field", 
      [Utils stringFromDefaults:RCBDefaultKeyword2Label],
      [Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
   [copyKeyword2MenuItem setTitle:title];
   
}


- (void)afterSplashPanelDone:(NSNotification *)notification
{
   BOOL ok = [RegController CHECK_REGISTRATION];
   if (!ok)
   {
      RegController* rc = [[RegController alloc] init];
      [[rc window] center];
      [rc showWindow:self];
      [NSApp runModalForWindow:[rc window]];
      [[rc window] orderOut:self];
      [rc release];
   }
   if ([Utils boolFromDefaults:RCBDefaultShowTransportPanel]) 
   {
      [self showTransportPanel:self];
   }
   
   if (initialDocument != nil)
   {
      [initialDocument makeWindowControllers];
      [initialDocument showWindows];
      [initialDocument updateChangeCount:NSChangeCleared];
   }
   
   [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(selectionDoubleClickedInOutlineView:)
                                             name:@"TBSelectionDoubleClicked"
                                           object:nil];
   
   if ([Utils boolFromDefaults:RCBCheckForUpdateAtStartup])
      [suUpdater checkForUpdatesInBackground];
 }
     

- (IBAction)gotoAscentWebSite:(id)sender
{
   [[NSWorkspace sharedWorkspace] 
      openURL:[NSURL URLWithString:@"http://www.montebellosoftware.com/index.html"]];
}


- (IBAction)gotoAscentForum:(id)sender
{
   [[NSWorkspace sharedWorkspace] 
      openURL:[NSURL URLWithString:@"http://www.montebellosoftware.com/cgi-bin/forum/ikonboard.cgi?"]];
}


- (IBAction)print:(id)sender
{
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)
      [[NSDocumentController sharedDocumentController] currentDocument];
   NSArray* wcs = [tbd windowControllers];
   TBWindowController* sc = [wcs objectAtIndex:0];
   
      NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
      NSPrintOperation* printOp;
      NSView* v = [sc mapPathView];
      printOp = [NSPrintOperation printOperationWithView:v 
                                               printInfo:printInfo];
      [printOp setShowPanels:YES];
      [printOp runOperation];
}
   

- (IBAction)showTransportPanel:(id)sender;
{
   BOOL shown;
   if (transportPanelController == nil)
   {
      transportPanelController = [[TransportPanelController alloc] init];
      [transportPanelController showWindow:self];
      shown = YES;
      //NSWindow* wind = [transportPanelController window];
      //NSLog(@"show transport panel, window:%@, tpc:%@", wind, transportPanelController);
   }
   else
   {
      NSWindow* wind = [transportPanelController window];
      //NSLog(@"show transport panel, window:%@, tpc:%@", wind, transportPanelController);
      if ([wind isVisible])
      {
         [wind performClose:self];
         shown = NO;
      }
      else
      {
         [transportPanelController showWindow:self];
         shown = YES;
     }
   }
   [transportPanelController connectToTimer];
   [Utils setBoolDefault:shown
                  forKey:RCBDefaultShowTransportPanel];
}




- (BOOL) validateMenuItem:(NSMenuItem*) mi
{
   if ([mi action] == @selector(showTransportPanel:))
   {
      if ([[transportPanelController window] isVisible] )
      {
         [mi setTitle:@"Hide Animation Control Panel"];
      }
      else
      {
         [mi setTitle:@"Show Animation Control Panel"];
      }
   }
   else if ([mi action] == @selector(copyKeywordToCustom:))
   {
      
      return ([[NSDocumentController sharedDocumentController] currentDocument] != nil);
   }

   return YES;
}


- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
   //NSLog(@"deleting %@", path);
}


- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
   return YES;
}


- (IBAction)clearMapCache:(id)sender
{
   NSAlert *alert = [[NSAlert alloc] init];
   [alert addButtonWithTitle:@"Clear Map Cache"];
   [alert addButtonWithTitle:@"Cancel"];
   [alert setMessageText:@"Clearing the map cache will delete all saved maps, resulting in slower performance until the same maps are retrieved again (a connection to the internet will also be required to re-fetch the maps)"];
   [alert setInformativeText:@"Continue clearing the map cache?"];
   [alert setAlertStyle:NSInformationalAlertStyle];
   if ([alert runModal] == NSAlertFirstButtonReturn) 
   {
      NSString* cacheFilePath = [Utils getMapTilesPath];
      if (cacheFilePath != nil)
      {
         NSFileManager* fm = [NSFileManager defaultManager];
         [fm removeFileAtPath:cacheFilePath handler:self];
         cacheFilePath = [Utils getMapTilesPath];     // re-create empty directory
      }
   }
   [alert release];
}


-(void) doCopyKeywordToKeyword:(int)src dest:(int)dst sourceName:(NSString*)srcName destName:(NSString*)dstName
{
   [[NSDocumentController sharedDocumentController] currentDocument];
   TrackBrowserDocument* tbd = (TrackBrowserDocument*)
      [[NSDocumentController sharedDocumentController] currentDocument];
   if (tbd)
   {
      NSUndoManager* undo = [tbd undoManager];
      if (![undo isUndoing])
      {
         NSString* s = [NSString stringWithFormat:@"Move field values from \"%@\" to \"%@\"", srcName, dstName];
         [undo setActionName:s];
      }
      [[undo prepareWithInvocationTarget:self] doCopyKeywordToKeyword:dst dest:src sourceName:dstName destName:srcName];
      NSArray* trackArray = [tbd trackArray];
      int num = [trackArray count];
      int i;
      for (i=0; i<num; i++)
      {
         Track* trk = [trackArray objectAtIndex:i];
         NSString* ss = [trk attribute:src];
         if (ss && ![ss isEqualToString:@""])
         {
            [trk setAttribute:dst
                  usingString:ss];
            [trk setAttribute:src
                  usingString:@""];
            [[tbd windowController] syncTrackToAttributesAndEditWindow:trk];
         }
      }
      [[[tbd windowController] window] setDocumentEdited:YES];
      [tbd updateChangeCount:NSChangeDone];
   }
}

   
- (IBAction)copyKeywordToCustom:(id)sender
{
   int src = kKeyword1;
   NSString* srcName = [Utils stringFromDefaults:RCBDefaultKeyword1Label];
   NSString* dstName = [Utils stringFromDefaults:RCBDefaultCustomFieldLabel];
   if (sender == copyKeyword2MenuItem) 
   {
      src = kKeyword2;
      srcName = [Utils stringFromDefaults:RCBDefaultKeyword2Label];
   }
   NSAlert *alert = [[NSAlert alloc] init];
   [alert addButtonWithTitle:@"Proceed"];
   [alert addButtonWithTitle:@"Cancel"];
   NSString* s = [NSString stringWithFormat:@"If the \"%@\" field is not blank for an activity, it will be copied to and replace any existing entry in the \"%@\" field.  The value in the \"%@\" field will then be cleared.\n\nThis operation will be applied to all activities.", 
      srcName, [Utils stringFromDefaults:RCBDefaultCustomFieldLabel], srcName ];
   [alert setMessageText:s];
   [alert setInformativeText:@"Use this feature to convert one of the custom popup fields to instead use the custom text entry field.\n"];
   [alert setAlertStyle:NSWarningAlertStyle];
   if ([alert runModal] == NSAlertFirstButtonReturn) 
   {
      [self doCopyKeywordToKeyword:src 
                              dest:kKeyword3       // "custom" text entry field is stored in kKeyword3
                        sourceName:srcName
                          destName:dstName];
   }
   [alert release];
}



@end
