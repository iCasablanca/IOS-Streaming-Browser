#import <Foundation/Foundation.h>


@interface NSNumber (DDNumber)


/*
    class method
 */
+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum;

/*
    class method
 */
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum;

/*
    class method
 */
+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum;

/*
    class method
 */
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum;

@end
