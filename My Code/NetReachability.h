
#import <Foundation/Foundation.h>
#import <sys/socket.h>

//CLASSES:

@class NetReachability;

//PROTOCOLS:

@protocol NetReachabilityDelegate <NSObject>
- (void) reachabilityDidUpdate:(NetReachability*)reachability reachable:(BOOL)reachable usingCell:(BOOL)usingCell;
@end

//CLASS INTERFACES:

/*
This class wraps the SCNetworkReachability APIs from SystemConfiguration, which tell you whether or not the system has a route to a given host.
Be aware that reachability doesn't guarantee you can get somewhere, it just lets you know when we can guarantee you won't get there.
If you only care about reachability of given host, use -initWithAddress:, -initWithIPv4Address: or -initWithHostName:.
If you care about reachability in general (i.e. is network active or not), use -initWithDefaultRoute:.
In both cases, use the "usingCell" parameter to know if reachability is achieved over WiFi or cell connection (e.g. Edge).
*/
@interface NetReachability : NSObject
{
@private
	void*						_netReachability;
	NSRunLoop*					_runLoop;
	id<NetReachabilityDelegate>	_delegate;
}
- (id) initWithDefaultRoute:(BOOL)ignoresAdHocWiFi; //If both Cell and Ad-Hoc WiFi are available and "ignoresAdHocWiFi" is YES, "usingCell" will still return YES

- (id) initWithAddress:(const struct sockaddr*)address;
- (id) initWithIPv4Address:(UInt32)address; //opaque (not an integer)
- (id) initWithHostName:(NSString*)name;

#if 0
@property(assign) id<NetReachabilityDelegate> delegate;
@property(readonly, getter=isReachable) BOOL reachable;
@property(readonly, getter=isUsingCell) BOOL usingCell; //Only valid if "isReachable" is YES
#else
-(id<NetReachabilityDelegate>) delegate;
-(void) setDelegate:(id<NetReachabilityDelegate>) del;
-(BOOL)isReachable;
-(BOOL)isUsingCell; //Only valid if "isReachable" is YES
#endif

@end
