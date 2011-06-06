#import "HTTPRedirectResponse.h"



@implementation HTTPRedirectResponse


/**
    @brief Initializes the HTTPRedirectResponse object with a path
    @param NSString
    @return id
**/
- (id)initWithPath:(NSString *)path
{
	if ((self = [super init]))
	{
		// Copies the path
		redirectPath = [path copy];
	}
	return self;
}

/**
    @brief Returns zero
    @return UInt64
**/
- (UInt64)contentLength
{
	return 0;
}

/**
    @brief Returns zero
    @return UInt64
**/
- (UInt64)offset
{
	return 0;
}

/**
    @brief Does nothing
    @param UInt64
    @return void
**/
- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

/**
    @brief Returns nil
    @param NSUInteger
    @return NSData
**/
- (NSData *)readDataOfLength:(NSUInteger)length
{
	return nil;
}

/**
    @brief Returns YES
    @return BOOL
**/
- (BOOL)isDone
{
	return YES;
}

/**
    @brief Returns an NSDictionary object with a 'Location' key, and a value as the redirect path
    @return NSDictionary
**/
- (NSDictionary *)httpHeaders
{	
	return [NSDictionary dictionaryWithObject:redirectPath forKey:@"Location"];
}

/**
    @brief Returns the integer 302
    @return NSInteger
**/
- (NSInteger)status
{	
	return 302;
}

/**
    @brief Standard deconstructor
    @return void
**/
- (void)dealloc
{	
	[redirectPath release];
	[super dealloc];
}

@end
