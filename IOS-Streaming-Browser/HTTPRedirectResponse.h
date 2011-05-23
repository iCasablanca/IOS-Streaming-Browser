#import <Foundation/Foundation.h>
#import "HTTPResponse.h"


@interface HTTPRedirectResponse : NSObject <HTTPResponse>
{
	NSString *redirectPath;
}


/*
    Initialize the HTTPRedirectResponse with a redirectPath
 */
- (id)initWithPath:(NSString *)redirectPath;

@end
