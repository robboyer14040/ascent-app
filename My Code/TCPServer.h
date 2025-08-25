
#import "TCPService.h"
#import "TCPConnection.h"
#import "Typedefs.h"

//CLASSES:

@class TCPServer, TCPServerConnection;

//PROTOCOLS:

@protocol TCPServerDelegate <NSObject>
@optional
- (void) serverDidStart:(TCPServer*)server;
- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name;
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;

- (BOOL) server:(TCPServer*)server shouldAcceptConnectionFromAddress:(const struct sockaddr*)address;
- (void) server:(TCPServer*)server didOpenConnection:(TCPServerConnection*)connection; //From this method, you typically set the delegate of the connection to be able to send & receive data through it
- (void) server:(TCPServer*)server didCloseConnection:(TCPServerConnection*)connection;

- (void) serverWillDisableBonjour:(TCPServer*)server;
- (void) serverWillStop:(TCPServer*)server;
@end

//CLASS INTERFACES:

/*
This subclass of TCPService implements a full TCP server which automatically maintains the list of active connections.
See TCPService.h for other methods.
*/
@interface TCPServer : TCPService
{
@private
	NSMutableSet*				_connections;
	id<TCPServerDelegate>		_delegate;
	NSUInteger					_delegateMethods;
}
+ (Class) connectionClass; //Must be a subclass of "TCPServerConnection"

#if 0
@property(readonly) NSArray* allConnections;
@property(assign) id<TCPServerDelegate> delegate;
#else
-(NSArray*) allConnections;
-(id<TCPServerDelegate>) delegate;
-(void) setDelegate:(id<TCPServerDelegate>)del;
#endif

@end

/*
Subclass of TCPConnection used by TCPServer for its connections.
*/
@interface TCPServerConnection : TCPConnection
{
@private
	TCPServer*			_server; //Not retained
}

#if 0
@property(readonly) TCPServer* server;
#else
-(TCPServer*) server;
#endif

@end
