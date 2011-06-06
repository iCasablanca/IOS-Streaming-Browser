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

/**
    The HTTP Server
**/
@interface HTTPServer : NSObject IMPLEMENTED_PROTOCOLS
{
    /////////////////////////////////////////////
	// Underlying asynchronous TCP/IP socket
    ////////////////////////////////////////////

    /**
        @brief Dispatch queues are lightweight objects to which blocks may be submitted.  The system manages a pool of threads which process  dispatch queues and invoke blocks submitted to them.
    **/
	dispatch_queue_t serverQueue;
    
    /**
        @brief Dispatch queues are lightweight objects to which blocks may be submitted.  The system manages a pool of threads which process  dispatch queues and invoke blocks submitted to them.
     **/    
	dispatch_queue_t connectionQueue;

	/**
        @brief For reading and writing data
    **/
    GCDAsyncSocket *asyncSocket;  
	
    ///////////////////////////////////////////
	// HTTP server configuration
    ///////////////////////////////////////////

	
    /**
        @brief The document root
    **/
    NSString *documentRoot; 
    
    /**
        @brief Default is HTTP connection
    **/
	Class connectionClass; 
    
    /**
        @brief The interface the server should listen on, "en1", "lo0", etc
    **/
	NSString *interface; 
    
    /**
        @brief The listening port
    **/
	UInt16 port; 

    ///////////////////////////////////////////	
	// NSNetService and related variables
    ///////////////////////////////////////////  
    
    /**
        @brief Represents a network service
    **/
	NSNetService *netService; 
    
    /**
        @brief The domain the service should be published on, the default is 'local'
    **/
	NSString *domain; 
    
    /**
        @brief tcp or udp
    **/
	NSString *type; 
    
    /**
        @brief Default is the computers name that the server is running on
    **/
	NSString *name; 
    
    /**
        @brief The published server name
    **/
	NSString *publishedName; 
	
    /**
        @brief NSDictionary for the text record
        Dictionary consisting of "zero or more strings, packed together in memory without any intervening gaps or padding bytes for word alignment. The format of each constituent string within the DNS TXT record is a single length byte, followed by 0-255 bytes of text data."
    **/
    NSDictionary *txtRecordDictionary;
	
    ///////////////////////////////////////////    
	// Connection management
    ///////////////////////////////////////////
    
    /**
        @brief The connections to the server
    **/
	NSMutableArray *connections; 

    /**
        @brief The web socket connections
    **/
	NSMutableArray *webSockets; 
    
    /**
        @brief Locks the http connection.  Note:  uses POSIX threads to implement its locking behavior
    **/
	NSLock *connectionsLock; 
    
    /**
        @brief Locks the websocket.  Note:  uses POSIX threads to implement its locking behavior
    **/
	NSLock *webSocketsLock; 
	
    /**
        @brief Whether the server is running or not
    **/
	BOOL isRunning;
}

/**
    @brief Specifies the document root to serve files from.
 
    For example, if you set this to "/Users/<your_username>/Sites", then it will serve files out of the local Sites directory (including subdirectories).
 
    The default value is nil.
    The default server configuration will not serve any files until this is set.
 
    If you change the documentRoot while the server is running, the change will affect future incoming http connections.
    @return NSString
**/
- (NSString *)documentRoot;

/**
    @brief Sets the document root
    @param NSString
    @return void
**/
- (void)setDocumentRoot:(NSString *)value;

/**
    @brief The connection class is the class used to handle incoming HTTP connections.
 
    The default value is [HTTPConnection class].
    You can override HTTPConnection, and then set this to [MyHTTPConnection class].
 
    If you change the connectionClass while the server is running, the change will affect future incoming http connections.
    @return Class
**/
- (Class)connectionClass;

/**
    @brief Sets the connection class
    @param Class
    @return void
**/
- (void)setConnectionClass:(Class)value;

/**
    @brief Set what interface you'd like the server to listen on.

    By default this is nil, which causes the server to listen on all available interfaces like en1, wifi etc.
 
    The interface may be specified by name (e.g. "en1" or "lo0") or by IP address (e.g. "192.168.4.34").
    You may also use the special strings "localhost" or "loopback" to specify that the socket only accept connections from the local machine.
    @return NSString
**/
- (NSString *)interface;

/**
    @brief Sets the interface
    @pram NSString
    @return void
**/
- (void)setInterface:(NSString *)value;

/**
    @brief The port number to run the HTTP server on.
 
    The default port number is zero, meaning the server will automatically use any available port.
    This is the recommended port value, as it avoids possible port conflicts with other applications.
    Technologies such as Bonjour can be used to allow other applications to automatically discover the port number.
 
    Note: As is common on most OS's, you need root privledges to bind to port numbers below 1024.
 
    You can change the port property while the server is running, but it won't affect the running server.
    To actually change the port the server is listening for connections on you'll need to restart the server.
 
    The listeningPort method will always return the port number the running server is listening for connections on.
    If the server is not running this method returns 0.

    @return UInt16
**/
- (UInt16)port;

/**
    @brief Gets the listening port
    @return UInt16
**/
- (UInt16)listeningPort;

/**
    @brief Sets the listening port
    @param UInt16
    @return void
**/
- (void)setPort:(UInt16)value;

/**
    @brief Bonjour domain for publishing the service.

    The default value is "local.".
 
    Note: Bonjour publishing requires you set a type.
 
    If you change the domain property after the bonjour service has already been published (server already started), you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
    @return NSString
**/
- (NSString *)domain;

/**
    @brief Sets the domain
    @param NSString
    @return void
**/
- (void)setDomain:(NSString *)value;



/**
    @brief Bonjour name for publishing the service.

    The default value is "".
 
    If using an empty string ("") for the service name when registering, the system will automatically use the "Computer Name".
    Using an empty string will also handle name conflicts by automatically appending a digit to the end of the name.
 
    Note: Bonjour publishing requires you set a type.
 
    If you change the name after the bonjour service has already been published (server already started), you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
 
    The publishedName method will always return the actual name that was published via the bonjour service.
    If the service is not running this method returns nil.
    @return NSString
**/
- (NSString *)name;



/**
    @brief Gets the published name of the server
    @return NSString
**/
- (NSString *)publishedName;

/**
    @brief Sets the published name of the server
    @param NSString
    @return void
**/
- (void)setName:(NSString *)value;

/**
    @brief Bonjour type for publishing the service.

    The default value is nil.
    The service will not be published via bonjour unless the type is set.
 
    If you wish to publish the service as a traditional HTTP server, you should set the type to be "_http._tcp.".
 
    If you change the type after the bonjour service has already been published (server already started), you'll need to invoke the republishBonjour method to update the broadcasted bonjour service.
    @return NSString
**/
- (NSString *)type;


/**
    @brief Set the type of service to be published via Bonjour param NSString
    @param NSString
    @return void
**/
- (void)setType:(NSString *)value;



/**
    @brief Republishes the service via bonjour if the server is running.

    If the service was not previously published, this method will publish it (if the server is running).
    @return void
**/
- (void)republishBonjour;

/**
    @brief Gets the TXT record dictionary
    @return NSDictionary
**/
- (NSDictionary *)TXTRecordDictionary;

/**
    @brief Sets the TXT record dictionary
    @param NSDictionary
    @return void
**/
- (void)setTXTRecordDictionary:(NSDictionary *)dict;

/**
    @brief Starts the server
    @param NSError
    @return BOOL
**/
- (BOOL)start:(NSError **)errPtr;


/**
    @brief Stops the server
    @return BOOL
**/
- (BOOL)stop;


/**
    @brief Whether the server is running
    @return BOOL
**/
- (BOOL)isRunning;

/**
    @brief Adds a web socket
    @pram WebSocket
    @return void
**/
- (void)addWebSocket:(WebSocket *)ws;

/**
    @brief Gets the number of HTTP connections
    @return NSUInteger
**/
- (NSUInteger)numberOfHTTPConnections;

/**
    @brief Gets the number of web socket connections
    @return NSUInteger
**/
- (NSUInteger)numberOfWebSocketConnections;

@end
