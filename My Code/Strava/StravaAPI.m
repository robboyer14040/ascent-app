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

static inline void ASCOnMain(void (^ _Nullable block)(void)) {
    if (!block) return;
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

static inline void ASCOnQueue(dispatch_queue_t q, void (^block)(void)) {
    if (!block) return;
    if (!q) ASCOnMain(block);
    else dispatch_async(q, block);
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
        NSDictionary *tok = [[NSUserDefaults standardUserDefaults] objectForKey:@"StravaTokens"];
        if ([tok isKindOfClass:[NSDictionary class]]) {
            NSString *a = tok[@"access"];
            NSString *r = tok[@"refresh"];
            NSNumber *e = tok[@"expires_at"];
            if ([a isKindOfClass:[NSString class]]) { ASC_RELEASE(_accessToken);  _accessToken  = [a copy]; }
            if ([r isKindOfClass:[NSString class]]) { ASC_RELEASE(_refreshToken); _refreshToken = [r copy]; }
            if ([e isKindOfClass:[NSNumber class]]) _accessExpiresAt = [e doubleValue];
        }   }
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

    NSString *scope           = @"read,activity:read_all";
    NSString *encodedRedirect = [_redirectURI stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *authURLString   = [NSString stringWithFormat:
        @"https://www.strava.com/oauth/authorize?client_id=%@&response_type=code&redirect_uri=%@&approval_prompt=auto&scope=%@",
        _clientID, encodedRedirect, scope];

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

- (void)fetchActivitiesSince:(NSDate * _Nullable)sinceDate
                        page:(NSUInteger)page
                     perPage:(NSUInteger)perPage
                  completion:(StravaActivitiesPageCompletion)completion
{
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { ASCOnMain(^{ if (completion) completion(nil, nil, err); }); return; }

        NSTimeInterval afterEpoch = (sinceDate ? floor([sinceDate timeIntervalSince1970]) : 0);
        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/athlete/activities?after=%.0f&page=%lu&per_page=%lu",
            afterEpoch, (unsigned long)page, (unsigned long)perPage];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error && [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
            if (error) { ASCOnMain(^{ if (completion) completion(nil, response, error); }); return; }

            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (http.statusCode == 401) {
                ASC_RELEASE(unretainedSelf->_accessToken); unretainedSelf->_accessToken = [@"" copy];
                NSError *e = [NSError errorWithDomain:@"Strava" code:401 userInfo:@{NSLocalizedDescriptionKey:@"Unauthorized"}];
                ASCOnMain(^{ if (completion) completion(nil, response, e); });
                return;
            }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Malformed response"}];
                ASCOnMain(^{ if (completion) completion(nil, response, e); });
                return;
            }

            ASCOnMain(^{ if (completion) completion((NSArray *)obj, response, nil); });
        }];

        [self _trackTask:task];
        [task resume];
    }];
}

- (void)fetchAllActivitiesSince:(NSDate * _Nullable)sinceDate
                        perPage:(NSUInteger)perPage
                       progress:(StravaProgress _Nullable)progress
                     completion:(StravaActivitiesAllCompletion)completion
{
    // MRC: copy blocks so they live across async calls (nil-safe)
    StravaProgress progressCopy = [progress copy];
    StravaActivitiesAllCompletion completionCopy = [completion copy];

    if (perPage == 0) perPage = 50;
    __block NSUInteger page = 1;
    __block NSMutableArray *accum = [[NSMutableArray alloc] init];

    NSDate *sinceCopy = [sinceDate copy];

    __block void (^fetchNext)(void) = nil;
    fetchNext = [^{
        [self fetchActivitiesSince:sinceCopy
                              page:page
                           perPage:perPage
                        completion:^(NSArray<NSDictionary *> * _Nullable activities,
                                     NSURLResponse * _Nullable response,
                                     NSError * _Nullable error)
        {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionCopy) completionCopy(nil, error);
                    [accum release];
                    [progressCopy release];
                    [completionCopy release];
                    [fetchNext release];
                    /* DO NOT release sinceCopy here; the copied block retains it */
                });
                return;
            }

            if (![activities isKindOfClass:[NSArray class]]) activities = (NSArray *)[NSArray array];

            if ([activities count] > 0) {
                [accum addObjectsFromArray:activities];
            }

            if (progressCopy) {
                NSUInteger pagesFetched = page;
                NSUInteger totalSoFar   = (NSUInteger)[accum count];
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressCopy(pagesFetched, totalSoFar);
                });
            }

            if ([activities count] < perPage) {
                NSArray *finalResult = [[accum copy] autorelease];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionCopy) completionCopy(finalResult, nil);
                    [accum release];
                    [progressCopy release];
                    [completionCopy release];
                    [fetchNext release];
                    /* DO NOT release sinceCopy here; the copied block retains it */
                });
                return;
            }

            page++;
            fetchNext();
        }];
    } copy];

    fetchNext();

    // Release our local reference; the copied block retains sinceCopy.
    [sinceCopy release];
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

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              [unretainedSelf _untrackTask:task];

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
        [self _trackTask:task];
        [task resume];
    }];
}


#if 0
// New, queue-aware API
- (void)fetchActivityDetail:(NSNumber *)activityID
                      queue:(dispatch_queue_t)queue
                 completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion
{
    if (!activityID) { ASCOnQueue(queue, ^{ if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-20 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); }); return; }
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { ASCOnQueue(queue, ^{ if (completion) completion(nil, err); }); return; }
        NSString *url = [NSString stringWithFormat:@"https://www.strava.com/api/v3/activities/%@?include_all_efforts=true", activityID];
        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];
            if (error) { ASCOnQueue(queue, ^{ if (completion) completion(nil, error); }); return; }
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-21 userInfo:@{NSLocalizedDescriptionKey:@"Malformed activity detail"}];
                ASCOnQueue(queue, ^{ if (completion) completion(nil, e); }); return;
            }
            ASCOnQueue(queue, ^{ if (completion) completion((NSDictionary *)obj, nil); });
        }];
        [self _trackTask:task];
        [task resume];
    }];
}
#endif

// Streams (arrays of aligned samples; use key_by_type for {type: [..]} map)
- (void)fetchActivityStreams:(NSNumber *)activityID
                       types:(NSArray<NSString *> *)types
                  completion:(void (^)(NSDictionary<NSString *, NSArray *> * _Nullable streams, NSError * _Nullable error))completion
{
    if (activityID == nil) { if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-22 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]); return; }

    NSString *keys = [types count] ? [types componentsJoinedByString:@","]
                                   : @"latlng,heartrate,velocity_smooth,time,cadence,altitude,distance";

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { if (completion) completion(nil, err); return; }

        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/activities/%@/streams?keys=%@&key_by_type=true",
            activityID, [keys stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) { ASCOnMain(^{ if (completion) completion(nil, error); }); return; }
            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-23 userInfo:@{NSLocalizedDescriptionKey:@"Malformed streams response"}];
                ASCOnMain(^{ if (completion) completion(nil, e); });
                return;
            }
            NSDictionary *dict = (NSDictionary *)obj;
            ASCOnMain(^{ if (completion) completion(dict, nil); });
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

- (void)fetchFreshAccessToken:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion {
    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { ASCOnMain(^{ if (completion) completion(nil, err); }); return; }
        NSString *tok = nil;
        @synchronized (self) { tok = [[_accessToken copy] autorelease]; }
        ASCOnMain(^{ if (completion) completion(tok, nil); });
    }];
}


- (void)_ensureFreshAccessToken:(StravaAuthCompletion)completion
{
    if ([self _accessTokenIsFresh]) { ASCOnMain(^{ if (completion) completion(nil); }); return; }

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
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) { ASCOnMain(^{ if (completion) completion(error); }); return; }

            NSError *jsonErr = nil;
            id obj = ASCJSON(data, &jsonErr);
            if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"Malformed token refresh"}];
                ASCOnMain(^{ if (completion) completion(e); });
                return;
            }

            NSDictionary *dict = (NSDictionary *)obj;
            NSString *access  = dict[@"access_token"];
            NSString *refresh = dict[@"refresh_token"];
            NSNumber *exp     = dict[@"expires_at"];   // seconds since epoch

            ASC_RELEASE(unretainedSelf->_accessToken);
            unretainedSelf->_accessToken = [access copy];

            if (refresh.length) {
                ASC_RELEASE(unretainedSelf->_refreshToken);
                unretainedSelf->_refreshToken = [refresh copy];
            }
            unretainedSelf->_accessExpiresAt = [exp isKindOfClass:[NSNumber class]] ? exp.doubleValue : 0;

            [unretainedSelf _persistTokens];
            ASCOnMain(^{ if (completion) completion(nil); });
        }];
        [self _trackTask:task];
        [task resume];
        return;
    }

    // No valid/refreshable token -> do full auth (your existing code)
    ASCOnMain(^{
        NSWindow *host = [NSApp keyWindow] ?: [NSApp mainWindow];
        if (!host) {
            host = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                               styleMask:NSWindowStyleMaskBorderless
                                                 backing:NSBackingStoreBuffered
                                                   defer:YES] autorelease];
        }
        [self startAuthorizationFromWindow:host completion:^(NSError * _Nullable err) {
            if (!err) [self _persistTokens]; // startAuthorization sets tokens on success
            if (completion) completion(err);
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


- (void)fetchActivityPhotos:(NSNumber *)activityID
                       size:(NSUInteger)size
                      queue:(dispatch_queue_t)queue
                 completion:(StravaPhotosCompletion)completion
{
    if (!activityID) {
        if (completion) completion(nil, [NSError errorWithDomain:@"Strava" code:-30 userInfo:@{NSLocalizedDescriptionKey:@"Missing activity id"}]);
        return;
    }
    if (size == 0) size = 1024;

    [self _ensureFreshAccessToken:^(NSError * _Nullable err) {
        if (err) { if (completion) completion(nil, err); return; }

        NSString *url = [NSString stringWithFormat:
            @"https://www.strava.com/api/v3/activities/%@/photos?photo_sources=true&size=%lu",
            activityID, (unsigned long)size];

        NSURLRequest *req = [self _GET:url bearer:_accessToken];

        __unsafe_unretained StravaAPI *unretainedSelf = self;
        __block NSURLSessionDataTask *task = nil;
        task = [_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [unretainedSelf _untrackTask:task];

            if (error) { (queue ? dispatch_async(queue, ^{ if (completion) completion(nil, error); }) : ASCOnMain(^{ if (completion) completion(nil, error); })); return; }

            NSError *jsonErr = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
                NSError *e = jsonErr ?: [NSError errorWithDomain:@"Strava" code:-31 userInfo:@{NSLocalizedDescriptionKey:@"Malformed photos response"}];
                (queue ? dispatch_async(queue, ^{ if (completion) completion(nil, e); }) : ASCOnMain(^{ if (completion) completion(nil, e); }));
                return;
            }
            (queue ? dispatch_async(queue, ^{ if (completion) completion((NSArray *)obj, nil); }) : ASCOnMain(^{ if (completion) completion((NSArray *)obj, nil); }));
        }];
        [self _trackTask:task];
        [task resume];
    }];
}


@end
