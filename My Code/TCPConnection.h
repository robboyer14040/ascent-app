
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import "Typedefs.h"


//CLASSES:

@class TCPConnection;

//PROTOCOLS:

@protocol TCPConnectionDelegate <NSObject>
@optional
- (void) connectionDidFailOpening:(TCPConnection*)connection;
- (void) connectionDidOpen:(TCPConnection*)connection;
- (void) connectionDidClose:(TCPConnection*)connection;

- (void) connection:(TCPConnection*)connection didReceiveData:(NSData*)data;
@end

//CLASS INTERFACES:

/*
This class acts as a controller for TCP based network connections.
The TCPConnection instance will use the current runloop at its time of creation.
*/
@interface TCPConnection : NSObject
{
@private
	CFReadStreamRef				_inputStream;
	CFWriteStreamRef			_outputStream;
	NSRunLoop*					_runLoop;
	id<TCPConnectionDelegate>	_delegate;
	NSUInteger					_delegateMethods;
	NSUInteger					_opened;
	struct sockaddr*			_localAddress;
	struct sockaddr*			_remoteAddress;
	BOOL						_invalidating;
}
- (id) initWithSocketHandle:(int)socket; //Acquires ownership of the socket
- (id) initWithRemoteAddress:(const struct sockaddr*)address;

-(id<TCPConnectionDelegate>) delegate;
-(void) setDelegate:(id<TCPConnectionDelegate>)del;

-(BOOL) isValid;
-(void) invalidate; //Close the connection
-(UInt16) localPort;
-(UInt32) localIPv4Address;
-(UInt16) remotePort;
-(UInt32) remoteIPv4Address;
-(const struct sockaddr*) remoteSocketAddress;

#if 0
@property(assign) id<TCPConnectionDelegate> delegate;
@property(readonly, getter=isValid) BOOL valid;
@property(readonly) UInt16 localPort;
@property(readonly) UInt32 localIPv4Address; //opaque (not an integer)
@property(readonly) UInt16 remotePort;
@property(readonly) UInt32 remoteIPv4Address; //opaque (not an integer)
@property(readonly) const struct sockaddr* remoteSocketAddress;
#endif

- (BOOL) sendData:(NSData*)data; //Blocking - Must be called from same thread the connection was created on
- (BOOL) hasDataAvailable; //Non-blocking - Must be called from same thread the connection was created on
- (NSData*) receiveData; //Blocking - Must be called from same thread the connection was created on

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier;
@end
