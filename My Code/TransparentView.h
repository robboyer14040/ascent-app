//
//  TransparentView.h
//  Ascent
//
//  Created by Rob Boyer on 4/2/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TransparentView : NSView 
{
	NSInvocation*           mMouseDownInvocation;
	NSMutableDictionary*	textFontAttrs;
	NSString*				centeredText;
}

-(void) setMouseDownInvocation:(NSInvocation*)inv;
-(void) setCenteredText:(NSString*)s;

@end
