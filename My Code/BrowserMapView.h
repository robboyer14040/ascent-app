/* BrowserMapView */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class Track;

@interface BrowserMapView : WebView
{
   Track* currentTrack;
}
-(void) setCurrentTrack:(Track*) tr;
- (id)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName;
- (void)drawRect:(NSRect)rect;
@end
