//
//  ColorBoxView.h
//  TLP
//
//  Created by Rob Boyer on 10/1/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ColorBoxView : NSView 
{
	int   tag;
	float alpha;
	NSColor*	color;
}

-(NSInteger)tag;
-(void)setTag:(NSInteger)t;
-(void)setAlpha:(float)a;
-(void)setColor:(NSColor*)c;

@end
