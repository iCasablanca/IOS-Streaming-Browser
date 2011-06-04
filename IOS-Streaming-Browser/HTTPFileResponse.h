#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;

// Implements HTTPResponse protocol
@interface HTTPFileResponse : NSObject <HTTPResponse>
{
    
    /**
     
    **/
	HTTPConnection *connection;
	
    
    /**
        The path to the file
    **/
	NSString *filePath;  
    
    /**
        The length of the file
    **/
	UInt64 fileLength;  
    
    /**
        The file offset
    **/
	UInt64 fileOffset;  
	
    /**
        Whether the file response has been aborted
    **/
	BOOL aborted; 
	
    /**
        The file descriptor
    **/
	int fileFD; 
    
    /**
        The file buffer
    **/
	void *buffer;
    
    /**
        The buffer size
    **/
	NSUInteger bufferSize;  
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
