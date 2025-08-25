/* CustomSplitDistanceController */

#import <Cocoa/Cocoa.h>

@interface CustomSplitDistanceController : NSWindowController
{
    IBOutlet NSTextField *distanceField;
    IBOutlet NSTextField *unitsField;
	
	float	customDistance;
	BOOL	isValid;
}
-(IBAction) done:(id)sender;
-(IBAction) cancel:(id)sender;
- (IBAction)setDistance:(id)sender;
- (float) customDistance;
- (void) setCustomDistance:(float)cd;

@end
