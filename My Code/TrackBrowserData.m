//
//  TrackBrowserData.m
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import "Defs.h"
#import "StringAdditions.h"
#import "TrackBrowserData.h"
#import "Track.h"
#import "BrowserInfo.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define CUR_VERSION 8

@implementation TrackBrowserData


- (id)init
{
    self = [super init];
    if (self)
    {
        _flags = 0;
        self.uuid = [NSString uniqueString];

        self.trackArray = [[[NSMutableArray alloc] init] autorelease];
        self.userDeletedTrackTimes = [[[NSMutableArray alloc] init] autorelease];

        self.lastSyncTime = [NSDate distantPast];
        self.numberOfSavesSinceLocalBackup = 0;

        self.initialEquipmentLogData = [NSMutableDictionary dictionaryWithCapacity:4];
        SET_FLAG(_flags, kHasInitialEquipmentLogData);

        self.startEndDateArray = [NSArray arrayWithObjects:[NSDate distantPast], [NSDate distantFuture], nil];
    }
    return self;
}


- (void)dealloc
{
    [_uuid release];
    [_trackArray release];
    [_tableInfoDict release];
    [_splitsTableInfoDict release];
    [_lastSyncTime release];
    [_userDeletedTrackTimes release];
    [_initialEquipmentLogData release];
    [_startEndDateArray release];
    [super dealloc];
}


#pragma mark - Property overrides to preserve side-effects

- (void)setTableInfoDict:(NSMutableDictionary *)value
{
    if (_tableInfoDict != value)
    {
        [_tableInfoDict release];
        _tableInfoDict = [value retain];
    }
    [[BrowserInfo sharedInstance] setColInfoDict:_tableInfoDict];
}


- (void)setSplitsTableInfoDict:(NSMutableDictionary *)value
{
    if (_splitsTableInfoDict != value)
    {
        [_splitsTableInfoDict release];
        _splitsTableInfoDict = [value retain];
    }
    [[BrowserInfo sharedInstance] setSplitsColInfoDict:_splitsTableInfoDict];
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    // Call designated initializer to get defaults, then overwrite with decoded values.
    self = [self init];
    if (!self)
    {
        return nil;
    }

    if ([coder allowsKeyedCoding])
    {
        self.trackArray = [coder decodeObjectForKey:@"tracks"];
        self.lastSyncTime = [coder decodeObjectForKey:@"lastSyncTime"];
        return self;
    }

    // Legacy (non-keyed) decoding path with versioning
    @try
    {
        int version = 0;
        [coder decodeValueOfObjCType:@encode(int) at:&version];

        if (version > CUR_VERSION)
        {
            NSException *e = [NSException exceptionWithName:ExFutureVersionName
                                                     reason:ExFutureVersionReason
                                                   userInfo:nil];
            @throw e;
        }

        if (version >= 1)
        {
            self.trackArray = [coder decodeObject];

            // Remove any tracks without creation times
            NSUInteger num = [self.trackArray count];
            if (num > 0)
            {
                NSMutableIndexSet *is = [NSMutableIndexSet indexSet];
                for (NSUInteger i = 0; i < num; i++)
                {
                    Track *t = [self.trackArray objectAtIndex:i];
                    if ([t creationTime] == nil)
                    {
                        [is addIndex:i];
                        NSLog(@"Removed track (%lu of %lu) with nil creation date!", (unsigned long)i, (unsigned long)num);
                    }
                }
                [self.trackArray removeObjectsAtIndexes:is];
            }

            self.lastSyncTime = [coder decodeObject];

            NSString *s = [coder decodeObject]; // added in v5, did not change version#
            if (!s || [s isEqualToString:@""])
            {
                s = [NSString uniqueString];
            }
            self.uuid = s;

            if (version > 7)
            {
                self.startEndDateArray = [coder decodeObject]; // changed from spare in v8
            }
            else
            {
                self.startEndDateArray = [NSArray arrayWithObjects:[NSDate distantPast], [NSDate distantFuture], nil];
                __unused NSString *spareString = [coder decodeObject]; // spare
            }

            // skip spares
            __unused NSString *spareString1 = [coder decodeObject];
            __unused NSString *spareString2 = [coder decodeObject];
            float fval = 0.0f;
            [coder decodeValueOfObjCType:@encode(float) at:&fval];
            [coder decodeValueOfObjCType:@encode(float) at:&fval];
            [coder decodeValueOfObjCType:@encode(float) at:&fval];
            [coder decodeValueOfObjCType:@encode(float) at:&fval];

            [coder decodeValueOfObjCType:@encode(int) at:&_numberOfSavesSinceLocalBackup]; // was spare
            int ival = 0;
            [coder decodeValueOfObjCType:@encode(int) at:&ival]; // was mobileme saves
            [coder decodeValueOfObjCType:@encode(int) at:&_flags]; // changed in v6 (was spare)
            [coder decodeValueOfObjCType:@encode(int) at:&ival]; // spare
        }

        if (version > 1)
        {
            self.tableInfoDict = [coder decodeObject];
        }

        if (version > 2)
        {
            self.splitsTableInfoDict = [coder decodeObject];
        }

        if (version > 3)
        {
            self.userDeletedTrackTimes = [coder decodeObject];
        }
        if (!self.userDeletedTrackTimes)
        {
            self.userDeletedTrackTimes = [NSMutableArray array];
        }

        BOOL hasInitialEquipmentLogData = NO;
        if (version >= 6)
        {
            hasInitialEquipmentLogData = FLAG_IS_SET(_flags, kHasInitialEquipmentLogData);
        }

        if (hasInitialEquipmentLogData)
        {
            self.initialEquipmentLogData = [coder decodeObject];
        }
        else
        {
            self.initialEquipmentLogData = [NSMutableDictionary dictionaryWithCapacity:4];
        }
        SET_FLAG(_flags, kHasInitialEquipmentLogData);
    }
    @catch (NSException *exception)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Document Read Error"];
        [alert setInformativeText:[exception reason]];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert runModal];
        @throw;
    }

    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:self.trackArray forKey:@"tracks"];
        [coder encodeObject:self.lastSyncTime forKey:@"lastSyncTime"];
        return;
    }

    // Legacy (non-keyed) encoding path with versioning
    int version = CUR_VERSION;
    float spareFloat = 0.0f;
    int spareInt = 0;

    [coder encodeValueOfObjCType:@encode(int) at:&version];
    [coder encodeObject:self.trackArray];
    [coder encodeObject:self.lastSyncTime];

    NSString *spareString = @"";
    [coder encodeObject:self.uuid];
    [coder encodeObject:self.startEndDateArray ?: @[]];
    [coder encodeObject:spareString];
    [coder encodeObject:spareString];
    [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(float) at:&spareFloat];
    [coder encodeValueOfObjCType:@encode(int) at:&_numberOfSavesSinceLocalBackup];
    [coder encodeValueOfObjCType:@encode(int) at:&spareInt];
    [coder encodeValueOfObjCType:@encode(int) at:&_flags]; // changed in v6 (was spareInt)
    [coder encodeValueOfObjCType:@encode(int) at:&spareInt];

    // v2
    [coder encodeObject:self.tableInfoDict];
    // v3
    [coder encodeObject:self.splitsTableInfoDict];
    // v4
    [coder encodeObject:self.userDeletedTrackTimes];

    // added in version 7 (flag indicates presence)
    SET_FLAG(_flags, kHasInitialEquipmentLogData);
    [coder encodeObject:self.initialEquipmentLogData];
}

@end
