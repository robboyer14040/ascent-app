//
//  AppController.m
//  Ascent
//

#import "AppController.h"
#import "ADWindowController.h"
#import "ALWindowController.h"
#import "DMWindowController.h"
#import "SGWindowController.h"
#import "EquipmentListWindowController.h"
#import "TrackBrowserDocument.h"
#import "MainWindowController.h"
#import "Track.h"
#import "Defs.h"
#import "SplashPanelController.h"
#import "TransportPanelController.h"
#import "RegController.h"
#import "MapPathView.h"
#import "StravaAPI.h"
#import <OmniAppKit/OAPreferenceClient.h>
#import <OmniAppKit/OAPreferenceClientRecord.h>
#import <OmniAppKit/OAPreferenceController.h>
#import "Utils.h"
#import <Quartz/Quartz.h>
#import <unistd.h>
#import <AddressBook/ABAddressBook.h>
#import <AddressBook/ABPerson.h>
#import "RBSplitView.h"
#import "SyncController.h"
#import "BackupNagController.h"
#import "EquipmentLog.h"
#import "GarminSyncWindowController.h"
#import "WeightValueTransformer.h"
#import <CoreText/CoreText.h>
#import "AscentDocumentController.h"

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
  #import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
  #define HAVE_UTTYPE 1
#else
  #import <CoreServices/CoreServices.h>
  #define HAVE_UTTYPE 0
#endif

// MARK: - Helpers / Records
static NSMutableArray<NSURL *> *gLaunchOpenURLs = nil;

static OAPreferenceClientRecord *
MakeRecord(NSString *category,
           NSString *identifier,
           NSString *className,
           NSString *title,
           NSString *shortTitle,
           NSString *iconName,
           NSString *nibName,
           NSInteger ordering)
{
    OAPreferenceClientRecord *r = [[OAPreferenceClientRecord alloc] initWithCategoryName:category];
    r.identifier   = identifier;
    r.className    = className;
    r.title        = title;
    r.shortTitle   = shortTitle;
    r.iconName     = iconName;
    r.nibName      = nibName;
    r.ordering     = @(ordering);
    return r;
}

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

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
    for (NSURL *url in items) {
        UTType *type = [UTType typeWithFilenameExtension:url.pathExtension];
        if (type && [type conformsToType:UTTypeFont]) [fontURLs addObject:url];
    }
#else
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
#endif

    if (fontURLs.count == 0) return YES;

    BOOL allOK = YES;
    for (NSURL *url in fontURLs) {
        CFErrorRef ce = NULL;
        Boolean ok = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url,
                                                      kCTFontManagerScopeProcess,
                                                      &ce);
        if (!ok) {
            allOK = NO;
            NSError *err = CFBridgingRelease(ce);
            if (![err.domain isEqualToString:(__bridge NSString *)kCTFontManagerErrorDomain] ||
                err.code != kCTFontManagerErrorAlreadyRegistered) {
                NSLog(@"Font register failed for %@: %@", url.lastPathComponent, err);
            }
        }
    }
    return (BOOL)allOK;
}

// MARK: - Private interface

static NSString * const kLastDocBookmarkKey = @"AscentLastOpenedDocBookmark";

@interface AboutBoxWC : NSWindowController <NSWindowDelegate>
@end

@interface AppController ()
//@property(nonatomic, assign) BOOL deferringOpens;
//@property(nonatomic, retain) NSMutableArray<NSURL *> *pendingOpenURLs;

// Bookmarks for last-opened document
- (void)rememberLastOpenedDocumentURL:(NSURL *)url;
- (void)forgetLastOpenedDocumentURL;
- (NSURL *)restoreLastOpenedDocumentURL;

// Launch flow
- (void)_startLaunchWork; // main-thread only
@end

@implementation AppController


// MARK: Defaults / Utilities

static void setColorDefault(NSMutableDictionary* dict,
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

+ (void)initialize
{
    if (self != [AppController class]) return;
    
    NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];
    
    NSString* value = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (value) value = [@"Version " stringByAppendingString:value];
    if (value) printf("Ascent %s\n", [value UTF8String]);
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    [Utils setBackupDefaults];
    
    // Register pasteboard types once
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObjects:TrackPBoardType, NSTabularTextPboardType, NSStringPboardType, nil];
    [pb declareTypes:types owner:self];
    
    // Register bundled fonts
    NSString *fontsFolder = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Fonts"];
    if (fontsFolder) {
        NSURL *fontsURL = [NSURL fileURLWithPath:fontsFolder];
        if (fontsURL) (void)RegisterFontsInFolder(fontsURL);
    }
    
    // Value transformer
    WeightValueTransformer *tf = [[[WeightValueTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:tf forName:@"WeightValueTransformer"];
}

- (id)init
{
    if ((self = [super init])) {
        transportPanelController = nil;
        initialDocument = nil;
        _deferringOpens = NO;
        _pendingOpenURLs = nil;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [transportPanelController release];
    [syncController release];
    [_pendingOpenURLs release];
    [super dealloc];
}

// MARK: App termination

- (void)applicationWillTerminate:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSError* error = nil;
    [[[EquipmentLog sharedInstance] managedObjectContext] save:&error];
    
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    [dc closeAllDocumentsWithDelegate:self
                  didCloseAllSelector:@selector(didCloseAllFunc:didCloseAll:contextInfo:)
                          contextInfo:NULL];
}

- (void)didCloseAllFunc:(NSDocumentController *)dc didCloseAll:(BOOL)didCloseAll contextInfo:(void *)ctx
{
    (void)dc; (void)didCloseAll; (void)ctx;
}

// MARK: URL handling (Strava callback)

- (void)application:(NSApplication *)app openURLs:(NSArray<NSURL *> *)urls
{
    for (NSURL *url in urls) {
        if ([[url.scheme lowercaseString] isEqualToString:@"ascent"]) {
            NSError *err = nil;
            BOOL ok = [[StravaAPI shared] handleCallbackURL:url error:&err];
            if (!ok) NSLog(@"Strava callback error: %@", err);
            break;
        }
    }
}

// MARK: Open-file deferral

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
    //    if (!self.pendingOpenURLs) self.pendingOpenURLs = [[NSMutableArray alloc] init];
    //    NSURL *u = [NSURL fileURLWithPath:filename];
    //    if (u) [self.pendingOpenURLs addObject:u];
    // Do NOT open it yet; we’ll open after splash
    return YES; // tell AppKit we handled it
}

- (void)application:(NSApplication *)app openFiles:(NSArray<NSString *> *)filenames
{
    //    if (!self.pendingOpenURLs) self.pendingOpenURLs = [[NSMutableArray alloc] init];
    //    for (NSString *p in filenames) {
    //        NSURL *u = [NSURL fileURLWithPath:p];
    //        if (u) [self.pendingOpenURLs addObject:u];
    //    }
    // Do NOT open now
    [app replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}


// Guard untitled opens while splash is up.
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (BOOL)applicationShouldRestoreWindows:(NSApplication *)app {
    return NO; // prevent macOS from auto-reopening last docs at launch
}


- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
    if (self.deferringOpens) return NO;
    [[NSDocumentController sharedDocumentController] newDocument:self];
    return YES;
}

// MARK: UI Hooks

- (IBAction)openTheDocument:(id)sender
{
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    
#if HAVE_UTTYPE
    NSMutableArray<UTType *> *contentTypes = [NSMutableArray array];
    NSArray *docTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
    for (NSDictionary *t in docTypes) {
        BOOL added = NO;
        for (NSString *uti in (t[@"LSItemContentTypes"] ?: @[])) {
            UTType *u = [UTType typeWithIdentifier:uti];
            if (u) { [contentTypes addObject:u]; added = YES; }
        }
        if (!added) {
            for (NSString *ext in (t[@"CFBundleTypeExtensions"] ?: @[])) {
                UTType *u = [UTType typeWithFilenameExtension:ext];
                if (u) { [contentTypes addObject:u]; added = YES; }
            }
        }
        if (@available(macOS 11.0, *)) {
            if (!added) {
                for (NSString *ext in (t[@"CFBundleTypeExtensions"] ?: @[])) {
                    UTType *u = [UTType typeWithTag:UTTagClassFilenameExtension value:ext conformingTo:UTTypeData];
                    if (u) [contentTypes addObject:u];
                }
            }
        }
    }
    if (contentTypes.count > 0) panel.allowedContentTypes = contentTypes;
#endif
    
    NSWindow *host = NSApp.mainWindow ?: NSApp.keyWindow;
    void (^openURL)(NSURL *) = ^(NSURL *url) {
        [dc openDocumentWithContentsOfURL:url
                                  display:YES
                        completionHandler:^(NSDocument *doc, BOOL alreadyOpen, NSError *error)
         {
            if (error) { [NSApp presentError:error]; return; }
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

// MARK: Launch sequence with splash


- (void)applicationWillFinishLaunching:(NSNotification *)note
{
    // Ensure nib is loaded very early
    (void)[SplashPanelController sharedInstance].window;
    
    self.deferringOpens = YES;
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
}


- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    SplashPanelController *sp = [SplashPanelController sharedInstance];
    [sp showPanelCenteredOnMainScreenWithHighLevel:YES];
    
    // Ensure app is active and the splash is actually ordered in
    [NSApp activateIgnoringOtherApps:YES];
    [sp.window makeKeyAndOrderFront:nil];     // now allowed (SplashKeyWindow)
    [sp.window orderFrontRegardless];
    [sp.window displayIfNeeded];              // draw immediately
    
    [CATransaction flush];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0]];
    
    // Turn 1: allow Core Animation / window-server to commit the splash
    dispatch_async(dispatch_get_main_queue(), ^{
        // Turn 2: now kick off deferred opens
        AscentDocumentController *dc =
        (AscentDocumentController *)[NSDocumentController sharedDocumentController];
        
        [dc drainDeferredOpensWithCompletion:^{
            self.deferringOpens = NO;        // <-- IMPORTANT
            // fade/close splash when your docs are up
            [sp startFade:nil];
            [self afterSplashPanelDone:nil];
            [self _startLaunchWork];
        }];
    });
}


- (void)_startLaunchWork
{
    // All AppKit calls here are on main
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    (void)[NSDocumentController sharedDocumentController];
    
    // Notifications you need during/after launch
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(afterSplashPanelDone:) name:@"AfterSplashPanelDone" object:nil];
    [nc addObserver:self selector:@selector(showActivityDetail:) name:@"OpenActivityDetail" object:nil];
    [nc addObserver:self selector:@selector(showDetailedMap:) name:@"OpenMapDetail" object:nil];
    [nc addObserver:self selector:@selector(showActivityDataList:) name:@"OpenDataDetail" object:nil];
    [nc addObserver:self selector:@selector(showSummaryGraph:) name:@"OpenSummaryGraph" object:nil];
    ///[nc addObserver:self selector:@selector(transportPanelClosed:) name:@"TransportPanelClosed" object:nil];
    
    initialDocument = nil;
    
    NSString* title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field",
                       [Utils stringFromDefaults:RCBDefaultKeyword1Label],
                       [Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
    [copyKeyword1MenuItem setTitle:title];
    
    title = [NSString stringWithFormat:@"Move \"%@\" values to \"%@\" field",
             [Utils stringFromDefaults:RCBDefaultKeyword2Label],
             [Utils stringFromDefaults:RCBDefaultCustomFieldLabel]];
    [copyKeyword2MenuItem setTitle:title];
    
    [Utils createPowerActivityArrayIfDoesntExist];
}


// MARK: Post-splash


- (void)afterSplashPanelDone:(NSNotification *)notification
{
    BOOL ok = YES; // (registration check omitted)
    
    if (!ok) {
        RegController* rc = [[RegController alloc] init];
        [[rc window] center];
        [rc showWindow:self];
        [NSApp runModalForWindow:[rc window]];
        [[rc window] orderOut:self];
        [rc release];
    }
    
    if ([Utils boolFromDefaults:RCBDefaultShowTransportPanel]) {
        [self showTransportPanel:self];
    }
    
    TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
    if (tbd) {
        NSArray* wcs = [tbd windowControllers];
        if (wcs.count > 0) {
            MainWindowController* sc = [wcs objectAtIndex:0];
            if (sc) [[sc window] makeKeyAndOrderFront:nil];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDoubleClickedInOutlineView:)
                                                 name:@"TBSelectionDoubleClicked"
                                               object:nil];
    
    // Birthday / age update (legacy AddressBook)
    NSDate* birthDate = [Utils objectFromDefaults:RCBDefaultBirthday];
    if (!birthDate) {
        ABPerson* curPerson = [[ABAddressBook sharedAddressBook] me];
        if (curPerson) {
            birthDate = [curPerson valueForProperty:kABBirthdayProperty];
            if (birthDate) [Utils setObjectDefault:birthDate forKey:RCBDefaultBirthday];
        }
    }
    if (!birthDate) {
        birthDate = [NSDate dateWithString:@"1980-01-01 10:00:00 +0600"];
        [Utils setObjectDefault:birthDate forKey:RCBDefaultBirthday];
    }
    int age = [Utils calculateAge:birthDate];
    [Utils setIntDefault:age forKey:RCBDefaultAge];
    
    // (Updater / backup nag omitted)
}

// MARK: Misc UI commands

-(IBAction)showDetailedMap:(id)sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    MainWindowController* sc = [tbd windowController];
    [sc showMapDetail:sender];
}

-(IBAction)showSummaryGraph:(id)sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    MainWindowController* sc = [tbd windowController];
    [sc showSummaryGraph:sender];
}

- (IBAction) showActivityDetail:(id) sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    MainWindowController* sc = [tbd windowController];
    [sc stopAnimations];
    Track* track = [tbd currentlySelectedTrack];
    if (track) {
        Lap* lap = [tbd selectedLap];
        ADWindowController* ad = [[ADWindowController alloc] initWithDocument:tbd];
        [tbd addWindowController:ad];
        [ad autorelease];
        [ad showWindow:self];
        [ad setTrack:track];
        [ad setLap:lap];
    }
}

- (IBAction) showActivityDataList:(id) sender
{
    TrackBrowserDocument* tbd = (TrackBrowserDocument*)
    [[NSDocumentController sharedDocumentController] currentDocument];
    MainWindowController* sc = [tbd windowController];
    [sc stopAnimations];
    Track* track = [tbd currentlySelectedTrack];
    if (track) {
        ALWindowController* al = [[ALWindowController alloc] initWithDocument:tbd];
        [tbd addWindowController:al];
        [al autorelease];
        NSWindow* wind = [al window]; (void)wind;
        
        [al setTrack:track];
        
        NSDate* ct = [track creationTime];
        NSString* name = [track attribute:kName] ?: @"";
        NSString* title = @"Activity Data - ";
        title = [title stringByAppendingString:name];
        
        NSString* format = @"%A, %B %d  %I:%M%p";
        if (name.length != 0) format = @"  (%A, %B %d  %I:%M%p)";
        
        NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        title = [title stringByAppendingString:
                 [ct descriptionWithCalendarFormat:format
                                          timeZone:tz
                                            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
#pragma clang diagnostic pop
        [[al window] setTitle:title];
        [al showWindow:self];
    }
}

- (void)selectionDoubleClickedInOutlineView:(NSNotification *)notification
{
    int defaultAction = [Utils intFromDefaults:RCBDefaultDoubleClickAction];
    switch (defaultAction)
    {
        default:
        case 0: [self showActivityDetail:self]; break;
        case 1: {
            TrackBrowserDocument* tbd = (TrackBrowserDocument*)[[NSDocumentController sharedDocumentController] currentDocument];
            MainWindowController* wc = [tbd windowController];
            [wc showMapDetail:self];
        } break;
        case 2: [self showActivityDataList:self]; break;
    }
}

- (TrackBrowserDocument*) currentTrackBrowserDocument
{
    return (TrackBrowserDocument*)[[NSDocumentController sharedDocumentController] currentDocument];
}

- (IBAction)print:(id)sender
{
    TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
    NSArray* wcs = [tbd windowControllers];
    MainWindowController* sc = [wcs objectAtIndex:0];
    
    NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
    NSView* v = [sc mapPathView];
    NSPrintOperation* op = [NSPrintOperation printOperationWithView:v printInfo:printInfo];
    [op setShowsPrintPanel:YES];
    [op runOperation];
}

-(IBAction) gotoPreferences:(id)sender
{
    [[OAPreferenceController sharedPreferenceController] showPreferencesPanel:nil];
}

- (IBAction)showTransportPanel:(id)sender
{
    BOOL shown;
    if (transportPanelController == nil)
    {
        transportPanelController = [[TransportPanelController alloc] init];
        [transportPanelController showWindow:self];
        shown = YES;
    }
    else
    {
        NSWindow* wind = [transportPanelController window];
        if ([wind isVisible]) { [wind performClose:self]; shown = NO; }
        else { [transportPanelController showWindow:self]; shown = YES; }
    }
    [transportPanelController connectToTimer];
    [Utils setBoolDefault:shown forKey:RCBDefaultShowTransportPanel];
}

#if 0
- (BOOL) validateMenuItem:(NSMenuItem*) mi
{
    if ([mi action] == @selector(showTransportPanel:)) {
        if ([[transportPanelController window] isVisible])
            [mi setTitle:@"Hide Animation Control Panel"];
        else
            [mi setTitle:@"Show Animation Control Panel"];
    } else if ([mi action] == @selector(copyKeywordToCustom:)) {
        return ([[NSDocumentController sharedDocumentController] currentDocument] != nil);
    }
    return YES;
}
#endif


// MARK: FS operations logging (optional)

- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
   copyingItemAtURL:(NSURL *)srcURL
              toURL:(NSURL *)dstURL
{
    NSLog(@"Copy error %@ → %@: %@", srcURL, dstURL, error);
    return YES;
}

- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
    movingItemAtURL:(NSURL *)srcURL
              toURL:(NSURL *)dstURL
{
    NSLog(@"Move error %@ → %@: %@", srcURL, dstURL, error);
    return YES;
}

- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
  removingItemAtURL:(NSURL *)url
{
    NSLog(@"Remove error %@: %@", url, error);
    return YES;
}

- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
   linkingItemAtURL:(NSURL *)srcURL
              toURL:(NSURL *)dstURL
{
    NSLog(@"Link error %@ → %@: %@", srcURL, dstURL, error);
    return YES;
}

// MARK: Map cache

- (IBAction)clearMapCache:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Clear Map Cache"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Clearing the map cache will delete all saved maps, resulting in slower performance until the same maps are retrieved again (a connection to the internet will also be required to re-fetch the maps)"];
    [alert setInformativeText:@"Continue clearing the map cache?"];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        NSString* cacheFilePath = [Utils getMapTilesPath];
        if (cacheFilePath) {
            NSError* error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:cacheFilePath error:&error];
            (void)[Utils getMapTilesPath]; // recreate folder
        }
    }
    [alert release];
}

// MARK: Keyword moves (unchanged)

-(void) doCopyKeywordToKeyword:(int)src dest:(int)dst sourceName:(NSString*)srcName destName:(NSString*)dstName
{
    TrackBrowserDocument* tbd = [self currentTrackBrowserDocument];
    if (tbd)
    {
        NSUndoManager* undo = [tbd undoManager];
        if (![undo isUndoing]) {
            NSString* s = [NSString stringWithFormat:@"Move field values from \"%@\" to \"%@\"", srcName, dstName];
            [undo setActionName:s];
        }
        [[undo prepareWithInvocationTarget:self] doCopyKeywordToKeyword:dst dest:src sourceName:dstName destName:srcName];
        NSArray* trackArray = [tbd trackArray];
        for (Track* trk in trackArray) {
            NSString* ss = [trk attribute:src];
            if (ss && ![ss isEqualToString:@""]) {
                [trk setAttribute:dst usingString:ss];
                [trk setAttribute:src usingString:@""];
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
    if (sender == copyKeyword2MenuItem) {
        src = kKeyword2;
        srcName = [Utils stringFromDefaults:RCBDefaultKeyword2Label];
    }
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Proceed"];
    [alert addButtonWithTitle:@"Cancel"];
    NSString* s = [NSString stringWithFormat:
                   @"If the \"%@\" field is not blank for an activity, it will be copied to and replace any existing entry in the \"%@\" field.  The value in the \"%@\" field will then be cleared.\n\nThis operation will be applied to all activities.",
                   srcName, [Utils stringFromDefaults:RCBDefaultCustomFieldLabel], srcName ];
    [alert setMessageText:s];
    [alert setInformativeText:@"Use this feature to convert one of the custom popup fields to instead use the custom text entry field.\n"];
    [alert setAlertStyle:NSAlertStyleWarning];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self doCopyKeywordToKeyword:src dest:kKeyword3 sourceName:srcName destName:dstName];
    }
    [alert release];
}

// MARK: Website

- (IBAction)gotoAscentWebSite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.montebellosoftware.com/index.html"]];
}

- (IBAction)gotoAscentForum:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.montebellosoftware.com/cgi-bin/forum/ikonboard.cgi?"]];
}

// MARK: Last-document bookmark helpers

- (void)rememberLastOpenedDocumentURL:(NSURL *)url {
    if (!url) return;
    NSError *err = nil;
    NSData *bm = [url bookmarkDataWithOptions:0
               includingResourceValuesForKeys:nil
                                relativeToURL:nil
                                        error:&err];
    if (bm) {
        [[NSUserDefaults standardUserDefaults] setObject:bm forKey:kLastDocBookmarkKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSURL *)restoreLastOpenedDocumentURL {
    NSData *bm = [[NSUserDefaults standardUserDefaults] objectForKey:kLastDocBookmarkKey];
    if (!bm) return nil;
    
    BOOL stale = NO;
    NSError *err = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bm
                                           options:0
                                     relativeToURL:nil
                               bookmarkDataIsStale:&stale
                                             error:&err];
    if (!url) { [self forgetLastOpenedDocumentURL]; return nil; }
    
    if (![url checkResourceIsReachableAndReturnError:&err] || stale) {
        [self forgetLastOpenedDocumentURL];
        return nil;
    }
    return url;
}

- (void)forgetLastOpenedDocumentURL {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastDocBookmarkKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)menuWillOpen:(NSMenu *)menu {
    for (NSMenuItem *it in menu.itemArray) {
        SEL a = it.action;
        if (!a) continue;
        id target = [NSApp targetForAction:a to:nil from:nil];
        NSLog(@"Menu '%@' item '%@' -> action %@ -> target %@",
              menu.title, it.title, NSStringFromSelector(a), target);
    }
}

@end





@implementation AboutBoxWC
- (void)windowWillClose:(NSNotification *)aNotification
{
    [NSApp stopModal];
}
@end
