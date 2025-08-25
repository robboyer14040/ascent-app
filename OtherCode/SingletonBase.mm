//
//  SingletonBase.mm
//  Ascent
//
//  Created by Rob Boyer on 8/5/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "SingletonBase.h"
#import <objc/objc-runtime.h>


@implementation SingletonBase

static NSMutableDictionary  *sharedInstances = nil;
static NSRecursiveLock        *sharedInstancesLock = nil;
static Method                abstractInit = NULL;
static Method                disabledInit = NULL;



+ (void)initialize
{
#if 0
    @synchronized(self)
    {
        if (!sharedInstances) {
            sharedInstances = [[NSMutableDictionary alloc] init];
            sharedInstancesLock = [[NSRecursiveLock alloc] init];
            abstractInit = class_getInstanceMethod(self, @selector(init));
            disabledInit = class_getInstanceMethod(self,
                                                   @selector(singletonInitDisabled));
        }
    }
#else
    if (self == [SingletonBase class]) {
        sharedInstances = [[NSMutableDictionary alloc] init];
        sharedInstancesLock = [[NSRecursiveLock alloc] init];
    }
#endif
    
}

+ (id)sharedInstance
{
#if 1
    Class cls = [self class];
    id singleton = nil;
   
    @try {
        [sharedInstancesLock lock];
        NSString *key = NSStringFromClass(cls);        ///
        singleton = [sharedInstances objectForKey:key];
        if (!singleton) {
            singleton = class_createInstance(cls, 0U);
            if (singleton) {
                Method singletonInit = class_getInstanceMethod(cls,  
                                                               @selector(init));
                ///[sharedInstances setObject:singleton forKey:cls];
                [sharedInstances setObject:singleton forKey:key];
                if (singletonInit) {
                    [singleton init];
//                  if (singletonInit->method_imp != abstractInit->method_imp) {
//                      singletonInit->method_imp = disabledInit->method_imp;
                        if (method_getImplementation(singletonInit) != method_getImplementation(abstractInit) ) {
                            method_setImplementation(singletonInit, method_getImplementation(disabledInit));
                        }
                }
            }            
        }
   }
   @catch (NSException *exception) {
      NSLog(@"%@ raised %@: %@", cls, [exception name], [exception  
         reason]);
   }
   @finally {
      [sharedInstancesLock unlock];
   }
#else
    Class cls = [self class];
    NSString *key = NSStringFromClass(cls);
    id singleton = nil;

    [sharedInstancesLock lock];
    singleton = [sharedInstances objectForKey:key];
    if (!singleton) {
        // Use your preferred creation path; this respects subclass init
        singleton = [[cls alloc] init];
        if (singleton) {
            [sharedInstances setObject:singleton forKey:key];
        }
    }
    [sharedInstancesLock unlock];

#endif
   return singleton;
}

- (id)singletonInitDisabled
{
   [NSException raise:NSInternalInconsistencyException
               format:@"can't re-init %@ sharedInstance", [self class]];
   
   return self;
}

+ (id)new
{
   return [self sharedInstance];
}

+ (id)allocWithZone:(NSZone *)zone
{
   return [self sharedInstance];
}

+ (id)alloc
{
   return [self sharedInstance];
}

- (id)init
{
   return [super init];
}

- (id)copy
{
   [self doesNotRecognizeSelector:_cmd];
   return self;
}

- (id)copyWithZone:(NSZone *)zone
{
   [self doesNotRecognizeSelector:_cmd];
   return self;
}

- (id)mutableCopy
{
   [self doesNotRecognizeSelector:_cmd];
   return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
   [self doesNotRecognizeSelector:_cmd];
   return self;
}


@end
