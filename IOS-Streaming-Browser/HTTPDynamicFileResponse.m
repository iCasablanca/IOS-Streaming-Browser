#import "HTTPDynamicFileResponse.h"
#import "HTTPConnection.h"


#define NULL_FD  -1


@implementation HTTPDynamicFileResponse


/**
    Initialize the HTTPDynamicFileResponse with a file path for
    a specific connection, separator string, and dictionary
    param NSSTring
    param HTTPConnection
    param NSString
    param NSDictionary
    returns id
**/
- (id)initWithFilePath:(NSString *)fpath
         forConnection:(HTTPConnection *)parent
             separator:(NSString *)separatorStr
 replacementDictionary:(NSDictionary *)dict
{
	if ((self = [super initWithFilePath:fpath forConnection:parent]))
	{
		// Sets the separator string
		separator = [[separatorStr dataUsingEncoding:NSUTF8StringEncoding] retain];
        
        // Sets the replacement dictionary
		replacementDict = [dict retain];
	}
	return self;
}

/**
    Whether using chunked encoding to transfer the response in a series of chunks with its own size indicator
    returns BOOL
**/
- (BOOL)isChunked
{
	
	return YES;
}

/**
    Does nothing
    returns UInt64
**/
- (UInt64)contentLength
{
	// This method shouldn't be called since we're using a chunked response.
	// We override it just to be safe.
	
	
	return 0;
}

/**
    Does nothing
    param UInt64
**/
- (void)setOffset:(UInt64)offset
{
	// This method shouldn't be called since we're using a chunked response.
	// We override it just to be safe.
	
}

/**
    If done reading the fule
**/
- (BOOL)isDone
{
    // if the readOffset is at the end of the file, and the readbuffer offet is zero
	BOOL result = (readOffset == fileLength) && (readBufferOffset == 0);
	
	
	return result;
}

/**
    Processes the read buffer
**/
- (void)processReadBuffer
{
	
	// At this point, the readBuffer has readBufferOffset bytes available.
	// This method is in charge of updating the readBufferOffset.
	
	NSUInteger bufLen = readBufferOffset;
	NSUInteger sepLen = [separator length]; // separator length
	
	// We're going to start looking for the separator at the beginning of the buffer,
	// and stop when we get to the point where the separator would no longer fit in the buffer.
	
	NSUInteger offset = 0;
    
    
	NSUInteger stopOffset = (bufLen > sepLen) ? bufLen - sepLen + 1 : 0;
	
	// In order to do the replacement, we need to find the starting and ending separator.
	// For example:
	// 
	// %%USER_NAME%%
	// 
	// Where "%%" is the separator.
	
	BOOL found1 = NO;
	BOOL found2 = NO;
	
	NSUInteger s1 = 0;
	NSUInteger s2 = 0;
	
    
    // Create a constant read only local attribute
	const void *sep = [separator bytes];
	
    
    // while the offset is less than the stop offset
	while (offset < stopOffset)
	{
        // Create a constant read only local attribute
		const void *subBuffer = readBuffer + offset;
	
        // compares the subbuffer to the separator
		if (memcmp(subBuffer, sep, sepLen) == 0)
		{
            
			if (!found1)
			{
				// Found the first separator
				
				found1 = YES;
				s1 = offset;
				offset += sepLen;
				
			}
			else
			{
				// Found the second separator
				
				found2 = YES;
				s2 = offset;
				offset += sepLen;
				
			} // found the 1st and 2nd separator
			
			if (found1 && found2)
			{
				// We found our separators.
				// Now extract the string between the two separators.
				
				NSRange fullRange = NSMakeRange(s1, (s2 - s1 + sepLen));
				NSRange strRange = NSMakeRange(s1 + sepLen, (s2 - s1 - sepLen));
				
				// Wish we could use the simple subdataWithRange method.
				// But that method copies the bytes...
				// So for performance reasons, we need to use the methods that don't copy the bytes.
				
				void *strBuf = readBuffer + strRange.location;
				NSUInteger strLen = strRange.length;
				
				NSString *key = [[NSString alloc] initWithBytes:strBuf length:strLen encoding:NSUTF8StringEncoding];

				if (key)
				{
					// Is there a given replacement for this key?
					
					NSString *value = [replacementDict objectForKey:key];
					if (value)
					{
						// Found the replacement value.
						// Now perform the replacement in the buffer.
						
						
						NSData *v = [value dataUsingEncoding:NSUTF8StringEncoding];

						NSUInteger vLength = [v length];
						
						if (fullRange.length == vLength)
						{
							// Replacement is exactly the same size as what it is replacing
							
							// memcpy(void *restrict dst, const void *restrict src, size_t n);
							
                            // copies vlength bytes from vbytes to the readbuffer
							memcpy(readBuffer + fullRange.location, [v bytes], vLength);
						}
						else // (fullRange.length != vLength)
						{
							NSInteger diff = (NSInteger)vLength - (NSInteger)fullRange.length;
							
							if (diff > 0)
							{
								// Replacement is bigger than what it is replacing.
								// Make sure there is room in the buffer for the replacement.
								
								if (diff > (readBufferSize - bufLen))
								{
									NSUInteger inc = MAX(diff, 256);
									
									readBufferSize += inc;
                                    
                                    // Resize the read buffer
									readBuffer = reallocf(readBuffer, readBufferSize);
								}
							}
							
							// Move the data that comes after the replacement.
							// 
							// If replacement is smaller than what it is replacing,
							// then we are shifting the data toward the beginning of the buffer.
							// 
							// If replacement is bigger than what it is replacing,
							// then we are shifting the data toward the end of the buffer.
							// 
							// memmove(void *dst, const void *src, size_t n);
							// 
							// The memmove() function copies n bytes from src to dst.
							// The two areas may overlap; the copy is always done in a non-destructive manner.
							
							void *src = readBuffer + fullRange.location + fullRange.length;
                            
							void *dst = readBuffer + fullRange.location + vLength;
							
							NSUInteger remaining = bufLen - (fullRange.location + fullRange.length);
							
                            // copy remaining bytes from source to destination
							memmove(dst, src, remaining);
							
							// Now copy the replacement into its location.
							// 
							// memcpy(void *restrict dst, const void *restrict src, size_t n)
							// 
							// The memcpy() function copies n bytes from src to dst.
							// If the two areas overlap, behavior is undefined.
							
							memcpy(readBuffer + fullRange.location, [v bytes], vLength);
							
							// And don't forget to update our indices.
							
							bufLen     += diff;
							offset     += diff;
							stopOffset += diff;
						}
					}
					
					[key release];
				}
				
				found1 = found2 = NO;
			}
		}
		else
		{
			offset++;
		}
	}
	
	// We've gone through our buffer now, and performed all the replacements that we could.
	// It's now time to update the amount of available data we have.
	
	if (readOffset == fileLength)
	{
		// We've read in the entire file.
		// So there can be no more replacements.
		
		data = [[NSData alloc] initWithBytes:readBuffer length:bufLen];
		readBufferOffset = 0;
	}
	else  // if the read offset is not equal to the file length
	{
		// There are a couple different situations that we need to take into account here.
		// 
		// Imagine the following file:
		// My name is %%USER_NAME%%
		// 
		// Situation 1:
		// The first chunk of data we read was "My name is %%".
		// So we found the first separator, but not the second.
		// In this case we can only return the data that precedes the first separator.
		// 
		// Situation 2:
		// The first chunk of data we read was "My name is %".
		// So we didn't find any separators, but part of a separator may be included in our buffer.
		
		NSUInteger available;
		if (found1)
		{
			// Situation 1
			available = s1;
		}
		else
		{
			// Situation 2
			available = stopOffset;
		}
		
		// Copy available data
		
		data = [[NSData alloc] initWithBytes:readBuffer length:available];
		
		// Remove the copied data from the buffer.
		// We do this by shifting the remaining data toward the beginning of the buffer.
		
		NSUInteger remaining = bufLen - available;
		
        // copies a byte string
		memmove(readBuffer, readBuffer + available, remaining);
        
        // set the read buffer's offset to the remaining bytes 
		readBufferOffset = remaining;
	}
	
    //This informs us that the response object has generated more data that we may be able to send.
	[connection responseHasAvailableData:self];
}

/**
    Standard deconstructor
**/
- (void)dealloc
{
	
	[separator release];
	[replacementDict release];
	
	[super dealloc];
}

@end
