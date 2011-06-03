#import "DDNumber.h"


@implementation NSNumber (DDNumber)

/**
    Class method
    Parse a string into a 64-bit signed integer
    param NSString
    param SInt64
    returns BOOL
**/
+ (BOOL)parseString:(NSString *)str 
         intoSInt64:(SInt64 *)pNum
{
    // Check if the passed-in string is nil, if so, return that we can't parse the string because it is nil
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, long long = 64 bit
    // converts string to long long
	*pNum = strtoll([str UTF8String], NULL, 10);
	
    // If there is an error
	if(errno != 0)
    {
		return NO;
        
	}else{ // if there is not an error
        
		return YES;
    }
}


/**
    Class method
    Parse a string into an unsigned 64-bit integer
    param NSString
    param UInt64
    returns BOOL
**/
+ (BOOL)parseString:(NSString *)str 
         intoUInt64:(UInt64 *)pNum
{
    // Check if the passed-in string is nil
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, unsigned long long = 64 bit
	// Converts string to unsigned long long
	*pNum = strtoull([str UTF8String], NULL, 10);
	
    // if there is an error
	if(errno != 0)
    {
		return NO;
    }else{ // if there is not an error
		return YES;
    }
}


/**
    Class method
    Parse a string into an NSInteger
    param NSString
    param NSInteger
    returns BOOL
**/
+ (BOOL)parseString:(NSString *)str 
      intoNSInteger:(NSInteger *)pNum
{
    // Check if the passed-in string is not empty
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On LP64, NSInteger = long = 64 bit
	// Otherwise, NSInteger = int = long = 32 bit
	// Converts strong to long
	*pNum = strtol([str UTF8String], NULL, 10);
	
	if(errno != 0) // if there is an error
    {
		return NO;
    }else{ // if there is not an error
		return YES;
    }
}


/**
    Class method
    Parse a string into an unsigned NSInteger
    param NSString
    param NSUInteger
    returns BOOL
**/
+ (BOOL)parseString:(NSString *)str 
     intoNSUInteger:(NSUInteger *)pNum
{
    // Check if the string is nil, and if so, return NO because there is no string to parse
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
    // This means the string is not nil
    
    
	errno = 0;
	
	// On LP64, NSUInteger = unsigned long = 64 bit
	// Otherwise, NSUInteger = unsigned int = unsigned long = 32 bit
	// Converts string to unsigned long
	*pNum = strtoul([str UTF8String], NULL, 10);
	
    
	if(errno != 0) // This means there was an error trying to parse the string
    {       
		return NO;
        
    }else{ // This means there was no error trying to parse the string

		return YES;
    }
}

@end
