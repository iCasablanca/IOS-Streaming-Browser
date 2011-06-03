#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class WebSocket;

#if TARGET_OS_IPHONE
  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000 // iPhone 4.0
    #define IMPLEMENTED_PROTOCOLS <NSNetServiceDelegate>
  #else
    #define IMPLEMENTED_PROTOCOLS 
  #endif
#else
  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060 // Mac OS X 10.6
    #define IMPLEMENTED_PROTOCOLS <NSNetServiceDelegate>
  #else
    #define IMPLEMENTED_PROTOCOLS 
  #endif
#endif


@interface HTTPServer : NSObject IMPLEMENTED_PROTOCOLS
{
    /////////////////////////////////////////////
	// Underlying asynchronous TCP/IP socket
    ////////////////////////////////////////////

    // Dispatch queues are lightweight objects to which blocks may be
    // submitted.  The system manages a pool of threads which process 
    // dispatch queues and invoke blocks submitted to them.
	dispatch_queue_t serverQueue;
	dispatch_queue_t connectionQueue;
	GCDAsyncSocket *asyncSocket;  // for reading and writing data
	
    ///////////////////////////////////////////
	// HTTP server configuration
    ///////////////////////////////////////////
	NSString *documentRoot; // the document root
	Class connectionClass; // default is HTTP connection
	NSString *interface; // the interface the server should listen on, "en1", "lo0", etc
	UInt16 port; // the listening port

    ///////////////////////////////////////////	
	// NSNetService and related variables
    ///////////////////////////////////////////    
	NSNetService *netService; // represents a network service
	NSString *domain; // the domain the service should be published on, the default is 'local'
	NSString *type; // tcp or udp
	NSString *name; // default is the computers name that the server is running on
	NSString *publishedName; // the published server name
	NSDictionary *txtRecordDictionary;
	
    ///////////////////////////////////////////    
	// Connection management
    ///////////////////////////////////////////
	NSMutableArray *connections; // the connections to the server
	NSMutableArray *webSockets; // the web socket connections
	NSLock *connectionsLock; // locks the http connection
	NSLock *webSocketsLock; // locks the websocket
	
    // Whether the server is running or not
	BOOL isRunning;
}

/**
 * Specifies the document root to serve files from.
 * For example, if you set this to "/Users/<your_username>/Sites",
 * then it will serve files out of the local Sites directory (including subdirectories).
 * 
 * The default value is nil.
 * The default server configuration will not serve any files until this is set.
 * 
 * If you change the documentRoot while the server is running,
 * the change will affect future incoming http connections.
**/
- (NSString *)documentRoot;

/**
    Sets the document root
**/
- (void)setDocumentRoot:(NSString *)value;

/**
 * The connection class is the class used to handle incoming HTTP connections.
 * 
 * The default value is [HTTPConnection class].
 * You can override HTTPConnection, and then set this to [MyHTTPConnection class].
 * 
 * If you change the connectionClass while the server is running,
 * the change will affect future incoming http connections.
**/
- (Class)connectionClass;

/**
    Sets the connection class
**/
- (void)setConnectionClass:(Class)value;

/**
 * Set what interface you'd like the server to listen on.
 * By default this is nil, which causes the server to listen on all available interfaces like en1, wifi etc.
 * 
 * The interface may be specified by name (e.g. "en1" or "lo0") or by IP address (e.g. "192.168.4.34").
 * You may also use the special strings "localhost" or "loopback" to specify that
 * the socket only accept connections from the local machine.
**/
- (NSString *)interface;

/**
    Sets the interface
**/
- (void)setInterface:(NSString *)value;

/**
 * The port number to run the HTTP server on.
 * 
 * The default port number is zero, meaning the server will automatically use any available port.
 * This is the recommended port value, as it avoids possible port conflicts with other applications.
 * Technologies such as Bonjour can be used to allow other applications to automatically discover the port number.
 * 
 * Note: As is common on most OS's, you need root privledges to bind to port numbers below 1024.
 * 
 * You can change the port property while the server is running, but it won't affect the running server.
 * To actually change the port the server is listening for connections on you'll need to restart the server.
 * 
 * The listeningPort method will always return the port number the running server is listening for connections on.
 * If the server is not running this method returns 0.
**/
- (UInt16)port;

/**
    Gets the listening port
**/
- (UInt16)listeningPort;

/**
    Sets the listening port
**/
- (void)setPort:(UInt16)value;

/**
 * Bonjour domain for publishing the service.
 * The default value is "local.".
 * 
 * Note: Bonjour publishing requires you set a type.
 * 
 * If you change the domain property after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
**/
- (NSString *)domain;

/**
    Sets the domain
**/
- (void)setDomain:(NSString *)value;

/**
 * Bonjour name for publishing the service.
 * The default value is "".
 * 
 * If using an empty string ("") for the service name when registering,
 * the system will automatically use the "Computer Name".
 * Using an empty string will also handle name conflicts
 * by automatically appending a digit to the end of the name.
 * 
 * Note: Bonjour publishing requires you set a type.
 * 
 * If you change the name after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 * 
 * The publishedName method will always return the actual name that was published via the bonjour service.
 * If the service is not running this method returns nil.
**/
- (NSString *)name;

/**
    Gets the published name of the server
**/
- (NSString *)publishedName;

/**
    Sets the published name of the server
**/
- (void)setName:(NSString *)value;

/**
 * Bonjour type for publishing the service.
 * The default value is nil.
 * The service will not be published via bonjour unless the type is set.
 * 
 * If you wish to publish the service as a traditional HTTP server, you should set the type to be "_http._tcp.".
 * 
 * If you change the type after the bonjour service has already been published (server already started),
 * you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
**/
- (NSString *)type;

/**
    Sets the type
**/
- (void)setType:(NSString *)value;

/**
 * Republishes the service via bonjour if the server is running.
 * If the service was not previously published, this method will publish it (if the server is running).
**/
- (void)republishBonjour;

/**
 *  Gets the TXT record dictionary
**/
- (NSDictionary *)TXTRecordDictionary;

/**
    Sets the TXT record dictionary
**/
- (void)setTXTRecordDictionary:(NSDictionary *)dict;

/**
    Starts the server
**/
- (BOOL)start:(NSError **)errPtr;

/**
    Stops the server
**/
- (BOOL)stop;

/**
    Whether the server is running
**/
- (BOOL)isRunning;

/**
    Adds a web socket
**/
- (void)addWebSocket:(WebSocket *)ws;

/**
    Gets the number of HTTP connections
**/
- (NSUInteger)numberOfHTTPConnections;

/**
    Gets the number of web socket connections
**/
- (NSUInteger)numberOfWebSocketConnections;

@end
