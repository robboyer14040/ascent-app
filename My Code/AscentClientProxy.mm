
#import <netinet/in.h>

#import "AscentClientProxy.h"
#import "TCPConnection.h"
#import "NetUtilities.h"
#import "Networking_Internal.h"

//CONSTANTS:

#define kMagic						0xABCD1234

//CLASS INTERFACES:

@interface AscentClientProxy (Internal) <TCPConnectionDelegate>
@end

//CLASS IMPLEMENTATIONS:

@implementation AscentClientProxy

//@synthesize server=_server, name=_name, delegate=_delegate;

- (id) initWithNSNetService:(NSNetService*)netService // netService must already be resolved
{
	if (netService) {
		NSArray* addresses = [netService addresses];
		if (addresses && [addresses count]) {
			NSString*			name = [netService name];
			struct sockaddr*	address = (struct sockaddr*)[[addresses objectAtIndex:0] bytes];
			
			self = [self initWithName:name address:address];
		}
	}
	
	return self;
}

- (id) initWithName:(NSString*)name address:(const struct sockaddr*)address
{
	if(address == NULL) {
		[self release];
		return nil;
	}
	
	if((self = [super init])) {
		_server = YES;
		_address = (sockaddr*)malloc(address->sa_len);
		bcopy(address, _address, address->sa_len);
		
		_name = [name copy];
	}
	
	return self;
}

- (id) initWithConnection:(TCPConnection*)connection
{
	if((self = [super init])) {
		_connection = [connection retain];
		[_connection setDelegate:self];
	}
	
	return self;
}

- (void) dealloc
{
	[self disconnect];
	
	[_name release];
	
	if(_address)
		free(_address);
	
	[super dealloc];
}

- (BOOL) connect
{
	if(_connection)
		return NO;
	
	_connection = [[TCPConnection alloc] initWithRemoteAddress:_address];
	if(_connection == nil)
		return NO;
	[_connection setDelegate:self];
	
	return YES;
}

- (BOOL) sendData:(NSData*)data
{
	return [_connection sendData:data];
}

- (void) disconnect
{
	BOOL				wasValidating = (_connection ? YES : NO),
	wasConnected = _connected;
	
	if(_disconnecting == NO) {
		_disconnecting = YES;
		
		_connected = NO;
		
		[_connection invalidate];
		[_connection setDelegate:nil];
		[_connection autorelease]; //NOTE: Ensure TCPConnection is not de-alloced immediately as -disconnect might be called from inside one of its delegate calls
		_connection = nil;
		
		if(wasConnected)
			[_delegate ascentClientProxyDidDisconnect:self];
		else if(wasValidating)
			[_delegate ascentClientProxyDidFailConnecting:self];
		
		_disconnecting = NO;
	}
}

- (const struct sockaddr*) socketAddress
{
	return _address;
}

- (UInt32) IPv4Address
{
	return (_address && (_address->sa_family == AF_INET) ? ((struct sockaddr_in*)_address)->sin_addr.s_addr : 0);
}

- (BOOL) isConnecting
{
	return (_connection && ! _connected);
}

- (BOOL) isConnected
{
	return _connected;
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08lX | address = %@ | name = \"%@\" | connected = %i>", [self class], (long)self, SockaddrToString(_address), [self name], [self isConnected]];
}

- (NSData*) _dataFromDictionary:(NSDictionary*)dictionary
{
	NSMutableData*				data = [NSMutableData data];
	int							magic = NSSwapHostIntToBig(kMagic);
	
	[data appendBytes:&magic length:sizeof(int)];
	[data appendData:[NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]];
	
	return data;
}

- (NSDictionary*) dictionaryFromData:(NSData*)data
{
	NSDictionary*				dictionary = nil;
	NSString*					error;
	
	if(([data length] > sizeof(int)) && (NSSwapBigIntToHost(*((int*)[data bytes])) == kMagic)) {
		dictionary = [NSPropertyListSerialization propertyListFromData:[data subdataWithRange:NSMakeRange(sizeof(int), [data length] - sizeof(int))] mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error];
		if(dictionary == nil)
			REPORT_ERROR(@"Failed de-serializing dictionary: \"%@\"", error);
	}
	
	return dictionary;
}

- (void) _finishConnecting:(NSDictionary*)dictionary
{
#if 0
	[_name release];
	_name = [[dictionary objectForKey:@"name"] copy];
	if(![_name length])
		[NSException raise:NSInternalInconsistencyException format:@""];
#endif	
	_connected = YES;
	
	[_delegate ascentClientProxyDidConnect:self];
}


- (void) connectionDidFailOpening:(TCPConnection*)connection
{
	[self disconnect];
}

- (void) connectionDidOpen:(TCPConnection*)connection
{
	NSDictionary*				dictionary;
	//NSData*						data;
	const struct sockaddr*		address;
	
	if(_address == NULL) {
		address = [_connection remoteSocketAddress];
		if(address == NULL) {
			REPORT_ERROR(@"Failed retrieving connection remote address from %@", _connection);
			[self disconnect];
			return;
		}
		_address = (sockaddr*)malloc(address->sa_len);
		bcopy(address, _address, address->sa_len);
	}
	
	dictionary = [NSMutableDictionary new];
#if 0
	[(NSMutableDictionary*)dictionary setObject:[_delegate ascentClientProxyWillSendName:self] forKey:@"name"];
	data = [self _dataFromDictionary:dictionary];
	[dictionary release];
	
	if(_server == NO) {
		dictionary = [self dictionaryFromData:[_connection receiveData]];
		if(dictionary == nil) {
			REPORT_ERROR(@"Failed receiving dictionary from connection", NULL);
			[self disconnect];
			return;
		}
	}
	
	if(![_connection sendData:data]) {
		REPORT_ERROR(@"Failed sending dictionary to connection", NULL);
		[self disconnect];
	}
#endif
	
	if(_server == NO)
		[self _finishConnecting:dictionary];
}

- (void) connectionDidClose:(TCPConnection*)connection
{
	[self disconnect];
}

- (void) connection:(TCPConnection*)connection didReceiveData:(NSData*)data
{
#if 0
	NSDictionary*				dictionary;
	
	if((dictionary = [self dictionaryFromData:data])) {
		if(!_connected)
			[self _finishConnecting:dictionary];
		else if(![dictionary count]) {
			if(![_connection sendData:data])
				REPORT_ERROR(@"Failed sending dictionary: \"%@\"", dictionary);
		}
		else
			REPORT_ERROR(@"Received unexpected dictionary: \"%@\"", dictionary);
	}
	else
#endif
		[_delegate ascentClientProxy:self didReceiveData:data];
}


-(BOOL) server
{
	return _server;
}

-(NSString*) name
{
	return _name;
}

-(id<AscentClientProxyDelegate>) delegate
{
	return _delegate;
}


-(void) setDelegate:(id<AscentClientProxyDelegate>)del
{
	if (del != _delegate)
	{
		[_delegate release];
		_delegate = [del retain];
	}
}


@end

#if 0
@property(readonly, getter=isServer) BOOL server;
@property(readonly) NSString* name;
@property(readonly) UInt32 IPv4Address; //opaque (not an integer)

@property(readonly, getter=isConnecting) BOOL connecting;
@property(readonly, getter=isConnected) BOOL connected;
#endif
