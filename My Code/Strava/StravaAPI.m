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
static NSString * const kStravaRedirectURI  = @"http://127.0.0.1:63429/strava-callback"; // full loopback URL


// One dedicated serial queue for ALL Strava work
static dispatch_queue_t ASCStravaQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.montebello.ascent.strava", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

// MRC-safe async dispatch (copies the block so it survives enqueue)
static inline void ASCDispatch(dispatch_queue_t q, void (^ _Nullable block)(void)) {
    if (!block) return;
    void (^heap)(void) = Block_copy(block);
    dispatch_async(q ?: dispatch_get_main_queue(), ^{
        if (heap) heap();
        if (heap) Block_release(heap);
    });
}

// Keep ASCOnMain around, but make it MRC-safe too
static inline void ASCOnMain(void (^ _Nullable block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) { block(); return; }
    void (^heap)(void) = Block_copy(block);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (heap) heap();
        if (heap) Block_release(heap);
    });
}

static id _Nullable ASCJSON(NSData * _Nullable data, NSError ** _Nullable err) {
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:err];
}


static OSStatus ASCKeychainUpsert(NSString *service, NSString *account, NSData *valueData) {
    // Delete if value is nil/empty
    if (valueData == nil || valueData.length == 0) {
        NSDictionary *delQuery = @{
            (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service ?: @"",
            (__bridge id)kSecAttrAccount: account ?: @""
        };
        OSStatus delStatus = SecItemDelete((__bridge CFDictionaryRef)delQuery);
        if (delStatus == errSecItemNotFound) return errSecSuccess;
        return delStatus;
    }

    // Try update first
    NSDictionary *query = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service ?: @"",
        (__bridge id)kSecAttrAccount: account ?: @""
    };
    NSDictionary *attrs = @{
        (__bridge id)kSecValueData: valueData
    };

    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)attrs);
    if (status == errSecItemNotFound) {
        // Add new
        NSMutableDictionary *add = [query mutableCopy];
        [add addEntriesFromDictionary:attrs];
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
        [add release];
    }
    return status;
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
    NSString       *_redirectURI; // e.g. http://127.0.0.1:63429/strava-callback
    int _loopFD;
    dispatch_source_t _loopAcceptSrc;
    dispatch_source_t _loopReadSrc;
    BOOL            _authInProgress;
    NSTimeInterval  _accessExpiresAt; // Unix epoch seconds
}
- (void)_trackTask:(NSURLSessionTask *)t;
- (void)_untrackTask:(NSURLSessionTask *)t;
- (void)_teardownLoopback;
// Get all photos for an activity (Strava + external). `size` is the longest edge (e.g. 1024 or 2048).
- (void)_fetchActivityPhotos:(NSNumber *)activityID
                       size:(NSUInteger)size
                      queue:(dispatch_queue_t _Nullable)queue
                 completion:(StravaPhotosCompletion)completion;



//- (void)_ensureFreshAccessTokenOnQueue:(dispatch_queue_t)q
//                            completion:(StravaAuthCompletion)completion;


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


@end

@implementation ASCActivitiesPager
- (void)dealloc {
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
        _loopFD = -1;
        _loopAcceptSrc = NULL;
        _loopReadSrc = NULL;
        _authInProgress = NO;
        _accessExpiresAt = 0;
#if 1
        NSDictionary *tok = [[NSUserDefaults standardUserDefaults] objectForKey:@"StravaTokens"];
        if ([tok isKindOfClass:[NSDictionary class]]) {
            NSString *a = tok[@"access"];
            NSString *r = tok[@"refresh"];
            NSNumber *e = tok[@"expires_at"];
            if ([a isKindOfClass:[NSString class]]) { ASC_RELEASE(_accessToken);  _accessToken  = [a copy]; }
            if ([r isKindOfClass:[NSString class]]) { ASC_RELEASE(_refreshToken); _refreshToken = [r copy]; }
            if ([e isKindOfClass:[NSNumber class]]) _accessExpiresAt = [e doubleValue];
        }
#endif
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

#pragma mark - Task tracking

- (void)_trackTask:(NSURLSessionTask *)task {
    if (!task) return;
    @synchronized (self) { [_inflightTasks addObject:task]; }
}

- (void)_untrackTask:(NSURLSessionTask *)task {
    if (!task) return;
    @synchronized (self) { [_inflightTasks removeObject:task]; }
}

#pragma mark - Private helpers
- (void)_teardownLoopback
{
    if (_loopReadSrc)   dispatch_source_cancel(_loopReadSrc);
    if (_loopAcceptSrc) dispatch_source_cancel(_loopAcceptSrc);
    if (_loopFD >= 0)   close(_loopFD);
    _loopReadSrc = NULL;
    _loopAcceptSrc = NULL;
    _loopFD = -1;
}


- (BOOL)_accessTokenIsFresh {
    // 60s skew to be safe
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    return (_accessToken.length > 0 && _accessExpiresAt > now + 60.0);
}


- (void)_persistTokens {
    NSDictionary *tok = @{
        @"access":     (_accessToken ?: @""),
        @"refresh":    (_refreshToken ?: @""),
        @"expires_at": @(_accessExpiresAt),
    };
    [[NSUserDefaults standardUserDefaults] setObject:tok forKey:@"StravaTokens"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

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


#pragma mark - Public API (matches header)

- (void)startAuthorizationFromWindow:(NSWindow *)window
                          completion:(StravaAuthCompletion)completion
{
    // Parse redirect URI (must exactly match what's registered in Strava Dashboard)
    NSURL *cbURL    = [NSURL URLWithString:(_redirectURI ?: @"")];
    NSString *host  = cbURL.host ?: @"127.0.0.1";
    NSNumber *pnum  = cbURL.port ?: @(63429);
    uint16_t port   = (uint16_t)pnum.unsignedShortValue;
    NSString *path  = cbURL.path.length ? cbURL.path : @"/strava-callback";

    // 1) Start the tiny loopback server BEFORE opening the browser
    __block int listenFD = -1;
    __block dispatch_source_t acceptSrc = NULL;
    __block dispatch_source_t readSrc   = NULL;

    NSError *lbErr = nil;
    if (![self asc_startLoopbackOnHost:host
                                  port:port
                                  path:path
                               acceptFD:&listenFD
                              acceptSrc:&acceptSrc
                                readSrc:&readSrc
                             onAuthCode:^(NSString *code)
    {
        // Got the authorization code → exchange for tokens.
        NSDictionary *form = @{
            @"client_id":     (_clientID ?: @""),
            @"client_secret": (_clientSecret ?: @""),
            @"grant_type":    @"authorization_code",
            @"code":          (code ?: @""),
            // IMPORTANT: must be EXACTLY the same redirect_uri used to get the code
            @"redirect_uri":  (_redirectURI ?: @"")
        };
        NSURLRequest *req = [self _POST:@"https://www.strava.com/oauth/token" form:form];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            // Always stop listening once we have (or fail to get) tokens
            [unretainedSelf asc_closeLoopbackFD:listenFD acceptSrc:acceptSrc readSrc:readSrc];
            [unretainedSelf _untrackTask:task];

            if (error) {
                ASCOnMain(^{ if (completion) completion(error); });
                return;
            }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava"
                                                            code:-4
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Malformed token response"}];
                ASCOnMain(^{ if (completion) completion(e); });
                return;
            }

            NSDictionary *dict = (NSDictionary *)obj;
            NSString *access  = dict[@"access_token"] ?: @"";
            NSString *refresh = dict[@"refresh_token"] ?: @"";

            // Keep in-memory copies
            ASC_RELEASE(unretainedSelf->_accessToken);
            unretainedSelf->_accessToken = [access copy];
            if (refresh.length) {
                ASC_RELEASE(unretainedSelf->_refreshToken);
                unretainedSelf->_refreshToken = [refresh copy];
            }

            // Persist to your secure store (Keychain recommended)
            // Implement this in your class.
            [unretainedSelf persistTokensWithAccess:access refresh:refresh];

            ASCOnMain(^{ if (completion) completion(nil); });
        }];
        [self _trackTask:task];
        [task resume];

    } error:&lbErr])
    {
        // Failed to start loopback server (commonly: port in use)
        ASCOnMain(^{
            if (completion) completion(lbErr ?: [NSError errorWithDomain:@"Strava"
                                                                     code:-10
                                                                 userInfo:@{NSLocalizedDescriptionKey:@"Failed to start loopback listener"}]);
        });
        return;
    }

    // 2) Build the authorize URL (MUST use the exact redirect_uri)
    NSAssert(_clientID.length,     @"Strava clientID not set");
    NSAssert(_clientSecret.length, @"Strava clientSecret not set");
    NSAssert(_redirectURI.length,  @"Strava redirectURI not set");

    NSString *scope           = @"read,profile:read_all,activity:read,activity:read_all";
    NSString *encodedRedirect = [_redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *authURLString   = [NSString stringWithFormat:
        @"https://www.strava.com/oauth/authorize?client_id=%@&response_type=code&redirect_uri=%@&approval_prompt=auto&scope=%@",
        _clientID, encodedRedirect, scope];
    
    NSLog(@"setting auth scope to %s",[scope UTF8String]);
     
    // 3) Open the user's browser to complete the flow
    ASCOnMain(^{
        NSWindow *hostWin = window ?: (NSApp.keyWindow ?: NSApp.mainWindow);
        if (!hostWin) {
            // Create a tiny placeholder to satisfy any nonnull expectations.
            hostWin = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1,1)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:YES] autorelease];
        }
        (void)hostWin;
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:authURLString]];
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


- (void)fetchActivityDetail:(NSNumber *)activityID
                 completion:(void (^)(NSDictionary * _Nullable activity, NSError * _Nullable error))completion
{
    if (!activityID) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-20 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }

    void (^completionCopy)(NSDictionary *, NSError *) = [completion copy];

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) {
            ASCDispatch(ASCStravaQueue(), ^{
                if (completionCopy) completionCopy(nil, err);
                if (completionCopy) Block_release(completionCopy);
            });
            return;
        }

        NSString *url = [NSString stringWithFormat:@"https://www.strava.com/api/v3/activities/%@?include_all_efforts=true", activityID];
        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) {
                ASCDispatch(ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, error);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-21 userInfo:@{NSLocalizedDescriptionKey:@"Malformed activity detail"}];
                ASCDispatch(ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, e);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            ASCDispatch(ASCStravaQueue(), ^{
                if (completionCopy) completionCopy((NSDictionary *)obj, nil);
                if (completionCopy) Block_release(completionCopy);
            });
        }];
        [self _trackTask:task];
        [task resume];
    }];
}



- (void)fetchActivityStreams:(NSNumber *)activityID
                       types:(NSArray<NSString *> *)types
                  completion:(void (^)(NSDictionary<NSString *, NSArray *> * _Nullable streams, NSError * _Nullable error))completion
{
    if (!activityID) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-22 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }

    void (^completionCopy)(NSDictionary *, NSError *) = [completion copy];

    NSString *keys = [types count] ? [types componentsJoinedByString:@","]
                                   : @"latlng,heartrate,velocity_smooth,time,cadence,altitude,distance";

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) {
            ASCDispatch(ASCStravaQueue(), ^{
                if (completionCopy) completionCopy(nil, err);
                if (completionCopy) Block_release(completionCopy);
            });
            return;
        }

        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/activities/%@/streams?keys=%@&key_by_type=true",
            activityID, [keys stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) {
                ASCDispatch(ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, error);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-23 userInfo:@{NSLocalizedDescriptionKey:@"Malformed streams response"}];
                ASCDispatch(ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, e);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            ASCDispatch(ASCStravaQueue(), ^{
                if (completionCopy) completionCopy((NSDictionary *)obj, nil);
                if (completionCopy) Block_release(completionCopy);
            });
        }];
        [self _trackTask:task];
        [task resume];
    }];
}

#pragma mark - Loopback mini-server

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

        dispatch_source_cancel(acceptSrc);

        readSrc = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)conn, 0, q);
        dispatch_source_set_event_handler(readSrc, ^{
            char buf[4096];
            ssize_t n = read(conn, buf, sizeof(buf)-1);
            if (n <= 0) { return; }
            buf[n] = 0;

            NSString *req = [[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSUTF8StringEncoding];
            NSRange firstLineEnd = [req rangeOfString:@"\r\n"];
            NSString *firstLine = (firstLineEnd.location != NSNotFound) ? [req substringToIndex:firstLineEnd.location] : req;

            NSArray *parts = [firstLine componentsSeparatedByString:@" "];
            NSString *target = (parts.count >= 2 ? parts[1] : @"");
            NSURLComponents *comps = [NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
            NSString *code = nil;
            for (NSURLQueryItem *item in comps.queryItems) {
                if ([item.name isEqualToString:@"code"]) { code = item.value; break; }
            }

            NSString *html = @"<html><head><meta charset='utf-8'><title>Authorized</title></head><body style='font:16px -apple-system'>Authorization completed. You can close this window.</body></html>";
            NSString *resp = [NSString stringWithFormat:
                              @"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n%@",
                              (unsigned long)[html lengthOfBytesUsingEncoding:NSUTF8StringEncoding], html];
            write(conn, [resp UTF8String], (ssize_t)[resp lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);

            dispatch_source_cancel(readSrc);
            close(conn);

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


- (NSString * _Nullable)currentAccessToken {
    @synchronized (self) {
        return [[_accessToken copy] autorelease]; // MRC: caller gets autoreleased copy
    }
}


- (void)fetchFreshAccessToken:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion
{
    if (!completion) return;
    void (^completionCopy)(NSString *, NSError *) = [completion copy]; // MRC

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) {
            if (completionCopy) completionCopy(nil, err);
            if (completionCopy) Block_release(completionCopy);
            return;
        }
        NSString *tok = nil;
        @synchronized (self) { tok = [[_accessToken copy] autorelease]; }
        if (completionCopy) completionCopy(tok, nil);
        if (completionCopy) Block_release(completionCopy);
    }];
}


- (void)_ensureFreshAccessToken:(StravaAuthCompletion)completion
{
    StravaAuthCompletion completionCopy = [completion copy]; // MRC retain

    if ([self _accessTokenIsFresh]) {
        if (completionCopy) completionCopy(nil);
        if (completionCopy) Block_release(completionCopy);
        return;
    }

    if (_refreshToken.length > 0) {
        NSDictionary *form = @{
            @"client_id":     (_clientID ?: @""),
            @"client_secret": (_clientSecret ?: @""),
            @"grant_type":    @"refresh_token",
            @"refresh_token": (_refreshToken ?: @"")
        };
        NSURLRequest *req = [self _POST:@"https://www.strava.com/oauth/token" form:form];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            [unretainedSelf _untrackTask:task];

            if (error) {
                if (completionCopy) completionCopy(error);
                if (completionCopy) Block_release(completionCopy);
                return;
            }

            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-3
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Malformed token refresh"}];
                if (completionCopy) completionCopy(e);
                if (completionCopy) Block_release(completionCopy);
                return;
            }

            NSDictionary *dict = (NSDictionary *)obj;
            NSString *access  = dict[@"access_token"];
            NSString *refresh = dict[@"refresh_token"];
            NSNumber *exp     = dict[@"expires_at"];

            ASC_RELEASE(unretainedSelf->_accessToken);
            unretainedSelf->_accessToken = [access copy];

            if (refresh.length) {
                ASC_RELEASE(unretainedSelf->_refreshToken);
                unretainedSelf->_refreshToken = [refresh copy];
            }
            unretainedSelf->_accessExpiresAt = [exp isKindOfClass:[NSNumber class]] ? exp.doubleValue : 0;

            [unretainedSelf _persistTokens];

            if (completionCopy) completionCopy(nil);
            if (completionCopy) Block_release(completionCopy);
        }];
        [self _trackTask:task];
        [task resume];
        return;
    }

    // No refresh token — kick UI auth on main, then invoke completionCopy ONCE.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *host = [NSApp keyWindow] ?: [NSApp mainWindow];
        if (!host) {
            host = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1,1)
                                               styleMask:NSWindowStyleMaskBorderless
                                                 backing:NSBackingStoreBuffered
                                                   defer:YES] autorelease];
        }
        [self startAuthorizationFromWindow:host completion:^(NSError * _Nullable err) {
            // (Re)persist if success
            if (!err) [self _persistTokens];
            if (completionCopy) completionCopy(err);
            if (completionCopy) Block_release(completionCopy);
        }];
    });
}

// --- Keychain helper (MRC-safe) ---------------------------------------------


// --- Public method -----------------------------------------------------------

- (void)persistTokensWithAccess:(NSString *)access refresh:(NSString *)refresh {
    // Use your bundle id to scope the service name
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *service  = (bundleID.length ? [bundleID stringByAppendingString:@".strava"] : @"Ascent.Strava");

    NSData *accessData  = (access.length  ? [access  dataUsingEncoding:NSUTF8StringEncoding]  : nil);
    NSData *refreshData = (refresh.length ? [refresh dataUsingEncoding:NSUTF8StringEncoding] : nil);

    OSStatus sa = ASCKeychainUpsert(service, @"access_token",  accessData);
    OSStatus sr = ASCKeychainUpsert(service, @"refresh_token", refreshData);

    if (sa != errSecSuccess || sr != errSecSuccess) {
        NSLog(@"[StravaAPI] Keychain persist error (access=%d, refresh=%d)",
              (int)sa, (int)sr);
    }
}


- (void)_fetchActivityPhotos:(NSNumber *)activityID
                       size:(NSUInteger)size
                      queue:(dispatch_queue_t)queue
                 completion:(StravaPhotosCompletion)completion
{
    if (!activityID) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-30 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }
    if (size == 0) size = 1024;

    StravaPhotosCompletion completionCopy = [completion copy];

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) {
            ASCDispatch(queue ?: ASCStravaQueue(), ^{
                if (completionCopy) completionCopy(nil, err);
                if (completionCopy) Block_release(completionCopy);
            });
            return;
        }

        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/activities/%@/photos?photo_sources=true&size=%lu",
            activityID, (unsigned long)size];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) {
                ASCDispatch(queue ?: ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, error);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-31 userInfo:@{NSLocalizedDescriptionKey:@"Malformed photos response"}];
                ASCDispatch(queue ?: ASCStravaQueue(), ^{
                    if (completionCopy) completionCopy(nil, e);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            ASCDispatch(queue ?: ASCStravaQueue(), ^{
                if (completionCopy) completionCopy((NSArray *)obj, nil);
                if (completionCopy) Block_release(completionCopy);
            });
        }];
        [self _trackTask:task];
        [task resume];
    }];
}



#pragma mark - Internal helpers

static NSString * _SAN_sanitizeFilename(NSString *name) {
    NSCharacterSet *ok = [NSCharacterSet characterSetWithCharactersInString:
                          @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];
    NSMutableString *out = [NSMutableString stringWithCapacity:name.length];
    for (NSUInteger i = 0; i < [name length]; i++) {
        unichar c = [name characterAtIndex:i];
        [out appendFormat:@"%C", [ok characterIsMember:c] ? c : '_'];
    }
    if ([out length] == 0) return @"unnamed";
    if ([out length] > 80) return [out substringToIndex:80];
    return out;
}

static NSData * _SAN_JPEGDataFromImageData(NSData *data) {
    if (!data) return nil;
    NSImage *img = [[[NSImage alloc] initWithData:data] autorelease];
    if (!img) return nil;

    NSData *tiff = [img TIFFRepresentation];
    if (!tiff) return nil;

    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithData:tiff] autorelease];
    if (!rep) return nil;

    NSDictionary *props = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.9f]
                                                       forKey:NSImageCompressionFactor];
    return [rep representationUsingType:NSBitmapImageFileTypeJPEG properties:props];
}

#pragma mark - Public

- (BOOL)fetchPhotosForActivity:(NSNumber*)stravaActivityID
                  rootMediaURL:(NSURL *)mediaURL
                    completion:(void (^)(NSArray<NSString *> * photoFilenames, NSError * error))completion
{
    if (!completion) return NO;
    if (stravaActivityID == 0 || mediaURL == nil) {
        NSError *paramErr = [NSError errorWithDomain:@"StravaAPI"
                                                code:400
                                            userInfo:[NSDictionary dictionaryWithObject:@"Invalid parameters"
                                                                                 forKey:NSLocalizedDescriptionKey]];
        completion([NSArray array], paramErr);
        return NO;
    }

    BOOL didStartAccess = NO;
    @try {
        if ([mediaURL respondsToSelector:@selector(startAccessingSecurityScopedResource)]) {
            didStartAccess = [mediaURL startAccessingSecurityScopedResource];
        }
    } @catch (__unused NSException *ex) {}

    NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
    NSError *dirErr = nil;

    ///NSString *actFolderName = [NSString stringWithFormat:@"%lu", (unsigned long)[stravaActivityID longValue]];
    //NSURL *actFolderURL = [mediaURL URLByAppendingPathComponent:actFolderName isDirectory:YES];
//    NSURL *actFolderURL = mediaURL;
//    if (![fm createDirectoryAtURL:actFolderURL withIntermediateDirectories:YES attributes:nil error:&dirErr]) {
//         if (didStartAccess) { @try { [mediaURL stopAccessingSecurityScopedResource]; } @catch (__unused NSException *ex) {} }
//        completion([NSArray array], dirErr ?: [NSError errorWithDomain:@"StravaAPI" code:500 userInfo:
//                                               [NSDictionary dictionaryWithObject:@"Failed to create media directory"
//                                                                           forKey:NSLocalizedDescriptionKey]]);
//        return NO;
//    }

    // Retain captured objects (MRC)
    [fm retain];
    [mediaURL retain];
   /// [actFolderURL retain];

    NSNumber *activityNum = [NSNumber numberWithUnsignedInteger:[stravaActivityID longValue]];
    NSUInteger desiredSize = 2048;

    // Use a background queue for the initial metadata fetch and downloads
    dispatch_queue_t bg = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    [self _fetchActivityPhotos:activityNum
                          size:desiredSize
                         queue:bg
                    completion:^(NSArray<NSDictionary *> *photos, NSError *error)
    {
        if (error) {
            if (didStartAccess) { @try { [mediaURL stopAccessingSecurityScopedResource]; } @catch (__unused NSException *ex) {} }
            [fm release];
            [mediaURL release];
 ///           [actFolderURL release];
            ASCOnMain(^{ completion([NSArray array], error); });
            return;
        }

        if (!photos || [photos count] == 0) {
            if (didStartAccess) { @try { [mediaURL stopAccessingSecurityScopedResource]; } @catch (__unused NSException *ex) {} }
            [fm release];
            [mediaURL release];
 ///           [actFolderURL release];
            ASCOnMain(^{ completion([NSArray array], nil); });
            return;
        }

        dispatch_group_t group = dispatch_group_create();
        NSURLSession *session = [NSURLSession sharedSession];
        NSMutableArray *writtenNames = [[[NSMutableArray alloc] initWithCapacity:[photos count]] autorelease];
        __block NSError *firstErr = nil;

        [photos enumerateObjectsUsingBlock:^(NSDictionary *photo, NSUInteger idx, BOOL *stop) {

            // Your endpoint returns an array of dicts; prefer photo[@"urls"][@"<size>"] if present.
            NSString *bestURLString = nil;
            NSDictionary *urls = ([photo objectForKey:@"urls"] && [[photo objectForKey:@"urls"] isKindOfClass:[NSDictionary class]])
                               ? (NSDictionary *)[photo objectForKey:@"urls"] : nil;
            if (urls) {
                NSString *exactKey = [NSString stringWithFormat:@"%lu", (unsigned long)desiredSize];
                bestURLString = [urls objectForKey:exactKey] ?: [urls objectForKey:@"2048"] ?: [urls objectForKey:@"1024"] ?: [urls objectForKey:@"600"];
                if (!bestURLString && [urls count] > 0) bestURLString = [[urls allValues] firstObject];
            }
            if (!bestURLString && [[photo objectForKey:@"url"] isKindOfClass:[NSString class]]) {
                bestURLString = [photo objectForKey:@"url"];
            }
            if (!bestURLString || [bestURLString length] == 0) {
                return; // skip quietly
            }

            // Stable-ish basename from id / unique_id / fallback hash
            NSString *pid = nil;
            id rawID = [photo objectForKey:@"id"];
            if ([rawID respondsToSelector:@selector(stringValue)]) pid = [rawID stringValue];
            else if ([rawID isKindOfClass:[NSString class]]) pid = (NSString *)rawID;
            if (!pid) {
                id uid = [photo objectForKey:@"unique_id"];
                if ([uid isKindOfClass:[NSString class]]) pid = (NSString *)uid;
            }
            if (!pid) pid = [NSString stringWithFormat:@"%lu", (unsigned long)[bestURLString hash]];

            NSString *base = [NSString stringWithFormat:@"photo_%04lu_%@", (unsigned long)(idx + 1), _SAN_sanitizeFilename(pid)];
            NSString *filename = [base stringByAppendingPathExtension:@"jpg"];
            ///NSURL *destURL = [actFolderURL URLByAppendingPathComponent:filename];
            NSURL *destURL = [mediaURL URLByAppendingPathComponent:filename];

            if ([fm fileExistsAtPath:[destURL path]]) {
                @synchronized (writtenNames) {
                    [writtenNames addObject:[[filename copy] autorelease]];
                }
                return;
            }

            NSURL *srcURL = [NSURL URLWithString:bestURLString];
            if (!srcURL) return;

            dispatch_group_enter(group);
            NSURLSessionDataTask *task = [session dataTaskWithURL:srcURL
                                                completionHandler:^(NSData *data, NSURLResponse *resp, NSError *dlErr)
            {
                if (dlErr || !data) {
                    if (!firstErr && dlErr) firstErr = [dlErr retain];
                    dispatch_group_leave(group);
                    return;
                }

                NSData *jpeg = _SAN_JPEGDataFromImageData(data);
                if (!jpeg) {
                    if (!firstErr) {
                        firstErr = [[NSError errorWithDomain:@"StravaAPI" code:422
                                                    userInfo:[NSDictionary dictionaryWithObject:@"Failed to render JPEG"
                                                                                         forKey:NSLocalizedDescriptionKey]] retain];
                    }
                    dispatch_group_leave(group);
                    return;
                }

                NSError *wErr = nil;
                if (![jpeg writeToURL:destURL options:NSDataWritingAtomic error:&wErr]) {
                    if (!firstErr && wErr) firstErr = [wErr retain];
                    dispatch_group_leave(group);
                    return;
                }

                @synchronized (writtenNames) {
                    [writtenNames addObject:[[filename copy] autorelease]];
                }
                dispatch_group_leave(group);
            }];
            [task resume];
        }];

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (didStartAccess) { @try { [mediaURL stopAccessingSecurityScopedResource]; } @catch (__unused NSException *ex) {} }

            [fm release];
            [mediaURL release];
            ///[actFolderURL release];

#if !OS_OBJECT_USE_OBJC
            dispatch_release(group);
#endif
            if (firstErr) {
                NSError *e = [firstErr autorelease];
                completion([NSArray arrayWithArray:writtenNames], e);
            } else {
                completion([NSArray arrayWithArray:writtenNames], nil);
            }
        });
    }];

    return YES; // async work successfully started
}


// StravaAPI.m  (add inside @implementation StravaAPI)

- (void)fetchGearMap:(StravaGearMapCompletion)completion
{
    if (!completion) return;
    StravaGearMapCompletion completionCopy = [completion copy]; // MRC retain

    [self _ensureFreshAccessToken:^(NSError * _Nullable authErr) {
        if (authErr) {
            ASCOnMain(^{ if (completionCopy) completionCopy(nil, authErr); if (completionCopy) Block_release(completionCopy); });
            return;
        }

        NSString *url = @"https://www.strava.com/api/v3/athlete";
        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            // Network-level error
            if (error) {
                ASCOnMain(^{ if (completionCopy) completionCopy(nil, error); if (completionCopy) Block_release(completionCopy); });
                return;
            }

            // HTTP status check
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (![http isKindOfClass:[NSHTTPURLResponse class]] || http.statusCode < 200 || http.statusCode >= 300) {
                NSError *e = [NSError errorWithDomain:@"StravaHTTP"
                                                 code:(http ? http.statusCode : -1)
                                             userInfo:@{ NSLocalizedDescriptionKey:
                                                             [NSString stringWithFormat:@"HTTP %ld fetching /athlete",
                                                                 (long)(http ? http.statusCode : -1)] }];
                ASCOnMain(^{ if (completionCopy) completionCopy(nil, e); if (completionCopy) Block_release(completionCopy); });
                return;
            }

            // Parse JSON
            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"StravaAPI"
                                                            code:-1001
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Malformed /athlete JSON"}];
                ASCOnMain(^{ if (completionCopy) completionCopy(nil, e); if (completionCopy) Block_release(completionCopy); });
                return;
            }

            NSDictionary *athlete = (NSDictionary *)obj;
            NSArray *bikes = ([[athlete objectForKey:@"bikes"] isKindOfClass:[NSArray class]] ? [athlete objectForKey:@"bikes"] : nil);
            NSArray *shoes = ([[athlete objectForKey:@"shoes"] isKindOfClass:[NSArray class]] ? [athlete objectForKey:@"shoes"] : nil);

            NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:8];

            void (^accum)(NSArray *) = ^(NSArray *items) {
                for (id it in items) {
                    if (![it isKindOfClass:[NSDictionary class]]) continue;
                    NSDictionary *g = (NSDictionary *)it;

                    NSString *gid  = [[g objectForKey:@"id"]   isKindOfClass:[NSString class]] ? [g objectForKey:@"id"]   : nil;
                    NSString *name = [[g objectForKey:@"name"] isKindOfClass:[NSString class]] ? [g objectForKey:@"name"] : nil;

                    if (!name.length) {
                        NSString *brand = [[g objectForKey:@"brand_name"] isKindOfClass:[NSString class]] ? [g objectForKey:@"brand_name"] : nil;
                        NSString *model = [[g objectForKey:@"model_name"] isKindOfClass:[NSString class]] ? [g objectForKey:@"model_name"] : nil;
                        if (brand.length || model.length) {
                            name = [NSString stringWithFormat:@"%@%@%@",
                                    brand ?: @"", (brand.length && model.length) ? @" " : @"", model ?: @""];
                        } else {
                            name = @"(Unnamed Gear)";
                        }
                    }

                    if (gid.length) [map setObject:name forKey:gid];
                }
            };

            if (bikes) accum(bikes);
            if (shoes) accum(shoes);

#if 0   // OPTIONAL FALLBACK: harvest gear from recent activities if /athlete has no gear arrays
            if ([map count] == 0) {
                // Collect gear_ids from a small page of recent activities
                __block NSMutableSet *gearIDs = [NSMutableSet set];
                dispatch_semaphore_t semActs = dispatch_semaphore_create(0);

                NSString *actsURL = @"https://www.strava.com/api/v3/athlete/activities?per_page=30&page=1";
                NSURLRequest *actsReq = [unretainedSelf _GET:actsURL bearer:unretainedSelf->_accessToken];

                __block NSURLSessionDataTask *t2 = nil;
                t2 = [unretainedSelf->_session dataTaskWithRequest:actsReq
                                                completionHandler:^(NSData *d2, NSURLResponse *r2, NSError *e2)
                {
                    if (!e2) {
                        id arr = [NSJSONSerialization JSONObjectWithData:d2 options:0 error:NULL];
                        if ([arr isKindOfClass:[NSArray class]]) {
                            for (id a in (NSArray *)arr) {
                                if (![a isKindOfClass:[NSDictionary class]]) continue;
                                NSString *gid = ([[a objectForKey:@"gear_id"] isKindOfClass:[NSString class]]
                                                 ? [a objectForKey:@"gear_id"] : nil);
                                if (gid.length) [gearIDs addObject:gid];
                            }
                        }
                    }
                    dispatch_semaphore_signal(semActs);
                }];
                [t2 resume];
                (void)dispatch_semaphore_wait(semActs, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)));
            #if !OS_OBJECT_USE_OBJC
                dispatch_release(semActs);
            #endif

                // Resolve each gear_id → name via /gear/{id}
                for (NSString *gid in gearIDs) {
                    dispatch_semaphore_t semGear = dispatch_semaphore_create(0);
                    NSString *gurl = [NSString stringWithFormat:@"https://www.strava.com/api/v3/gear/%@", gid];
                    NSURLRequest *greq = [unretainedSelf _GET:gurl bearer:unretainedSelf->_accessToken];

                    __block NSURLSessionDataTask *tg = nil;
                    tg = [unretainedSelf->_session dataTaskWithRequest:greq
                                                    completionHandler:^(NSData *gd, NSURLResponse *gr, NSError *ge)
                    {
                        if (!ge) {
                            id gobj = [NSJSONSerialization JSONObjectWithData:gd options:0 error:NULL];
                            if ([gobj isKindOfClass:[NSDictionary class]]) {
                                NSString *name = ([[gobj objectForKey:@"name"] isKindOfClass:[NSString class]]
                                                  ? [gobj objectForKey:@"name"] : nil);
                                if (!name.length) {
                                    NSString *brand = [[gobj objectForKey:@"brand_name"] isKindOfClass:[NSString class]] ? [gobj objectForKey:@"brand_name"] : nil;
                                    NSString *model = [[gobj objectForKey:@"model_name"] isKindOfClass:[NSString class]] ? [gobj objectForKey:@"model_name"] : nil;
                                    if (brand.length || model.length) {
                                        name = [NSString stringWithFormat:@"%@%@%@",
                                                brand ?: @"", (brand.length && model.length) ? @" " : @"", model ?: @""];
                                    } else {
                                        name = @"(Unnamed Gear)";
                                    }
                                }
                                if (gid.length && name.length) { @synchronized(map) { [map setObject:name forKey:gid]; } }
                            }
                        }
                        dispatch_semaphore_signal(semGear);
                    }];
                    [tg resume];
                    (void)dispatch_semaphore_wait(semGear, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
                #if !OS_OBJECT_USE_OBJC
                    dispatch_release(semGear);
                #endif
                }
            }
#endif

            NSDictionary *outMap = [[map copy] autorelease];
            ASCOnMain(^{ if (completionCopy) completionCopy(outMap, nil); if (completionCopy) Block_release(completionCopy); });
        }];

        [unretainedSelf _trackTask:task];
        [task resume];
    }];
}


// Synchronous page fetch of activities.
// IMPORTANT: Call from a background queue; blocks the caller until the request completes.
- (NSArray<NSDictionary *> *)fetchActivitiesSince:(NSDate *)since
                                          perPage:(NSUInteger)perPage
                                             page:(NSUInteger)page
                                            error:(NSError **)outError
{
    NSParameterAssert(since != nil);
    if ([NSThread isMainThread]) {
        NSLog(@"[StravaAPI] WARNING: fetchActivitiesSince: called on main thread; this method blocks.");
    }

    __block NSError *authErr = nil;
    dispatch_semaphore_t semAuth = dispatch_semaphore_create(0);
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) authErr = [err retain];
        dispatch_semaphore_signal(semAuth);
    }];
    (void)dispatch_semaphore_wait(semAuth, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semAuth);
#endif
    if (authErr) {
        if (outError) *outError = [authErr autorelease];
        return nil;
    }

    NSTimeInterval afterEpoch = floor([since timeIntervalSince1970]);
    NSString *url = [NSString stringWithFormat:
                     @"https://www.strava.com/api/v3/athlete/activities?after=%.0f&per_page=%lu&page=%lu",
                     afterEpoch, (unsigned long)perPage, (unsigned long)page];

    NSURLRequest *req = [self _GET:url bearer:_accessToken];

    __block NSArray *result = nil;
    __block NSError *reqErr = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    __unsafe_unretained StravaAPI *unretainedSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [_session dataTaskWithRequest:req
                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        [unretainedSelf _untrackTask:task];

        if (error) {
            reqErr = [error retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (![http isKindOfClass:[NSHTTPURLResponse class]] || http.statusCode < 200 || http.statusCode >= 300) {
            reqErr = [[NSError errorWithDomain:@"StravaHTTP"
                                          code:(http ? http.statusCode : -1)
                                      userInfo:@{ NSLocalizedDescriptionKey:
                                                      [NSString stringWithFormat:@"HTTP %ld fetching /athlete/activities",
                                                       (long)(http ? http.statusCode : -1)],
                                                  NSURLErrorFailingURLErrorKey: url }] retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
            reqErr = [(jsonErr ?: [NSError errorWithDomain:@"StravaAPI"
                                                      code:-2001
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Malformed activities JSON"}]) retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        result = [obj retain]; // NSArray<NSDictionary *>
        dispatch_semaphore_signal(sem);
    }];
    [self _trackTask:task];
    [task resume];

    (void)dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(sem);
#endif

    if (outError) *outError = [reqErr autorelease];
    return [result autorelease];
}


// Synchronous fetch of streams for one activity, returning a by-type dictionary.
// IMPORTANT: Call from a background queue; blocks the caller until the request completes.
- (NSDictionary<NSString *, NSArray *> *)fetchStreamsForActivityID:(NSNumber *)actID
                                                             error:(NSError **)outError
{
    if (!actID) {
        if (outError) *outError = [NSError errorWithDomain:@"StravaAPI" code:-22
                                                  userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}];
        return nil;
    }
    if ([NSThread isMainThread]) {
        NSLog(@"[StravaAPI] WARNING: fetchStreamsForActivityID: called on main thread; this method blocks.");
    }

    __block NSError *authErr = nil;
    dispatch_semaphore_t semAuth = dispatch_semaphore_create(0);
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) authErr = [err retain];
        dispatch_semaphore_signal(semAuth);
    }];
    (void)dispatch_semaphore_wait(semAuth, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(semAuth);
#endif
    if (authErr) {
        if (outError) *outError = [authErr autorelease];
        return nil;
    }

    // Request the common keys; key_by_type=true returns a dictionary of {type: streamObject}
    NSString *keys = @"time,latlng,distance,velocity_smooth,altitude,heartrate,cadence,temp,watts,grade_smooth,moving";
    NSString *url  = [NSString stringWithFormat:
                      @"https://www.strava.com/api/v3/activities/%@/streams?keys=%@&key_by_type=true",
                      actID, keys];

    NSURLRequest *req = [self _GET:url bearer:_accessToken];

    __block NSDictionary *result = nil;
    __block NSError *reqErr = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    __unsafe_unretained StravaAPI *unretainedSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [_session dataTaskWithRequest:req
                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        [unretainedSelf _untrackTask:task];

        if (error) {
            reqErr = [error retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (![http isKindOfClass:[NSHTTPURLResponse class]] || http.statusCode < 200 || http.statusCode >= 300) {
            reqErr = [[NSError errorWithDomain:@"StravaHTTP"
                                          code:(http ? http.statusCode : -1)
                                      userInfo:@{ NSLocalizedDescriptionKey:
                                                      [NSString stringWithFormat:@"HTTP %ld fetching /activities/%@/streams",
                                                               (long)(http ? http.statusCode : -1),
                                                               actID],
                                                  NSURLErrorFailingURLErrorKey: url }] retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (!jsonErr && [obj isKindOfClass:[NSDictionary class]]) {
            result = [obj retain]; // key_by_type response
            dispatch_semaphore_signal(sem);
            return;
        }

        if (!jsonErr && [obj isKindOfClass:[NSArray class]]) {
            // Convert array-form into by-type dict
            NSArray *arr = (NSArray *)obj;
            NSMutableDictionary *byType = [NSMutableDictionary dictionaryWithCapacity:[arr count]];
            for (id item in arr) {
                if (![item isKindOfClass:[NSDictionary class]]) continue;
                NSString *type = [(NSDictionary *)item objectForKey:@"type"];
                if (type) [byType setObject:item forKey:type];
            }
            result = [byType retain];
            dispatch_semaphore_signal(sem);
            return;
        }

        reqErr = [(jsonErr ?: [NSError errorWithDomain:@"StravaAPI"
                                                  code:-2002
                                              userInfo:@{NSLocalizedDescriptionKey:@"Malformed streams JSON"}]) retain];
        dispatch_semaphore_signal(sem);
    }];
    [self _trackTask:task];
    [task resume];

    (void)dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(sem);
#endif

    if (outError) *outError = [reqErr autorelease];
    return [result autorelease];
}


// Public: Fetch segment efforts for an activity, sorted by ascending start time.
// Each entry is a NSDictionary with top-level effort fields and a compact "segment" sub-dictionary.
// Completion is always invoked on the main thread.
- (void)fetchSegmentsForActivityID:(NSNumber *)activityID
                        completion:(void (^)(NSArray<NSDictionary *> * _Nullable segments,
                                             NSError * _Nullable error))completion
{
    if (!completion) return;
    if (!activityID) {
        NSError *e = [NSError errorWithDomain:@"StravaAPI"
                                         code:4001
                                     userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}];
        ASCOnMain(^{ completion(nil, e); });
        return;
    }

    void (^completionCopy)(NSArray<NSDictionary *> *, NSError *) = [completion copy]; // MRC

    [self _ensureFreshAccessToken:^(NSError * _Nullable authErr) {
        if (authErr) {
            ASCOnMain(^{
                if (completionCopy) completionCopy(nil, authErr);
                if (completionCopy) Block_release(completionCopy);
            });
            return;
        }

        // Reuse the activity detail endpoint; it returns "segment_efforts" when include_all_efforts=true.
        NSString *url = [NSString stringWithFormat:
                         @"https://www.strava.com/api/v3/activities/%@?include_all_efforts=true",
                         activityID];
        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            [unretainedSelf _untrackTask:task];

            if (error) {
                ASCOnMain(^{
                    if (completionCopy) completionCopy(nil, error);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            // Basic HTTP validation
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (![http isKindOfClass:[NSHTTPURLResponse class]] || http.statusCode < 200 || http.statusCode >= 300) {
                NSError *e = [NSError errorWithDomain:@"StravaHTTP"
                                                 code:(http ? http.statusCode : -1)
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            [NSString stringWithFormat:@"HTTP %ld fetching activity detail",
                                                             (long)(http ? http.statusCode : -1)],
                                                        NSURLErrorFailingURLErrorKey: url}];
                ASCOnMain(^{
                    if (completionCopy) completionCopy(nil, e);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"StravaAPI"
                                                            code:4002
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Malformed activity JSON"}];
                ASCOnMain(^{
                    if (completionCopy) completionCopy(nil, e);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            NSDictionary *activity = (NSDictionary *)obj;
            NSArray *efforts = [[activity objectForKey:@"segment_efforts"] isKindOfClass:[NSArray class]]
                             ? (NSArray *)[activity objectForKey:@"segment_efforts"]
                             : nil;

            if (![efforts isKindOfClass:[NSArray class]]) {
                // No segment efforts found — return empty array, not an error
                ASCOnMain(^{
                    if (completionCopy) completionCopy([NSArray array], nil);
                    if (completionCopy) Block_release(completionCopy);
                });
                return;
            }

            // Map each effort into a compact NSDictionary we control.
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:[efforts count]];
            for (id it in efforts) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *eff = (NSDictionary *)it;

                // Pull common effort fields (existence-checked)
                id effortID          = [eff objectForKey:@"id"];
                NSString *startUTC   = [[eff objectForKey:@"start_date"] isKindOfClass:[NSString class]] ? [eff objectForKey:@"start_date"] : nil;
                NSString *startLocal = [[eff objectForKey:@"start_date_local"] isKindOfClass:[NSString class]] ? [eff objectForKey:@"start_date_local"] : nil;

                NSNumber *elapsed    = [[eff objectForKey:@"elapsed_time"] isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"elapsed_time"] : nil;
                NSNumber *moving     = [[eff objectForKey:@"moving_time"]  isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"moving_time"]  : nil;
                NSNumber *distance   = [[eff objectForKey:@"distance"]     isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"distance"]     : nil;

                NSNumber *prRank     = [[eff objectForKey:@"pr_rank"]    isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"pr_rank"]    : nil;
                NSNumber *komRank    = [[eff objectForKey:@"kom_rank"]   isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"kom_rank"]   : nil;

                NSNumber *avgHR      = [[eff objectForKey:@"average_heartrate"] isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"average_heartrate"] : nil;
                NSNumber *maxHR      = [[eff objectForKey:@"max_heartrate"]     isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"max_heartrate"]     : nil;

                NSNumber *deviceWatts= [[eff objectForKey:@"device_watts"] isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"device_watts"] : nil;
                NSNumber *avgWatts   = [[eff objectForKey:@"average_watts"] isKindOfClass:[NSNumber class]] ? [eff objectForKey:@"average_watts"] : nil;

                NSDictionary *seg    = [[eff objectForKey:@"segment"] isKindOfClass:[NSDictionary class]] ? [eff objectForKey:@"segment"] : nil;
                NSString *segName    = [[seg objectForKey:@"name"] isKindOfClass:[NSString class]] ? [seg objectForKey:@"name"] : nil;
                id segID             = [seg objectForKey:@"id"];

                // Optional compact segment sub-dict
                NSMutableDictionary *segmentSlim = nil;
                if ([seg isKindOfClass:[NSDictionary class]]) {
                    segmentSlim = [NSMutableDictionary dictionaryWithCapacity:12];
                    id v;

                    if ((v = [seg objectForKey:@"id"]))                   [segmentSlim setObject:v forKey:@"id"];
                    if ((v = ([seg objectForKey:@"name"] ?: nil)))        [segmentSlim setObject:v forKey:@"name"];
                    if ((v = [seg objectForKey:@"distance"]))             [segmentSlim setObject:v forKey:@"distance"];
                    if ((v = [seg objectForKey:@"average_grade"]))        [segmentSlim setObject:v forKey:@"average_grade"];
                    if ((v = [seg objectForKey:@"maximum_grade"]))        [segmentSlim setObject:v forKey:@"maximum_grade"];
                    if ((v = [seg objectForKey:@"elevation_high"]))       [segmentSlim setObject:v forKey:@"elevation_high"];
                    if ((v = [seg objectForKey:@"elevation_low"]))        [segmentSlim setObject:v forKey:@"elevation_low"];
                    if ((v = [seg objectForKey:@"climb_category"]))       [segmentSlim setObject:v forKey:@"climb_category"];
                    if ((v = [seg objectForKey:@"city"]))                 [segmentSlim setObject:v forKey:@"city"];
                    if ((v = [seg objectForKey:@"state"]))                [segmentSlim setObject:v forKey:@"state"];
                    if ((v = [seg objectForKey:@"country"]))              [segmentSlim setObject:v forKey:@"country"];
                    if ((v = [seg objectForKey:@"start_latlng"]))         [segmentSlim setObject:v forKey:@"start_latlng"];
                    if ((v = [seg objectForKey:@"end_latlng"]))           [segmentSlim setObject:v forKey:@"end_latlng"];
                }

                NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:16];
                if (effortID)       [row setObject:effortID forKey:@"effort_id"];
                if (segID)          [row setObject:segID    forKey:@"segment_id"];
                if (segName)        [row setObject:segName  forKey:@"name"];
                if (startUTC)       [row setObject:startUTC forKey:@"start_date"];
                if (startLocal)     [row setObject:startLocal forKey:@"start_date_local"];
                if (elapsed)        [row setObject:elapsed forKey:@"elapsed_time"];
                if (moving)         [row setObject:moving  forKey:@"moving_time"];
                if (distance)       [row setObject:distance forKey:@"distance"];
                if (prRank)         [row setObject:prRank  forKey:@"pr_rank"];
                if (komRank)        [row setObject:komRank forKey:@"kom_rank"];
                if (avgHR)          [row setObject:avgHR   forKey:@"average_heartrate"];
                if (maxHR)          [row setObject:maxHR   forKey:@"max_heartrate"];
                if (deviceWatts)    [row setObject:deviceWatts forKey:@"device_watts"];
                if (avgWatts)       [row setObject:avgWatts    forKey:@"average_watts"];
                if (segmentSlim)    [row setObject:segmentSlim forKey:@"segment"];

                [out addObject:row];
            }

            // Sort ascending by start_date (ISO-8601 sorts lexicographically)
            NSArray *sorted = [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSString *sa = [a objectForKey:@"start_date"];
                NSString *sb = [b objectForKey:@"start_date"];
                if (![sa isKindOfClass:[NSString class]]) sa = @"";
                if (![sb isKindOfClass:[NSString class]]) sb = @"";
                return [sa compare:sb options:NSLiteralSearch];
            }];

            ASCOnMain(^{
                if (completionCopy) completionCopy(sorted, nil);
                if (completionCopy) Block_release(completionCopy);
            });
        }];

        [unretainedSelf _trackTask:task];
        [task resume];
    }];
}

@end
