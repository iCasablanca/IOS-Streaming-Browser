#import "HTTPDataResponse.h"



@implementation HTTPDataResponse


/**
    Initializes the HTTPDataResponse with data
    param NSData
    returns id
**/
- (id)initWithData:(NSData *)dataParam
{
    
	if((self = [super init]))
	{
		
		offset = 0;  // Set offset to data as zero
		data = [dataParam retain];
	}
	return self;
}

/**
    Standard deconstructor
**/
- (void)dealloc
{
	
	[data release];
	[super dealloc];
}

/**
    Returns the length of the data as an unsigned 64-bit integer 
    returns UInt64
**/
- (UInt64)contentLength
{
    // Get the number of bytes of data
	UInt64 result = (UInt64)[data length];
	return result;
}


/**
    Returns the offset to the data
    returns UInt64
**/
- (UInt64)offset
{
	return offset;
}

/**
    Sets the offset to the data
    param UInt64
**/
- (void)setOffset:(UInt64)offsetParam
{	
	offset = (NSUInteger)offsetParam;
}

/**
    Returns the data of a certain length
    param NSUInteger
    returns NSData
**/
- (NSData *)readDataOfLength:(NSUInteger)lengthParameter
{
	// Number of bytes yet to read
	NSUInteger remaining = [data length] - offset;

    // Get the lesser of the length or the number of bytes remaining to read
	NSUInteger length = lengthParameter < remaining ? lengthParameter : remaining;
	
    
	void *bytes = (void *)([data bytes] + offset);
	
    // Increases the offset by the length of data just read
	offset += length;
	
    // Gets the data of a certain length
	return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];
}

/**
    Returns whether done reading the data
    returns BOOL
**/
- (BOOL)isDone
{
    // If the offset is at the end of the data
	BOOL result = (offset == [data length]);	
	
	return result;
}

@end
