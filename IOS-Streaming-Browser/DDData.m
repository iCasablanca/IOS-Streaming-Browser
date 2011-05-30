#import "DDData.h"
#import <CommonCrypto/CommonDigest.h>


@implementation NSData (DDData)

static char encodingTable[64] = {
'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };


/*
 
 */
- (NSData *)md5Digest
{
    
    // Creates unsigned character with value of 16
    // unsigned char has a range of 0 to 255
	unsigned char result[CC_MD5_DIGEST_LENGTH];  // 16- digest length in bytes */
    
    
    
    CC_MD5([self bytes], (CC_LONG)[self length], result);
    
    
    return [NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH];
}

/*
   SHA-1 (Secure Hash Algorithm) is a cryptographic hash function with a 160 bit output.
 */
- (NSData *)sha1Digest
{
    // unsigned char has a range of 0 to 255
	unsigned char result[CC_SHA1_DIGEST_LENGTH]; // 20 - digest length in bytes 
    
    
    // CC_SHA1 computes the SHA-1 message digest of the len bytes at data and places it in md (i.e. [self length]) (which must have space for CC_SHA1_DIGEST_LENGTH == 20 bytes of output). It returns the md pointer.
	CC_SHA1([self bytes], (CC_LONG)[self length], result);
    
    
    // CC_SHA1_DIGEST_LENGTH is 20 bytes long
    return [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
}

/*
    
    returns NSString
 */
- (NSString *)hexStringValue
{
    // Create a string buffer 
	NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([self length] * 2)];
	
    // Create a constant read only local attribute
    // unsigned char has a range of 0 to 255
    const unsigned char *dataBuffer = [self bytes];
    
    // int is a valued from 0 to 2,147,483,647
    int i;
    
    for (i = 0; i < [self length]; ++i)
	{
        // The 02 prefix makes sure the hex values are zero-padded
        [stringBuffer appendFormat:@"%02x", (unsigned long)dataBuffer[i]];
	}
    
    // Returns a copy of the stringBuffer and then autoreleases it
    return [[stringBuffer copy] autorelease];
}

/*
    
    returns NSString
 */
- (NSString *)base64Encoded
{
    // Create a constant read only local attribute
    // unsigned char has a range of 0 to 255
	const unsigned char	*bytes = [self bytes];
    
    // Creates a mutable string with a capacity equal to the length of the data
	NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
    
    
    // Value is 0 to 2,147,483,647
	unsigned long ixtext = 0;
    
    // Value is 0 to 2,147,483,647
	unsigned long lentext = [self length];
    
    // Count remaining
	long ctremaining = 0; 
    
    // unsigned char has a range of 0 to 255
	unsigned char inbuf[3], outbuf[4];
    
    // short has a range of 0 to 32,768
	unsigned short i = 0;
    
    // short has a range of 0 to 32,768
	unsigned short charsonline = 0;

    // count copy
    unsigned short ctcopy = 0; 
    
    // Value is 0 to 2,147,483,647
	unsigned long ix = 0;
	
	while( YES )
	{
        // count remainting
		ctremaining = lentext - ixtext;
        
        // if the count remaining is less than or equal to zero
		if( ctremaining <= 0 )
        {
            break;
		}
        
        
		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
            
			if( ix < lentext ) 
            {
                inbuf[i] = bytes[ix];
                
			}else{
                inbuf [i] = 0;
            }
		}
		
		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
        
        // Count copy
		ctcopy = 4;
		
		switch( ctremaining ) // count remaining
		{
			case 1:
				ctcopy = 2; // count copy
				break;
			case 2:
				ctcopy = 3; // count copy
				break;
		}
		
		for( i = 0; i < ctcopy; i++ )
        {
			[result appendFormat:@"%c", encodingTable[outbuf[i]]];
		}
        
        
		for( i = ctcopy; i < 4; i++ )
        {
			[result appendString:@"="];
		}
        
        
		ixtext += 3;
        
        
		charsonline += 4;
	}
	
	return [NSString stringWithString:result];
}


/*
 
 */
- (NSData *)base64Decoded
{
    // Create a constant read only local attribute
    // unsigned char has a range of 0 to 255
	const unsigned char	*bytes = [self bytes];
    
    // NSMutableData (and its superclass NSData) provide data objects, object-oriented wrappers for byte buffers
	NSMutableData *result = [NSMutableData dataWithCapacity:[self length]];
	
    // Value is 0 to 2,147,483,647
	unsigned long ixtext = 0;
    
    // Value is 0 to 2,147,483,647
	unsigned long lentext = [self length];
    
    // ch has a range of 0 to 255
	unsigned char ch = 0;
    
    // unsigned char has a range of 0 to 255
	unsigned char inbuf[4], outbuf[3];
    
    // short has a range of 0 to 32,768
	short i = 0;

    // short has a range of 0 to 32,768
    short ixinbuf=0;
    
    // flag to ignore
	BOOL flignore = NO;  
    
    // flag for end text
	BOOL flendtext = NO; 
	
	while( YES )
	{
		if( ixtext >= lentext ) 
        {
            break;
        }
        
        
		ch = bytes[ixtext++];
        
        // flag to ignore
		flignore = NO;
		
		if( ( ch >= 'A' ) && ( ch <= 'Z' ) ) 
        {
            ch = ch - 'A';
		}else if( ( ch >= 'a' ) && ( ch <= 'z' ) ) 
        {
            ch = ch - 'a' + 26;
		}else if( ( ch >= '0' ) && ( ch <= '9' ) ) 
        {    
            ch = ch - '0' + 52;
		}else if( ch == '+' )
        {    
            ch = 62;
		}else if( ch == '=' ) 
        {    
            flendtext = YES;
		}else if( ch == '/' ) 
        {    
            ch = 63;
		}else
        {    
            flignore = YES;
		}
        
        // if not ignoring
		if( ! flignore )
		{
            // count of characters in the input buffer
            // short has a range of 0 to 32,768
			short ctcharsinbuf = 3;
            
            // flag to break
			BOOL flbreak = NO;
		
            // flag to end text
			if( flendtext )
			{
				if( ! ixinbuf )
                {    
                    break;
                }
                
                
				if( ( ixinbuf == 1 ) || ( ixinbuf == 2 ) ) 
                {    
                    // count of characters in the input buffer
                    ctcharsinbuf = 1;
                }else{ 
                    
                    // count of characters in the input buffer
                    ctcharsinbuf = 2;
                }
                
                
				ixinbuf = 3;
				flbreak = YES;
			}
			
            
			inbuf [ixinbuf++] = ch;
			
			if( ixinbuf == 4 )
			{
				ixinbuf = 0;
				outbuf [0] = ( inbuf[0] << 2 ) | ( ( inbuf[1] & 0x30) >> 4 );
				outbuf [1] = ( ( inbuf[1] & 0x0F ) << 4 ) | ( ( inbuf[2] & 0x3C ) >> 2 );
				outbuf [2] = ( ( inbuf[2] & 0x03 ) << 6 ) | ( inbuf[3] & 0x3F );
				
                
                // for each of the characters in the buffer
				for( i = 0; i < ctcharsinbuf; i++ )
					[result appendBytes:&outbuf[i] length:1];
			}
			
			if( flbreak )  break;
		}
	}
	
	return [NSData dataWithData:result];
}

@end
