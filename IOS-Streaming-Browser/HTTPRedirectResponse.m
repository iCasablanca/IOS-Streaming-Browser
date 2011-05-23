#import "HTTPRedirectResponse.h"



@implementation HTTPRedirectResponse


/*
    Initializes the HTTPRedirectResponse object with a path
 */
- (id)initWithPath:(NSString *)path
{
	if ((self = [super init]))
	{
		
		redirectPath = [path copy];
	}
	return self;
}

/*
    Returns zero
 */
- (UInt64)contentLength
{
	return 0;
}

/*
    Returns zero
 */
- (UInt64)offset
{
	return 0;
}

/*
    Does nothing
 */
- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

/*
    Returns nil
 */
- (NSData *)readDataOfLength:(NSUInteger)length
{
	
	return nil;
}

/*
    Returns YES
 */
- (BOOL)isDone
{
	return YES;
}

/*
    
 */
- (NSDictionary *)httpHeaders
{
	
	return [NSDictionary dictionaryWithObject:redirectPath forKey:@"Location"];
}

/*
    Returns the integer 302
 */
- (NSInteger)status
{
	
	return 302;
}

/*
    Standard deconstructor
 */
- (void)dealloc
{
	
	[redirectPath release];
	[super dealloc];
}

@end
