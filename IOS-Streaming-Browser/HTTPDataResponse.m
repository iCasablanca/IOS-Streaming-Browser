#import "HTTPDataResponse.h"



@implementation HTTPDataResponse


/*
    Initializes the HTTPDataResponse with data
 */
- (id)initWithData:(NSData *)dataParam
{
    
	if((self = [super init]))
	{
		
		offset = 0;  // Set offset to data as zero
		data = [dataParam retain];
	}
	return self;
}

/*
    Standard deconstructor
 */
- (void)dealloc
{
	
	[data release];
	[super dealloc];
}

/*
    Returns the length of the data as an unsigned 64-bit integer 
 */
- (UInt64)contentLength
{
	UInt64 result = (UInt64)[data length];
	return result;
}


/*
    Returns the offset to the data
 */
- (UInt64)offset
{
	
	return offset;
}

/*
    Sets the offset to the data
 */
- (void)setOffset:(UInt64)offsetParam
{
	
	offset = (NSUInteger)offsetParam;
}

/*
    Returns the data of a certain length
 */
- (NSData *)readDataOfLength:(NSUInteger)lengthParameter
{
	
	NSUInteger remaining = [data length] - offset;
	NSUInteger length = lengthParameter < remaining ? lengthParameter : remaining;
	
	void *bytes = (void *)([data bytes] + offset);
	
    // Increases the offset by the length of data just read
	offset += length;
	
	return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];
}

/*
    Returns whether done reading the data
 */
- (BOOL)isDone
{
	BOOL result = (offset == [data length]);
	
	
	return result;
}

@end
