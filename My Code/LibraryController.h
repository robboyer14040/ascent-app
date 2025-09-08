//
//  LibraryController.h
//  Ascent
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DatabaseManager;
@class ActivityStore;
@class TrackPointStore;
@class IdentifierStore;

@interface AscentLibrary : NSObject {
@private
    NSURL *_fileURL;
    NSData *_bookmarkData;
    NSString *_displayName;
    DatabaseManager *_db;
    ActivityStore *_activities;
    TrackPointStore *_points;
    IdentifierStore *_identifiers;
    NSInteger _trackCount;
    int64_t _totalPoints;
    uint64_t _fileSizeBytes;
    BOOL _hasSecurityScope;
}
@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSData *bookmarkData;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) DatabaseManager *db;
@property (nonatomic, readonly) ActivityStore *activities;
@property (nonatomic, readonly) TrackPointStore *points;
@property (nonatomic, readonly) IdentifierStore *identifiers;
@property (atomic, readonly) NSInteger trackCount;
@property (atomic, readonly) int64_t totalPoints;
@property (atomic, readonly) uint64_t fileSizeBytes;
@property (atomic, readonly) BOOL hasSecurityScope;

// Internal setters
- (void)setFileURL:(NSURL *)url;
- (void)setBookmarkData:(NSData *)data;
- (void)setDisplayName:(NSString *)name;
- (void)setDb:(DatabaseManager *)db;
- (void)setActivities:(ActivityStore *)s;
- (void)setPoints:(TrackPointStore *)s;
- (void)setIdentifiers:(IdentifierStore *)s;
- (void)setTrackCount:(NSInteger)c;
- (void)setTotalPoints:(int64_t)p;
- (void)setFileSizeBytes:(uint64_t)b;
- (void)setHasSecurityScope:(BOOL)flag;
@end

extern NSNotificationName const AscentLibraryControllerActiveLibraryDidChangeNotification;
extern NSNotificationName const AscentLibraryControllerLibrariesDidChangeNotification;

extern NSErrorDomain const AscentLibraryControllerErrorDomain;
typedef NS_ERROR_ENUM(AscentLibraryControllerErrorDomain, AscentLibraryControllerError) {
    AscentLibraryControllerErrorOpenFailed = 1,
    AscentLibraryControllerErrorBookmarkInvalid = 2,
    AscentLibraryControllerErrorDuplicate = 3,
    AscentLibraryControllerErrorCloseFailed = 4,
};

@protocol LibraryControllerDelegate <NSObject>
@optional
- (void)libraryWillOpenAtURL:(NSURL *)url;
- (void)libraryDidOpen:(AscentLibrary *)library;
- (void)libraryWillClose:(AscentLibrary *)library;
- (void)libraryDidCloseURL:(NSURL *)url;
@end

@interface LibraryController : NSObject {
@private
    NSMutableArray<AscentLibrary *> *_mutableLibraries;
    NSURL *_stateDirURL;
    dispatch_queue_t _controllerQueue;
    AscentLibrary *_activeLibrary;
    id<LibraryControllerDelegate> _delegate;
}
@property (nonatomic, assign) id<LibraryControllerDelegate> delegate;
@property (nonatomic, readonly) NSArray<AscentLibrary *> *openLibraries;
@property (atomic, readonly) AscentLibrary *activeLibrary;
@property (nonatomic, readonly) dispatch_queue_t controllerQueue;

- (instancetype)initWithStateDirectoryURL:(NSURL *)stateDirURL;

- (void)createLibraryAtURL:(NSURL *)url
                completion:(void (^_Nullable)(AscentLibrary *_Nullable library, NSError *_Nullable error))completion;

- (void)openLibraryAtURL:(NSURL *)url
              completion:(void (^_Nullable)(AscentLibrary *_Nullable library, NSError *_Nullable error))completion;

- (void)closeLibrary:(AscentLibrary *)library
          completion:(void (^_Nullable)(NSError *_Nullable error))completion;

- (void)closeAllLibrariesWithCompletion:(void (^_Nullable)(NSError *_Nullable error))completion;

- (void)selectActiveLibrary:(AscentLibrary *)library;

- (NSArray<NSURL *> *)recentLibraryURLs;
- (void)recordRecentLibraryURL:(NSURL *)url bookmark:(NSData *_Nullable)bookmarkData;
- (void)pruneRecentLibraryURL:(NSURL *)url;

- (void)exportActiveLibrarySnapshotToURL:(NSURL *)destURL
                              completion:(void (^_Nullable)(NSError *_Nullable error))completion;

- (void)refreshStatsForLibrary:(AscentLibrary *)library
                    completion:(void (^_Nullable)(NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
