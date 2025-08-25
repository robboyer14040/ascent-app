
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import "Typedefs.h"

//CLASS INTERFACES:

/*
This class acts a controller for a listening TCP port that accepts incoming connections.
You must subclass this class and override the -handleNewConnectionWithSocket:fromRemoteAddress: method.
You can also enable Bonjour advertising for the listening TCP port.
*/
@interface TCPService : NSObject <NSNetServiceDelegate>
{
@private
	UInt16				_port;
	NSRunLoop*			_runLoop;
	CFSocketRef			_ipv4Socket;
	NSNetService*		_netService;
	BOOL				_running;
	struct sockaddr*	_localAddress;
}
- (id) initWithPort:(UInt16)port; //Pass 0 to have a port automatically be chosen

- (BOOL) startUsingRunLoop:(NSRunLoop*)runLoop;
- (void) stop;
- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name; //Pass "nil" for the default local domain - Pass only the application protocol for "protocol" e.g. "myApp"
- (void) disableBonjour;
- (void) handleNewConnectionWithSocket:(NSSocketNativeHandle)socket fromRemoteAddress:(const struct sockaddr*)address; //To be implemented by subclasses

#if 0
@property(readonly, getter=isRunning) BOOL running;
@property(readonly) UInt16 localPort; //Only valid when running
@property(readonly) UInt32 localIPv4Address; //Only valid when running - opaque (not an integer)
@property(readonly, getter=isBonjourEnabled) BOOL bonjourEnabled;
#else
-(BOOL) isRunning;
-(UInt16) localPort; //Only valid when running
-(UInt32) localIPv4Address; //Only valid when running - opaque (not an integer)
-(BOOL) isBonjourEnabled;
#endif

@end
