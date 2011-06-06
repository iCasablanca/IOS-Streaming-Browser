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

/**
    HTTPMessage
**/
@interface HTTPMessage : NSObject
{
    /**
        Message can be request or response
        @brief Core Foundation opaque type representing an HTTP message
    **/
	CFHTTPMessageRef message; 
}


/**
    @brief Initialize an empty HTTP message
    @return id
**/
- (id)initEmptyRequest;

/**
    @brief Initialize a request HTTPMessage with a URL and version
    @param NSString
    @param NSURL
    @param NSString
    @return id - self (HTTPMessage)
**/
- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version;

/**
     @brief Initialize a response HTTPMessage with a code, description, and version
    @param NSString
    @param NSString
    @param NSString
    @return id 
**/
- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version;

/**
    @brief Returns whether can appendData with data
    @param NSData
    @return BOOL
**/
- (BOOL)appendData:(NSData *)data;

/**
    @brief Returns whether the header is complete
    @return BOOL
**/
- (BOOL)isHeaderComplete;

/**
    @brief Gets the version
    @return NSString
**/
- (NSString *)version;

/**
    @brief Gets the method
    @return NSString
**/
- (NSString *)method;

/**
    @brief Gets the url
    @return NSURL
**/
- (NSURL *)url;

/**
    @brief Gets the status code
    @return NSInteger
**/
- (NSInteger)statusCode;

/**
    @brief Gets all the header fields wrapped in an NSDictionary object
    @return NSDictionary
**/
- (NSDictionary *)allHeaderFields;

/**
    @brief Returns the header field as a string
    @param NSString
    @return NSString
**/
- (NSString *)headerField:(NSString *)headerField;

/**
    @brief Sets the header field
    @param NSString
    @param NSString
    @return void
**/
- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue;

/**
    @brief Returns the message data
    @return NSData
**/
- (NSData *)messageData;

/**
    @brief Returns the body data
    @return NSData
**/
- (NSData *)body;

/**
    @brief Set the body data
    @param NSData
    @return void
**/
- (void)setBody:(NSData *)body;

@end
