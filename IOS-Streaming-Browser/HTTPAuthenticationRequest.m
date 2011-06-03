#import "HTTPAuthenticationRequest.h"
#import "HTTPMessage.h"



@interface HTTPAuthenticationRequest (PrivateAPI)
- (NSString *)quotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header;
- (NSString *)nonquotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header;
@end


@implementation HTTPAuthenticationRequest


/**
    Initialize the HTTPAuthenticationRequest with an HTTPMessage
    param HTTPMessage
    returns id
**/
- (id)initWithRequest:(HTTPMessage *)request
{
	if ((self = [super init]))
	{
        // Get the Authorization header field from the HTTP message
		NSString *authInfo = [request headerField:@"Authorization"];
		
        // Set the basic authentication flag to no
		isBasic = NO;
        
        // Check if the authorization header field to see if it has length greater than or equal to 6 characters. (i.e. the word 'Basic' plus a space
		if ([authInfo length] >= 6)
		{
            
            // Returns a new string containing the characters of the receiver up to, but not including, the one at a given index
			isBasic = [[authInfo substringToIndex:6] caseInsensitiveCompare:@"Basic "] == NSOrderedSame;
		}
		
        // Set the digest authentication flag to no
		isDigest = NO;
        
        // Check is the authorization header field is 'Digest'
		if ([authInfo length] >= 7)
		{
            // a new string containing the characters of the receiver up to, but not including, the one at a given index.
			isDigest = [[authInfo substringToIndex:7] caseInsensitiveCompare:@"Digest "] == NSOrderedSame;
		}
		
        // if using basic authentication
		if (isBasic)
		{
            
            // Gets the substring in the 7th position, makes a copy, and then schedules it for autorelease
			NSMutableString *temp = [[[authInfo substringFromIndex:6] mutableCopy] autorelease];
            
            // Trims any whitespace from the string
			CFStringTrimWhitespace((CFMutableStringRef)temp);
			
            // Copies the value in the temp string to the base64Credentials variable
			base64Credentials = [temp copy];
		}
		
        
        // If using digest authentication
		if (isDigest)
		{
            // Get the username from the header
			username = [[self quotedSubHeaderFieldValue:@"username" fromHeaderFieldValue:authInfo] retain];
            
            // Get the realm from the header
			realm    = [[self quotedSubHeaderFieldValue:@"realm" fromHeaderFieldValue:authInfo] retain];
            
            // Get the nonce from the header
			nonce    = [[self quotedSubHeaderFieldValue:@"nonce" fromHeaderFieldValue:authInfo] retain];
            
            // Get the URI from the header
			uri      = [[self quotedSubHeaderFieldValue:@"uri" fromHeaderFieldValue:authInfo] retain];
			
			// It appears from RFC 2617 that the qop is to be given unquoted
			// Tests show that Firefox performs this way, but Safari does not
			// Thus we'll attempt to retrieve the value as nonquoted, but we'll verify it doesn't start with a quote
			qop      = [self nonquotedSubHeaderFieldValue:@"qop" fromHeaderFieldValue:authInfo];
            
            // If there is a quality of protection setting
			if(qop && ([qop characterAtIndex:0] == '"'))
			{
                // gets the quality of protection
                // Possible values are:
                //  auth-int indicate authentication with integrity protection
                //  auth-param
				qop  = [self quotedSubHeaderFieldValue:@"qop" fromHeaderFieldValue:authInfo];
			}
            
            // Increment the reference count for the quality of protection
			[qop retain];
			
            //Retrieves a nonquoted "Sub Header Field Value" from a given header field value.
			nc       = [[self nonquotedSubHeaderFieldValue:@"nc" fromHeaderFieldValue:authInfo] retain];
            
            // Retrieves a quoted "Sub Header Field Value" from a given header field value.
			cnonce   = [[self quotedSubHeaderFieldValue:@"cnonce" fromHeaderFieldValue:authInfo] retain];
            
            // Retrieves a quoted "Sub Header Field Value" from a given header field value.
			response = [[self quotedSubHeaderFieldValue:@"response" fromHeaderFieldValue:authInfo] retain];
		}
	}
	return self;
}

/**
    Deconstructor
**/
- (void)dealloc
{
	[base64Credentials release];
	[username release];
	[realm release];
	[nonce release];
	[uri release];
	[qop release];
	[nc release];
	[cnonce release];
	[response release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
    Gets whether basic authentication
    returns BOOL
**/
- (BOOL)isBasic {
	return isBasic;
}


/**
    Whether digest authentication
    returns BOOL
**/
- (BOOL)isDigest {
	return isDigest;
}


/**
    Returns base64 credentials
    returns NSString
**/
- (NSString *)base64Credentials {
	return base64Credentials;
}

/**
    Returns the username
    The user's name in the specified realm, encoded according to the value of the "charset" directive. This directive is required and MUST be present exactly once; otherwise, authentication fails.
**/
- (NSString *)username {
	return username;
}


/**
    Returns the realm
    The realm containing the user's account. This directive is required if the server provided any realms in the "digest-challenge", in which case it may appear exactly once and its value SHOULD be one of those realms. If the directive is missing, "realm-value" will set to the empty string when computing A1 (see below for details).
**/
- (NSString *)realm {
	return realm;
}


/**
    Returns the nonce
    The server-specified data string received in the preceding digest-challenge. This directive is required and MUST be present exactly once; otherwise, authentication fails.
**/
- (NSString *)nonce {
	return nonce;
}

/**
    Returns the URI
**/
- (NSString *)uri {
	return uri;
}


/**
    Returns the quality of protection
    Indicates what "quality of protection" the client accepted. If present, it may appear exactly once and its value MUST be one of the alternatives in qop-options. If not present, it defaults to "auth". These values affect the computation of the response. Note that this is a single token, not a quoted list of alternatives.

**/
- (NSString *)qop {
	return qop;
}


/**
    Returns the nonce count
    The nc-value is the hexadecimal count of the number of requests (including the current request) that the client has sent with the nonce value in this request. For example, in the first request sent in response to a given nonce value, the client sends "nc=00000001". The purpose of this directive is to allow the server to detect request replays by maintaining its own copy of this count - if the same nc-value is seen twice, then the request is a replay. See the description below of the construction of the response value. This directive may appear at most once; if multiple instances are present, the client should abort the authentication exchange.
**/
- (NSString *)nc {
	return nc;
}


/**
    A cnonce is a a client-specified data string which MUST be different
    each time a digest-response is sent as part of initial authentication.
    The cnonce-value is an opaque quoted string value provided by the client
    and used by both client and server to avoid chosen plaintext attacks,
    and to provide mutual authentication. The security of the implementation
    depends on a good choice. It is RECOMMENDED that it contain at least 64
    bits of entropy. This directive is required and MUST be present exactly
    once; otherwise, authentication fails.
**/
- (NSString *)cnonce {
	return cnonce;
}

/**
    Returns the response
    A string of 32 hex digits computed as defined below, which proves that the user knows a password. This directive is required and MUST be present exactly once; otherwise, authentication fails.
**/
- (NSString *)response {
	return response;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Retrieves a "Sub Header Field Value" from a given header field value.
 * The sub header field is expected to be quoted.
 * 
 * In the following header field:
 * Authorization: Digest username="Mufasa", qop=auth, response="6629fae4939"
 * The sub header field titled 'username' is quoted, and this method would return the value @"Mufasa".
**/
- (NSString *)quotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header
{
    
    // Finds and returns the range of the first occurrence of the parameter withing the header
	NSRange startRange = [header rangeOfString:[NSString stringWithFormat:@"%@=\"", param]];
    
    // If the parameter was not found anywhere within the header
	if(startRange.location == NSNotFound)
	{
		
		return nil;
	}
	
    // Gets the location after the parameter
	NSUInteger postStartRangeLocation = startRange.location + startRange.length;
    
    // The header length minus the length of the location found in the header.  This is provides the for everything in the header after the last parameter
	NSUInteger postStartRangeLength = [header length] - postStartRangeLocation;
    
    // Creates a new range with a start location after the parameter to the end of the header
	NSRange postStartRange = NSMakeRange(postStartRangeLocation, postStartRangeLength);
	
    // Finds the the location of the next quotation mark
	NSRange endRange = [header rangeOfString:@"\"" options:0 range:postStartRange];
    
    // If the ending quotation mark is not found
	if(endRange.location == NSNotFound)
	{
		// The ending quote was not found anywhere in the header
		return nil;
	}
	
    
    // Made it to this point in the method, this means an end quote was found
    
    // Creates a range from the start location to the end location
	NSRange subHeaderRange = NSMakeRange(postStartRangeLocation, endRange.location - postStartRangeLocation);
    
    // Returns the string of the subheader
	return [header substringWithRange:subHeaderRange];
}

/**
 * Retrieves a "Sub Header Field Value" from a given header field value.
 * The sub header field is expected to not be quoted.
 * 
 * In the following header field:
 * Authorization: Digest username="Mufasa", qop=auth, response="6629fae4939"
 * The sub header field titled 'qop' is nonquoted, and this method would return the value @"auth".
**/
- (NSString *)nonquotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header
{
    
    // Finds the begining of the range
	NSRange startRange = [header rangeOfString:[NSString stringWithFormat:@"%@=", param]];
    
    // The param was not found anywhere in the header    
	if(startRange.location == NSNotFound)
	{
		return nil;
	}
	
    
    // Gets the starting location of the range
	NSUInteger postStartRangeLocation = startRange.location + startRange.length;
    
    // Gets the length of from the startRange location to the end of the header
	NSUInteger postStartRangeLength = [header length] - postStartRangeLocation;
    
    // Creates a new range from the starting location, and a length from the start location to the end of the header
	NSRange postStartRange = NSMakeRange(postStartRangeLocation, postStartRangeLength);
	
    // Search for a comma
	NSRange endRange = [header rangeOfString:@"," options:0 range:postStartRange];
    
    
	if(endRange.location == NSNotFound)
	{
		// The ending comma was not found anywhere in the header
		// However, if the nonquoted param is at the end of the string, there would be no comma
		// This is only possible if there are no spaces anywhere
		NSRange endRange2 = [header rangeOfString:@" " options:0 range:postStartRange];
		if(endRange2.location != NSNotFound)
		{
			return nil;
		}
		else
		{
			return [header substringWithRange:postStartRange];
		}
	}
	else // If a comma was found
	{
        // Create a new range from the start location to the comma
		NSRange subHeaderRange = NSMakeRange(postStartRangeLocation, endRange.location - postStartRangeLocation);
        
        // Returns the subHeader
		return [header substringWithRange:subHeaderRange];
	}
}

@end
