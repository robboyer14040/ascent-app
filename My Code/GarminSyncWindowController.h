//
//  GarminSyncWindowController.h
//  Ascent
//
//  Created by Rob Boyer on 12/25/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class TrackBrowserDocument;
	
@interface AscentWebView : WKWebView
@end
	
@interface GarminSyncWindowController : NSWindowController 
{
	IBOutlet AscentWebView*		webView;
	TrackBrowserDocument*		tbDocument;
	NSString*					importDir;
}

@property(retain, nonatomic) NSString* importDir;

-(id)initWithDocument:(TrackBrowserDocument*)doc;
-(void)importNewFiles;


@end
