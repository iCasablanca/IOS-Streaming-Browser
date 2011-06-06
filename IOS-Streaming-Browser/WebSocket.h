#import <Foundation/Foundation.h>

@class HTTPMessage;
@class GCDAsyncSocket;


#define WebSocketDidDieNotification  @"WebSocketDidDie"

/**
    WebSocket
**/
@interface WebSocket : NSObject
{
    
    /**
        @brief Websocket queue
    **/
	dispatch_queue_t websocketQueue; 
	
    /**
       @brief The web socket request
    **/
	HTTPMessage *request; 

    /**
      @brief The socket (i.e. file handle)
    **/
	GCDAsyncSocket *asyncSocket; 
	
    /**
        @brief The terminator
    **/
	NSData *term;
	
    /**
        @brief If web socket is started
    **/
	BOOL isStarted;  
    
    /**
        @brief If web socket is open
    **/
	BOOL isOpen;  
    
    /**
        @brief If version76
    **/
	BOOL isVersion76; 
}

/**
    Class method
    @brief If is a WebSocket request
    @param HTTPMessage
    @return BOOL
**/
+ (BOOL)isWebSocketRequest:(HTTPMessage *)request;

/**
    @brief Initialize with HTTPMessage request and a socket
    @param HTTPMessage
    @param GCDAsyncSocket
    @return id
**/
- (id)initWithRequest:(HTTPMessage *)request socket:(GCDAsyncSocket *)socket;

/**
    @brief Delegate option.
  
    In most cases it will be easier to subclass WebSocket, but some circumstances may lead one to prefer standard delegate callbacks instead.
**/
@property (/* atomic */ assign) id delegate;

/**
 * The WebSocket class is thread-safe, generally via it's GCD queue.
 * All public API methods are thread-safe,
 * and the subclass API methods are thread-safe as they are all invoked on the same GCD queue.
**/
@property (nonatomic, readonly) dispatch_queue_t websocketQueue;

/**
 * Public API
 * 
 * These methods are automatically called by the HTTPServer.
 * You may invoke the stop method yourself to close the WebSocket manually.
**/

/**
    @brief Starting point for the WebSocket after it has been fully initialized (including subclasses).
    This method is called by the HTTPConnection it is spawned from.
    @return void
**/
- (void)start;



/**
    @brief This method is called by the HTTPServer if it is asked to stop.
    The server, in turn, invokes stop on each WebSocket instance.
    @return void
**/
- (void)stop;

/**
    Public API
  
    @brief Sends a message over the WebSocket.
    This method is thread-safe.
    @param NSString
    @return void
**/
- (void)sendMessage:(NSString *)msg;

/**
 * Subclass API
 * 
 * These methods are designed to be overriden by subclasses.
**/

/**
    @brief If the web socket did open
    @return void
**/
- (void)didOpen;

/**
    @brief If the web socket did receive an incoming message
    @param NSString
    @return void
**/
- (void)didReceiveMessage:(NSString *)msg;

/**
    @brief If the web socket did close
    @return void
**/
- (void)didClose;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * There are two ways to create your own custom WebSocket:
 * 
 * - Subclass it and override the methods you're interested in.
 * - Use traditional delegate paradigm along with your own custom class.
 * 
 * They both exist to allow for maximum flexibility.
 * In most cases it will be easier to subclass WebSocket.
 * However some circumstances may lead one to prefer standard delegate callbacks instead.
 * One such example, you're already subclassing another class, so subclassing WebSocket isn't an option.
**/

@protocol WebSocketDelegate
@optional

/**
    @brief The websocket did open
    @param WebSocket
    @return void
**/
- (void)webSocketDidOpen:(WebSocket *)ws;

/**
    @brief The websocket did receive an incoming message
    @param WebSocket
    @param NSString
    @return void
**/
- (void)webSocket:(WebSocket *)ws didReceiveMessage:(NSString *)msg;

/**
    @brief The websocket did close
    @param WebSocket
    @return void
**/
- (void)webSocketDidClose:(WebSocket *)ws;

@end