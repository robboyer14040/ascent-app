//
//  DBComm.h
//  Ascent
//
//  Created by Rob Boyer on 2/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>



@interface DBComm : NSObject 
{
	NSString*		userDBID;	
	void*			curlHandle;
}

- (int) createUser:(NSString*)name ident:(NSString*)ident password:(NSString*)pw birthdate:(NSDate*)bd maxhr:(float)mhr
			regkey:(NSString*)rkey homelat:(double)lat homelon:(double)lon;
- (int) loginUser:(NSString*)name email:(NSString*)em password:(NSString*)pw;
- (int) publishTracks:(NSArray*)tracks;
- (NSString *)userDBID;
- (void)setUserDBID:(NSString *)value;


@end
