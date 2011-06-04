#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;

/**
 * This is an asynchronous version of HTTPFileResponse.
 * It reads data from the given file asynchronously via GCD.
 * 
 * It may be overriden to allow custom post-processing of the data that has been read from the file.
 * An example of this is the HTTPDynamicFileResponse class.
**/

// Implements HTTPResponse protocol
@interface HTTPAsyncFileResponse : NSObject <HTTPResponse>
{	
    
    /**
     
    **/
	HTTPConnection *connection;
	
    /**
      the file path
    **/
	NSString *filePath; 
    
    /**
      the file length
    **/
	UInt64 fileLength;  
    
    /**
      File offset as pertains to data given to connection
    **/
	UInt64 fileOffset;  
    
    /**
      File offset as pertains to data read from file (but maybe not returned to connection)
    **/
	UInt64 readOffset;  
	
    /**
      whether the file response is aborted
    **/
	BOOL aborted;  
	
    
    /**
      the data from the file
    **/
	NSData *data;  
	
    
    /**
      the file descriptior (i.e. file handle)
    **/
	int fileFD; 
    
    
    /**
        The read buffer.  This is for holding the data read from a file, and waiting to be sent to the host
    **/
	void *readBuffer; 
    
    /**
        Malloc'd size of readBuffer
    **/
	NSUInteger readBufferSize;     
    
    /**
      Offset within readBuffer where the end of existing data is
    **/
	NSUInteger readBufferOffset;   
    
    /**
        The read request length.  
    **/
	NSUInteger readRequestLength; 
    
    /**
        The read queue
    **/
	dispatch_queue_t readQueue;  
    
    /**
        The read source
    **/
	dispatch_source_t readSource; 
    
    /**
        Whether read source is suspended
    **/
	BOOL readSourceSuspended;  
}

/**
        Initialize the HTTPAsyncFileResponse with a file path and HTTPConnection
        param NSString
        param HTTPConnection
        returns id
**/
- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;

/**
    returns filePath as an NSString
**/
- (NSString *)filePath;

@end

/**
 * Explanation of Variables (excluding those that are obvious)
 * 
 * fileOffset
 *   This is the number of bytes that have been returned to the connection via the readDataOfLength method.
 *   If 1KB of data has been read from the file, but none of that data has yet been returned to the connection,
 *   then the fileOffset variable remains at zero.
 *   This variable is used in the calculation of the isDone method.
 *   Only after all data has been returned to the connection are we actually done.
 * 
 * readOffset
 *   Represents the offset of the file descriptor.
 *   In other words, the file position indidcator for our read stream.
 *   It might be easy to think of it as the total number of bytes that have been read from the file.
 *   However, this isn't entirely accurate, as the setOffset: method may have caused us to
 *   jump ahead in the file (lseek).
 * 
 * readBuffer
 *   Malloc'd buffer to hold data read from the file.
 * 
 * readBufferSize
 *   Total allocation size of malloc'd buffer.
 * 
 * readBufferOffset
 *   Represents the position in the readBuffer where we should store new bytes.
 * 
 * readRequestLength
 *   The total number of bytes that were requested from the connection.
 *   It's OK if we return a lesser number of bytes to the connection.
 *   It's NOT OK if we return a greater number of bytes to the connection.
 *   Doing so would disrupt proper support for range requests.
 *   If, however, the response is chunked then we don't need to worry about this.
 *   Chunked responses inheritly don't support range requests.
**/