#import "HTTPRedirectResponse.h"



@implementation HTTPRedirectResponse


/*
    Initializes the HTTPRedirectResponse object with a path
    param NSString
    returns id
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
    returns UInt64
*/
- (UInt64)contentLength
{
	return 0;
}

/*
    Returns zero
    returns UInt64
*/
- (UInt64)offset
{
	return 0;
}

/*
    Does nothing
    param UInt64
*/
- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

/*
    Returns nil
    param NSUInteger
    returns NSData
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
    Returns an NSDictionary object with a 'Location' key, and a value as the redirect path
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
