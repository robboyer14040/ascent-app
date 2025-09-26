//
//  ActivityOutlineView.h
//  Ascent
//
//  Created by Rob Boyer on 11/20/06.
//  Copyright 2006 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MyTableHeaderView;
@class ColumnHelper;
@class TrackBrowserDocument;


@interface ActivityOutlineView : NSOutlineView 
{
	MyTableHeaderView*		tableHeaderView;
	ColumnHelper*			columnHelper;
	NSImage*				trackDragImage;
}

@property(nonatomic, retain) NSImage* trackDragImage;
@property(nonatomic, assign) TrackBrowserDocument *document;

- (void) rebuild;
- (BOOL) columnUsesStringCompare:(NSString*)colIdent;
-(void)prepareToDie;

@end
