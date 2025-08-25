//
//  ItemList.m
//  Ascent
//
//  Created by Rob Boyer on 11/5/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import "ItemList.h"
#import "Defs.h"

@interface Item : NSObject 
{
   NSString*   name;
   int         tag;
}
- (id) initWithInfo:(NSString*)name tag:(int)tg;
- (NSString*) name;
- (int) tag;

@end

@implementation Item

- (id) initWithInfo:(NSString*)n tag:(int)tg
{
   self = [super init];
   name = n;
   tag = tg;
   return self;
}

- (id) init
{
   return [self initWithInfo:@"" tag:0];
}

- (NSString*) name
{
   return name;
}

- (int) tag
{
   return tag;
}

- (void)dealloc
{

}


@end


@implementation ItemList

- (id) init
{
   itemArray = [[NSMutableArray alloc] init];
   return self;
}

- (void)dealloc
{
}


- (void) addItem:(NSString*)name tag:(int)t
{
	Item* it = [[Item alloc] initWithInfo:name tag:t];
	[itemArray addObject:it];
}


- (NSString*) nameOfItemAtIndex:(int)idx
{
   int count = [itemArray count];
   if (IS_BETWEEN(0,idx,(count-1)))
   {
      Item* it = [itemArray objectAtIndex:idx];
      return [it name];
   }
   return @"";
}


- (int) tagOfItemAtIndex:(int)idx
{
   int count = [itemArray count];
   if (IS_BETWEEN(0,idx,(count-1)))
   {
      Item* it = [itemArray objectAtIndex:idx];
      return [it tag];
   }
   return 0;
}


- (int) numItems
{
   return [itemArray count];
}



@end
