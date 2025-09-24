//
//   BrowserInfo.h
//  Ascent
//
//  Created by Rob Boyer on 2/19/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BrowserInfo : NSObject 
@property(nonatomic, retain) NSMutableDictionary* colInfoDict;
@property(nonatomic, retain) NSMutableDictionary* splitsColInfoDict;

+ (void) initialize;
+ (BrowserInfo*) sharedInstance;

@end
