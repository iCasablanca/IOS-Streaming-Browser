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
	NSString *base64Credentials; // basic or digest
	
    // The user's name in the specified realm.
	NSString *username;
    
    // A string to be displayed to users so they know which username and    password to use. This string should contain at least the name of    the host performing the authentication and might additionally    indicate the collection of users who might have access. An example might be "registered_users@gotham.news.com".
	NSString *realm;
    
    // A server-specified data string which should be uniquely generated each time a 401 response is made. It is recommended that this    string be base64 or hexadecimal data. Specifically, since the    string is passed in the header lines as a quoted string, the    double-quote character is not allowed.
	NSString *nonce;
    
    // The URI from Request-URI of the Request-Line; duplicated here    because proxies are allowed to change the Request-Line in transit.
	NSString *uri;
    
    // This directive is optional, but is made so only for backward    compatibility with RFC 2069 [6]; it SHOULD be used by all    implementations compliant with this version of the Digest scheme.    If present, it is a quoted string of one or more tokens indicating the "quality of protection" values supported by the server.  The value "auth" indicates authentication; the value "auth-int"indicates authentication with integrity protection;
	NSString *qop;
    
    //  This MUST be specified if a qop directive is sent (see above), and MUST NOT be specified if the server did not send a qop directive in the WWW-Authenticate header field.  The nc-value is the hexadecimal count of the number of requests (including the current request) that the client has sent with the nonce value in this request.  For example, in the first request sent in response to a given nonce value, the client sends "nc=00000001".  The purpose of this directive is to allow the server to detect request replays by maintaining its own copy of this count - if the same nc-value is seen twice, then the request is a replay. 
	NSString *nc;
    
    // This MUST be specified if a qop directive is sent (see above), and MUST NOT be specified if the server did not send a qop directive in the WWW-Authenticate header field.  The cnonce-value is an opaque quoted string value provided by the client and used by both client and server to avoid chosen plaintext attacks, to provide mutual authentication, and to provide some message integrity protection.
	NSString *cnonce;
    
    // A string of 32 hex digits computed as defined below, which proves that the user knows a password
	NSString *response;
}

/*
    Initializes the HTTPAuthenticationRequest with an HTTPMessage
    param HTTPMessage
    returns id
*/
- (id)initWithRequest:(HTTPMessage *)request;

/*
    Getter method for accessing whether basic authentication
    returns BOOL
*/
- (BOOL)isBasic;

/*
    Getter method for accessing whether digest authentication
    returns BOOL
*/
- (BOOL)isDigest;

///////////////////////
// Basic Authentication
///////////////////////

/*
    returns NSString
*/
- (NSString *)base64Credentials;

///////////////////////////////
// Digest
//////////////////////////////

/*
 The user's name in the specified realm, encoded according to the value of the "charset" directive. This directive is required and MUST be present exactly once; otherwise, authentication fails.
*/
- (NSString *)username;

/*
 The realm containing the user's account. This directive is required if the server provided any realms in the "digest-challenge", in which case it may appear exactly once and its value SHOULD be one of those realms. If the directive is missing, "realm-value" will set to the empty string when computing A1 (see below for details).

*/
- (NSString *)realm;

/*
 The server-specified data string received in the preceding digest-challenge. This directive is required and MUST be present exactly once; otherwise, authentication fails.
*/
- (NSString *)nonce;

/*
 Indicates the principal name of the service with which the client wishes to connect, formed from the serv-type, host, and serv-name. For example, the FTP service on "ftp.example.com" would have a "digest-uri" value of "ftp/ftp.example.com"; the SMTP server from the example above would have a "digest-uri" value of "smtp/mail3.example.com/example.com".
 
 Servers SHOULD check that the supplied value is correct. This will detect accidental connection to the incorrect server. It is also so that clients will be trained to provide values that will work with implementations that use a shared back-end authentication service that can provide server authentication.
 
 The serv-type component should match the service being offered. The host component should match one of the host names of the host on which the service is running, or it's IP address. Servers SHOULD NOT normally support the IP address form, because server authentication by IP address is not very useful; they should only do so if the DNS is unavailable or unreliable. The serv-name component should match one of the service's configured service names.
 
 This directive may appear at most once; if multiple instances are present, the client should abort the authentication exchange.
 
 Note: In the HTTP use of Digest authentication, the digest-uri is the URI (usually a URL) of the resource requested -- hence the name of the directive.
*/
- (NSString *)uri;


/*
 Indicates what "quality of protection" the client accepted. If present, it may appear exactly once and its value MUST be one of the alternatives in qop-options. If not present, it defaults to "auth". These values affect the computation of the response. Note that this is a single token, not a quoted list of alternatives.
*/
- (NSString *)qop;

/*
 The nc-value is the hexadecimal count of the number of requests (including the current request) that the client has sent with the nonce value in this request. For example, in the first request sent in response to a given nonce value, the client sends "nc=00000001". The purpose of this directive is to allow the server to detect request replays by maintaining its own copy of this count - if the same nc-value is seen twice, then the request is a replay. See the description below of the construction of the response value. This directive may appear at most once; if multiple instances are present, the client should abort the authentication exchange.
*/
- (NSString *)nc;

/*
 A client-specified data string which MUST be different each time a digest-response is sent as part of initial authentication. The cnonce-value is an opaque quoted string value provided by the client and used by both client and server to avoid chosen plaintext attacks, and to provide mutual authentication. The security of the implementation depends on a good choice. It is RECOMMENDED that it contain at least 64 bits of entropy. This directive is required and MUST be present exactly once; otherwise, authentication fails.
*/
- (NSString *)cnonce;

/*
 A string of 32 hex digits computed as defined below, which proves that the user knows a password. This directive is required and MUST be present exactly once; otherwise, authentication fails.
*/
- (NSString *)response;

@end
