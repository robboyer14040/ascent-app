//
//  TrackPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "TrackPaneController.h"
#import "TrackListController.h"
#import "TrackCalendarController.h"
#import "Selection.h"
#import "AnimTimer.h"
#import "TrackBrowserDocument.h"
#import "Track.h"
#import "Utils.h"
#import "ProgressBarHelper.h"
#import "StravaAPI.h"
#import "StravaImporter.h"
#import "DMWindowController.h"
#import "LeftSplitController.h"

enum
{
    kCMEmailSelected,
    kCMSaveSelected,
    kCMGoogleFlyBy,
    kCMExportTCX,
    kCMExportGPX,
    kCMExportKML,
    kCMExportCSV,
    kCMExportTXT,
    kCMOpenActivityDetail,
    kCMOpenMapDetail,
    kCMOpenSummary,
    kCMOpenDataDetail,
    kCMCut,
    kCMCopy,
    kCMPaste,
    kCMAdjustGMTOffset,
    kCMAddActivity,
    kCMEditActivity,
    kCMExportSummaryCSV,
    kCMExportSummaryTXT,
    kCMAltitudeSmoothing,
    kCMPublish,
    kCMSplitActivity,
    kCMCombineActivities,
    kCMCompareActivities,
    kCMRefreshMap,
    kCMUploadToMobile,
    kCMEnrichTracks,
};


@interface TrackPaneController ()
{
    ProgressBarHelper* _pbHelper;
}
- (NSString*) _getTempPath;
- (void) _doTCXImport:(NSArray*)files showProgress:(BOOL)sp;
- (void) _doTCXImportWithoutProgress:(NSArray*)files;
- (void) _doTCXImportWithProgress:(NSArray*)files;
- (void) _doHRMImportWithProgress:(NSArray*)files;
- (void) _doFITImportWithProgress:(NSArray *)files;
- (void) _doGPXImportWithProgress:(NSArray*)files;
- (NSArray<NSString*>*) _postImportPanel:(NSArray<NSString*>*) extensions;
-(void) _buildContextualMenu;
@end

@implementation TrackPaneController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize parentSplitVC = _parentSplitVC;
@synthesize controlsBar = _controlsBar;
@synthesize outlineOptionsMenu = _outlineOptionsMenu;
@synthesize viewModeControl = _viewModeControl;
@synthesize searchField = _searchField;
@synthesize contentContainer = _contentContainer;
@synthesize calendarMode = _calendarMode;


- (void)awakeFromNib
{
    [super awakeFromNib];

    if (_controlsBar != nil) {
        _controlsBar.material = NSVisualEffectMaterialHeaderView;
        _controlsBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        _controlsBar.state = NSVisualEffectStateFollowsWindowActiveState;
    }

    _outlineVC = [[TrackListController alloc] initWithNibName:@"TrackListController" bundle:nil];
    _calendarVC = [[TrackCalendarController alloc] initWithNibName:@"TrackCalendarController" bundle:nil];

    [self injectDependencies];

    [self setCalendarMode:NO];

    if (_viewModeControl != nil) {
        [_viewModeControl setTarget:self];
        [_viewModeControl setAction:@selector(toggleViewMode:)];
    }
    
    _pbHelper = [ProgressBarHelper ProgressHelper]; // singleton
    
    int vt = [Utils intFromDefaults:RCBDefaultBrowserViewType];
    [_outlineVC setViewType:vt];
    [_outlineOptionsMenu selectItemWithTag:vt];
    
    [self _buildContextualMenu];
}


- (void)dealloc {
    [_outlineVC release];
    [_calendarVC release];
    [_selection release];
    [_parentSplitVC release];
    [super dealloc];
}



- (void) viewDidLoad {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDoubleClicked:)
                                                 name:TrackSelectionDoubleClicked
                                               object:nil];
    
   [super viewDidLoad];
}


-(void)setParentSplitVC:(LeftSplitController *)parentSplitVC
{
    if (parentSplitVC && !_parentSplitVC) {
        _parentSplitVC = [parentSplitVC retain];
        // Hook drag handle
        if (self.dragHandle) {
            self.dragHandle.delegate = _parentSplitVC;
            if (!self.dragHandle.splitView) {
                self.dragHandle.splitView = _parentSplitVC.splitView;
            }
        }
    }
}



- (IBAction)toggleViewMode:(id)sender
{
    BOOL wantCalendar = NO;
    if ([sender respondsToSelector:@selector(selectedSegment)]) {
        wantCalendar = ([(NSSegmentedControl *)sender selectedSegment] == 1);
    }
    [self setCalendarMode:wantCalendar];
}



- (IBAction)setBrowserViewMode:(id)sender
{
    NSInteger viewType = [sender tag];
    [Utils setIntDefault:(int)viewType
                  forKey:RCBDefaultBrowserViewType];
    [_outlineVC setViewType:viewType];
}


- (void)setCalendarMode:(BOOL)calendarMode
{
//    NSResponder *r = self.view.window.firstResponder;
//    while (r) { NSLog(@"-> %@", r); r = r.nextResponder; }
    
    _calendarMode = calendarMode;

    NSViewController<TrackListHandling> *target = nil;
    if (_calendarMode) {
        target = _calendarVC;
        _searchField.enabled = NO;
        _outlineOptionsMenu.enabled = NO;
    } else {
        target = _outlineVC;
        _searchField.enabled = YES;
        _outlineOptionsMenu.enabled = YES;
    }

    if (_current == target) {
        return;
    }

    if (_current != nil) {
        [[_current view] removeFromSuperview];
        [_current removeFromParentViewController];
    }

    _current = target;

    if (_current == nil) {
        return;
    }

    [self addChildViewController:_current];

    NSView *v = _current.view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentContainer addSubview:v];
    [v setNeedsDisplay:YES];
    
    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:_contentContainer.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:_contentContainer.bottomAnchor]
    ]];
}

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    if (_document) {
        [self injectDependencies];
    }
}

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];
    [self injectDependencies];
}

- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _outlineVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _calendarVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
}


- (IBAction)setSearchOptions:(id)sender
{
    if (_current == _outlineVC)
    {
        [_outlineVC setSearchOptions:sender];
    }
}


- (IBAction)setSearchCriteria:(id)sender
{
    if (_current == _outlineVC)
    {
        [_outlineVC setSearchCriteria:sender];
    }
}



- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    
    BOOL ret = YES;
    SEL action = [anItem action];
///    NSLog(@"TPC validating %@ ...", anItem);
    NSUInteger numMultiplySelected = _selection.selectedTracks.count;
    if (action == @selector(copy:)) {
        return numMultiplySelected > 0 || _selection.selectedTrack != nil;
    }
    if (action == @selector(paste:)) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        return [pb canReadItemWithDataConformingToTypes:[NSArray arrayWithObject:@"com.montebellosoftware.ascent.tracks"]];
    }
    
//    NSUInteger numSelectedTracks = (numMultiplySelected > 0 ? numMultiplySelected : (_selection.selectedTrack ? 1 : 0));
//    if ((action == @selector(exportGPX:)) ||
//        (action == @selector(exportTCX:)))
//    {
//        return numSelectedTracks > 0;
//    }
//    else if ((action == @selector(exportKML:)) ||
//             (action == @selector(exportCSV:)) ||
//             (action == @selector(exportTXT:)) ||
//             (action == @selector(splitActivity:)) ||
//             (action == @selector(showMapDetail:)) ||
//             (action == @selector(showDataDetail:)) ||
//             (action == @selector(showActivityDetail:)) ||
//             (action == @selector(googleEarthFlyBy:)) ||
//             (action == @selector(editActivity:)))
//    {
//        return numSelectedTracks == 1;
//    }
//    else if ((action == @selector(copy:)) ||
//             (action == @selector(cut:)) ||
//             (action == @selector(delete:)) ||
//             (action == @selector(getGMTOffset:)) ||
//             (action == @selector(getDistanceMethod:)) ||
//             (action == @selector(mailActivity:)) ||
//             (action == @selector(saveSelectedTracks:)) ||
//             (action == @selector(getAltitudeSmoothing:)))
//    {
//        if ([self calendarViewActive])
//        {
//            ret = [calendarView selectedTrack] != nil;
//        }
//        else
//        {
//            ret = ([trackTableView numberOfSelectedRows] > 0);
//        }
//    }
//    else if  (action == @selector(paste:))
//    {
//        return ([[NSPasteboard generalPasteboard] dataForType:TrackPBoardType] != nil);
//    }
//    else if (action == @selector(combineActivities:))
//    {
//        if ([self calendarViewActive])
//        {
//            ret = NO;
//        }
//        else
//        {
//            ret = ([trackTableView numberOfSelectedRows] > 1);
//        }
//    }
//    else if ((action == @selector(deleteLap:))  ||
//             (action == @selector(insertLapMarker:)))
//    {
//        if ([self calendarViewActive])
//        {
//            ret = NO;
//        }
//        else
//        {
//            ret = (currentlySelectedLap != nil);
//        }
//    }
//    else if ((action == @selector(zoomIn:)) ||
//             (action == @selector(zoomOut:)))
//    {
//        ret = NO;
//    }
//    else if (action == @selector(selectAll:))
//    {
//        ret = ![self calendarViewActive];
//    }
    //NSLog(@"validate ui item: %@ : %s", [(NSMenuItem*)anItem title], ret ? "YES" : "NO");
    return ret;
}

#pragma mark - Import/Export

- (NSArray<NSString*>*) _postImportPanel:(NSArray<NSString*>*) extensions
{
    [self _stopAnimations];
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (id ext in extensions) {
        UTType *ty = [UTType typeWithFilenameExtension:ext];
        if (ty)
            [types addObject:ty];
    }
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:types.count];
    if (types.count > 0)
    {
        NSOpenPanel *op = [NSOpenPanel openPanel];
        op.canChooseFiles = YES;
        op.canChooseDirectories = NO;
        op.allowsMultipleSelection = YES;
        op.allowedContentTypes = types;
        NSInteger result = [op runModal];
        if (result == NSModalResponseOK) {
            NSArray<NSURL *> *urls = [op URLs];
            NSMutableArray *paths = [NSMutableArray arrayWithCapacity:urls.count];
            for (NSURL *u in urls) {
                [paths addObject:[u path]];
            }
        }
    }
    return [NSArray arrayWithArray:paths];
}


- (IBAction)importTCX:(id)sender
{
    NSArray* paths = [self _postImportPanel:[NSArray arrayWithObjects:@"tcx", @"hst", nil]];
    if (paths && paths.count > 0)
    {
        [self _doTCXImportWithProgress:paths];
    }
    [self _stopAnimations];
}


- (IBAction)importFIT:(id)sender
{
    NSArray* paths = [self _postImportPanel:[NSArray arrayWithObject:@"fit"]];
    if (paths && paths.count > 0)
    {
        [self _doFITImportWithProgress:paths];
    }
}



- (IBAction)importHRM:(id)sender
{
    NSArray* paths = [self _postImportPanel:[NSArray arrayWithObject:@"hrm"]];
    if (paths && paths.count > 0)
    {
        [self _doHRMImportWithProgress:paths];
    }
}


- (IBAction)importGPX:(id)sender
{
    NSArray* paths = [self _postImportPanel:[NSArray arrayWithObject:@"gpx"]];
    if (paths && paths.count > 0)
    {
        [self _doGPXImportWithProgress:paths];
    }
}



-(NSString*) baseDirectoryForImportExport
{
    return [NSString stringWithFormat:@"%@/Desktop", NSHomeDirectory()];
}


- (NSString *)baseActivityFileName:(Track *)track fileType:(NSString *)ft
{
    NSDate *date = [track creationTime];
    NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];

    // Cache the formatter (NSDateFormatter is expensive; not thread-safe)
    static NSDateFormatter *fmt = nil;
    if (!fmt) {
        fmt = [[NSDateFormatter alloc] init];
        // Use a stable, file-safe month abbreviation regardless of user settings
        fmt.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
        // Your original "%d-%b-%y %H_%M."  ->  "dd-MMM-yy HH_mm"
        fmt.dateFormat = @"dd-MMM-yy HH_mm";
    }
    fmt.timeZone = tz;

    NSString *stem = [fmt stringFromDate:date];

    // Normalize extension: allow both "fit" and ".fit"
    NSString *ext = [ft hasPrefix:@"."] ? [ft substringFromIndex:1] : ft;
    return [stem stringByAppendingPathExtension:ext];
}


- (IBAction)exportKML:(id)sender
{
    [self _stopAnimations];

    NSMutableArray *arr = [_current prepareArrayOfSelectedTracks];
    if (arr.count != 1) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select a single track in the browser for export"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
        return;
    }

    NSSavePanel *sp = [NSSavePanel savePanel];
    // KML is XML-based; use a concrete KML type if the system knows it, else fall back to XML
    UTType *kmlType = [UTType typeWithFilenameExtension:@"kml"] ?: UTTypeXML;
    sp.allowedContentTypes = @[ kmlType ];
    sp.allowsOtherFileTypes = NO;
    sp.canCreateDirectories = YES;

    NSString *baseName = [self baseActivityFileName:arr.firstObject fileType:@"kml"];
    NSString *dirPath  = [self baseDirectoryForImportExport];
    if (dirPath.length) sp.directoryURL = [NSURL fileURLWithPath:dirPath];
    if (baseName.length) sp.nameFieldStringValue = baseName;

    NSWindow *win = self.view.window ?: NSApp.mainWindow ?: NSApp.keyWindow;
    void (^complete)(NSModalResponse) = ^(NSModalResponse result){
        if (result != NSModalResponseOK) return;
        NSURL *url = sp.URL;
        if (!url) return;
        [_document exportKMLFile:arr.firstObject fileName:url.path];
    };

    if (win) {
        [sp beginSheetModalForWindow:win completionHandler:complete];
    } else {
        complete([sp runModal]);
    }
}

- (IBAction)exportTCX:(id)sender
{
    [self _stopAnimations];

    NSArray *arr = [_current prepareArrayOfSelectedTracks];
    if (arr.count < 1) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select one or more tracks in the browser for export"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
        return;
    }

    NSSavePanel *sp = [NSSavePanel savePanel];
    // TCX is XML-based; use a dynamic type for "tcx" or fall back to XML
    UTType *tcxType = [UTType typeWithFilenameExtension:@"tcx"] ?: UTTypeXML;
    sp.allowedContentTypes = @[ tcxType ];
    sp.allowsOtherFileTypes = NO;
    sp.canCreateDirectories = YES;

    NSString *baseName = [self baseActivityFileName:arr.firstObject fileType:@"tcx"];
    NSString *dirPath  = [self baseDirectoryForImportExport];
    if (dirPath.length) sp.directoryURL = [NSURL fileURLWithPath:dirPath];
    if (baseName.length) sp.nameFieldStringValue = baseName;

    NSWindow *win = self.view.window ?: NSApp.mainWindow ?: NSApp.keyWindow;
    void (^complete)(NSModalResponse) = ^(NSModalResponse result){
        if (result != NSModalResponseOK) return;
        NSURL *url = sp.URL;
        if (!url) return;
        [_document exportTCXFile:arr fileName:url.path];
    };

    if (win) {
        [sp beginSheetModalForWindow:win completionHandler:complete];
    } else {
        complete([sp runModal]);
    }
}

- (void)doExportTextFile:(NSString *)suffix seperator:(char)sep
{
    [self _stopAnimations];

    NSMutableArray *arr = [_current prepareArrayOfSelectedTracks];
    if (arr.count != 1) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select a single track in the browser for export"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
        return;
    }

    NSSavePanel *sp = [NSSavePanel savePanel];

    // Choose the most appropriate UTType for the provided suffix
    UTType *t = nil;
    if ([[suffix lowercaseString] isEqualToString:@"csv"]) {
        // Prefer the dedicated CSV type when available (macOS 12+)
        t = [UTType typeWithIdentifier:@"public.comma-separated-values-text"];
        if (!t) t = UTTypeCommaSeparatedText; // if SDK provides the symbol
        if (!t) t = [UTType typeWithFilenameExtension:@"csv"];
        if (!t) t = UTTypePlainText;
    } else if ([[suffix lowercaseString] isEqualToString:@"txt"]) {
        t = UTTypePlainText;
    } else {
        t = [UTType typeWithFilenameExtension:suffix] ?: UTTypePlainText;
    }

    sp.allowedContentTypes = @[ t ];
    sp.allowsOtherFileTypes = NO;
    sp.canCreateDirectories = YES;

    NSString *baseName = [self baseActivityFileName:arr.firstObject fileType:suffix];
    NSString *dirPath  = [self baseDirectoryForImportExport];
    if (dirPath.length) sp.directoryURL = [NSURL fileURLWithPath:dirPath];
    if (baseName.length) sp.nameFieldStringValue = baseName;

    NSWindow *win = self.view.window ?: NSApp.mainWindow ?: NSApp.keyWindow;
    void (^complete)(NSModalResponse) = ^(NSModalResponse result){
        if (result != NSModalResponseOK) return;
        NSURL *url = sp.URL;
        if (!url) return;

        Track *track = arr.firstObject;
        NSString *s = [track buildTextOutput:sep];
        NSError *err = nil;
        if (![s writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
            NSLog(@"Could not write document out: %@", err.localizedDescription);
        }
    };

    if (win) {
        [sp beginSheetModalForWindow:win completionHandler:complete];
    } else {
        complete([sp runModal]);
    }
}


- (IBAction)exportGPX:(id)sender
{
    [self _stopAnimations];

    NSMutableArray *arr = [_current prepareArrayOfSelectedTracks];
    if (arr.count != 1) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select a single track in the browser for export"];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
        return;
    }

    NSSavePanel *sp = [NSSavePanel savePanel];

    // Prefer a real GPX type; fall back to XML if unknown on the system
    UTType *gpxType = [UTType typeWithFilenameExtension:@"gpx"];
    if (!gpxType) gpxType = UTTypeXML;
    sp.allowedContentTypes = @[ gpxType ];
    sp.allowsOtherFileTypes = NO;
    sp.canCreateDirectories = YES;

    // Suggest directory + filename
    NSString *baseName = [self baseActivityFileName:arr.firstObject fileType:@"gpx"];
    NSString *dirPath  = [self baseDirectoryForImportExport];
    if (dirPath.length) sp.directoryURL = [NSURL fileURLWithPath:dirPath];
    if (baseName.length) sp.nameFieldStringValue = baseName;

    // Present as a sheet from our window (we're an NSWindowController)
    NSWindow *win = self.view.window ?: NSApp.mainWindow ?: NSApp.keyWindow;

    if (win) {
        [sp beginSheetModalForWindow:win completionHandler:^(NSModalResponse result) {
            if (result != NSModalResponseOK) return;
            NSURL *url = sp.URL;
            if (!url) return;
            [_document exportGPXFile:arr.firstObject fileName:url.path];
        }];
    } else {
        if ([sp runModal] == NSModalResponseOK) {
            NSURL *url = sp.URL;
            if (url) [_document exportGPXFile:arr.firstObject fileName:url.path];
        }
    }
}


- (IBAction)googleEarthFlyBy:(id)sender
{
    [self _stopAnimations];
    NSMutableArray* arr = [_current prepareArrayOfSelectedTracks];
    if ([arr count] != 1)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select a single track in the browser for fly-by"];
        //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
    }
    else
    {
        NSError* error;
        Track* track = [arr objectAtIndex:0];
        NSDate* trackDate = [track creationTime];
        // MRC-safe replacement
        NSString *frm = @"dd-MMM-yy 'at' hh:mma"; // %d-%b-%y at %I:%M%p
        NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];

        static NSDateFormatter *fmt = nil;
        if (!fmt) {
            fmt = [[NSDateFormatter alloc] init];
            // For predictable, ASCII file/UI strings; use currentLocale if you want user-localized month/AM-PM
            fmt.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
            fmt.dateFormat = frm;
        }
        fmt.timeZone = tz;

        NSString *dayKey = [fmt stringFromDate:trackDate];
        NSMutableString* filename = [NSMutableString stringWithString:[self _getTempPath]];
        if (filename != nil)
        {
            NSFileManager* fm = [NSFileManager defaultManager];
            [fm removeItemAtPath:filename
                           error:&error];
            filename = [NSMutableString stringWithString:[self _getTempPath]];
        }
        [filename  appendString:@"/"];
        [filename  appendString:dayKey];
        [filename  appendString:@".kml"];
        NSFileManager* fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:filename
                       error:&error];
        [_document exportKMLFile:[arr objectAtIndex:0]
                         fileName:filename];
        
        NSString *path = filename; // your existing variable
        NSURL *fileURL = [NSURL fileURLWithPath:path];

        // Prefer the bundle identifier; fall back to the default app for the file if GE isn't found.
        NSURL *appURL = [[NSWorkspace sharedWorkspace]
            URLForApplicationWithBundleIdentifier:@"com.google.GoogleEarthPro"];
        if (!appURL) {
            appURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:fileURL];
        }

        NSWorkspaceOpenConfiguration *cfg = [NSWorkspaceOpenConfiguration configuration];
        cfg.activates = YES;                 // bring app to front
        cfg.promptsUserIfNeeded = YES;       // show UI if needed

        [[NSWorkspace sharedWorkspace] openURLs:@[fileURL]
                          withApplicationAtURL:appURL
                                  configuration:cfg
                              completionHandler:^(NSRunningApplication *app, NSError *error)
        {
            BOOL worked = (app != nil && error == nil);
            if (!worked) {
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"There was a problem completing this request. Have you installed Google Earth?"];
                [alert setInformativeText:@"This feature requires Google Earth to be installed."];
                [alert setAlertStyle:NSAlertStyleInformational];
                [alert runModal];
            }
            // Do whatever you previously did with `worked` here.
        }];
    }
}


- (IBAction)exportCSV:(id)sender
{
    [self doExportTextFile:@"csv" seperator:','];
}


- (IBAction)exportTXT:(id)sender
{
    [self doExportTextFile:@"tsv" seperator:'\t'];
}


- (void)doExportSummaryTextFile:(NSString *)suffix seperator:(char)sep
{
    [self _stopAnimations];

    NSSavePanel *sp = [NSSavePanel savePanel];

    // Choose an appropriate content type for the suffix
    UTType *t = nil;
    NSString *lower = [suffix lowercaseString];
    if ([lower isEqualToString:@"csv"]) {
        t = [UTType typeWithIdentifier:@"public.comma-separated-values-text"]
            ?: UTTypeCommaSeparatedText
            ?: [UTType typeWithFilenameExtension:@"csv"]
            ?: UTTypePlainText;
    } else if ([lower isEqualToString:@"txt"]) {
        t = UTTypePlainText;
    } else {
        t = [UTType typeWithFilenameExtension:lower] ?: UTTypePlainText;
    }
    sp.allowedContentTypes = @[ t ];
    sp.allowsOtherFileTypes = NO;
    sp.canCreateDirectories = YES;

    // Default name and directory
    NSMutableString *baseName = [NSMutableString stringWithString:([_document displayName] ?: @"Summary")];
    if (suffix.length) {
        [baseName appendFormat:@".%@", suffix];
    }
    sp.nameFieldStringValue = baseName;

    NSString *dirPath = [self baseDirectoryForImportExport];
    if (dirPath.length) sp.directoryURL = [NSURL fileURLWithPath:dirPath];

    // Present as a sheet if we have a window, otherwise modal
    NSWindow *win = self.view.window ?: NSApp.mainWindow ?: NSApp.keyWindow;

    void (^complete)(NSModalResponse) = ^(NSModalResponse result){
        if (result != NSModalResponseOK) return;
        NSURL *url = sp.URL;
        if (!url) return;

        NSString *text = [_current buildSummaryTextOutput:sep];
        NSError *err = nil;
        if (![text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
            NSLog(@"Could not write document out: %@", err.localizedDescription);
        }
    };

    if (win) {
        [sp beginSheetModalForWindow:win completionHandler:complete];
    } else {
        complete([sp runModal]);
    }
}



- (IBAction)exportSummaryCSV:(id)sender
{
    [self doExportSummaryTextFile:@"csv" seperator:','];
}


- (IBAction)exportSummaryTXT:(id)sender
{
    [self doExportSummaryTextFile:@"tsv" seperator:'\t'];
}



- (IBAction)exportLatLonText:(id)sender
{
    [self _stopAnimations];
    NSMutableArray* arr = [_current prepareArrayOfSelectedTracks];
    if ([arr count] != 1)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Please select a single track in the browser for export"];
        //[alert setInformativeText:@"Please purchase a registration key to enable all features."];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert runModal];
    }
    else
    {
        NSSavePanel *sp = [NSSavePanel savePanel];
        
        // Instead of setAllowedFileTypes:
        [sp setAllowedContentTypes:@[ UTTypePlainText ]];
        
        [sp setCanCreateDirectories:YES];
        [sp setExtensionHidden:NO];
        
        // Suggested file name
        NSString *baseName = [self baseActivityFileName:[arr objectAtIndex:0]
                                               fileType:@"txt"];
        [sp setNameFieldStringValue:baseName];
        
        // Starting directory
        [sp setDirectoryURL:[NSURL fileURLWithPath:[self baseDirectoryForImportExport]
                                       isDirectory:YES]];
        
        // Show panel
        NSInteger runResult = [sp runModal];
        if (runResult == NSModalResponseOK) {
            ///NSURL *destURL = [sp URL];
            // **FIXME** use destURL
        }
        
        /* if successful, save file under designated name */
        if (runResult == NSModalResponseOK)
        {
            NSURL *destURL = [sp URL];
            if (destURL) {
                [_document exportLatLonTextFile:[arr objectAtIndex:0]
                                        fileName:[destURL path]];
            }
        }
    }
    
}


- (void)_stopAnimations
{
    [[AnimTimer defaultInstance] stop:self];
}


- (NSString*) _getTempPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *path = [NSMutableString stringWithString:[paths objectAtIndex:0]];
    path = [path stringByAppendingPathComponent:PROGRAM_NAME];
    [Utils verifyDirAndCreateIfNecessary:path];
    path = [path stringByAppendingPathComponent:@"Temp"];
    [Utils verifyDirAndCreateIfNecessary:path];
    return path;
}


- (void) _doTCXImport:(NSArray*)files showProgress:(BOOL)sp
{
    ///NSUInteger numOld = [[_document trackArray] count];
    if (sp)
        [_pbHelper startProgressIndicator:self.view.window
                                   title:@"Importing tracks..."];
    NSUInteger num = [files count];
    Track* lastTrack = nil;
    for (int i=0; i<num; i++)
    {
        NSAutoreleasePool*        localPool = [NSAutoreleasePool new];
        NSString* file = [files objectAtIndex:i];
        if (sp)
            [_pbHelper updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
        lastTrack = [_document importTCXFile:file];
        [localPool release];
    }
    if (lastTrack != nil)
    {
        [_current updateAfterImport];
        [_document updateChangeCount:NSChangeDone];
        [self.view.window setDocumentEdited:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:TrackArrayChangedNotification object:_document];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
        [_current  selectLastImportedTrack:lastTrack];
    }
    if (sp)
        [_pbHelper endProgressIndicator];
}

- (void) _doTCXImportWithoutProgress:(NSArray*)files
{
    [self _doTCXImport:files
         showProgress:NO];
}

- (void) _doTCXImportWithProgress:(NSArray*)files
{
    [self _doTCXImport:files
         showProgress:YES];
}

- (void) _doHRMImportWithProgress:(NSArray*)files
{
    [_pbHelper startProgressIndicator:self.view.window title:@"Importing tracks..."];
    NSUInteger num = [files count];
    Track* lastTrack = nil;
    for (int i=0; i<num; i++)
    {
        NSString* file = [files objectAtIndex:i];
        [_pbHelper updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
        lastTrack = [_document importHRMFile:file];
    }
    if (lastTrack != nil)
    {
        [_current updateAfterImport];
        [_document updateChangeCount:NSChangeDone];
        [self.view.window setDocumentEdited:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:TrackArrayChangedNotification object:_document];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
        [_current  selectLastImportedTrack:lastTrack];
    }
    [_pbHelper endProgressIndicator];
}


- (void) _doGPXImportWithProgress:(NSArray*)files
{
    [_pbHelper startProgressIndicator:self.view.window title:@"Importing tracks..."];
    NSUInteger num = [files count];
    Track* lastTrack = nil;
    for (int i=0; i<num; i++)
    {
        NSString* file = [files objectAtIndex:i];
        [_pbHelper updateProgressIndicator:[NSString stringWithFormat:@"Importing %@...", file ]];
        lastTrack = [_document importGPXFile:file];
    }
    if (lastTrack != nil)
    {
        [_current updateAfterImport];
        [_document updateChangeCount:NSChangeDone];
        [self.view.window setDocumentEdited:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:TrackArrayChangedNotification object:_document];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
        [_current selectLastImportedTrack:lastTrack];
    }
    [_pbHelper endProgressIndicator];
}


- (void)_doFITImportWithProgress:(NSArray *)files
{
    // Ensure the progress UI starts on the main thread
    if ([NSThread isMainThread]) {
        [_pbHelper startProgressIndicator:self.view.window title:@"importing FIT tracks..."];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [_pbHelper startProgressIndicator:self.view.window title:@"importing FIT tracks..."];
        });
    }

    dispatch_queue_t workQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_semaphore_t doneSem = dispatch_semaphore_create(0);

    __block Track *lastTrack = nil; // Will be retained inside the worker

    // Kick off the work on a background queue
    dispatch_async(workQ, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSUInteger num = [files count];
        for (NSUInteger i = 0; i < num; i++) {
            NSString *file = [files objectAtIndex:i];

            // Update the progress text on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *name = [file lastPathComponent];
                [_pbHelper updateProgressIndicator:[NSString stringWithFormat:@"importing %@...", name]];
            });

            // Heavy work off the main thread
            Track *t = [_document importFITFile:file];
            if (t) {
                // Keep the most recent imported track
                if (lastTrack) [lastTrack release];
                lastTrack = [t retain];
            }
        }

        // Wrap up on the main thread (UI + notifications)
        dispatch_async(dispatch_get_main_queue(), ^{
            if (lastTrack != nil) {
                [_current updateAfterImport];
                [_document updateChangeCount:NSChangeDone];
                [self.view.window setDocumentEdited:YES];
                [[NSNotificationCenter defaultCenter] postNotificationName:TrackArrayChangedNotification object:_document];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"InvalidateBrowserCache" object:nil];
                [_current selectLastImportedTrack:lastTrack];
            }

            [_pbHelper endProgressIndicator];

            // Balance our retain
            if (lastTrack) {
                [lastTrack release];
                lastTrack = nil;
            }

            // Signal completion
            dispatch_semaphore_signal(doneSem);
        });

        [pool drain];
    });

    // Wait for completion:
    // If we're on the main thread, spin the runloop so UI stays responsive
    if ([NSThread isMainThread]) {
        while (dispatch_semaphore_wait(doneSem, DISPATCH_TIME_NOW) != 0) {
            // Allow UI updates, progress text, etc.
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
    } else {
        // Off-main callers can block directly
        dispatch_semaphore_wait(doneSem, DISPATCH_TIME_FOREVER);
    }

    // Clean up semaphore for MRC
#if !OS_OBJECT_USE_OBJC
    dispatch_release(doneSem);
#endif
}


- (IBAction)cut:(id)sender
{
    [_current processCut:sender];
}


- (IBAction)copy:(id)sender
{
    [_current processCopy:sender];
}


- (IBAction)paste:(id)sender
{
    [_current processPaste:sender];
}


- (IBAction)delete:(id)sender
{
    [_current processDelete:sender];
}


- (IBAction)syncStravaActivities:(id)sender
{
    NSWindow *host = self.view.window ?: NSApp.keyWindow ?: NSApp.mainWindow;
   // Get a fresh token (StravaAPI will refresh or re-auth as needed)
    [[StravaAPI shared] fetchFreshAccessToken:^(NSString * _Nullable token, NSError * _Nullable error) {

        // Always hop to main for any UI work
        dispatch_async(dispatch_get_main_queue(), ^{

            if (error || token.length == 0) {
                NSLog(@"Token fetch error: %@", error);
                NSAlert *a = [[[NSAlert alloc] init] autorelease];
                a.messageText = @"Strava Authorization Failed";
                a.informativeText = error.localizedDescription ?: @"Could not obtain a Strava access token.";
                [a beginSheetModalForWindow:host completionHandler:nil];
                return;
            }

            // Ensure "Bearer " prefix for StravaImporter
            NSString *bearer = [token hasPrefix:@"Bearer "] ? token : [@"Bearer " stringByAppendingString:token];

            // Helper to start the import (runs on main; importer will use its own queue internally)
            void (^startImportWithToken)(NSString *) = ^(NSString *tok) {
                [_pbHelper startProgressIndicator:self.view.window
                                            title:@"checking if Strava is home…"];

                StravaImporter *importer = [[StravaImporter alloc] init];

                NSDate *lastSyncTime = [_document lastSyncTime];

                // If lastSyncTime is distantPast, try document's newest date
                if (lastSyncTime == [NSDate distantPast]) {
                    NSArray *dateRange = [_document documentDateRange];
                    if (dateRange.count == 2) {
                        NSDate *newestDate = [dateRange objectAtIndex:1];
                        if (newestDate && ([newestDate compare:[NSDate distantFuture]] != NSOrderedSame)) {
                            lastSyncTime = newestDate;
                        }
                    }
                }

                // Default to “last 3 days” if still unset
                NSCalendar *cal = [NSCalendar currentCalendar];
                if (!lastSyncTime || ([lastSyncTime compare:[NSDate distantPast]] == NSOrderedSame)) {
                    NSDate *now = [NSDate date];
                    lastSyncTime = [cal dateByAddingUnit:NSCalendarUnitMonth
                                                   value:-2
                                                  toDate:now options:0];
                }

                // Truncate to midnight (local)
                NSDateComponents *dc = [cal components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay)
                                              fromDate:lastSyncTime];
                NSDate *since = [[NSCalendar currentCalendar] dateFromComponents:dc];

                NSLog(@"syncing activites later than %s", [[since description] UTF8String]);

                __block BOOL madeDeterminate = NO;

                [importer importTracksSince:since
                                    perPage:200
                                   maxPages:20
                                   progress:^(NSUInteger pagesFetched, NSUInteger totalSoFar)
                {
                    // This block may already be on main; keep UI safe anyway.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!madeDeterminate && totalSoFar > 0) {
                            madeDeterminate = YES;
                            [_pbHelper beginWithTitle:@"syncing Strava activities…" divisions:(int)totalSoFar];
                        } else {
                            [_pbHelper incrementDiv];
                        }
                    });
                }
                                 completion:^(NSArray *tracks, NSError *error)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (error) {
                            NSLog(@"Strava import failed: %@", error);
                        } else {
                            if ([tracks count] > 0) {
                                [_pbHelper updateProgressIndicator:@"updating browser..."];

                                // Avoid MRC leak: autorelease the mutableCopy
                                NSMutableArray *tracksCopy = [[tracks mutableCopy] autorelease];
                                NSArray *beginEndDates = [_document addTracksAfterStravaSync:tracksCopy];

                                if (beginEndDates.count == 2) {
                                    NSDate *oldestDate = [beginEndDates objectAtIndex:0];
                                    NSDate *newestDate = [beginEndDates objectAtIndex:1];

                                    if (oldestDate && newestDate) {
                                        [_document setLastSyncTime:newestDate];

                                        NSArray *docRange = [_document documentDateRange];
                                        if (docRange.count == 2) {
                                            NSDate *docBeginDate = [docRange objectAtIndex:0];
                                            NSDate *docEndDate   = [docRange objectAtIndex:1];

                                            if (([docBeginDate compare:[NSDate distantPast]] == NSOrderedSame) ||
                                                ([oldestDate compare:docBeginDate] == NSOrderedAscending)) {
                                                docBeginDate = oldestDate;
                                            }
                                            if (([docEndDate compare:[NSDate distantFuture]] == NSOrderedSame) ||
                                                ([newestDate compare:docEndDate] == NSOrderedDescending)) {
                                                docEndDate = newestDate;
                                            }

                                            [_document setDocumentDateRange:[NSArray arrayWithObjects:docBeginDate, docEndDate, nil]];
                                            NSLog(@"setting document begin/end dates to %s and %s",
                                                  [[docBeginDate description] UTF8String],
                                                  [[docEndDate description] UTF8String]);
                                        }
                                    }
                                }

                                [self.view.window setDocumentEdited:YES];
                            }
                        }

                        [importer release];
                        [_pbHelper endProgressIndicator];
                    });
                }];
            };

            startImportWithToken(bearer);
        });
    }];
}


#if 0
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
#endif



-(void) _buildContextualMenu
{
    NSMenu* cm = [[[NSMenu alloc] init] autorelease];
    
    //[cm setShowsStateColumn:YES];
    
    [[cm addItemWithTitle:@"Email..."
                   action:@selector(mailActivity:)
            keyEquivalent:@""] setTag:kCMEmailSelected];
    
    [[cm addItemWithTitle:@"Save..."
                   action:@selector(saveSelectedTracks:)
            keyEquivalent:@""] setTag:kCMSaveSelected];
    
    [[cm addItemWithTitle:@"Google Earth Fly-By..."
                   action:@selector(googleEarthFlyBy:)
            keyEquivalent:@""] setTag:kCMGoogleFlyBy];
    
    [cm addItem:[NSMenuItem separatorItem]];
    
    [[cm addItemWithTitle:@"Export as gpx..."
                   action:@selector(exportGPX:)
            keyEquivalent:@""] setTag:kCMExportGPX];
    
    [[cm addItemWithTitle:@"Export as kml..."
                   action:@selector(exportKML:)
            keyEquivalent:@""] setTag:kCMExportKML];
    
    [[cm addItemWithTitle:@"Export as tcx..."
                   action:@selector(exportTCX:)
            keyEquivalent:@""] setTag:kCMExportTCX];
    
    [[cm addItemWithTitle:@"Export activity as tab-separated values (tsv)..."
                   action:@selector(exportTXT:)
            keyEquivalent:@""] setTag:kCMExportTXT];
    
    [[cm addItemWithTitle:@"Export activity as comma-separated values (csv)..."
                   action:@selector(exportCSV:)
            keyEquivalent:@""] setTag:kCMExportCSV];
    
    [[cm addItemWithTitle:@"Export summary data as tab-separated values (tsv)..."
                   action:@selector(exportSummaryTXT:)
            keyEquivalent:@""] setTag:kCMExportSummaryTXT];
    
    [[cm addItemWithTitle:@"Export summary data as comma-separated values (csv)..."
                   action:@selector(exportSummaryCSV:)
            keyEquivalent:@""] setTag:kCMExportSummaryCSV];
    
    [cm addItem:[NSMenuItem separatorItem]];
  
    [[cm addItemWithTitle:@"Update Detailed Track Info"
                   action:@selector(enrichSelectedTracks:)
            keyEquivalent:@""] setTag:kCMEnrichTracks];

    [cm addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem* mi;
    mi = [cm addItemWithTitle:@"Add Activity..."
                       action:@selector(addActivity:)
                keyEquivalent:@"A"];
    [mi setTag:kCMAddActivity];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    
//    mi = [cm addItemWithTitle:@"Edit Activity..."
//                       action:@selector(editActivity:)
//                keyEquivalent:@"E"];
//    [mi setTag:kCMEditActivity];
    [mi setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    
    [[cm addItemWithTitle:@"Split Activity..."
                   action:@selector(splitActivity:)
            keyEquivalent:@""] setTag:kCMSplitActivity];
    
    [[cm addItemWithTitle:@"Compare Activities"
                   action:@selector(compareActivities:)
            keyEquivalent:@"y"] setTag:kCMCompareActivities];
    
    [[cm addItemWithTitle:@"Combine Activities"
                   action:@selector(combineActivities:)
            keyEquivalent:@""] setTag:kCMCombineActivities];
    
//    [[cm addItemWithTitle:@"Adjust GMT Offset..."
//                   action:@selector(getGMTOffset:)
//            keyEquivalent:@""] setTag:kCMAdjustGMTOffset];
//    
//    [[cm addItemWithTitle:@"Altitude Smoothing..."
//                   action:@selector(getAltitudeSmoothing:)
//            keyEquivalent:@""] setTag:kCMAltitudeSmoothing];
    
    
    [cm addItem:[NSMenuItem separatorItem]];
    
    mi = [cm addItemWithTitle:@"Open Activity Detail View"
                       action:@selector(showActivityDetail:)
                keyEquivalent:@"g"];
    [mi setTag:kCMOpenActivityDetail];
    
    mi = [cm addItemWithTitle:@"Open Map Detail View"
                       action:@selector(showMapDetail:)
                keyEquivalent:@"m"];
    [mi setTag:kCMOpenMapDetail];
    
    mi = [cm addItemWithTitle:@"Open Data Detail View"
                       action:@selector(showDataDetail:)
                keyEquivalent:@"D"];
    [mi setTag:kCMOpenDataDetail];
    
    [cm addItem:[NSMenuItem separatorItem]];
    
    [[cm addItemWithTitle:@"Refresh Map"
                   action:@selector(refreshMap:)
            keyEquivalent:@""] setTag:kCMRefreshMap];
    
    [_outlineVC setContextualMenu:cm];
    [_calendarVC setContextualMenu:cm];
}


- (void)selectionDoubleClicked:(NSNotification *)notification
{
    int defaultAction = [Utils intFromDefaults:RCBDefaultDoubleClickAction];
    switch (defaultAction)
    {
        default:
        case 0:
            [[NSNotificationCenter defaultCenter] postNotificationName:OpenActivityDetailNotification
                                                                object:_document];
            break;
        case 1:
            [[NSNotificationCenter defaultCenter] postNotificationName:OpenMapDetailNotification
                                                                object:_document];
            break;
        case 2:
            ///[self showActivityDataList:self];
            break;
    }
}


- (IBAction)toggleLowerSplit:(id)sender;
{
    if (_parentSplitVC) {
        [_parentSplitVC toggleLowerSplit];
    }
}



@end
