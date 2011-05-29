#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class HTTPMessage;
@class HTTPServer;
@class WebSocket;
@protocol HTTPResponse;


#define HTTPConnectionDidDieNotification  @"HTTPConnectionDidDie"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConfig : NSObject
{

	HTTPServer *server; // The HTTPServer which is handling the connection
	NSString *documentRoot; // The document root for the server
	dispatch_queue_t queue;  // The dispatch queue for requests
}


/*
    Initializes the HTTPconnection with a server and document root
*/
- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot;

/*
    Initializes the HTTPConnection with a server, document root, and 
    dispatch queue
*/
- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;


// Sets the properties for the instance attributes/variables
@property (nonatomic, readonly) HTTPServer *server;
@property (nonatomic, readonly) NSString *documentRoot;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConnection : NSObject
{
	dispatch_queue_t connectionQueue; // queue with all the connections
	GCDAsyncSocket *asyncSocket;  // Handles each request one at a time in order
	HTTPConfig *config;  // HTTP server configuration
	
	BOOL started;  // whether connection started
	
	HTTPMessage *request;  // the request 
	unsigned int numHeaderLines;  // number of header lines
	
	BOOL sentResponseHeaders;   // whether sent response headers
	
	NSString *nonce;  // A nonce is a  server-specified string uniquely generated for each 401 response.
    
    
	long lastNC; // the last nonce
	
	NSObject<HTTPResponse> *httpResponse; // the response
	
	NSMutableArray *ranges;
	NSMutableArray *ranges_headers;
	NSString *ranges_boundry;
	int rangeIndex;
	
	UInt64 requestContentLength;  // the request content length
	UInt64 requestContentLengthReceived;
	
	NSMutableArray *responseDataSizes;
}


/*
    Returns HTTPConnection
    param GCDAsyncSocket
    param HTTPConfig
    returns id
*/
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig;

/**
 * Starting point for the HTTP connection after it has been fully initialized (including subclasses).
 * This method is called by the HTTP server.
 **/
- (void)start;

/**
 * This method is called by the HTTPServer if it is asked to stop.
 * The server, in turn, invokes stop on each HTTPConnection instance.
 **/
- (void)stop;

/**
 * Starting point for the HTTP connection.
 **/
- (void)startConnection;

/**
    Returns whether or not the server will accept messages of a given method at a particular URI.
    param NSString
    param NSString
    returns BOOL
**/
- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path;

/**
    Returns whether or not the server expects a body from the given method.
 
    In other words, should the server expect a content-length header and associated body from this method.
    This would be true in the case of a POST, where the client is sending data, or for something like PUT where the client is supposed to be uploading a file.
 
    param NSString
    param NSString
    returns BOOL
**/
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path;

/**
 * Returns whether or not the server is configured to be a secure server.
 * In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
 * This is the equivalent of having an https server, where it is assumed that all connections must be secure.
 * If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server
 * would need to be run on a separate port in order to support unsecure connections.
 * 
 * Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
 **/
- (BOOL)isSecureServer;

/**
 * This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
 **/
- (NSArray *)sslIdentityAndCertificates;

/**
    Returns whether or not the requested resource is password protected.
    In this generic implementation, nothing is password protected.
    param NSString
    returns BOOL
**/
- (BOOL)isPasswordProtected:(NSString *)path;

/**
 * Returns whether or not the authentication challenge should use digest access authentication.
 * The alternative is basic authentication.
 * 
 * If at all possible, digest access authentication should be used because it's more secure.
 * Basic authentication sends passwords in the clear and should be avoided unless using SSL/TLS.
 **/
- (BOOL)useDigestAccessAuthentication;

/**
    Returns the authentication realm.
    In this generic implmentation, a default realm is used for the entire server.
    returns NSString
**/
- (NSString *)realm;

/**
    Returns the password for the given username.
    param NSString
    returns NSString
**/
- (NSString *)passwordForUser:(NSString *)username;

/**
 * Parses the given query string.
 * 
 * For example, if the query is "q=John%20Mayer%20Trio&num=50"
 * then this method would return the following dictionary:
 * { 
 *   q = "John Mayer Trio" 
 *   num = "50" 
 * }
 **/
- (NSDictionary *)parseParams:(NSString *)query;

/** 
 * Parses the query variables in the request URI. 
 * 
 * For example, if the request URI was "/search.html?q=John%20Mayer%20Trio&num=50" 
 * then this method would return the following dictionary: 
 * { 
 *   q = "John Mayer Trio" 
 *   num = "50" 
 * } 
 **/ 
- (NSDictionary *)parseGetParams;

/*
    Returns the URL as a string for the HTTPMessage
 */
- (NSString *)requestURI;

/**
 * Returns an array of possible index pages.
 * For example: {"index.html", "index.htm"}
 **/
- (NSArray *)directoryIndexFileNames;

/**
    Converts relative URI path into full file-system path.
    param NSString
    returns NSString
**/
- (NSString *)filePathForURI:(NSString *)path;

/**
 * This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResponse is a wrapper for an NSData object, and may be used to send a custom response.
 **/
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path;

/*
    param NSString
    returns WebSocket
*/
- (WebSocket *)webSocketForURI:(NSString *)path;

/**
    This method is called after receiving all HTTP headers, but before reading any of the request body.
    param UInt64
**/
- (void)prepareForBodyWithSize:(UInt64)contentLength;

/**
    This method is called to handle data read from a POST / PUT.
    The given data is part of the request body.
    param NSData
**/
- (void)processDataChunk:(NSData *)postDataChunk;

/**
    Called if the HTML version is other than what is supported
    param NSString
**/
- (void)handleVersionNotSupported:(NSString *)version;

/**
    Called if the authentication information was required and absent, or if authentication failed.
**/
- (void)handleAuthenticationFailed;

/**
    Called if we're unable to find the requested resource.
**/
- (void)handleResourceNotFound;

/**
 * Called if we receive some sort of malformed HTTP request.
 * The data parameter is the invalid HTTP header line, including CRLF, as read from GCDAsyncSocket.
 * The data parameter may also be nil if the request as a whole was invalid, such as a POST with no Content-Length.
 **/
- (void)handleInvalidRequest:(NSData *)data;

/**
 * Called if we receive a HTTP request with a method other than GET or HEAD.
 **/
- (void)handleUnknownMethod:(NSString *)method;

/**
    This method is called immediately prior to sending the response headers.
    This method adds standard header fields, and then converts the response to an NSData object.
    param HTTPMessage
    returns NSData
**/
- (NSData *)preprocessResponse:(HTTPMessage *)response;

/**
 * This method is called immediately prior to sending the response headers (for an error).
 * This method adds standard header fields, and then converts the response to an NSData object.
 **/
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response;

/*
    Returns whether the HTTPConnection should die
    returns BOOL
*/
- (BOOL)shouldDie;

/*
    Closes the connection
*/
- (void)die;

@end


@interface HTTPConnection (AsynchronousHTTPResponse)

/*
    param NSObject with HTTPResponse protocol
*/
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;

/*
    param NSObject with HTTPResponse protocl
*/
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender;

@end
