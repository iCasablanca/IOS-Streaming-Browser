#import <Foundation/Foundation.h>


@interface NSNumber (DDNumber)


/*
    class method
    Parse a string into a signed 64-bit integer
    param NSString
    param SInt64
    returns BOOL
 */
+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum;

/*
    class method
    Parse a string into an unsigned 64-bit integer
    param NSString
    param UInt64
    returns BOOL
 */
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum;

/*
    class method
    Parse string into signed NSInteger
    param NSString
    param NSInteger
    returns BOOL
 */
+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum;

/*
    class method
    Parse string into an unsigned NSInteger
    param NSString
    param NSUInteger
    returns BOOL
 */
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum;

@end
