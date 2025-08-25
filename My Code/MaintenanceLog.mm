//
//  MaintenanceLog.mm
//  Ascent
//
//  Created by Rob Boyer on 12/24/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import "MaintenanceLog.h"


@implementation MaintenanceLog

@dynamic date;


-(void)dealloc
{
}



- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
}


- (void)awakeFromInsert
{
	[super awakeFromInsert];
	//	[self setPrimitiveValue:[NSDate date] 
	//					 forKey:@"date"];

}


@end
