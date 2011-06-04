#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

// Implements HTTPResponse protocol
@interface HTTPDataResponse : NSObject <HTTPResponse>
{

    /**
     
    **/
	NSUInteger offset;
    
    /**
      the data
    **/
	NSData *data;  
}

/**
    Initializes the HTTPDataResponse with data
    param NSDAta
    returns id
**/
- (id)initWithData:(NSData *)data;

@end
