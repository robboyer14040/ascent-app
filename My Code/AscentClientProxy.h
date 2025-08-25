//
//  AscentClientProxy.h
//  Ascent
//
//  Created by Rob Boyer on 7/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <sys/socket.h>

//CLASSES:

@class TCPConnection;

//CLASS INTERFACES:
@interface AscentClientProxy : NSObject
{
@private
	BOOL					_server;
	NSString*				_name;
	struct sockaddr*		_address;
	TCPConnection*			_connection;
	BOOL					_connected;
	id						_delegate;
	BOOL					_disconnecting;
}

-(BOOL) server;
-(NSString*) name;
-(UInt32) IPv4Address;
-(BOOL)isConnecting;
-(BOOL)isConnected;

#if 0
@property(readonly, getter=isServer) BOOL server;
@property(readonly) NSString* name;
@property(readonly) UInt32 IPv4Address; //opaque (not an integer)

@property(readonly, getter=isConnecting) BOOL connecting;
@property(readonly, getter=isConnected) BOOL connected;
#endif


- (NSDictionary*) dictionaryFromData:(NSData*)data;

//-(id<AscentClientProxyDelegate>) delegate;
//-(void) setDelegate:(id<AscentClientProxyDelegate>)del;

@end
