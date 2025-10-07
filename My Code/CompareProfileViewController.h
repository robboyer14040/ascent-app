//
//  CompareProfileViewController.h
//  Ascent
//
//  Created by Rob Boyer on 3/5/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AscentAnimationTargetProtocol.h"


@class ActivityDetailView;
@class Track;
@class CWTransparentView;
@class CWTransparentWindow;

@interface CompareProfileViewController : NSObject <AscentAnimationTarget>
{
	ActivityDetailView*					adView;
	CWTransparentView*		transparentView;
	CWTransparentWindow*	transparentWindow;
	Track*					track;
	int						lapOffset;
}
@property (retain, nonatomic) ActivityDetailView* adView;
@property (retain, nonatomic) CWTransparentView* transparentView;
@property (retain, nonatomic) CWTransparentWindow* transparentWindow;
@property (retain, nonatomic) Track* track;
@property (nonatomic) int lapOffset;

-(id)initWithTrack:(Track*)t profileView:(ActivityDetailView*)av transparentView:(CWTransparentView*)tv transparentWindow:(CWTransparentWindow*)tw;
-(BOOL)isFocused;

@end
