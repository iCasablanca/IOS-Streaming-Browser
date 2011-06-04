/**
 * The HTTPMessage class is a simple Objective-C wrapper around Apple's CFHTTPMessage class.
**/

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif

#define HTTPVersion1_0  ((NSString *)kCFHTTPVersion1_0)
#define HTTPVersion1_1  ((NSString *)kCFHTTPVersion1_1)


@interface HTTPMessage : NSObject
{
    /**
        message can be request or response
    **/
	CFHTTPMessageRef message; 
}


/**
    Initialize an empty HTTP message
    returns id
**/
- (id)initEmptyRequest;

/**
    Initialize a request HTTPMessage with a URL and version
    param NSString
    param NSURL
    param NSString
    returns id - self (HTTPMessage)
**/
- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version;

/**
     Initialize a response HTTPMessage with a code, description, and version
    param NSString
    param NSString
    param NSString
    returns id 
**/
- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version;

/**
    Returns whether can appendData with data
    param NSData
**/
- (BOOL)appendData:(NSData *)data;

/**
    Returns whether the header is complete
**/
- (BOOL)isHeaderComplete;

/**
    Gets the version
**/
- (NSString *)version;

/**
    Gets the method
**/
- (NSString *)method;

/**
    Gets the url
**/
- (NSURL *)url;

/**
    Gets the status code
**/
- (NSInteger)statusCode;

/**
    Gets all the header fields wrapped in an NSDictionary object
**/
- (NSDictionary *)allHeaderFields;

/**
    Returns the header field as a string
    param NSString
    returns NSString
**/
- (NSString *)headerField:(NSString *)headerField;

/**
    Sets the header field
    param NSString
    param NSString
**/
- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue;

/**
    Returns the message data
    returns NSData
**/
- (NSData *)messageData;

/**
    Returns the body data
    returns NSData
**/
- (NSData *)body;

/**
    Set the body data
    param NSData
**/
- (void)setBody:(NSData *)body;

@end
