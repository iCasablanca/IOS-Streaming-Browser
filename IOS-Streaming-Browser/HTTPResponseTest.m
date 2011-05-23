#import "HTTPResponseTest.h"
#import "HTTPConnection.h"


// 
// This class is a UnitTest for the delayResponeHeaders capability of HTTPConnection
// 

@interface HTTPResponseTest (PrivateAPI)
- (void)doAsyncStuff;
- (void)asyncStuffFinished;
@end


@implementation HTTPResponseTest


/*
    Initialize the HTTPResponseTest
*/
- (id)initWithConnection:(HTTPConnection *)parent
{
	if ((self = [super init]))
	{
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
		connectionQueue = dispatch_get_current_queue();
		dispatch_retain(connectionQueue);
		
		readyToSendResponseHeaders = NO;
		
		dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
		dispatch_async(concurrentQueue, ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			[self doAsyncStuff];
			[pool release];
		});
	}
	return self;
}


/*
 
*/
- (void)doAsyncStuff
{
	// This method is executed on a global concurrent queue
	
	
	[NSThread sleepForTimeInterval:5.0];
	
	dispatch_async(connectionQueue, ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[self asyncStuffFinished];
		[pool release];
	});
}


/*
 
*/
- (void)asyncStuffFinished
{
	// This method is executed on the connectionQueue
	
	
	readyToSendResponseHeaders = YES;
	[connection responseHasAvailableData:self];
}


/*
 
*/
- (BOOL)delayResponeHeaders
{
	
	return !readyToSendResponseHeaders;
}


/*
 
*/
- (void)connectionDidClose
{
	// This method is executed on the connectionQueue
	
	
	connection = nil;
}


/*
 
*/
- (UInt64)contentLength
{
	
	return 0;
}


/*
 
*/
- (UInt64)offset
{
	
	return 0;
}


/*
 
*/
- (void)setOffset:(UInt64)offset
{
	
	// Ignored
}


/*
 
*/
- (NSData *)readDataOfLength:(NSUInteger)length
{
	
	return nil;
}


/*
 
*/
- (BOOL)isDone
{
	
	return YES;
}

/*
    Standard deconstructor
*/
- (void)dealloc
{
	
	dispatch_release(connectionQueue);
	[super dealloc];
}

@end
