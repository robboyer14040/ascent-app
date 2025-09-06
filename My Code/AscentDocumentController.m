// AscentDocumentController.m
// Build this file with -fno-objc-arc (File Inspector -> Objective-C ARC -> No)

#import <Cocoa/Cocoa.h>
#import "SplashPanelController.h"

#pragma mark - Forward declare async selectors (so it compiles on older SDKs)

/*
 We *declare* the async APIs in a private category so the compiler won’t warn,
 but we still *check respondsToSelector:* at runtime before calling them.
 On older SDKs/OS versions we fall back to the synchronous variants.
*/
@interface NSDocumentController (ASCAsyncDecls)
- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler;

- (void)reopenDocumentForURL:(NSURL *)url
           withContentsOfURL:(NSURL *)contentsURL
                     display:(BOOL)displayDocument
           completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler;

- (void)openUntitledDocumentAndDisplay:(BOOL)displayDocument
                     completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler;
@end

#pragma mark - Request model (MRC)

typedef void (^ASCOpenCompletion)(NSDocument * _Nullable, BOOL alreadyOpen, NSError * _Nullable);

@interface ASCOpenRequest : NSObject {
@public
    NSURL *_url;           // nil means "untitled"
    NSURL *_contentsURL;   // for reopen; may be nil
    BOOL   _display;
    BOOL   _isReopen;
    ASCOpenCompletion _userCompletion; // copied block (MRC)
}
- (instancetype)initOpenURL:(NSURL *)url display:(BOOL)display;
- (instancetype)initReopenURL:(NSURL *)url contentsURL:(NSURL *)contentsURL display:(BOOL)display;
- (void)setUserCompletion:(ASCOpenCompletion)blk;
- (ASCOpenCompletion)userCompletion;
@end

@implementation ASCOpenRequest
- (instancetype)initOpenURL:(NSURL *)url display:(BOOL)display {
    if ((self = [super init])) {
        _url = [url retain];
        _contentsURL = nil;
        _display = display;
        _isReopen = NO;
        _userCompletion = nil;
    }
    return self;
}
- (instancetype)initReopenURL:(NSURL *)url contentsURL:(NSURL *)contentsURL display:(BOOL)display {
    if ((self = [super init])) {
        _url = [url retain];
        _contentsURL = [contentsURL retain];
        _display = display;
        _isReopen = YES;
        _userCompletion = nil;
    }
    return self;
}
- (void)setUserCompletion:(ASCOpenCompletion)blk {
    if (_userCompletion) { Block_release(_userCompletion); _userCompletion = nil; }
    _userCompletion = blk ? Block_copy(blk) : nil;
}
- (ASCOpenCompletion)userCompletion { return _userCompletion; }
- (void)dealloc {
    if (_userCompletion) { Block_release(_userCompletion); _userCompletion = nil; }
    [_url release];
    [_contentsURL release];
    [super dealloc];
}
@end

#pragma mark - Controller

@interface AscentDocumentController : NSDocumentController {
    NSMutableArray *_deferred;   // of ASCOpenRequest *
    BOOL            _draining;
}
- (void)drainDeferredOpensWithCompletion:(void (^)(void))completion;
@end

@implementation AscentDocumentController

static BOOL sDeferring = YES;

+ (void)initialize {
    if (self == [AscentDocumentController class]) {
        sDeferring = YES;
    }
}


+ (void)load {
    // Make sure we defer as early as possible.
    sDeferring = YES;
}


- (instancetype)init {
    if ((self = [super init])) {
        _deferred = [[NSMutableArray alloc] init];
        _draining = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_appDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:NSApp];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_deferred release];
    [super dealloc];
}

#pragma mark - Runtime-compat async wrappers

- (void)asc_asyncOpenURL:(NSURL *)url
                 display:(BOOL)display
       completionHandler:(ASCOpenCompletion)completion
{
    SEL sel = @selector(openDocumentWithContentsOfURL:display:completionHandler:);
    if ([[NSDocumentController class] instancesRespondToSelector:sel]) {
        // Safe to call async API directly
        [super openDocumentWithContentsOfURL:url
                                      display:display
                            completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
            if (completion) completion(doc, already, err);
        }];
        return;
    }

    // Fallback to synchronous API
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL wasAlready = ([self documentForURL:url] != nil);
    NSError *err = nil;
    NSDocument *doc = [super openDocumentWithContentsOfURL:url display:display error:&err];
#pragma clang diagnostic pop
    if (completion) completion(doc, wasAlready, err);
}

- (void)asc_asyncReopenURL:(NSURL *)url
              contentsURL:(NSURL *)contentsURL
                  display:(BOOL)display
        completionHandler:(ASCOpenCompletion)completion
{
    SEL sel = @selector(reopenDocumentForURL:withContentsOfURL:display:completionHandler:);
    if ([[NSDocumentController class] instancesRespondToSelector:sel]) {
        [super reopenDocumentForURL:url
                   withContentsOfURL:contentsURL
                             display:display
                   completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
            if (completion) completion(doc, already, err);
        }];
        return;
    }

    // Fallback to synchronous reopen (available on older SDKs)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL wasAlready = ([self documentForURL:url] != nil);
    NSError *err = nil;
    NSDocument *doc = [super reopenDocumentForURL:url
                                 withContentsOfURL:contentsURL
                                           display:display
                                             error:&err];
#pragma clang diagnostic pop
    if (completion) completion(doc, wasAlready, err);
}

- (void)asc_asyncOpenUntitledDisplay:(BOOL)display
                   completionHandler:(ASCOpenCompletion)completion
{
    SEL sel = @selector(openUntitledDocumentAndDisplay:completionHandler:);
    if ([[NSDocumentController class] instancesRespondToSelector:sel]) {
        [super openUntitledDocumentAndDisplay:display
                            completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
            if (completion) completion(doc, already, err);
        }];
        return;
    }

    // Fallback to synchronous untitled open
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSError *err = nil;
    NSDocument *doc = [super openUntitledDocumentAndDisplay:display error:&err];
#pragma clang diagnostic pop
    if (completion) completion(doc, NO, err);
}

#pragma mark - Deferral drain

- (void)drainDeferredOpensWithCompletion:(void (^)(void))completion
{
    static BOOL didDrain = NO;
    if (didDrain || _draining) { if (completion) completion(); return; }
    didDrain = YES;

    NSArray *batch = [[_deferred copy] autorelease];
    if (batch.count == 0) {
        sDeferring = NO;
        if (completion) completion();
        return;
    }

    __block NSArray *holdBatch = [batch retain];
    __block void (^final)(void) = completion ? Block_copy(completion) : nil;

    _draining  = YES;
    sDeferring = NO;

    __block NSUInteger remaining = batch.count;

    for (ASCOpenRequest *req in batch) {
        ASCOpenCompletion user = [req userCompletion]; // held by req

        if (req->_url == nil && !req->_isReopen) {
            [self asc_asyncOpenUntitledDisplay:req->_display completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
                if (user) user(doc, already, err);
                if (--remaining == 0) {
                    _draining = NO;
                    [holdBatch release]; holdBatch = nil;
                    if (final) { final(); Block_release(final); final = nil; }
                }
            }];
        } else if (req->_isReopen) {
            [self asc_asyncReopenURL:req->_url contentsURL:req->_contentsURL display:req->_display
                   completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
                if (user) user(doc, already, err);
                if (--remaining == 0) {
                    _draining = NO;
                    [holdBatch release]; holdBatch = nil;
                    if (final) { final(); Block_release(final); final = nil; }
                }
            }];
        } else {
            [self asc_asyncOpenURL:req->_url display:req->_display completionHandler:^(NSDocument *doc, BOOL already, NSError *err){
                if (user) user(doc, already, err);
                if (--remaining == 0) {
                    _draining = NO;
                    [holdBatch release]; holdBatch = nil;
                    if (final) { final(); Block_release(final); final = nil; }
                }
            }];
        }
    }

    [_deferred removeAllObjects];
}

- (void)_appDidFinishLaunching:(NSNotification *)__unused n
{
#if 0
    // Give the splash a paint tick, then drain.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if (sDeferring) {
            [self drainDeferredOpensWithCompletion:nil];
        }
    });
#endif
}

#pragma mark - Overrides (capture requests while deferring)

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler
{
    if (sDeferring && !_draining) {
        ASCOpenRequest *req = [[[ASCOpenRequest alloc] initOpenURL:url display:displayDocument] autorelease];
        if (completionHandler) [req setUserCompletion:completionHandler];
        [_deferred addObject:req];
        return;
    }
    [self asc_asyncOpenURL:url display:displayDocument completionHandler:completionHandler];
}

- (void)reopenDocumentForURL:(NSURL *)url
           withContentsOfURL:(NSURL *)contentsURL
                     display:(BOOL)displayDocument
           completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler
{
    if (sDeferring && !_draining) {
        ASCOpenRequest *req = [[[ASCOpenRequest alloc] initReopenURL:url contentsURL:contentsURL display:displayDocument] autorelease];
        if (completionHandler) [req setUserCompletion:completionHandler];
        [_deferred addObject:req];
        return;
    }
    [self asc_asyncReopenURL:url contentsURL:contentsURL display:displayDocument completionHandler:completionHandler];
}

- (void)openUntitledDocumentAndDisplay:(BOOL)displayDocument
                     completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler
{
    if (sDeferring && !_draining) {
        ASCOpenRequest *req = [[[ASCOpenRequest alloc] initOpenURL:nil display:displayDocument] autorelease];
        if (completionHandler) [req setUserCompletion:completionHandler];
        [_deferred addObject:req];
        return;
    }
    [self asc_asyncOpenUntitledDisplay:displayDocument completionHandler:completionHandler];
}

@end
