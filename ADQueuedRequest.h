//
//  ADQueuedRequest.h
//  Ascent
//
//  Created by Rob Boyer on 9/4/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//


#import "AscentDocumentController.h"

typedef NS_ENUM(NSInteger, ADQueuedKind) {
    ADQueuedKindOpenURL,
    ADQueuedKindReopenURL,
    ADQueuedKindOpenUntitled
};

@interface ADQueuedRequest : NSObject
@property(nonatomic, assign) ADQueuedKind kind;
@property(nonatomic, retain) NSURL *url;
@property(nonatomic, retain) NSURL *altURL; // for reopen
@property(nonatomic, assign) BOOL display;
@property(nonatomic, copy) void (^handler)(NSDocument *doc, BOOL alreadyOpen, NSError *err);
@end

@implementation ADQueuedRequest
- (void)dealloc {
    [_url release];
    [_altURL release];
    [_handler release];
    [super dealloc];
}
@end

static BOOL sDeferring = NO;
static NSMutableArray *sQueue; // of ADQueuedRequest

@implementation AscentDocumentController

+ (void)initialize {
    if (self == [AscentDocumentController class]) {
        sQueue = [[NSMutableArray alloc] init];
    }
}

+ (void)beginDeferringOpens {
    sDeferring = YES;
    // Ensure singleton is created as our subclass
    (void)[AscentDocumentController sharedDocumentController];
}

+ (void)endDeferringOpensAndFlush {
    sDeferring = NO;
    // Drain queued requests on main
    NSArray *items = [[sQueue copy] autorelease];
    [sQueue removeAllObjects];

    AscentDocumentController *dc = (AscentDocumentController *)[AscentDocumentController sharedDocumentController];
    for (ADQueuedRequest *req in items) {
        switch (req.kind) {
            case ADQueuedKindOpenURL: {
                [super openDocumentWithContentsOfURL:req.url
                                             display:req.display
                                   completionHandler:req.handler];
            } break;

            case ADQueuedKindReopenURL: {
                [super reopenDocumentForURL:req.url
                         withContentsOfURL:req.altURL
                                  display:req.display
                        completionHandler:req.handler];
            } break;

            case ADQueuedKindOpenUntitled: {
                [super openUntitledDocumentAndDisplay:req.display
                                    completionHandler:req.handler];
            } break;
        }
    }
}

#pragma mark - Modern async overrides

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument * _Nullable doc,
                                                BOOL documentWasAlreadyOpen,
                                                NSError * _Nullable error))completionHandler
{
    if (sDeferring) {
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindOpenURL;
        q.url = url;
        q.display = displayDocument;
        q.handler = [completionHandler copy];
        [sQueue addObject:q];
        [q release];
        return; // we’ll call completion later from the flush
    }
    [super openDocumentWithContentsOfURL:url
                                 display:displayDocument
                       completionHandler:completionHandler];
}

- (void)reopenDocumentForURL:(NSURL *)url
           withContentsOfURL:(NSURL *)contentsURL
                      display:(BOOL)displayDocument
            completionHandler:(void (^)(NSDocument * _Nullable doc,
                                        BOOL documentWasAlreadyOpen,
                                        NSError * _Nullable error))completionHandler
{
    if (sDeferring) {
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindReopenURL;
        q.url = url;
        q.altURL = contentsURL;
        q.display = displayDocument;
        q.handler = [completionHandler copy];
        [sQueue addObject:q];
        [q release];
        return;
    }
    [super reopenDocumentForURL:url
              withContentsOfURL:contentsURL
                         display:displayDocument
               completionHandler:completionHandler];
}

- (void)openUntitledDocumentAndDisplay:(BOOL)displayDocument
                     completionHandler:(void (^)(NSDocument * _Nullable doc,
                                                 BOOL documentWasAlreadyOpen,
                                                 NSError * _Nullable error))completionHandler
{
    if (sDeferring) {
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindOpenUntitled;
        q.display = displayDocument;
        q.handler = [completionHandler copy];
        [sQueue addObject:q];
        [q release];
        return;
    }
    [super openUntitledDocumentAndDisplay:displayDocument completionHandler:completionHandler];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
// Optional legacy sync path, silenced locally.
- (NSDocument *)openDocumentWithContentsOfURL:(NSURL *)url
                                      display:(BOOL)displayDocument
                                        error:(NSError **)outError
{
    if (sDeferring) {
        // Queue as async; tell caller we’ll complete later (no error alert).
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindOpenURL;
        q.url = url;
        q.display = displayDocument;
        // Bridge sync to async: make a tiny handler that does nothing (AppKit won’t show an error).
        q.handler = [^(NSDocument *doc, BOOL already, NSError *err){} copy];
        [sQueue addObject:q];
        [q release];
        if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                      code:NSUserCancelledError
                                                  userInfo:nil];
        return nil;
    }
    return [super openDocumentWithContentsOfURL:url display:displayDocument error:outError];
}


// AscentDocumentController.m (additions)

#pragma mark - Old/sync creation paths used at launch

// 10.7+ async creation helper that AppKit sometimes calls internally
- (void)makeDocumentForURL:(NSURL *)url
         withContentsOfURL:(NSURL *)contentsURL
                    ofType:(NSString *)typeName
         completionHandler:(void (^)(NSDocument * _Nullable doc,
                                     NSError * _Nullable error))completionHandler
{
    if (sDeferring) {
        // Queue as a "reopen" so we can complete later
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindReopenURL;
        q.url = url;
        q.altURL = contentsURL;
        q.display = YES;
        q.handler = [^(NSDocument *doc, BOOL already, NSError *err) {
            // Bridge back to the completion the caller expected
            if (completionHandler) completionHandler(doc, err);
        } copy];
        [sQueue addObject:q];
        [q release];
        return;
    }
    [super makeDocumentForURL:url withContentsOfURL:contentsURL ofType:typeName completionHandler:completionHandler];
}

// Legacy synchronous constructor path (still used in some launch cases)
- (NSDocument *)makeDocumentForURL:(NSURL *)url
                 withContentsOfURL:(NSURL *)contentsURL
                            ofType:(NSString *)typeName
                             error:(NSError **)outError
{
    if (sDeferring) {
        ADQueuedRequest *q = [[ADQueuedRequest alloc] init];
        q.kind = ADQueuedKindReopenURL;
        q.url = url;
        q.altURL = contentsURL;
        q.display = YES;
        q.handler = [^(NSDocument *doc, BOOL already, NSError *err){} copy];
        [sQueue addObject:q];
        [q release];

        if (outError) {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSUserCancelledError
                                        userInfo:nil];
        }
        return nil; // tell caller "not now" — we’ll finish later during flush
    }
    return [super makeDocumentForURL:url withContentsOfURL:contentsURL ofType:typeName error:outError];
}


#pragma clang diagnostic pop

@end
