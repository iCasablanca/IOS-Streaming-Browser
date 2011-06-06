#import "HTTPDataResponse.h"



@implementation HTTPDataResponse


/**
    @brief Initializes the HTTPDataResponse with data
    @param NSData
    @return id
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
    @brief Standard deconstructor
    @returm void
**/
- (void)dealloc
{
	
	[data release];
	[super dealloc];
}

/**
    @brief Returns the length of the data as an unsigned 64-bit integer 
    @return UInt64
**/
- (UInt64)contentLength
{
    // Get the number of bytes of data
	UInt64 result = (UInt64)[data length];
	return result;
}


/**
    @brief Returns the offset to the data
    @return UInt64
**/
- (UInt64)offset
{
	return offset;
}

/**
    @brief Sets the offset to the data
    @param UInt64
    @return void
**/
- (void)setOffset:(UInt64)offsetParam
{	
	offset = (NSUInteger)offsetParam;
}

/**
    @brief Returns the data of a certain length
    @param NSUInteger
    @return NSData
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
    @brief Returns whether done reading the data
    @return BOOL
**/
- (BOOL)isDone
{
    // If the offset is at the end of the data
	BOOL result = (offset == [data length]);	
	
	return result;
}

@end
