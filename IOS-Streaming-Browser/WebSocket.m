#import "WebSocket.h"
#import "HTTPMessage.h"
#import "GCDAsyncSocket.h"
#import "DDNumber.h"
#import "DDData.h"


#define TIMEOUT_NONE          -1
#define TIMEOUT_REQUEST_BODY  10

#define TAG_HTTP_REQUEST_BODY      100
#define TAG_HTTP_RESPONSE_HEADERS  200
#define TAG_HTTP_RESPONSE_BODY     201

#define TAG_PREFIX                 300
#define TAG_MSG_PLUS_SUFFIX        301


@interface WebSocket (PrivateAPI)

/**
    Read the http request body
**/
- (void)readRequestBody;


/**
    Send a response body
**/
- (void)sendResponseBody;


/**
    Send the response headers
**/
- (void)sendResponseHeaders;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation WebSocket

/**
    Whether the HTTPRequest is a request for a web socket
    param HTTPMessage
    returns BOOL
**/
+ (BOOL)isWebSocketRequest:(HTTPMessage *)request
{
	// Request (Draft 75):
	// 
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// WebSocket-Protocol: sample
	// 
	// 
	// Request (Draft 76):
	//
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// Sec-WebSocket-Protocol: sample
	// Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5
	// Sec-WebSocket-Key2: 12998 5 Y3 1  .P00
	// 
	// ^n:ds[4U
	
	// Look for Upgrade: and Connection: headers.
	// If we find them, and they have the proper value,
	// we can safely assume this is a websocket request.
	
    // Gets the Upgrade header value from the request
	NSString *upgradeHeaderValue = [request headerField:@"Upgrade"];
    
    // Gets the Connection header value from the request
	NSString *connectionHeaderValue = [request headerField:@"Connection"];
	
    
    
	BOOL isWebSocket = YES;
	
    // Check if there is an upgrade and connection value.  If the header doesn't have an upgrade and connection header, then it is not a web-socket request
	if (!upgradeHeaderValue || !connectionHeaderValue) {
		isWebSocket = NO;
	} // Make sure the upgrade header value is 'WebSocket'
	else if (![upgradeHeaderValue caseInsensitiveCompare:@"WebSocket"] == NSOrderedSame) {
		isWebSocket = NO;
	} // Make sure the connection header value is 'Upgrade'
	else if (![connectionHeaderValue caseInsensitiveCompare:@"Upgrade"] == NSOrderedSame) {
		isWebSocket = NO;
	}
	
	// return that this request is a web socket request
	return isWebSocket;
}


/**
    Class method
    Whether the request is a version 76 of the web socket protocol
    param HTTPMessage
    returns BOOL
**/
+ (BOOL)isVersion76Request:(HTTPMessage *)request
{
    
    // Gets the header field for the websocket key1
	NSString *key1 = [request headerField:@"Sec-WebSocket-Key1"];
    
    // Gets the header field for the websocket key2
	NSString *key2 = [request headerField:@"Sec-WebSocket-Key2"];
	
    // Whether version 76 protocol
	BOOL isVersion76;
	
    // if there is no key1 or key2, then it is not version 76 compliant
	if (!key1 || !key2) {
		isVersion76 = NO;
	}
	else {
		isVersion76 = YES;
	}
	
	
	return isVersion76;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup and Teardown
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Creates the getters and setters for the delegate and the websocketQueue
@synthesize delegate;
@synthesize websocketQueue;


/**
    Initialize the web socket with an HTTP request and a socket
    param HTTPMessage
    param GCDAsyncSocket
    returns id
**/
- (id)initWithRequest:(HTTPMessage *)aRequest socket:(GCDAsyncSocket *)socket
{
	// If the http request is not nil
	if (aRequest == nil)
	{
		[self release];
		return nil;
	}
	
    // If the http request is nil
    
    
	if ((self = [super init]))
	{
		// Creates a new dispatch queue to which blocks may be submitted
		websocketQueue = dispatch_queue_create("WebSocket", NULL);
		request = [aRequest retain];
		
		asyncSocket = [socket retain];
        
        // Set this web socket instance as the asyncSocket delegate, and the websocketQueue as the delegate queue
		[asyncSocket setDelegate:self delegateQueue:websocketQueue];

		// Set the flag for whether the socket is open
		isOpen = NO;
        
        // Get whether this request is a version 76 web socket compliant
		isVersion76 = [[self class] isVersion76Request:request];
		
        // Creates a terminator
		term = [[NSData alloc] initWithBytes:"\xFF" length:1];
	}
	return self;
}


/**
    Standard deconstructor
 **/
- (void)dealloc
{
	// Decrement the reference count of a dispatch object.
	dispatch_release(websocketQueue);
	
	[request release];
	
	[asyncSocket setDelegate:nil delegateQueue:NULL];
	[asyncSocket disconnect];
	[asyncSocket release];
	
	[super dealloc];
}


/**
    Get the websocket delegate
    returns id
 **/
- (id)delegate
{
	__block id result = nil;
	
    // Submits a block for synchronous execution on the websocketQueue
	dispatch_sync(websocketQueue, ^{
        
		result = delegate;
        
	}); // END OF BLOCK
	
	return result;
}


/**
    Sets the websocket delegate
    param id
**/
- (void)setDelegate:(id)newDelegate
{
    // Submits a block for asynchronous execution on the websocketQueue
	dispatch_async(websocketQueue, ^{
        
		delegate = newDelegate;
        
	}); // END OF BLOCK
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Start and Stop
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Starting point for the WebSocket after it has been fully initialized (including subclasses).
 * This method is called by the HTTPConnection it is spawned from.
**/
- (void)start
{
	// This method is not exactly designed to be overriden.
	// Subclasses are encouraged to override the didOpen method instead.
	
    // Submits a block for asynchronous execution on the websocketQueue
	dispatch_async(websocketQueue, ^{
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
        // If the websocket is started
		if (isStarted) return;
        
        // Sets web socket flag to started
		isStarted = YES;
		
        // if the request is version 76 compliant
		if (isVersion76)
		{
            // Read the request body
			[self readRequestBody];
		}
		else // if the request is not version 76 compliant
		{
            // Set response headers
			[self sendResponseHeaders];
            
            // if web socket has been opened
			[self didOpen];
		}
		
		[pool release];
	}); // END OF BLOCK
}

/**
 * This method is called by the HTTPServer if it is asked to stop.
 * The server, in turn, invokes stop on each WebSocket instance.
**/
- (void)stop
{
	// This method is not exactly designed to be overriden.
	// Subclasses are encouraged to override the didClose method instead.
	
    // Submits a block for asynchronous execution on the websocketQueue
	dispatch_async(websocketQueue, ^{
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[asyncSocket disconnect];
		
		[pool release];
        
	}); // END OF BLOCK
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTP Response
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Read the request body from the socket
**/
- (void)readRequestBody
{
	
	NSAssert(isVersion76, @"WebSocket version 75 doesn't contain a request body");
	
    // reads data from the socket
	[asyncSocket readDataToLength:8 withTimeout:TIMEOUT_NONE tag:TAG_HTTP_REQUEST_BODY];
}

/**
    Get the header field Origin value
    returns NSString
**/
- (NSString *)originResponseHeaderValue
{
	
    // The |Origin| field is used to protect against unauthorized cross-origin use of a WebSocket server by scripts using the |WebSocket| API in a Web browser.  The server specifies which origin it is willing to receive requests from by including a |Sec-WebSocket-Origin| field with that origin.  If multiple origins are authorized, the server echoes the value in the |Origin| field of the client's handshake.
    
    // Gets the Origin field
	NSString *origin = [request headerField:@"Origin"];
	
    // Check if the origin header field is nil
	if (origin == nil)
	{
        // Get the port
		NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
		
        // Returns localhost as the origin
		return [NSString stringWithFormat:@"http://localhost:%@", port];
	}
	else // if the origin header field is not nil
	{
        // Returns the origin of the request
		return origin;
	}
}

/**
    Get the value for the 'Host' field in the request header
    returns NSString
**/
- (NSString *)locationResponseHeaderValue
{
	
	NSString *location;
    
    // Gets the value for the host
	NSString *host = [request headerField:@"Host"];
	
    // Get the request url as a string
	NSString *requestUri = [[request url] relativeString];
	
    // If the host from the request header is nil
	if (host == nil)
	{
        
		NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
		
		location = [NSString stringWithFormat:@"ws://localhost:%@%@", port, requestUri];
	}
	else // If the host from the request header is not nil
	{
		location = [NSString stringWithFormat:@"ws://%@%@", host, requestUri];
	}
	
	return location;
}


/**
    Sends the response readers
**/
- (void)sendResponseHeaders
{
	
	// Request (Draft 75):
	// 
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// WebSocket-Protocol: sample
	// 
	// 
	// Request (Draft 76):
	//
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// Sec-WebSocket-Protocol: sample
	// Sec-WebSocket-Key2: 12998 5 Y3 1  .P00
	// Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5
	// 
	// ^n:ds[4U

	
	// Response (Draft 75):
	// 
	// HTTP/1.1 101 Web Socket Protocol Handshake
	// Upgrade: WebSocket
	// Connection: Upgrade
	// WebSocket-Origin: http://example.com
	// WebSocket-Location: ws://example.com/demo
	// WebSocket-Protocol: sample
	// 
	// 
	// Response (Draft 76):
	//
	// HTTP/1.1 101 WebSocket Protocol Handshake
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Sec-WebSocket-Origin: http://example.com
	// Sec-WebSocket-Location: ws://example.com/demo
	// Sec-WebSocket-Protocol: sample
	// 
	// 8jKS'y:G*Co,Wxa-

	// Create a web socket response
	HTTPMessage *wsResponse = [[HTTPMessage alloc] initResponseWithStatusCode:101
                description:@"Web Socket Protocol Handshake"	                                                                  version:HTTPVersion1_1];
	
    // Set the web-socket response header fields
	[wsResponse setHeaderField:@"Upgrade" value:@"WebSocket"];
	[wsResponse setHeaderField:@"Connection" value:@"Upgrade"];
	
	// Note: It appears that WebSocket-Origin and WebSocket-Location
	// are required for Google's Chrome implementation to work properly.
	// 
	// If we don't send either header, Chrome will never report the WebSocket as open.
	// If we only send one of the two, Chrome will immediately close the WebSocket.
	// 
	// In addition to this it appears that Chrome's implementation is very picky of the values of the headers.
	// They have to match exactly with what Chrome sent us or it will close the WebSocket.
	
	NSString *originValue = [self originResponseHeaderValue];
	NSString *locationValue = [self locationResponseHeaderValue];
	
	NSString *originField = isVersion76 ? @"Sec-WebSocket-Origin" : @"WebSocket-Origin";
    
	NSString *locationField = isVersion76 ? @"Sec-WebSocket-Location" : @"WebSocket-Location";
	
	[wsResponse setHeaderField:originField value:originValue];
	[wsResponse setHeaderField:locationField value:locationValue];
	
    
	NSData *responseHeaders = [wsResponse messageData];
	
	[wsResponse release];
	
	// Write the response to the socket
	[asyncSocket writeData:responseHeaders withTimeout:TIMEOUT_NONE tag:TAG_HTTP_RESPONSE_HEADERS];
}


/**
    Process the web socket key values from the request
    param NSString
    returns NSData
**/
- (NSData *)processKey:(NSString *)key
{
	
	unichar c; // character
	NSUInteger i; // index of the character in the key
    
    // Gets the key length
	NSUInteger length = [key length];
	
	// Concatenate the digits into a string,
	// and count the number of spaces.
	
	NSMutableString *numStr = [NSMutableString stringWithCapacity:10];
	long long numSpaces = 0;
	
    // enumerates through each character in the key
	for (i = 0; i < length; i++)
	{
        // Gets the character at a specific index
		c = [key characterAtIndex:i];
		
        // Check if a number
		if (c >= '0' && c <= '9')
		{
            
			[numStr appendFormat:@"%C", c];
		}
        // Check if a space
		else if (c == ' ')
		{
            // Counter for the number of spaces in the key
			numSpaces++;
		}
	}
	
    // converts a string value to a long
	long long num = strtoll([numStr UTF8String], NULL, 10);
	
    
	long long resultHostNum;
	
    // Check the counter to see if there are any spaces in the key
	if (numSpaces == 0)
    {
		resultHostNum = 0;
	}else{ // if there are spaces in the key
		resultHostNum = num / numSpaces;
	}
	
	// Convert result to 4 byte big-endian (network byte order)
	// and then convert to raw data.
	
	UInt32 result = OSSwapHostToBigInt32((uint32_t)resultHostNum);
	
    // &result is the address
	return [NSData dataWithBytes:&result length:4];
}


/**
    Sends the response body
    param NSData
**/
- (void)sendResponseBody:(NSData *)d3
{
	
	NSAssert(isVersion76, @"WebSocket version 75 doesn't contain a response body");
	NSAssert([d3 length] == 8, @"Invalid requestBody length");
	
    // Sets the key values in the header
	NSString *key1 = [request headerField:@"Sec-WebSocket-Key1"];
	NSString *key2 = [request headerField:@"Sec-WebSocket-Key2"];
	
	NSData *d1 = [self processKey:key1];
	NSData *d2 = [self processKey:key2];
	
	// Concatenated d1, d2 & d3
	
	NSMutableData *d0 = [NSMutableData dataWithCapacity:(4+4+8)];
    
	[d0 appendData:d1];
	[d0 appendData:d2];
	[d0 appendData:d3];
	
	// Hash the data using MD5
	
	NSData *responseBody = [d0 md5Digest];
	
    // Writes the data to the socket
	[asyncSocket writeData:responseBody withTimeout:TIMEOUT_NONE tag:TAG_HTTP_RESPONSE_BODY];
	

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Functionality
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    If the web socket has been opened
**/
- (void)didOpen
{
	
	// Override me to perform any custom actions once the WebSocket has been opened.
	// This method is invoked on the websocketQueue.
	// 
	// Don't forget to invoke [super didOpen] in your method.
	
	// Start reading for messages
	[asyncSocket readDataToLength:1 withTimeout:TIMEOUT_NONE tag:TAG_PREFIX];
	
	// Notify delegate that the web socket did open
	if ([delegate respondsToSelector:@selector(webSocketDidOpen:)])
	{
        
		[delegate webSocketDidOpen:self];
	}
}

/**
    Sends a message
    param NSString
**/
- (void)sendMessage:(NSString *)msg
{
	// Encodes the message
	NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
	
    // Puts message into a NSMutableData
	NSMutableData *data = [NSMutableData dataWithCapacity:([msgData length] + 2)];
	
    
	[data appendBytes:"\x00" length:1];  // NULL 0x00

	[data appendData:msgData];

    
	[data appendBytes:"\xFF" length:1];  // End of transmission 0x04

	
	// Remember: GCDAsyncSocket is thread-safe
	
    // Writes data to the socket with no timeout or tag
	[asyncSocket writeData:data withTimeout:TIMEOUT_NONE tag:0];
}

/**
    Did receive an incoming message
    param NSString
**/
- (void)didReceiveMessage:(NSString *)msg
{
	
	// Override me to process incoming messages.
	// This method is invoked on the websocketQueue.
	// 
	// For completeness, you should invoke [super didReceiveMessage:msg] in your method.
	
	// Notify delegate that it did receive a message
	if ([delegate respondsToSelector:@selector(webSocket:didReceiveMessage:)])
	{
        // Notify the socket it received a message
		[delegate webSocket:self didReceiveMessage:msg];
	}
}


/**
    Notifiy delegate that websocket did close
**/
- (void)didClose
{
	
	// Override me to perform any cleanup when the socket is closed
	// This method is invoked on the websocketQueue.
	// 
	// Don't forget to invoke [super didClose] at the end of your method.
	
	// Notify delegate that the websocket did close
	if ([delegate respondsToSelector:@selector(webSocketDidClose:)])
	{
        
		[delegate webSocketDidClose:self];
	}
	
	// Notify HTTPServer
	[[NSNotificationCenter defaultCenter] postNotificationName:WebSocketDidDieNotification object:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Socket did read the request with a specific tag
    param GCDAsyncSocket
    param NSData
    param long
**/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	// If a request body
	if (tag == TAG_HTTP_REQUEST_BODY) // value is 100
	{
        // Sends the response headers
		[self sendResponseHeaders];
        
        // Send the response body
		[self sendResponseBody:data];
        
        // Web socket did open
		[self didOpen];
	}
    // If TAG is not the HTTP request body, then check if a prefix
	else if (tag == TAG_PREFIX) // value is 300
	{
        // Gets the number of bytes in the data which was read from the socket
		UInt8 *pFrame = (UInt8 *)[data bytes];
        
        
		UInt8 frame = *pFrame;
		
        
		if (frame <= 0x7F) // the number 127
		{
			[asyncSocket readDataToData:term withTimeout:TIMEOUT_NONE tag:TAG_MSG_PLUS_SUFFIX]; // suffix value is 301
		}
		else // frame is not 127
		{
			// Unsupported frame type
			[self didClose];
		}
	}
	else  // If not the HTTP_REQUEST_BODY or TAG_PREFIX
	{
		NSUInteger msgLength = [data length] - 1; // Excluding ending 0xFF frame (number 255)
		
        // Creates a UTF8 encoded string
		NSString *msg = [[NSString alloc] initWithBytes:[data bytes] length:msgLength encoding:NSUTF8StringEncoding];
		
        // Did receive an incoming message
		[self didReceiveMessage:msg];
		
		[msg release];
		
		// Read next message
		[asyncSocket readDataToLength:1 withTimeout:TIMEOUT_NONE tag:TAG_PREFIX]; // tag prefix value is 300
	}
}

/**
    If the web socket did disconnect
**/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
	// Web socket did close
	[self didClose];
}

@end
