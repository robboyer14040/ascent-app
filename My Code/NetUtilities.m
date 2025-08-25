
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>

#include "NetUtilities.h"

//FUNCTIONS:
#if 0
NSString* HostGetName()
{
	static NSString*				name = nil;
	
	if(name == nil) {
		name = [[[UIDevice currentDevice] name] copy];		
	}

	return name;
}
#endif

NSString* SockaddrToString(const struct sockaddr* address)
{
	if(address && address->sa_family == AF_INET) {
		const struct sockaddr_in* sin = (struct sockaddr_in*) address;
		return [NSString stringWithFormat:@"%@:%d", [NSString stringWithUTF8String:inet_ntoa(sin->sin_addr)], ntohs(sin->sin_port)];
	}
	
	return nil;
}
