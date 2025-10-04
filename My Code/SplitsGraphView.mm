//
//  SplitsGraphView.mm
//  Ascent
//
//  Created by Robert Boyer on 9/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SplitsGraphView.h"
#import "Utils.h"
#import "SplitTableItem.h"
#import "ColumnInfo.h"
#import "DrawingUtilities.h"
#import "ColorBoxView.h"

@interface MyTextFieldCell : NSTextFieldCell
{
}
@end

@implementation MyTextFieldCell

-(BOOL)isOpaque
{
	return NO;
}
@end



@implementation SplitsGraphView

- (void)_commonInit
{
    staticColumnInfo = [[SplitsTableStaticColumnInfo alloc] init];
    xAxisIsTime = NO;
    maxDist = 0.0;
    valueFontAttrs = [[NSMutableDictionary alloc] init];
    [valueFontAttrs setObject:[NSFont boldSystemFontOfSize:10] forKey:NSFontAttributeName];
    tickFontAttrs = [[NSMutableDictionary alloc] init];
    [tickFontAttrs setObject:[NSFont systemFontOfSize:6] forKey:NSFontAttributeName];
    selectedLapStartTime = selectedLapEndTime = -42.0;
    textFontAttrs = [[NSMutableDictionary alloc] init];
    [textFontAttrs setObject:[NSFont systemFontOfSize:18] forKey:NSFontAttributeName];
    [textFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"]
                      forKey:NSForegroundColorAttributeName];

    
    
    NSRect fr;
    fr.origin.x = fr.origin.y = 0.0;
    fr.size.width = 40.0;
    fr.size.height = 15.0;
    splitsTableView = nil;
    splitArray = nil;
    valueColorBox = [[ColorBoxView alloc] initWithFrame:fr];
    [valueColorBox setColor:[NSColor colorWithCalibratedRed:249.0/255.0
                                                      green:249.0/255.0
                                                       blue:19.0/255.0
                                                      alpha:1.0]];
    [valueColorBox setAlpha:0.5];
    [valueColorBox setHidden:YES];
    valueTextField = [[NSTextField alloc] initWithFrame:fr];
    //MyTextFieldCell* tcell = [[[MyTextFieldCell alloc] initTextCell:@""] autorelease];
    //[valueTextField setCell:tcell];
    [valueTextField setDrawsBackground:NO];
    [valueTextField setBezeled:NO];
    [valueTextField setEditable:NO];
    [valueTextField setHidden:YES];
    [valueTextField setAlignment:NSTextAlignmentCenter];
    [valueTextField setFont:[NSFont boldSystemFontOfSize:10]];
    [self addSubview:valueColorBox];
    [self addSubview:valueTextField];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(splitSelected:)
                                                 name:@"SplitSelected"
                                               object:nil];
}


- (instancetype)initWithFrame:(NSRect)r {
    if ((self = [super initWithFrame:r]))
        [self _commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super initWithCoder:c]))
        [self _commonInit];
    return self;
}



- (void)splitSelected:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [tickFontAttrs release];
    [textFontAttrs release];
    [valueColorBox release];
    [valueTextField release];
    [staticColumnInfo release];
    [super dealloc];
}


#define Y_AXIS_WIDTH		25
#define X_AXIS_HEIGHT		15

-(NSRect) drawBounds
{
	NSRect bds = [self bounds];
	bds.origin.x += Y_AXIS_WIDTH;
	bds.origin.y += X_AXIS_HEIGHT;
	bds.size.width -= (Y_AXIS_WIDTH + 3.0);
	bds.size.height -= (X_AXIS_HEIGHT + 3.0);
	return bds;
}


#define kNumHorizTickPoints    20


- (float) drawTickMarks:(ColumnInfo*)columnInfo maxValue:(float)max
{
	NSRect bounds = [self bounds];
	bounds.origin.x += Y_AXIS_WIDTH;
	bounds.size.width -= (Y_AXIS_WIDTH + 3.0);
	bounds.size.height -= 4.0;
	[tickFontAttrs setObject:[NSColor colorNamed:@"TextPrimary"] forKey:NSForegroundColorAttributeName];
	float incr;
	if (xAxisIsTime)
	{
		//NSRect tbounds = bounds;
		//int numHorizTicks = AdjustTimeRuler(kNumHorizTickPoints, 0.0, [currentTrack DURATION_METHOD], &incr);
		//float graphDur = numHorizTicks*incr;
		//tbounds.size.width = (graphDur*tbounds.size.width)/[currentTrack DURATION_METHOD];
		//DUDrawTickMarks(tbounds, (int)kHorizontal, 0.0, 0.0, [currentTrack DURATION_METHOD], numHorizTicks, tickFontAttrs, YES, 
		//				tbounds.origin.x + tbounds.size.width);
	}
	else
	{
		float tmxd = [Utils convertDistanceValue:maxDist];
		float tmnd = 0.0;
		int numHorizTicks = AdjustDistRuler(kNumHorizTickPoints, 0.0, tmxd-tmnd, &incr);
		NSRect tbounds = bounds;
		tbounds.size.width = (numHorizTicks*incr*tbounds.size.width)/(tmxd-tmnd);
		DUDrawTickMarks(tbounds, (int)kHorizontal, 0.0, 0.0, numHorizTicks*incr, numHorizTicks, tickFontAttrs, NO, 
						tbounds.origin.x + tbounds.size.width);
	}
	if (columnInfo)
	{
		//bounds.origin.x -= Y_AXIS_WIDTH;
		bounds.origin.y += X_AXIS_HEIGHT;
		bounds.size.height -= X_AXIS_HEIGHT;
		float min = 0.0;
		int flags = [columnInfo flags];
		int numVertTickPoints;
		int maxVertTicks = ((int)(bounds.size.height/20.0)) & 0xfffffffe;
		BOOL isTime = FLAG_IS_SET(flags, kUsePaceFormatter);
		if (FLAG_IS_SET(flags, KIsDeltaValue))
		{
			min = -max;
			numVertTickPoints = AdjustRuler(maxVertTicks/2, 0, max, &incr);
			if (min < 0)
			{
				max = numVertTickPoints*incr;
				min = -max;
			}
			else
			{
				max = numVertTickPoints*incr;
				min = 0.0;
			}
		}
		else
		{
			numVertTickPoints = AdjustRuler(maxVertTicks, 0, max, &incr);
			max = numVertTickPoints*incr;
		}
		DUDrawTickMarks(bounds, (int)kVerticalLeft, 0.0, min, max, numVertTickPoints*2, tickFontAttrs, isTime, 99999999999.0);
		NSString* leg = [columnInfo getLegend];
		NSSize sz = [leg sizeWithAttributes:tickFontAttrs];
		//if (kVerticalLeft == axis)
		{
			[leg drawAtPoint:NSMakePoint(bounds.origin.x + 0 - sz.width, bounds.origin.y - 12.0) withAttributes:tickFontAttrs];
		}
		//else
		//{
		//	[leg drawAtPoint:NSMakePoint(bounds.origin.x + bounds.size.width - 0 + 1.0, bounds.origin.y - 12.0) withAttributes:tickFontAttrs];
		//}
	}
	return max;
}


- (void)drawGraphItemType:(ColumnInfo*)columnInfo
{
	NSMutableDictionary *fontAttrs = [[[NSMutableDictionary alloc] init] autorelease];
	NSFont* font =  [NSFont fontWithName:@"Lucida Grande" size:9.0];
	[fontAttrs setObject:font forKey:NSFontAttributeName];
    [fontAttrs setObject:[NSColor colorNamed:@"TextPrimary"]
                  forKey:NSForegroundColorAttributeName];
	NSString* s = [columnInfo menuLabel];
	NSSize size = [s sizeWithAttributes:fontAttrs];
	NSRect bounds = [self drawBounds];
	float x = bounds.origin.x + bounds.size.width - (size.width + 4.0);
	float y = bounds.origin.y +  bounds.size.height - (size.height) + 2.0;
	[s drawAtPoint:NSMakePoint(x,y) withAttributes:fontAttrs];
}	


-(void)setColumnKey:(NSString*)key
{
	if (key != columnKey)
	{
		columnKey = key;
	}
}


-(NSString*)columnKey
{
	return columnKey;
}



- (void)drawRect:(NSRect)rect 
{
    [[NSColor colorNamed:@"BackgroundPrimary"] set];
	[NSBezierPath fillRect:[self bounds]];
	[[[NSColor colorNamed:@"TextPrimary"] colorWithAlphaComponent:0.6] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:[self bounds]];
    NSUInteger numSplits = splitArray ? [splitArray count] : 0;
	if (numSplits > 0)
    {
        SplitTableItem* ti = [splitArray objectAtIndex:numSplits-1];
        maxDist = [ti cumulativeDistanceInMiles] + [ti deltaDistanceInMiles];
        NSRect drawBounds = [self drawBounds];
        int numPossible = [staticColumnInfo numPossibleColumns];
        if (!IS_BETWEEN(0, graphItem, numPossible-1)) graphItem = 0;
        ColumnInfo* columnInfo = [[[ColumnInfo alloc] initWithInfo:[staticColumnInfo nthPossibleColumnInfo:graphItem]] autorelease];
        if (maxDist > 0.0)
        {
            int colFlags = [columnInfo flags];
            if (!FLAG_IS_SET(colFlags, kNotAValidSplitGraphItem))
            {
                float pixelsPerMile = drawBounds.size.width/maxDist;
                float yBottom;
                float xLeft = drawBounds.origin.x;
                float ht;
                [[Utils colorFromDefaults:RCBDefaultAltitudeColor] set];
                if (FLAG_IS_SET(colFlags, KIsDeltaValue))
                {
                    yBottom = drawBounds.origin.y + drawBounds.size.height/2.0;
                    ht = drawBounds.size.height/2.0;
                    [NSBezierPath setDefaultLineWidth:1.0];
                    NSPoint pt1, pt2;
                    pt1.x = (int)drawBounds.origin.x;
                    pt1.y = (int)(yBottom);
                    pt2.x = (int)(drawBounds.origin.x + drawBounds.size.width);
                    pt2.y = pt1.y;
                    [NSBezierPath strokeLineFromPoint:pt1 toPoint:pt2];
                    
                }
                else
                {
                    yBottom = drawBounds.origin.y;
                    ht = drawBounds.size.height;
                }
                NSString* colIdent = [columnInfo ident];
                NSString* kvMax = [NSString stringWithFormat:@"@max.%@", colIdent];
                float max = [[splitArray valueForKeyPath:kvMax] floatValue];
                max = [self drawTickMarks:columnInfo
                                 maxValue:max];
                for (int i=0; i<numSplits; i++)
                {
                    SplitTableItem* sti = [splitArray objectAtIndex:i];
                    float value = [[sti valueForKey:colIdent] floatValue];
                    float rectWidth = [sti deltaDistanceInMiles]*pixelsPerMile;
                    if (max != 0.0)
                    {
                        NSRect r;
                        float valH = 0.0;
                        r.origin.x = xLeft;
                        r.size.width = rectWidth;
                        valH = ((value * ht)/max);
                        if (valH < 0.0)
                        {
                            r.origin.y = yBottom + valH;
                            if (r.origin.y < drawBounds.origin.y)
                            {
                                float extra = drawBounds.origin.y - r.origin.y;
                                r.origin.y = drawBounds.origin.y;
                                valH += extra;
                            }
                            r.size.height = -valH;
                        }
                        else
                        {
                            r.origin.y = yBottom;
                            r.size.height = valH;
                        }
                        [[NSColor colorNamed:@"TextPrimary"] set];
                        [NSBezierPath setDefaultLineWidth:0.5];
                        [NSBezierPath strokeRect:r];
                        [sti setTrackingRect:r];
                        //printf("sti split time:%0.1f, lap start, end: %0.1f, %01.f\n", [sti splitTime], selectedLapStartTime, selectedLapEndTime);
                        if ([sti selected])
                        {
                            [[[Utils colorFromDefaults:RCBDefaultSplitColor] colorWithAlphaComponent:.9] set];
                        }
                        else if (IS_BETWEEN(selectedLapStartTime, [sti splitTime], selectedLapEndTime ))
                        {
                            [[[Utils colorFromDefaults:RCBDefaultLapColor] colorWithAlphaComponent:.5] set];
                        }
                        else
                        {
                            [[Utils colorFromDefaults:RCBDefaultAltitudeColor] set];
                        }
                        [NSBezierPath fillRect:r];
                    }
                    xLeft += rectWidth;
                }
            }
            [self drawGraphItemType:columnInfo];
        }
        else
        {
            NSRect dbounds = [self bounds];
            NSString* s = splitArray ? @"No Split Data" : @"No Activity Selected";
            NSSize size = [s sizeWithAttributes:textFontAttrs];
            float x = dbounds.origin.x + dbounds.size.width/2.0 - size.width/2.0;
            float y = (dbounds.size.height/2.0) - (size.height/2.0);
            [textFontAttrs setObject:[[NSColor colorNamed:@"TextPrimary"] colorWithAlphaComponent:0.25] forKey:NSForegroundColorAttributeName];
            [s drawAtPoint:NSMakePoint(x,y)
            withAttributes:textFontAttrs];
        }
    }
}


- (NSArray *)splitArray
{
	return splitArray;
}


- (void)setSplitArray:(NSArray *)value  splitsTable:(SplitsTableView*)stv
{
	if (splitArray != value)
	{
		splitArray = value;
		maxDist = 0.0;
	}
	if (splitsTableView != stv)
	{
		splitsTableView =  [stv retain];
	}
	[self setNeedsDisplay:YES];
}


- (void)setSelectedLapTimes:(float)start end:(float)end
{
	selectedLapStartTime = start;
	selectedLapEndTime = end;
	[self setNeedsDisplay:YES];
}


- (int)graphItem
{
	return graphItem;
}


- (void)setGraphItem:(int)value
{
	graphItem = value;
	[self setNeedsDisplay:YES];
}


static NSInteger sLastIdx = -1;
static NSInteger sStartIdx = 0;

- (int) tableIndexAtDistance:(float)dist
{
	NSUInteger num = [splitArray count];
	for (int i=0; i<num; i++)
	{
		SplitTableItem* sti = [splitArray objectAtIndex:i];
		float low = [sti cumulativeDistanceInMiles];
		float high = low +  [sti deltaDistanceInMiles];
		if (IS_BETWEEN(low, dist, high))
		{
			return i;
		}
	}
	return -1;
}


- (void) doSelect:(NSEvent*) ev dragging:(BOOL)isDragging
{
	NSPoint evLoc = [ev locationInWindow];
	evLoc = [self convertPoint:evLoc fromView:nil];
	NSRect bounds = [self drawBounds];
	float w = bounds.size.width;
	if (w > 0.0)
	{
		float distPerPixel = maxDist/w;
		float clickDist = distPerPixel * (evLoc.x - bounds.origin.x);
		NSMutableIndexSet* selSet = [NSMutableIndexSet indexSet];
		NSInteger idx = [self tableIndexAtDistance:clickDist];
		if (idx >= 0)
		{
			NSInteger first, last;
			if (sLastIdx < 0)
			{
				sLastIdx = sStartIdx = idx;
			}
			if (idx > sStartIdx) 
			{
				first = sStartIdx; last = idx;
			}
			else
			{
				first = idx; last = sStartIdx;
			}
			for (NSInteger i=first; i<=last; i++)
			{
				[selSet addIndex:i];
			}
			sLastIdx = idx;
		}
		[splitArray makeObjectsPerformSelector:@selector(deselect)];
		idx = [selSet firstIndex];
		while (idx != NSNotFound)
		{
			[[splitArray objectAtIndex:idx] select];
			idx = [selSet indexGreaterThanIndex:idx];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SplitSelected" object:self];
	}
}	

- (void)mouseDown:(NSEvent*) ev
{
	if ([splitsTableView numberOfSelectedRows] > 0)
	{
		[splitArray makeObjectsPerformSelector:@selector(deselect)];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SplitSelected" object:self];
	}
	else
	{
		sLastIdx = -1;
		sStartIdx = 0;
		[self doSelect:ev dragging:NO];
	}
}

- (void)mouseDragged:(NSEvent*) ev 
{
	[self doSelect:ev dragging:YES];
}


- (void)mouseUp:(NSEvent*) ev
{
	sLastIdx = -1;
	sStartIdx = 0;
}



- (void)resetCursorRects
{
	[self addCursorRect:[self bounds]
				 cursor:[NSCursor crosshairCursor]];
}

-(void) resetTrackingRect
{
	if (trackingRect)
		[self removeTrackingRect:trackingRect];
	///NSRect b = [self bounds];
	//printf("rtr %0.1f x %0.1f\n", b.size.width, b.size.height);
	trackingRect = [self addTrackingRect:[self bounds]
								   owner:self
								userData:nil
							assumeInside:NO];
}


- (void)viewDidMoveToWindow {
	//printf("view did move to window\n");
}


-(SplitTableItem*)findSTI:(NSPoint)p
{
	NSUInteger num = [splitArray count];
	for (int i=0; i<num; i++)
	{
		SplitTableItem* sti = [splitArray objectAtIndex:i];
		NSRect r = [sti trackingRect];
		if (NSPointInRect(p, r))
		{
			return sti;
		}
	}
	return nil;
}


- (void)mouseEntered:(NSEvent *)theEvent
{
	//printf("mouse entered, %d\n", tag);
	[ [self window] setAcceptsMouseMovedEvents:YES];
    [ [self window] makeFirstResponder:self];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	//printf("mouse exited, %d\n", tag);
    [ [self window] setAcceptsMouseMovedEvents:NO];
	[valueColorBox setHidden:YES];
	[valueTextField setHidden:YES];
}




- (void)mouseMoved:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	NSPoint local_point = [self convertPoint:event_location fromView:nil];	
	//printf("mouse moved [%0.1f,%0.1f]\n", local_point.x, local_point.y);
	SplitTableItem* sti = [self findSTI:local_point];
	if (sti)
	{
		ColumnInfo* columnInfo = [[ColumnInfo alloc] initWithInfo:[staticColumnInfo nthPossibleColumnInfo:graphItem]];
		float value = [[sti valueForKey:[columnInfo ident]] floatValue];
		[valueTextField setFormatter:[columnInfo formatter]];
		[valueTextField setFloatValue:value];
		[valueTextField sizeToFit];
		NSString* s = [valueTextField stringValue];
		NSSize sz = [s sizeWithAttributes:valueFontAttrs];
		NSRect fr = [valueTextField frame];
		fr.size.width = sz.width + 15.0;
		fr.origin.x = local_point.x - (fr.size.width/2.0);
		fr.origin.y = local_point.y + 8.0;
		[valueColorBox setHidden:YES];
		[valueTextField setHidden:YES];
		[valueTextField setFrame:fr];
		[valueColorBox setFrame:fr];
		[valueColorBox setHidden:NO];
		[valueTextField setHidden:NO];
	}
	else
	{
		[valueColorBox setHidden:YES];
		[valueTextField setHidden:YES];
	}
}




@end
