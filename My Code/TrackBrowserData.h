//
//  TrackBrowserData.h
//  Ascent
//
//  Created by Rob Boyer on 9/15/25.
//  © 2025 Montebello Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// values for the TrackBrowserData 'flags' field
enum
{
    kUsesEquipmentLog                = 0x00000001,
    kHasInitialEquipmentLogData      = 0x00000002,
};

@interface TrackBrowserData : NSObject <NSCoding>
{
@private
    // Keep legacy ivar names for drop-in compatibility (MRC)
    NSMutableArray        *trackArray;
    NSMutableDictionary   *tableInfoDict;          // main browser column info
    NSMutableDictionary   *splitsTableInfoDict;    // splits table column info
    NSDate                *lastSyncTime;
    NSMutableArray        *userDeletedTrackTimes;
    NSMutableDictionary   *initialEquipmentLogData;
    NSString              *uuid;
    NSArray               *startEndDateArray;
    int                    numberOfSavesSinceLocalBackup;
    int                    flags;
}

// Modern properties (retain/assign under MRC)
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSMutableArray *trackArray;
@property (nonatomic, retain) NSMutableDictionary *tableInfoDict;
@property (nonatomic, retain) NSMutableDictionary *splitsTableInfoDict;
@property (nonatomic, retain) NSDate *lastSyncTime;
@property (nonatomic, retain) NSMutableArray *userDeletedTrackTimes;
@property (nonatomic, retain) NSMutableDictionary *initialEquipmentLogData;
@property (nonatomic, retain) NSArray *startEndDateArray;

@property (nonatomic, assign) int numberOfSavesSinceLocalBackup;
@property (nonatomic, assign) int flags;

@end
