
#import "TCPConnection.h"
#import "AscentClientProxy.h"

//MACROS:

/* Generic error reporting */
#define REPORT_ERROR(__FORMAT__, ...) printf("%s: %s\n", __FUNCTION__, [[NSString stringWithFormat:__FORMAT__, __VA_ARGS__] UTF8String])

/* Optional delegate methods support */
#ifndef __DELEGATE_IVAR__
#define __DELEGATE_IVAR__ _delegate
#endif
#ifndef __DELEGATE_METHODS_IVAR__
#define __DELEGATE_METHODS_IVAR__ _delegateMethods
#endif
#define TEST_DELEGATE_METHOD_BIT(__BIT__) (self->__DELEGATE_METHODS_IVAR__ & (1 << __BIT__))
#define SET_DELEGATE_METHOD_BIT(__BIT__, __NAME__) { if([self->__DELEGATE_IVAR__ respondsToSelector:@selector(__NAME__)]) self->__DELEGATE_METHODS_IVAR__ |= (1 << __BIT__); else self->__DELEGATE_METHODS_IVAR__ &= ~(1 << __BIT__); }

//CLASS INTERFACES:

@interface TCPConnection ()
- (void) _invalidate; //For subclasses
@end

//PROTOCOLS:

@protocol AscentClientProxyDelegate <NSObject>
- (NSString*) ascentClientProxyWillSendName:(AscentClientProxy*)peer;
- (void) ascentClientProxyDidFailConnecting:(AscentClientProxy*)peer;
- (void) ascentClientProxyDidConnect:(AscentClientProxy*)peer;
- (void) ascentClientProxyDidDisconnect:(AscentClientProxy*)peer;
- (void) ascentClientProxy:(AscentClientProxy*)peer didReceiveData:(NSData*)data;
@end

//CLASS INTERFACES:

@interface AscentClientProxy ()

#if 0
@property(assign) id<AscentClientProxyDelegate> delegate;
@property(readonly) const struct sockaddr* socketAddress;
#endif

-(id<AscentClientProxyDelegate>) delegate;
-(void) setDelegate:(id<AscentClientProxyDelegate>)del;
-(const struct sockaddr*) socketAddress;

- (id) initWithNSNetService:(NSNetService*)netService; // netService must already be resolved
- (id) initWithName:(NSString*)name address:(const struct sockaddr*)address;
- (id) initWithConnection:(TCPConnection*)connection;
- (BOOL) connect;
- (BOOL) sendData:(NSData*)data;
- (void) disconnect;
@end
