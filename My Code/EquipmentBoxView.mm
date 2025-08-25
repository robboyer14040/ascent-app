//
//  EquipmentBoxView.mm
//  Ascent
//
//  Created by Rob Boyer on 1/30/10.
//  Copyright 2010 Montebello Software, LLC. All rights reserved.
//

#import "EquipmentBoxView.h"
#import "EquipmentLog.h"
#import "EquipmentItem.h"


enum
{
	kNumVisibleItems	 = 4,
	
};

///static const float kButtonWidth = 31.0;
static const float kButtonHeight = 31.0;
static const float kMarginWidth = 1.0;
///static const float kHorizSpacing = 0.0;
static const float kVertSpacing = 0.0;
#define FONT_SIZE		11.0


@interface EquipmentBoxView ()
-(IBAction)equipmentButtonPushed:(id)sender;
@end;

@implementation EquipmentBoxView

@synthesize track;
@synthesize equipmentButtonAction;


- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        track = nil;
	}
    return self;
}



-(void)setEquipmentButtonAction:(NSInvocation*)inv
{
	if (inv != equipmentButtonAction)
	{
		equipmentButtonAction = inv;
	}
}


-(void)awakeFromNib
{
	self.equipmentButtonAction = nil;
	equipmentItemsForTrack = nil;
	track = nil;
	buttons = [[NSMutableArray arrayWithCapacity:kNumVisibleItems] retain];
 	
	[self setBoxType:NSBoxPrimary];
	[self setTitle:@"Equipment"];
	[self setBorderType:NSBezelBorder];
	[self setTransparent:NO];
	[self setHidden:NO];
	NSView* view = [self contentView];
	NSRect bounds = [view bounds];
	int yint = bounds.size.height - kButtonHeight - 1.0;
	float y = (float)yint;		// no fractional pixels!
	for (int i=0; i<kNumVisibleItems; i++)
	{
		NSRect r;
		r.origin.x = kMarginWidth;
		r.origin.y = y;
		r.size.width = bounds.size.width - 4.0;
		r.size.height = kButtonHeight;
		NSButton* b = [[NSButton alloc] initWithFrame:r];
		[b setButtonType:NSMomentaryPushInButton];
		[b setBezelStyle:NSRegularSquareBezelStyle];
		[b setImagePosition:NSImageLeft];
		[b setAlignment:NSTextAlignmentLeft];
		[[b cell] setImageScaling:NSImageScaleProportionallyDown];
		[b setTitle:@""];
		[b setHidden:YES];
		[b setTag:i];
		[b setAction:@selector(equipmentButtonPushed:)];
		[b setTarget:self];
		[b setAutoresizingMask:NSViewWidthSizable];
		[view addSubview:b];
		[buttons addObject:b];
		y -= (kButtonHeight + kVertSpacing);
	}
}

-(void)dealloc
{
    [buttons release];
}


-(void)update
{
	if (!track) return;
	equipmentItemsForTrack = [[EquipmentLog sharedInstance] equipmentItemsForTrack:track];
	int idx = 0;
		for (EquipmentItem* ei in equipmentItemsForTrack)
	{
		if (idx < [buttons count])
		{
			NSButton* b = [buttons objectAtIndex:idx];
			if (b)
			{
				NSImage* img = [[NSImage alloc] initWithContentsOfFile:[ei valueForKey:@"imagePath"]];
				[b setImage:img];
				[b setAlternateImage:img];
				[b setHidden:NO];
				[b setTitle:[ei name]];
			}
			++idx;
		}
	}
	for (int i=idx; i<kNumVisibleItems; i++)
	{
		NSButton* b = [buttons objectAtIndex:i];
		if (b) [b setHidden:YES];
	}
}


-(void)setTrack:(Track*)t
{
	if (t != track)
	{
		track = t;
	}
	[self update];
}


- (void)drawRect:(NSRect)dirtyRect 
{
	[super drawRect:dirtyRect];
}


-(IBAction)equipmentButtonPushed:(id)sender
{
	int tag = [sender tag];
	if (tag >= 0 && tag < [equipmentItemsForTrack count])
	{
		EquipmentItem* ei = [equipmentItemsForTrack objectAtIndex:tag];
		NSString* uuid = [ei uniqueID];
		[equipmentButtonAction retainArguments];
		[equipmentButtonAction setArgument:&uuid 
									 atIndex:2];
		[equipmentButtonAction invoke];
		
	}
}
@end
