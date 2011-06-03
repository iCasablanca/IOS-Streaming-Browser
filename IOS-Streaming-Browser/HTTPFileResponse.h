#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;

// Implements HTTPResponse protocol
@interface HTTPFileResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
	
	NSString *filePath;  // the path to the file
	UInt64 fileLength;  // the length of the file
	UInt64 fileOffset;  // the file offset
	
	BOOL aborted; // whether the file response has been aborted
	
	int fileFD; // the file descriptor
	void *buffer;  // the file buffer
	NSUInteger bufferSize;  // the buffer size
}

/**
    Initialize the HTTPFile response with a filepath and connection
    param NSSTring
    param HTTPConnection
    returns id
**/
- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;

/**
    Gets the file path
    returns NSString
**/
- (NSString *)filePath;

@end
