//
//  BackupDelegate.h
//  Ascent
//
//  Created by Rob Boyer on 12/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TrackBrowserDocument;

enum ConnectionState 
{
    kConnectionStateFinished,
    kConnectionStateQuiescent,
	kConnectionStateUpMakeCollection,
    kConnectionStateUpPutBackup,
    kConnectionStateUpDeleteBackup
};

typedef enum ConnectionState ConnectionState;

@interface BackupDelegate : NSObject 
{
	TrackBrowserDocument*	tbDocument;
	ConnectionState			connectionState;
	NSURLConnection*		connection;
	NSString*				backupFileBaseName;
	NSString*				sourceBackupFilePath;
	NSString*				compressedBackupFilePath;
	NSString*				mobileMeAccountName;
	NSInputStream*			uploadInputStream;
	NSTimer*				uploadTimer;
	BOOL					uploadInProgress;
	BOOL					cancelled;
}

-(id)initWithDocument:(TrackBrowserDocument*)tbdoc;
-(BOOL)doBackupsIfRequired:(NSURL *)absoluteURL;
-(BOOL)isFinished;

@end
