#import "GCDAsyncSocket.h"
#import "HTTPServer.h"
#import "HTTPConnection.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "HTTPDataResponse.h"
#import "HTTPAuthenticationRequest.h"
#import "DDNumber.h"
#import "DDRange.h"
#import "DDData.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "WebSocket.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

// Define chunk size used to read in data for responses
// This is how much data will be read from disk into RAM at a time
#if TARGET_OS_IPHONE
  #define READ_CHUNKSIZE  (1024 * 128)
#else
  #define READ_CHUNKSIZE  (1024 * 512)
#endif

// Define chunk size used to read in POST upload data
#if TARGET_OS_IPHONE
  #define POST_CHUNKSIZE  (1024 * 32)
#else
  #define POST_CHUNKSIZE  (1024 * 128)
#endif

// Define the various timeouts (in seconds) for various parts of the HTTP process
#define TIMEOUT_READ_FIRST_HEADER_LINE       30
#define TIMEOUT_READ_SUBSEQUENT_HEADER_LINE  30
#define TIMEOUT_READ_BODY                    -1
#define TIMEOUT_WRITE_HEAD                   30
#define TIMEOUT_WRITE_BODY                   -1
#define TIMEOUT_WRITE_ERROR                  30
#define TIMEOUT_NONCE                       300

// Define the various limits
// LIMIT_MAX_HEADER_LINE_LENGTH: Max length (in bytes) of any single line in a header (including \r\n)
// LIMIT_MAX_HEADER_LINES      : Max number of lines in a single header (including first GET line)
#define LIMIT_MAX_HEADER_LINE_LENGTH  8190
#define LIMIT_MAX_HEADER_LINES         100

// Define the various tags we'll use to differentiate what it is we're currently doing
#define HTTP_REQUEST_HEADER                10
#define HTTP_REQUEST_BODY                  11
#define HTTP_PARTIAL_RESPONSE              20
#define HTTP_PARTIAL_RESPONSE_HEADER       21
#define HTTP_PARTIAL_RESPONSE_BODY         22
#define HTTP_CHUNKED_RESPONSE_HEADER       30
#define HTTP_CHUNKED_RESPONSE_BODY         31
#define HTTP_CHUNKED_RESPONSE_FOOTER       32
#define HTTP_PARTIAL_RANGE_RESPONSE_BODY   40
#define HTTP_PARTIAL_RANGES_RESPONSE_BODY  50
#define HTTP_RESPONSE                      90
#define HTTP_FINAL_RESPONSE                91

// A quick note about the tags:
// 
// The HTTP_RESPONSE and HTTP_FINAL_RESPONSE are designated tags signalling that the response is completely sent.
// That is, in the onSocket:didWriteDataWithTag: method, if the tag is HTTP_RESPONSE or HTTP_FINAL_RESPONSE, it is assumed that the response is now completely sent.
// Use HTTP_RESPONSE if it's the end of a response, and you want to start reading more requests afterwards.
// Use HTTP_FINAL_RESPONSE if you wish to terminate the connection after sending the response.
// 
// If you are sending multiple data segments in a custom response, make sure that only the last segment has the HTTP_RESPONSE tag. For all other segments prior to the last segment use HTTP_PARTIAL_RESPONSE, or some other tag of your own invention.

@interface HTTPConnection (PrivateAPI)

/**
    Start reading the request
**/
- (void)startReadingRequest;

/**
    Send response headers and body
**/
- (void)sendResponseHeadersAndBody;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HTTPConnection


// initialize with capacity of 5
static NSMutableArray *recentNonces;  

/**
 * This method is automatically called (courtesy of Cocoa) before the first instantiation of this class.
 * We use it to initialize any static variables.
**/
+ (void)initialize
{
      
    
    
	static BOOL initialized = NO;
    
    // If the HTTPConnection is not initialized
	if(!initialized)
	{
		// Initialize class variables
		recentNonces = [[NSMutableArray alloc] initWithCapacity:5];
		
        // Flag for whether the connection is initialized
		initialized = YES;
	}
}

/**
    This method is designed to be called by a scheduled timer, and will remove a nonce from the recent nonce list.
    The nonce to remove should be set as the timer's userInfo.
    param NSTimer
**/
+ (void)removeRecentNonce:(NSTimer *)aTimer
{
    // Removes the timer's userInfo object.
	[recentNonces removeObject:[aTimer userInfo]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init, Dealloc:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sole Constructor.
 * Associates this new HTTP connection with the given AsyncSocket.
 * This HTTP connection object will become the socket's delegate and take over responsibility for the socket.
    param GCDAsyncSocket
    param HTTPConfig
    returns self
**/
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    DDLogError(@"initWithAsyncSocket");
    
	if ((self = [super init]))
	{
		// if there is a dispatch queue for requests
		if (aConfig.queue)
		{
            // Get the HTTPConfig dispatch queue
			connectionQueue = aConfig.queue;
            
            // Increments the reference count on the connection queue
			dispatch_retain(connectionQueue);
		}
		else  // if there is not a dispatch queue for requests then create one
		{
            // Create the HTTPConnection queue
			connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		}
		
		// Take over ownership of the socket
		asyncSocket = [newSocket retain];
        
        // Set the connection queue as the asyncSocket's delegate
		[asyncSocket setDelegate:self delegateQueue:connectionQueue];
		
		// Store configuration
		config = [aConfig retain];
		
		// Initialize lastNC (last nonce count).
		// Used with digest access authentication.
		// These must increment for each request from the client.
		lastNC = 0;
		
		// Create a new HTTP message
		request = [[HTTPMessage alloc] initEmptyRequest];
		
        // Sets the number of header lines to zero
		numHeaderLines = 0;
		
        // Creates a mutable array for the HTTPResponse sizes
		responseDataSizes = [[NSMutableArray alloc] initWithCapacity:5];
	}
	return self;
}

/**
    Standard Deconstructor.
**/
- (void)dealloc
{
	
    // Decrement the reference count of a dispatch object.
	dispatch_release(connectionQueue);
	
	[asyncSocket setDelegate:nil delegateQueue:NULL];
	[asyncSocket disconnect];
	[asyncSocket release];
	
	[config release];
	
	[request release];
	
	[nonce release];
	
    // Check if the HTTPResponse has a connectionDidClose method
	if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
	{
		[httpResponse connectionDidClose];
	}
	[httpResponse release];
	
	[ranges release];
	[ranges_headers release];
	[ranges_boundry release];
	
	[responseDataSizes release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Method Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Returns whether or not the server will accept messages of a given method at a particular URI.
    param NSString
    param NSString
    return BOOL
**/
- (BOOL)supportsMethod:(NSString *)method 
                atPath:(NSString *)path
{
	DDLogError(@"supportsMethod: method: %@, path: %@",method,path);
    
	// Override me to support methods such as POST.
	// 
	// Things you may want to consider:
	// - Does the given path represent a resource that is designed to accept this method?
	// - If accepting an upload, is the size of the data being uploaded too big?
	//   To do this you can check the requestContentLength variable.
	// 
	// For more information, you can always access the HTTPMessage request variable.
	// 
	// You should fall through with a call to [super supportsMethod:method atPath:path]
	// 
	// See also: expectsRequestBodyFromMethod:atPath:
	
    
    // We with accept GET methods
	if ([method isEqualToString:@"GET"])
    {
		return YES;
	}
    
    // We will accept HEAD methods
	if ([method isEqualToString:@"HEAD"])
    {
		return YES;
	}
	
    // We will not accept any other methods
	return NO;
}

/**
    Returns whether or not the server expects a body from the given method.
  
    In other words, should the server expect a content-length header and associated body from this method.
    This would be true in the case of a POST, where the client is sending data, or for something like PUT where the client is supposed to be uploading a file.
    param NSString
    param NSString
    returns BOOL
**/
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    DDLogError(@"expectsRequestBodyFromMethod: method: %@, path: %@",method,path);
	
	// Override me to add support for other methods that expect the client
	// to send a body along with the request header.
	// 
	// You should fall through with a call to [super expectsRequestBodyFromMethod:method atPath:path]
	// 
	// See also: supportsMethod:atPath:
	
    
    // We accept POST methods
	if ([method isEqualToString:@"POST"])
    {
		return YES;
	}
    
    // We accept PUT methods
	if ([method isEqualToString:@"PUT"])
    {
		return YES;
	}
    
    // We don't accept any other methods
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTPS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether or not the server is configured to be a secure server.
 * In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
 * This is the equivalent of having an https server, where it is assumed that all connections must be secure.
 * If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server
 * would need to be run on a separate port in order to support unsecure connections.
 * 
 * Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
**/
- (BOOL)isSecureServer
{
	
	// Override me to create an https server...
	
	return NO;
}

/**
    This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
    It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
**/
- (NSArray *)sslIdentityAndCertificates
{
	
	// Override me to provide the proper required SSL identity.
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Password Protection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Returns whether or not the requested resource is password protected.
    In this generic implementation, nothing is password protected.
    param NSString
    returns BOOL
**/
- (BOOL)isPasswordProtected:(NSString *)path
{
	
	// Override me to provide password protection...
	// You can configure it for the entire server, or based on the current request
	
	return NO;
}

/**
    Returns whether or not the authentication challenge should use digest access authentication.
    The alternative is basic authentication.
 
    If at all possible, digest access authentication should be used because it's more secure.
    Basic authentication sends passwords in the clear and should be avoided unless using SSL/TLS.
    returns BOOL
**/
- (BOOL)useDigestAccessAuthentication
{
	
	// Override me to customize the authentication scheme
	// Make sure you understand the security risks of using the weaker basic authentication
	
	return NO;
}

/**
    Returns the authentication realm.
    In this generic implmentation, a default realm is used for the entire server.
    returns NSString
**/
- (NSString *)realm
{
	
	// Override me to provide a custom realm...
	// You can configure it for the entire server, or based on the current request
	
	return @"defaultRealm@host.com";
}

/**
    Returns the password for the given username.
    param NSString
    returns NSString
**/
- (NSString *)passwordForUser:(NSString *)username
{
	
	// Override me to provide proper password authentication
	// You can configure a password for the entire server, or custom passwords for users and/or resources
	
	// Security Note:
	// A nil password means no access at all. (Such as for user doesn't exist)
	// An empty string password is allowed, and will be treated as any other password. (To support anonymous access)
	
	return nil;
}

/**
    Generates and returns an authentication nonce.
    A nonce is a  server-specified string uniquely generated for each 401 response.
    The default implementation uses a single nonce for each session.
    returns NSString
**/
- (NSString *)generateNonce
{
	
	// We use the Core Foundation UUID class to generate a nonce value for us
	// UUIDs (Universally Unique Identifiers) are 128-bit values guaranteed to be unique.
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
    
    
    // Makes a newly allocated Core Foundation object eligible for collection.
    // Returns the string representation of a specified CFUUID object.
	NSString *newNonce = [NSMakeCollectable(CFUUIDCreateString(NULL, theUUID)) autorelease];
    
    
    // Release the UUID
	CFRelease(theUUID);
	
	// We have to remember that the HTTP protocol is stateless.
	// Even though with version 1.1 persistent connections are the norm, they are not guaranteed.
	// Thus if we generate a nonce for this connection,
	// it should be honored for other connections in the near future.
	// 
	// In fact, this is absolutely necessary in order to support QuickTime.
	// When QuickTime makes it's initial connection, it will be unauthorized, and will receive a nonce.
	// It then disconnects, and creates a new connection with the nonce, and proper authentication.
	// If we don't honor the nonce for the second connection, QuickTime will repeat the process and never connect.
	
    
    // Adds newNonce to the recentNonces NSMutableArray
	[recentNonces addObject:newNonce];
	
    
    // Schedule a timer for the authentication
	[NSTimer scheduledTimerWithTimeInterval:TIMEOUT_NONCE
	                                 target:[HTTPConnection class]
	                               selector:@selector(removeRecentNonce:)
	                               userInfo:newNonce
	                                repeats:NO];
    
    // Returns the newly generated nonce
	return newNonce;
}

/**
    Returns whether or not the user is properly authenticated.
    returns BOOL
**/
- (BOOL)isAuthenticated
{
	
	// Extract the authentication information from the Authorization header
	HTTPAuthenticationRequest *auth = [[[HTTPAuthenticationRequest alloc] initWithRequest:request] autorelease];
	
    // If using digest authentication
	if ([self useDigestAccessAuthentication])
	{
		// Digest Access Authentication (RFC 2617)
		
		if(![auth isDigest])
		{
			// User didn't send proper digest access authentication credentials
			return NO;
		}
		
        // If the authentication user name is nil
		if ([auth username] == nil)
		{
			// The client didn't provide a username
			// Most likely they didn't provide any authentication at all
			return NO;
		}
		
        // Gets the password for a specific username
		NSString *password = [self passwordForUser:[auth username]];

        // If the authentication password is nil
        if (password == nil)
		{
			// No access allowed (username doesn't exist in system)
			return NO;
		}
		
        // Gets a string representation of the request url
		NSString *url = [[request url] relativeString];
		
        
        // Check if the request url matches the authenication uri.  
		if (![url isEqualToString:[auth uri]])
		{
			// Requested URL and Authorization URI do not match
			// This could be a replay attack
			// IE - attacker provides same authentication information, but requests a different resource
			return NO;
		}
		
		// The nonce the client provided will most commonly be stored in our local (cached) nonce variable
		if (![nonce isEqualToString:[auth nonce]])
		{
			// The given nonce may be from another connection
			// We need to search our list of recent nonce strings that have been recently distributed
			if ([recentNonces containsObject:[auth nonce]])
			{
				// Store nonce in local (cached) nonce variable to prevent array searches in the future
				[nonce release];
                
				nonce = [[auth nonce] copy];
				
				// The client has switched to using a different nonce value
				// This may happen if the client tries to get a file in a directory with different credentials.
				// The previous credentials wouldn't work, and the client would receive a 401 error
				// along with a new nonce value. The client then uses this new nonce value and requests the file again.
				// Whatever the case may be, we need to reset lastNC, since that variable is on a per nonce basis.
				lastNC = 0;
			}
			else
			{
				// We have no knowledge of ever distributing such a nonce.
				// This could be a replay attack from a previous connection in the past.
				return NO;
			}
		}
		
        // Gets the authentication nonce
        // converts a string to a long
        // base-16
		long authNC = strtol([[auth nc] UTF8String], NULL, 16);
		
        // Check if the nonce count is less the the last nonce count
		if (authNC <= lastNC)
		{
			// The nc value (nonce count) hasn't been incremented since the last request.
			// This could be a replay attack.
			return NO;
		}
        
        // Set the last nonce to this authorization nonce
		lastNC = authNC;
		
        
        // Forms the authentication response
		NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", [auth username], [auth realm], password];
        
        
        // Forms the authentication response with the request method and the authentication uri
		NSString *HA2str = [NSString stringWithFormat:@"%@:%@", [request method], [auth uri]];
		
        
        // Encrypts the username, realm and password using message digest algorithm
		NSString *HA1 = [[[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		
        // Encrypts the request method and uri using message digest algorithm
		NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		
        // Forms the response string with the MD5 encrypted values
		NSString *responseStr = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",HA1, [auth nonce], [auth nc], [auth cnonce], [auth qop], HA2];
		
        // Encrypts the response string
		NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		
        // Check that the authentication response we have created matches the authentication response
		return [response isEqualToString:[auth response]];
	}
	else
	{
		// Basic Authentication
		
        // If the authentication is not basic authentication
		if (![auth isBasic])
		{
			// User didn't send proper base authentication credentials
			return NO;
		}
		
		// Decode the base 64 encoded credentials by getting the HTTPAuthenticationRequest base64Credentials
		NSString *base64Credentials = [auth base64Credentials];
		
        
        // Returns an NSData object containing a representation of the receiver encoded using UTF8 encoding, and then decodes the base64 string.
		NSData *temp = [[base64Credentials dataUsingEncoding:NSUTF8StringEncoding] base64Decoded];
		
        
        // Create a string to hold the users credentials
		NSString *credentials = [[[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding] autorelease];
		
		// The credentials should be of the form "username:password"
		// The username is not allowed to contain a colon
		
        
        // Finds and returns the range of the first occurrence of a given string within the receiver.
		NSRange colonRange = [credentials rangeOfString:@":"];
		
        // Check if there is a colon
		if (colonRange.length == 0)
		{
			// Malformed credentials
			return NO;
		}
		
        // Gets the user name from the credentials
		NSString *credUsername = [credentials substringToIndex:colonRange.location];
        
        // Gets the password from the credentials.  This is the string past the location of the colon
		NSString *credPassword = [credentials substringFromIndex:(colonRange.location + colonRange.length)];
		
        
        // Gets the password for a particular username
		NSString *password = [self passwordForUser:credUsername];
        
        // Check if the password is nil
		if (password == nil)
		{
			// No access allowed (username doesn't exist in system)
			return NO;
		}
		
        // Check that the password matches the credentials password
		return [password isEqualToString:credPassword];
	}
}

/**
    Adds a digest access authentication challenge to the given response.
    param HTTPMessage
**/
- (void)addDigestAuthChallenge:(HTTPMessage *)response
{
	
    // Creates the authentication challenge format
	NSString *authFormat = @"Digest realm=\"%@\", qop=\"auth\", nonce=\"%@\"";
    
    
    // Creates the string for the authentication information
	NSString *authInfo = [NSString stringWithFormat:authFormat, [self realm], [self generateNonce]];
	
    // Sets the response header for authentication
	[response setHeaderField:@"WWW-Authenticate" value:authInfo];
}

/**
    Adds a basic authentication challenge to the http response.
    param HTTPMessage
**/
- (void)addBasicAuthChallenge:(HTTPMessage *)response
{
	// Creates the authentication format
	NSString *authFormat = @"Basic realm=\"%@\"";
    
    // Creates the authentication information with the authentication formation and the instances realm
	NSString *authInfo = [NSString stringWithFormat:authFormat, [self realm]];
	
    // Adds WWW-Authenticate and the format and realm to the response
    // header field
	[response setHeaderField:@"WWW-Authenticate" value:authInfo];
}


////////////////////////////////////////////////////////////////////////////
#pragma mark Core
////////////////////////////////////////////////////////////////////////////

/**
 * Starting point for the HTTP connection after it has been fully initialized (including subclasses).
 * This method is called by the HTTP server.
**/
- (void)start
{
    DDLogError(@"start");
    
    //  Submits a block for asynchronous execution on the connectionQueue
	dispatch_async(connectionQueue, ^{
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
        // Check if the connection is already started
		if (started)
        {
            return;
        }
        
        // If not started the set the flag that the connection is started and start the connection
		started = YES;
		
        // Starts the connection
		[self startConnection];
		
		[pool release];
	});  // END OF BLOCK
}

/**
 * This method is called by the HTTPServer if it is asked to stop.
 * The server, in turn, invokes stop on each HTTPConnection instance.
**/
- (void)stop
{
    DDLogError(@"stop");
    
    // Submits a block for asynchronous execution on the connectionQueue
	dispatch_async(connectionQueue, ^{
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Disconnect the socket.
		// The socketDidDisconnect delegate method will handle everything else.
		[asyncSocket disconnect];
		
		[pool release];
        
	}); // END OF BLOCK
}

/**
    Starting point for the HTTP connection.
**/
- (void)startConnection
{
    DDLogError(@"startConnection");
    
	// Override me to do any custom work before the connection starts.
	// 
	// Be sure to invoke [super startConnection] when you're done.
	
	
	if ([self isSecureServer])
	{
		// We are configured to be an HTTPS server.
		// That is, we secure via SSL/TLS the connection prior to any communication.
		
		NSArray *certificates = [self sslIdentityAndCertificates];
		
        // if there are certificates in the array
		if ([certificates count] > 0)
		{
			// All connections are assumed to be secure. Only secure connections are allowed on this server.
            // The objects for the dictionary are:
            //      is server
            //      certificates
            //      authentication level
			NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
			
			// Configure this connection as the server
			[settings setObject:[NSNumber numberWithBool:YES]
						 forKey:(NSString *)kCFStreamSSLIsServer];
			
            // Set the SSL certificate
			[settings setObject:certificates
						 forKey:(NSString *)kCFStreamSSLCertificates];
			
			// Configure this connection to use the highest possible SSL level
			[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
						 forKey:(NSString *)kCFStreamSSLLevel];
			
            // Start transport layer security with specific settings
			[asyncSocket startTLS:settings];
		}
	}
	
    // Starts reading an HTTP request
	[self startReadingRequest];
}

/**
 * Starts reading an HTTP request.
**/
- (void)startReadingRequest
{
	DDLogError(@"startReadingRequest");
    
    // Reads all bytes up to (and including) a delimiter sequence
	[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
	                withTimeout:TIMEOUT_READ_FIRST_HEADER_LINE
	                  maxLength:LIMIT_MAX_HEADER_LINE_LENGTH
	                        tag:HTTP_REQUEST_HEADER];
}

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
- (NSDictionary *)parseParams:(NSString *)query
{
    DDLogError(@"parseParams: %@",query);
    
    // Separates the compones which are separated by the '&' symbol
	NSArray *components = [query componentsSeparatedByString:@"&"];

    // Creates a mutable dictionary for the parameters key- value pairs
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[components count]];
	
    
	NSUInteger i;
    
    // Loop through each of the components in the array
	for (i = 0; i < [components count]; i++)
	{ 
		NSString *component = [components objectAtIndex:i];
        
        // If the component has length
		if ([component length] > 0)
		{
            // Gets the range (location and length) of the equal sign
			NSRange range = [component rangeOfString:@"="];
            
            // If there is an equal sign in the range
			if (range.location != NSNotFound)
			{ 
                // returns substring up to but not including index 
				NSString *escapedKey = [component substringToIndex:(range.location + 0)]; 
                
                // returns substring up to but not including index (start counting at 0)
				NSString *escapedValue = [component substringFromIndex:(range.location + 1)];
				
                // If there is an escape key in the parameters
				if ([escapedKey length] > 0)
				{
					CFStringRef k;  // The key
                    CFStringRef v;  // The value
					
                    // The key
					k = CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)escapedKey, CFSTR(""));
                    
                    // The value
					v = CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)escapedValue, CFSTR(""));
					
					NSString *key;
                    NSString *value;
					
                    // Makes the key eligible for collection.
					key   = [NSMakeCollectable(k) autorelease];
                    
                    // Makes the value eligible for collection.
					value = [NSMakeCollectable(v) autorelease];
	
                    
                    // If there is a key
					if (key)
					{
                        // If there is a value
						if (value)
                        {
                            // Adds the value and key to the dictionary
							[result setObject:value forKey:key]; 
                            
						}else{
                            
                            // Adds the key to the dictionary with a null value
							[result setObject:[NSNull null] forKey:key];
                            
                        }
					}
				}
			}
		}
	}
	
	return result;
}

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
- (NSDictionary *)parseGetParams 
{
    DDLogError(@"parseGetParams");
    
    // If the request header is not complete
	if(![request isHeaderComplete]) 
    {
        return nil;
	}
    
    // A disctionary for holding the keys and values from the parameters
	NSDictionary *result = nil;
	
    // Gets the request url
	NSURL *url = [request url];
    
    // If there is a url
	if(url)
	{
        // Gets the query for the url
		NSString *query = [url query];
        
        // If there is a query string
		if (query)
		{
            // Parses the given query string
			result = [self parseParams:query];
		}
	}
	
	return result; 
}

/**
 * Attempts to parse the given range header into a series of sequential non-overlapping ranges.
 * If successfull, the variables 'ranges' and 'rangeIndex' will be updated, and YES will be returned.
 * Otherwise, NO is returned, and the range request should be ignored.
 **/
- (BOOL)parseRangeRequest:(NSString *)rangeHeader 
        withContentLength:(UInt64)contentLength
{
	DDLogError(@"parseRangeRequest: %@, %llu",rangeHeader,contentLength);
    
	// Examples of byte-ranges-specifier values (assuming an entity-body of length 10000):
	// 
	// - The first 500 bytes (byte offsets 0-499, inclusive):  bytes=0-499
	// 
	// - The second 500 bytes (byte offsets 500-999, inclusive): bytes=500-999
	// 
	// - The final 500 bytes (byte offsets 9500-9999, inclusive): bytes=-500
	// 
	// - Or bytes=9500-
	// 
	// - The first and last bytes only (bytes 0 and 9999):  bytes=0-0,-1
	// 
	// - Several legal but not canonical specifications of the second 500 bytes (byte offsets 500-999, inclusive):
	// bytes=500-600,601-999
	// bytes=500-700,601-999
	// 
	
    
    // Get the range (location and length) of the equal sign in a string
	NSRange eqsignRange = [rangeHeader rangeOfString:@"="];
	
    // If no equal sign found in the range
	if(eqsignRange.location == NSNotFound) 
    {
        return NO;
    }

    // Location of the equal sign
    // Type index
	NSUInteger tIndex = eqsignRange.location;
    
    // The location plus the range
    // Function index
	NSUInteger fIndex = eqsignRange.location + eqsignRange.length;
	
    
    // Get the string up to the equal sign
	NSString *rangeType  = [[[rangeHeader substringToIndex:tIndex] mutableCopy] autorelease];
    
    
    // Gets the substring for the function index
	NSString *rangeValue = [[[rangeHeader substringFromIndex:fIndex] mutableCopy] autorelease];
	
    // Trimes the whitespace from the range type
	CFStringTrimWhitespace((CFMutableStringRef)rangeType);
    
    // Trims the whitespace from the range value
	CFStringTrimWhitespace((CFMutableStringRef)rangeValue);
	
    // Case insensitive comparison of string and whether they are the same order
	if([rangeType caseInsensitiveCompare:@"bytes"] != NSOrderedSame)
    {
        return NO;
	}
    
    // Gets the components in the range which are separated by a comma
	NSArray *rangeComponents = [rangeValue componentsSeparatedByString:@","];
	
    
    // If there are no components separated by a comma
	if([rangeComponents count] == 0) 
    {
        return NO;
	}
    
    
	[ranges release];
    
    // creates an NSMutable array for the range components
	ranges = [[NSMutableArray alloc] initWithCapacity:[rangeComponents count]];
	
    // Set the range index to zero
	rangeIndex = 0;
	
	// Note: We store all range values in the form of DDRange structs, wrapped in NSValue objects.
	// Since DDRange consists of UInt64 values, the range extends up to 16 exabytes.
	
	NSUInteger i;
    
    // Loops through each of the components
	for (i = 0; i < [rangeComponents count]; i++)
	{
        
        // Gets the range component at a particular index
		NSString *rangeComponent = [rangeComponents objectAtIndex:i];
		
        // Get the range (location and length) of a dash in the string
		NSRange dashRange = [rangeComponent rangeOfString:@"-"];
		
        // if there is no '-' in the range
		if (dashRange.location == NSNotFound)
		{
            //////////////////////////////////////////////////
			// We're dealing with an individual byte number
			//////////////////////////////////////////////////
            
			UInt64 byteIndex;
            
            // If can not parse the range component (a string) into an unsigned 64-bit integer
			if(![NSNumber parseString:rangeComponent intoUInt64:&byteIndex]) return NO;
	
            // Check if there are more bytes than the content length
			if(byteIndex >= contentLength) return NO;
			
            
            // Adds a range with the location of the byteIndex, and length of 1
			[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(byteIndex, 1)]];
            
		}
		else // if there is a '-' in the range
		{
            //////////////////////////////////////////
			// We're dealing with a range of bytes
			//////////////////////////////////////////
            
            
            // Get the location fo the dash
            // Type index
			tIndex = dashRange.location;
            
            // Function index
			fIndex = dashRange.location + dashRange.length;
			
            
            // Gets a substring for the type index
			NSString *r1str = [rangeComponent substringToIndex:tIndex];
            
            // Gets a substring for the function index
			NSString *r2str = [rangeComponent substringFromIndex:fIndex];
			
			UInt64 r1;  // range 1 - type index
            UInt64 r2;  // range 2 - function index
			
            // Type index
			BOOL hasR1 = [NSNumber parseString:r1str intoUInt64:&r1];
            
            // Function index
			BOOL hasR2 = [NSNumber parseString:r2str intoUInt64:&r2];
			
            // if has type index
			if (!hasR1)
			{
				// We're dealing with a "-[#]" range
				// 
				// r2 is the number of ending bytes to include in the range
				
                // Has function index
				if(!hasR2)
                {
                    return NO;
                }
                
                // Function index greater than the contentLength
				if(r2 > contentLength)
                {
                    return NO;
                }
                
				UInt64 startIndex = contentLength - r2;
				
                // Add object to the ranges mutable array
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(startIndex, r2)]];
			}
			else if (!hasR2)
			{
				// We're dealing with a "[#]-" range
				// 
				// r1 is the starting index of the range, which goes all the way to the end
				
				if(r1 >= contentLength) return NO;
				
                
                // Add object to the ranges mutable array
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, contentLength - r1)]];
			}
			else
			{
				// We're dealing with a normal "[#]-[#]" range
				// 
				// Note: The range is inclusive. So 0-1 has a length of 2 bytes.
				
				if(r1 > r2) // type index greater than function index
                {
                    return NO;
                }
                
                // function index greater or equal to content length
				if(r2 >= contentLength) 
                {
                    return NO;
                }
				
                // Add objects to the ranges mutable array
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, r2 - r1 + 1)]];
			}
		}
	}
	
    // Check if there are any range components.  If no components, then return
	if([ranges count] == 0) return NO;
	
    
	// Now make sure none of the ranges overlap
	
    // Loop through the items in the mutable ranges array
	for (i = 0; i < [ranges count] - 1; i++)
	{
        
        
		DDRange range1 = [[ranges objectAtIndex:i] ddrangeValue];
		
		NSUInteger j;
        
     
        // Loop through the items in the mutable ranges array
		for (j = i+1; j < [ranges count]; j++)
		{
			DDRange range2 = [[ranges objectAtIndex:j] ddrangeValue];
			
            
			DDRange iRange = DDIntersectionRange(range1, range2);
			
            // If there is not an intersection range between range1 and range2
			if(iRange.length != 0)
			{
				return NO;
			}
		}
	}
	
	// Sort the ranges array
	
	[ranges sortUsingSelector:@selector(ddrangeCompare:)];
	
	return YES;
}


/**
    Gets the URL as a string for the request HTTPMessage
    returns NSSTring
**/
- (NSString *)requestURI
{
    DDLogError(@"requestURI");
    
    // If the request HTTPMessage is nil
	if(request == nil) 
    {
        return nil;
	}
    
    // Returns the request message url as a readable string
	return [[request url] relativeString];
}

/**
    This method is called after a full HTTP request has been received.
    The current request is in the HTTPMessage request variable.
**/
- (void)replyToHTTPRequest
{
    DDLogError(@"replyToHTTPRequest");
	
	// Check the HTTP version
	// We only support version 1.0 and 1.1
	
	NSString *version = [request version];
    
    // If the version is not 1.1 or 1.0
	if (![version isEqualToString:HTTPVersion1_1] && ![version isEqualToString:HTTPVersion1_0])
	{
        // Returns an error that the HTTP version is not supported
		[self handleVersionNotSupported:version];
		return;
	}
    
	// We have determined the version is either 1.1 or 1.0
    
    
	// Extract requested URI
	NSString *uri = [self requestURI];
	
	// Check for WebSocket request
	if ([WebSocket isWebSocketRequest:request])
	{
		// Gets a web socket for a specific URI
		WebSocket *ws = [self webSocketForURI:uri];
		
        
        // If the web socket is nil
		if (ws == nil)
		{
            // unable to find the requested resource
			[self handleResourceNotFound];
		}
		else // if the web socket is not nil 
		{
            // Starting point for the WebSocket after it has been fully initialized (including subclasses).
			[ws start];
			
            // Adds a web socket to the server
			[[config server] addWebSocket:ws];
			
			// The WebSocket should now be the delegate of the underlying socket.
			// But gracefully handle the situation if it forgot.
			if ([asyncSocket delegate] == self)
			{
				
				// Disconnect the socket.
				// The socketDidDisconnect delegate method will handle everything else.
				[asyncSocket disconnect];
			}
			else  // if the asyncSocket delegate is not self
			{
				// The WebSocket is using the socket,
				// so make sure we don't disconnect it in the dealloc method.
				[asyncSocket release];
				asyncSocket = nil;
	
                // Kill this connection
				[self die];
				
				// Note: There is a timing issue here that should be pointed out.
				// 
				// A bug that existed in previous versions happend like so:
				// - We invoked [self die]
				// - This caused us to get released, and our dealloc method to start executing
				// - Meanwhile, AsyncSocket noticed a disconnect, and began to dispatch a socketDidDisconnect at us
				// - The dealloc method finishes execution, and our instance gets freed
				// - The socketDidDisconnect gets run, and a crash occurs
				// 
				// So the issue we want to avoid is releasing ourself when there is a possibility
				// that AsyncSocket might be gearing up to queue a socketDidDisconnect for us.
				// 
				// In this particular situation notice that we invoke [asyncSocket delegate].
				// This method is synchronous concerning AsyncSocket's internal socketQueue.
				// Which means we can be sure, when it returns, that AsyncSocket has already
				// queued any delegate methods for us if it was going to.
				// And if the delegate methods are queued, then we've been properly retained.
				// Meaning we won't get released / dealloc'd until the delegate method has finished executing.
				// 
				// In this rare situation, the die method will get invoked twice.
			}
		}
		
		return;
	}
	
	// Check Authentication (if needed)
	// If not properly authenticated for resource, issue Unauthorized response
	if ([self isPasswordProtected:uri] && ![self isAuthenticated])
	{
        // Host has not been authenticated
		[self handleAuthenticationFailed];
		return;
	}
	
    // The host has been authenticated
    
    
	// Extract the method
	NSString *method = [request method];
	
	// Note: We already checked to ensure the method was supported in onSocket:didReadData:withTag:
	
	// Gets the http response form the particular method and uri
	httpResponse = [[self httpResponseForMethod:method URI:uri] retain];
	
    
    // if the http response is nil
	if (httpResponse == nil)
	{
       //  unable to find the requested resource
		[self handleResourceNotFound];
		return;
	}
	
    // The http response is not nil
    
    // Send the response headers and body back to the host
	[self sendResponseHeadersAndBody];
}

/**
    Prepares a single-range response.
  
    Note: The returned HTTPMessage is owned by the sender, who is responsible for releasing it.
    param UInt64
    returns HTTPMessage
**/
- (HTTPMessage *)newUniRangeResponse:(UInt64)contentLength
{
	
    DDLogError(@"newUniRangeResponse");
    
	// Status Code 206 - Partial Content
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	
    // Get the object at index 0.  Note:  there should only be one item in the range array because this is a uni range response
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	
    // Convert the range length to a string
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", range.length];
    
    // Set the response header content length
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	
    // Converts a range location to a string
	NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];

	// Converts the contents of a range to a string
    NSString *contentRangeStr = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
    
    // Sets the response header content-range
	[response setHeaderField:@"Content-Range" value:contentRangeStr];
	
	return response;
}

/**
    Prepares a multi-range response.
  
    Note: The returned HTTPMessage is owned by the sender, who is responsible for releasing it.
    param UInt64
    returns HTTPMessage
**/
- (HTTPMessage *)newMultiRangeResponse:(UInt64)contentLength
{
	DDLogError(@"newMultiRangeResponse");
    
	// Status Code 206 - Partial Content
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	
	// We have to send each range using multipart/byteranges
	// So each byterange has to be prefix'd and suffix'd with the boundry
	// Example:
	// 
	// HTTP/1.1 206 Partial Content
	// Content-Length: 220
	// Content-Type: multipart/byteranges; boundary=4554d24e986f76dd6
	// 
	// 
	// --4554d24e986f76dd6
	// Content-Range: bytes 0-25/4025
	// 
	// [...]
	// --4554d24e986f76dd6
	// Content-Range: bytes 3975-4024/4025
	// 
	// [...]
	// --4554d24e986f76dd6--
	
	ranges_headers = [[NSMutableArray alloc] initWithCapacity:[ranges count]];
	
    // Create an empty unique identifier
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
    
    // Creates the boundary
	ranges_boundry = NSMakeCollectable(CFUUIDCreateString(NULL, theUUID));

	CFRelease(theUUID);
	
    // Converts the starting boundary to a string
	NSString *startingBoundryStr = [NSString stringWithFormat:@"\r\n--%@\r\n", ranges_boundry];
    
    // Converts the ending range boundary to a string
	NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
	
    // Initialize the message content length to zero
	UInt64 actualContentLength = 0;
	
	NSUInteger i;
    
    // Loop through the ranges
	for (i = 0; i < [ranges count]; i++)
	{
        
        // Gets the range at a specific index in the ranges array
		DDRange range = [[ranges objectAtIndex:i] ddrangeValue];
		
        // Converts the range location to a string
		NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];
        
        // Converts the length of the range to a string
		NSString *contentRangeVal = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
        
        
        // The Content-Range entity-header is sent with a partial entity-body to specify where in the full entity-body the partial body should be applied.
		NSString *contentRangeStr = [NSString stringWithFormat:@"Content-Range: %@\r\n\r\n", contentRangeVal];
		
        
        // Appends the starting boundary string with the content range string
		NSString *fullHeader = [startingBoundryStr stringByAppendingString:contentRangeStr];
        
        // Encodes the header data as a UTF8 string
		NSData *fullHeaderData = [fullHeader dataUsingEncoding:NSUTF8StringEncoding];
		
        // Adds header to the ranges_headers array
		[ranges_headers addObject:fullHeaderData];
		
        // Increment the content length by the header data
		actualContentLength += [fullHeaderData length];
        
        // Increments the content length by the length of the range
		actualContentLength += range.length;
	}
	
    // Done looping through the ranges mutable array
    
    
    // Encodes the ending boundary data
	NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
	
    // Increments the contents length by the number of bytes in the ending boundary data 
	actualContentLength += [endingBoundryData length];
	
    // Converts the actual content length to a string
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", actualContentLength];
    
    // Sets the response header content length
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	
    
    // Sets the content type
	NSString *contentTypeStr = [NSString stringWithFormat:@"multipart/byteranges; boundary=%@", ranges_boundry];
    
    // Sets the response header content type
	[response setHeaderField:@"Content-Type" value:contentTypeStr];
	
	return response;
}

/**
    Returns the chunk size line that must precede each chunk of data when using chunked transfer encoding.
    This consists of the size of the data, in hexadecimal, followed by a CRLF.
    param NSUInteger
    returns NSData
**/
- (NSData *)chunkedTransferSizeLineForLength:(NSUInteger)length
{
    DDLogError(@"chunkedTransferSizeLineForLength");
    
    
    // length can be 0 to 2,147,483,647
	return [[NSString stringWithFormat:@"%lx\r\n", (unsigned long)length] dataUsingEncoding:NSUTF8StringEncoding];
}

/**
    Returns the data that signals the end of a chunked transfer.
    returns NSData
**/
- (NSData *)chunkedTransferFooter
{
	// Each data chunk is preceded by a size line (in hex and including a CRLF),
	// followed by the data itself, followed by another CRLF.
	// After every data chunk has been sent, a zero size line is sent,
	// followed by optional footer (which are just more headers),
	// and followed by a CRLF on a line by itself.
	
	return [@"\r\n0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
}


/**
    Sends the response header and body back to the host
**/
- (void)sendResponseHeadersAndBody
{
    DDLogError(@"sendResponseHeaderAndBody");
    
    // If the httpResponse has a delayResponeHeaders method
	if ([httpResponse respondsToSelector:@selector(delayResponeHeaders)])
	{
        // Whether to delay the response headers
		if ([httpResponse delayResponeHeaders])
		{
			return;
		}
	}
	
	BOOL isChunked = NO;
	
    // Check if the http responds responds to a call to isChunked
	if ([httpResponse respondsToSelector:@selector(isChunked)])
	{
        // Set flag for whether response is chunked
		isChunked = [httpResponse isChunked];
	}
	
	// If a response is "chunked", this simply means the HTTPResponse object
	// doesn't know the content-length in advance.
	
	UInt64 contentLength = 0;
	
    // If the response is not serving content in a series of chunks
	if (!isChunked)
	{
        // Gets the http response content length
		contentLength = [httpResponse contentLength];
	}
	
	// Check for specific range request
	NSString *rangeHeader = [request headerField:@"Range"];
	
	BOOL isRangeRequest = NO;
	
	// If the response is "chunked" then we don't know the exact content-length.
	// This means we'll be unable to process any range requests.
	// This is because range requests might include a range like "give me the last 100 bytes"
	
	if (!isChunked && rangeHeader)
	{
        
        // Attempts to parse the given range header into a series of sequential non-overlapping ranges.
		if ([self parseRangeRequest:rangeHeader withContentLength:contentLength])
		{
            // Sets the flag that 
			isRangeRequest = YES;
		}
	}
	
    
	HTTPMessage *response;
	
    // If there is not a range request
	if (!isRangeRequest)
	{
		// Create response
		// Default status code: 200 - OK
		NSInteger status = 200;
		
        // If the response responds to the status selector
		if ([httpResponse respondsToSelector:@selector(status)])
		{
            // Gets the httpResponse status
			status = [httpResponse status];
		}
        
        // Allocate and initialize a HTTPMessage with a status code, description and version
		response = [[HTTPMessage alloc] initResponseWithStatusCode:status description:nil version:HTTPVersion1_1];
		
        
        // If the content is sent in a series of chunks
		if (isChunked)
		{
            // Set the response header for chunked data
			[response setHeaderField:@"Transfer-Encoding" value:@"chunked"];
		}
		else // If not sending the content in a series of chunks
		{
            // Set the content length
			NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", contentLength];
            
            // Sets the response HTTPMessage header's content length
			[response setHeaderField:@"Content-Length" value:contentLengthStr];
		}
	}
	else // If there is a range request
	{
        // If the range count equals 1
		if ([ranges count] == 1)
		{
            // Prepares a single-range response
			response = [self newUniRangeResponse:contentLength];
		}
		else // If the range count is not equal to one
		{
            // Prepares a mult-range response
			response = [self newMultiRangeResponse:contentLength];
		}
	}
	
    // Whether the response has zero length
	BOOL isZeroLengthResponse = !isChunked && (contentLength == 0);
    
	// If they issue a 'HEAD' command, we don't have to include the file
	// If they issue a 'GET' command, we need to include the file
	
	if ([[request method] isEqualToString:@"HEAD"] || isZeroLengthResponse)
	{
        
        // Preprocess the response
		NSData *responseData = [self preprocessResponse:response];
        
        // Write the data to the socket.  This is the response header
		[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		
        // Set the flag that we have sent the response headers
		sentResponseHeaders = YES;
	}
	else // if the request method is not equal to 'HEAD'
	{
		// Write the header response
		NSData *responseData = [self preprocessResponse:response];
        
        // Write the data to the socket
		[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
		
        // Set the flag that we have sent the response headers
		sentResponseHeaders = YES;
		
		// Now we need to send the body of the response
		if (!isRangeRequest)
		{
			// Regular request
			NSData *data = [httpResponse readDataOfLength:READ_CHUNKSIZE];
			
            // if the httpResponse has length
			if ([data length] > 0)
			{
                // Adds object to the response data sizes array
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				
                // if the response is chunked
				if (isChunked)
				{
                    
                    // Gets the chunk size line that must precede each chunk of data when using chunked transfer encoding.
					NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
                    
                    // Writes the http chunked response header to the socket
					[asyncSocket writeData:chunkSize withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_HEADER];
					
                    // Writes the http chunked response body to the socket
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_CHUNKED_RESPONSE_BODY];
					
                    
                    // Check whether done writing the response
					if ([httpResponse isDone])
					{
                        
                        // Gets the data that signals the end of a chunked transfer.
						NSData *footer = [self chunkedTransferFooter];
                        
                        // Write data to the socket
						[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
					}
					else // If not done writing
					{
                        
                        // Gets carriage return and line feed
						NSData *footer = [GCDAsyncSocket CRLFData];
                        
                        // Writes a response footer to the socket
						[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_FOOTER];
					}
				}
				else // if response is not chunked
				{
                    // Set the tag as 90 for HTTP_RESPONSE, or
                    // sets the tag to 22 for partial response body
					long tag = [httpResponse isDone] ? HTTP_RESPONSE : HTTP_PARTIAL_RESPONSE_BODY;
                    
                    // Write data to the socket
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
				}
			}
		}
		else
		{
			// Client specified a byte range in request
			
			if ([ranges count] == 1)
			{
				// Client is requesting a single range
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				
                // Set the response offset
				[httpResponse setOffset:range.location];
				
                // If the range length is less than the read chunk size, then the bytes to read is the length.  If not, then read the chunk size
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				
                // Reads data of a certain length
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				
                // If there is a httpResponse
				if ([data length] > 0)
				{
                    // adds data to the response
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					
                    // Whether a complete or partial response
					long tag = [data length] == range.length ? HTTP_RESPONSE : HTTP_PARTIAL_RANGE_RESPONSE_BODY;
                    
                    // Write data to the socket
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
				}
			}
			else // if range count is not equal to 1
			{
				// Client is requesting multiple ranges
				// We have to send each range using multipart/byteranges
				
				// Write range header
				NSData *rangeHeaderData = [ranges_headers objectAtIndex:0];
                
                // Writes a partial response header to the socket
				[asyncSocket writeData:rangeHeaderData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
				
				// Start writing range body
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				
                // Set the httpResponse offset
				[httpResponse setOffset:range.location];
				
                
                // Determine the number of bytes to read
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				
                
                // Read the data from the httpResponse
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				
                
                // If there was data in the httpResponse
				if ([data length] > 0)
				{
                    
                    // Adds object to the array of response data sizes
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					
                    // Write data to the socket
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
				}
			}
		}
	}
	
	[response release];
}

/**
 * Returns the number of bytes of the http response body that are sitting in asyncSocket's write queue.
 * 
 * We keep track of this information in order to keep our memory footprint low while
 * working with asynchronous HTTPResponse objects.
**/
- (NSUInteger)writeQueueSize
{
    DDLogError(@"writeQueueSize");
    
    // Number of bytes in the write queue
	NSUInteger result = 0;
	
	NSUInteger i;
    
    // Loops through the response data sizes array
	for(i = 0; i < [responseDataSizes count]; i++)
	{
        
		result += [[responseDataSizes objectAtIndex:i] unsignedIntegerValue];
	}
	
	return result;
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for standard (non-range) responses.
**/
- (void)continueSendingStandardResponseBody
{
	DDLogError(@"continueSendingStandardResponseBody");
    
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous HTTPResponse object informs us that it has more available data for us to send.
	// In the case of the asynchronous HTTPResponse, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
	NSUInteger writeQueueSize = [self writeQueueSize];
	
    
    // If the writeQueue size is larger than the chunk size
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	
    
	NSUInteger available = READ_CHUNKSIZE - writeQueueSize;

    // Gets the data for the response.
	NSData *data = [httpResponse readDataOfLength:available];
	
    // If the response data has length
	if ([data length] > 0)
	{
        
		[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
		
        // If the response is not separated into chunks
		BOOL isChunked = NO;
		
        // Check if the response responds to the isChunked selector
		if ([httpResponse respondsToSelector:@selector(isChunked)])
		{
            // Sets the httpResponse as chunked
			isChunked = [httpResponse isChunked];
		}
		
        // If the response is chunked
		if (isChunked)
		{
            
            // Gets the chunk size line that must precede each chunk of data when using chunked transfer encoding.
            // This consists of the size of the data, in hexadecimal, followed by a CRLF.
			NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
            
            // Writes the chunked response header to the socket
			[asyncSocket writeData:chunkSize withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_HEADER];
		
            // Writes the chunked response body to the socket
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_CHUNKED_RESPONSE_BODY];
			
            
            // If the response has been fully writen to the socket
			if([httpResponse isDone])
			{
                // Gets the data that signals the end of a chunked transfer.
				NSData *footer = [self chunkedTransferFooter];
                
                // Write the data to the socket
				[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
			}
			else // If the response has not been fully writen to the socket
			{
                // Gets carriage return and line feed
				NSData *footer = [GCDAsyncSocket CRLFData];
                
                // Writes the chunked response footer to the socket
				[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_FOOTER];
			}
		}
		else // if the response is not chunked
		{
            // if the response is done
			long tag = [httpResponse isDone] ? HTTP_RESPONSE : HTTP_PARTIAL_RESPONSE_BODY;
            
            // Writes the data to the socket with a timeout and tag
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
		}
	}
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for single-range responses.
**/
- (void)continueSendingSingleRangeResponseBody
{
	DDLogError(@"continueSendingSingleRangeResponseBody");
    
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous response informs us that is has more available data for us to send.
	// In the case of the asynchronous response, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
	NSUInteger writeQueueSize = [self writeQueueSize];
	
    
    // If the writeQueue size is larger than the read chunk size
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	
    
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	
    // Gets the httpResponse offset
	UInt64 offset = [httpResponse offset];
    
    
	UInt64 bytesRead = offset - range.location;
    
	UInt64 bytesLeft = range.length - bytesRead;
	
    
    // If there are bytes left 
	if (bytesLeft > 0)
	{
        
        
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
        
        
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
		
        
        // Gets the data for the response
		NSData *data = [httpResponse readDataOfLength:bytesToRead];
		
        
		if ([data length] > 0)
		{
            // Sets the response data size
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			
            // Creates the tag for the response or partial response
			long tag = [data length] == bytesLeft ? HTTP_RESPONSE : HTTP_PARTIAL_RANGE_RESPONSE_BODY;
            
            // Write the data to the socket
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
		}
	}
}

/**
 * Sends more data, if needed, without growing the write queue over its approximate size limit.
 * The last chunk of the response body will be sent with a tag of HTTP_RESPONSE.
 * 
 * This method should only be called for multi-range responses.
**/
- (void)continueSendingMultiRangeResponseBody
{
	DDLogError(@"continueSendingMultiRangeResponseBody");
    
	// This method is called when either asyncSocket has finished writing one of the response data chunks,
	// or when an asynchronous HTTPResponse object informs us that is has more available data for us to send.
	// In the case of the asynchronous HTTPResponse, we don't want to blindly grab the new data,
	// and shove it onto asyncSocket's write queue.
	// Doing so could negatively affect the memory footprint of the application.
	// Instead, we always ensure that we place no more than READ_CHUNKSIZE bytes onto the write queue.
	// 
	// Note that this does not affect the rate at which the HTTPResponse object may generate data.
	// The HTTPResponse is free to do as it pleases, and this is up to the application's developer.
	// If the memory footprint is a concern, the developer creating the custom HTTPResponse object may freely
	// use the calls to readDataOfLength as an indication to start generating more data.
	// This provides an easy way for the HTTPResponse object to throttle its data allocation in step with the rate
	// at which the socket is able to send it.
	
    
    // Gets the number of bytes of the http response body that are sitting in asyncSocket's write queue, and ready to sent to the host
	NSUInteger writeQueueSize = [self writeQueueSize];
	
	if(writeQueueSize >= READ_CHUNKSIZE) 
    {
        return;
    }
    
    
	DDRange range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
	
    // Gets the response offset
	UInt64 offset = [httpResponse offset];
    
    
    
	UInt64 bytesRead = offset - range.location;
    
    
	UInt64 bytesLeft = range.length - bytesRead;
	
    
	if (bytesLeft > 0)
	{
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
        
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
	
        // Reads the data from the httpResponse
		NSData *data = [httpResponse readDataOfLength:bytesToRead];
		
        // if the data has length
		if ([data length] > 0)
		{
            // Increases the response data size
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			
            // Write the data to the socket
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
		}
	}
	else  // if there are no bytes left
	{
		if (++rangeIndex < [ranges count])
		{
			// Write range header
			NSData *rangeHeader = [ranges_headers objectAtIndex:rangeIndex];
            
            // Writes data to the socket
			[asyncSocket writeData:rangeHeader withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
			
			// Start writing range body
			range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
			
            // Sets the httpResponse offset
			[httpResponse setOffset:range.location];
			
            
            // Subtracts the writeQueuesize from the read chunk size
			NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
            
            // Gets the number of bytes to read
			NSUInteger bytesToRead = range.length < available ? (NSUInteger)range.length : available;
			
            // Reads the data from the http response
			NSData *data = [httpResponse readDataOfLength:bytesToRead];
			
            // If the data has size
			if ([data length] > 0)
			{
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				
                // Writes the data to the socket
				[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
			}
		}
		else // if the rangeIndex >= to the range count
		{
			// We're not done yet - we still have to send the closing boundry tag
			NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
            
            // Sets the ending boundary to a UTF8 encoded string
			NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
			
            // Writes data to the socket
			[asyncSocket writeData:endingBoundryData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Responses
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Returns an array of possible index pages.
    For example: {"index.html", "index.htm"}
    returns NSArray
**/
- (NSArray *)directoryIndexFileNames
{
	DDLogError(@"directoryIndexFileNames");
    
	// Override me to support other index pages.
	
	return [NSArray arrayWithObjects:@"index.html", @"index.htm", nil];
}

/**
    Converts relative URI path into full file-system path.
    param NSString
    returns NSString
**/
- (NSString *)filePathForURI:(NSString *)path
{
	DDLogError(@"filePathForURI: %@",path);
	// Override me to perform custom path mapping.
	// For example you may want to use a default file other than index.html, or perhaps support multiple types.
	
	NSString *documentRoot = [config documentRoot];
    
	// Part 0: Validate document root setting.
	// 
	// If there is no configured documentRoot,
	// then it makes no sense to try to return anything.
	
	if (documentRoot == nil)
	{
		return nil;
	}
	
    /////////////////////////////////////////////////////////////
	// Part 1: Strip parameters from the url
	// 
	// E.g.: /page.html?q=22&var=abc -> /page.html
    //////////////////////////////////////////////////////////////
	
	NSURL *docRoot = [NSURL fileURLWithPath:documentRoot isDirectory:YES];
    
    // If there is no document root set
	if (docRoot == nil)
	{
		return nil;
	}
	
    // There is a document root
    
    // Get the string representation of the URL for the document root
	NSString *relativePath = [[NSURL URLWithString:path relativeToURL:docRoot] relativePath];
	
    /////////////////////////////////////////////////////////////////
	// Part 2: Append relative path to document root (base path)
	// 
	// E.g.: relativePath="/images/icon.png"
	//       documentRoot="/Users/robbie/Sites"
	//           fullPath="/Users/robbie/Sites/images/icon.png"
	// 
	// We also standardize the path.
	// 
	// E.g.: "Users/robbie/Sites/images/../index.html" -> "/Users/robbie/Sites/index.html"
	//////////////////////////////////////////////////////////////////
    
    
    
	NSString *fullPath = [[documentRoot stringByAppendingPathComponent:relativePath] stringByStandardizingPath];
	
    
	if ([relativePath isEqualToString:@"/"])
	{
		fullPath = [fullPath stringByAppendingString:@"/"];
	}
	
    //////////////////////////////////////////////////////////////
	// Part 3: Prevent serving files outside the document root.
	// 
	// Sneaky requests may include ".." in the path.
	// 
	// E.g.: relativePath="../Documents/TopSecret.doc"
	//       documentRoot="/Users/robbie/Sites"
	//           fullPath="/Users/robbie/Documents/TopSecret.doc"
	// 
	// E.g.: relativePath="../Sites_Secret/TopSecret.doc"
	//       documentRoot="/Users/robbie/Sites"
	//           fullPath="/Users/robbie/Sites_Secret/TopSecret"
	//////////////////////////////////////////////////////////////
    
	if (![documentRoot hasSuffix:@"/"])
	{
		documentRoot = [documentRoot stringByAppendingString:@"/"];
	}
	
	if (![fullPath hasPrefix:documentRoot])
	{
		return nil;
	}
	
    ///////////////////////////////////////////////////////////////////
	// Part 4: Search for index page if path is pointing to a directory
    ///////////////////////////////////////////////////////////////////
	
	BOOL isDir = NO;

	// if the file exists at the path and it is not a directory
	if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
	{
        
        // Get an array of possible index pages
		NSArray *indexFileNames = [self directoryIndexFileNames];
		
        
        
        // Loop through the array of possible index pages
		for (NSString *indexFileName in indexFileNames)
		{
            // Appends the file name to the full path
			NSString *indexFilePath = [fullPath stringByAppendingPathComponent:indexFileName];
			
            // If the file exists at the path and is a directory
			if ([[NSFileManager defaultManager] fileExistsAtPath:indexFilePath isDirectory:&isDir] && !isDir)
			{
				return indexFilePath;
			}
		}
		
		// No matching index files found in directory
		return nil;
	}
	else // If file does not exist at the path
	{
		return fullPath;
	}
}

/**
 * This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResponse is a wrapper for an NSData object, and may be used to send a custom response.
**/
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	DDLogError(@"httpResponseForMethod: %@ %@",method,path);
	// Override me to provide custom responses.
	
	NSString *filePath = [self filePathForURI:path];
	
	BOOL isDir = NO;
	
    // If the file exists at a path and  is not a directory
	if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
	{
        
		return [[[HTTPFileResponse alloc] initWithFilePath:filePath forConnection:self] autorelease];
	
		// Use me instead for asynchronous file IO.
		// Generally better for larger files.
		
        //	return [[[HTTPAsyncFileResponse alloc] initWithFilePath:filePath forConnection:self] autorelease];
        
	}else  // If file path is a directory
    {
        if ([path isEqualToString:@"/"]) {
            DDLogError(@"path is a slash");
            DDLogError(@"config documentRoot is: %@",[config documentRoot]);
        }else{
            DDLogError(@"path is not just a slash");
        }
        
        // Create a mutable string to hold the data being sent to the host
        NSMutableString *outdata = [NSMutableString new];
        
        [outdata appendString:@"<html>\n"];
        [outdata appendString:@"<head>\n"];
        [outdata appendString:@"<script language=\"JavaScript\"><!--\n"];
        [outdata appendString:@"function refreshIt() {\n"];
        [outdata appendString:@"if (!document.images) return;\n"];
        [outdata appendString:@"document.images['myImage'].src = '1.png?' + Math.random();\n"];
        [outdata appendString:@"setTimeout('refreshIt()',1000);\n"];
        [outdata appendString:@"}\n"];
        [outdata appendString:@"//--></script>\n"];
        [outdata appendString:@"</head>\n"];
        [outdata appendString:@"<body onLoad=\" setTimeout('refreshIt()',1000)\">\n"];
        [outdata appendString:@"<img src=\"1.png\" name=\"myImage\">\n"];
        [outdata appendString:@"</body>\n"];
        [outdata appendString:@"</html>\n"];

        // Encodes the mutable string 
        NSData *browseData = [outdata dataUsingEncoding:NSUTF8StringEncoding];
        
        // Creates a data response
        return [[[HTTPDataResponse alloc] initWithData:browseData] autorelease];
 
    }
	
	return nil;
}


/**
    Gets the webSocket for a specific URI
    return WebSocket
**/
- (WebSocket *)webSocketForURI:(NSString *)path
{
	DDLogError(@"webSocketForURI: %@",path);
	// Override me to provide custom WebSocket responses.
	// To do so, simply override the base WebSocket implementation, and add your custom functionality.
	// Then return an instance of your custom WebSocket here.
	// 
	// For example:
	// 
	// if ([path isEqualToString:@"/myAwesomeWebSocketStream"])
	// {
	//     return [[[MyWebSocket alloc] initWithRequest:request socket:asyncSocket] autorelease];
	// }
	// 
	// return [super webSocketForURI:path];
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Uploads
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called after receiving all HTTP headers, but before reading any of the request body.
**/
- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	// Override me to allocate buffers, file handles, etc.
}

/**
 * This method is called to handle data read from a POST / PUT.
 * The given data is part of the request body.
**/
- (void)processDataChunk:(NSData *)postDataChunk
{
	// Override me to do something useful with a POST / PUT.
	// If the post is small, such as a simple form, you may want to simply append the data to the request.
	// If the post is big, such as a file upload, you may want to store the file to disk.
	// 
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Errors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called if the HTML version is other than what is supported
**/
- (void)handleVersionNotSupported:(NSString *)version
{
    DDLogError(@"handleVersionNotSupported: %@",version);
    
	// Override me for custom error handling of unsupported http version responses
	// If you simply want to add a few extra header fields, see the preprocessErrorResponse: method.
	// You can also use preprocessErrorResponse: to add an optional HTML body.
	
	// Create a response and initialize with because the HTTP version is not supported
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:505 description:nil version:HTTPVersion1_1];
    
    // Set the content length to zero
	[response setHeaderField:@"Content-Length" value:@"0"];
    
    // The response which will be sent to the host
	NSData *responseData = [self preprocessErrorResponse:response];
    
    // Write the reponse to the socket by creating a writePacket and sending the packet to the socket queue 
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
	
	[response release];
}

/**
 * Called if the authentication information was required and absent, or if authentication failed.
**/
- (void)handleAuthenticationFailed
{
    DDLogError(@"handleAuthenticationFailed");
    
	// Override me for custom handling of authentication challenges
	// If you simply want to add a few extra header fields, see the preprocessErrorResponse: method.
	// You can also use preprocessErrorResponse: to add an optional HTML body.
	
		
	// Status Code 401 - Unauthorized
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:401 description:nil version:HTTPVersion1_1];
    
    // Set the HTTPMessage "Content-Length" header field to a value of zero
	[response setHeaderField:@"Content-Length" value:@"0"];
	
    
    // Test if using digest authentication
	if ([self useDigestAccessAuthentication])
	{
        // Adds a digest authentication challenge to the http response
		[self addDigestAuthChallenge:response];
	}
	else // if using basic authentication
	{
        // Adds a basic authentication challenge to the http response
		[self addBasicAuthChallenge:response];
	}
	
    // This method is called immediately prior to sending the response headers (for an error).
    // This method adds standard header fields, and then converts the response to an NSData object.
	NSData *responseData = [self preprocessErrorResponse:response];
    
    
    
    // Writes the response to the socket.  Keeps the connection alive so that we can read more request from the host.  We only kill this connection if the user responsds incorrectly
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
	
    
	[response release];
}

/**
 * Called if we receive some sort of malformed HTTP request.
 * The data parameter is the invalid HTTP header line, including CRLF, as read from GCDAsyncSocket.
 * The data parameter may also be nil if the request as a whole was invalid, such as a POST with no Content-Length.
**/
- (void)handleInvalidRequest:(NSData *)data
{
    DDLogError(@"handleInvalidRequest");
	// Override me for custom error handling of invalid HTTP requests
	// If you simply want to add a few extra header fields, see the preprocessErrorResponse: method.
	// You can also use preprocessErrorResponse: to add an optional HTML body.
	
	/////////////////////////////////
	// Status Code 400 - Bad Request
    /////////////////////////////////
    
    // Create the response with a status code of 400 for a bad request
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:400 description:nil version:HTTPVersion1_1];
    
    // Set the content length to zero
	[response setHeaderField:@"Content-Length" value:@"0"];
    
    // Set the header field so the connection is closed
	[response setHeaderField:@"Connection" value:@"close"];
	
    // This method is called immediately prior to sending the response headers (for an error).
    // This method adds standard header fields, and then converts the response to an NSData object.
	NSData *responseData = [self preprocessErrorResponse:response];
    
    // Write the data to the socket with a tag the all data has been completely written to the socket
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_FINAL_RESPONSE];
	
	[response release];
	
	// Note: We used the HTTP_FINAL_RESPONSE tag to disconnect after the response is sent.
	// We do this because we couldn't parse the request,
	// so we won't be able to recover and move on to another request afterwards.
	// In other words, we wouldn't know where the first request ends and the second request begins.
}

/**
    Called if we receive a HTTP request with a method other than GET or HEAD.
    param NSString
**/
- (void)handleUnknownMethod:(NSString *)method
{
    DDLogError(@"handleUnknownMethod");
	// Override me for custom error handling of 405 method not allowed responses.
	// If you simply want to add a few extra header fields, see the preprocessErrorResponse: method.
	// You can also use preprocessErrorResponse: to add an optional HTML body.
	// 
	// See also: supportsMethod:atPath:
	
	/////////////////////////////////////////
	// Status code 405 - Method Not Allowed
    /////////////////////////////////////////
    
    // Creates the response
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:405 description:nil version:HTTPVersion1_1];
    
    // Sets the content length to zero
	[response setHeaderField:@"Content-Length" value:@"0"];
    
    // Sets the connection to be closed
	[response setHeaderField:@"Connection" value:@"close"];
	
    
    // Preprocess teh response
	NSData *responseData = [self preprocessErrorResponse:response];
    
    // Write the data to the socket with the tag that all data has been completely written to the socket.  It also terminates the connection because this is the final response
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_FINAL_RESPONSE];
    
	[response release];
	
	// Note: We used the HTTP_FINAL_RESPONSE tag to disconnect after the response is sent.
	// We do this because the method may include an http body.
	// Since we can't be sure, we should close the connection.
}

/**
    Called if we're unable to find the requested resource.
**/
- (void)handleResourceNotFound
{
    DDLogError(@"handleResourceNotFound");
	// Override me for custom error handling of 404 not found responses
	// If you simply want to add a few extra header fields, see the preprocessErrorResponse: method.
	// You can also use preprocessErrorResponse: to add an optional HTML body.
	
	/////////////////////////////////
	// Status Code 404 - Not Found
    /////////////////////////////////
    
    // Creates the response
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:404 description:nil version:HTTPVersion1_1];
    
    // Sets content length to close
	[response setHeaderField:@"Content-Length" value:@"0"];
	
    // Note:  We are not setting the header field to close the connection.  The client just requested a resource which is not found so give them another chance to request the resource
    
    
    // Preprocess the response
	NSData *responseData = [self preprocessErrorResponse:response];
    
    // Write the response to the socket
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
	
	[response release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Headers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Gets the current date and time, formatted properly (according to RFC) for insertion into an HTTP header.
**/
- (NSString *)dateAsString:(NSDate *)date
{
    DDLogError(@"dataAsString");
    
	// From Apple's Documentation (Data Formatting Guide -> Date Formatters -> Cache Formatters for Efficiency):
	// 
	// "Creating a date formatter is not a cheap operation. If you are likely to use a formatter frequently,
	// it is typically more efficient to cache a single instance than to create and dispose of multiple instances.
	// One approach is to use a static variable."
	// 
	// This was discovered to be true in massive form via issue #46:
	// 
	// "Was doing some performance benchmarking using instruments and httperf. Using this single optimization
	// I got a 26% speed improvement - from 1000req/sec to 3800req/sec. Not insignificant.
	// The culprit? Why, NSDateFormatter, of course!"
	// 
	// Thus, we are using a static NSDateFormatter here.
	
	static NSDateFormatter *df;
	
	static dispatch_once_t onceToken;
    
    
	dispatch_once(&onceToken, ^{
		
		// Example: Sun, 06 Nov 1994 08:49:37 GMT
		
        // DateFormatter
		df = [[NSDateFormatter alloc] init];
		[df setFormatterBehavior:NSDateFormatterBehavior10_4];
		[df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		[df setDateFormat:@"EEE, dd MMM y HH:mm:ss 'GMT'"];
		
		// For some reason, using zzz in the format string produces GMT+00:00
	});  // END OF BLOCK
	
    // Returns a date as a string
	return [df stringFromDate:date];
}

/**
 * This method is called immediately prior to sending the response headers.
 * This method adds standard header fields, and then converts the response to an NSData object.
**/
- (NSData *)preprocessResponse:(HTTPMessage *)response
{
	DDLogError(@"preprocessResponse");
    
	// Override me to customize the response headers
	// You'll likely want to add your own custom headers, and then return [super preprocessResponse:response]
	
	// Add standard headers
	NSString *now = [self dateAsString:[NSDate date]];
    
    // Sets the date field in the response header
	[response setHeaderField:@"Date" value:now];
	
	// Add server capability headers
	[response setHeaderField:@"Accept-Ranges" value:@"bytes"];
	
	// Add optional response headers
	if ([httpResponse respondsToSelector:@selector(httpHeaders)])
	{
        // Creates a dictionary for the response headers
		NSDictionary *responseHeaders = [httpResponse httpHeaders];
		
        // Enumerates the responseHeaders dictionary
        // Gets an enumerator object that lets you access each key in the dictionary.
		NSEnumerator *keyEnumerator = [responseHeaders keyEnumerator];

        
		NSString *key;
		
        // enumerate through the keys in the response header
		while ((key = [keyEnumerator nextObject]))
		{
            // Gets the value for a certain key in the response headers
			NSString *value = [responseHeaders objectForKey:key];
			
            // Sets the response header field
			[response setHeaderField:key value:value];
		}
	}
	
	return [response messageData];
}

/**
 * This method is called immediately prior to sending the response headers (for an error).
 * This method adds standard header fields, and then converts the response to an NSData object.
**/
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response;
{
	DDLogError(@"preprocessErrorResponse");
	// Override me to customize the error response headers
	// You'll likely want to add your own custom headers, and then return [super preprocessErrorResponse:response]
	// 
	// Notes:
	// You can use [response statusCode] to get the type of error.
	// You can use [response setBody:data] to add an optional HTML body.
	// If you add a body, don't forget to update the Content-Length.
	// 
	// if ([response statusCode] == 404)
	// {
	//     NSString *msg = @"<html><body>Error 404 - Not Found</body></html>";
	//     NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
	//     
	//     [response setBody:msgData];
	//     
	//     NSString *contentLengthStr = [NSString stringWithFormat:@"%lu", (unsigned long)[msgData length]];
	//     [response setHeaderField:@"Content-Length" value:contentLengthStr];
	// }
	
	// Add standard headers
    
    // Gets the current date as a string
	NSString *now = [self dateAsString:[NSDate date]];
    
    // Set the  response header date value
	[response setHeaderField:@"Date" value:now];
	
	// Add server capability headers
	[response setHeaderField:@"Accept-Ranges" value:@"bytes"];
	
	// Add optional response headers
	if ([httpResponse respondsToSelector:@selector(httpHeaders)])
	{
        
        // Dictionary for the response headers
		NSDictionary *responseHeaders = [httpResponse httpHeaders];
		
        // Gets an enumerator object for enumerating the response headers dictionary
		NSEnumerator *keyEnumerator = [responseHeaders keyEnumerator];

		NSString *key;
		
        // Loops through each key in the header
		while((key = [keyEnumerator nextObject]))
		{
            // Gets the value for a specific key
			NSString *value = [responseHeaders objectForKey:key];
			
            // Sets the response header field
			[response setHeaderField:key value:value];
		}
	}
	
	return [response messageData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark GCDAsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called after the socket has successfully read data from the stream.
 * Remember that this method will only be called after the socket reaches a CRLF, or after it's read the proper length.
**/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
    DDLogError(@"socket didReadData withTag");
    
    // if a request header is HEADER - equals 10
	if (tag == HTTP_REQUEST_HEADER)
	{
		// Append the header line to the http message
		BOOL result = [request appendData:data];
        
        // if there is no result
		if (!result)
		{
            // Called if we receive some sort of malformed HTTP request.
			[self handleInvalidRequest:data];
            
            
		}// if there is a result, check to see if the header is not complete
		else if (![request isHeaderComplete])
		{
			// We don't have a complete header yet
			// That is, we haven't yet received a CRLF on a line by itself, indicating the end of the header
			if (++numHeaderLines > LIMIT_MAX_HEADER_LINES)
			{
				// Reached the maximum amount of header lines in a single HTTP request
				// This could be an attempted DOS attack
				[asyncSocket disconnect];
				
				// Explictly return to ensure we don't do anything after the socket disconnect
				return;
			}
			else // if the header is less than the maximum header lines
			{
                
                // Reads data from socket
				[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
				                withTimeout:TIMEOUT_READ_SUBSEQUENT_HEADER_LINE
				                  maxLength:LIMIT_MAX_HEADER_LINE_LENGTH
				                        tag:HTTP_REQUEST_HEADER];
			}
		}
		else // if there is a result, and the header is complete
		{
			// We have an entire HTTP request header from the client
			
			// Extract the method (such as GET, HEAD, POST, etc)
			NSString *method = [request method];
			
			// Extract the uri (such as "/index.html")
			NSString *uri = [self requestURI];
			
			// Check for a Content-Length field
			NSString *contentLength = [request headerField:@"Content-Length"];
			
			// Content-Length MUST be present for upload methods (such as POST or PUT)
			// and MUST NOT be present for other methods.
			BOOL expectsUpload = [self expectsRequestBodyFromMethod:method atPath:uri];
			
            // if expecting we need to get the data from a file at a specific path
			if (expectsUpload)
			{
                // Check if there is a contentLength header
				if (contentLength == nil)
				{
                    // Malformed http request
					[self handleInvalidRequest:nil];
					return;
				}
				
                // The content length is not nil
                
				if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
				{
					// Malformed http request
					[self handleInvalidRequest:nil];
					return;
				}
			}
			else // if not expecting an upload
			{
                // If there is a contentLength in the header
				if (contentLength != nil)
				{
					// Received Content-Length header for method not expecting an upload.
					// This better be zero...
					
					if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
					{
						// Malformed http request
						[self handleInvalidRequest:nil];
						return;
					}
					
                    // If the request header has a contentLength field
					if (requestContentLength > 0)
					{
						// Malformed http request
						[self handleInvalidRequest:nil];
						return;
					}
				}
				
				requestContentLength = 0;
				requestContentLengthReceived = 0;
			}
			
			// Check to make sure the given method is supported.  For example, does the request have a GET or HEAD method
			if (![self supportsMethod:method atPath:uri])
			{
				// The method is unsupported - either in general, or for this specific request
				// Send a 405 - Method not allowed response
				[self handleUnknownMethod:method];
				return;
			}
			
            // The request has a 'GET' or 'HEAD' method
            
            // If expecting an upload of data from the host
			if (expectsUpload)
			{
				// Reset the total amount of data received for the upload
				requestContentLengthReceived = 0;
				
				// Prepare for the upload
				[self prepareForBodyWithSize:requestContentLength];
				
                // If the request headers content length is greater than zero
				if (requestContentLength > 0)
				{
					// Start reading the request body
					NSUInteger bytesToRead;
                    
                    // If the content length is less than the posting chunksize
					if(requestContentLength < POST_CHUNKSIZE)
                    {
                        // Get the number of bytes to read from the http request's contentLength header
						bytesToRead = (NSUInteger)requestContentLength;
                        
					}else{
                        
                        // Read just only the post chunksize amount of data
						bytesToRead = POST_CHUNKSIZE;
                    }
					
                    // Read data of a specific length from the socket
					[asyncSocket readDataToLength:bytesToRead
					                  withTimeout:TIMEOUT_READ_BODY
					                          tag:HTTP_REQUEST_BODY];
				}
				else
				{
					// Empty upload
					[self replyToHTTPRequest];
				}
			}
			else
			{
				// Now we need to reply to the request
				[self replyToHTTPRequest];
			}
		}
	}
	else
	{
		// Handle a chunk of data from the POST body
		
        // Cumulative counter for the number of bytes received
		requestContentLengthReceived += [data length];
        
        // Process the chunked data
		[self processDataChunk:data];
		
        // If we haven't received all the data from the socket
		if (requestContentLengthReceived < requestContentLength)
		{
			// We're not done reading the post body yet...
			UInt64 bytesLeft = requestContentLength - requestContentLengthReceived;
			
            
            // The number of bytes yet to read 
			NSUInteger bytesToRead = bytesLeft < POST_CHUNKSIZE ? (NSUInteger)bytesLeft : POST_CHUNKSIZE;
		
            // Read data from socket
			[asyncSocket readDataToLength:bytesToRead
			                  withTimeout:TIMEOUT_READ_BODY
			                          tag:HTTP_REQUEST_BODY];
		}
		else
		{
			// Now we need to reply to the request
			[self replyToHTTPRequest];
		}
	}
}

/**
    This method is called after the socket has successfully written data to the stream.
    param GCDAsyncSocket
    param long
**/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    DDLogError(@"socket didWriteDataWithTag");
    
    // Set the flag that we are not done writing
	BOOL doneSendingResponse = NO;
	
    // If a partial body response
	if (tag == HTTP_PARTIAL_RESPONSE_BODY)
	{
		// Update the amount of data we have in asyncSocket's write queue
		[responseDataSizes removeObjectAtIndex:0];
		
		// We only wrote a part of the response - there may be more
		[self continueSendingStandardResponseBody];
	}
    // If a chunked response for the body
	else if (tag == HTTP_CHUNKED_RESPONSE_BODY)
	{
		// Update the amount of data we have in asyncSocket's write queue.
		// This will allow asynchronous responses to continue sending more data.
		[responseDataSizes removeObjectAtIndex:0];
		
		// Don't continue sending the response yet.
		// The chunked footer that was sent after the body will tell us if we have more data to send.
	}
	else if (tag == HTTP_CHUNKED_RESPONSE_FOOTER)
	{
		// Normal chunked footer indicating we have more data to send (non final footer).
		[self continueSendingStandardResponseBody];
	}
    // If a partial range response for the body of the message
	else if (tag == HTTP_PARTIAL_RANGE_RESPONSE_BODY)
	{
		// Update the amount of data we have in asyncSocket's write queue
		[responseDataSizes removeObjectAtIndex:0];
		
		// We only wrote a part of the range - there may be more
		[self continueSendingSingleRangeResponseBody];
	}
    // If a partial ranges response for the body of the message
	else if (tag == HTTP_PARTIAL_RANGES_RESPONSE_BODY)
	{
		// Update the amount of data we have in asyncSocket's write queue
		[responseDataSizes removeObjectAtIndex:0];
		
		// We only wrote part of the range - there may be more, or there may be more ranges
		[self continueSendingMultiRangeResponseBody];
	}
    // If an http response or final response
	else if (tag == HTTP_RESPONSE || tag == HTTP_FINAL_RESPONSE)
	{
		// Update the amount of data we have in asyncSocket's write queue
		if ([responseDataSizes count] > 0)
		{
            
			[responseDataSizes removeObjectAtIndex:0];
		}
		
        // Flag for whether we are done sending the http response
		doneSendingResponse = YES;
	}
	
    // If done sending a response, then send clean-up and disconnect
	if (doneSendingResponse)
	{
        // If this is the final response
		if (tag == HTTP_FINAL_RESPONSE)
		{
			// Terminate the connection
			[asyncSocket disconnect];
			
			// Explictly return to ensure we don't do anything after the socket disconnect
			return;
		}
		else // if not a final response. Don't close the connection because we want to read more data from the host
		{
			// Cleanup after the last request
			// And start listening for the next request
			
			// Inform the http response that we're done
			if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
			{
                
				[httpResponse connectionDidClose];
			}
			
			// Release any resources we no longer need
			[httpResponse release];
			httpResponse = nil;
			
			[ranges release];
			[ranges_headers release];
			[ranges_boundry release];
			ranges = nil;
			ranges_headers = nil;
			ranges_boundry = nil;
			
			if ([self shouldDie])
			{
				// The only time we should invoke [self die] is from socketDidDisconnect,
				// or if the socket gets taken over by someone else like a WebSocket.
				
				[asyncSocket disconnect];
			}
			else // if should not die
			{
				// Release the old request, and create a new one
				[request release];
                
                // Create and http request message
				request = [[HTTPMessage alloc] initEmptyRequest];
				
                
				numHeaderLines = 0;
				sentResponseHeaders = NO;
				
				// And start listening for more requests
				[self startReadingRequest];
			}
		}
	}
}

/**
    Sent after the socket has been disconnected.
    param GCDAsyncSocket
    param NSError
**/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err;
{
    DDLogError(@"socketDidDisconnect withError");
	
	[asyncSocket release];
	asyncSocket = nil;
	
	[self die];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTPResponse Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method may be called by asynchronous HTTPResponse objects.
 * That is, HTTPResponse objects that return YES in their "- (BOOL)isAsynchronous" method.
 * 
 * This informs us that the response object has generated more data that we may be able to send.
**/
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender
{
    DDLogError(@"responseHasAvailableData");
	
	// We always dispatch this asynchronously onto our connectionQueue,
	// even if the connectionQueue is the current queue.
	// 
	// We do this to give the HTTPResponse classes the flexibility to call
	// this method whenever they want, even from within a readDataOfLength method.
	
	dispatch_async(connectionQueue, ^{
		
        // Check that the caller of this method is not an httpResponse.
		if (sender != httpResponse)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
        // If have not sent the response headers
		if (!sentResponseHeaders)
		{
            
            // Sends the response headers and body
			[self sendResponseHeadersAndBody];
		}
		else // if have sent the response headers, then send the body
		{
			if (ranges == nil)
			{
                // Sends more data, if needed, without growing the write queue over its approximate size limit.
				[self continueSendingStandardResponseBody];
			}
			else // if ranges is not nil
			{
                // If sending a unibody response
				if ([ranges count] == 1)
                {
                    // Sends more data, if needed, without growing the write queue over its approximate size limit.
					[self continueSendingSingleRangeResponseBody];
                    
                // If sending a multibody response    
				}else{ // if ranges count is not equal to 1
                    
                    
                    // Sends more data, if needed, without growing the write queue over its approximate size limit.
					[self continueSendingMultiRangeResponseBody];
                }
			}
		}
		
		[pool release];
	}); // END OF BLOCK
}

/**
 * This method is called if the response encounters some critical error,
 * and it will be unable to fullfill the request.
**/
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender
{
    DDLogError(@"responseDidAbort");
	
	// We always dispatch this asynchronously onto our connectionQueue,
	// even if the connectionQueue is the current queue.
	// 
	// We do this to give the HTTPResponse classes the flexibility to call
	// this method whenever they want, even from within a readDataOfLength method.
	
    // Submits a block for asynchronous execution on the connectionQueue
	dispatch_async(connectionQueue, ^{
		
        // Make sure the caller of this method is not an httpResponse.  
		if (sender != httpResponse)
		{
			return;
		}
		
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
        // Disconnects the socket after writing the data
		[asyncSocket disconnectAfterWriting];
		
		[pool release];
	}); // END OF BLOCK
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Closing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called after each response has been fully sent.
 * Since a single connection may handle multiple request/responses, this method may be called multiple times.
 * That is, it will be called after completion of each response.
**/
- (BOOL)shouldDie
{
	DDLogError(@"shouldDie");
	// Override me if you want to perform any custom actions after a response has been fully sent.
	// You may also force close the connection by returning YES.
	// 
	// If you override this method, you should take care to fall through with [super shouldDie]
	// instead of returning NO.
	
	
	BOOL shouldDie = NO; // flag for whether the connection should die
	
    // Get the http request version
	NSString *version = [request version];
    
    // If the http request version is using 1.1
	if ([version isEqualToString:HTTPVersion1_1])
	{
		// HTTP version 1.1
		// Connection should only be closed if request included "Connection: close" header
		
		NSString *connection = [request headerField:@"Connection"];
		
        // Close the connection
		shouldDie = (connection && ([connection caseInsensitiveCompare:@"close"] == NSOrderedSame));
	}
    // If HTTP version 1.0
	else if ([version isEqualToString:HTTPVersion1_0])
	{
		// HTTP version 1.0
		// Connection should be closed unless request included "Connection: Keep-Alive" header
		
		NSString *connection = [request headerField:@"Connection"];
		
        // If there is not a connection
		if (connection == nil)
        {
            // Flag the connection to die
			shouldDie = YES;
            
		}else{ // If there is a connection
            
            // Keep the connection alive
			shouldDie = [connection caseInsensitiveCompare:@"Keep-Alive"] != NSOrderedSame;
        }
	}
	
    // if not HTTP version 1.0 or 1.1
	return shouldDie;
}

/**
    Closes the connection
**/
- (void)die
{
	DDLogError(@"die");
    
	// Override me if you want to perform any custom actions when a connection is closed.
	// Then call [super die] when you're done.
	// 
	// Important: There is a rare timing condition where this method might get invoked twice.
	// If you override this method, you should be prepared for this situation.
	
	// Inform the http response that we're done
	if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
	{
        //This method is called from the HTTPConnection class when the connection is closed, or when the connection is finished with the response.
		[httpResponse connectionDidClose];
	}
	
	// Release the http response so we don't call it's connectionDidClose method again in our dealloc method
	[httpResponse release];
	httpResponse = nil;
	
	// Post notification of dead connection
	// This will allow our server to release us from its array of connections
	[[NSNotificationCenter defaultCenter] postNotificationName:HTTPConnectionDidDieNotification object:self];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HTTPConfig


// Creates the getters and setters for server, documentRoot, and queue
@synthesize server;
@synthesize documentRoot;
@synthesize queue;


/**
    Initialize the HTTPConfig with a server and documentRoot
**/
- (id)initWithServer:(HTTPServer *)aServer documentRoot:(NSString *)aDocumentRoot
{
    DDLogError(@"initWithServer documentRoot: %@",aDocumentRoot);
    
	if ((self = [super init]))
	{
        // Gets the server from the method request parameter
		server = [aServer retain];
        
        // Gets the document root from the method request parameter
		documentRoot = [aDocumentRoot retain];
	}
	return self;
}


/**
    Initialize the HTTPConfig with a server, documentRoot and queue
    param HTTPServer
    param NSString
    param dispatch_queue_t
**/
- (id)initWithServer:(HTTPServer *)aServer documentRoot:(NSString *)aDocumentRoot queue:(dispatch_queue_t)q
{
    DDLogError(@"initWithServer documentRoot queue: %@",documentRoot);
    
	if ((self = [super init]))
	{
        // Gets the server from the method request parameter
		server = [aServer retain];
		
        // Gets the document root from the method request parameter
		documentRoot = [aDocumentRoot stringByStandardizingPath];
        
        // Check if the document root has a suffix
		if ([documentRoot hasSuffix:@"/"])
		{
            // Appends a forward slash to the document root
			documentRoot = [documentRoot stringByAppendingString:@"/"];
		}
        
        // Increments the reference count on the document root
		[documentRoot retain];
		
        // If there is a dispatch queue
		if (q)
		{
            //Increment the reference count of a dispatch object.
			dispatch_retain(q);
			queue = q;
		}
	}
	return self;
}


/**
    Standard deconstructor
**/
- (void)dealloc
{
	[server release];
	[documentRoot release];
	
	if (queue)
		dispatch_release(queue);
	
	[super dealloc];
}




@end
