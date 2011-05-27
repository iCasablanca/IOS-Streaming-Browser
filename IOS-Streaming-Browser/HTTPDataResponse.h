#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

// Implements HTTPResponse protocol
@interface HTTPDataResponse : NSObject <HTTPResponse>
{
	NSUInteger offset;
	NSData *data;  // the data
}

/*
    Initializes the HTTPDataResponse with data
 */
- (id)initWithData:(NSData *)data;

@end
