//
//  GarminSyncWindowController.mm
//  Ascent
//
//  Created by Rob Boyer on 12/25/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "GarminSyncWindowController.h"
#import "TrackBrowserDocument.h"
#import "TBWindowController.h"		// @@FiXME@@
#import "Utils.h"
#import "StringAdditions.h"


@implementation AscentWebView

- (void)mouseDragged:(NSEvent*) ev 
{
	printf("mouse drag\n");
}

@end


@implementation GarminSyncWindowController
@synthesize importDir;

- (id)initWithDocument:(TrackBrowserDocument*)doc
{
	self = [super initWithWindowNibName:@"GarminSync"];
	tbDocument = doc;
	self.importDir = nil;
	return self;
}


-(void)dealloc
{
	self.importDir = nil;
}


-(void)awakeFromNib
{
	NSString* path = [[NSBundle mainBundle] pathForResource:@"gs" 
													 ofType:@"html"];
	path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
 	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:path]]];
	[webView setAlphaValue:0.85];
	[[self window] setMovableByWindowBackground:NO];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp stopModal];
}


-(IBAction)dismiss:(id)sender
{
	[[self window]  close];
}


- (void)webView:(WebView *)webView windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject 
{
	NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    [windowScriptObject setValue:self forKey:@"syncController"];
	
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector 
{
	NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if (selector == @selector(importActivity:)) 
	{
        return NO;
    }
	else if (selector == @selector(finishedImporting)) 
	{
       return NO;
    }
    return YES;
}


+ (NSString *) webScriptNameForSelector:(SEL)sel 
{
	NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
	if (sel == @selector(importActivity:)) 
	{
		return @"importActivity";
	} 
	else if (sel == @selector(finishedImporting)) 
	{
		return @"finishedImporting";
	} 
	else 
	{
		return nil;
	}
}


- (void) importActivity: (NSString*) act 
{
	NSData* data = [act dataUsingEncoding:NSUTF8StringEncoding];
	NSString* path = [Utils tempPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError* error;
	if (!self.importDir)
	{
		[fileManager removeItemAtPath:path 
								error:&error];
		if ([fileManager createDirectoryAtPath:path 
				   withIntermediateDirectories:YES
									attributes:nil
										 error:&error])
		{
			self.importDir = path;
		}
	}
	if (self.importDir)
	{
		NSString* uid = [NSString uniqueString];
		path = [path stringByAppendingPathComponent:uid];
		path = [path stringByAppendingPathExtension:@"tcx"];
		
		if ([fileManager createFileAtPath:path 
								 contents:data
							   attributes:nil])
		{
			NSLog(@"created %@\n", path);
			//[[tbDocument windowController] doTCXImportWithProgress:[NSArray arrayWithObject:path]];
		}
	}
}


- (void) finishedImporting 
{
	[self dismiss:self];
}


-(void)importNewFiles
{
	if (importDir)
	{
		NSError* error;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray* files = [fileManager contentsOfDirectoryAtPath:importDir 
														  error:&error];
		NSMutableArray* fullFileSpecs = [NSMutableArray arrayWithCapacity:[files count]];
		for (NSString* file in files)
		{
			NSString* p = [importDir stringByAppendingPathComponent:file];
			[fullFileSpecs addObject:p];
		}
#if 1
		for (NSString* file in fullFileSpecs)
		{
			[[tbDocument windowController] performSelector:@selector(doTCXImportWithoutProgress:) 
												withObject:[NSArray arrayWithObject:file] 
												afterDelay:0.0];
		}
#else
		// leaks memory
		[[tbDocument windowController] doTCXImportWithProgress:fullFileSpecs];
#endif
	}
}


@end
