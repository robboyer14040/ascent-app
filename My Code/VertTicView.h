//
//  VertTicView.h
//  Ascent
//
//  Created by Rob Boyer on 3/18/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SGView;

@interface VertTicView : NSView 
{
   NSMutableDictionary*    textAttrs; 
   NSMutableDictionary*    tickFontAttrs; 
   SGView*                 sgView;
   BOOL                    isLeft;
}

- (SGView *)sgView;
- (void)setSgView:(SGView *)value;
- (BOOL)isLeft;
- (void)setIsLeft:(BOOL)value;


@end
