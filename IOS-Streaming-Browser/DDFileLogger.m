#import "DDFileLogger.h"



#import <unistd.h>  // defines miscellaneous symbolic constants and types, and declares miscellaneous functions


#import <sys/attr.h>
#import <sys/xattr.h>
#import <libkern/OSAtomic.h>

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
// 
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define LOG_LEVEL 2

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)

@interface DDLogFileManagerDefault (PrivateAPI)

/**
    @return void
**/
- (void)deleteOldLogFiles;

@end

@interface DDFileLogger (PrivateAPI)

#if GCD_MAYBE_UNAVAILABLE

/**
    @param NSMutableArray
    @return void
**/
- (void)lt_getMaximumFileSize:(NSMutableArray *)resultHolder;

/**
    @param NSNumber
    @return void
**/
- (void)lt_setMaximumFileSize:(NSNumber *)maximumFileSizeWrapper;

/**
    @param NSMutableArray
    @return void
**/
- (void)lt_getRollingFrequency:(NSMutableArray *)resultHolder;

/**
    @param NSNumber
    @return void
**/
- (void)lt_setRollingFrequency:(NSNumber *)rollingFrequencyWrapper;

#endif

/**
    @return void
**/
- (void)rollLogFileNow;

/**
    @param NSTimer
    @return void
**/
- (void)maybeRollLogFileDueToAge:(NSTimer *)aTimer;

/**
    @return void
**/
- (void)maybeRollLogFileDueToSize;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDLogFileManagerDefault

@synthesize maximumNumberOfLogFiles;


/**
    @brief Initialize the DDLogFileManagerDefault
    @return id
**/
- (id)init
{
	if ((self = [super init]))
	{
		maximumNumberOfLogFiles = DEFAULT_LOG_MAX_NUM_LOG_FILES;
		
		NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		
		[self addObserver:self forKeyPath:@"maximumNumberOfLogFiles" options:kvoOptions context:nil];
		
		NSLogVerbose(@"DDFileLogManagerDefault: logsDir:\n%@", [self logsDirectory]);
		NSLogVerbose(@"DDFileLogManagerDefault: sortedLogFileNames:\n%@", [self sortedLogFileNames]);
	}
	return self;
}

/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @param NSString
    @param id
    @param NSDictionary
    @return void
**/
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([old isEqual:new])
	{
		// No change in value - don't bother with any processing.
		return;
	}
	
	if ([keyPath isEqualToString:@"maximumNumberOfLogFiles"])
	{
		NSLogInfo(@"DDFileLogManagerDefault: Responding to configuration change: maximumNumberOfLogFiles");
		
        // Flag for whether grand central dispatch is available
		if (IS_GCD_AVAILABLE)
		{
		#if GCD_MAYBE_AVAILABLE
			
            
            // The prototype of blocks submitted to dispatch queues, which take no arguments and have no return value.
			dispatch_block_t block = ^{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
				[self deleteOldLogFiles];
				
				[pool release];
			}; // END OF BLOCK
			
			dispatch_async([DDLog loggingQueue], block);
			
		#endif
		}
		else
		{
		#if GCD_MAYBE_UNAVAILABLE
			
			[self performSelector:@selector(deleteOldLogFiles)
			             onThread:[DDLog loggingThread]
			           withObject:nil
			        waitUntilDone:NO];
			
		#endif
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Deleting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Deletes archived log files that exceed the maximumNumberOfLogFiles configuration value.
    @return void
**/
- (void)deleteOldLogFiles
{
	NSLogVerbose(@"DDLogFileManagerDefault: deleteOldLogFiles");
	
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	NSUInteger maxNumLogFiles = self.maximumNumberOfLogFiles;
	
	// Do we consider the first file?
	// We are only supposed to be deleting archived files.
	// In most cases, the first file is likely the log file that is currently being written to.
	// So in most cases, we do not want to consider this file for deletion.
	
	NSUInteger count = [sortedLogFileInfos count];
    
    // Whether to excludes the first log file and delete other log files, or delete all log files
	BOOL excludeFirstFile = NO;
	
    // Check if there are log files
	if (count > 0)
	{
		DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:0];
		
		if (!logFileInfo.isArchived)
		{
			excludeFirstFile = YES;
		}
	}
	
	NSArray *sortedArchivedLogFileInfos;
    
    // If deletign all log files, or excluding the first log file
	if (excludeFirstFile)
	{
		count--;
		sortedArchivedLogFileInfos = [sortedLogFileInfos subarrayWithRange:NSMakeRange(1, count)];
	}
	else // If deleting all log files
	{
		sortedArchivedLogFileInfos = sortedLogFileInfos;
	}
	
	NSUInteger i;
    
    // Loop through the log files
	for (i = 0; i < count; i++)
	{
        
		if (i >= maxNumLogFiles)
		{
			DDLogFileInfo *logFileInfo = [sortedArchivedLogFileInfos objectAtIndex:i];
			
			NSLogInfo(@"DDLogFileManagerDefault: Deleting file: %@", logFileInfo.fileName);
			
			[[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:nil];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Log Files
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Returns the path to the logs directory.
    If the logs directory doesn't exist, this method automatically creates it.
    @return NSString
**/
- (NSString *)logsDirectory
{
#if TARGET_OS_IPHONE
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
#else
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	
	NSString *appName = [[NSProcessInfo processInfo] processName];
	
	NSString *baseDir = [basePath stringByAppendingPathComponent:appName];
#endif
	
	NSString *logsDir = [baseDir stringByAppendingPathComponent:@"Logs"];
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:logsDir])
	{
		NSError *err = nil;
		if(![[NSFileManager defaultManager] createDirectoryAtPath:logsDir
		                              withIntermediateDirectories:YES attributes:nil error:&err])
		{
			NSLogError(@"DDFileLogManagerDefault: Error creating logsDirectory: %@", err);
		}
	}
	
	return logsDir;
}


/**
    @brief Check if the file name is a log file
    @param NSString
    @return BOOL
**/
- (BOOL)isLogFile:(NSString *)fileName
{
	// A log file has a name like "log-<uuid>.txt", where <uuid> is a HEX-string of 6 characters.
	// 
	// For example: log-DFFE99.txt
	
	BOOL hasProperPrefix = [fileName hasPrefix:@"log-"];
	
	BOOL hasProperLength = [fileName length] >= 10;
	
	
	if (hasProperPrefix && hasProperLength)
	{
		NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
		
		NSString *hex = [fileName substringWithRange:NSMakeRange(4, 6)];
		NSString *nohex = [hex stringByTrimmingCharactersInSet:hexSet];
		
		if ([nohex length] == 0)
		{
			return YES;
		}
	}
	
	return NO;
}

/**
    @brief Returns an array of NSString objects, each of which is the filePath to an existing log file on disk.
    @return NSArray
**/
- (NSArray *)unsortedLogFilePaths
{
	NSString *logsDirectory = [self logsDirectory];
	
	NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];
	
	NSMutableArray *unsortedLogFilePaths = [NSMutableArray arrayWithCapacity:[fileNames count]];
	
	for (NSString *fileName in fileNames)
	{
		// Filter out any files that aren't log files. (Just for extra safety)
		
		if ([self isLogFile:fileName])
		{
			NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
			
			[unsortedLogFilePaths addObject:filePath];
		}
	}
	
	return unsortedLogFilePaths;
}

/**
    @brief Returns an array of NSString objects, each of which is the fileName of an existing log file on disk.
    @return NSArray
**/
- (NSArray *)unsortedLogFileNames
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	NSMutableArray *unsortedLogFileNames = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (NSString *filePath in unsortedLogFilePaths)
	{
		[unsortedLogFileNames addObject:[filePath lastPathComponent]];
	}
	
	return unsortedLogFileNames;
}

/**
    @brief Returns an array of DDLogFileInfo objects, each representing an existing log file on disk, and containing important information about the log file such as it's modification date and size.
    @return NSArray
**/
- (NSArray *)unsortedLogFileInfos
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	NSMutableArray *unsortedLogFileInfos = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (NSString *filePath in unsortedLogFilePaths)
	{
		DDLogFileInfo *logFileInfo = [[DDLogFileInfo alloc] initWithFilePath:filePath];
		
		[unsortedLogFileInfos addObject:logFileInfo];
		[logFileInfo release];
	}
	
	return unsortedLogFileInfos;
}

/**
    @brief Just like the unsortedLogFilePaths method, but sorts the array.
 
    The items in the array are sorted by modification date.
    The first item in the array will be the most recently modified log file.
    @return NSArray
**/
- (NSArray *)sortedLogFilePaths
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	NSMutableArray *sortedLogFilePaths = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFilePaths addObject:[logFileInfo filePath]];
	}
	
	return sortedLogFilePaths;
}

/**
    @brief Just like the unsortedLogFileNames method, but sorts the array.
    The items in the array are sorted by modification date.
    The first item in the array will be the most recently modified log file.
    @return NSArray
**/
- (NSArray *)sortedLogFileNames
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	NSMutableArray *sortedLogFileNames = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFileNames addObject:[logFileInfo fileName]];
	}
	
	return sortedLogFileNames;
}

/**
    @brief Just like the unsortedLogFileInfos method, but sorts the array.
    The items in the array are sorted by modification date.
    The first item in the array will be the most recently modified log file.
    @return NSArray
**/
- (NSArray *)sortedLogFileInfos
{
	return [[self unsortedLogFileInfos] sortedArrayUsingSelector:@selector(reverseCompareByCreationDate:)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Generates a short UUID suitable for use in the log file's name.
    The result will have six characters, all in the hexadecimal set [0123456789ABCDEF].
    @return NSString
**/
- (NSString *)generateShortUUID
{
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	
	CFStringRef fullStr = CFUUIDCreateString(NULL, uuid);
	CFStringRef shortStr = CFStringCreateWithSubstring(NULL, fullStr, CFRangeMake(0, 6));
	
	CFRelease(fullStr);
	CFRelease(uuid);
	
	return [NSMakeCollectable(shortStr) autorelease];
}

/**
    @brief Generates a new unique log file path, and creates the corresponding log file.
    @return NSString
**/
- (NSString *)createNewLogFile
{
	// Generate a random log file name, and create the file (if there isn't a collision)
	
	NSString *logsDirectory = [self logsDirectory];
	do
	{
		NSString *fileName = [NSString stringWithFormat:@"log-%@.txt", [self generateShortUUID]];
		
		NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
		{
			NSLogVerbose(@"DDLogFileManagerDefault: Creating new log file: %@", fileName);
			
			[[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
			
			// Since we just created a new log file, we may need to delete some old log files
			[self deleteOldLogFiles];
			
			return filePath;
		}
		
	} while(YES);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDLogFileFormatterDefault

/**
    @brief Initialize the DDLogFileFormatterDefault
    @return id
**/
- (id)init
{
	if((self = [super init]))
	{
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
	}
	return self;
}


/**
    @param DDLogMessage
    @return NSString
**/
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
	NSString *dateAndTime = [dateFormatter stringFromDate:(logMessage->timestamp)];
	
	return [NSString stringWithFormat:@"%@  %@", dateAndTime, logMessage->logMsg];
}


/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{
	[dateFormatter release];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDFileLogger

@synthesize maximumFileSize;
@synthesize rollingFrequency;
@synthesize logFileManager;


/**
    @brief Initialize the DDFileLogger
    @return id
**/
- (id)init
{
	DDLogFileManagerDefault *defaultLogFileManager = [[[DDLogFileManagerDefault alloc] init] autorelease];
	
	return [self initWithLogFileManager:defaultLogFileManager];
}

/**
    @brief Initialize the DDFileLogger with a log file manager
    @return id
**/
- (id)initWithLogFileManager:(id <DDLogFileManager>)aLogFileManager
{
	if ((self = [super init]))
	{
		maximumFileSize = DEFAULT_LOG_MAX_FILE_SIZE;
		rollingFrequency = DEFAULT_LOG_ROLLING_FREQUENCY;
		
		logFileManager = [aLogFileManager retain];
		
		formatter = [[DDLogFileFormatterDefault alloc] init];
	}
	return self;
}


/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{
	[formatter release];
	[logFileManager release];
	
	[currentLogFileInfo release];
	
	[currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	[currentLogFileHandle release];
	
	[rollingTimer invalidate];
	[rollingTimer release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Gets the maximum file size.  This value can be between 0 and 9,223,372,036,854,775,807
    @return unsigned long long. 
**/
- (unsigned long long)maximumFileSize
{
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation should access the maximumFileSize variable directly,
	// but if we forget to do this, then this method should at least work properly.
	
	if (IS_GCD_AVAILABLE)
	{
	#if GCD_MAYBE_AVAILABLE
		
		if (dispatch_get_current_queue() == loggerQueue)
		{
			return maximumFileSize;
		}
		
        // Result can be between 0 and 9,223,372,036,854,775,807
		__block unsigned long long result;
		
		dispatch_block_t block = ^{
            
			result = maximumFileSize;
		};
		dispatch_sync([DDLog loggingQueue], block);
		
		return result;
		
	#endif
	}
	else
	{
	#if GCD_MAYBE_UNAVAILABLE
		
		NSThread *loggingThread = [DDLog loggingThread];
		
		if ([NSThread currentThread] == loggingThread)
		{
			return maximumFileSize;
		}
		
        // Results can be between 0 and 9,223,372,036,854,775,807
		unsigned long long result;
		NSMutableArray *resultHolder = [[NSMutableArray alloc] init];
		
		[self performSelector:@selector(lt_getMaximumFileSize:)
		             onThread:loggingThread
		           withObject:resultHolder
		        waitUntilDone:YES];
		
		OSMemoryBarrier();
		
		result = [[resultHolder objectAtIndex:0] unsignedLongLongValue];
		[resultHolder release];
		
		return result;
		
	#endif
	}
}


/**
    @brief Sets the maximum file size.  This value can be between 0 and 9,223,372,036,854,775,807
    @param unsigned long long
    @return void
**/
- (void)setMaximumFileSize:(unsigned long long)newMaximumFileSize
{
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For documentation please refer to the DDAbstractLogger implementation.
	
	if (IS_GCD_AVAILABLE)
	{
	#if GCD_MAYBE_AVAILABLE
		
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			maximumFileSize = newMaximumFileSize;
			[self maybeRollLogFileDueToSize];
			
			[pool release];
		};
		
		if (dispatch_get_current_queue() == loggerQueue)
			block();
		else
			dispatch_async([DDLog loggingQueue], block);
		
	#endif
	}
	else
	{
	#if GCD_MAYBE_UNAVAILABLE
		
		NSThread *loggingThread = [DDLog loggingThread];
		NSNumber *newMaximumFileSizeWrapper = [NSNumber numberWithUnsignedLongLong:newMaximumFileSize];
		
		if ([NSThread currentThread] == loggingThread)
		{
			[self lt_setMaximumFileSize:newMaximumFileSizeWrapper];
		}
		else
		{
			[self performSelector:@selector(lt_setMaximumFileSize:)
			             onThread:loggingThread
			           withObject:newMaximumFileSizeWrapper
			        waitUntilDone:NO];
		}
		
	#endif
	}
}


/**
    @return NSTimeInterval
**/
- (NSTimeInterval)rollingFrequency
{
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation should access the rollingFrequency variable directly,
	// but if we forget to do this, then this method should at least work properly.
	
	if (IS_GCD_AVAILABLE)
	{
	#if GCD_MAYBE_AVAILABLE
		
		if (dispatch_get_current_queue() == loggerQueue)
		{
			return rollingFrequency;
		}
		
		__block NSTimeInterval result;
		
		dispatch_block_t block = ^{
			result = rollingFrequency;
		};
		dispatch_sync([DDLog loggingQueue], block);
		
		return result;
		
	#endif
	}
	else
	{
	#if GCD_MAYBE_UNAVAILABLE
		
		NSThread *loggingThread = [DDLog loggingThread];
		
		if ([NSThread currentThread] == loggingThread)
		{
			return rollingFrequency;
		}
		
		NSTimeInterval result;
		NSMutableArray *resultHolder = [[NSMutableArray alloc] init];
		
		[self performSelector:@selector(lt_getRollingFrequency:)
		             onThread:loggingThread
		           withObject:resultHolder
		        waitUntilDone:YES];
		
		OSMemoryBarrier();
		
		result = [[resultHolder objectAtIndex:0] doubleValue];
		[resultHolder release];
		
		return result;
		
	#endif
	}
}


/**
    @param NSTimeInterval
    @return void
**/
- (void)setRollingFrequency:(NSTimeInterval)newRollingFrequency
{
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For documentation please refer to the DDAbstractLogger implementation.
	
	if (IS_GCD_AVAILABLE)
	{
	#if GCD_MAYBE_AVAILABLE
		
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			rollingFrequency = newRollingFrequency;
			[self maybeRollLogFileDueToAge:nil];
			
			[pool release];
		};
		
		if (dispatch_get_current_queue() == loggerQueue)
			block();
		else
			dispatch_async([DDLog loggingQueue], block);
		
	#endif
	}
	else
	{
	#if GCD_MAYBE_UNAVAILABLE
		
		NSThread *loggingThread = [DDLog loggingThread];
		NSNumber *newMaximumRollingFrequencyWrapper = [NSNumber numberWithDouble:newRollingFrequency];
		
		if ([NSThread currentThread] == loggingThread)
		{
			[self lt_setRollingFrequency:newMaximumRollingFrequencyWrapper];
		}
		else
		{
			[self performSelector:@selector(lt_setRollingFrequency:)
			             onThread:loggingThread
			           withObject:newMaximumRollingFrequencyWrapper
			        waitUntilDone:NO];
		}
		
	#endif
	}
}

#if GCD_MAYBE_UNAVAILABLE


/**
    @brief Get the maximum file size
    @param NSMutableArray
    @return void
**/
- (void)lt_getMaximumFileSize:(NSMutableArray *)resultHolder
{
	// This method is executed on the logging thread.
	
	[resultHolder addObject:[NSNumber numberWithUnsignedLongLong:maximumFileSize]];
	OSMemoryBarrier();
}


/**
    @brief Set the maximum file size
    @param NSNumber
    @return void
**/
- (void)lt_setMaximumFileSize:(NSNumber *)maximumFileSizeWrapper
{
	// This method is executed on the logging thread.
	
	maximumFileSize = [maximumFileSizeWrapper unsignedLongLongValue];
	
	[self maybeRollLogFileDueToSize];
}

/**
    @brief Get the rolling frequency
    @param NSMutableArray
    @return void
**/
- (void)lt_getRollingFrequency:(NSMutableArray *)resultHolder
{
	// This method is executed on the logging thread.
	
	[resultHolder addObject:[NSNumber numberWithDouble:rollingFrequency]];
	OSMemoryBarrier();
}

/**
    @brief Set the rolling frequency
    @param NSNumber
    @return void
**/
- (void)lt_setRollingFrequency:(NSNumber *)rollingFrequencyWrapper
{
	// This method is executed on the logging thread.
	
	rollingFrequency = [rollingFrequencyWrapper doubleValue];
	
	[self maybeRollLogFileDueToAge:nil];
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Rolling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @return void
**/
- (void)scheduleTimerToRollLogFileDueToAge
{
	if (rollingTimer)
	{
		[rollingTimer invalidate];
		[rollingTimer release];
		rollingTimer = nil;
	}
	
	if (currentLogFileInfo == nil)
	{
		return;
	}
	
	NSDate *logFileCreationDate = [currentLogFileInfo creationDate];
	
	NSTimeInterval ti = [logFileCreationDate timeIntervalSinceReferenceDate];
	ti += rollingFrequency;
	
	NSDate *logFileRollingDate = [NSDate dateWithTimeIntervalSinceReferenceDate:ti];
	
	NSLogVerbose(@"DDFileLogger: scheduleTimerToRollLogFileDueToAge");
	
	NSLogVerbose(@"DDFileLogger: logFileCreationDate: %@", logFileCreationDate);
	NSLogVerbose(@"DDFileLogger: logFileRollingDate : %@", logFileRollingDate);
	
	rollingTimer = [[NSTimer scheduledTimerWithTimeInterval:[logFileRollingDate timeIntervalSinceNow]
	                                                 target:self
	                                               selector:@selector(maybeRollLogFileDueToAge:)
	                                               userInfo:nil
	                                                repeats:NO] retain];
}


/**
    @return void
**/
- (void)rollLogFile
{
	// This method is public.
	// We need to execute the rolling on our logging thread/queue.
	
	if (IS_GCD_AVAILABLE)
	{
	#if GCD_MAYBE_AVAILABLE
		
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			[self rollLogFileNow];
			[pool release];
		}; // END OF BLOCK
        
		dispatch_async([DDLog loggingQueue], block);
		
	#endif
	}
	else
	{
	#if GCD_MAYBE_UNAVAILABLE
		
		[self performSelector:@selector(rollLogFileNow)
		             onThread:[DDLog loggingThread]
		           withObject:nil
		        waitUntilDone:NO];
		
	#endif
	}
}

/**
    @return void
**/
- (void)rollLogFileNow
{
	NSLogVerbose(@"DDFileLogger: rollLogFileNow");
	
	[currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	[currentLogFileHandle release];
	currentLogFileHandle = nil;
	
	currentLogFileInfo.isArchived = YES;
	
	if ([logFileManager respondsToSelector:@selector(didRollAndArchiveLogFile:)])
	{
		[logFileManager didRollAndArchiveLogFile:(currentLogFileInfo.filePath)];
	}
	
	[currentLogFileInfo release];
	currentLogFileInfo = nil;
}

/**
    @param NSTimer
    @return void
**/
- (void)maybeRollLogFileDueToAge:(NSTimer *)aTimer
{
	if (currentLogFileInfo.age >= rollingFrequency)
	{
		NSLogVerbose(@"DDFileLogger: Rolling log file due to age...");
		
		[self rollLogFileNow];
	}
	else
	{
		[self scheduleTimerToRollLogFileDueToAge];
	}
}


/**
    @return void
**/ 
- (void)maybeRollLogFileDueToSize
{
	// This method is called from logMessage.
	// Keep it FAST.
	
    // File size can be between 0 and 9,223,372,036,854,775,807
	unsigned long long fileSize = [currentLogFileHandle offsetInFile];
	
	// Note: Use direct access to maximumFileSize variable.
	// We specifically wrote our own getter/setter method to allow us to do this (for performance reasons).
	
	if (fileSize >= maximumFileSize) // YES, we are using direct access. Read note above.
	{
		NSLogVerbose(@"DDFileLogger: Rolling log file due to size...");
		
		[self rollLogFileNow];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Returns the log file that should be used.
 
    If there is an existing log file that is suitable, within the constraints of maximumFileSize and rollingFrequency, then it is returned.
  
    Otherwise a new file is created and returned.
    @return DDLogFileInfo
**/
- (DDLogFileInfo *)currentLogFileInfo
{
	if (currentLogFileInfo == nil)
	{
		NSArray *sortedLogFileInfos = [logFileManager sortedLogFileInfos];
		
		if ([sortedLogFileInfos count] > 0)
		{
			DDLogFileInfo *mostRecentLogFileInfo = [sortedLogFileInfos objectAtIndex:0];
			
			BOOL useExistingLogFile = YES;
			BOOL shouldArchiveMostRecent = NO;
			
			if (mostRecentLogFileInfo.isArchived)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = NO;
			}
			else if (mostRecentLogFileInfo.fileSize >= maximumFileSize)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			else if (mostRecentLogFileInfo.age >= rollingFrequency)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			
			if (useExistingLogFile)
			{
				NSLogVerbose(@"DDFileLogger: Resuming logging with file %@", mostRecentLogFileInfo.fileName);
				
				currentLogFileInfo = [mostRecentLogFileInfo retain];
			}
			else
			{
				if (shouldArchiveMostRecent)
				{
					mostRecentLogFileInfo.isArchived = YES;
					
					if ([logFileManager respondsToSelector:@selector(didArchiveLogFile:)])
					{
						[logFileManager didArchiveLogFile:(mostRecentLogFileInfo.filePath)];
					}
				}
			}
		}
		
		if (currentLogFileInfo == nil)
		{
			NSString *currentLogFilePath = [logFileManager createNewLogFile];
			
			currentLogFileInfo = [[DDLogFileInfo alloc] initWithFilePath:currentLogFilePath];
		}
	}
	
	return currentLogFileInfo;
}

/**
    @brief Gets the file handle to the current log file
    @return NSFileHandle
**/
- (NSFileHandle *)currentLogFileHandle
{
	if (currentLogFileHandle == nil)
	{
		NSString *logFilePath = [[self currentLogFileInfo] filePath];
		
		currentLogFileHandle = [[NSFileHandle fileHandleForWritingAtPath:logFilePath] retain];
		[currentLogFileHandle seekToEndOfFile];
		
		if (currentLogFileHandle)
		{
			[self scheduleTimerToRollLogFileDueToAge];
		}
	}
	
	return currentLogFileHandle;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark DDLogger Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @param DDLogMessage
    @return void
**/
- (void)logMessage:(DDLogMessage *)logMessage
{
	NSString *logMsg = logMessage->logMsg;
	
	if (formatter)
	{
		logMsg = [formatter formatLogMessage:logMessage];
	}
	
	if (logMsg)
	{
		if (![logMsg hasSuffix:@"\n"])
		{
			logMsg = [logMsg stringByAppendingString:@"\n"];
		}
		
		NSData *logData = [logMsg dataUsingEncoding:NSUTF8StringEncoding];
		
		[[self currentLogFileHandle] writeData:logData];
		
		[self maybeRollLogFileDueToSize];
	}
}

/**
    @brief Gets the logger name
    @return NSString
**/
- (NSString *)loggerName
{
	return @"cocoa.lumberjack.fileLogger";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_IPHONE_SIMULATOR
  #define XATTR_ARCHIVED_NAME  @"archived"
#else
  #define XATTR_ARCHIVED_NAME  @"lumberjack.log.archived"
#endif

@implementation DDLogFileInfo

@synthesize filePath;

@dynamic fileName;
@dynamic fileAttributes;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic fileSize;
@dynamic age;

@dynamic isArchived;


#pragma mark Lifecycle

/**
    Class method
    @param NSSTring
    @return id
**/
+ (id)logFileWithPath:(NSString *)aFilePath
{
	return [[[DDLogFileInfo alloc] initWithFilePath:aFilePath] autorelease];
}

/**
    @brief Initialize with a file path
    @param NSString
    @return id
**/
- (id)initWithFilePath:(NSString *)aFilePath
{
	if ((self = [super init]))
	{
		filePath = [aFilePath copy];
	}
	return self;
}

/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{
	[filePath release];
	[fileName release];
	
	[fileAttributes release];
	
	[creationDate release];
	[modificationDate release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Gets the file attributes
    @return NSDictionary
**/
- (NSDictionary *)fileAttributes
{
	if (fileAttributes == nil)
	{
		fileAttributes = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] retain];
	}
	return fileAttributes;
}

/**
    @brief Gets the file name
    @return NSString
**/
- (NSString *)fileName
{
	if (fileName == nil)
	{
		fileName = [[filePath lastPathComponent] retain];
	}
	return fileName;
}


/**
    @brief Gets the modification date
    @return NSDate
**/
- (NSDate *)modificationDate
{
	if (modificationDate == nil)
	{
		modificationDate = [[[self fileAttributes] objectForKey:NSFileModificationDate] retain];
	}
	
	return modificationDate;
}

/**
    @brief The log file creation date
    @return NSDate
**/
- (NSDate *)creationDate
{
	if (creationDate == nil)
	{
	
	#if TARGET_OS_IPHONE
        
        // Create a constant read only local attribute
		const char *path = [filePath UTF8String];
		
		struct attrlist attrList;
		memset(&attrList, 0, sizeof(attrList));
		attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
		attrList.commonattr = ATTR_CMN_CRTIME;
		
		struct {
			u_int32_t attrBufferSizeInBytes;
			struct timespec crtime;
		} attrBuffer;
		
		int result = getattrlist(path, &attrList, &attrBuffer, sizeof(attrBuffer), 0);
		if (result == 0)
		{
			double seconds = (double)(attrBuffer.crtime.tv_sec);
			double nanos   = (double)(attrBuffer.crtime.tv_nsec);
			
			NSTimeInterval ti = seconds + (nanos / 1000000000.0);
			
			creationDate = [[NSDate dateWithTimeIntervalSince1970:ti] retain];
		}
		else
		{
			NSLogError(@"DDLogFileInfo: creationDate(%@): getattrlist result = %i", self.fileName, result);
		}
		
	#else
		
		creationDate = [[[self fileAttributes] objectForKey:NSFileCreationDate] retain];
		
	#endif
		
	}
	return creationDate;
}

/**
    @brief Gets the file size
    @return value between 0 and 9,223,372,036,854,775,807
**/
- (unsigned long long)fileSize
{
	if (fileSize == 0)
	{
		fileSize = [[[self fileAttributes] objectForKey:NSFileSize] unsignedLongLongValue];
	}
	
	return fileSize;
}

/**
    @brief Gets the age of the log file
    @return NSTimeInterval
**/
- (NSTimeInterval)age
{
	return [[self creationDate] timeIntervalSinceNow] * -1.0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Archiving
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @brief Whether the log file is archived
    @return BOOL
**/
- (BOOL)isArchived
{
	
#if TARGET_IPHONE_SIMULATOR
	
	// Extended attributes don't work properly on the simulator.
	// So we have to use a less attractive alternative.
	// See full explanation in the header file.
	
	return [self hasExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	
#else
	
	return [self hasExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
#endif
}

/**
    @brief Set the file for archiving
    @param BOOL
    @return void
**/
- (void)setIsArchived:(BOOL)flag
{
	
#if TARGET_IPHONE_SIMULATOR
	
	// Extended attributes don't work properly on the simulator.
	// So we have to use a less attractive alternative.
	// See full explanation in the header file.
	
	if (flag)
		[self addExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	
#else
	
	if (flag)
		[self addExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Changes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @return void
**/
- (void)reset
{
	[fileName release];
	fileName = nil;
	
	[fileAttributes release];
	fileAttributes = nil;
	
	[creationDate release];
	creationDate = nil;
	
	[modificationDate release];
	modificationDate = nil;
}

/**
    @brief Rename the log file
    @param NSString
    @return void
**/
- (void)renameFile:(NSString *)newFileName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if (![newFileName isEqualToString:[self fileName]])
	{
		NSString *fileDir = [filePath stringByDeletingLastPathComponent];
		
		NSString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];
		
		NSLogVerbose(@"DDLogFileInfo: Renaming file: '%@' -> '%@'", self.fileName, newFileName);
		
		NSError *error = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newFilePath error:&error])
		{
			NSLogError(@"DDLogFileInfo: Error renaming file (%@): %@", self.fileName, error);
		}
		
		[filePath release];
		filePath = [newFilePath retain];
		
		[self reset];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attribute Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_IPHONE_SIMULATOR

// Extended attributes don't work properly on the simulator.
// So we have to use a less attractive alternative.
// See full explanation in the header file.

/**
    @param NSString
    @return boolean
**/
- (BOOL)hasExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	// Split the file name into components.
	// 
	// log-ABC123.archived.uploaded.txt
	// 
	// 0. log-ABC123
	// 1. archived
	// 2. uploaded
	// 3. txt
	// 
	// So we want to search for the attrName in the components (ignoring the first and last array indexes).
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	// Watch out for file names without an extension
	
	NSUInteger count = [components count];
	NSUInteger max = (count >= 2) ? count-1 : count;
	
	NSUInteger i;
    
	for (i = 1; i < max; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		
		if ([attrName isEqualToString:attr])
		{
			return YES;
		}
	}
	
	return NO;
}


/**
    @param NSString
    @return void
**/
- (void)addExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if ([attrName length] == 0) return;
	
	// Example:
	// attrName = "archived"
	// 
	// "log-ABC123.txt" -> "log-ABC123.archived.txt"
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	NSUInteger count = [components count];
	
	NSUInteger estimatedNewLength = [[self fileName] length] + [attrName length] + 1;
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	
	NSString *lastExt = @"";
	
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		if ([attr length] == 0)
		{
			continue;
		}
		
		if ([attrName isEqualToString:attr])
		{
			// Extension attribute already exists in file name
			return;
		}
		
		if ([lastExt length] > 0)
		{
			[newFileName appendFormat:@".%@", lastExt];
		}
		
		lastExt = attr;
	}
	
	[newFileName appendFormat:@".%@", attrName];
	
	if ([lastExt length] > 0)
	{
		[newFileName appendFormat:@".%@", lastExt];
	}
	
	[self renameFile:newFileName];
}


/**
    @param NSString
    @return void
**/
- (void)removeExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if ([attrName length] == 0) return;
	
	// Example:
	// attrName = "archived"
	// 
	// "log-ABC123.txt" -> "log-ABC123.archived.txt"
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	NSUInteger count = [components count];
	
	NSUInteger estimatedNewLength = [[self fileName] length];
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	
	BOOL found = NO;
	
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		
		if ([attrName isEqualToString:attr])
		{
			found = YES;
		}
		else
		{
			[newFileName appendFormat:@".%@", attr];
		}
	}
	
	if (found)
	{
		[self renameFile:newFileName];
	}
}

#else

/**
    @param NSString
    @return boolean
**/
- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName
{
    // Create a constant read only local attribute
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	ssize_t result = getxattr(path, name, NULL, 0, 0, 0);
	
	return (result >= 0);
}

/**
    @param NSString
    @return void
**/
- (void)addExtendedAttributeWithName:(NSString *)attrName
{
    // Create a constant read only local attribute
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	int result = setxattr(path, name, NULL, 0, 0, 0);
	
	if (result < 0)
	{
		NSLogError(@"DDLogFileInfo: setxattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}

/**
    @param NSString
    @return void
**/
- (void)removeExtendedAttributeWithName:(NSString *)attrName
{
    // Create a constant read only local attribute
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	int result = removexattr(path, name, 0);
	
	if (result < 0 && errno != ENOATTR)
	{
		NSLogError(@"DDLogFileInfo: removexattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    @param id
    @return boolean
**/
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]])
	{
		DDLogFileInfo *another = (DDLogFileInfo *)object;
		
		return [filePath isEqualToString:[another filePath]];
	}
	
	return NO;
}


/**
    @param DDLogFileInfo
    @return NSComparisonResult
**/
- (NSComparisonResult)reverseCompareByCreationDate:(DDLogFileInfo *)another
{
	NSDate *us = [self creationDate];
	NSDate *them = [another creationDate];
	
	NSComparisonResult result = [us compare:them];
	
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}

/**
    @param DDLogFileInfo
    @return NSComparisonResult
**/
- (NSComparisonResult)reverseCompareByModificationDate:(DDLogFileInfo *)another
{
	NSDate *us = [self modificationDate];
	NSDate *them = [another modificationDate];
	
	NSComparisonResult result = [us compare:them];
	
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}

@end
