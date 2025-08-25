//
//  EquipmentBoxView.h
//  Ascent
//
//  Created by Rob Boyer on 1/30/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface EquipmentBoxView : NSBox 
{
	Track*				track;
	NSMutableArray*		buttons;
	NSInvocation*		equipmentButtonAction;
	NSArray*			equipmentItemsForTrack;
}
@property (nonatomic, retain) Track* track;
@property (nonatomic, retain) NSInvocation* equipmentButtonAction;

-(IBAction)equipmentButtonPushed:(id)sender;
-(void)update;

@end
