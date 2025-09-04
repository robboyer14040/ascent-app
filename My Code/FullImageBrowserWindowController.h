//  FullImageBrowserWindowController.h
//  Ascent
//
//  Manual retain/release (MRC)

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface FullImageBrowserWindowController : NSWindowController

/// Designated initializer.
/// @param baseURL Security-scoped *directory* URL that contains the media files (may be nil if you pass absolute file URLs in mediaNames).
/// @param names   Array of NSString file names (e.g. @"media/xyz.jpg", @"clip.mp4") or absolute file URL strings.
/// @param start   Initial index to display (clamped into range).
/// @param title   Optional window title; if nil/empty the file name is used.
- (instancetype)initWithBaseURL:(nullable NSURL *)baseURL
                     mediaNames:(NSArray<NSString *> *)names
                     startIndex:(NSInteger)start
                          title:(nullable NSString *)title NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithWindow:(NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Exposed navigation/actions (used by arrow keys and can be called by your UI).
- (void)goNext;
- (void)goPrev;
- (void)togglePlayPause;   // space bar behavior for movies

/// Programmatically jump to a given item.
- (void)showMediaAtIndex:(NSInteger)index;

/// Readonly state you might find useful.
@property (nonatomic, readonly, retain, nullable) NSURL *baseURL;
@property (nonatomic, readonly, retain) NSArray<NSString *> *mediaNames;
@property (nonatomic, readonly) NSInteger currentIndex;

@end

NS_ASSUME_NONNULL_END
