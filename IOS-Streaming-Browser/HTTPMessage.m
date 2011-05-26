#import "HTTPMessage.h"


@implementation HTTPMessage


/**
    returns self as an empty HTTP message
**/
- (id)initEmptyRequest
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateEmpty(NULL, YES);
	}
	return self;
}

/**
    Initialize a request HTTPMessage with a URL and version
    returns self (HTTPMessage)
 **/
- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateRequest(NULL, (CFStringRef)method, (CFURLRef)url, (CFStringRef)version);
	}
	return self;
}

/**
    Initialize a response HTTPMessage with a code, description, and version
 **/
- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateResponse(NULL, (CFIndex)code, (CFStringRef)description, (CFStringRef)version);
	}
	return self;
}

/**
    Standard deconstructor
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
    Returns whether can appendData to a message
 **/
- (BOOL)appendData:(NSData *)data
{
	return CFHTTPMessageAppendBytes(message, [data bytes], [data length]);
}

/**
    Whether the header is complete
 **/
- (BOOL)isHeaderComplete
{
	return CFHTTPMessageIsHeaderComplete(message);
}


/**
    Gets the version
 **/
- (NSString *)version
{
	return [NSMakeCollectable(CFHTTPMessageCopyVersion(message)) autorelease];
}


/**
    Gets the method
 **/
- (NSString *)method
{
	return [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(message)) autorelease];
}


/**
    Gets the url
 **/
- (NSURL *)url
{
	return [NSMakeCollectable(CFHTTPMessageCopyRequestURL(message)) autorelease];
}


/**
    Gets the status code
 **/
- (NSInteger)statusCode
{
	return (NSInteger)CFHTTPMessageGetResponseStatusCode(message);
}


/**
    Gets all the header fields
 **/
- (NSDictionary *)allHeaderFields
{
	return [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(message)) autorelease];
}


/**
    Gets a speicific header field
 **/
- (NSString *)headerField:(NSString *)headerField
{
	return [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)headerField)) autorelease];
}


/**
    Sets a header field
 **/
- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue
{
	CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)headerField, (CFStringRef)headerFieldValue);
}


/**
    Gets the message data
 **/
- (NSData *)messageData
{
    
	return [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
}


/**
    Gets the message body
 **/
- (NSData *)body
{
	return [NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease];
}


/**
    Sets the message body
 **/
- (void)setBody:(NSData *)body
{
	CFHTTPMessageSetBody(message, (CFDataRef)body);
}

@end
