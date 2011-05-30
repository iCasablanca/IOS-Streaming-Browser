#import "HTTPFileResponse.h"
#import "HTTPConnection.h"


#import <unistd.h>
#import <fcntl.h>


#define NULL_FD  -1


@implementation HTTPFileResponse


/*
    Initialize the HTTPFileResponse with a file path and HTTPConnection
    param NSString
    param HTTPConnection
    returns id
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
        
        // Sets the file offset to the beginning of the file
		fileOffset = 0;
		
        // Whether file response has been aborted
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
	// Check if the connection did abort
	[connection responseDidAbort:self];
	aborted = YES;
}

/*
    Whether can open the file or not
    returns BOOL
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
    returns BOOL
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
    
    // If the file descriptor is not null then the file is open
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
    returns UInt64
*/
- (UInt64)contentLength
{
	
	return fileLength;
}

/*
    Gets the file offset
    returns UInt64
*/
- (UInt64)offset
{
	
	return fileOffset;
}


/*
    Set the file offset
    param UInt64
*/
- (void)setOffset:(UInt64)offset
{
	
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return;
	}
	
    // Sets file file offset
	fileOffset = offset;
	
    // repositions the file offset
	off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);

    // if lseek return the resulting offset location as measured in bytes from the beginning of the file then it returns an error of -1
	if (result == -1)
	{
		// abort the file response
		[self abort];
	}
}


/*
    Reads a specific length of data from the file and returns as within an NSData object
    param NSUInteger
    returns NSData
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
        // Bytes left to read from the file
		bufferSize = bytesToRead;
        
        // Try to change the size of the buffer
		buffer = reallocf(buffer, (size_t)bufferSize);
		
        // If could not change the size of the buffer
		if (buffer == NULL)
		{
			// abort the file response
			[self abort];
			return nil;
		}
	}
	
    /////////////////////////
	// Perform the read
	/////////////////////////
    
	// reads bytes from file descriptor into buffer 
	ssize_t result = read(fileFD, buffer, bytesToRead);
	
    
    /////////////////////////
	// Check the results
    /////////////////////////
    
    
	// If there was an error attempting to read from the file
	if (result < 0)
	{
		
		[self abort];
		return nil;
	} // if nothing there is nothing to read
	else if (result == 0)
	{
		
		[self abort];
		return nil;
	}
	else // (result > 0)
	{
		// Increases the file offset by the number of bytes read into the buffer
		fileOffset += result;
		
        // Returns the bytes in the buffer
		return [NSData dataWithBytes:buffer length:result];
	}
}

/*
    If done reading the files
    returns BOOL
*/
- (BOOL)isDone
{
    // Check if the fileOffset is at the end of the file.  This means we have read all the data from the file
	BOOL result = (fileOffset == fileLength);
	
	return result;
}

/*
    Returns the filePath as string
    returns NSString
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
	// if the file descriptor is not null 
	if (fileFD != NULL_FD)
	{
		// close the file handle
		close(fileFD);
	}
	
	if (buffer)
    {
		free(buffer);
	}
    
	[filePath release];
	[super dealloc];
}

@end
