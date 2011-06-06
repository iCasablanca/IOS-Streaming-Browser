#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;

// Implements HTTPResponse protocol
@interface HTTPFileResponse : NSObject <HTTPResponse>
{
    
    /**
        @brief HTTP connection
    **/
	HTTPConnection *connection;
	
    
    /**
        @brief The path to the file
    **/
	NSString *filePath;  
    
    /**
        @brief The length of the file
    **/
	UInt64 fileLength;  
    
    /**
        @brief The file offset
    **/
	UInt64 fileOffset;  
	
    /**
        @brief Whether the file response has been aborted
    **/
	BOOL aborted; 
	
    /**
        @brief The file descriptor
    **/
	int fileFD; 
    
    /**
        @brief The file buffer
    **/
	void *buffer;
    
    /**
        @brief The buffer size
    **/
	NSUInteger bufferSize;  
}

/**
    @brief Initialize the HTTPFile response with a filepath and connection
    @param NSSTring
    @param HTTPConnection
    @return id
**/
- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;

/**
    @brief Gets the file path
    @return NSString
**/
- (NSString *)filePath;

@end
