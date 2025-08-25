
#import <unistd.h>

#import "TCPServer.h"
#import "Networking_Internal.h"

//CLASS INTERFACES:

@interface TCPServerConnection (Private)
- (void) _setServer:(TCPServer*)server;
@end

@interface TCPServer (Internal)
- (void) _removeConnection:(TCPServerConnection*)connection;
@end

//CLASS IMPLEMENTATIONS:

@implementation TCPServerConnection

//@synthesize server=_server;

- (void) _setServer:(TCPServer*)server
{
	_server = server;
}


-(TCPServer*)server
{
	return _server;
}

- (void) _invalidate
{
	TCPServer*			server;
	
	server = _server;
	
	[super _invalidate]; //NOTE: The server delegate may destroy the server when notified this connection was invalidated
	
	[server _removeConnection:self];
}

@end

@implementation TCPServer

//@synthesize delegate=_delegate;


-(id<TCPServerDelegate>) delegate
{
	return _delegate;
}


+ (Class) connectionClass
{
	return [TCPServerConnection class];
}

- (id) initWithPort:(UInt16)port
{
	if((self = [super initWithPort:port])) {
		_connections = [NSMutableSet new];
	}
	
	return self;
}

- (void) dealloc
{
	[self stop]; //NOTE: Make sure our -stop is executed immediately
	
}

- (void) setDelegate:(id<TCPServerDelegate>)delegate
{
	_delegate = delegate;
	
	SET_DELEGATE_METHOD_BIT(0, serverDidStart:);
	SET_DELEGATE_METHOD_BIT(1, serverDidEnableBonjour:withName:);
	SET_DELEGATE_METHOD_BIT(2, server:shouldAcceptConnectionFromAddress:);
	SET_DELEGATE_METHOD_BIT(3, server:didOpenConnection:);
	SET_DELEGATE_METHOD_BIT(4, server:didCloseConnection:);
	SET_DELEGATE_METHOD_BIT(5, serverWillDisableBonjour:);
	SET_DELEGATE_METHOD_BIT(6, serverWillStop:);
	SET_DELEGATE_METHOD_BIT(7, server:didNotEnableBonjour:);
}

- (BOOL) startUsingRunLoop:(NSRunLoop*)runLoop
{
	if(![super startUsingRunLoop:runLoop])
	return NO;
	
	if(TEST_DELEGATE_METHOD_BIT(0))
	[_delegate serverDidStart:self];
	
	return YES;
}

/*
 Bonjour will not allow conflicting service instance names (in the same domain), and may have automatically renamed
 the service if there was a conflict.  We pass the name back to the delegate so that the name can be displayed to
 the user.
 See http://developer.apple.com/networking/bonjour/faq.html for more information.
 */

- (void)netServiceDidPublish:(NSNetService *)sender
{
	[super netServiceDidPublish:sender];
	if(TEST_DELEGATE_METHOD_BIT(1))
		[_delegate serverDidEnableBonjour:self withName:sender.name];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	[super netServiceDidPublish:sender];
	if(TEST_DELEGATE_METHOD_BIT(7))
		[_delegate server:self didNotEnableBonjour:errorDict];
}

- (void) disableBonjour
{
	if([self isBonjourEnabled] && TEST_DELEGATE_METHOD_BIT(5))
	[_delegate serverWillDisableBonjour:self];
	
	[super disableBonjour];
}

- (void) stop
{
	NSArray*			connections;
	TCPConnection*		connection;
	
	if([self isRunning] && TEST_DELEGATE_METHOD_BIT(6))
	[_delegate serverWillStop:self];
	
	[super stop];
	
	connections = [self allConnections];
	//for(connection in connections)
	NSEnumerator *enumerator = [connections objectEnumerator];
	while ((connection = [enumerator nextObject])) {
		[connection invalidate];
	}
}

- (NSArray*) allConnections
{
	NSArray*				connections;
	
	connections = [_connections allObjects];
	
	return connections;
}

- (void) _addConnection:(TCPServerConnection*)connection
{
	[_connections addObject:connection];
	[connection _setServer:self];
	
	if(TEST_DELEGATE_METHOD_BIT(3))
	[_delegate server:self didOpenConnection:connection];
}

- (void) _removeConnection:(TCPServerConnection*)connection
{
	if(TEST_DELEGATE_METHOD_BIT(4))
	[_delegate server:self didCloseConnection:connection];
	
	[connection _setServer:nil];
	[_connections removeObject:connection];
}

- (void) handleNewConnectionWithSocket:(NSSocketNativeHandle)socket fromRemoteAddress:(const struct sockaddr*)address
{
	TCPServerConnection*		connection;
	
	if(!TEST_DELEGATE_METHOD_BIT(2) || [_delegate server:self shouldAcceptConnectionFromAddress:address]) {
		connection = [[[[self class] connectionClass] alloc] initWithSocketHandle:socket];
		if(connection) {
			[self _addConnection:connection];
			}
		else
		REPORT_ERROR(@"Failed creating TCPServerConnection for socket #%i", socket);
	}
	else
	close(socket);
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08lX | %i connections | super = %@>", [self class], (long)self, [_connections count], [super description]];
}

@end
