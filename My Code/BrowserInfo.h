//
//   BrowserInfo.h
//  Ascent
//
//  Created by Rob Boyer on 2/19/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BrowserInfo : NSObject 
{
   NSMutableDictionary*    colInfoDict;
   NSMutableDictionary*    splitsColInfoDict;
}

+ (void) initialize;
+ (BrowserInfo*) sharedInstance;


-(NSMutableDictionary*) colInfoDict;
-(void) setColInfoDict:(NSMutableDictionary*)dict;
-(NSMutableDictionary*) splitsColInfoDict;
-(void) setSplitsColInfoDict:(NSMutableDictionary*)dict;


@end
