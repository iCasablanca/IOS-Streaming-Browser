#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif

@class HTTPMessage;


@interface HTTPAuthenticationRequest : NSObject
{
    // Whether basic authentication
    // basic access authentication is a method designed
    // to allow a web browser, or other client program, to
    // provide credentials – in the form of a user name and
    // password – when making a request
	BOOL isBasic;
    
    // Digest access authentication is one of the agreed 
    // methods a web server can use to negotiate credentials 
    // with a web user's browser. It uses encryption to send 
    // the password over the network which is safer than the 
    // Basic access authentication that sends plaintext.
	BOOL isDigest;
	
    
    // base64 encoding of basic authentication credentials    
	NSString *base64Credentials;
	
	NSString *username;
	NSString *realm;
	NSString *nonce;
	NSString *uri;
	NSString *qop;
	NSString *nc;
	NSString *cnonce;
	NSString *response;
}

/*
    Initializes the HTTPAuthenticationRequest with an HTTPMessage
*/
- (id)initWithRequest:(HTTPMessage *)request;

/*
    Getter method for accessing whether basic authentication
*/
- (BOOL)isBasic;

/*
    Getter method for accessing whether digest authentication
*/
- (BOOL)isDigest;

// Basic
- (NSString *)base64Credentials;

// Digest
- (NSString *)username;
- (NSString *)realm;
- (NSString *)nonce;
- (NSString *)uri;
- (NSString *)qop;
- (NSString *)nc;
- (NSString *)cnonce;
- (NSString *)response;

@end
