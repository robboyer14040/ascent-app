#import <Foundation/Foundation.h>
#import "AscentClientProxy.h"
#import "Typedefs.h"


//CLASSES:

@class AscentServer, TCPServer;

//PROTOCOLS:

@protocol AscentServerDelegate <NSObject>
@optional
- (void) ascentServerDidStartAdvertisingToClients:(AscentServer*)server;
- (void) ascentServerWillStopAdvertisingToClients:(AscentServer*)server;

- (BOOL) ascentServer:(AscentServer*)server shouldAllowConnectionToClient:(AscentClientProxy*)client;
- (void) ascentServer:(AscentServer*)server didFailConnectingToClient:(AscentClientProxy*)client;
- (void) ascentServer:(AscentServer*)server didConnectToClient:(AscentClientProxy*)client;
- (void) ascentServer:(AscentServer*)server didReceiveData:(NSData*)data fromClient:(AscentClientProxy*)client;
- (void) ascentServer:(AscentServer*)server didDisconnectFromClient:(AscentClientProxy*)client;
@end

//CLASS INTERFACES:

@interface AscentServer : NSObject
{
@private
	NSString*					_name;
	id<AscentServerDelegate>	_delegate;
	NSUInteger					_delegateMethods;
	TCPServer*					_server;
	CFMutableDictionaryRef		_activeClients;
	NSMutableSet*				_connectedClients;
	
	BOOL						_advertising;
}
- (id) initWithName:(NSString*)name port:(UInt16)port; //The "name" can be "nil" - Pass 0 to have a port automatically be chosen
#if 0
@property(readonly) NSString* name;
@property(readonly) UInt16 port;
@property(assign) id<AscentServerDelegate> delegate;
@property(readonly, getter=isAdvertising) BOOL advertising;
@property(readonly) NSArray* connectedClients;
#else
-(NSString*) name;
-(UInt16) port;
-(id<AscentServerDelegate>) delegate;
-(void) setDelegate:(id<AscentServerDelegate>)del;
-(BOOL) isAdvertising;
-(NSArray*) connectedClients;
#endif


- (BOOL) startAdvertisingToClientsWithIdentifier:(NSString*)identifier; //The "identifier" must be unique to your game
- (void) stopAdvertisingToClients;
- (void) disconnectFromClient:(AscentClientProxy*)client;
- (BOOL) sendData:(NSData*)data toClient:(AscentClientProxy*)client;
- (BOOL) sendDataToAllClients:(NSData*)data;
@end
