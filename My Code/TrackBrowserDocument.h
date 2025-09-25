//
//  TrackBrowserDocument.h
//  TLP
//
//  Created by Rob Boyer on 7/10/06.
//  Copyright rcb Construction 2006 . All rights reserved.
//


#import <Cocoa/Cocoa.h>

@class ADWindowController;
@class MainWindowController;
@class Lap;
@class Track;
@class TrackPoint;
@class TrackBrowserData;
@class BackupDelegate;
@class EquipmentLog;
@class EquipmentListWindowController;
@class ProgressBarController;
@class DatabaseManager;
@class ActivityStore;
@class TrackPointStore;
@class IdentifierStore;

extern int kSearchTitles;
extern int kSearchNotes;
extern int kSearchKeywords;
extern int kSearchActivityType;
extern int kSearchEquipment;
extern int kSearchEventType;

NSString * const AscentUTIDatabaseOLD   = @"com.montebellosoftware.ascent.tlp";
NSString * const AscentUTIDatabase      = @"com.montebellosoftware.ascent.db";

@interface TrackBrowserDocument : NSDocument
{
	Track*							currentlySelectedTrack;
	Lap*							selectedLap;
	ADWindowController*				adWindowController;
	MainWindowController*				tbWindowController;
	BackupDelegate*					backupDelegate;
    NSURL*                          databaseFileURL;
}
@property (nonatomic, retain) TrackBrowserData  *docMetaData;
@property (nonatomic) BOOL equipmentTotalsNeedUpdate;
@property(nonatomic, retain) EquipmentLog* equipmentLog;
@property(nonatomic, retain) NSMutableDictionary* equipmentLogDataDict;
@property (nonatomic, retain) DatabaseManager   *documentDBM;       // canonical writable DBM for this doc's file
@property (nonatomic, retain) ActivityStore     *activityStore;      // built on documentDBM
@property (nonatomic, retain) TrackPointStore   *trackPointStore;    // built on documentDBM
@property (nonatomic, retain) IdentifierStore   *identifierStore;    // built on documentDBM

- (void)syncGPS;
- (NSDate*)lastSyncTime;
- (void)setLastSyncTime:(NSDate*) d;
- (void)setTracks:(NSMutableArray*)tracks;
- (Track*) currentlySelectedTrack;
- (void)setCurrentlySelectedTrack:(Track*)t;
- (void)selectionChanged;
- (NSMutableArray*)trackArray;
- (MainWindowController*) windowController;
-(void) addTracks:(NSArray*)arr;
-(NSArray*) addTracksAfterStravaSync:(NSArray*)arr;
-(void) deleteTracks:(NSArray*)arr;
-(Track*)combineTracks:(NSArray*)tracks;
-(Track*) splitTrack:(Track*)track usingThreshold:(NSTimeInterval)threshold;
-(Track*)splitTrack:(Track*)trk atActiveTimeDelta:(NSTimeInterval)activeTimeDelta;
-(void) replaceTrack:(Track*)oldTrack with:(Track*)newTrack;
- (void) replaceTrackPoint:(Track*)track point:(TrackPoint*)pt newPoint:(TrackPoint*)np key:(id)ident updateTrack:(BOOL)upd;
-(void) removePointsAtIndices:(Track*)track selected:(NSIndexSet*)is;
- (void) changeTrackPoints:(Track*)track newPointArray:(NSMutableArray*)pts updateTrack:(BOOL)upd;
-(Track*) importTCXFile:(NSString*)fileName;
-(void) exportTCXFile:(NSArray*)tracks fileName:(NSString*)fileName;
-(Track*) importGPXFile:(NSString*)fileName;
-(void) exportGPXFile:(Track*)track fileName:(NSString*)fileName;
-(void) exportKMLFile:(Track*)track fileName:(NSString*)fileName;
-(void) exportLatLonTextFile:(Track*)track fileName:(NSString*)fileName;
-(Track*) importHRMFile:(NSString*)fileName;
-(Track*) importFITFile:(NSString*)fileName;
-(NSMutableDictionary*) colInfoDict;
-(void) setColInfoDict:(NSMutableDictionary*)dict;
-(NSMutableDictionary*) splitsColInfoDict;
-(void) setSplitsColInfoDict:(NSMutableDictionary*)dict;
-(Lap*) selectedLap;
-(void) setSelectedLap:(Lap*)l;
-(BOOL) insertLapMarker:(NSTimeInterval)atActiveTimeDelta inTrack:(Track*)track;
-(BOOL) addLap:(Lap*)lap toTrack:(Track*)track;
-(BOOL) deleteLap:(Lap*)lap fromTrack:(Track*)track;
-(int)numberOfSavesSinceLocalBackup;
-(int)numberOfSavesSinceMobileMeBackup;
-(void)setNumberOfSavesSinceLocalBackup:(int)n;
-(void)setNumberOfSavesSinceMobileMeBackup:(int)n;
-(BOOL)usesEquipmentLog;
-(void)setUsesEquipmentLog:(BOOL)uses;
-(float)getEquipmentDataAtIndex:(int)idx forEquipmentNamed:(NSString*)eq;
-(float)getCumulativeEquipmentDataStartingAtIndex:(int)idx forEquipmentNamed:(NSString*)eq;
-(void)setInitialEquipmentLogData:(NSMutableDictionary*)eld;
-(NSMutableDictionary*)initialEquipmentLogData;
-(void)setDocumentDateRange:(NSArray*)datesArray;	// array of earliest and latest dates for doc
-(NSArray*)documentDateRange;
-(NSString*)uuid;
-(void)setDatabaseFileURL:(NSURL*) url;
-(NSURL*)databaseFileURL;
@end
