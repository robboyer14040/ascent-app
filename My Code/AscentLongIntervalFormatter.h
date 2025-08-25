//
//  AscentLongIntervalFormatter.h
//  Ascent
//
//  Created by Rob Boyer on 12/22/09.
//  Copyright 2009 Montebello Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#if 0

NS_ASSUME_NONNULL_BEGIN

@interface AscentLongIntervalFormatter : NSNumberFormatter 
{
	NSMutableDictionary*       attrs;
}
- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj
             forString:(NSString *)string
                range:(inout NSRange * _Nullable)rangep
                 error:(out NSError * _Nullable * _Nullable)error;
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes;


#endif

NS_ASSUME_NONNULL_BEGIN

@interface AscentLongIntervalFormatter : NSNumberFormatter
{
    NSMutableDictionary*       attrs;

}

- (nullable NSString *)stringForObjectValue:(nullable id)obj;

- (BOOL)getObjectValue:(id _Nullable __autoreleasing * _Nullable)obj
            forString:(NSString *)string
               range:(NSRange * _Nullable)rangep
               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

// Matches NSFormatter’s modern signature; `obj` is nonnull by default in this block
- (nullable NSAttributedString *)attributedStringForObjectValue:(id)obj
                                         withDefaultAttributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs;


@end


NS_ASSUME_NONNULL_END
