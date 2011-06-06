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

    /**
        @brief The HTTPServer which is handling the connection
    **/
	HTTPServer *server;
    
    /**
        @brief The document root for the server
    **/
	NSString *documentRoot; 
    
    /**
        @brief The dispatch queue for requests
    **/
	dispatch_queue_t queue;  
}


/**
    @brief Initializes the HTTPconnection with a server and document root
    @param HTTPServer
    @param NSString
    @return id (self)
**/
- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot;

/**
    @brief Initializes the HTTPConnection with a server, document root, and  dispatch queue
    @param HTTPServer
    @param NSString
    @param dispatch_queue
    @return id (self)
**/
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
    
    /**
        @brief Queue with all the connections
    **/
	dispatch_queue_t connectionQueue; 

    /**
        @brief Handles each request one at a time in order
    **/
    GCDAsyncSocket *asyncSocket;  
    
    /**
        @brief HTTP server configuration
    **/
	HTTPConfig *config;  
    
    /**
        @brief Flag for whether the connection started
    **/
	BOOL started;  
	
    /**
        @brief The http request from the host 
    **/
	HTTPMessage *request;  
    
    /**
        @brief Number of header lines
    **/
	unsigned int numHeaderLines;  
	
    /**
        @brief Flag for whether sent response headers to the host
    **/
	BOOL sentResponseHeaders;   
	
    
    /**
        @brief A nonce is a  server-specified string uniquely generated for each 401 response.
    **/
	NSString *nonce;  
    
    /**
        @brief The last nonce
    **/
	long lastNC; 
	
    /**
        @brief The http response sent to the host
    **/
	NSObject<HTTPResponse> *httpResponse; 
	
    /**
        @brief Mutable array for the response ranges
    **/
	NSMutableArray *ranges; 

    /**
        @brief Mutable array for the response range headers
    **/
	NSMutableArray *ranges_headers; 
    
    
    /**
        @brief The response ranges boundary
    **/
	NSString *ranges_boundry; 
    
    /**
        @brief The range index
    **/
	int rangeIndex;
	
    /**
        @brief The length of the http request from the host
    **/
    UInt64 requestContentLength;
    
    /**
        @brief The number of bytes received from the host
    **/
	UInt64 requestContentLengthReceived;
	
    /**
        @brief HTTP response data sizes
    **/
	NSMutableArray *responseDataSizes; 
}


/**
    @brief Returns HTTPConnection
    @param GCDAsyncSocket
    @param HTTPConfig
    @return id
**/
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig;

/**
 * Starting point for the HTTP connection after it has been fully initialized (including subclasses).
 * This method is called by the HTTP server.
 **/
- (void)start;

/**
    @brief This method is called by the HTTPServer if it is asked to stop.
    The server, in turn, invokes stop on each HTTPConnection instance.
    @return void
**/
- (void)stop;


/**
    @brief Starting point for the HTTP connection.
    @return void
**/
- (void)startConnection;

/**
    @brief Returns whether or not the server will accept messages of a given method at a particular URI.
    @param NSString
    @param NSString
    @return BOOL
**/
- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path;

/**
    @brief Returns whether or not the server expects a body from the given method.
 
    In other words, should the server expect a content-length header and associated body from this method.
    This would be true in the case of a POST, where the client is sending data, or for something like PUT where the client is supposed to be uploading a file.
 
    @param NSString
    @param NSString
    @return BOOL
**/
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path;

/**
    @brief Returns whether or not the server is configured to be a secure server.
 
    In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
    This is the equivalent of having an https server, where it is assumed that all connections must be secure.
    If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server would need to be run on a separate port in order to support unsecure connections.
 
    Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
    @return BOOL
**/
- (BOOL)isSecureServer;

/**
    @brief This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
    It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
    @return NSArray
**/
- (NSArray *)sslIdentityAndCertificates;

/**
    @brief Returns whether or not the requested resource is password protected.
    In this generic implementation, nothing is password protected.
    param NSString
    @return BOOL
**/
- (BOOL)isPasswordProtected:(NSString *)path;

/**
    @brief Returns whether or not the authentication challenge should use digest access authentication.
 * The alternative is basic authentication.
 * 
 * If at all possible, digest access authentication should be used because it's more secure.
 * Basic authentication sends passwords in the clear and should be avoided unless using SSL/TLS.
    @return BOOL
**/
- (BOOL)useDigestAccessAuthentication;

/**
    @brief Returns the authentication realm.
    In this generic implmentation, a default realm is used for the entire server.
    @return NSString
**/
- (NSString *)realm;

/**
    @brief Returns the password for the given username.
    @param NSString
    @return NSString
**/
- (NSString *)passwordForUser:(NSString *)username;

/**
    @brief Parses the given query string.
 * 
 * For example, if the query is "q=John%20Mayer%20Trio&num=50"
 * then this method would return the following dictionary:
 * { 
 *   q = "John Mayer Trio" 
 *   num = "50" 
 * }
    @param NSString
    @return NSDictionary
**/
- (NSDictionary *)parseParams:(NSString *)query;

/** 
    @brief Parses the query variables in the request URI. 
 
 * For example, if the request URI was "/search.html?q=John%20Mayer%20Trio&num=50" 
 * then this method would return the following dictionary: 
 * { 
 *   q = "John Mayer Trio" 
 *   num = "50" 
 * } 
    @return NSDictionary
**/ 
- (NSDictionary *)parseGetParams;

/**
    @brief Returns the URL as a string for the HTTPMessage
    @return NSString
**/
- (NSString *)requestURI;

/**
    @brief Returns an array of possible index pages.
    For example: {"index.html", "index.htm"}
    @return NSArray
**/
- (NSArray *)directoryIndexFileNames;

/**
    @brief Converts relative URI path into full file-system path.
    @param NSString
    @return NSString
**/
- (NSString *)filePathForURI:(NSString *)path;

/**
    @brief This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResponse is a wrapper for an NSData object, and may be used to send a custom response.
    @param NSString
    @param NSString
    @return NSObject <HTTPResponse>
**/
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path;

/**
    @brief Get the webSocket for a particular URI
    @param NSString
    @return WebSocket
**/
- (WebSocket *)webSocketForURI:(NSString *)path;

/**
    @brief This method is called after receiving all HTTP headers, but before reading any of the request body.
    @param UInt64
    @return void
**/
- (void)prepareForBodyWithSize:(UInt64)contentLength;

/**
    @brief This method is called to handle data read from a POST / PUT.
    The given data is part of the request body.
    @param NSData
    @return void
**/
- (void)processDataChunk:(NSData *)postDataChunk;

/**
    @brief Called if the HTML version is other than what is supported
    @param NSString
    @return void
**/
- (void)handleVersionNotSupported:(NSString *)version;

/**
    Called if the authentication information was required and absent, or if authentication failed.
**/
- (void)handleAuthenticationFailed;

/**
    @brief Called if we're unable to find the requested resource.
    @return void
**/
- (void)handleResourceNotFound;

/**
    @brief Called if we receive some sort of malformed HTTP request.

    The data parameter is the invalid HTTP header line, including CRLF, as read from GCDAsyncSocket.
    The data parameter may also be nil if the request as a whole was invalid, such as a POST with no Content-Length.
 
    @param NSData
    @return void
**/
- (void)handleInvalidRequest:(NSData *)data;

/**
    @brief Called if we receive a HTTP request with a method other than GET or HEAD.
    @param NSString
    @return void
**/
- (void)handleUnknownMethod:(NSString *)method;

/**
    @brief This method is called immediately prior to sending the response headers.
 
    This method adds standard header fields, and then converts the response to an NSData object.
 
    @param HTTPMessage
    @return NSData
**/
- (NSData *)preprocessResponse:(HTTPMessage *)response;

/**
    @brief This method is called immediately prior to sending the response headers (for an error).
    
    This method adds standard header fields, and then converts the response to an NSData object.
    @param HTTPMessage
    @return NSData
**/
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response;

/**
    @brief Returns whether the HTTPConnection should die
    @return BOOL
**/
- (BOOL)shouldDie;

/**
    @brief Closes the connection
    @return void
**/
- (void)die;

@end


@interface HTTPConnection (AsynchronousHTTPResponse)

/**
    @param NSObject with HTTPResponse protocol
    @return void
**/
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;

/**
    @param NSObject with HTTPResponse protocl
    @return void
**/
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender;

@end
