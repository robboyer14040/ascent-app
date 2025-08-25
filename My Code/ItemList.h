//
//  ItemList.h
//  Ascent
//
//  Created by Rob Boyer on 11/5/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ItemList : NSObject 
{
   NSMutableArray*   itemArray;
}
- (void) addItem:(NSString*)name tag:(int)t;
- (NSString*) nameOfItemAtIndex:(int)idx;
- (int) tagOfItemAtIndex:(int)idx;
- (int) numItems;

@end
