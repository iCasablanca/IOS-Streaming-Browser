#import "HTTPFileResponse.h"
#import "HTTPConnection.h"


#import <unistd.h>
#import <fcntl.h>


#define NULL_FD  -1


@implementation HTTPFileResponse


/*
    Initialize the HTTPFileResponse with a file path and HTTPConnection
 */
- (id)initWithFilePath:(NSString *)fpath forConnection:(HTTPConnection *)parent
{
	if((self = [super init]))
	{
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
        // copies the file path into the instance variable
		filePath = [fpath copy];
        
        // If there is no file path then decrement the reference count for self and return nil
		if (filePath == nil)
		{
			
			[self release];
			return nil;
		}
		
        // Gets an NSDictionary of key/value pairs containing the attributes of the item (file, directory, symlink, etc.)
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        
        // If there are no file attributed, then decrement the 
		if (fileAttributes == nil)
		{
			
			[self release];
			return nil;
		}
		
        // Gets the file size
		fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
        
        
		fileOffset = 0;
		
		aborted = NO;
		
		// We don't bother opening the file here.
		// If this is a HEAD request we only need to know the fileLength.
		fileFD = NULL_FD;
	}
	return self;
}


/*
    Abort the connection
 */
- (void)abort
{
	
	[connection responseDidAbort:self];
	aborted = YES;
}

/*
    Whether can open the file or not
 */
- (BOOL)openFile
{
	
    // open the files as read only
	fileFD = open([filePath UTF8String], O_RDONLY);
    
    // If could not open the file
	if (fileFD == NULL_FD)
	{
		// Abort the connection
		[self abort];
        
        // Return 'NO' because we could not open the file
		return NO;
	}
	
	
	return YES;
}

/*
    Whether the file needs to be opened
 */
- (BOOL)openFileIfNeeded
{
	if (aborted)
	{
		// The file operation has been aborted.
		// This could be because we failed to open the file,
		// or the reading process failed.
		return NO;
	}
	
    // If the connection has not been aborted
    
    
	if (fileFD != NULL_FD)
	{
		// File has already been opened.
		return YES;
	}
	
    // opens the file
	return [self openFile];
}


/*
    Get the file length
 */
- (UInt64)contentLength
{
	
	return fileLength;
}

/*
    Gets the file offset
 */
- (UInt64)offset
{
	
	return fileOffset;
}


/*
    Set the file offset
 */
- (void)setOffset:(UInt64)offset
{
	
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return;
	}
	
	fileOffset = offset;
	
	off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);
	if (result == -1)
	{
		
		[self abort];
	}
}


/*
    Reads a specific length of data from the file and returns as within an NSData object
 */
- (NSData *)readDataOfLength:(NSUInteger)length
{
	
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return nil;
	}
	
	// Determine how much data we should read.
	// 
	// It is OK if we ask to read more bytes than exist in the file.
	// It is NOT OK to over-allocate the buffer.
	
	UInt64 bytesLeftInFile = fileLength - fileOffset;
	
	NSUInteger bytesToRead = (NSUInteger)MIN(length, bytesLeftInFile);
	
	// Make sure buffer is big enough for read request.
	// Do not over-allocate.
	
	if (buffer == NULL || bufferSize < bytesToRead)
	{
		bufferSize = bytesToRead;
		buffer = reallocf(buffer, (size_t)bufferSize);
		
		if (buffer == NULL)
		{
			
			[self abort];
			return nil;
		}
	}
	
	// Perform the read
	
	
	ssize_t result = read(fileFD, buffer, bytesToRead);
	
	// Check the results
	
	if (result < 0)
	{
		
		[self abort];
		return nil;
	}
	else if (result == 0)
	{
		
		[self abort];
		return nil;
	}
	else // (result > 0)
	{
		
		fileOffset += result;
		
		return [NSData dataWithBytes:buffer length:result];
	}
}

/*
    If done reading the files
 */
- (BOOL)isDone
{
	BOOL result = (fileOffset == fileLength);
	
	
	return result;
}

/*
    Returns the filePath as string
 */
- (NSString *)filePath
{
	return filePath;
}


/*
    Standard deconstructor
 */
- (void)dealloc
{
	
	if (fileFD != NULL_FD)
	{
		
		close(fileFD);
	}
	
	if (buffer)
		free(buffer);
	
	[filePath release];
	[super dealloc];
}

@end
