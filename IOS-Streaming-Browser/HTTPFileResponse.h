#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;

// Implements HTTPResponse protocol
@interface HTTPFileResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
	
	NSString *filePath;
	UInt64 fileLength;
	UInt64 fileOffset;
	
	BOOL aborted;
	
	int fileFD;
	void *buffer;
	NSUInteger bufferSize;
}

/*
 
 */
- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;

/*
 
 */
- (NSString *)filePath;

@end
