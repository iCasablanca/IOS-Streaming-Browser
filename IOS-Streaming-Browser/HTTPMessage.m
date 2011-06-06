#import "HTTPMessage.h"


@implementation HTTPMessage


/**
    @brief Initialize the HTTPMessage with an empty message
    @return id (self as an empty HTTP message)
**/
- (id)initEmptyRequest
{
	if ((self = [super init]))
	{
        // Create an empty HTTP message
		message = CFHTTPMessageCreateEmpty(NULL, YES);
	}
	return self;
}

/**
    @brief Initialize a request HTTPMessage with a URL and version
    @param NSString
    @param NSURL
    @param NSString
    @return id self (HTTPMessage)
 **/
- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version
{
	if ((self = [super init]))
	{
        // Create an http message with a method, url, and version
		message = CFHTTPMessageCreateRequest(NULL, (CFStringRef)method, (CFURLRef)url, (CFStringRef)version);
	}
	return self;
}

/**
    @brief Initialize a response HTTPMessage with a code, description, and version
    @param NSSInteger
    @param NSString
    @param NSSTring
    @return id
**/
- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version
{
	if ((self = [super init]))
	{
        // Create an empty HTTP message with a code, description and version 
		message = CFHTTPMessageCreateResponse(NULL, (CFIndex)code, (CFStringRef)description, (CFStringRef)version);
	}
	return self;
}

/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{
	if (message)
	{
		CFRelease(message);
	}
	[super dealloc];
}

/**
    @brief Returns whether can appendData to a message
    @param NSData
    @return BOOL
**/
- (BOOL)appendData:(NSData *)data
{
    // Append date to the HTTP message
	return CFHTTPMessageAppendBytes(message, [data bytes], [data length]);
}

/**
    @brief Whether the header is complete
    @return BOOL
**/
- (BOOL)isHeaderComplete
{
    // Test whether the http message header is complete
	return CFHTTPMessageIsHeaderComplete(message);
}


/**
    @brief Gets the version
    @return NSString
**/
- (NSString *)version
{
	return [NSMakeCollectable(CFHTTPMessageCopyVersion(message)) autorelease];
}


/**
    @brief Gets the method
    @return NSSTring
**/
- (NSString *)method
{
    
	return [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(message)) autorelease];
}


/**
    @brief Gets the url
    @return NSURL
**/
- (NSURL *)url
{
	return [NSMakeCollectable(CFHTTPMessageCopyRequestURL(message)) autorelease];
}


/**
    @brief Gets the status code
    @return NSInteger
**/
- (NSInteger)statusCode
{
    // Returns the status code for the response as an integer
	return (NSInteger)CFHTTPMessageGetResponseStatusCode(message);
}


/**
    @brief Gets a CFDictionary containing all of the header fields.
    @return NSDictionary
**/
- (NSDictionary *)allHeaderFields
{
    // Returns a CFDictionary containing all of the header fields.
	return [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(message)) autorelease];
}


/**
    @brief Gets a speicific header field
    @param NSString
    @return NSString
**/
- (NSString *)headerField:(NSString *)headerField
{
	return [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)headerField)) autorelease];
}


/**
    @brief Sets a header field
    @param NSString
    @param NSString
    @return void
**/
- (void)setHeaderField:(NSString *)headerField 
                 value:(NSString *)headerFieldValue
{
    
	CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)headerField, (CFStringRef)headerFieldValue);
}


/**
    @brief Gets the message data
    @return NSData
**/
- (NSData *)messageData
{
    
	return [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
}


/**
    @brief Gets the message body
    @return NSData
**/
- (NSData *)body
{
	return [NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease];
}


/**
    @brief Sets the message body
    @param NSData
    @return void
**/
- (void)setBody:(NSData *)body
{
    // Set the message body
	CFHTTPMessageSetBody(message, (CFDataRef)body);
}

@end
