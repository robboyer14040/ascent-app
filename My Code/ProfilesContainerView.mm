//
//  ProfilesContainerView.mm
//  Ascent
//
//  Created by Rob Boyer on 4/10/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "ProfilesContainerView.h"
#import "CompareWindowController.h"
#import "Defs.h"
#import "Utils.h"

@implementation ProfilesContainerView

@synthesize textFontAttrs;
@synthesize placeholderText;


-(id) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) 
	{
		[self enablePlaceholderText:YES];
	}
	return self;
	
}

-(void)dealloc
{
	self.textFontAttrs = nil;
	self.placeholderText = nil;
}


- (void)awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObjects:ActivityDragType, nil]];
	NSFont* font = [NSFont systemFontOfSize:18];
	textFontAttrs = [[NSMutableDictionary alloc] init];
	[textFontAttrs setObject:font forKey:NSFontAttributeName];
	[textFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
}


-(void)enablePlaceholderText:(BOOL)enable
{
	if (enable)
	{
		self.placeholderText = @"Drag activities here from main browser";
	}
	else
	{
		self.placeholderText = nil;
	}
	[self.layer setNeedsDisplay];
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender 
{
    return NSDragOperationGeneric;
}


- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
	return YES;
}


- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	CompareWindowController* wc = (CompareWindowController*)[[self window] windowController];
	NSData* data = [pb dataForType:ActivityDragType];
	NSMutableArray* arr = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	[wc addTracksFromArrayOfTrackDates:arr];
	return YES;
}


- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
}


-(void)drawRect:(NSRect)fr
{
	NSRect bounds = [self bounds];
    [[NSColor colorNamed:@"BackgroundPrimary"] set];
    [NSBezierPath fillRect:bounds];
	[[[NSColor blackColor] colorWithAlphaComponent:0.6] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:bounds];
	
	if (self.placeholderText && ![self.placeholderText isEqualToString:@""])
	{
		NSSize size = [self.placeholderText sizeWithAttributes:textFontAttrs];
		float x = bounds.origin.x + bounds.size.width/2.0 - size.width/2.0;
		float y = (bounds.size.height/2.0) - (size.height/2.0);
		[textFontAttrs setObject:[[NSColor blackColor] colorWithAlphaComponent:0.20] forKey:NSForegroundColorAttributeName];
		[self.placeholderText drawAtPoint:NSMakePoint(x,y) 
						   withAttributes:textFontAttrs];
	}
}




@end

