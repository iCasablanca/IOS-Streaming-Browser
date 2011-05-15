#import "HTTPRedirectResponse.h"



@implementation HTTPRedirectResponse

- (id)initWithPath:(NSString *)path
{
	if ((self = [super init]))
	{
		
		redirectPath = [path copy];
	}
	return self;
}

- (UInt64)contentLength
{
	return 0;
}

- (UInt64)offset
{
	return 0;
}

- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	
	return nil;
}

- (BOOL)isDone
{
	return YES;
}

- (NSDictionary *)httpHeaders
{
	
	return [NSDictionary dictionaryWithObject:redirectPath forKey:@"Location"];
}

- (NSInteger)status
{
	
	return 302;
}

- (void)dealloc
{
	
	[redirectPath release];
	[super dealloc];
}

@end
