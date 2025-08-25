//
//  SyncController.h
//  Ascent
//
//  Created by Rob Boyer on 7/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentServer.h"

@class NetReachability;
@class SyncController;
@class Track;
@class AppController;
@class TrackBrowserDocument;

@interface SyncController : NSObject <AscentServerDelegate>
{
	AppController*				appController;
	NetReachability*			reachability;
	AscentClientProxy*			clientProxy;
	AscentServer*				server;
	SyncController*				syncController;
	Track*						trackBeingSynced;
	NSMutableArray*				trackArrayBeingSynced;
	TrackBrowserDocument*		document;
	NSArray*					tracksWithDataOnMobileDevice;
	NSArray*					tracksWithoutDataOnMobileDevice;
	NSMutableDictionary*		remoteUUIDDict;
}
-(id)initWithAppController:(AppController*)ac;
-(void)startAdvertising;
-(void)stopAdvertising;
-(void)setDocument:(TrackBrowserDocument*)tbd;

@end
