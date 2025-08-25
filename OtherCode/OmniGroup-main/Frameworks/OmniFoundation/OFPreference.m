// Copyright 2001-2020 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFPreference.h>

#import <OmniFoundation/NSFileManager-OFSimpleExtensions.h> // For group container identifier utility

#import <OmniFoundation/OFEnumNameTable.h>
#import <OmniFoundation/OFNull.h>
#import <OmniFoundation/NSBundle-OFExtensions.h> // For -containingApplicationBundleIdentifier
#import <OmniFoundation/NSDate-OFExtensions.h> // For -initWithXMLString:
#import <OmniFoundation/OFErrors.h>
#import <OmniFoundation/OFBindingPoint.h>
#import <OmniFoundation/OFMultiValueDictionary.h>
#import <OmniFoundation/NSString-OFURLEncoding.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniFoundation/NSUserDefaults-OFExtensions.h>
#import <Foundation/NSScriptCommand.h>
#import <Foundation/NSScriptObjectSpecifiers.h>
#endif

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Id$");

NS_ASSUME_NONNULL_BEGIN

//#define DEBUG_PREFERENCES

static NSObject *unset = nil;

NSString * const OFPreferenceObjectValueBinding = @"objectValue";
NSString * const OFPreferenceDidChangeNotification = @"OFPreferenceDidChangeNotification";

@interface OFPreferenceWrapper ()
{
@package
    NSUserDefaults *_userDefaults;
    volatile unsigned _registrationGeneration;
    NSNotificationCenter *_preferenceNotificationCenter;
    NSLock *_preferencesLock;
}
@end


@interface OFPreference ()
{
@protected
    __weak OFPreferenceWrapper *_wrapper;

    // OFEnumeratedPreference references these
    NSString *_key;
    id _value;
}
@end

@interface OFEnumeratedPreference : OFPreference
{
    OFEnumNameTable *names;
}

- (id)_initWithKey:(NSString * )key enumeration:(OFEnumNameTable *)enumeration wrapper:(OFPreferenceWrapper *)wrapper;

@end

@implementation OFPreference
{
    unsigned _generation;
    id _defaultValue;
    
    id _controller;
    NSString *_controllerKey;
    BOOL _updatingController;
}

static id _Nullable _retainedObjectValue(OFPreference *self, id const *_value, NSString *key)
{
    id result = nil;

    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return nil;
    }

    @synchronized(self) {
        if (self->_generation != wrapper->_registrationGeneration)
            result = [unset retain];
        else
            result = [*_value retain];
    }
    
    if (result == unset) {
        [result release];
        [self _refresh];
        return _retainedObjectValue(self, _value, key); // gcc does tail-call optimization
    }

#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) -> %@", self, key, result);
#endif

    return result;
}

static inline id _Nullable _objectValue(OFPreference *self, id const *_value, NSString *key, NSString *className)
{
    id result = [_retainedObjectValue(self, _value, key) autorelease];

    // We use a class name rather than a class to avoid calling +class when assertions are off
    OBASSERT(!result || [result isKindOfClass: NSClassFromString(className)]);

    return result;
}

static void _setValueUnderlyingValue(OFPreference *self, OFPreferenceWrapper *wrapper, id _Nullable controller, NSString * _Nullable keyPath, NSString *key, id _Nullable value)
{
    // Per discussion with tjw in <bug:///122290> (Bug: OFPreference deadlock), we should avoid writing to OFPreference from a background thread/queue.
    // The original design of OFPreference was that it would be readable in a thread-safe way from any queue, but that writing to it should happen on the main queue.
    //
    // Assert that we are on the main thread, and we'll independently fix the call sites.
    // It's possible that we may be able to relax this restriction to only preference instances associated with a controller, but we'd prefer to assert on all non-main-thread writes for now, and fix the fallout.
    
    OBPRECONDITION([NSThread isMainThread]);
    
    if (self->_updatingController)
        controller = nil;
    
    BOOL setUpdating = (controller && !self->_updatingController);
    if (setUpdating)
        self->_updatingController = YES;
    
    [self willChangeValueForKey:OFPreferenceObjectValueBinding];
    
    @try {
        if (value) {
            [wrapper->_userDefaults setObject:value forKey:key];
            if (controller)
                [controller setValue:value forKeyPath:keyPath];
        } else {
            [wrapper->_userDefaults removeObjectForKey:key];
            if (controller)
                [controller setValue:nil forKeyPath:keyPath];
        }
    } @finally {
        [self didChangeValueForKey:OFPreferenceObjectValueBinding];

        if (setUpdating)
            self->_updatingController = NO;
    }
}

static void _setValue(OFPreference *self, OB_STRONG id *_value, NSString *key, _Nullable id value)
{
    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return;
    }

    @synchronized(self) {
        // If this preference is created & used by a OAPreferenceClient, or other NSController, use KVC on the controller to set the preference so that other observers of the controller will get notified via KVO.
        // This introduces an(other?) ugly bit, though.  Our OAPreferenceClient instances each use a OFPreferenceWrapper.  This creates a feedback loop on setting in some cases (particularly clearing to a default value).  So, we have _updatingController to record whether we are getting called recursively.
        NSString *keyPath;
        id controller = self->_controller;
        NSString *controllerKey = self->_controllerKey;
        
        if (controller) {
            if (controllerKey)
                keyPath = [NSString stringWithFormat:@"%@.%@", controllerKey, key];
            else
                keyPath = key;
        } else {
            // Won't be used anyway
            keyPath = nil;
        }

        if (value) {
            [value retain];
            [*_value release];
            *_value = value;
            
            _setValueUnderlyingValue(self, wrapper, controller, keyPath, key, value);
#ifdef DEBUG_PREFERENCES
            NSLog(@"OFPreference(0x%08x:%@) <- %@", self, key, *_value);
#endif
        } else {
            _setValueUnderlyingValue(self, wrapper, controller, keyPath, key, value);
            
            // Get the new value exposed by removing this from the user default domain
            [*_value release];
            *_value = [unset retain];

#ifdef DEBUG_PREFERENCES
            NSLog(@"OFPreference(0x%08x:%@) <- nil (is now %@)", self, key, *_value);
#endif
        }
    }
    
    // Tell anyone who is interested that this default changed
    [wrapper->_preferenceNotificationCenter postNotificationName:OFPreferenceDidChangeNotification object:self];
}

+ (void) initialize;
{
    OBINITIALIZE;
    
    unset = [[NSObject alloc] init];  // just getting a guaranteed-unique, retainable/releasable object
}

+ (NSSet <NSString *> *)registeredKeys;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] registeredKeys];
}

+ (void)recacheRegisteredKeys
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] recacheRegisteredKeys];
}

+ (void)registerDefaultValue:(id)value forKey:(NSString *)key options:(OFPreferenceRegistrationOptions)options;
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] registerDefaultValue:value forKey:key options:options];
}

+ (void)registerDefaults:(NSDictionary<NSString *, id> *)registrationDictionary options:(OFPreferenceRegistrationOptions)options;
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] registerDefaults:registrationDictionary options:options];
}

+ (void)addObserver:(id)anObserver selector:(SEL)aSelector forPreference:(OFPreference * _Nullable)aPreference;
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] addObserver:anObserver selector:aSelector forPreference:aPreference];
}

+ (id)addObserverForPreference:(nullable OFPreference *)preference usingBlock:(void (^)(OFPreference *preference))block;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] addObserverForPreference:preference usingBlock:block];
}

+ (void)removeObserver:(id)anObserver forPreference:(OFPreference * _Nullable)aPreference;
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] removeObserver:anObserver forPreference:aPreference];
}

+ (nullable id)coerceStringValue:(nullable NSString *)stringValue toTypeOfPropertyListValue:(id)propertyListValue error:(NSError **)outError;
{
    // This block helper unconditionally returns nil, and populates the given outError with error details specific to the (captured) stringValue and propertyListValue. Parsing code below can use this helper as a one-line return statement: return coercionFailure(outError);
    id (^coercionFailure)(NSError **) = ^id(NSError **localOutError) { // avoid shadowing
        if (localOutError != NULL) {
            NSString *description = NSLocalizedStringFromTableInBundle(@"Unable to parse value", @"OmniFoundation", OMNI_BUNDLE, @"error description");
            NSString *failureReason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to convert '%@' to the same type as '%@' (%@)", @"OmniFoundation", OMNI_BUNDLE, @"error reason"), stringValue, propertyListValue, [propertyListValue class]];
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : description, NSLocalizedFailureReasonErrorKey : failureReason };
            *localOutError = [NSError errorWithDomain:OFErrorDomain code:OFValueTypeCoercionFailure userInfo:userInfo];
        }
        return nil;
    };
    
    if (stringValue == nil || [stringValue isNull]) { // null
        return [NSNull null];
    } else if ([propertyListValue isKindOfClass:[NSString class]]) { // <string>
        return stringValue;
    } else if ([propertyListValue isKindOfClass:[NSNumber class]]) { // <real> or <integer> or <true/> or <false/>
        const char *objCType = [(NSNumber *)propertyListValue objCType];
        if (strcmp(objCType, @encode(int)) == 0) // <integer> on 32-bit platform
            return [NSNumber numberWithInt:[stringValue intValue]];
        else if (strcmp(objCType, @encode(long)) == 0) // <integer> on 64-bit platform
            return [NSNumber numberWithInteger:[stringValue integerValue]];
        else if (strcmp(objCType, @encode(double)) == 0) // <real>
            return [NSNumber numberWithDouble:[stringValue doubleValue]];
        else if (strcmp(objCType, @encode(char)) == 0) // <true/> or <false/>
            return [NSNumber numberWithBool:[stringValue boolValue]];
        else {
            OBASSERT((strcmp(objCType, @encode(double)) == 0)); // ??? What is this new property list type?
            return [NSNumber numberWithDouble:[stringValue doubleValue]];
        }
    } else if ([propertyListValue isKindOfClass:[NSDate class]]) { // <date>
        return [[[NSDate alloc] initWithXMLString:stringValue] autorelease];
    } else if ([propertyListValue isKindOfClass:[NSData class]]) { // <data> (not yet implemented)
        OBASSERT(![propertyListValue isKindOfClass:[NSData class]]);
        NSLog(@"+[OFPreference coerceStringValue:toTypeOfPropertyListValue:error: unimplemented conversion to NSData");
        return coercionFailure(outError);
    } else if ([propertyListValue isKindOfClass:[NSArray class]]) { // <array>
        id coercedValue = [stringValue propertyList];
        if (![coercedValue isKindOfClass:[NSArray class]])
            return coercionFailure(outError);
        return coercedValue;
    } else if ([propertyListValue isKindOfClass:[NSDictionary class]]) { // <dict>
        id coercedValue = [stringValue propertyList];
        if (![coercedValue isKindOfClass:[NSDictionary class]])
            return coercionFailure(outError);
        return coercedValue;
    }
    return coercionFailure(outError);
}

// OFPreference instances must be uniqued, so you should always go through +preferenceForKey:
- init;
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    NSScriptCommand *command = [NSScriptCommand currentCommand];
    if (command) {
        // Some one doing 'make new' in a script; don't crash but log an error
        [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [command setScriptErrorString:@"Preferences cannot be defined by scripts."];
        
        [self release];
        return nil;
    }
#endif

    OBRejectUnusedImplementation(self, _cmd);
}

- (void)dealloc;
{
    // Instances are currently held onto forever, so we shouldn't hit this.
    OBPRECONDITION(NO);
    
    [_key release];
    [_value release];
    [_defaultValue release];
    [_controller release];
    [_controllerKey release];
    [super dealloc];
}

// Subclass methods

- (NSUInteger) hash;
{
    return [_key hash];
}

- (BOOL) isEqual: (id) otherPreference;
{
    return [_key isEqual: [otherPreference key]];
}

#pragma mark API

+ (BOOL)hasPreferenceForKey:(NSString *)key;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] hasPreferenceForKey:key];
}

+ (OFPreference *)preferenceForKey:(NSString *)key;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] preferenceForKey:key];
}

+ (OFPreference *)preferenceForKey:(NSString *)key enumeration:(OFEnumNameTable * _Nullable)enumeration;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] preferenceForKey:key enumeration:enumeration];
}

+ (OFPreference *)preferenceForKey:(NSString *)key defaultValue:(id)value;
{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] preferenceForKey:key defaultValue:value];
}

- (NSString *) key;
{
    return _key;
}

- (OFEnumNameTable * _Nullable) enumeration
{
    return nil;
}

- (id)controller;
{
    return _controller;
}

- (NSString *)controllerKey;
{
    return _controllerKey;
}

- (void)setController:(id)controller key:(NSString *)controllerKey;
{
    // Should be set once when setting up a preference controller.
    OBPRECONDITION(_controller == nil);
    OBPRECONDITION(_controllerKey == nil);
    
    _controller = [controller retain];
    _controllerKey = [controllerKey copy];
}

- (id) defaultObjectValue;
{
    NSDictionary *registrationDictionary;
    id defaultValue;

    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return nil;
    }

    @synchronized(self) {
        if (_defaultValue != nil && _generation != wrapper->_registrationGeneration) {
	    [_defaultValue release];
	    _defaultValue = nil;
	}
	defaultValue = _defaultValue;
    }

    if (defaultValue != nil)
        return _defaultValue;

    registrationDictionary = [wrapper->_userDefaults volatileDomainForName:NSRegistrationDomain];
    defaultValue = [registrationDictionary objectForKey:_key];

    @synchronized(self) {
	if (_defaultValue == nil)
	    _defaultValue = [defaultValue retain];
    }

    return defaultValue;
}

- (BOOL)hasNonDefaultValue;
{
    id defaultValue = [self defaultObjectValue];
    if (defaultValue == nil)
        return NO;
    id value = [self objectValue];
    return !OFISEQUAL(value, defaultValue);
}


- (void) restoreDefaultValue;
{
    _setValue(self, &_value, _key, nil);
}

- (BOOL) hasPersistentValue;
{
    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return NO;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    for (NSString *domain in @[bundleIdentifier, NSGlobalDomain]) {
        id value = [[wrapper->_userDefaults persistentDomainForName:domain] objectForKey:_key];
        if (value != nil) {
            return YES;
        }
    }
    
    return NO;
}

- (_Nullable id) objectValue;
{
    return _objectValue(self, &_value, _key, @"NSObject");
}

- (NSString * _Nullable) stringValue;
{
    return [[self objectValue] description];
}

- (NSArray * _Nullable) arrayValue;
{
    return _objectValue(self, &_value, _key, @"NSArray");
}

- (NSDictionary * _Nullable) dictionaryValue;
{
    return _objectValue(self, &_value, _key, @"NSDictionary");
}

- (NSData * _Nullable) dataValue;
{
    return _objectValue(self, &_value, _key, @"NSData");
}

- (NSURL * _Nullable) bookmarkURLValue;
{
    NSData *bookmarkData = [self dataValue];
    if (bookmarkData.length == 0)
        return nil;
    
    BOOL isStale = NO;
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    NSURLBookmarkResolutionOptions resolutionOptions = NSURLBookmarkResolutionWithSecurityScope;
#else
    NSURLBookmarkResolutionOptions resolutionOptions = 0;
#endif
    NSURL *bookmarkURL = [NSURL URLByResolvingBookmarkData:bookmarkData options:resolutionOptions relativeToURL:nil bookmarkDataIsStale:&isStale error:NULL];
    return bookmarkURL;
}

- (void)setBookmarkURLValue:(NSURL * _Nullable)bookmarkURL;
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    NSURLBookmarkCreationOptions creationOptions = NSURLBookmarkCreationWithSecurityScope;
#else
    NSURLBookmarkCreationOptions creationOptions = 0;
#endif
    NSData *bookmarkData = bookmarkURL != nil ? [bookmarkURL bookmarkDataWithOptions:creationOptions includingResourceValuesForKeys:nil relativeToURL:nil error:NULL] : nil;
    [self setDataValue:bookmarkData];
}

- (int) intValue;
{
    id number;
    int result;

    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number intValue];
    else
        result = 0;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %d", self, _key, _cmd, result);
#endif
    
    return result;
}

- (NSInteger) integerValue;
{
    id number;
    NSInteger result;
    
    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number integerValue];
    else
        result = 0;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %d", self, _key, _cmd, result);
#endif
    
    return result;
}

- (unsigned int) unsignedIntValue;
{
    id number;
    unsigned int result;

    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number unsignedIntValue];
    else
        result = 0;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %d", self, _key, _cmd, result);
#endif

    return result;
}

- (NSUInteger) unsignedIntegerValue;
{
    id number;
    NSUInteger result;
    
    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number unsignedIntegerValue];
    else
        result = 0;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %d", self, _key, _cmd, result);
#endif
    
    return result;
}

- (float) floatValue;
{
    id number;
    float result;

    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number floatValue];
    else
        result = 0.0f;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %f", self, _key, _cmd, result);
#endif

    return result;
}

- (double) doubleValue;
{
    id number;
    double result;
    
    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number doubleValue];
    else
        result = 0.0f;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %f", self, _key, _cmd, result);
#endif
    
    return result;
}

- (BOOL) boolValue;
{
    id number;
    BOOL result;

    number = _retainedObjectValue(self, &_value, _key);
    OBASSERT(!number || [number isKindOfClass: [NSNumber class]] || [number isKindOfClass: [NSString class]]);
    if (number)
        result = [number boolValue];
    else
        result = NO;
    [number release];
#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) %s -> %s", self, _key, _cmd, result ? "YES" : "NO");
#endif

    return result;
}

- (NSArray <NSString *> * _Nullable)stringArrayValue;
{
    return [self arrayValue];
}

- (NSInteger) enumeratedValue
{
    [NSException raise:NSInvalidArgumentException format:@"-%@ called on non-enumerated %@ (%@)", NSStringFromSelector(_cmd), [self shortDescription], _key];
    return INT_MIN; // unreached; and unlikely to be a valid enumeration value
}

- (void)setObjectValue:(id _Nullable)value;
{
    _setValue(self, &_value, _key, value);
}

- (void)setStringValue:(NSString * _Nullable)value;
{
    OBPRECONDITION(!value || [value isKindOfClass: [NSString class]]);
    _setValue(self, &_value, _key, value);
}

- (void)setArrayValue:(NSArray * _Nullable)value;
{
    OBPRECONDITION(!value || [value isKindOfClass: [NSArray class]]);
    _setValue(self, &_value, _key, value);
}

- (void)setDictionaryValue:(NSDictionary * _Nullable)value;
{
    OBPRECONDITION(!value || [value isKindOfClass: [NSDictionary class]]);
    _setValue(self, &_value, _key, value);
}

- (void)setDataValue:(NSData * _Nullable)value;
{
    OBPRECONDITION(!value || [value isKindOfClass: [NSData class]]);
    _setValue(self, &_value, _key, value);
}

- (void) setIntValue: (int) value;
{
    NSNumber *number = [[NSNumber alloc] initWithInt: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void) setIntegerValue: (NSInteger) value;
{
    NSNumber *number = [[NSNumber alloc] initWithInteger: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void) setUnsignedIntValue: (unsigned int) value;
{
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInt: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void) setUnsignedIntegerValue: (NSUInteger) value;
{
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInteger: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void) setFloatValue: (float) value;
{
    NSNumber *number = [[NSNumber alloc] initWithFloat: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void) setDoubleValue: (double) value;
{
    NSNumber *number = [[NSNumber alloc] initWithDouble: value];
    _setValue(self, &_value, _key, number);
    [number release];
}


- (void) setBoolValue: (BOOL) value;
{
    NSNumber *number = [[NSNumber alloc] initWithBool: value];
    _setValue(self, &_value, _key, number);
    [number release];
}

- (void)setEnumeratedValue:(NSInteger)value;
{
    [NSException raise:NSInvalidArgumentException format:@"-%@ called on non-enumerated %@ (%@)", NSStringFromSelector(_cmd), [self shortDescription], _key];
}

- (void)addObserver:(id)anObserver selector:(SEL)aSelector;
{
    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return;
    }

    [wrapper addObserver:anObserver selector:aSelector forPreference:self];
}

- (void)removeObserver:(id)anObserver;
{
    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return;
    }

    [wrapper removeObserver:anObserver forPreference:self];
}

#pragma mark AppleScript Support

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE

- (NSScriptObjectSpecifier * _Nullable)objectSpecifier;
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    // We assume that preferences will be owned by the application with an element of @"scriptPreferences".  This is what OAApplication does.
    id application = [NSClassFromString(@"NSApplication") performSelector:@selector(sharedApplication)];
    return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[application classDescription] containerSpecifier:[application objectSpecifier] key:@"scriptPreferences" uniqueID:_key] autorelease];
#pragma clang diagnostic pop
}

- (NSString *)scriptIdentifier;
{
    return _key;
}

- (_Nullable id)scriptValue;
{
    id value = [self objectValue];
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSData class]])
        return [value description];
    else
        return value;
}

- (void)setScriptValue:(_Nullable id)value;
{
    // TODO: Make sure this is a plist type?
    // Cocoa Scripting should do this for us, or reject the apple event, before we are ever called.

    if ([value isKindOfClass:[NSString class]])
        value = [[self class] coerceStringValue:value toTypeOfPropertyListValue:[self defaultObjectValue] error:NULL];

    [self setObjectValue:value];
}

- (id)scriptDefaultValue;
{
    id value = [self defaultObjectValue];
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSData class]])
        return [value description];
    else
        return value;
}

#endif

#pragma mark Private

- (id)_initWithKey:(NSString * )key wrapper:(OFPreferenceWrapper *)wrapper;
{
    OBPRECONDITION(wrapper != nil);
    OBPRECONDITION(key != nil);

    _wrapper = wrapper;
    _key = [key copy];
    _generation = 0;
    _value = [unset retain];
    
    return self;
}

- (void)_refresh
{
    OFPreferenceWrapper *wrapper = self->_wrapper;
    if (wrapper == nil) {
        OBASSERT_NOT_REACHED("Using a preference from a deallocated OFPreferenceWrapper");
        return;
    }

    unsigned newGeneration;
    id newValue;

    [wrapper->_preferencesLock lock];
/// rcb ifdef'd out - FIXME
#if 0
#ifdef DEBUG
    if (![_key hasPrefix:@"SiteSpecific:"] && ![[wrapper->_userDefaults volatileDomainForName:NSRegistrationDomain] objectForKey:_key]) {
        NSLog(@"OFPreference: No default value is registered for '%@'", _key);
        OBPRECONDITION([[wrapper->_userDefaults volatileDomainForName:NSRegistrationDomain] objectForKey:_key]);
    }
#endif
#endif
    
    newGeneration = wrapper->_registrationGeneration;
    newValue = [[wrapper->_userDefaults objectForKey: _key] retain];
    [wrapper->_preferencesLock unlock];

#ifdef DEBUG_PREFERENCES
    NSLog(@"OFPreference(0x%08x:%@) faulting in value %@ generation %u", self, _key, newValue, newGeneration);
#endif

    @synchronized(self) {
        [_value release];
        _value = newValue;
	if (_generation != newGeneration) {
	    [_defaultValue release];
	    _defaultValue = nil;
	    _generation = newGeneration;
	}
    }
}

@end

@implementation OFEnumeratedPreference

- (id)_initWithKey:(NSString * )key enumeration:(OFEnumNameTable *)enumeration wrapper:(OFPreferenceWrapper *)wrapper;
{
    if (!(self = [super _initWithKey:key wrapper:wrapper]))
        return nil;
    names = [enumeration retain];
    return self;
}

// no -dealloc: we are never deallocated

- (OFEnumNameTable * _Nullable) enumeration
{
    // API-wise, this has to be nullable, but for our instances it never should be.
    OBPRECONDITION(names != nil);

    return names;
}

- (id)defaultObjectValue
{
    id defaultValue = [super defaultObjectValue];
    if (defaultValue == nil)
        return [names nameForEnum:[names defaultEnumValue]];
    else
        return defaultValue;
}

#define BAD_TYPE_IMPL(x) { [NSException raise:NSInvalidArgumentException format:@"-%@ called on enumerated %@ (%@)", NSStringFromSelector(_cmd), [self shortDescription], _key]; x; }

- (NSString * _Nullable)stringValue;            BAD_TYPE_IMPL(return nil)
- (NSArray * _Nullable)arrayValue;              BAD_TYPE_IMPL(return nil)
- (NSDictionary * _Nullable)dictionaryValue;    BAD_TYPE_IMPL(return nil)
- (NSData * _Nullable)dataValue;                BAD_TYPE_IMPL(return nil)
- (int)intValue;                      BAD_TYPE_IMPL(return 0)
- (NSInteger)integerValue             BAD_TYPE_IMPL(return 0)
- (unsigned int)unsignedIntValue;     BAD_TYPE_IMPL(return 0)
- (NSUInteger)unsignedIntegerValue    BAD_TYPE_IMPL(return 0)
- (float)floatValue;                  BAD_TYPE_IMPL(return 0)
- (double)doubleValue;                BAD_TYPE_IMPL(return 0)
- (BOOL)boolValue;                    BAD_TYPE_IMPL(return NO)

- (NSInteger)enumeratedValue;
{
    id value = _retainedObjectValue(self, &_value, _key);
    
    NSInteger result;
    if ([value isKindOfClass:[NSNumber class]]) {
        result = [(NSNumber *)value integerValue];
        [value release];
    } else if ([value isKindOfClass:[NSString class]]) {
        result = [names enumForName:value];
        [value release];
    } else {
        OBASSERT_NOT_REACHED("Enumerated preference not a string or a number");
        [value release];
        result = [names defaultEnumValue];
    }
    
    return result;
}

- (void)setStringValue:(NSString * _Nullable)value;            BAD_TYPE_IMPL(;)
- (void)setArrayValue:(NSArray * _Nullable)value;              BAD_TYPE_IMPL(;)
- (void)setDictionaryValue:(NSDictionary * _Nullable)value;    BAD_TYPE_IMPL(;)
- (void)setDataValue:(NSData * _Nullable)value;                BAD_TYPE_IMPL(;)
- (void)setIntValue:(int)value;                      BAD_TYPE_IMPL(;)
- (void)setIntegerValue:(NSInteger)value;            BAD_TYPE_IMPL(;)
- (void)setFloatValue:(float)value;                  BAD_TYPE_IMPL(;)
- (void)setDoubleValue:(double)value;                BAD_TYPE_IMPL(;)
- (void)setBoolValue:(BOOL)value;                    BAD_TYPE_IMPL(;)

- (void)setEnumeratedValue:(NSInteger)value;
{
    [self setObjectValue:[names nameForEnum:value]];
}

@end

// MARK: -

@implementation OFPreferenceWrapper
{
@private
    NSMutableDictionary <NSString *, OFPreference *> *_preferencesByKey;
    NSSet <NSString *> * _Nullable _registeredKeysCache;
}

+ (OFPreferenceWrapper *)sharedPreferenceWrapper;
{
    static OFPreferenceWrapper *sharedPreferenceWrapper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPreferenceWrapper = [[OFPreferenceWrapper alloc] _initWithSuiteName:nil];
    });

    return sharedPreferenceWrapper;
}

static NSMutableDictionary <NSString *, OFPreferenceWrapper *> *PreferenceWrapperBySuiteName;
static NSLock *PreferenceWrapperLock;

+ (OFPreferenceWrapper *)groupContainerIdentifierForContainingApplicationBundleIdentifierPreferenceWrapper;
{
    NSString *containingApplicationBundleIdentifier = NSBundle.containingApplicationBundleIdentifier;
    return [self preferenceWrapperWithGroupIdentifier:containingApplicationBundleIdentifier];
}

+ (OFPreferenceWrapper *)preferenceWrapperWithSuiteName:(NSString *)suiteName;
{
    OBPRECONDITION(suiteName != nil);

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PreferenceWrapperLock = [[NSLock alloc] init];
        PreferenceWrapperBySuiteName = [[NSMutableDictionary alloc] init];
    });

    [PreferenceWrapperLock lock];
    OFPreferenceWrapper *wrapper = PreferenceWrapperBySuiteName[suiteName];
    if (wrapper == nil) {
        wrapper = [[[OFPreferenceWrapper alloc] _initWithSuiteName:suiteName] autorelease];
        PreferenceWrapperBySuiteName[suiteName] = wrapper;
    }
    [PreferenceWrapperLock unlock];

    return wrapper;
}

// For preference domains that should be stored in a group container. This should be the base identifer ("com.mycompany.appname") and the appropriate prefix will be added to the suite name for the current platform.
+ (OFPreferenceWrapper *)preferenceWrapperWithGroupIdentifier:(NSString *)suiteName;
{
    // TODO: Move this method off NSFileManager(OFSimpleExtensions) to NSProcessInfo?

    return [self preferenceWrapperWithSuiteName:[[NSFileManager defaultManager] groupContainerIdentifierForBaseIdentifier:suiteName]];
}

- _initWithSuiteName:(nullable NSString *)suiteName;
{
    self = [super init];

    _suiteName = [suiteName copy];

    // The second case can come up when running unit tests and we end up with com.apple.dt.xctest.tool for both the main bundle and for the containingApplicationBundleIdentifier (since that short circuits when running unit tests to avoid trying to write into Xcode's preferences).
    if (suiteName == nil || [suiteName isEqual:[[NSBundle mainBundle] bundleIdentifier]]) {
        _userDefaults = [[NSUserDefaults standardUserDefaults] retain];
    } else {
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    }

    [_userDefaults volatileDomainForName:NSRegistrationDomain]; // avoid a race condition
    _preferencesByKey = [[NSMutableDictionary alloc] init];
    _preferencesLock = [[NSLock alloc] init];

    _preferenceNotificationCenter = [[NSNotificationCenter alloc] init];

    _registrationGeneration = 1;

    return self;
}

- (void) dealloc;
{
    OBRejectUnusedImplementation(self, _cmd); // OFPreferenceWrapper instances should never be deallocated
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
    [super dealloc]; // We know this won't be reached, but w/o this we get a warning about a missing call to super -dealloc
#pragma clang diagnostic pop
}

- (NSSet <NSString *> *)registeredKeys;
{
    NSSet <NSString *> *result;

    ///[_preferencesLock lock];

    if (_registeredKeysCache == nil) {
        NSMutableSet *keys = [[NSMutableSet alloc] init];
        [keys addObjectsFromArray:[_preferencesByKey allKeys]];
        [keys addObjectsFromArray:[[_userDefaults volatileDomainForName:NSRegistrationDomain] allKeys]];
        _registeredKeysCache = [keys copy];
        [keys release];
    }

    result = [_registeredKeysCache retain];

    [_preferencesLock unlock];

    return [result autorelease];
}

- (NSUserDefaults *)underlyingUserDefaults;
{
    return _userDefaults;
}

- (void)recacheRegisteredKeys
{
    [_preferencesLock lock];
    [_registeredKeysCache release];
    _registeredKeysCache = nil;
    _registrationGeneration ++;
    [_preferencesLock unlock];
}

- (void)registerDefaultValue:(id)value forKey:(NSString *)key options:(OFPreferenceRegistrationOptions)options;
{
    NSDictionary *registrationDictionary = @{key: value};
    [self registerDefaults:registrationDictionary options:options];
}

- (void)registerDefaults:(NSDictionary<NSString *, id> *)registrationDictionary options:(OFPreferenceRegistrationOptions)options;
{
    NSSet<NSString *> *registeredKeys = self.registeredKeys;
    BOOL shouldOverwriteExistingRegistration = ((options & OFPreferenceRegistrationPreserveExistingRegistrations) == 0);

    BOOL (^shouldRegisterDefaultForKey)(NSString * _Nullable key) = ^BOOL (NSString * _Nullable key) {
        return (key != nil) && (shouldOverwriteExistingRegistration || ![registeredKeys containsObject:key]);
    };

    if (registrationDictionary.count == 1) {
        NSString *key = registrationDictionary.allKeys.firstObject;
        if (shouldRegisterDefaultForKey(key)) {
            OBASSERT(_preferencesByKey[key] == nil, "Registering defaults for key %@ that was already accessed via OFPreference.", key);
            [_userDefaults registerDefaults:registrationDictionary];
            [self recacheRegisteredKeys];
        }
    } else {
        NSMutableArray<NSString *> *filteredKeys = nil;

        for (NSString *key in registrationDictionary) {

            if (!shouldRegisterDefaultForKey(key)) {
                if (filteredKeys == nil) {
                    filteredKeys = [NSMutableArray array];
                }
                [filteredKeys addObject:key];
            } else {
                OBASSERT(_preferencesByKey[key] == nil, "Registering defaults for key %@ that was already accessed via OFPreference.", key);
            }
        }

        if (filteredKeys != nil && filteredKeys.count == registrationDictionary.count) {
            return;
        }

        if (filteredKeys != nil) {
            NSMutableDictionary *filteredRegistrationDictionary = [NSMutableDictionary dictionaryWithDictionary:registrationDictionary];
            [filteredRegistrationDictionary removeObjectsForKeys:filteredKeys];
            registrationDictionary = filteredRegistrationDictionary;
        }

        [_userDefaults registerDefaults:registrationDictionary];
        [self recacheRegisteredKeys];
    }
}

- (void)addObserver:(id)anObserver selector:(SEL)aSelector forPreference:(OFPreference * _Nullable)aPreference;
{
    OBPRECONDITION(aPreference == nil || aPreference.wrapper == self, "Don't addObserver for notifications via incorrect OFPreferenceWrapper. This could happen using OFPreference class methods for a preference registered to the group container OFPreferenceWrapper.");
    [_preferenceNotificationCenter addObserver:anObserver selector:aSelector name:OFPreferenceDidChangeNotification object:aPreference];
}

- (id)addObserverForPreference:(nullable OFPreference *)preference usingBlock:(void (^)(OFPreference *preference))block;
{
    id result = [_preferenceNotificationCenter addObserverForName:OFPreferenceDidChangeNotification object:preference queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        OFPreference *changedPreference = note.object;
        if ([changedPreference isKindOfClass:[OFPreference class]]) {
            block(changedPreference);
        }
    }];
    return result;
}

- (void)removeObserver:(id)anObserver forPreference:(OFPreference * _Nullable)aPreference;
{
    OBPRECONDITION(aPreference == nil || aPreference.wrapper == self, "Don't removeObserver for notifications via incorrect OFPreferenceWrapper. This could happen using OFPreference class methods for a preference registered to the group container OFPreferenceWrapper.");
    [_preferenceNotificationCenter removeObserver:anObserver name:OFPreferenceDidChangeNotification object:aPreference];
}

- (BOOL)hasPreferenceForKey:(NSString *)key;
{
    BOOL hasPreferenceForKey = NO;

    [_preferencesLock lock];

    hasPreferenceForKey = ([_preferencesByKey objectForKey: key] != nil);

    [_preferencesLock unlock];

    return hasPreferenceForKey;
}

- (OFPreference *)preferenceForKey:(NSString *)key;
{
    return [self preferenceForKey:key enumeration:nil];
}

- (OFPreference *)preferenceForKey:(NSString *)key enumeration:(OFEnumNameTable * _Nullable)enumeration;
{
    OFPreference *preference;

    OBPRECONDITION(key);

    [_preferencesLock lock];
    preference = [[_preferencesByKey objectForKey: key] retain];
    if (!preference) {
        if (enumeration == nil) {
            preference = [[OFPreference alloc] _initWithKey:key wrapper:self];
        } else {
            preference = [[OFEnumeratedPreference alloc] _initWithKey:key enumeration:enumeration wrapper:self];
        }
        [_preferencesByKey setObject: preference forKey: key];
    }
    [_preferencesLock unlock];

    if (enumeration != nil) {
        // It's OK to pass in a nil value for the enumeration, if you know that the enumeration has already been set up
        assert([[preference enumeration] isEqual: enumeration]);
    }

    return [preference autorelease];
}

- (OFPreference *)preferenceForKey:(NSString *)key defaultValue:(id)value;
{
    [self registerDefaultValue:value forKey:key options:OFPreferenceRegistrationPreserveExistingRegistrations];

    return [self preferenceForKey:key];
}

- (nullable id)objectForKey:(NSString *)defaultName;
{
    return [[OFPreference preferenceForKey: defaultName] objectValue];
}

- (void)setObject:(nullable id)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setObjectValue:value];
}

- (nullable id)valueForKey:(NSString *)aKey;
{
    return [[self preferenceForKey:aKey] objectValue];
}

- (void)setValue:(nullable id)value forKey:(NSString *)aKey;
{
    [[self preferenceForKey:aKey] setObjectValue:value];
}

- (void)removeObjectForKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] restoreDefaultValue];
}

- (nullable NSString *)stringForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] stringValue];
}

- (nullable NSArray *)arrayForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] arrayValue];
}

- (nullable NSDictionary *)dictionaryForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] dictionaryValue];
}

- (nullable NSData *)dataForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] dataValue];
}

- (nullable NSURL *)bookmarkURLForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] bookmarkURLValue];
}

- (nullable NSArray *)stringArrayForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] stringArrayValue];
}

- (int)intForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] intValue];
}

- (NSInteger)integerForKey:(NSString *)defaultName;
{
    return [[self preferenceForKey:defaultName] intValue];
}

- (float)floatForKey:(NSString *)defaultName; 
{
    return [[self preferenceForKey:defaultName] floatValue];
}

- (double)doubleForKey:(NSString *)defaultName; 
{
    return [[self preferenceForKey:defaultName] floatValue];
}

- (BOOL)boolForKey:(NSString *)defaultName;  
{
    return [[self preferenceForKey:defaultName] boolValue];
}

- (void)setInt:(int)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setIntValue:value];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setIntegerValue:value];
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setFloatValue:value];
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setDoubleValue:value];
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
{
    [[self preferenceForKey:defaultName] setBoolValue:value];
}

- (BOOL)synchronize;
{
    return [_userDefaults synchronize];
}

- (NSDictionary *)volatileDomainForName:(NSString *)name;
{
    return [_userDefaults volatileDomainForName:name];
}

@end

static NSUserDefaults *StandardUserDefaults = nil;
static NSMutableDictionary *ConfigurationValueRegistrations = nil;

NSString * const OFChangeConfigurationValueURLPath = @"/change-configuration-value";

@interface OFConfigurationValue ()

@property(nonatomic,readonly) BOOL integral;

- (void)update;

@end

@implementation OFConfigurationValue
{
    NSMutableArray <OFConfigurationValueObserver> *_observers;
}

+ (void)initialize;
{
    OBINITIALIZE;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We've seen KVO crashes where it *looks* like the +standardUserDefaults is changing out from underneath us while we had an active observation. Hold on to the one we are going to observe (though we might lose updates).
        StandardUserDefaults = [[NSUserDefaults standardUserDefaults] retain];
        ConfigurationValueRegistrations = [[NSMutableDictionary alloc] init];
    });
}

+ (NSArray *)configurationValues;
{
    OBPRECONDITION([NSThread isMainThread]);
    
    return [ConfigurationValueRegistrations allValues];
}

+ (void)restoreAllConfigurationValuesToDefaults;
{
    [ConfigurationValueRegistrations enumerateKeysAndObjectsUsingBlock:^(NSString *configurationValueKey, OFConfigurationValue *configurationValue, BOOL *stop) {
        [configurationValue restoreDefaultValue];
    }];
}

// Each app has its own scheme. We could maybe determine it automatically if there is only one scheme.
static NSString *ConfigurationValuesURLScheme = nil;
+ (void)setConfigurationValuesURLScheme:(NSString *)scheme;
{
    OBPRECONDITION(scheme);
    ConfigurationValuesURLScheme = [scheme copy];
}

// An empty array is valid -- it produces a 'reset all' configuration
+ (NSURL *)URLForConfigurationValues:(NSArray *)configurationValues;
{
    if (ConfigurationValuesURLScheme == nil) {
        OBASSERT_NOT_REACHED("Expect to have call +setConfigurationValuesURLScheme: during app startup");
        return nil;
    }

    // Start by resetting everything to defaults
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@?all=", ConfigurationValuesURLScheme, OFChangeConfigurationValueURLPath];
    
    for (OFConfigurationValue *configurationValue in configurationValues) {
        if (configurationValue.hasNonDefaultValue) {
            double value = configurationValue.currentValue;
            
            NSString *quotedName = [NSString encodeURLString:configurationValue.key asQuery:YES leaveSlashes:NO leaveColons:NO];
            OBASSERT([quotedName isEqual:configurationValue.key], "We really expect pretty vanilla strings for configuration parameters since they are used as global variable names.");
            
            if (value == (NSInteger)value) {
                [urlString appendFormat:@"&%@=%ld", quotedName, (NSInteger)value];
            } else {
                [urlString appendFormat:@"&%@=%f", quotedName, value];
            }
        }
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    OBASSERT(url);
    return url;
}

static unsigned ConfigurationContext;

- initWithKey:(NSString *)key integral:(BOOL)integral defaultValue:(double)defaultValue minimumValue:(double)minimumValue maximumValue:(double)maximumValue;
{
    OBPRECONDITION(defaultValue >= minimumValue);
    OBPRECONDITION(defaultValue <= maximumValue);
    OBASSERT_IF(integral, defaultValue == floor(defaultValue));
    OBASSERT_IF(integral, minimumValue == floor(minimumValue));
    OBASSERT_IF(integral, maximumValue == floor(maximumValue));

    if (!(self = [super init])) {
        return nil;
    }
    
    _key = [key copy];
    _integral = integral;
    _defaultValue = defaultValue;
    _minimumValue = minimumValue;
    _maximumValue = maximumValue;

    [StandardUserDefaults addObserver:self forKeyPath:_key options:0 context:&ConfigurationContext];
    [self update];
    
    return self;
}

- (void)dealloc;
{
    [StandardUserDefaults removeObserver:self forKeyPath:_key context:&ConfigurationContext];

    [_key release];
    [_observers release];
    [super dealloc];
}

- (void)addValueObserver:(OFConfigurationValueObserver)observer;
{
    if (!_observers)
        _observers = [[NSMutableArray alloc] init];

    observer = [observer copy];
    [_observers addObject:observer];
    [observer release];
}

- (BOOL)hasNonDefaultValue;
{
    return self.currentValue != self.defaultValue;
}

- (void)restoreDefaultValue;
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:_key];
}

- (void)setValueFromString:(NSString *)stringValue;
{
    if (_integral) {
        NSInteger level = [stringValue integerValue];
        [[NSUserDefaults standardUserDefaults] setObject:@(level) forKey:_key];
    } else {
        double value = [stringValue doubleValue];
        [[NSUserDefaults standardUserDefaults] setObject:@(value) forKey:_key];
    }
}

- (void)setValueFromDouble:(double)value;
{
    // -update does the clamping and snapping to integral values when needed.
    [[NSUserDefaults standardUserDefaults] setObject:@(value) forKey:_key];
}

- (void)update;
{
    OBPRECONDITION([NSThread isMainThread]);
    
    double level = _defaultValue;
    if (_integral) {
        const char *env = getenv([_key UTF8String]); /* easier for command line tools */
        if (env)
            level = strtoul(env, NULL, 0);
        else if ([[NSUserDefaults standardUserDefaults] objectForKey:_key])
            level = [[NSUserDefaults standardUserDefaults] integerForKey:_key];
    } else {
        const char *env = getenv([_key UTF8String]); /* easier for command line tools */
        if (env)
            level = strtod(env, NULL);
        else if ([[NSUserDefaults standardUserDefaults] objectForKey:_key])
            level = [[NSUserDefaults standardUserDefaults] doubleForKey:_key];
    }

    level = CLAMP(level, _minimumValue, _maximumValue);

    // Log if the value is getting set to something non-zero the first time around, or if its changing the second time around.
    if (_currentValue != level) {
        if ((_currentValue == _defaultValue && level != _defaultValue) || (_currentValue != _defaultValue && level != _currentValue))
            NSLog(@"CONFIGURATION %@ = %g", _key, level);

        [self willChangeValueForKey:OFValidateKeyPath(self, currentValue)];
        _currentValue = level;
        [self didChangeValueForKey:OFValidateKeyPath(self, currentValue)];

        // Fire block based observers too
        NSArray <OFConfigurationValueObserver> *observers = [_observers copy];
        for (OFConfigurationValueObserver observer in observers) {
            observer(self);
        }
        [observers release];
    }
}

- (NSString *)debugDescription;
{
    return [NSString stringWithFormat:@"<%@:%p %@ integral:%d>", NSStringFromClass([self class]), self, _key, _integral];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context;
{
    if (object == StandardUserDefaults && context == &ConfigurationContext) {
        OBASSERT([keyPath isEqual:_key]);

        // Make sure this work is performed on the main thread, asynchronously, if necessary, in the case that we get notified by a background thread.
        //
        // N.B. We do this instead of passing a queue when registering for the notification because if we do, that will block the posting thread until the main thread handles the notification. But in the case of handling NSUserDefaultsDidChangeNotification we can end up deadlocking for one of two reasons:
        //
        // - Because OFPreference holds a lock on the posting thread,
        //   and we try to grab the lock on the main thread. See
        //   <bug:///122290> (Bug: OFPreference deadlock).
        //
        // - Because of a deadlock in NSUserDefaults/CFPreferences itself.
        //   Unfortunately Xcode terminated my debug session before I
        //   could grab the backtraces. I think we were setting a
        //   preference on the background thread, and the main thread
        //   was blocked in _CFPREFERENCES_IS_WAITING_FOR_CFPREFSD.
        //
        //   I'll update this comment when that data becomes available.
        //
        // So we'll just receive the notification on whatever thread posted it, then ensure we handle it asynchronously on the main thread if needed.

        OFMainThreadPerformBlock(^{
            [self update];
        });
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


@end

BOOL OFHandleChangeConfigurationValueURL(NSURL *url, NSError **outError, OFConfigurationValueChangeConfirmation confirm)
{
    OBPRECONDITION([NSThread isMainThread]);
    
    if (![[url path] isEqual:OFChangeConfigurationValueURLPath]) {
        NSString *reason = [NSString stringWithFormat:@"Expected URL to have a path of \"%@\", but it had \"%@\".", OFChangeConfigurationValueURLPath, [url path]];
        OFError(outError, OFChangeDebugLevelURLError, @"Cannot change the debug level.", reason);
        return NO;
    }
    
    
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableArray *actionDescriptions = [NSMutableArray array];
    
    void (^addAction)(void (^)(void)) = ^(void (^action)(void)){
        action = [[action copy] autorelease];
        [actions addObject:action];
    };
    
    __block BOOL success = YES;
    [[url query] parseQueryString:^(NSString *decodedName, NSString *decodedValue, BOOL *stop) {
        // Add a special case to let customers reset to the default state after we've had them turn on stuff temporarily.
        if ([decodedName isEqual:@"all"] && (OFISNULL(decodedValue) || [NSString isEmptyString:decodedValue])) {
            [actionDescriptions addObject:NSLocalizedStringFromTableInBundle(@"Restore all internal configuration settings to defaults", @"OmniFoundation", OMNI_BUNDLE, @"alert title when clicking on a configuration value URL")];
            addAction(^{
                [OFConfigurationValue restoreAllConfigurationValuesToDefaults];
            });
            return;
        }
        
        OFConfigurationValue *configurationValue = ConfigurationValueRegistrations[decodedName];
        if (configurationValue == nil) {
            OFError(outError, OFChangeDebugLevelURLError, @"Cannot change the configuration value.", @"No such configuration value defined.");
            success = NO;
            *stop = YES;
            return;
        }
        
        if (OFISNULL(decodedValue) || [NSString isEmptyString:decodedValue]) {
            [actionDescriptions addObject:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Restore \"%@\" to its default value", @"OmniFoundation", OMNI_BUNDLE, @"alert message format when clicking on a configuration value URL"), decodedName]];
            addAction(^{
                [configurationValue restoreDefaultValue];
            });
            return;
        }
        
        [actionDescriptions addObject:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Set \"%@\" to \"%@\"", @"OmniFoundation", OMNI_BUNDLE, @"alert message format when clicking on a configuration value URL"), decodedName, decodedValue]];
        addAction(^{
            [configurationValue setValueFromString:decodedValue];
        });
    }];
    
    if (!success)
        return NO;
    
    void (^performActions)(void) = ^{
        for (void (^action)(void) in actions) {
            action();
        }
    };
    
    if (confirm) {
        NSString *title = NSLocalizedStringFromTableInBundle(@"Change configuration?", @"OmniFoundation", OMNI_BUNDLE, @"alert title when clicking on a configuration value URL");
        NSString *message = NSLocalizedStringFromTableInBundle(@"This configuration link will make the following changes:", @"OmniFoundation", OMNI_BUNDLE, @"alert message header when clicking on a configuration value URL");
        
        NSString *details = [[actionDescriptions arrayByPerformingBlock:^NSString *(NSString *desc) {
            return [NSString stringWithFormat:@"• %@", desc];
        }] componentsJoinedByString:@"\n"];
        message = [message stringByAppendingFormat:@"\n\n%@", details];
        
        confirm(title, message, ^(BOOL confirmed, NSError *confirmError) {
            if (confirmed) {
                performActions();
            }
        });
    } else {
        performActions();
    }
    
    return YES;
}

void _OFRegisterIntegerConfigurationValue(NSInteger *outLevel, NSString *name, double defaultValue, double minimumValue, double maximumValue)
{
    OBPRECONDITION([NSThread isMainThread]);
    
    @autoreleasepool {
        OBASSERT(ConfigurationValueRegistrations[name] == nil);

        OFConfigurationValue *configurationValue = [[OFConfigurationValue alloc] initWithKey:name integral:YES defaultValue:defaultValue minimumValue:minimumValue maximumValue:maximumValue];

        [configurationValue addValueObserver:^(OFConfigurationValue *value){
            *outLevel = (NSInteger)value.currentValue;
        }];
        *outLevel = (NSInteger)configurationValue.currentValue; // Initial value

        ConfigurationValueRegistrations[name] = configurationValue;
        [configurationValue release];
    }
}
void _OFRegisterTimeIntervalConfigurationValue(NSTimeInterval *outInterval, NSString *name, double defaultValue, double minimumValue, double maximumValue)
{
    OBPRECONDITION([NSThread isMainThread]);
    
    @autoreleasepool {
        OBASSERT(ConfigurationValueRegistrations[name] == nil);

        OFConfigurationValue *configurationValue = [[OFConfigurationValue alloc] initWithKey:name integral:NO defaultValue:defaultValue minimumValue:minimumValue maximumValue:maximumValue];
        [configurationValue addValueObserver:^(OFConfigurationValue *value){
            *outInterval = value.currentValue;
        }];
        *outInterval = configurationValue.currentValue; // Initial value

        ConfigurationValueRegistrations[name] = configurationValue;
        [configurationValue release];
    }
}

NS_ASSUME_NONNULL_END
