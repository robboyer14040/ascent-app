#import "SGView.h"
#import "Track.h"
#import "TrackBrowserDocument.h"
#import "Defs.h"
#import "Utils.h"
#import "DrawingUtilities.h"
#import "TypeInfo.h"

//---- Utility object for storing summary data -------
@interface SummaryData : NSObject
{
   @public
   float    values[kNumPlotTypes];
};

@end

@implementation SummaryData

-(id)init
{
   self = [super init];
   int i;
   for (i=0; i<kNumPlotTypes; i++) values[i] = 0.0;
   return self;
}

@end


//-----------------------------------------------------

@implementation SGView

-(void)savePlotTypeDefaults
{
   long enab = 0;
   int i;
   for (i=0; i<kNumPlotTypes; i++) 
   {
      TypeInfo* ti = [typeInfoArray objectAtIndex:i];
      if ([ti enabled])
      {
         enab |= (1 << i);
      }
   }
   [Utils setIntDefault:enab forKey:RCBDefaultSumPlotTypesEnabled];
}


-(void)restorePlotTypeDefaults
{
   long enab = [Utils intFromDefaults:RCBDefaultSumPlotTypesEnabled];
   int i;
   for (i=0; i<kNumPlotTypes; i++) 
   {
      [[typeInfoArray objectAtIndex:i] setEnabled:(((1 << i) & enab) != 0)];
   }
}


- (id)initWithFrame:(NSRect)frameRect
{
   tbDocument = nil;
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
	}
   dataDict  = [[NSMutableDictionary dictionaryWithCapacity:52] retain];
   typeInfoArray = [[NSMutableArray alloc] init];
   
   haveData = NO;
   int i;
   for (i=0; i<kNumPlotTypes; i++) 
   {
      TypeInfo* ti = [[TypeInfo alloc] init];
      [typeInfoArray addObject:ti];
   }

   TypeInfo* ti = [typeInfoArray objectAtIndex:kDistance];
   //[ti setEnabled:YES];
   [ti setColorKey:RCBDefaultDistanceColor];

   ti = [typeInfoArray objectAtIndex:kWeightPlot];
   [ti setIsAverage:YES];
   [ti setColorKey:RCBDefaultWeightColor];
   
   ti = [typeInfoArray objectAtIndex:kDuration];
   //[ti setEnabled:NO];
   [ti setIsTimeValue:YES];
   [ti setColorKey:RCBDefaultDurationColor];

   ti = [typeInfoArray objectAtIndex:kMovingDuration];
   //[ti setEnabled:YES];
   [ti setIsTimeValue:YES];
   [ti setIsMovingTimeValue:YES];
   [ti setSharedRulerPlot:kDuration];
   [ti setColorKey:RCBDefaultMovingDurationColor];
   
   ti = [typeInfoArray objectAtIndex:kAltitude];
   //[ti setEnabled:YES];
   [ti setColorKey:RCBDefaultAltitudeColor];
   
   ti = [typeInfoArray objectAtIndex:kAvgHeartrate];
   [ti setIsAverage:YES];
   [ti setColorKey:RCBDefaultHeartrateColor];
   
   ti = [typeInfoArray objectAtIndex:kAvgSpeed];
   [ti setIsAverage:YES];
   [ti setColorKey:RCBDefaultSpeedColor];

   ti = [typeInfoArray objectAtIndex:kAvgMovingSpeed];
   [ti setIsAverage:YES];
   [ti setIsMovingTimeValue:YES];
   [ti setColorKey:RCBDefaultMovingSpeedColor];
   [ti setSharedRulerPlot:kAvgSpeed];
   
   ti = [typeInfoArray objectAtIndex:kAvgPace];
   [ti setIsAverage:YES];
   [ti setIsTimeValue:YES];
   [ti setColorKey:RCBDefaultPaceColor];
   
   ti = [typeInfoArray objectAtIndex:kAvgMovingPace];
   [ti setIsAverage:YES];
   [ti setIsMovingTimeValue:YES];
   [ti setIsTimeValue:YES];
   [ti setColorKey:RCBDefaultMovingPaceColor];
   [ti setSharedRulerPlot:kAvgPace];
   
   ti = [typeInfoArray objectAtIndex:kAvgCadence];
   [ti setIsAverage:YES];
   [ti setColorKey:RCBDefaultCadenceColor];

   ti = [typeInfoArray objectAtIndex:kCalories];
   [ti setIsAverage:NO];
   [ti setColorKey:RCBDefaultCaloriesColor];
   
   [self restorePlotTypeDefaults];
   
   leftTickViewWidth = rightTickViewWidth = 0.0;
   plotUnits = kWeeks;
   graphType = kBarGraph;
   
   NSFont* font = [NSFont systemFontOfSize:10];
   textAttrs = [[NSMutableDictionary alloc] init];
   [textAttrs setObject:font forKey:NSFontAttributeName];
   
   font = [NSFont systemFontOfSize:8];
   tickFontAttrs = [[NSMutableDictionary alloc] init];
   [tickFontAttrs setObject:font forKey:NSFontAttributeName];

   return self;
}


- (void) dealloc
{
    [dataDict release];
#if DEBUG_LEAKS
   NSLog(@"Summary Graph view dealloc...rc:%d", [self retainCount]);
#endif
    [super dealloc];
}





-(void)enablePlotType:(int)pt on:(BOOL)isOn
{
   if (IS_BETWEEN(0, pt, kNumPlotTypes-1))
   {
      [[typeInfoArray objectAtIndex:pt] setEnabled:isOn];
      //typeInfo[pt].enabled = isOn;
      [self setNeedsDisplay:YES];
      [self savePlotTypeDefaults];
      
   }
}


-(BOOL)plotEnabled:(int)pt
{
   if (IS_BETWEEN(0, pt, kNumPlotTypes-1))
   {
      return [[typeInfoArray objectAtIndex:pt] enabled];
      //return typeInfo[pt].enabled;
   }
   return NO;
}


-(int)plotUnits
{
   return plotUnits;
}


-(void) setPlotUnits:(int)units
{
   plotUnits = units;
   haveData = NO;
   [self setNeedsDisplay:YES];
}


NSInteger compareDates(id dt1, id dt2, void* ctx)
{
   NSString* s1 = (NSString*) dt1;
   NSString* s2 = (NSString*) dt2;
   return [s1 compare:s2];
}


// generate dictionary that has keys that are weekly (mondays) or monthly dates, and summary data as dictionary values
- (void) calcData
{
   [dataDict removeAllObjects];
   if (nil != tbDocument)
   {
      NSArray* trackArray = [tbDocument trackArray];
      if (nil != trackArray)
      {
          NSUInteger numTracks = [trackArray count];
         int i;
         int weekStartDay = [Utils intFromDefaults:RCBDefaultWeekStartDay];
         NSCalendar* cal = [NSCalendar currentCalendar];
         NSCalendarDate *caldate;
         NSCalendarDate *firstDayOfWeekDate;
         NSString* key;
         for (i=0; i<numTracks; i++)
         {
            Track* track = [trackArray objectAtIndex:i];
            NSDate* d = [track creationTime];
            NSDateComponents* comps = [cal components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSWeekCalendarUnit|NSDayCalendarUnit)  fromDate:d];
            NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMT]];
            if (comps != nil)
            {
               // calculate the date for the monday of the week that the track was created
               caldate = [NSCalendarDate dateWithYear:[comps year] 
                                                month:[comps month] 
                                                  day:[comps day] 
                                                 hour:0 
                                               minute:0 
                                               second:0 
                                             timeZone:tz];
               
               int dayOfWeek = [caldate dayOfWeek];         // returns [0,6]
               if ((weekStartDay == 1) && (dayOfWeek == 0)) dayOfWeek = 7; // finagle for monday start
               int monday = [comps day] - dayOfWeek + weekStartDay;    // [comps day] returns 1-based day of month. 
               firstDayOfWeekDate = [NSCalendarDate dateWithYear:[comps year] 
                                                           month:[comps month] 
                                                             day:monday 
                                                            hour:0 
                                                          minute:0 
                                                          second:0 
                                                        timeZone:tz];
               // generate key depending on whether we're looking at months or weeks
               if (kWeeks == plotUnits)
               {
                  key = [firstDayOfWeekDate descriptionWithCalendarFormat:@"%Y-%m-%d"];
               }
               else
               {
                  key = [caldate descriptionWithCalendarFormat:@"%Y-%m"];
               }
               // accumulate weekly or monthly summary data
               SummaryData* sd = [dataDict objectForKey:key];
               if (sd == nil) 
               {
                  sd = [[SummaryData alloc] init];
                  [dataDict setObject:sd forKey:key];
               }
               sd->values[kDistance] += [track distance];
               float df = [track duration];
               float mdf = [track movingDuration];
               sd->values[kDuration] += df;
               sd->values[kMovingDuration] += mdf;
               sd->values[kAltitude]    += [track totalClimb];
               sd->values[kAvgHeartrate]  += ([track avgHeartrate] * df);
               sd->values[kAvgSpeed]  += ([track avgSpeed] * df);
               sd->values[kAvgMovingSpeed]  += ([track avgMovingSpeed] * mdf);
               sd->values[kAvgPace]  += (60.0 * [track avgPace] * df);     // must be in seconds
               sd->values[kAvgMovingPace]  += (60.0 * [track avgMovingPace] * mdf);    // must be in seconds
               sd->values[kAvgCadence] += ([track avgCadence] * df);
               sd->values[kWeightPlot] += ([track weight] * df);
               sd->values[kCalories] += [track calories];
            }
         }
      }
   }
   
   int i;
   for (i=0; i<kNumPlotTypes; i++) 
   {
      TypeInfo* ti = [typeInfoArray objectAtIndex:i];
      [ti setMaxValue:0.0];
   }
   NSEnumerator *enumerator = [dataDict objectEnumerator];
   id value;
   // calculate max values for scaling the bars
   while ((value = [enumerator nextObject])) 
   {
      SummaryData* sd = (SummaryData*)value;
      int j;
      for (j=0; j<kNumPlotTypes; j++)
      {
         TypeInfo* ti = [typeInfoArray objectAtIndex:j];
         if ([ti isAverage])
         {
            if ([ti isMovingTimeValue])
            {
               if (sd->values[kMovingDuration] != 0.0) sd->values[j] = sd->values[j]/sd->values[kMovingDuration];
            }
            else
            {
               if (sd->values[kDuration] != 0.0) sd->values[j] = sd->values[j]/sd->values[kDuration];
            }
         }
         
         if (sd->values[j] > [ti maxValue])
         {
            [ti setMaxValue:sd->values[j]];
          }
       }
   }
   haveData = YES;
}


- (void) drawBar:(NSRect)r color:(NSColor*)clr
{
   [clr setFill];
   [[NSBezierPath bezierPathWithRect:r] fill];
   [[NSColor blackColor] set];
   [NSBezierPath setDefaultLineWidth:1.0];
   [NSBezierPath strokeRect:r];
}


- (int) getNumPlotsEnabled
{
   int num = 0;
   int i;
   int numInArray = [typeInfoArray count];;
   for (i=0; i<numInArray; i++)
   {
      if ([[typeInfoArray objectAtIndex:i] enabled]) num++;
   }
   return num;
}


-(void) plotBarData:(NSRect)r
           value:(float)val 
            info:(TypeInfo*)ti 
{
   NSColor* clr = [Utils colorFromDefaults:[ti colorKey]];
   r.size.height = (val * [ti scaleFactor]);
   [self drawBar:r color:clr];
}


- (void) drawBarGraphDisplay:(NSArray*)theKeys pad:(NSSize)pad
{
 
   float xPad = pad.width;
   float yPad = pad.height;
   
   // calculate scaleFactors based on window height, and width of tick text based on max values
   int numTypes = [self getNumPlotsEnabled];
    NSUInteger numGroups = [theKeys count];
   NSPoint pt;
   pt.x = xPad;
   pt.y = yPad;
   float barWidth = 10.0;
   float groupSpacingWidth = 24.0;
   float groupWidth = ((numTypes*(barWidth+2)) + groupSpacingWidth);
   float totalWidth = xPad + (groupWidth*(float)numGroups);
   NSRect bounds = [self bounds];
   bounds.size.width = totalWidth;
   [self setFrame:bounds];
   [self setBounds:bounds];
     [[NSColor colorNamed:@"BackgroundPrimary"] set];
   [NSBezierPath fillRect:bounds];
   
   
   if (numTypes > 0)
   {
      NSRect r;
      // draw shaded background, alternating each group of items                    
      r.origin.x = pt.x;
      r.origin.y = 0;
      r.size.width = groupWidth;
      r.size.height = bounds.size.height;
      NSColor* shadeColor = [NSColor colorWithCalibratedRed:(167.0/255.0) green:(255.0/255.0) blue:(169.0/255.0) alpha:0.42];
      NSColor* fclr = shadeColor;
       NSColor* backgroundColor = nil;
       int i;
      for (i=0; i<numGroups; i++)
      {
         if ((i % 2) == 0)    // alternate shading/non-shading
            fclr = shadeColor;
         else
            fclr = backgroundColor;
         [fclr setFill];
         [[NSBezierPath bezierPathWithRect:r] fill];
         r.origin.x += groupWidth;
      }                  
      r.origin.x = pt.x + (groupSpacingWidth/2.0);
      r.origin.y = pt.y;
      r.size.width = barWidth;
      
      NSRect tickBounds = bounds;
      tickBounds.origin.x = pt.x;
      tickBounds.origin.y += yPad;
      tickBounds.size.height -= 2.0*yPad;
      // draw 'groups of bars together, representing a time interval (such as a week, or month)
      NSString* lastYear = @"";
      for (i=0; i<numGroups; i++)
      {
         BOOL last = (i == (numGroups-1));
         NSString* date = [theKeys objectAtIndex:i];
         SummaryData* sd = [dataDict objectForKey:date];
         // draw the text indicating the start of the time interval below the group of bars
         NSString* year = [date substringToIndex:4];
         NSString* day = [date substringFromIndex:5];
         NSSize stringSize = [day sizeWithAttributes:textAttrs];
         float stringPadX = ((numTypes*(barWidth+2)) - stringSize.width)/2.0;
         [day drawAtPoint:NSMakePoint(r.origin.x + stringPadX, 12.0) withAttributes:textAttrs];
         if ([year compare:lastYear] != NSOrderedSame)
         {
            [year drawAtPoint:NSMakePoint(r.origin.x + stringPadX, 2.0) withAttributes:textAttrs];
            lastYear = year;
         }
         // now, draw the bars, one for each type of data
         int j; 
         for (j=0; j < kNumPlotTypes; j++)
         {
            TypeInfo* ti = [typeInfoArray objectAtIndex:j];
            if ([ti enabled])
            {
               [self plotBarData:r
                           value:sd->values[j] 
                            info:ti ];
               r.origin.x += (barWidth+2);
             }
         }
         if (!last) r.origin.x += groupSpacingWidth;
      }
   }
}



- (void) drawLineGraphDisplay:(NSArray*)theKeys  pad:(NSSize)pad
{
   float xPad = pad.width;
   float yPad = pad.height;
   
   // calculate scaleFactors based on window height, and width of tick text based on max values
   int numTypes = [self getNumPlotsEnabled];
   int numPoints = [theKeys count];
   NSPoint pt;
   float spacingWidth = 40.0;
   pt.x = xPad;
   pt.y = yPad;
   float totalWidth = xPad + (spacingWidth*(float)numPoints);
   NSRect bounds = [self bounds];
   bounds.size.width = totalWidth + 20;
   [self setFrame:bounds];
   [self setBounds:bounds];
   
   
  /// NSColor* backgroundColor = [Utils colorFromDefaults:RCBDefaultBackgroundColor];
    [[NSColor colorNamed:@"BackgroundPrimary"] set];
   [NSBezierPath fillRect:bounds];
   
   
   if (numTypes > 0)
   {
      
      NSRect tickBounds = bounds;
      tickBounds.origin.x = pt.x;
      tickBounds.origin.y += yPad;
      tickBounds.size.height -= 2.0*yPad;

      pt.x = pt.x + (spacingWidth/2.0);
      NSString* lastYear = @"";
      int i;
     
      for (i=0; i<numPoints; i++)
      {
         BOOL last = (i == (numPoints-1));
         NSString* date = [theKeys objectAtIndex:i];
         SummaryData* sd = [dataDict objectForKey:date];
         // draw the text indicating the start of the time interval below the point
         NSString* year = [date substringToIndex:4];
         NSString* day = [date substringFromIndex:5];
         NSSize stringSize = [day sizeWithAttributes:textAttrs];
         float stringPadX = (spacingWidth - stringSize.width)/2.0;
         [day drawAtPoint:NSMakePoint(pt.x + stringPadX, 12.0) withAttributes:textAttrs];
         if ([year compare:lastYear] != NSOrderedSame)
         {
            [year drawAtPoint:NSMakePoint(pt.x + stringPadX, 2.0) withAttributes:textAttrs];
            lastYear = year;
         }
         // now, build the line segment, one for each type of data
         int j; 
         BOOL lineDrawn = NO;
         for (j=0; j < kNumPlotTypes; j++)
         {
            NSPoint lpt = pt;
            lpt.x += spacingWidth/2.0;
            TypeInfo* ti = [typeInfoArray objectAtIndex:j];
            if ([ti enabled])
            {
               lpt.y = yPad + (sd->values[j]  * [ti scaleFactor]);
               if ([ti path] == nil)
               {
                  NSBezierPath* path = [[NSBezierPath alloc] init];
                  [ti setPath:path];
                  [[ti path] moveToPoint:lpt];
               }
               else
               {
                  [[ti path] lineToPoint:lpt];
               }
               if (!lineDrawn)
               {
                  lineDrawn = YES;
                  NSColor* clr = [NSColor grayColor];
                  NSPoint pt1 = lpt;
                  NSPoint pt2 = lpt;
                  pt1.y = yPad;
                  pt2.y = bounds.size.height - yPad;
                  [clr set];
                  [NSBezierPath strokeLineFromPoint:pt1 toPoint:pt2];
               }
               if (last) 
               {
                  NSColor* clr = [Utils colorFromDefaults:[ti colorKey]];
                  [clr set];
                  [[ti path] setLineWidth:3.0];
                  [[ti path] setLineJoinStyle:NSLineJoinStyleRound];
                  [[ti path] stroke];
                  //offset = [self drawTickMarks:ti
                  //                        type:j
                  //                      bounds:tickBounds
                  //                     xOffset:offset];
                  [ti setPath:nil];
               }
            }
         }
         pt.x += spacingWidth;
      }
   }
}


- (void)drawRect:(NSRect)rect
{
	if (!haveData) [self calcData];
	NSColor* backgroundColor = [[self window] backgroundColor];
	[backgroundColor set];
	[NSBezierPath fillRect:[self bounds]];
	TypeInfo* tid = [typeInfoArray objectAtIndex:kDistance];
	if (0.0 < [tid maxValue])
	{
		// get the keys, and sort them by date
		NSArray* keys = [dataDict allKeys];
        NSUInteger numGroups = [keys count];
		NSMutableArray* theKeys = [NSMutableArray arrayWithCapacity:numGroups];
		[theKeys addObjectsFromArray:keys]; 
		[theKeys sortUsingFunction:compareDates context:nil];


		leftTickViewWidth = rightTickViewWidth = 0.0;
		float xPad =  0.0;      // amount of space above and below bar graphs
		float yPad = 30.0;      // amount of space above and below bar graphs
		NSRect bounds = [self bounds];
		float h = bounds.size.height - (2*yPad);
		int i;
		int ctr = 0;
		for (i=0; i<kNumPlotTypes; i++)
		{
			TypeInfo* ti = [typeInfoArray objectAtIndex:i];
			[ti setPath:nil];
			if ([ti enabled])
			{
				float incr;
				BOOL useStatuteUnits = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
				float tempMax;
				if ([ti isTimeValue]) 
				{
					BOOL isPace = (i==kAvgPace)||(i==kAvgMovingPace);
					if (isPace)
					{
						tempMax = [Utils convertPaceValue:[ti maxValue]];		
					}
					else
					{
						tempMax = [ti maxValue];
					}
					[ti setNumTicks:AdjustTimeRuler(20, 0,  tempMax, &incr)];
					if (!useStatuteUnits && isPace) incr = MPKToMPM(incr);
				}
				else
				{
					switch (i)
					{
						case kAltitude:
							tempMax = [Utils convertClimbValue:[ti maxValue]];
							[ti setNumTicks:AdjustRuler(20, 0, tempMax, &incr)];
							if (!useStatuteUnits) incr = MetersToFeet(incr);
							break;
					 
						case kAvgSpeed:
						case kAvgMovingSpeed:
						case kSpeed:
						case kDistance:
							tempMax = [Utils convertSpeedValue:[ti maxValue]];
							[ti setNumTicks:AdjustRuler(20, 0, tempMax, &incr)];
							if (!useStatuteUnits) incr = KilometersToMiles(incr);
							break;

						case kWeightPlot:
							tempMax = [Utils convertWeightValue:[ti maxValue]];
							[ti setNumTicks:AdjustRuler(20, 0, tempMax, &incr)];
							if (!useStatuteUnits) incr = KilogramsToPounds(incr);
							break;

						default:
							[ti setNumTicks:AdjustRuler(20, 0, [ti maxValue], &incr)];
							break;
					}
				}	
				[ti setMaxTickValue:([ti numTicks] * incr)];
				[ti setScaleFactor:[ti maxTickValue] > 0.0 ? h/[ti maxTickValue] : 0.0];
				[ti setMaxValueTextWidth:TickTextWidth([ti maxTickValue], tickFontAttrs, [ti isTimeValue])] ;
				tPlotType shared = [ti sharedRulerPlot];
				BOOL skip = NO;
				if (shared != kReserved)
				{
					TypeInfo* sti = [typeInfoArray objectAtIndex:shared];
					if ((sti != nil) && ([sti enabled]))
					{
						if ([ti maxTickValue] > [sti maxTickValue])
						{
							[sti setMaxTickValue:[ti maxTickValue]];
							[sti setScaleFactor:[ti scaleFactor]];
							[sti setMaxValueTextWidth:[ti maxValueTextWidth]];
							[sti setNumTicks:[ti numTicks]];
						}
						else
						{
							[ti setMaxTickValue:[sti maxTickValue]];
							[ti setScaleFactor:[sti scaleFactor]];
							[ti setMaxValueTextWidth:[sti maxValueTextWidth]];
							[ti setNumTicks:[sti numTicks]];
						}
						skip = YES;
					}
				}
				if (skip == NO)
				{
					if ((ctr % 2) == 0)
					{
						leftTickViewWidth += [ti maxValueTextWidth]+2;
					}
					else
					{
						rightTickViewWidth += [ti maxValueTextWidth]+2;
					}
					++ctr;
				}
			}
		}
		NSRect windowFrame = [[self window] frame];
		NSScrollView* sv = [self enclosingScrollView];
		bounds = [sv frame];
		float scrollWidth = windowFrame.size.width - ((leftTickViewWidth + rightTickViewWidth) + 48);
		bounds.size.width = scrollWidth;
		bounds.origin.x = leftTickViewWidth + 24;
		[sv setFrame:bounds];
		bounds = [sv bounds];
		bounds.size.width = scrollWidth;
		[sv setBounds:bounds];
		NSSize padSize;
		padSize.width = xPad; padSize.height = yPad;

		switch (graphType)
		{
			case kBarGraph:
				[self drawBarGraphDisplay:theKeys pad:(NSSize)padSize];
				break;
		 
			case kLineGraph:
				[self drawLineGraphDisplay:theKeys pad:(NSSize)padSize];
				break;
		}
	}
}


-(void)setDocument:(TrackBrowserDocument*)tbd
{
   tbDocument = tbd;
}


-(void)setGraphType:(int)gt
{
   graphType = gt;
   [self setNeedsDisplay:YES];
}



-(int)graphType
{
   return graphType;
}

- (BOOL)haveData {
   return haveData;
}

- (float)leftTickViewWidth {
   return leftTickViewWidth;
}

- (float)rightTickViewWidth {
   return rightTickViewWidth;
}

- (NSArray *)typeInfoArray {
   if (!typeInfoArray) {
      typeInfoArray = [[NSMutableArray alloc] init];
   }
   return typeInfoArray;
}

- (unsigned)countOfTypeInfoArray {
   if (!typeInfoArray) {
      typeInfoArray = [[NSMutableArray alloc] init];
   }
   return [typeInfoArray count];
}

- (id)objectInTypeInfoArrayAtIndex:(unsigned)theIndex {
   if (!typeInfoArray) {
      typeInfoArray = [[NSMutableArray alloc] init];
   }
   return [typeInfoArray objectAtIndex:theIndex];
}


@end
