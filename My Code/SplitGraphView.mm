//
//  SplitGraphView.mm
//  Ascent
//
//  Created by Robert Boyer on 9/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SplitGraphView.h"
#import "Utils.h"
#import "SplitTableItem.h"
#import "ColumnInfo.h"
#import "DrawingUtilities.h"

@implementation SplitGraphView

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        staticColumnInfo = [[SplitsTableStaticColumnInfo alloc] init];
		xAxisIsTime = NO;
		maxDist = 0.0;
		NSFont* font = [NSFont systemFontOfSize:6];
		tickFontAttrs = [[NSMutableDictionary alloc] init];
		[tickFontAttrs setObject:font forKey:NSFontAttributeName];
		selectedLapStartTime = selectedLapEndTime = -42.0;
    }
    return self;
}


- (void)splitSelected:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
}


-(void) awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(splitSelected:)
												 name:@"SplitSelected"
											   object:nil];
}

- (void) dealloc
{
	[tickFontAttrs release];
	[staticColumnInfo release];
	[splitArray release];
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
	[tickFontAttrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
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
	}
	return max;
}


- (void)drawGraphItemType:(ColumnInfo*)columnInfo
{
	NSMutableDictionary *fontAttrs = [[[NSMutableDictionary alloc] init] autorelease];
	NSFont* font = [NSFont systemFontOfSize:9];
	[fontAttrs setObject:font forKey:NSFontAttributeName];
	NSString* s = [columnInfo menuLabel];
	NSSize size = [s sizeWithAttributes:fontAttrs];
	NSRect bounds = [self drawBounds];
	float x = bounds.origin.x + bounds.size.width - (size.width + 4.0);
	float y = bounds.origin.y +  bounds.size.height - (size.height);
	[[[NSColor blackColor] colorWithAlphaComponent:0.6] set];
	[s drawAtPoint:NSMakePoint(x,y) withAttributes:fontAttrs];
}	


- (void)drawRect:(NSRect)rect 
{
	[[Utils colorFromDefaults:RCBDefaultBackgroundColor] set];
	[NSBezierPath fillRect:[self bounds]];
	[[[NSColor blackColor] colorWithAlphaComponent:0.6] set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:[self bounds]];
	
	if (splitArray)
	{
		int numSplits = [splitArray count];
		if (numSplits >= 1)
		{
			int num = [splitArray count];
			if (num > 0)
			{
				SplitTableItem* ti = [splitArray objectAtIndex:num-1];
				maxDist = [ti cumulativeDistance] + [ti deltaDistance];
			}
			NSRect drawBounds = [self drawBounds];
			int numPossible = [staticColumnInfo numPossibleColumns];
			if (!IS_BETWEEN(0, graphItem, numPossible-1)) graphItem = 0;
			ColumnInfo* columnInfo = [[[ColumnInfo alloc] initWithInfo:[staticColumnInfo nthPossibleColumnInfo:graphItem]] autorelease];
			if (columnInfo)
			{
				int colFlags = [columnInfo flags];
				if (!FLAG_IS_SET(colFlags, kNotAValidSplitGraphItem))
				{
					float rectWidth = drawBounds.size.width/numSplits;
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
							[[NSColor blackColor] set];
							[NSBezierPath setDefaultLineWidth:0.5];
							[NSBezierPath strokeRect:r];
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
		}
	}
}


- (NSArray *)splitArray
{
	return splitArray;
}


- (void)setSplitArray:(NSArray *)value
{
	if (splitArray != value)
	{
		[splitArray release];
		splitArray = [value retain];
		maxDist = 0.0;
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



@end
