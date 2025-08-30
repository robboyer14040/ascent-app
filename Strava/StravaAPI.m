//
//  StravaAPI.m
//  Ascent
//
//  NON-ARC (MRC) implementation aligned with StravaAPI.h
//

#import "StravaAPI.h"
#import <AppKit/AppKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <errno.h>

#pragma mark - MRC helpers
#if !__has_feature(objc_arc)
#  define ASC_AUTORELEASE(x) [(x) autorelease]
#  define ASC_RELEASE(x)     do { if (x) [(x) release]; } while (0)
#  define ASC_RETAIN(x)      [(x) retain]
#else
#  define ASC_AUTORELEASE(x) (x)
#  define ASC_RELEASE(x)
#  define ASC_RETAIN(x)      (x)
#endif

static NSString * const kStravaClientID     = @"174788";         // your numeric client ID
static NSString * const kStravaClientSecret = @"b55a74d43f1b54f210141998bc236f94945fcedf";    // from Strava dashboard
static NSString * const kStravaRedirectURI  = @"http://127.0.0.1:63429/strava-callback"; // ✅ full URL


static inline void ASCOnMain(void (^ _Nullable block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

static id _Nullable ASCJSON(NSData * _Nullable data, NSError ** _Nullable err) {
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:err];
}


@interface ASCActivitiesPager : NSObject {
@public
    StravaAPI *api;                                  // (assign) no retain cycle
    NSDate *sinceDate;                               // (retain)
    NSUInteger perPage;                              // value
    NSUInteger page;                                 // value, starts at 1
    NSMutableArray *accum;                           // (retain)
    StravaProgress progress;                         // (copy)
    StravaActivitiesAllCompletion completion;        // (copy)
    BOOL finished;                                   // guard: fire once
}
@end


@interface StravaAPI ()
{
    NSURLSession   *_session;
    NSMutableSet   *_inflightTasks; // of NSURLSessionTask*

    // Simple in-memory token store (replace with Keychain in production)
    NSString       *_accessToken;
    NSString       *_refreshToken;

    // Config values (set from your app)
    NSString       *_clientID;
    NSString       *_clientSecret;
    NSString       *_redirectURI; // e.g. ascent://oauth-callback
 }
// Loopback helpers (declared so we can implement them below)
- (BOOL)asc_startLoopbackOnHost:(NSString *)host
                           port:(uint16_t)port
                           path:(NSString *)path
                        acceptFD:(int *)outFD
                       acceptSrc:(dispatch_source_t *)outAcceptSrc
                         readSrc:(dispatch_source_t *)outReadSrc
                      onAuthCode:(void (^)(NSString *code))handler
                           error:(NSError **)outError;

- (void)asc_closeLoopbackFD:(int)fd
                  acceptSrc:(dispatch_source_t)acceptSrc
                    readSrc:(dispatch_source_t)readSrc;
- (void)_pageActivitiesWithContext:(ASCActivitiesPager *)ctx;
@end



@implementation ASCActivitiesPager
- (void)dealloc {
    // Release/cancel everything we own
    if (progress)   Block_release(progress);
    if (completion) Block_release(completion);
    [sinceDate release];
    [accum release];
    [super dealloc];
}
@end


@implementation StravaAPI

+ (instancetype)shared {
    static StravaAPI *gShared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ gShared = [[self alloc] init]; });
    return gShared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [[NSURLSession sessionWithConfiguration:cfg] retain];
        _inflightTasks = [[NSMutableSet alloc] init];

        _clientID     = [kStravaClientID copy];
        _clientSecret = [kStravaClientSecret copy];
        _redirectURI  = [kStravaRedirectURI copy];

        _accessToken  = [@"" copy];
        _refreshToken = [@"" copy];
    }
    return self;
}


#if !__has_feature(objc_arc)
- (void)dealloc {
    @synchronized (self) {
        for (NSURLSessionTask *t in _inflightTasks) { [t cancel]; }
    }
    ASC_RELEASE(_session);
    ASC_RELEASE(_inflightTasks);
    ASC_RELEASE(_clientID);
    ASC_RELEASE(_clientSecret);
    ASC_RELEASE(_redirectURI);
    ASC_RELEASE(_accessToken);
    ASC_RELEASE(_refreshToken);
    [super dealloc];
}
#endif

#pragma mark - Private helpers

- (BOOL)_hasValidAccessToken { return (_accessToken.length > 0); }

- (NSURLRequest *)_GET:(NSString *)urlString bearer:(NSString * _Nullable)token {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"GET"];
    if (token.length) {
        NSString *hdr = [NSString stringWithFormat:@"Bearer %@", token];
        [req setValue:hdr forHTTPHeaderField:@"Authorization"];
    }
    return req;
}

- (NSURLRequest *)_POST:(NSString *)urlString form:(NSDictionary *)form {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"POST"];
    NSMutableArray *pairs = [NSMutableArray array];
    for (id key in form) {
        id obj = [form objectForKey:key];
        NSString *k = [[key description] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *v = [[obj description] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", k, v]];
    }
    NSData *body = [[pairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [req setHTTPBody:body];
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    return req;
}

- (void)_ensureFreshAccessToken:(StravaAuthCompletion)completion {
    if ([self _hasValidAccessToken]) { ASCOnMain(^{ if (completion) completion(nil); }); return; }

    if (_refreshToken.length > 0) {
        NSDictionary *form = [NSDictionary dictionaryWithObjectsAndKeys:
                              (_clientID ?: @""), @"client_id",
                              (_clientSecret ?: @""), @"client_secret",
                              @"refresh_token", @"grant_type",
                              (_refreshToken ?: @""), @"refresh_token",
                              nil];
        NSURLRequest *req = [self _POST:@"https://www.strava.com/oauth/token" form:form];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        NSURLSessionDataTask *task = [_session dataTaskWithRequest:req
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
            if (error) { ASCOnMain(^{ if (completion) completion(error); }); return; }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);

            if (http.statusCode == 400) {
                // Invalid refresh token: clear and re-auth
                ASC_RELEASE(unretainedSelf->_accessToken); unretainedSelf->_accessToken = [@"" copy];
                ASC_RELEASE(unretainedSelf->_refreshToken); unretainedSelf->_refreshToken = [@"" copy];
                @synchronized (unretainedSelf) {
                    for (NSURLSessionTask *t in unretainedSelf->_inflightTasks) { [t cancel]; }
                    [unretainedSelf->_inflightTasks removeAllObjects];
                }
                ASCOnMain(^{
                    NSWindow *host = [NSApp keyWindow] ?: [NSApp mainWindow];
                    if (!host) {
                        host = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                                           styleMask:NSWindowStyleMaskBorderless
                                                             backing:NSBackingStoreBuffered
                                                               defer:YES] autorelease];
                    }
                    [unretainedSelf startAuthorizationFromWindow:host completion:^(NSError * _Nullable err) {
                        if (completion) completion(err);
                    }];
                });                return;
            }

            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-3 userInfo:[NSDictionary dictionaryWithObject:@"Malformed token refresh" forKey:NSLocalizedDescriptionKey]];
                ASCOnMain(^{ if (completion) completion(e); });
                return;
            }

            NSDictionary *dict = (NSDictionary *)obj;
            NSString *access = [dict objectForKey:@"access_token"];
            NSString *newRefresh = [dict objectForKey:@"refresh_token"];

            ASC_RELEASE(unretainedSelf->_accessToken); unretainedSelf->_accessToken = [access copy];
            if (newRefresh.length) { ASC_RELEASE(unretainedSelf->_refreshToken); unretainedSelf->_refreshToken = [newRefresh copy]; }
            ASCOnMain(^{ if (completion) completion(nil); });
        }];

        @synchronized (self) { [_inflightTasks addObject:task]; }
        [task resume];
        return;
    }

    // No refresh token → need full auth
    ASCOnMain(^{
        NSWindow *host = [NSApp keyWindow] ?: [NSApp mainWindow];
        if (!host) {
            // create a harmless dummy if nothing is available
            host = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:YES] autorelease];
        }
        [self startAuthorizationFromWindow:host completion:^(NSError * _Nullable err) {
            if (completion) completion(err);
        }];
    });}

#pragma mark - Public API (matches header)

- (void)startAuthorizationFromWindow:(NSWindow *)window completion:(StravaAuthCompletion)completion
{
    // Parse _redirectURI to get host/port/path
    NSURL *cbURL = [NSURL URLWithString:(_redirectURI ?: @"")];
    NSString *host = cbURL.host ?: @"127.0.0.1";
    NSNumber *portNum = cbURL.port ?: @(63429);
    uint16_t port = (uint16_t)[portNum unsignedShortValue];
    NSString *path = cbURL.path.length ? cbURL.path : @"/strava-callback";

    // 1) Start a tiny loopback server BEFORE opening the browser.
    __block int listenFD = -1;
    __block dispatch_source_t acceptSrc = NULL;
    __block dispatch_source_t readSrc = NULL;

    NSError *lbErr = nil;
    if (![self asc_startLoopbackOnHost:host port:port path:path
                              acceptFD:&listenFD
                             acceptSrc:&acceptSrc
                               readSrc:&readSrc
                            onAuthCode:^(NSString *code) {

        // 2) Exchange code -> tokens (must send the SAME redirect_uri)
        NSDictionary *form = @{
            @"client_id":     (_clientID ?: @""),
            @"client_secret": (_clientSecret ?: @""),
            @"grant_type":    @"authorization_code",
            @"code":          (code ?: @""),
            @"redirect_uri":  (_redirectURI ?: @"")
        };
        NSURLRequest *req = [self _POST:@"https://www.strava.com/oauth/token" form:form];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        NSURLSessionDataTask *task = [_session dataTaskWithRequest:req
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // Clean up listener regardless
            [self asc_closeLoopbackFD:listenFD acceptSrc:acceptSrc readSrc:readSrc];

            if (error) { ASCOnMain(^{ if (completion) completion(error); }); return; }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-4 userInfo:@{NSLocalizedDescriptionKey:@"Malformed token response"}];
                ASCOnMain(^{ if (completion) completion(e); });
                return;
            }
            NSDictionary *dict = (NSDictionary *)obj;
            NSString *access = dict[@"access_token"];
            NSString *refresh = dict[@"refresh_token"];

            ASC_RELEASE(unretainedSelf->_accessToken); unretainedSelf->_accessToken = [access copy];
            if (refresh.length) { ASC_RELEASE(unretainedSelf->_refreshToken); unretainedSelf->_refreshToken = [refresh copy]; }

            ASCOnMain(^{ if (completion) completion(nil); });
        }];
        [task resume];
        
    } error:&lbErr]) {
        ASCOnMain(^{ if (completion) completion(lbErr ?: [NSError errorWithDomain:@"Strava" code:-10 userInfo:@{NSLocalizedDescriptionKey:@"Failed to start loopback"}]); });
        return;
    }

    // 3) Compose authorize URL using EXACT redirect_uri
    NSAssert(_clientID.length, @"Strava clientID not set");
    NSAssert(_clientSecret.length, @"Strava clientSecret not set");
    NSAssert(_redirectURI.length, @"Strava redirectURI not set");

    NSString *scope = @"read,activity:read_all";
    NSString *encodedRedirect = [_redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *auth = [NSString stringWithFormat:
        @"https://www.strava.com/oauth/authorize?client_id=%@&response_type=code&redirect_uri=%@&approval_prompt=auto&scope=%@",
        _clientID, encodedRedirect, scope];

    // 4) Open on main thread (use real window per your nonnull contract)
    ASCOnMain(^{
        NSWindow *hostWin = window ?: (NSApp.keyWindow ?: NSApp.mainWindow);
        if (!hostWin) {
            hostWin = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:YES] autorelease];
        }
        (void)hostWin; // only to satisfy the nonnull param contract
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:auth]];
    });
}

- (BOOL)handleCallbackURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)outError {
    // TODO: Parse the callback, exchange code for tokens. For now, just claim handled.
    (void)url; (void)outError;
    return YES;
}

- (BOOL)isAuthorized {
    return [self _hasValidAccessToken] || (_refreshToken.length > 0);
}

- (void)fetchActivitiesSince:(NSDate * _Nullable)sinceDate
                        page:(NSUInteger)page
                     perPage:(NSUInteger)perPage
                  completion:(StravaActivitiesPageCompletion)completion
{
    __block BOOL fired = NO;
    NSObject *lock = [[NSObject alloc] init];

    // retain the finish block until it fires
    __block StravaActivitiesPageCompletion finish = NULL;

    finish = Block_copy(^(NSArray<NSDictionary *> * _Nullable activities,
                          NSURLResponse * _Nullable response,
                          NSError * _Nullable error) {
        BOOL shouldFire = NO;
        @synchronized (lock) { if (!fired) { fired = YES; shouldFire = YES; } }
        if (!shouldFire) return;

        ASCOnMain(^{ if (completion) completion(activities, response, error); });

        // IMPORTANT: Do NOT Block_release(finish) or release 'lock' here.
        // Re-entrancy or late callbacks can still enter this block and touch
        // captured variables. Self-releasing causes UAF.
    });
    
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { finish(nil, nil, err); return; }

        NSTimeInterval afterEpoch = (sinceDate ? floor([sinceDate timeIntervalSince1970]) : 0);
        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/athlete/activities?after=%.0f&page=%lu&per_page=%lu",
            afterEpoch, (unsigned long)page, (unsigned long)perPage];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        NSURLSessionDataTask *task = [_session dataTaskWithRequest:req
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
            if (error) { finish(nil, response, error); return; }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode == 401) {
                ASC_RELEASE(unretainedSelf->_accessToken); unretainedSelf->_accessToken = [@"" copy];
                NSError *e = [NSError errorWithDomain:@"Strava" code:401 userInfo:@{NSLocalizedDescriptionKey:@"Unauthorized"}];
                finish(nil, response, e);
                return;
            }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Malformed response"}];
                finish(nil, response, e);
                return;
            }
            finish((NSArray *)obj, response, nil);
        }];

        @synchronized (self) { [_inflightTasks addObject:task]; }
        [task resume];
    }];
}


- (void)fetchAllActivitiesSince:(NSDate * _Nullable)sinceDate
                        perPage:(NSUInteger)perPage
                       progress:(StravaProgress _Nullable)progress
                     completion:(StravaActivitiesAllCompletion)completion
{
    if (perPage == 0) perPage = 50;

    // Build a self-owned context that survives all async calls
    ASCActivitiesPager *ctx = [[ASCActivitiesPager alloc] init];
    ctx->api        = self;                           // assign (shared singleton anyway)
    ctx->sinceDate  = [sinceDate retain];
    ctx->perPage    = perPage;
    ctx->page       = 1;
    ctx->accum      = [[NSMutableArray alloc] init];
    ctx->progress   = progress ? Block_copy(progress) : NULL;
    ctx->completion = completion ? Block_copy(completion) : NULL;
    ctx->finished   = NO;

    // Start the loop; ctx is released exactly once in the helper when we're done
    [self _pageActivitiesWithContext:ctx];
}


// Accept a single HTTP GET to http://host:port<path>?code=... ; respond with a small HTML page.
// When code is parsed, calls handler(code). Returns YES on success.
- (BOOL)asc_startLoopbackOnHost:(NSString *)host
                           port:(uint16_t)port
                           path:(NSString *)path
                        acceptFD:(int *)outFD
                       acceptSrc:(dispatch_source_t *)outAcceptSrc
                         readSrc:(dispatch_source_t *)outReadSrc
                      onAuthCode:(void (^)(NSString *code))handler
                           error:(NSError **)outError
{
    if (!host.length) host = @"127.0.0.1";
    if (!path.length) path = @"/strava-callback";
    if (!handler) return NO;

    int fd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) { if (outError) *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return NO; }

    // Reuse port quickly
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        int err = errno; close(fd);
        if (outError) *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:@{NSLocalizedDescriptionKey:@"bind() failed; is another server using this port?"}];
        return NO;
    }
    if (listen(fd, 1) != 0) {
        int err = errno; close(fd);
        if (outError) *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:@{NSLocalizedDescriptionKey:@"listen() failed"}];
        return NO;
    }

    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t acceptSrc = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, q);
    if (!acceptSrc) { close(fd); if (outError) *outError = [NSError errorWithDomain:@"Strava" code:-11 userInfo:@{NSLocalizedDescriptionKey:@"accept source create failed"}]; return NO; }

    __block dispatch_source_t readSrc = NULL;

    dispatch_source_set_event_handler(acceptSrc, ^{
        struct sockaddr_in cli; socklen_t cliLen = sizeof(cli);
        int conn = accept(fd, (struct sockaddr *)&cli, &cliLen);
        if (conn < 0) return;

        // Stop accepting further connections
        dispatch_source_cancel(acceptSrc);

        readSrc = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)conn, 0, q);
        dispatch_source_set_event_handler(readSrc, ^{
            char buf[4096];
            ssize_t n = read(conn, buf, sizeof(buf)-1);
            if (n <= 0) { return; }
            buf[n] = 0;

            // Very simple parse: "GET /path?query HTTP/"
            NSString *req = [[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSUTF8StringEncoding];
            NSRange firstLineEnd = [req rangeOfString:@"\r\n"];
            NSString *firstLine = (firstLineEnd.location != NSNotFound) ? [req substringToIndex:firstLineEnd.location] : req;

            // Extract target
            NSArray *parts = [firstLine componentsSeparatedByString:@" "];
            NSString *target = (parts.count >= 2 ? parts[1] : @"");
            // Expect /path?code=...
            NSURLComponents *comps = [NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
            NSString *code = nil;
            for (NSURLQueryItem *item in comps.queryItems) {
                if ([item.name isEqualToString:@"code"]) { code = item.value; break; }
            }

            // Respond page
            NSString *html = @"<html><head><meta charset='utf-8'><title>Authorized</title></head><body style='font:16px -apple-system'>Authorization completed. You can close this window.</body></html>";
            NSString *resp = [NSString stringWithFormat:
                              @"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n%@",
                              (unsigned long)[html lengthOfBytesUsingEncoding:NSUTF8StringEncoding], html];
            write(conn, [resp UTF8String], (ssize_t)[resp lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);

            // Close connection & stop read source
            dispatch_source_cancel(readSrc);
            close(conn);

            // Deliver code
            if (code.length) handler(code);
            ASC_AUTORELEASE(req);
        });
        dispatch_source_set_cancel_handler(readSrc, ^{ /* conn closed above */ });
        dispatch_resume(readSrc);
    });
    dispatch_source_set_cancel_handler(acceptSrc, ^{ /* fd closed in asc_closeLoopbackFD */ });
    dispatch_resume(acceptSrc);

    if (outFD) *outFD = fd;
    if (outAcceptSrc) *outAcceptSrc = acceptSrc;
    if (outReadSrc) *outReadSrc = readSrc;
    return YES;
}

- (void)asc_closeLoopbackFD:(int)fd acceptSrc:(dispatch_source_t)acceptSrc readSrc:(dispatch_source_t)readSrc
{
    if (readSrc)   dispatch_source_cancel(readSrc);
    if (acceptSrc) dispatch_source_cancel(acceptSrc);
    if (fd >= 0)   close(fd);
}


// Detailed activity (one object, richer than summary)
- (void)fetchActivityDetail:(NSNumber *)activityID
                 completion:(void (^)(NSDictionary * _Nullable activity, NSError * _Nullable error))completion
{
    if (activityID == nil) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-20 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { if (completion) completion(nil, err); return; }

        NSString *url = [NSString stringWithFormat:@"https://www.strava.com/api/v3/activities/%@?include_all_efforts=true", activityID];
        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        NSURLSessionDataTask *task = [_session dataTaskWithRequest:req
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) { ASCOnMain(^{ if (completion) completion(nil, error); }); return; }
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-21 userInfo:@{NSLocalizedDescriptionKey:@"Malformed activity detail"}];
                ASCOnMain(^{ if (completion) completion(nil, e); });
                return;
            }
            ASCOnMain(^{ if (completion) completion((NSDictionary *)obj, nil); });
        }];
        [task resume];
    }];
}

// Streams (arrays of aligned samples; use key_by_type for {type: [..]} map)
- (void)fetchActivityStreams:(NSNumber *)activityID
                       types:(NSArray<NSString *> *)types
                  completion:(void (^)(NSDictionary<NSString *, NSArray *> * _Nullable streams, NSError * _Nullable error))completion
{
    if (activityID == nil) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-22 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }

    // Typical keys: latlng,heartrate,velocity_smooth,time,cadence,altitude,distance,grade_smooth,temp,moving
    NSString *keys = [types count] ? [types componentsJoinedByString:@","] :
                                     @"latlng,heartrate,velocity_smooth,time,cadence,altitude,distance";
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { if (completion) completion(nil, err); return; }

        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/activities/%@/streams?keys=%@&key_by_type=true",
            activityID, [keys stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        NSURLSessionDataTask *task = [_session dataTaskWithRequest:req
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) { ASCOnMain(^{ if (completion) completion(nil, error); }); return; }
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-23 userInfo:@{NSLocalizedDescriptionKey:@"Malformed streams response"}];
                ASCOnMain(^{ if (completion) completion(nil, e); });
                return;
            }
            // Shape: { "latlng": [{"data":[[lat,lon],…]}], "heartrate":[{"data":[hr, …]}], ... }  (Strava returns arrays by type; with key_by_type=true you get one entry per type)
            // Some libs wrap in arrays; handle both dict and dict-of-arrays.
            NSDictionary *dict = (NSDictionary *)obj;
            ASCOnMain(^{ if (completion) completion(dict, nil); });
        }];
        [task resume];
    }];
}

- (void)_pageActivitiesWithContext:(ASCActivitiesPager *)ctx
{
    // NOTE: we intentionally do NOT release ctx here. It was allocated with +new
    // in the public method and will be released exactly once when we finish/error.

    [self fetchActivitiesSince:ctx->sinceDate
                          page:ctx->page
                       perPage:ctx->perPage
                    completion:^(NSArray<NSDictionary *> * _Nullable activities,
                                 NSURLResponse * _Nullable response,
                                 NSError * _Nullable error)
    {
        if (ctx->finished) return; // ignore late callbacks

        if (error) {
            ctx->finished = YES;
            if (ctx->completion) {
                StravaActivitiesAllCompletion comp = ctx->completion;
                ASCOnMain(^{ comp(nil, error); });
            }
            [ctx release]; // FINAL release
            return;
        }

        if ([activities count] == 0) {
            ctx->finished = YES;
            if (ctx->completion) {
                // Return an immutable snapshot
                NSArray *result = [NSArray arrayWithArray:ctx->accum];
                StravaActivitiesAllCompletion comp = ctx->completion;
                ASCOnMain(^{ comp(result, nil); });
            }
            [ctx release]; // FINAL release
            return;
        }

        // Accumulate & report progress
        [ctx->accum addObjectsFromArray:activities];
        if (ctx->progress) {
            StravaProgress prog = ctx->progress;
            NSUInteger pageNow = ctx->page;
            NSUInteger total   = (NSUInteger)[ctx->accum count];
            ASCOnMain(^{ prog(pageNow, total); });
        }

        // Next page
        ctx->page += 1;
        [self _pageActivitiesWithContext:ctx];
    }];
}

@end
