
#import <unistd.h>
#import <netinet/in.h>

#import <CoreServices/CoreServices.h>
#import "TCPConnection.h"
#import "NetUtilities.h"
#import "Networking_Internal.h"

//CONSTANTS:

#define kMagic						0xABCD1234
#define kOpenedMax					3
#define DEBUG_RW					1


//STRUCTURE:

typedef struct {
	NSUInteger		magic;
	NSUInteger		length;
} Header; //NOTE: This header is in big-endian

//CLASS INTERFACES:

@interface TCPConnection (Internal)
- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output;
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream;
@end

//FUNCTIONS:

static void _ReadClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}

static void _WriteClientCallBack(CFWriteStreamRef stream, CFStreamEventType type, void* clientCallBackInfo)
{
	NSAutoreleasePool*		localPool = [NSAutoreleasePool new];
	
	[(TCPConnection*)clientCallBackInfo _handleStreamEvent:type forStream:stream];
	
	[localPool release];
}

//CLASS IMPLEMENTATION:

@implementation TCPConnection

//@synthesize delegate=_delegate;

-(id<TCPConnectionDelegate>) delegate
{
	return _delegate;
}


- (id) initWithSocketHandle:(int)socket
{
	CFReadStreamRef			readStream = NULL;
	CFWriteStreamRef		writeStream = NULL;
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, socket, &readStream, &writeStream);
	if(!readStream || !writeStream) {
		close(socket);
		if(readStream)
		CFRelease(readStream);
		if(writeStream)
		CFRelease(writeStream);
		[self release];
		return nil;
	}
	
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream);
	CFRelease(writeStream);
	
	return self;
}

- (id) initWithRemoteAddress:(const struct sockaddr*)address
{
	CFReadStreamRef			readStream = NULL;
	CFWriteStreamRef		writeStream = NULL;
	CFSocketSignature		signature;
	CFDataRef				data;
	
	data = (address ? CFDataCreate(kCFAllocatorDefault, (const UInt8*)address, address->sa_len) : NULL);
	if(data == NULL) {
		[self release];
		return nil;
	}
	
	signature.protocolFamily = PF_INET;
	signature.socketType = SOCK_STREAM;
	signature.protocol = IPPROTO_TCP;
	signature.address = data;
	CFStreamCreatePairWithPeerSocketSignature(kCFAllocatorDefault, &signature, &readStream, &writeStream);
	CFRelease(data);
	if(!readStream || !writeStream) {
		if(readStream)
		CFRelease(readStream);
		if(writeStream)
		CFRelease(writeStream);
		[self release];
		return nil;
	}
	
	self = [self _initWithRunLoop:[NSRunLoop currentRunLoop] readStream:readStream writeStream:writeStream];
	CFRelease(readStream);
	CFRelease(writeStream);
	
	return self;
}

- (id) _initWithRunLoop:(NSRunLoop*)runLoop readStream:(CFReadStreamRef)input writeStream:(CFWriteStreamRef)output
{
	CFStreamClientContext	context = {0, self, NULL, NULL, NULL};
	
	if((self = [super init])) {
		_inputStream = (CFReadStreamRef)CFRetain(input);
		_outputStream = (CFWriteStreamRef)CFRetain(output);
		_runLoop = runLoop;
		[_runLoop retain];
		
		CFReadStreamSetClient(_inputStream, kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _ReadClientCallBack, &context);
		CFReadStreamScheduleWithRunLoop(_inputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		CFWriteStreamSetClient(_outputStream, kCFStreamEventOpenCompleted | kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, _WriteClientCallBack, &context);
		CFWriteStreamScheduleWithRunLoop(_outputStream, [_runLoop getCFRunLoop], kCFRunLoopCommonModes);
		
		if(!CFReadStreamOpen(_inputStream) || !CFWriteStreamOpen(_outputStream)) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) dealloc
{	
	[self invalidate];
	
	if(_localAddress)
	free(_localAddress);
	if(_remoteAddress)
	free(_remoteAddress);
	
	[super dealloc];
}

- (void) setDelegate:(id<TCPConnectionDelegate>)delegate
{
	_delegate = delegate;
	
	SET_DELEGATE_METHOD_BIT(0, connectionDidFailOpening:);
	SET_DELEGATE_METHOD_BIT(1, connectionDidOpen:);
	SET_DELEGATE_METHOD_BIT(2, connectionDidClose:);
	SET_DELEGATE_METHOD_BIT(3, connection:didReceiveData:);
}

- (BOOL) isValid
{
	return ((_opened >= kOpenedMax) && !_invalidating ? YES : NO);
}

- (void) _invalidate
{
	if(_inputStream) {
		CFReadStreamSetClient(_inputStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(_inputStream);
		CFRelease(_inputStream);
		_inputStream = NULL;
	}
	
	if(_outputStream) {
		CFWriteStreamSetClient(_outputStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(_outputStream);
		CFRelease(_outputStream);
		_outputStream = NULL;
	}
	
	if(_runLoop) {
		[_runLoop release];
		_runLoop = nil;
	}
	
	if(_opened >= kOpenedMax) {
		if(TEST_DELEGATE_METHOD_BIT(2))
		[_delegate connectionDidClose:self];
		_opened = 0;
	}
	else if(TEST_DELEGATE_METHOD_BIT(0))
	[_delegate connectionDidFailOpening:self];
}

- (void) invalidate
{
	if(_invalidating == NO) {
		_invalidating = YES;
		
		[self _invalidate];
	}
}

#define MAX_WRITE_SIZE		1024
- (BOOL) _writeData:(NSData*)data
{
	CFIndex					length = [data length],
							result;
	Header					header;
	
	header.magic = NSSwapHostIntToBig(kMagic);
	header.length = NSSwapHostIntToBig(length);
#if DEBUG_RW
	NSLog(@"trying to write header, %ld bytes...", sizeof(Header));
#endif
	result = CFWriteStreamWrite(_outputStream, (const UInt8*)&header, sizeof(Header));
	if(result != sizeof(Header)) {
		REPORT_ERROR(@"Wrote only %i bytes out of %i bytes in header", (int)result, (int)sizeof(Header));
		return NO;
	}
#if DEBUG_RW
	NSLog(@"wrote %d bytes", (int)result);
#endif
	
	int left = length;
	
	while(left > 0) {
		int sz = (left > MAX_WRITE_SIZE) ? MAX_WRITE_SIZE : left;
#if DEBUG_RW
		NSLog(@"trying to write %d (wrote %ld so far out of %ld total) bytes...", sz, length-left, length);
#endif
		result = CFWriteStreamWrite(_outputStream, (UInt8*)[data bytes] + [data length] - left, sz);
		if(result <= 0) {
			REPORT_ERROR(@"Wrote only %i bytes out of %i (%i) bytes in data", (int)result, (int)left, [data length]);
			return NO;
		}
#if DEBUG_RW
		NSLog(@"wrote %d bytes", (int)result);
#endif
		left -= result;
	}
	
	return YES;
}
#define MAX_READ_SIZE		1024
- (NSData*) _readData
{
	NSMutableData*			data;
	CFIndex					result,
							length;
	Header					header;
	
#if DEBUG_RW
	NSLog(@"trying to read header, %ld bytes...", sizeof(Header));
#endif
	result = CFReadStreamRead(_inputStream, (UInt8*)&header, sizeof(Header));
#if DEBUG_RW
	NSLog(@"read %ld bytes", result);
#endif
	if(result == 0)
	return (id)kCFNull;
	if(result != sizeof(Header)) {
		REPORT_ERROR(@"Read only %i bytes out of %i bytes in header", (int)result, (int)sizeof(Header));
		return nil;
	}
	UInt32 m = NSSwapBigIntToHost(header.magic);
	if(m != kMagic) {
		REPORT_ERROR(@"Invalid header", NULL);
		return nil;
	}
	
	length = NSSwapBigIntToHost(header.length);
	data = [NSMutableData dataWithCapacity:length];
	[data setLength:length];
	
	int left = length;
	while(left > 0) {
		int sz = (left > MAX_READ_SIZE) ? MAX_READ_SIZE : left;
#if DEBUG_RW
		NSLog(@"trying to read %d bytes (%ld bytes so far out of %ld)...", sz, length-left, length);
#endif
		result = CFReadStreamRead(_inputStream, (UInt8*)[data mutableBytes] + [data length] - left, sz);
		if(result <= 0) {
			REPORT_ERROR(@"Read only %i bytes out of %i (%i) bytes in data", (int)result, (int)left, [data length]);
			return nil;
		}
#if DEBUG_RW
		NSLog(@"read %ld bytes", result);
#endif
		left -= result;
	}
	
	return data;
}

- (void) _initializeConnection:(CFTypeRef)stream
{
	int						value = 1;
	CFDataRef				data;
	CFSocketNativeHandle	socket;
	socklen_t				length;
	
	if((data = (CFDataRef)(CFGetTypeID(stream) == CFWriteStreamGetTypeID() ? CFWriteStreamCopyProperty((CFWriteStreamRef)stream, kCFStreamPropertySocketNativeHandle) : CFReadStreamCopyProperty((CFReadStreamRef)stream, kCFStreamPropertySocketNativeHandle)))) {
		CFDataGetBytes(data, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8*)&socket);
		value = 1;
		setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &value, sizeof(value));
		value = sizeof(Header);
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		setsockopt(socket, SOL_SOCKET, SO_SNDLOWAT, &value, sizeof(value));
		CFRelease(data);
		
		length = SOCK_MAXADDRLEN;
		_localAddress = (struct sockaddr*) malloc(length);
		if(getsockname(socket, _localAddress, &length) < 0) {
			free(_localAddress);
			_localAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve local address (%i)", errno);
		}
		length = SOCK_MAXADDRLEN;
		_remoteAddress = (struct sockaddr*) malloc(length);
		if(getpeername(socket, _remoteAddress, &length) < 0) {
			free(_remoteAddress);
			_remoteAddress = NULL;
			REPORT_ERROR(@"Unable to retrieve remote address (%i)", errno);
		}
		
		if(TEST_DELEGATE_METHOD_BIT(1))
		[_delegate connectionDidOpen:self]; //NOTE: Connection may have been invalidated after this call!
	}
	else
	[NSException raise:NSInternalInconsistencyException format:@"Unable to retrieve socket from CF stream"];
}

/* Behavior notes regarding socket based CF streams:
- The connection is really ready once both input & output streams are opened and the output stream is writable
- The connection can receive a "has bytes available" notification before it's ready as defined above, in which case it should be ignored as there seems to be no bytes available to read anyway
*/
- (void) _handleStreamEvent:(CFStreamEventType)type forStream:(CFTypeRef)stream
{
	NSData*				data;
	CFStreamError		error;
	
	
	switch(type) {
		
		case kCFStreamEventOpenCompleted:
		if(_opened < kOpenedMax) {
			_opened += 1;
			if(_opened == kOpenedMax)
			[self _initializeConnection:stream];
		}
		break;
		
		case kCFStreamEventHasBytesAvailable: //NOTE: kCFStreamEventHasBytesAvailable will be sent for 0 bytes available to read when stream reaches end
		if(_opened >= kOpenedMax) {
			do {
				data = [self _readData];
				if(data != (id)kCFNull) {
					if(data == nil) {
						[self invalidate]; //NOTE: "self" might have been already de-alloced after this call!
						return;
					}
					else {
						if((_invalidating == NO) && TEST_DELEGATE_METHOD_BIT(3))
						[_delegate connection:(id)self didReceiveData:data]; //NOTE: Avoid type conflict with NSURLConnection delegate
					}
				}
			} while(!_invalidating && CFReadStreamHasBytesAvailable(_inputStream));
		}
		break;
		
		case kCFStreamEventCanAcceptBytes:
		if(_opened < kOpenedMax) {
			_opened += 1;
			if(_opened == kOpenedMax)
			[self _initializeConnection:stream];
		}
		break;
		
		case kCFStreamEventErrorOccurred:
		error = (CFGetTypeID(stream) == CFWriteStreamGetTypeID() ? CFWriteStreamGetError((CFWriteStreamRef)stream) : CFReadStreamGetError((CFReadStreamRef)stream));
		REPORT_ERROR(@"Error (%i) occured in CF stream", (int)error.error);
		case kCFStreamEventEndEncountered:
		[self invalidate];
		break;
				
	}
}

- (BOOL) hasDataAvailable
{
	if(![self isValid])
	return NO;
	
	return CFReadStreamHasBytesAvailable(_inputStream);
}

- (NSData*) receiveData
{
	NSData*				data;
	
	if(![self isValid])
	return nil;
	
	data = [self _readData];
	if(data == nil)
	[self invalidate];
	else if(data == (id)kCFNull)
	data = nil;
	
	return data;
}

- (BOOL) sendData:(NSData*)data
{
	if(![self isValid] || !data)
	return NO;
	
	if(![self _writeData:data]) {
		[self invalidate];
		return NO;
	}
	
	return YES;
}

- (UInt16) localPort
{
	if(_localAddress)
	switch(_localAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_localAddress)->sin_port);
		case AF_INET6: return ntohs(((struct sockaddr_in6*)_localAddress)->sin6_port);
	}
	
	return 0;
}

- (UInt32) localIPv4Address
{
	return (_localAddress && (_localAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_localAddress)->sin_addr.s_addr : 0);
}

- (UInt16) remotePort
{
	if(_remoteAddress)
	switch(_remoteAddress->sa_family) {
		case AF_INET: return ntohs(((struct sockaddr_in*)_remoteAddress)->sin_port);
	}
	
	return 0;
}

- (UInt32) remoteIPv4Address
{
	return (_remoteAddress && (_remoteAddress->sa_family == AF_INET) ? ((struct sockaddr_in*)_remoteAddress)->sin_addr.s_addr : 0);
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08lX | valid = %i | local address = %@ | remote address = %@>", [self class], (long)self, [self isValid], SockaddrToString(_localAddress), SockaddrToString(_remoteAddress)];
}

- (const struct sockaddr*) remoteSocketAddress
{
	return _remoteAddress;
}

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier {
	if (![identifier length])
    return nil;
    
    return [NSString stringWithFormat:@"_%@._tcp.", identifier];
}
@end


#if 0
@property(assign) id<TCPConnectionDelegate> delegate;

@property(readonly, getter=isValid) BOOL valid;
- (void) invalidate; //Close the connection

@property(readonly) UInt16 localPort;
@property(readonly) UInt32 localIPv4Address; //opaque (not an integer)
@property(readonly) UInt16 remotePort;
@property(readonly) UInt32 remoteIPv4Address; //opaque (not an integer)

@property(readonly) const struct sockaddr* remoteSocketAddress;
#endif
