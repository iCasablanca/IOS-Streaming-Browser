#import <Foundation/Foundation.h>

@class HTTPMessage;
@class GCDAsyncSocket;


#define WebSocketDidDieNotification  @"WebSocketDidDie"

@interface WebSocket : NSObject
{
    
    /**
      websocket queue
    **/
	dispatch_queue_t websocketQueue; 
	
    /**
       the web socket request
    **/
	HTTPMessage *request; 

    /**
      the socket (i.e. file handle)
    **/
	GCDAsyncSocket *asyncSocket; 
	
    /**
     
    **/
	NSData *term;
	
    /**
      if web socket is started
    **/
	BOOL isStarted;  
    
    /**
      if web socket is open
    **/
	BOOL isOpen;  
    
    /**
      if version76
    **/
	BOOL isVersion76; 
}

/**
    Class method
    param HTTPMessage
    returns BOOL
**/
+ (BOOL)isWebSocketRequest:(HTTPMessage *)request;

/**
    Initialize with HTTPMessage request and a socket
    param HTTPMessage
    param GCDAsyncSocket
**/
- (id)initWithRequest:(HTTPMessage *)request socket:(GCDAsyncSocket *)socket;

/**
 * Delegate option.
 * 
 * In most cases it will be easier to subclass WebSocket,
 * but some circumstances may lead one to prefer standard delegate callbacks instead.
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
 * Starting point for the WebSocket after it has been fully initialized (including subclasses).
 * This method is called by the HTTPConnection it is spawned from.
 **/
- (void)start;



/**
 * This method is called by the HTTPServer if it is asked to stop.
 * The server, in turn, invokes stop on each WebSocket instance.
 **/
- (void)stop;

/**
 * Public API
 * 
 * Sends a message over the WebSocket.
 * This method is thread-safe.
**/
- (void)sendMessage:(NSString *)msg;

/**
 * Subclass API
 * 
 * These methods are designed to be overriden by subclasses.
**/

/**
    If the web socket did open
**/
- (void)didOpen;

/**
    If the web socket did receive an incoming message
**/
- (void)didReceiveMessage:(NSString *)msg;

/**
    If the web socket did close
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
    The websocket did open
    param WebSocket
**/
- (void)webSocketDidOpen:(WebSocket *)ws;

/**
    The websocket did receive an incoming message
    param WebSocket
    param NSString
**/
- (void)webSocket:(WebSocket *)ws didReceiveMessage:(NSString *)msg;

/**
    The websocket did close
    param WebSocket
**/
- (void)webSocketDidClose:(WebSocket *)ws;

@end