#import "DDNumber.h"


@implementation NSNumber (DDNumber)

/*
    Class method
 */
+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, long long = 64 bit
	
	*pNum = strtoll([str UTF8String], NULL, 10);
	
	if(errno != 0)
    {
		return NO;
	}else{
		return YES;
    }
}


/*
    Class method
 */
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, unsigned long long = 64 bit
	
	*pNum = strtoull([str UTF8String], NULL, 10);
	
	if(errno != 0)
    {
		return NO;
    }else{
		return YES;
    }
}


/*
    Class method
 */
+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On LP64, NSInteger = long = 64 bit
	// Otherwise, NSInteger = int = long = 32 bit
	
	*pNum = strtol([str UTF8String], NULL, 10);
	
	if(errno != 0)
    {
		return NO;
    }else{
		return YES;
    }
}


/*
    Class method
 */
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum
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
	
	*pNum = strtoul([str UTF8String], NULL, 10);
	
    
	if(errno != 0) // This means there was an error trying to parse the string
    {       
		return NO;
    }else{ // This means there was no error trying to parse the string
		return YES;
    }
}

@end
