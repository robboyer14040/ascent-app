#import "AppController.h"
#import "ADWindowController.h"
#import "ALWindowController.h"
#import "DMWindowController.h"
#import "SGWindowController.h"
#import "EquipmentListWindowController.h"
#import "TrackBrowserDocument.h"
#import "TBWindowController.h"
#import "Track.h"
#import "Defs.h"
#import "SplashPanelController.h"
#import "TransportPanelController.h"
#import "RegController.h"
#import "MapPathView.h"
#import <OmniAppKit/OAPreferenceClient.h>
#import <OmniAppKit/OAPreferenceClientRecord.h>
#import <OmniAppKit/OAPreferenceController.h>
#import "Utils.h"
#import <Quartz/Quartz.h>
#import <unistd.h>			// for sleep
#import <AddressBook/ABAddressBook.h>
#import <AddressBook/ABPerson.h>
///#import "RBSplitSubview.h"
#import "RBSplitView.h"
#import "SyncController.h"
#import "BackupNagController.h"
#import "EquipmentLog.h"
#import "GarminSyncWindowController.h"
#import "WeightValueTransformer.h"
#import <CoreText/CoreText.h>

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
  #import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
  #define HAVE_UTTYPE 1
#else
  #import <CoreServices/CoreServices.h>
  #define HAVE_UTTYPE 0
#endif

/// FIXME move this MakeRecord method somewhere better

static OAPreferenceClientRecord *
MakeRecord(NSString *category,
           NSString *identifier,
           NSString *className,
           NSString *title,
           NSString *shortTitle,
           NSString *iconName,   // system name or name in your bundle
           NSString *nibName,    // the nib you load in your client
           NSInteger ordering)
{
    OAPreferenceClientRecord *r = [[OAPreferenceClientRecord alloc] initWithCategoryName:category];
    r.identifier   = identifier;
    r.className    = className;               // e.g. @"GeneralPrefsClient"
    r.title        = title;
    r.shortTitle   = shortTitle;
    r.iconName     = iconName;                // e.g. NSImageNamePreferencesGeneral
    r.nibName      = nibName;                 // e.g. @"GeneralPrefs"
    r.ordering     = @(ordering);             // sort within category
    // Optional defaults (shown in your header):
    // r.defaultsArray = @[ /* OFPreference keys you want this pane to own */ ];
    // r.defaultsDictionary = @{ /* seed defaults */ };
    return r;
}

// AI generated this method
static BOOL RegisterFontsInFolder(NSURL *fontsURL) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *lsErr = nil;
    NSArray<NSURL *> *items =
        [fm contentsOfDirectoryAtURL:fontsURL
          includingPropertiesForKeys:nil
                             options:0
                               error:&lsErr];
    if (!items) {
        NSLog(@"Font dir list failed: %@", lsErr);
        return NO;
    }

    NSMutableArray<NSURL *> *fontURLs = [NSMutableArray array];

    if (@available(macOS 11.0, *)) {
        // Modern: UTType (UniformTypeIdentifiers)
        for (NSURL *url in items) {
            UTType *type = [UTType typeWithFilenameExtension:url.pathExtension];
            if (type && [type conformsToType:UTTypeFont]) {
                [fontURLs addObject:url];
            }
        }
    } else {
        // Legacy fallback (deprecated CoreServices C APIs) — gated and silenced
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (NSURL *url in items) {
            CFStringRef ext = (__bridge CFStringRef)url.pathExtension;
            if (!ext) continue;
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL);
            if (uti) {
                Boolean isFont = UTTypeConformsTo(uti, CFSTR("public.font"));
                CFRelease(uti);
                if (isFont) [fontURLs addObject:url];
            }
        }
#pragma clang diagnostic pop
    }

    if (fontURLs.count == 0) return YES; // nothing to do, but not a failure

    BOOL allOK = YES;
    for (NSURL *url in fontURLs) {
        CFErrorRef ce = NULL;
        Boolean ok = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url,
                                                      kCTFontManagerScopeProcess,
                                                      &ce);
        if (!ok) {
            allOK = NO;
            NSError *err = CFBridgingRelease(ce);
            // Optional: ignore “already registered” errors
            if (![err.domain isEqualToString:(__bridge NSString *)kCTFontManagerErrorDomain] ||
                err.code != kCTFontManagerErrorAlreadyRegistered) {
                NSLog(@"Font register failed for %@: %@", url.lastPathComponent, err);
            }
        }
    }
    return (BOOL)allOK;
}



@interface AboutBoxWC : NSWindowController <NSWindowDelegate>

@end


@interface AppController ()
- (void)afterDocOpened:(NSNotification *)notification;
@end

@implementation AppController

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

	NSString* value = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	if (value != nil)
	{
		value = [@"Version " stringByAppendingString : value];
	}
	printf("Ascent %s\n", [value UTF8String]);
	
	//NSLog(@"This machine has %u processor(s).", OFNumberOfProcessors());
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
   
	[Utils setBackupDefaults];
	
	//NSLog(@"registered default prefs: %@", defaultValues);
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSArray *types = [NSArray arrayWithObjects:TrackPBoardType, NSTabularTextPboardType, NSStringPboardType, nil];
	[pb declareTypes:types owner:self];

	
    NSString *fontsFolder = [[[NSBundle mainBundle] resourcePath]
                             stringByAppendingPathComponent:@"Fonts"];
	if (fontsFolder)
    {
		NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
		if (fontsURL) 
		{
#if 0
// ATS... is deprecated
			FSRef fsRef;
			//FSSpec fsSpec;
			(void)CFURLGetFSRef((CFURLRef)fontsURL, &fsRef);
			//OSStatus status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL,
			//								NULL, &fsSpec, NULL);
			OSStatus status = noErr;
			if (noErr == status) {
				ATSGeneration generationCount = ATSGetGeneration();
				ATSFontContainerRef container;
				//status = ATSFontActivateFromFileSpecification(&fsSpec, kATSFontContextLocal, kATSFontFormatUnspecified, NULL, kATSOptionFlagsDefault, &container);
				status = ATSFontActivateFromFileReference(&fsRef, kATSFontContextLocal, kATSFontFormatUnspecified, NULL, kATSOptionFlagsDefault, &container);
				generationCount = ATSGetGeneration() - generationCount;
				if (generationCount) {
					// NSLog(@"app - %@ added %u font file%s", @"", generationCount, 
					//      (generationCount == 1 ? "" : "s"));
					ItemCount count;
					status = ATSFontFindFromContainer (container, 
													   kATSOptionFlagsDefault, 0, NULL,&count);
					ATSFontRef *ioArray=(ATSFontRef *)malloc(count * sizeof(ATSFontRef));
					status = ATSFontFindFromContainer (container, 
													kATSOptionFlagsDefault, count, ioArray, &count);
					int i;
					for (i=0; i<count; i++)
					{
						CFStringRef fontName=NULL;
						status = ATSFontGetName (ioArray[i], kATSOptionFlagsDefault, 
										  &fontName);
						CFRelease(fontName);
						//if (fontName) f = [NSFont fontWithName:(NSString*)fontName size:24];
						// NSLog(@"added %@", (NSString*) fontName);
					}
					free(ioArray);
				}
			}
#else
            RegisterFontsInFolder(fontsURL);
//            CFArrayRef errors;
//            CTFontManagerRegisterFontsForURLs((CFArrayRef)((^{
//                NSFileManager *fileManager = [NSFileManager defaultManager];
//                NSArray *resourceURLs = [fileManager contentsOfDirectoryAtURL:fontsURL includingPropertiesForKeys:nil options:0 error:nil];
//                return [resourceURLs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL *url, NSDictionary *bindings) {
//                    CFStringRef pathExtension = (CFStringRef)[url pathExtension];
//                    NSArray *allIdentifiers = (NSArray *)UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, pathExtension, CFSTR("public.font"));
//                    if (![allIdentifiers count]) {
//                        return NO;
//                    }
//                    CFStringRef utType = (CFStringRef)[allIdentifiers lastObject];
//                    return (!CFStringHasPrefix(utType, CFSTR("dyn.")) && UTTypeConformsTo(utType, CFSTR("public.font")));
//                }]];
//            })()), kCTFontManagerScopeProcess, &errors);
#endif
            
		}
	}
    
	WeightValueTransformer *tf;
	
	// create an autoreleased instance of our value transformer
	tf = [[[WeightValueTransformer alloc] init] autorelease];
	
	// register it with the name that we refer to it with
	[NSValueTransformer setValueTransformer:tf
									forName:@"WeightValueTransformer"];
	
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
	[syncController release];
	[super dealloc];
}

- (void)didCloseAllFunc:(NSDocumentController *)docController  didCloseAll: (BOOL)didCloseAll contextInfo:(void *)contextInfo
{
   //volatile int f = 42;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	NSError* error;
	[[[EquipmentLog sharedInstance] managedObjectContext] save:&error];
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
	NSError* error;
	NSURL* url = [[[NSURL alloc] initFileURLWithPath:filename] autorelease];
	doc = [dc openDocumentWithContentsOfURL:url 
									display:YES
									  error:&error];
	[[[NSUserDefaultsController sharedUserDefaultsController] values]  setValue:[NSArchiver archivedDataWithRootObject:url] 
																		 forKey:@"lastFileURL"];
#ifdef DEBUG
	NSLog(@"opened file %@, lastFileURL:%@\n", filename, url);
#endif
	return ( doc != nil);
}



#if 0// AppDelegate.m
- (IBAction)openTheDocument:(id)sender {
    NSLog(@"DocTypes = %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"]);
    [[NSDocumentController sharedDocumentController] openDocument:sender];
}
#endif


- (IBAction)openTheDocument:(id)sender
{
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;

    // Build allowed types from your Info.plist (CFBundleDocumentTypes)

    NSMutableArray<UTType *> *contentTypes = [NSMutableArray array];
    NSArray *docTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];

    for (NSDictionary *t in docTypes) {
        BOOL added = NO;

        // 1) Try declared UTIs
        for (NSString *uti in (t[@"LSItemContentTypes"] ?: @[])) {
            if (UTType *u = [UTType typeWithIdentifier:uti]) {
                [contentTypes addObject:u]; added = YES;
            }
        }

        // 2) Fallback: map declared extensions -> UTType
        if (!added) {
            for (NSString *ext in (t[@"CFBundleTypeExtensions"] ?: @[])) {
                if (UTType *u = [UTType typeWithFilenameExtension:ext]) {
                    [contentTypes addObject:u]; added = YES;
                }
            }
        }

        // 3) Last-ditch: create a dynamic type from the extension, conforming to data
        if (@available(macOS 11.0, *)) {
            if (!added) {
                for (NSString *ext in (t[@"CFBundleTypeExtensions"] ?: @[])) {
                    if (UTType *u = [UTType typeWithTag:UTTagClassFilenameExtension
                                                  value:ext
                                           conformingTo:UTTypeData]) {
                        [contentTypes addObject:u];
                    }
                }
            }
        }
    }
    panel.allowedContentTypes = [NSOrderedSet orderedSetWithArray:contentTypes].array;
    if (contentTypes.count > 0) {
        panel.allowedContentTypes = contentTypes; // NSOpenPanel API
    }
    // else leave unfiltered; user can still pick anything your app can open

    NSWindow *host = NSApp.mainWindow ?: NSApp.keyWindow;
    void (^openURL)(NSURL *) = ^(NSURL *url) {
        [dc openDocumentWithContentsOfURL:url
                                  display:YES
                        completionHandler:^(NSDocument * _Nullable doc,
                                            BOOL documentWasAlreadyOpen,
                                            NSError * _Nullable error)
        {
            if (error) { [NSApp presentError:error]; return; }
            // NSDocumentController records recents automatically on success.
            // (Optional belt-and-suspenders:)
            NSLog(@"max recents = %ld",
                  (long)[NSDocumentController sharedDocumentController].maximumRecentDocumentCount);
            NSLog(@"bundle id = %@", [[NSBundle mainBundle] bundleIdentifier]);
            if (doc.fileURL) [dc noteNewRecentDocumentURL:doc.fileURL];
        }];
    };

    if (host) {
        [panel beginSheetModalForWindow:host completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK && panel.URL) openURL(panel.URL);
        }];
    } else {
        if ([panel runModal] == NSModalResponseOK && panel.URL) openURL(panel.URL);
    }
}


- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *) sender
{
   if ([[NSUserDefaults standardUserDefaults]  objectForKey:@"lastFileURL"])
      return NO;
	sleep(2);
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

-(IBAction)saveADocument:(id)sender
{
    
    
}


-(IBAction)showAboutBox:(id)sender
{
#if 0
    /************ BEGIN QUARTZ COMPOSER *************/
    NSRect fr = [aboutContentView bounds];
    QCView* aboutView = [[QCView alloc] initWithFrame:fr];
    [aboutContentView addSubview:aboutView];
    [aboutView release];
    // If we were to load the composition from the application's resources into the QCView of the about window...
    [aboutView loadCompositionFromFile:[[NSBundle mainBundle]
                                        pathForResource:@"AboutBox"
                                        ofType:@"qtz"]];
    [aboutView setEraseColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0]];
    [aboutView setAutostartsRendering:YES];
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
    [aboutView setValue:@"Testing:\n\nRon Goodman\nMichael Gould\nChris Konovaliv\nKevin Ohler\nRick Oshlo\nScott Ruda\nByron Sheppard\nBob Wagner" forInputKey:@"TestingBy"];
    [aboutView setValue:@"Maps courtesy of Microsoft\nGPS I/O courtesy of GPSBabel" forInputKey:@"MapsBy"];
    [aboutView setValue:@"Special thanks to:\n\nAndy Matuschak for Sparkle\n(http://andymatuschak.org/)\nMatt Gemmell for HUDWindow\n(http://mattgemmell.com)\nRBSplitView by Rainer Brokerhoff\n(http://www.brokerhoff.net)\nThe Omni Group for OmniFoundation\nLos Gatos Bicycle Racing Club (LGBRC)" forInputKey:@"ThanksTo"];
    [[aboutView window] center];
    //[qcView setValue:[NSApp applicationIconImage] forInputKey:@"Image"];
    //[qcView setValue:[NSColor redColor] forInputKey:@"Color"];
    
    /************* END QUARTZ COMPOSER **************/
    ///[[aboutView window] makeKeyAndOrderFront:aboutView];
    
    
    //./[aboutPanel makeKeyAndOrderFront:self];
    AboutBoxWC* abc = [[AboutBoxWC alloc] initWithWindow:aboutPanel];
    [aboutPanel setDelegate:abc];
    [NSApp runModalForWindow:aboutPanel];
    [aboutPanel orderOut:self];
    [aboutView unloadComposition];
    [aboutView removeFromSuperview];	// should release/free aboutView here
    [abc release];
#endif
}



-(IBAction)showDetailedMap:(id)sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    TBWindowController* sc = [tbd windowController];
    [sc showMapDetail:sender];
}


-(IBAction)showSummaryGraph:(id)sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    TBWindowController* sc = [tbd windowController];
    [sc showSummaryGraph:sender];
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
		NSString* title = @"Activity Data - ";
		title = [title stringByAppendingString:name];
		NSString* format = @"%A, %B %d  %I:%M%p";
		if ([name length] != 0)
		{
			format = @"  (%A, %B %d  %I:%M%p)";
		}
		NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
		title = [title stringByAppendingString:[ct descriptionWithCalendarFormat:format
																	  timeZone:tz
																		locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
		[wind setTitle:title];
		[alWindowController showWindow:self];
	}
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
        {
           TrackBrowserDocument* tbd = (TrackBrowserDocument*)[[NSDocumentController sharedDocumentController] currentDocument];
           TBWindowController* wc = [tbd windowController];
           [wc showMapDetail:self];
        }
        break;
        
        case 2:
            [self showActivityDataList:self];
            break;
    }
}



-(void) openLastDoc:(id)junk
{
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
   //sleep(1);
   //[[NSNotificationCenter defaultCenter] postNotificationName:@"AfterDocOpened" object:self];
#if 1
	// do open on the main thread, otherwise drag/drop operations don't seem
	// to work correctly.  Don't know why.
	[self performSelectorOnMainThread:@selector(afterDocOpened:) 
						   withObject:nil 
						waitUntilDone:NO];
#else
	[self afterDocOpened:nil];
#endif
   [pool release];
}   


- (void)afterDocOpened:(NSNotification *)notification
{
	NSError *error;
	if (/*([notification object] == self) && */(fileURLData != nil))
	{
	   @try
	   {
			NSURL *fileURL = [NSUnarchiver unarchiveObjectWithData:  fileURLData];
			[fileURLData autorelease];
			fileURLData = nil;
#ifdef _DEBUG
		   NSLog(@"OPENING LAST FILE...");
#endif
           // NEW (async, preferred)
           [[NSDocumentController sharedDocumentController]
               openDocumentWithContentsOfURL:fileURL
                                     display:YES
                           completionHandler:^(NSDocument *doc,
                                               BOOL documentWasAlreadyOpen,
                                               NSError *error)
           {
               if (error) {
                   // present the error
                   [[NSApplication sharedApplication] presentError:error];
                   return;
               }
               // success: doc is opened; do any post-open work here
           }];
#ifdef _DEBUG
		   NSLog(@"DONE");
#endif
		   if (initialDocument != nil)
		   {
			   [initialDocument makeWindowControllers];
			   [initialDocument showWindows];
			   [initialDocument updateChangeCount:NSChangeCleared];
		   }

	   }
	   @catch(NSException *exception)
	   {
		   NSLog(@"exception:%@", exception);
	   }
	   @finally
	   {
	   }
	}
	
	[[SplashPanelController sharedInstance] canDismiss:YES];
	[[SplashPanelController sharedInstance] updateProgress:@"data loaded"];
	[[SplashPanelController sharedInstance] performSelectorOnMainThread:@selector(startFade:)
															 withObject:nil 
														  waitUntilDone:NO];
	
}


- (void)transportPanelClosed:(NSNotification *)notification
{
   //[transportPanelController release];
   //transportPanelController = nil;
}


- (void)applicationWillResignActive:(NSNotification *)aNotification
{
	[syncController setDocument:[self currentTrackBrowserDocument]];
}


- (void)applicationDidUpdate:(NSNotification *)aNotification
{
	//printf("did update! %x\n", [self currentTrackBrowserDocument]);
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[[SplashPanelController sharedInstance] showPanel];
	[[SplashPanelController sharedInstance] updateProgress:@"initializing..."];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [NSDocumentController sharedDocumentController];
    

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
											 selector:@selector(showSummaryGraph:)
												 name:@"OpenSummaryGraph"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(transportPanelClosed:)
												name:@"TransportPanelClosed"
											  object:nil];


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
			[[SplashPanelController sharedInstance] startFade:nil];
		}
	}
	else
	{
		[[SplashPanelController sharedInstance] canDismiss:YES];
		[[SplashPanelController sharedInstance] startFade:nil];
	}

	NSString* title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field",
                       [Utils stringFromDefaults:RCBDefaultKeyword1Label],
                       [Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
	[copyKeyword1MenuItem setTitle:title];

	title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field", 
	[Utils stringFromDefaults:RCBDefaultKeyword2Label],
	[Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
	[copyKeyword2MenuItem setTitle:title];
	[Utils createPowerActivityArrayIfDoesntExist];

//	syncController = [[SyncController alloc] initWithAppController:self];
//	BOOL wifiEnabled = [Utils boolFromDefaults:RCBDefaultEnableWiFiSync];
//	if (wifiEnabled)
//	{
//		[syncController startAdvertising];
//		NSLog(@"Running as sync server...");		
//	}
}


- (void)afterSplashPanelDone:(NSNotification *)notification
{
    ///BOOL ok = [RegController CHECK_REGISTRATION];
    BOOL ok = YES;
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
    TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
    if (tbd)
    {
        NSArray* wcs = [tbd windowControllers];
        if (wcs)
        {
            TBWindowController* sc = [wcs objectAtIndex:0];
            if (sc) [[sc window] makeKeyAndOrderFront:nil];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDoubleClickedInOutlineView:)
                                                 name:@"TBSelectionDoubleClicked"
                                               object:nil];
    
    // update the user's birthday and age...
    NSDate* birthDate = [Utils objectFromDefaults:RCBDefaultBirthday];
    if (!birthDate)
    {
        ABPerson* curPerson = [[ABAddressBook sharedAddressBook] me];
        if (curPerson)
        {
            birthDate = [curPerson valueForProperty:kABBirthdayProperty];
            if (birthDate)
            {
                [Utils setObjectDefault:birthDate forKey:RCBDefaultBirthday];
            }
        }
    }
    if (!birthDate)
    {
        birthDate = [NSDate dateWithString:@"1980-01-01 10:00:00 +0600"];
        [Utils setObjectDefault:birthDate forKey:RCBDefaultBirthday];
    }
    int age = [Utils calculateAge:birthDate];
    [Utils setIntDefault:age forKey:RCBDefaultAge];
    
#if 0
    NSLog(@"UPDATER IS BROKEN");
    // FIXME if ([Utils boolFromDefaults:RCBCheckForUpdateAtStartup])
    //	[suUpdater checkForUpdatesInBackground];
    
    if (ok)
    {
        BOOL nag = [Utils boolFromDefaults:RCBDefaultShowBackupNagDialog];
        if (nag)
        {
            BackupNagController* bnc = [[BackupNagController alloc] init];
            [[bnc window] center];
            [NSApp runModalForWindow:[bnc window]];
            [[bnc window] orderOut:self];
            [bnc release];
        }
    }
#endif
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

- (TrackBrowserDocument*) currentTrackBrowserDocument
{
	return  (TrackBrowserDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
}

- (IBAction)print:(id)sender
{
	TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
	NSArray* wcs = [tbd windowControllers];
	TBWindowController* sc = [wcs objectAtIndex:0];
   
	NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
	NSPrintOperation* printOp;
	NSView* v = [sc mapPathView];
	printOp = [NSPrintOperation printOperationWithView:v 
										   printInfo:printInfo];
	[printOp setShowsPrintPanel:YES];
	[printOp runOperation];
}
   
-(IBAction) gotoPreferences:(id)sender
{
    [[OAPreferenceController sharedPreferenceController] showPreferencesPanel:nil];
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


- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
 copyingItemAtURL:(NSURL *)srcURL
             toURL:(NSURL *)dstURL
{
    NSLog(@"Copy error %@ → %@: %@", srcURL, dstURL, error);
    // return YES to keep going, NO to abort the operation
    return YES;
}

// Move
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
  movingItemAtURL:(NSURL *)srcURL
            toURL:(NSURL *)dstURL
{
    NSLog(@"Move error %@ → %@: %@", srcURL, dstURL, error);
    return YES;
}

// Remove
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
 removingItemAtURL:(NSURL *)url
{
    NSLog(@"Remove error %@: %@", url, error);
    return YES;
}

// Link (if you use it)
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
  linkingItemAtURL:(NSURL *)srcURL
             toURL:(NSURL *)dstURL
{
    NSLog(@"Link error %@ → %@: %@", srcURL, dstURL, error);
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
            NSError* error;
            [fm removeItemAtPath:cacheFilePath 
                           error:&error];
            cacheFilePath = [Utils getMapTilesPath];     // re-create empty directory
        }
    }
    [alert release];
}


-(void) doCopyKeywordToKeyword:(int)src dest:(int)dst sourceName:(NSString*)srcName destName:(NSString*)dstName
{
  	TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
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


@implementation AboutBoxWC

- (void)windowWillClose:(NSNotification *)aNotification
{
    [NSApp stopModal];
}



@end

