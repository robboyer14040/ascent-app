//
//  SelectAndApplyActionController.h
//  Ascent
//
//  Created by Rob Boyer on 11/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;
@class TopDataPointFilterItem;

@interface SelectAndApplyActionController : NSWindowController 
{
	IBOutlet NSPopUpButton*		fieldTypePopup;
	IBOutlet NSPopUpButton*		selectionCriteriaPopup;
	IBOutlet NSTextField*		selectionValueField;
	IBOutlet NSPopUpButton*		actionTypePopup;
	IBOutlet NSTextField*		actionValueField;
	IBOutlet NSTextField*		descriptionField;
	IBOutlet NSButton*			applyButton;
	IBOutlet NSButton*			applyOnlyToSelectedButton;
	NSMutableArray*				trackPoints;
	NSMutableDictionary*		topItems;
	NSMutableDictionary*		defaultsDict;
	TopDataPointFilterItem*		topItem;
	NSString*					lastTopItemKey;
	NSIndexSet*					selectedPointIndices;
	int							currentPointIndex;
	BOOL						useStatute;
	BOOL						useCentigrade;
	BOOL						isValid;
	BOOL						displayingPace;
	BOOL						applyToSelected;
}

-(IBAction)setPopUpValue:(id)sender;
-(IBAction)setTextFieldValue:(id)sender;
-(IBAction)apply:(id)sender;
-(IBAction)cancel:(id)sender;
-(IBAction)applyOnlyToSelected:(id)sender;

- (id) initWithTrack:(Track*)tr selected:(NSIndexSet*)spi displayingPace:(BOOL)dp;
- (NSMutableArray*) newPoints;


@end
