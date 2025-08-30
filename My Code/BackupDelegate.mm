//
//  BackupDelegate.mm
//  Ascent
//
//  Created by Rob Boyer on 12/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "BackupDelegate.h"
#import "TrackBrowserDocument.h"
#import "Utils.h"
#import "ProgressBarController.h"
#import <Security/Security.h>
#import <unistd.h>			// for sleep


#define ENABLE_LOGGING			_DEBUG&&1

static NSString* kAscentMobileMeBackupDirectory	= @"AscentBackups";
static NSString* kURLBackupColTemplate			= @"https://idisk.me.com/%@/%@";
static NSString* kURLBackupFileTemplate			= @"https://idisk.me.com/%@/%@/%@";


static OSStatus CopyMobileMeAccountAndPassword(CFStringRef *accountPtr, CFStringRef *passwordPtr)
{
    OSStatus                    err;
    OSStatus                    junk;
    SecKeychainAttribute        searchAttr;
    SecKeychainAttributeList    searchAttrs;
    SecKeychainSearchRef        search;
    SecKeychainItemRef          item;
	
    //assert(accountPtr != NULL);
    //assert(*accountPtr == NULL);
    //assert( (passwordPtr == NULL) || (*passwordPtr == NULL) );
	
    search = NULL;
    item   = NULL;
	
    searchAttr.tag    = kSecServiceItemAttr;
    searchAttr.data   = (void*)"iTools";
    searchAttr.length = strlen( (const char *) searchAttr.data );
    
    searchAttrs.count = 1;
    searchAttrs.attr  = &searchAttr;
    
    err = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &searchAttrs, &search);
    if (err == noErr) {
        err = SecKeychainSearchCopyNext(search, &item);
    }
    if (err == noErr) {
        UInt32                      attrTags[1];
        UInt32                      attrFormats[1];
        SecKeychainAttributeInfo    attrsToGet;
        SecKeychainAttributeList *  attrsGot;
        UInt32                      passwordDataLen;
        UInt32 *                    passwordDataLenPtr;
        void *                      passwordData;
        void **                     passwordDataPtr;
        
        // Only get the password if the caller has asked for it.  The keychain 
        // API doesn't make this particularly easy (-:
        
        passwordDataLen = 0;
        passwordData = NULL;
        if (passwordPtr == NULL) {
            passwordDataLenPtr = NULL;
            passwordDataPtr    = NULL;
        } else {
            passwordDataLenPtr = &passwordDataLen;
            passwordDataPtr    = &passwordData;
        }
        
        // Set up the attributes to fetch, which in this case is just the acount 
        // name.
        
        attrTags[0]    = kSecAccountItemAttr;
        attrFormats[0] = CSSM_DB_ATTRIBUTE_FORMAT_STRING;
        
        assert(sizeof(attrTags) == sizeof(attrFormats));
		
        attrsToGet.count  = sizeof(attrTags) / sizeof(attrTags[0]);
        attrsToGet.tag    = attrTags;
        attrsToGet.format = attrFormats;
        err = SecKeychainItemCopyAttributesAndData(item, &attrsToGet, NULL, &attrsGot, passwordDataLenPtr, passwordDataPtr);
        if (err == noErr) {
            assert(attrsGot->count == attrsToGet.count);
            
            *accountPtr = CFStringCreateWithBytes(NULL, (const UInt8*)attrsGot->attr[0].data, attrsGot->attr[0].length, kCFStringEncodingUTF8, true);
            if (*accountPtr == NULL) {
                err = coreFoundationUnknownErr;
            } else if (passwordPtr != NULL) {
                assert(passwordDataPtr != NULL);
                *passwordPtr = CFStringCreateWithBytes(NULL, (const UInt8*)passwordData, passwordDataLen, kCFStringEncodingUTF8, true);
                if (*passwordPtr == NULL) {
                    CFRelease(*accountPtr);
                    err = coreFoundationUnknownErr;
                }
            }
            
            junk = SecKeychainItemFreeAttributesAndData(attrsGot, passwordData);
            assert(junk == noErr);
        }
    }
	
    if (item != NULL) {
        CFRelease(item);
    }
    if (search != NULL) {
        CFRelease(search);
    }
        
    return err;
}




#import "zlib.h"

#define CHUNK 256*1024

/* Compress from file source to file dest until EOF on source.
 def() returns Z_OK on success, Z_MEM_ERROR if memory could not be
 allocated for processing, Z_STREAM_ERROR if an invalid compression
 level is supplied, Z_VERSION_ERROR if the version of zlib.h and the
 version of the library linked do not match, or Z_ERRNO if there is
 an error reading or writing the files. */
static int compress(NSString* sourcePath, NSString* destPath)
{
	int level = Z_DEFAULT_COMPRESSION;
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char out[CHUNK];
	
	NSFileHandle* readHandle = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager createFileAtPath:destPath 
							 contents:[NSData data] 
						   attributes:nil])
	{
		NSFileHandle* writeHandle = [NSFileHandle fileHandleForWritingAtPath:destPath];
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:sourcePath 
																	 error:NULL];
		int fileSize = 0;
		NSNumber *fileSizeNum;
		if (fileAttributes != nil) 
		{
			fileSizeNum = [fileAttributes objectForKey:NSFileSize];
			fileSize = [fileSizeNum intValue];
		}
		
		/* allocate deflate state */
		strm.zalloc = Z_NULL;
		strm.zfree = Z_NULL;
		strm.opaque = Z_NULL;
		ret = deflateInit(&strm, level);
		if (ret != Z_OK)
			return ret;
		
		int numBytesLeft = fileSize;
		/* compress until end of file */
		do 
		{
			//strm.avail_in = fread(in, 1, CHUNK, source);
			NSData* uncompressedData = [readHandle readDataOfLength:CHUNK];
			int lengthRead = [uncompressedData length];
			strm.avail_in = lengthRead;
#if 0
			//if (ferror(source)) 
			{
				(void)deflateEnd(&strm);
				return Z_ERRNO;
			}
#endif
			numBytesLeft -= lengthRead;
			flush = (numBytesLeft <= 0) ? Z_FINISH : Z_NO_FLUSH;
			strm.next_in = (Bytef*)[uncompressedData bytes];
			
			/* run deflate() on input until output buffer not full, finish
			 compression if all of source has been read in */
			do 
			{
				strm.avail_out = CHUNK;
				strm.next_out = out;
				
				ret = deflate(&strm, flush);    /* no bad return value */
				assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
				
				have = CHUNK - strm.avail_out;
				//if (fwrite(out, 1, have, dest) != have || ferror(dest)) 
				NSData* outData = [NSData dataWithBytes:out 
												 length:have];
				[writeHandle writeData:outData];
#if 0			
				{
					(void)deflateEnd(&strm);
					return Z_ERRNO;
				}
#endif
			} while (strm.avail_out == 0);
			assert(strm.avail_in == 0);     /* all input will be used */
			/* done when last data in file processed */
		} while (flush != Z_FINISH);
		assert(ret == Z_STREAM_END);        /* stream will be complete */
		
		/* clean up and return */
		(void)deflateEnd(&strm);
		[writeHandle synchronizeFile];
	}
    return Z_OK;
}



@interface BackupDelegate (Private)
-(void)setConnection:(NSURLConnection*)conn;
-(NSURLConnection*)connection;
-(void)setSourceBackupFilePath:(NSString*)path;
-(NSString*)sourceBackupFilePath;
-(NSString*)backupFileBaseName;
-(void)setBackupFileBaseName:(NSString*)name;
- (NSString *)compressedBackupFilePath;
- (void)setCompressedBackupFilePath:(NSString *)value;
- (NSString *)mobileMeAccountName;
- (void)setMobileMeAccountName:(NSString *)value;
- (NSInputStream *)uploadInputStream;
- (void)setUploadInputStream:(NSInputStream *)value;
-(void) killUploadTimer;
-(BOOL)checkAccountName;
-(void)startNetworkBackup;
-(void)finishNetworkBackup;
- (BOOL)makeArchive:(NSString*)srcPath destPath:(NSString*)dstPath;
@end


@implementation BackupDelegate  : NSObject

-(id)initWithDocument:(TrackBrowserDocument*)tbdoc
{
	if (self = [super init])
	{
		// can't retain, because tbDocument retains us and get into circular deletion tbDocument = [tbdoc retain];
		tbDocument = tbdoc;
		connection = nil;
		backupFileBaseName = nil;
		sourceBackupFilePath = nil;
		compressedBackupFilePath = nil;
		uploadInputStream = nil;
		uploadInProgress = NO;
	}
	return self;
}


-(void)dealloc
{
    [super dealloc];
}



- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
 copyingItemAtURL:(NSURL *)srcURL
             toURL:(NSURL *)dstURL
{
    NSLog(@"Copy error %@ → %@: %@", srcURL, dstURL, error);
    // return YES to keep going, NO to abort the operation
    return NO;
}


// Move
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
  movingItemAtURL:(NSURL *)srcURL
            toURL:(NSURL *)dstURL
{
    NSLog(@"Move error %@ → %@: %@", srcURL, dstURL, error);
    return NO;
}

// Remove
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
 removingItemAtURL:(NSURL *)url
{
    NSLog(@"Remove error %@: %@", url, error);
    return NO;
}

// Link (if you use it)
- (BOOL)fileManager:(NSFileManager *)fm
shouldProceedAfterError:(NSError *)error
  linkingItemAtURL:(NSURL *)srcURL
             toURL:(NSURL *)dstURL
{
    NSLog(@"Link error %@ → %@: %@", srcURL, dstURL, error);
    return NO;
}


-(void)trimBackups:(NSString*)folder baseFileName:(NSString*)baseFileName retainCount:(int)retainCount
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* fileArray = [fm contentsOfDirectoryAtPath:folder
												 error:NULL];
    NSUInteger count = [fileArray count];
	NSMutableArray* marr = [NSMutableArray arrayWithCapacity:count];
	for (int i=0; i<count; i++)
	{
		NSString* filePath = [fileArray objectAtIndex:i];
		NSString* extension = [filePath pathExtension];
		NSRange baseNameRange = [filePath rangeOfString:baseFileName];
		NSRange searchRange;
		searchRange.location = baseNameRange.length;
		searchRange.length = [filePath length] - searchRange.location;
		NSRange delimRange = [filePath rangeOfString:@"__"
											 options:NSBackwardsSearch
											   range:searchRange];
		if (([extension isEqualToString:ASCENT_DOCUMENT_EXTENSION]) &&
			(baseNameRange.location == 0) &&
			(delimRange.location == baseNameRange.length))
		{
			filePath = [folder stringByAppendingPathComponent:filePath];
			[marr addObject:filePath];
		}
	}
	[marr sortUsingSelector:@selector(compareFileModDates:)];
	count = [marr count];
	if (count > retainCount)
	{
		int numToRemove = count-retainCount;
		for (int i=0; i<numToRemove; i++)
		{
			[fm removeItemAtPath:[marr objectAtIndex:i] 
						   error:NULL];
		}
	}
}


- (void)startConnection:(ConnectionState)startState
// Called by -uploadAction: and -downloadAction after starting the connection 
// to set up the UI for the connection.
{
    assert(startState != kConnectionStateQuiescent);
   // assert([self connection] == kConnectionStateQuiescent);
    connectionState = startState;
    
	
    // Setup various status indicators.
    
    //[self updateMinorStatus:@"Connecting"];
}

-(void) killUploadTimer
{
	[uploadTimer invalidate];
	uploadTimer = nil;
}


- (void)stopConnection:(NSString *)status
// Called by various routines to shut down the connection and restore the 
// UI to its default state.
{
     // Shut down the connection itself.
    
    [self.connection cancel];
	[self setConnection:nil];
	[self killUploadTimer];
	[self setUploadInputStream:nil];
	uploadInProgress = NO;
    connectionState = kConnectionStateQuiescent;
}


- (void)createDestinationCollection
// Start connection to MOVE the main file to the backup file.
{
    NSMutableURLRequest *   request;
	if ([self checkAccountName])
	{
		
		NSString* dir = [NSString stringWithFormat:kURLBackupColTemplate, [self mobileMeAccountName], kAscentMobileMeBackupDirectory];
#if ENABLE_LOGGING
		NSLog(@"attempting to create backup folder on idisk using URL:%@", dir);
#endif		
		request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:dir]];
		assert(request != nil);
		
		[request setHTTPMethod:@"MKCOL"];
		//[request setTimeoutInterval:10.0];
		
		assert(self.connection == nil);
		[self setConnection:[NSURLConnection connectionWithRequest:request delegate:self]];
		[self startConnection:kConnectionStateUpMakeCollection];
		assert(self.connection != nil);
	}
	else
	{
		[self finishNetworkBackup];
	}
}



-(BOOL)checkAccountName
{
	BOOL ret = YES;
	if ([self mobileMeAccountName] == nil)
	{
		CFStringRef account;
		CFStringRef password;
		OSStatus sts = CopyMobileMeAccountAndPassword(&account, &password);
		if (sts == noErr)
		{
			[self setMobileMeAccountName:(NSString*)account];
		}
		else
		{
			ret = NO;
			NSAlert *alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"MobileMe backup could not be completed"];
			[alert setInformativeText:@"MobileMe backup requires access to MobileMe account information in the keychain"];
			[alert setAlertStyle:NSWarningAlertStyle];
			[alert runModal];
			[self stopConnection:@"No Access Granted"];
		}
	}
	return ret;
}



-(void) uploadThread:(NSString*)srcPath
{
	NSMutableURLRequest *   request;
	NSString* path = [NSString stringWithFormat:kURLBackupFileTemplate, [self mobileMeAccountName], kAscentMobileMeBackupDirectory, [self backupFileBaseName]];
	path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
	assert(request != nil);
	
	[request setHTTPMethod:@"PUT"];
	//[request setHTTPMethod:@"POST"];
	[self setUploadInputStream:[NSInputStream inputStreamWithFileAtPath:srcPath]];
	[request setHTTPBodyStream:[self uploadInputStream]];
	[request setTimeoutInterval:10.0];
	
	assert(connection == nil);
	[self setConnection:[NSURLConnection connectionWithRequest:request delegate:self]];
	assert(connection != nil);
	
	[self startConnection:kConnectionStateUpPutBackup];
	
	// start a new thread to do the upload, and monitor its progress here,updating the progress bar as required
	uploadInProgress = YES;
	
	BOOL isRunning;
	double resolution = 0.5;
	@try 
	{
		do 
		{
			NSDate* next = [NSDate dateWithTimeIntervalSinceNow:resolution];
			isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
												 beforeDate:next];
		} while (isRunning && uploadInProgress && !cancelled);
		if (cancelled) [self stopConnection:@"Cancelled"];
	}
	@catch (NSException *exception) 
	{
		[self stopConnection:@"Exception Occurred"];
	}
}


-(void)cancelUpload
{
	cancelled = YES;
}


-(void)startNetworkBackup
{
	connectionState = kConnectionStateQuiescent;
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	ProgressBarController* pbc = [pb controller];
	[pbc begin:@"Uploading to MobileMe"  divisions:1];
	[pbc updateMessage:[NSString stringWithFormat:@"verifying credentials"]];
}


-(void)finishNetworkBackup
{
	connectionState = kConnectionStateFinished;
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	[[[pb controller] window] orderOut:[[tbDocument windowController] window]];
}


- (void)startUpload:(ConnectionState)startState
// Start a PUT connection to upload the main file.
{
	// NOTE: this is running on  the main thread.  The connection is being run in another thread, so
	// we just spin here waiting for it to finish, an error to occur, or the user to cancel.
	SharedProgressBar* pb = [SharedProgressBar sharedInstance];
	ProgressBarController* pbc = [pb controller];
	if ([self checkAccountName])
	{
		BOOL ok = YES;
		BOOL deleteSrcFile = NO;
		NSString* srcFile = [self compressedBackupFilePath];
		if (srcFile == nil)
		{
			[pbc updateMessage:@"compressing activity document"];
			srcFile = [[self sourceBackupFilePath] stringByAppendingString:@".tmpzip"];
			ok = [self makeArchive:[self sourceBackupFilePath]
						  destPath:srcFile];
			deleteSrcFile = YES;
		}
		if (ok)
		{
#if ENABLE_LOGGING
			NSLog(@"starting MobileMe fle upload with source file %@", srcFile);
#endif
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:srcFile 
																		 error:NULL];
			
			NSNumber *fileSize;
			if (fileAttributes != nil) 
			{
				if ((fileSize = [fileAttributes objectForKey:NSFileSize]))
				{
#if ENABLE_LOGGING
					NSLog(@"backup file size: %qi\n", [fileSize unsignedLongLongValue]);
#endif
				}
			}
			
			cancelled = NO;
			[NSThread detachNewThreadSelector:@selector(uploadThread:)
									 toTarget:self
								   withObject:srcFile];

			int totalSize = [fileSize intValue];
			[pbc begin:@"Uploading to MobileMe"  
			 divisions:totalSize];
			[pbc setCancelSelector:@selector(cancelUpload)
						 forObject:self];
			NSModalSession session = [NSApp beginModalSessionForWindow:[pbc window]];
			while (uploadInProgress)
			{
				if ([NSApp runModalSession:session] != NSModalResponseContinue)
				{
					break;
				}
				NSNumber* offset = [uploadInputStream propertyForKey:NSStreamFileCurrentOffsetKey];
				int loaded = [offset intValue];
				[pbc setDivs:loaded];
				[pbc updateMessage:[NSString stringWithFormat:@"uploaded %@ of %@", [Utils friendlySizeAsString:loaded], [Utils friendlySizeAsString:totalSize]]];
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.19]];
			}
			[NSApp endModalSession:session];
			if (deleteSrcFile)
			{
				[fileManager removeItemAtPath:srcFile 
										error:NULL];
			}
		}
		else
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"MobileMe backup could not be completed"];
			[alert setInformativeText:@"Error occurred while compressing activity document"];
			[alert setAlertStyle:NSWarningAlertStyle];
			[alert runModal];
			[self stopConnection:@"Compression failed"];
		}
	}
	[self finishNetworkBackup];
}

		


-(NSString*)sourceBackupFilePath
{
	return sourceBackupFilePath;
}


-(void)setSourceBackupFilePath:(NSString*)path
{
	if (sourceBackupFilePath != path)
	{
		sourceBackupFilePath = path;
	}
}

-(NSString*)backupFileBaseName
{
	return backupFileBaseName;
}

-(void)setBackupFileBaseName:(NSString*)name
{
	if (backupFileBaseName != name)
	{
		backupFileBaseName = name;
	}
}


- (NSString *)compressedBackupFilePath 
{
    return compressedBackupFilePath;
}


- (void)setCompressedBackupFilePath:(NSString *)value 
{
    if (compressedBackupFilePath != value) 
	{
        [compressedBackupFilePath release];
        compressedBackupFilePath = [value retain];
    }
}

	
- (NSString *)mobileMeAccountName 
{
	return [[mobileMeAccountName retain] autorelease];
}

- (void)setMobileMeAccountName:(NSString *)value 
{
	if (mobileMeAccountName != value) 
	{
		[mobileMeAccountName release];
		mobileMeAccountName = [value copy];
	}
}
	
- (NSInputStream *)uploadInputStream 
{
	return uploadInputStream;
}

- (void)setUploadInputStream:(NSInputStream *)value 
{
	if (uploadInputStream != value) {
		[uploadInputStream release];
		uploadInputStream = [value retain];
	}
}


	
-(BOOL)doMobileMeBackup:(NSString*)source toFileBaseName:(NSString*)toFileBaseName
{
	connectionState = kConnectionStateQuiescent;
	[self setSourceBackupFilePath:source];
	[self setBackupFileBaseName:toFileBaseName];
	[self createDestinationCollection];
	return YES;
}


-(BOOL)doBackupsIfRequired:(NSURL *)absoluteURL
{
	BOOL finished = YES;
	[self setCompressedBackupFilePath:nil];
	[self setBackupFileBaseName:nil];
	[self setSourceBackupFilePath:nil];
	BOOL doLocalBackup = [Utils boolFromDefaults:RCBDefaultDoLocalBackup];
	BOOL doMobileMeBackup = [Utils boolFromDefaults:RCBDefaultDoMobileMeBackup];
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* localBackupFolder = [Utils stringFromDefaults:RCBDefaultLocalBackupFolder];
	localBackupFolder = [localBackupFolder stringByExpandingTildeInPath];
	NSString* newlySavedFile = [absoluteURL path];
	NSString* backupFile = newlySavedFile;
	if ([fm fileExistsAtPath:backupFile])
	{
		SharedProgressBar* pb = [SharedProgressBar sharedInstance];
		ProgressBarController* pbc = [pb controller];
		NSString* targetFileBaseName = [[newlySavedFile lastPathComponent] stringByDeletingPathExtension];
		NSString* dateComponent = [[NSDate date] descriptionWithCalendarFormat:@"__%Y%m%d_%H%M%S"
																	  timeZone:nil
																		locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
		NSString* backupToFileBaseName = [targetFileBaseName stringByAppendingString:dateComponent];
		///backupToFileBaseName = [backupToFileBaseName stringByAppendingPathExtension:[newlySavedFile pathExtension]];
		backupToFileBaseName = [backupToFileBaseName stringByAppendingPathExtension:@"zip"];
		if (doLocalBackup || doMobileMeBackup)
		{
			int localBackupFreq = [Utils intFromDefaults:RCBDefaultLocalBackupFrequency];
			int numOfSavesSinceBU = [tbDocument numberOfSavesSinceLocalBackup]+1;
#if ENABLE_LOGGING
			NSLog(@"local backup enabled, numSaves:%d, freq:%d", numOfSavesSinceBU, localBackupFreq);
#endif
			if (numOfSavesSinceBU >= localBackupFreq)
			{
				BOOL worked = YES;
				if (![fm fileExistsAtPath:localBackupFolder])
				{
					worked = [fm createDirectoryAtPath:localBackupFolder 
							   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
				}
				if (worked)
				{
					localBackupFolder = [localBackupFolder stringByAppendingPathComponent:@"Backups of "];
					localBackupFolder = [localBackupFolder stringByAppendingString:targetFileBaseName];
					if (![fm fileExistsAtPath:localBackupFolder])
					{
						worked = [fm createDirectoryAtPath:localBackupFolder 
							   withIntermediateDirectories:YES
												attributes:nil
													 error:NULL];
					}
#if ENABLE_LOGGING
					NSLog(@"local backup folder: %@", localBackupFolder);
#endif
				}
				NSString* targetFilePath = nil;
				if (worked)
				{
					NSError* error;
					targetFilePath = [localBackupFolder stringByAppendingPathComponent:backupToFileBaseName];
					NSString* tempName = [targetFileBaseName stringByAppendingString:dateComponent];
					NSString* targetFilePathDir = [localBackupFolder stringByAppendingPathComponent:tempName];
					if (![fm fileExistsAtPath:targetFilePathDir])
					{
						worked = [fm createDirectoryAtPath:targetFilePathDir 
							   withIntermediateDirectories:YES
												attributes:nil
													 error:NULL];
					}
					if (worked)
					{
						NSString* copyDest = [targetFilePathDir stringByAppendingPathComponent:[newlySavedFile lastPathComponent]];
						worked = [fm copyItemAtPath:backupFile 
											 toPath:copyDest
											  error:&error];
						NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
						NSString *p = [NSMutableString stringWithString:[paths objectAtIndex:0]];
						p = [p stringByAppendingPathComponent:@"Ascent"];
						p = [p stringByAppendingPathComponent:@"EquipmentLog"];
						copyDest = [targetFilePathDir stringByAppendingPathComponent:[p lastPathComponent]];
						worked = [fm copyItemAtPath:p
											 toPath:copyDest
											  error:&error];
								  
					}
					
					[pbc begin:@"Saving local backup"
					 divisions:0];
					[pbc updateMessage:[NSString stringWithFormat:@"compressing activity document..."]];
					worked =  [self makeArchive:targetFilePathDir
									   destPath:targetFilePath];
					[fm removeItemAtPath:targetFilePathDir 
								   error:&error];
					
				}
				if (worked)
				{
					NSLog(@"%@", targetFilePath);
					[self setCompressedBackupFilePath:targetFilePath];
					[self trimBackups:localBackupFolder
						 baseFileName:targetFileBaseName
						  retainCount:[Utils intFromDefaults:RCBDefaultLocalBackupRetainCount]];
					[tbDocument setNumberOfSavesSinceLocalBackup:0];
				}
				else
				{
					NSAlert *alert = [[[NSAlert alloc] init] autorelease];
					[alert addButtonWithTitle:@"OK"];
					[alert setMessageText:@"Local backup could not be completed"];
					[alert setInformativeText:@"Error occurred while compressing activity document"];
					[alert setAlertStyle:NSWarningAlertStyle];
					[alert runModal];
				}
			}
			else
			{
				[tbDocument setNumberOfSavesSinceLocalBackup:numOfSavesSinceBU];
			}
		}
		if (doMobileMeBackup)
		{
			int backupFreq = [Utils intFromDefaults:RCBDefaultMobileMeBackupFrequency];
			int numOfSavesSinceBU = [tbDocument numberOfSavesSinceMobileMeBackup]+1;
#if ENABLE_LOGGING
			NSLog(@"MobileMe backup enabled, numSaves:%d, freq:%d", numOfSavesSinceBU, backupFreq);
#endif
			if (numOfSavesSinceBU >= backupFreq)
			{
				finished = NO;
				[self startNetworkBackup];
				[self doMobileMeBackup:backupFile
						toFileBaseName:backupToFileBaseName];
			}
			else
			{
				[tbDocument setNumberOfSavesSinceMobileMeBackup:numOfSavesSinceBU];
			}
		}
	}
	return finished;			
}


-(void)setConnection:(NSURLConnection*)conn
{
	if (connection != conn)
	{
		[connection release];
		connection = [conn retain];
	}
}


-(NSURLConnection*)connection
{
	return connection;
}


#pragma mark ***** NSURLConnection delegate callbacks

- (void)connection:(NSURLConnection *)conn didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
// Called by NSURLConnection when the server requires authentication.
{
#if _DEBUG
	printf("AUTHENTICATING!!\n");
#endif
#pragma unused(conn)
    CFStringRef account;
    CFStringRef password;
	
	OSStatus sts = CopyMobileMeAccountAndPassword(&account, &password);
    if (sts == noErr)
	{
		[self setMobileMeAccountName:(NSString*)account];
		if (password != nil) 
		{
			NSURLCredential *           cred;
			NSURLCredentialPersistence  credPersist;
			
			credPersist = NSURLCredentialPersistencePermanent;
#if TARGET_IPHONE_SIMULATOR
			credPersist = NSURLCredentialPersistenceForSession;
#endif
			
			cred = [NSURLCredential 
					credentialWithUser:(NSString*)account 
					password:(NSString*)password 
					persistence:credPersist];
			assert(cred != nil);
			
			[challenge.sender useCredential:cred 
					forAuthenticationChallenge:challenge];
		} 
		else 
		{
            [challenge.sender cancelAuthenticationChallenge:challenge];
		}
	}
}


-(BOOL)isFinished
{
	return connectionState == kConnectionStateFinished;
}



- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response
// Called by NSURLConnection when the server responds to our request.
{
#pragma unused(conn)
#pragma unused(response)
    int       statusCode;
	
    assert(conn == self.connection);
    assert(response != nil);
	
    assert( [response isKindOfClass:[NSHTTPURLResponse class]] );
	
    statusCode = ((NSHTTPURLResponse *)response).statusCode;
#if _DEBUG
	printf("connection response statusCode: %d\n", statusCode);
#endif
    if ( (statusCode / 100) != 2 ) 
	{
        ConnectionState     originalState;
		originalState = connectionState;
		
        // We got some sort of error.  Shut 'er down Clancy, she's pumping mud!
		[self stopConnection:@"Failed"];
        
        // In some case we expect a failure, so detect those cases and proceed 
        // to the next state.
        switch (originalState) 
		{
			case kConnectionStateUpMakeCollection: 
				{
					// If we tried to make the collection, 
					// and that failed because the collection was already there, 
					// just proceed to the upload state.
#if ENABLE_LOGGING
					NSLog(@"backup directory already exists, starting file upload");
#endif		
					if (statusCode == 405) 
					{
						[self startUpload:kConnectionStateUpPutBackup];
					}
				} 
				break;

            default: 
				{
					// do nothing
				} break;
		}
    } 
	else 
	{
     }
}


- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
// Called by NSURLConnection when we receive some data from the server.
{
#pragma unused(conn)
    assert(conn == self.connection);
    assert(data != nil);
	
#if 0
    if ( ([data length] + ((self.incomingData == nil) ? 0 : [self.incomingData length])) > kMaximumDownloadSize ) {
        
        // Too much data.  Shut everything down.
        
        [self stopConnection:@"Failed (content too large)"];
    } else {
		
        // Add the data to our incomingData buffer and update the status to 
        // reflect our progress.
        
        if (self.incomingData == nil) {
            self.incomingData = [data mutableCopy];
        } else {
            [self.incomingData appendData:data];
        }
        if ( (self.connectionState == kConnectionStateDownGetMain) || (self.connectionState == kConnectionStateDownGetBackup) ) {
            self.statusLabel.text = [NSString stringWithFormat:@"%zu bytes downloaded", (size_t) [self.incomingData length]];
        }
    }
#endif
}


- (void)connectionDidFinishLoading:(NSURLConnection *)conn
// Called by NSURLConnection at the end of a successful connection.
{
#pragma unused(conn)
    ConnectionState     originalState;
 	
    assert(conn == self.connection);
    
    // Update our status and shut down the connection.
    
    originalState = connectionState;
    [self stopConnection:@"Done"];
    
    // Proceed to the next state.
    switch (originalState) 
	{
		
        case kConnectionStateUpMakeCollection: 
		{
            // If the MOVE to create a backup is successful, start uploading the data.
#if ENABLE_LOGGING
			NSLog(@"backup folder created, starting file upload");
#endif		
           [self startUpload:kConnectionStateUpPutBackup];
        } 
		break;
			
        case kConnectionStateUpPutBackup: 
		{
#if ENABLE_LOGGING
			NSLog(@"backup file successfully uploaded");
#endif		
			[self setUploadInputStream:nil];
			[tbDocument setNumberOfSavesSinceMobileMeBackup:0];
		}
		break;
			
        default: 
		{
            // do nothing
        } 
		break;
    }
    
    //[finalData release];

}


- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	[self stopConnection:@"Failed"];
	[self finishNetworkBackup];
}



- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
// Called by NSURLConnection when the connection fails.
{
#pragma unused(conn)
	assert(error != nil);
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:[error localizedDescription]];
	NSString* failureReason = [error localizedFailureReason];
	NSString* recoverySuggestion = [error localizedRecoverySuggestion];
	NSMutableString* msg = [NSMutableString stringWithString:@""];
	if (failureReason)
	{
		[msg appendString:failureReason];
		[msg appendString:@"\n"];
		[msg appendString:[error localizedRecoverySuggestion]];
	}
	else if (recoverySuggestion)
	{
		[msg appendString:recoverySuggestion];
	}
	else
	{
		[msg appendString:[NSString stringWithFormat:@"Error code: %d\n", [error code]]];
	}
	[alert setInformativeText:msg];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
	[self stopConnection:@"Failed"];
	[self finishNetworkBackup];
}


- (BOOL)makeArchive:(NSString*)srcPath destPath:(NSString*)dstPath
{
	NSTask* task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/ditto"];
	//[task setCurrentDirectoryPath:path];    
	
	NSMutableArray* args = [[[NSMutableArray alloc] init] autorelease];
	[args addObject:@"-V"];
	[args addObject:@"-c"];
	[args addObject:@"-k"];
	[args addObject:@"--keepParent"];
	[args addObject:@"--sequesterRsrc"];
	[args addObject:srcPath];
	[args addObject:dstPath];
	[task setArguments:args];
	[task launch];
	[task waitUntilExit];
	int sts = [task terminationStatus];
	[task terminate];
	return sts == 0;
}	


@end
