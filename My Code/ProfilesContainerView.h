//
//  ProfilesContainerView.h
//  Ascent
//
//  Created by Rob Boyer on 4/10/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ProfilesContainerView : NSView
{
	NSString*				placeholderText;
	NSMutableDictionary*	textFontAttrs;
}
@property(nonatomic, retain) NSMutableDictionary* textFontAttrs;
@property(nonatomic, retain) NSString* placeholderText;
-(void)enablePlaceholderText:(BOOL)enable;
@end

