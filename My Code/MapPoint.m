//
//  MapPoint.m
//  TLP
//
//  Created by Rob Boyer on 7/16/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import "MapPoint.h"


@implementation MapPoint

- (id) initWithPoint:(NSPoint)p time:(NSTimeInterval)dt speed:(float)sp
{
   self = [super init];
   x = p.x;
   y = p.y;
   speed = sp;
   delta = dt;
   return self;
}

- (id) init
{
   NSPoint p;
   p.x = 0.0; p.y = 0.0;
   return [self initWithPoint:p time:0.0 speed:0];
}

- (float) x
{
   return x;
}

- (float) y
{
   return y;
}


- (NSPoint) point
{
   NSPoint pt;
   pt.x = x;
   pt.y = y;
   return pt;
}


- (float) speed
{
   return speed;
}

- (NSTimeInterval) delta
{
   return delta;
}


- (void) dealloc
{
}

@end

