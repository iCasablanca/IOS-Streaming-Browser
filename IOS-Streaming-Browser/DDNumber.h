#import <Foundation/Foundation.h>


@interface NSNumber (DDNumber)


/**
    class method
    @brief Parse a string into a signed 64-bit integer
    @param NSString
    @param SInt64
    @return BOOL
**/
+ (BOOL)parseString:(NSString *)str 
         intoSInt64:(SInt64 *)pNum;

/**
    class method
    @Parse a string into an unsigned 64-bit integer
    @param NSString
    @param UInt64
    @return BOOL
**/
+ (BOOL)parseString:(NSString *)str 
         intoUInt64:(UInt64 *)pNum;

/**
    class method
    @Parse string into signed NSInteger
    @param NSString
    @param NSInteger
    @return BOOL
**/
+ (BOOL)parseString:(NSString *)str 
      intoNSInteger:(NSInteger *)pNum;

/**
    class method
    @Parse string into an unsigned NSInteger
    @param NSString
    @param NSUInteger
    @return BOOL
**/
+ (BOOL)parseString:(NSString *)str 
     intoNSUInteger:(NSUInteger *)pNum;

@end
