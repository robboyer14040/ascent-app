//
//  AscentServer.mm
//  Ascent
//
//  Created by Rob Boyer on 7/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AscentServer.h"
#import "TCPServer.h"
#import "NetUtilities.h"
#import "Networking_Internal.h"

//CLASS INTERFACES:

@interface AscentServer (Internal) <AscentClientProxyDelegate, TCPServerDelegate>
@end

//CLASS IMPLEMENTATIONS:

@implementation AscentServer

//@synthesize delegate=_delegate, name=_name, advertising=_advertising;

- (id) init
{
	return [self initWithName:nil port:0];
}

- (id) initWithName:(NSString*)name port:(UInt16)port
{
	if((self = [super init])) {
		_name = [name copy];
		_activeClients = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		_connectedClients = [NSMutableSet new];
		
		_server = [[TCPServer alloc] initWithPort:port];
		[_server setDelegate:self];
		if(![_server startUsingRunLoop:[NSRunLoop currentRunLoop]]) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) dealloc
{
	AscentClientProxy*			peer;
	
	[self stopAdvertisingToClients];
	
	[_server stop];
	[_server setDelegate:nil];
	[_server release];
	
	//for(peer in _connectedClients) {
	NSEnumerator *enumerator = [_connectedClients objectEnumerator];
	while ((peer = [enumerator nextObject])) {
		/* code that acts on the set’s values */
		[peer setDelegate:nil];
		[peer disconnect];
	}
	[_connectedClients release];
	
	if(_activeClients)
		CFRelease(_activeClients);
	
	[_name release];
	
	[super dealloc];
}

- (void) setDelegate:(id<AscentServerDelegate>)delegate
{
	_delegate = delegate;
	
	SET_DELEGATE_METHOD_BIT(0, ascentServerDidStartAdvertisingToClients:);
	SET_DELEGATE_METHOD_BIT(1, ascentServerWillStopAdvertisingToClients:);
	SET_DELEGATE_METHOD_BIT(2, ascentServer:shouldAllowConnectionToClient:);
	SET_DELEGATE_METHOD_BIT(3, ascentServer:didFailConnectingToClient:);
	SET_DELEGATE_METHOD_BIT(4, ascentServer:didConnectToClient:);
	SET_DELEGATE_METHOD_BIT(5, ascentServer:didReceiveData:fromClient:);
	SET_DELEGATE_METHOD_BIT(6, ascentServer:didDisconnectFromClient:);
}

- (UInt16) port
{
	return [_server localPort];
}

- (BOOL) startAdvertisingToClientsWithIdentifier:(NSString*)identifier
{
	if(_advertising || ![identifier length])
		return NO;
	
	if(![_server enableBonjourWithDomain:@"local" applicationProtocol:identifier name:_name])
		return NO;
	
	return YES;
}

- (void) stopAdvertisingToClients
{
	if(_advertising) {
		if(TEST_DELEGATE_METHOD_BIT(1))
			[_delegate ascentServerWillStopAdvertisingToClients:self];
		_advertising = NO;
	}
	
	[_server disableBonjour];
}

- (NSArray*) connectedClients
{
	return [_connectedClients allObjects];
}

- (void) disconnectFromClient:(AscentClientProxy*)client
{
	if(client && [_connectedClients containsObject:client])
		[client disconnect];
}


- (BOOL) sendDataToAllClients:(NSData*)data
{
	AscentClientProxy*			peer;
	BOOL				success = YES;
	
	//for(peer in _connectedClients) {
	NSEnumerator *enumerator = [_connectedClients objectEnumerator];
	while ((peer = [enumerator nextObject])) {
		if(![peer sendData:data])
			success = NO;
	}
	
	return success;
}

- (BOOL) sendData:(NSData*)data toClient:(AscentClientProxy*)client
{
	if(!client || ![_connectedClients containsObject:client])
		return NO;
	
	return [client sendData:data];
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08lX | advertising = %i | connected clients = %i>", [self class], (long)self, [self isAdvertising], [[self connectedClients] count]];
}


-(NSString*) name
{
	return _name;
}


-(id<AscentServerDelegate>) delegate
{
	return _delegate;
}


-(BOOL) isAdvertising
{
	return _advertising;
}



@end




@implementation AscentServer (TCPServerDelegate)

- (void) server:(TCPServer*)server didOpenConnection:(TCPServerConnection*)connection
{
	AscentClientProxy*			peer;
	
	peer = [[AscentClientProxy alloc] initWithConnection:connection];
	if(peer) {
		[peer setDelegate:self];
		CFDictionaryAddValue(_activeClients, connection, peer);
		[peer release];
	}
	else {
		REPORT_ERROR(@"Failed creating AscentClientProxy from %@", connection);
		[connection invalidate];
	}
}

- (void) server:(TCPServer*)server didCloseConnection:(TCPServerConnection*)connection
{
	AscentClientProxy*			peer = (AscentClientProxy*)CFDictionaryGetValue(_activeClients, connection);
	
	[peer retain];
	CFDictionaryRemoveValue(_activeClients, connection);
	[peer autorelease]; //NOTE: We need the AscentClientProxy instance not to be de-alloced until -[AscentClientProxy disconnect] has completed
}

- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name {
	_advertising = YES;
	
	// Make sure we use the name advertised by Bonjour
	[_name release];
	_name = [name copy];
	
	if(TEST_DELEGATE_METHOD_BIT(0))
		[_delegate ascentServerDidStartAdvertisingToClients:self];
}

@end

@implementation AscentServer (AscentClientProxyDelegate)

- (NSString*) ascentClientProxyWillSendName:(AscentClientProxy*)peer
{
	return _name;
}

- (void) ascentClientProxyDidFailConnecting:(AscentClientProxy*)peer
{
	[peer retain];
	
	if(TEST_DELEGATE_METHOD_BIT(3))
		[_delegate ascentServer:self didFailConnectingToClient:peer];
	
	[peer setDelegate:nil];
	[peer release];
}

- (void) ascentClientProxyDidConnect:(AscentClientProxy*)peer
{
	if(!TEST_DELEGATE_METHOD_BIT(2) || [_delegate ascentServer:self shouldAllowConnectionToClient:peer]) {
		[_connectedClients addObject:peer];
		
		if(TEST_DELEGATE_METHOD_BIT(4))
			[_delegate ascentServer:self didConnectToClient:peer];
	}
	else {
		[peer setDelegate:nil];
		
		[peer disconnect];
	}
}

- (void) ascentClientProxyDidDisconnect:(AscentClientProxy*)peer
{
	if([_connectedClients containsObject:peer]) {
		[peer retain];
		
		[_connectedClients removeObject:peer];
		
		if(TEST_DELEGATE_METHOD_BIT(6))
			[_delegate ascentServer:self didDisconnectFromClient:peer];
		
		[peer setDelegate:nil];
		[peer release];
	}
}

- (void) ascentClientProxy:(AscentClientProxy*)peer didReceiveData:(NSData*)data
{
	if(TEST_DELEGATE_METHOD_BIT(5))
		[_delegate ascentServer:self didReceiveData:data fromClient:peer];
}



@end
