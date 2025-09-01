//
//  KML.mm
//  Ascent
//
//  Created by Rob Boyer on 2/7/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "KML.h"
#import "Utils.h"
#import "Track.h"
#import "Lap.h"
#import "TrackPoint.h"
#import "Defs.h"
#import "PathMarker.h"

@implementation KML

-(KML*) initKMLWithFileURL:(NSURL*)url
{
   NSLog(@"import KML: %@\n", url);
   self = [super init];
   xmlURL = url;
   currentImportTrack = nil;
   currentImportPoint = nil;
   currentImportLap = nil;
   currentImportPointArray = nil;
   currentTrackName = nil;
   inPoint = inActivity = inLap = inTrack = NO;
   currentStringValue = nil;
   return self;
}


-(void) dealloc
{
    [super dealloc];
}



- (NSDate*) dateFromTimeString:(NSString*) ts
{
   NSRange r;
   r.length = 10;
   r.location = 0;
   NSString* sub = [ts substringWithRange:r];
   NSMutableString* d = [NSMutableString stringWithString:sub];
   r.length = 8;
   r.location = 11;
   NSString* t = [ts substringWithRange:r];
   //NSLog(@"point at %@ %@\n", d, t);
   [d appendString:@" "];
   [d appendString:t];
   [d appendString:@" +0000"];
   return [NSDate dateWithString:d];
}



//---- EXPORT ----------------------------------------------------------------------------------------------------


- (BOOL) exportTrack:(Track*)track
{
	NSXMLElement *root = (NSXMLElement *)[NSXMLNode elementWithName:@"kml"];
#if 0
	NSString* v = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	NSMutableString* me = [NSMutableString stringWithString:@"Ascent "];
	[me appendString:v];
	[root addAttribute:[NSXMLNode attributeWithName:@"version" 
										stringValue:@"1.0"]];
	[root addAttribute:[NSXMLNode attributeWithName:@"creator" 
										stringValue:me]];
#endif
	[root addAttribute:[NSXMLNode attributeWithName:@"xmlns" 
										stringValue:@"http://www.opengis.net/kml/2.2"]];

	NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithRootElement:root];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];

	NSXMLElement* kmldoc = [NSXMLNode elementWithName:@"Document"];

	NSDate* trackDate = [track creationTime];
	NSString* frm = @"%d-%b-%y at %I:%M%p";
	NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
	NSString* dayKey = [trackDate descriptionWithCalendarFormat:frm
													   timeZone:tz 
														 locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];


	NSMutableString* an = [NSMutableString stringWithString:@"Ascent activity on "];
	[an appendString:dayKey];

	NSXMLElement* name = [NSXMLNode elementWithName:@"name"
										stringValue:an];
	[kmldoc addChild:name];

	NSXMLElement* open = [NSXMLNode elementWithName:@"open"
										stringValue:@"1"];
	[kmldoc addChild:open];

	// line style setup
	NSXMLElement* style = [NSXMLNode elementWithName:@"Style"];
	[style addAttribute:[NSXMLNode attributeWithName:@"id"
										 stringValue:@"AscentLineStyle"]];
	  
	NSXMLElement* lineStyle = [NSXMLNode elementWithName:@"LineStyle"];
	NSColor* clr = [Utils colorFromDefaults:RCBDefaultPathColor];
	CGFloat r,g,b,a;
	[clr getRed:&r 
		  green:&g
		   blue:&b
		  alpha:&a];
	NSString* c = [NSString stringWithFormat:@"%02.2x%02.2x%02.2x%02.2x", (int)(a*255.0), (int)(b*255.0), (int)(g*255.0), (int)(r*255.0)];
	NSXMLElement* color = [NSXMLNode elementWithName:@"color"
										stringValue:c];
	[lineStyle addChild:color];

	NSXMLElement* width = [NSXMLNode elementWithName:@"width"
										stringValue:@"4"];
	[lineStyle addChild:width];

	NSXMLElement* polyStyle = [NSXMLNode elementWithName:@"PolyStyle"];
	color = [NSXMLNode elementWithName:@"color"
						   stringValue:c];



	[polyStyle addChild:color];
	[style addChild:lineStyle];
	[style addChild:polyStyle];
	[kmldoc addChild:style];

	//-----------
   
	// label style setup for markers
	NSXMLElement* makersLabelStyle = [NSXMLNode elementWithName:@"Style"];
	[makersLabelStyle addAttribute:[NSXMLNode attributeWithName:@"id"
										stringValue:@"AscentMarkerStyle"]];

	NSXMLElement* labelStyle = [NSXMLNode elementWithName:@"LabelStyle"];
	clr = [Utils colorFromDefaults:RCBDefaultAltitudeColor];
	[clr getRed:&r 
		 green:&g
		  blue:&b
		 alpha:&a];
	int ir, ig, ib, ia;
	ir = (int)(r*255.0);
	ig = (int)(g*255.0);
	ib = (int)(b*255.0);
	ia = (int)(a*255.0);
	c = [NSString stringWithFormat:@"%02.2x%02.2x%02.2x%02.2x",  ia, ib, ig, ir];
	color = [NSXMLNode elementWithName:@"color"
										stringValue:c];
	[labelStyle addChild:color];

	NSXMLElement* iconStyle = [NSXMLNode elementWithName:@"IconStyle"];
	color = [NSXMLNode elementWithName:@"color"
						  stringValue:c];
	[iconStyle addChild:color];

	polyStyle = [NSXMLNode elementWithName:@"PolyStyle"];
	color = [NSXMLNode elementWithName:@"color"
						  stringValue:c];
	[polyStyle addChild:color];

	lineStyle = [NSXMLNode elementWithName:@"LineStyle"];
	color = [NSXMLNode elementWithName:@"color"
						  stringValue:c];
	[lineStyle addChild:color];


	[makersLabelStyle addChild:polyStyle];
	[makersLabelStyle addChild:lineStyle];
	[makersLabelStyle addChild:labelStyle];
	[makersLabelStyle addChild:iconStyle];
	[kmldoc addChild:makersLabelStyle];
   
   //-----------
   
	// label style setup for laps
	NSXMLElement* lapsLabelStyle = [NSXMLNode elementWithName:@"Style"];
	[lapsLabelStyle addAttribute:[NSXMLNode attributeWithName:@"id"
												   stringValue:@"AscentLapStyle"]];

	labelStyle = [NSXMLNode elementWithName:@"LabelStyle"];
	clr = [Utils colorFromDefaults:RCBDefaultLapColor];
	[clr getRed:&r 
		  green:&g
		   blue:&b
		  alpha:&a];
	ir = (int)(r*255.0);
	ig = (int)(g*255.0);
	ib = (int)(b*255.0);
	ia = (int)(a*255.0);

	c = [NSString stringWithFormat:@"%02.2x%02.2x%02.2x%02.2x", ia, ib, ig, ir];
	color = [NSXMLNode elementWithName:@"color"
						   stringValue:c];
	[labelStyle addChild:color];
	iconStyle = [NSXMLNode elementWithName:@"IconStyle"];
	color = [NSXMLNode elementWithName:@"color"
						   stringValue:c];
	[iconStyle addChild:color];

	lineStyle = [NSXMLNode elementWithName:@"LineStyle"];
	color = [NSXMLNode elementWithName:@"color"
						   stringValue:c];
	[lineStyle addChild:color];

	polyStyle = [NSXMLNode elementWithName:@"PolyStyle"];
	color = [NSXMLNode elementWithName:@"color"
						   stringValue:c];
	[polyStyle addChild:color];

	[lapsLabelStyle addChild:polyStyle];
	[lapsLabelStyle addChild:lineStyle];
	[lapsLabelStyle addChild:labelStyle];
	[lapsLabelStyle addChild:iconStyle];
	[kmldoc addChild:lapsLabelStyle];
   
   //-----------
   

   // now add the track
   
	NSXMLElement* pm = [NSXMLNode elementWithName:@"Placemark"];
	[pm addAttribute:[NSXMLNode attributeWithName:@"id"
                                                    stringValue:@"AscentTrack"]];

	NSXMLElement* styleURL = [NSXMLNode elementWithName:@"styleUrl"
											stringValue:@"#AscentLineStyle"];
	[pm addChild:styleURL];

	NSString* nm = [track attribute:kName];
	if ([nm isEqualToString:@""])
	{
	  nm = [track name];
	}
	name = [NSXMLNode elementWithName:@"name"
						  stringValue:nm];
	[pm addChild:name];

	NSXMLElement* lineString = [NSXMLNode elementWithName:@"LineString"];
	NSXMLElement* extrude = [NSXMLNode elementWithName:@"extrude"
										   stringValue:@"0"];
	[lineString addChild:extrude];

	NSXMLElement* tessellate = [NSXMLNode elementWithName:@"tessellate"
											  stringValue:@"1"];
	[lineString addChild:tessellate];

	NSXMLElement* altitudeMode = [NSXMLNode elementWithName:@"altitudeMode"
												stringValue:@"clampToGround"];
	[lineString addChild:altitudeMode];

	NSArray* pts = [track goodPoints];
	int num = [pts count];
	NSMutableString* ms = [[NSMutableString alloc] initWithString:@""];
	for (int i=0; i<num; i++)
	{
		TrackPoint* pt = [pts objectAtIndex:i];
		if ([pt validLatLon])
		{
			float lat = [pt latitude];
			float lon = [pt longitude];
			if (((int)lat == 180) || ((int)lon == 180))
			{
				NSLog(@"bad point lat or lon!");
			}
			else
			{ 
				NSString* fs = [NSString stringWithFormat:@"%1.6f,%1.6f ",lon, lat/* 0 FeetToMeters([pt altitude]) */];
				[ms appendString:fs];
			}
		}
   }
   NSXMLElement* coords = [NSXMLNode elementWithName:@"coordinates"
                                         stringValue:ms];
   [lineString addChild:coords];
   [pm addChild:lineString];
   [kmldoc addChild:pm];
   
  
   //---- Laps
   
	NSArray* laps = [track laps];
	num = [laps count];
	if (num > 0)
	{
		NSXMLElement* folder = [NSXMLNode elementWithName:@"Folder"];
		NSXMLElement* fname = [NSXMLNode elementWithName:@"name"
											 stringValue:@"Laps"];
		[folder addChild:fname];
		open = [NSXMLNode elementWithName:@"open"
							  stringValue:@"1"];
		[folder addChild:open];

		for (int i=0; i<num; i++)
		{
			Lap* lap = [laps objectAtIndex:i];
			float lat = [lap beginLatitude];
			float lon = [lap beginLongitude];
			if (((int)lat == 180) || ((int)lon == 180))
			{
				NSLog(@"bad lap lat or lon!");
			}
			else
			{
				pm = [NSXMLNode elementWithName:@"Placemark"];
                [pm addAttribute:[NSXMLNode attributeWithName:@"id"
                                                  stringValue:[NSString stringWithFormat:@"Lap %d", i+1]]];
				styleURL = [NSXMLNode elementWithName:@"styleUrl"
										  stringValue:@"#AscentLapStyle"];
				[pm addChild:styleURL];
				NSString* n = [NSString stringWithFormat:@"Lap %d", i+1];
				name = [NSXMLNode elementWithName:@"name"
									  stringValue:n];
				[pm addChild:name];

				NSMutableString* ld = [NSMutableString stringWithFormat:@"Lap start at "];
				NSString* lapFrm = @"%H:%M";
				NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT:[track secondsFromGMTAtSync]];
				[ld appendString:[[track lapStartTime:lap] descriptionWithCalendarFormat:lapFrm
																				timeZone:tz 
																				  locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];
				NSXMLElement* desc = [NSXMLNode elementWithName:@"description"
													stringValue:ld];
				[pm addChild:desc];
				NSXMLElement* point = [NSXMLNode elementWithName:@"Point"];
				n = [NSString stringWithFormat:@"%1.6f,%1.6f ", lon, lat];

				coords = [NSXMLNode elementWithName:@"coordinates"
										stringValue:n];
				[point addChild:coords];
				[pm addChild:point];
				[folder addChild:pm];
			}
		}
		[kmldoc addChild:folder];
	}   
   
	NSArray* markers = [track markers];
	num = [markers count];
	if (num > 0)
	{
		NSXMLElement* folder = [NSXMLNode elementWithName:@"Folder"];
		NSXMLElement* fname = [NSXMLNode elementWithName:@"name"
											 stringValue:@"Markers"];
		[folder addChild:fname];
		open = [NSXMLNode elementWithName:@"open"
							 stringValue:@"1"];
		[folder addChild:open];
		for (int i=0; i<num; i++)
		{
			PathMarker* marker = [markers objectAtIndex:i];

			TrackPoint* pt = [track closestPointToDistance:[marker distance]];
			if (pt != nil)
			{
				float lat = [pt latitude];
				float lon = [pt longitude];
				if (((int)lat == 180) || ((int)lon == 180))
				{
				  NSLog(@"bad marker lat or lon!");
				}
				else
				{
					pm = [NSXMLNode elementWithName:@"Placemark"];
                    [pm addAttribute:[NSXMLNode attributeWithName:@"id"
                                                      stringValue:[NSString stringWithFormat:@"Marker %d", i+1]]];
					styleURL = [NSXMLNode elementWithName:@"styleUrl"
											  stringValue:@"#AscentMarkerStyle"];
					[pm addChild:styleURL];

					BOOL useStatute = [Utils boolFromDefaults:RCBDefaultUnitsAreEnglishKey];
					NSString* n = [NSString stringWithFormat:@"Marker %d at %5.1f %s", i+1, [Utils convertDistanceValue:[pt distance]],
									   useStatute ? "miles" : "km"];
					name = [NSXMLNode elementWithName:@"description"
										  stringValue:n];
					[pm addChild:name];

					NSXMLElement* desc = [NSXMLNode elementWithName:@"name"
														stringValue:[marker name]];
					[pm addChild:desc];
					NSXMLElement* point = [NSXMLNode elementWithName:@"Point"];
					n = [NSString stringWithFormat:@"%10.6f,%10.6f ", lon, lat];

					coords = [NSXMLNode elementWithName:@"coordinates"
											stringValue:n];
					[point addChild:coords];
					[pm addChild:point];
					[folder addChild:pm];
				}
			}
		}
		[kmldoc addChild:folder];
	}
	
	[root addChild:kmldoc];
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	if (![xmlData writeToURL:xmlURL atomically:YES]) 
	{
		NSLog(@"Could not write document out...");
		return NO;
	}   
	return YES;
}




@end
