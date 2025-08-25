//
//  ColumnHelper.h
//  Ascent
//
//  Created by Robert Boyer on 9/28/07.
//  Copyright 2007 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;
@class MyTableHeaderView;
@class StaticColumnInfo;

@interface ColumnHelper : NSObject 
{
	NSTableView*			tableView;
	TrackBrowserDocument*	tbDocument;
	SEL						dictSelector;
	SEL						setDictSelector;
	StaticColumnInfo*		staticColumnInfo;
}


- (id)initWithTableView:(NSTableView*)view staticColInfo:(StaticColumnInfo*)sci dictSelector:(SEL)dictSel setDictSelector:(SEL)setDictSel;
- (void)rebuild;
- (BOOL)columnUsesStringCompare:(NSString*)colIdent;
- (void)columnResized:(NSNotification *)aNotification;
- (void)columnMoved:(NSNotification *)aNotification;


@end
