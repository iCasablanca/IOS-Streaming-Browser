#import "HTTPAsyncFileResponse.h"
#import "HTTPConnection.h"


#import <unistd.h>
#import <fcntl.h>


#define NULL_FD  -1

/**
 * Architecure overview:
 * 
 * HTTPConnection will invoke our readDataOfLength: method to fetch data.
 * We will return nil, and then proceed to read the data via our readSource on our readQueue.
 * Once the requested amount of data has been read, we then pause our readSource,
 * and inform the connection of the available data.
 * 
 * While our read is in progress, we don't have to worry about the connection calling any other methods,
 * except the connectionDidClose method, which would be invoked if the remote end closed the socket connection.
 * To safely handle this, we do a synchronous dispatch on the readQueue,
 * and nilify the connection as well as cancel our readSource.
 * 
 * In order to minimize resource consumption during a HEAD request,
 * we don't open the file until we have to (until the connection starts requesting data).
**/

@implementation HTTPAsyncFileResponse


/**
    Initialize the HTTPAsyncFileResponse with a file path and HTTPConnection
    param NSString
    param HTTPConnection
    returns id
**/
- (id)initWithFilePath:(NSString *)fpath forConnection:(HTTPConnection *)parent
{
	if ((self = [super init]))
	{
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
        // Copy the passed-in file path variable into the local instance variable
		filePath = [fpath copy];
        
        // Check that the file path variable is not nil
		if (filePath == nil)
		{
			// If the file path variable is nil, then decrement this instances reference count and return nil
			[self release];
			return nil;
		}
		
		// Creates a dictionary object with the file attributes for the specified file path
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
        
        // Check that there are file attributes
		if (fileAttributes == nil)
		{
			
			[self release];
			return nil;
		}
		
        // Gets the length of the file
		fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
        
        // Set the file offset to the beginning of the file (i.e. zero)
		fileOffset = 0;
		
		aborted = NO;
		
		// We don't bother opening the file here.
		// If this is a HEAD request we only need to know the fileLength.
		fileFD = NULL_FD;
	}
	return self;
}


/**
    Abort the HTTP connection
**/
- (void)abort
{
	// abort the connection
	[connection responseDidAbort:self];
	aborted = YES;
}


/**
    Process the read buffer
**/
- (void)processReadBuffer
{
	// This method is here to allow superclasses to perform post-processing of the data.
	// For an example, see the HTTPDynamicFileResponse class.
	// 
	// At this point, the readBuffer has readBufferOffset bytes available.
	// This method is in charge of updating the readBufferOffset.
	// Failure to do so will cause the readBuffer to grow to fileLength. (Imagine a 1 GB file...)
	
	// Copy the data out of the temporary readBuffer.
	data = [[NSData alloc] initWithBytes:readBuffer length:readBufferOffset];
	
	// Reset the read buffer.
	readBufferOffset = 0;
	
	// Notify the connection that we have data available for it.
	[connection responseHasAvailableData:self];
}

/**
    Pause the read source
**/
- (void)pauseReadSource
{
    // If the read source is not suspended then suspend it
	if (!readSourceSuspended)
	{
		// Set the flag
		readSourceSuspended = YES;
		dispatch_suspend(readSource);
	}
}

/**
    Resume the read source
**/
- (void)resumeReadSource
{
    // If the read source is suspended
	if (readSourceSuspended)
	{
		// Set the flag
		readSourceSuspended = NO;
        
        // Resume the read source
		dispatch_resume(readSource);
	}
}

/**
    Cancel the read source
**/
- (void)cancelReadSource
{
	
	dispatch_source_cancel(readSource);
	
	// Cancelling a dispatch source doesn't
	// invoke the cancel handler if the dispatch source is paused.
	
	if (readSourceSuspended)
	{
		readSourceSuspended = NO;
		dispatch_resume(readSource);
	}
}

/**
    Whether can open a file and setup the readSource
    returns BOOL
**/
- (BOOL)openFileAndSetupReadSource
{
	// Open file as read only
	fileFD = open([filePath UTF8String], (O_RDONLY | O_NONBLOCK));
    
    // Test whether able to open the file
	if (fileFD == NULL_FD)
	{
		
		return NO;
	}
	
	// Creates a new dispatch queue to which blocks may be submitted.
	readQueue = dispatch_queue_create("HTTPAsyncFileResponse", NULL);
    
    // Creates a new dispatch source to monitor low-level system objects and automatically submit a handler block to a dispatch queue in response to events.
	readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fileFD, 0, readQueue);
	
	// Sets the event handler block for the readSource
	dispatch_source_set_event_handler(readSource, ^{
		
		
		// Determine how much data we should read.
		// 
		// It is OK if we ask to read more bytes than exist in the file.
		// It is NOT OK to over-allocate the buffer.
		
		unsigned long long _bytesAvailableOnFD = dispatch_source_get_data(readSource);
		
        // Bytes left to read from the file.  This is computed by taking the file length and subtracting the reader offset 
		UInt64 _bytesLeftInFile = fileLength - readOffset;
		
        // Bytes available on the file descriptor
		NSUInteger bytesAvailableOnFD;
        
        // The bytes yet to read from the file
		NSUInteger bytesLeftInFile;
		
        // Bytes available on the file descriptor
		bytesAvailableOnFD = (_bytesAvailableOnFD > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesAvailableOnFD;

        // Bytes yet to read from the file
		bytesLeftInFile    = (_bytesLeftInFile    > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesLeftInFile;
		
        // Bytes yet to read from the request
		NSUInteger bytesLeftInRequest = readRequestLength - readBufferOffset;
		
        // Lesser of the bytes left in the request or in the file
		NSUInteger bytesLeft = MIN(bytesLeftInRequest, bytesLeftInFile);
		
        // Lesser of bytes on file descriptor or bytes left in request
		NSUInteger bytesToRead = MIN(bytesAvailableOnFD, bytesLeft);
		
        /////////////////////////////////////////////////////////
		// Make sure buffer is big enough for read request.
		// Do not over-allocate.
        /////////////////////////////////////////////////////////
		
        
        // if the readbuffer is null or the bytes to read is greater than the buffer size minus the offset
		if (readBuffer == NULL || bytesToRead > (readBufferSize - readBufferOffset))
		{
            
            // Set the read buffer size to the number of bytes to read.  We don't want to create a buffer is larger or smaller than the number of bytes we are reading into the buffer
			readBufferSize = bytesToRead;
            
            // Realloate the size of the read buffer
			readBuffer = reallocf(readBuffer, (size_t)bytesToRead);
		
            // If the read buffer is null
			if (readBuffer == NULL)
			{
				// pause the read source
				[self pauseReadSource];
                
                // abort the http connection
				[self abort];
				
				return;
			}
		}
		
        ///////////////////////
		// Perform the read
		///////////////////////
		
        // Reads data from the file descriptor
		ssize_t result = read(fileFD, readBuffer + readBufferOffset, (size_t)bytesToRead);
		
		// Check the results
		if (result < 0)
		{
			// pause the readSource and abort the connection
			[self pauseReadSource];
			[self abort];
		}
		else if (result == 0)
		{
			// pause the readSource and abort the connection
			[self pauseReadSource];
			[self abort];
		}
		else // (result > 0) - we have successfully read some data
		{
			// Increase the read offset by the amount of data read from the file descriptor
			readOffset += result;
            
            // Increase the readbufer offset by the amount of data read from the file descriptor
			readBufferOffset += result;
			
            // Pause the read source
			[self pauseReadSource];
            
            // This method is here to allow superclasses to perform post-processing of the data.
			[self processReadBuffer];
		}
		
	}); // END OF BLOCK
	
    // Gets the file descriptor
	int theFileFD = fileFD;
    
    // Set the dispatch source to the readSource
	dispatch_source_t theReadSource = readSource;
	
	dispatch_source_set_cancel_handler(readSource, ^{
		
		// Do not access self from within this block in any way, shape or form.
		// 
		// Note: You access self if you reference an iVar.
		
		
		dispatch_release(theReadSource);
        
		close(theFileFD);
        
	}); // END OF BLOCK
	
    // Set the flag that the readSource is suspended
	readSourceSuspended = YES;
	
	return YES;
}

/**
    Whether need to open file or if it has already been opened
**/
- (BOOL)openFileIfNeeded
{
	if (aborted)
	{
		// The file operation has been aborted.
		// This could be because we failed to open the file,
		// or the reading process failed.
		return NO;
	}
	
    // if there is a file descriptor, then return YES because we don't need to open the file
	if (fileFD != NULL_FD)
	{
		// File has already been opened.
		return YES;
	}
	
    // Open the file and setup the readSource
	return [self openFileAndSetupReadSource];
}	

/**
    Get file length
    returns UInt64
**/
- (UInt64)contentLength
{
	
	return fileLength;
}

/**
    Get the file offset
    returns UInt64
**/
- (UInt64)offset
{
	
	return fileOffset;
}

/**
    Set the file's offset
    param Uint64
**/
- (void)setOffset:(UInt64)offset
{
    // Check if file could not be opened
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return;
	}
	
	fileOffset = offset;
	readOffset = offset;
	
    // reposition read/write file offset
	off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);

    // At the end
	if (result == -1)
	{
		
		[self abort];
	}
}

/**  
    Reads a certain length of data from the file
    param NSUInteger
    returns NSData
**/
- (NSData *)readDataOfLength:(NSUInteger)length
{
    // if there is data 
	if (data)
	{
        // Computes the length of the data
		NSUInteger dataLength = [data length];		
		
        // Increase the file offset by the length of data read
		fileOffset += dataLength;
		
        
		NSData *result = data;
		data = nil;
		
		return [result autorelease];
	}
	else // if there is no data 
	{
		if (![self openFileIfNeeded])
		{
			// File opening failed,
			// or response has been aborted due to another error.
			return nil;
		}
		
        // Submits a block for synchronous execution on a dispatch queue
		dispatch_sync(readQueue, ^{
			
			NSAssert(readSourceSuspended, @"Invalid logic - perhaps HTTPConnection has changed.");
			
            
			readRequestLength = length;
            
            // Resumes reading
			[self resumeReadSource];
            
            
		});  // END OF BLOCK
		
		return nil;
	}
}

/**
    If done reading the file
    returns BOOL
**/
- (BOOL)isDone
{
    // Check if fileoffset is at the end of the file
	BOOL result = (fileOffset == fileLength);
	
	return result;
}

/**
    Gets the file path
    returns NSString
**/
- (NSString *)filePath
{
	return filePath;
}

/**
    Whether this response is asynchronous
    returns BOOL
**/
- (BOOL)isAsynchronous
{
	return YES;
}

/**
    Cancel the readSource and set connection to nil
**/
- (void)connectionDidClose
{
	// If there is a file descriptor
	if (fileFD != NULL_FD)
	{
        // Submits a block for synchronous execution on the readQueue
		dispatch_sync(readQueue, ^{
			
			// Prevent any further calls to the connection
			connection = nil;
			
			// Cancel the readSource.
			// We do this here because the readSource's eventBlock has retained self.
			// In other words, if we don't cancel the readSource, we will never get deallocated.
			
			[self cancelReadSource];
		});
	}
}

/**
    Standard deconstructor
**/
- (void)dealloc
{
	// Check to see if there is anything in the read queue
	if (readQueue)
    {
		dispatch_release(readQueue);
	}
    
    // Check to see if there is anything in the read buffer
	if (readBuffer)
    {
		free(readBuffer);
	}
    
	[filePath release];
	[data release];
	
	[super dealloc]; 
}

@end
