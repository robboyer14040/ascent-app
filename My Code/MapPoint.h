//
//  MapPoint.h
//  TLP
//
//  Created by Rob Boyer on 7/16/06.
//  Copyright 2006 rcb Construction. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MapPoint : NSObject
{
   NSTimeInterval delta;
   float x,y,speed;
}
- (id) initWithPoint:(NSPoint)p time:(NSTimeInterval)dt speed:(float)s;
- (NSPoint) point;
- (float) x;
- (float) y;
- (float) speed;
- (NSTimeInterval) delta;

@end
