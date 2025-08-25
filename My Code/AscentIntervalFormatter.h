//
//  AscentIntervalFormatter.h
//  Ascent
//
//  Created by Rob Boyer on 2/28/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if 0
@interface AscentIntervalFormatter : NSNumberFormatter
{
   NSMutableDictionary*       attrs;
   BOOL usePaceFormat;
}

- (id) initAsPace:(BOOL)usePace;
- (nullable NSString *)stringForObjectValue:(nullable id)obj;
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj
             forString:(NSString * _Nullable)string
                range:(inout NSRange * _Nullable)rangep
                 error:(out NSError * _Nullable * _Nullable)error;
- (nullable NSAttributedString *)attributedStringForObjectValue:(id)obj
                                          withDefaultAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;

@end

#else

NS_ASSUME_NONNULL_BEGIN

@interface AscentIntervalFormatter : NSNumberFormatter {
    NSMutableDictionary * _Nullable attrs;
    BOOL usePaceFormat;
}

- (instancetype)initAsPace:(BOOL)usePace;

- (nullable NSString *)stringForObjectValue:(nullable id)obj;

- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string range:(inout nullable NSRange *)rangep error:(out NSError **)error;

// Matches NSFormatter’s modern signature; `obj` is nonnull by default in this block
- (nullable NSAttributedString *)attributedStringForObjectValue:(id)obj
                                         withDefaultAttributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs;

@end

NS_ASSUME_NONNULL_END

#endif
