#import "DDRange.h"
#import "DDNumber.h"

/**
    Note: C-style method
    param DDRange - DDRange is the functional equivalent of a 64 bit NSRange.
    param DDRange -  DDRange is the functional equivalent of a 64 bit NSRange.
    returns DDRange
 **/
DDRange DDUnionRange(DDRange range1, DDRange range2)
{
	DDRange result;
	
	result.location = MIN(range1.location, range2.location);
	result.length   = MAX(DDMaxRange(range1), DDMaxRange(range2)) - result.location;
	
	return result;
}

/**
     Note: C-style method
    param DDRange - DDRange is the functional equivalent of a 64 bit NSRange.
    param DDRange
    returns DDRange
**/
DDRange DDIntersectionRange(DDRange range1, DDRange range2)
{
    // DDRange is the functional equivalent of a 64 bit NSRange.
	DDRange result;
	
    // if the maximum range location less than location of range2, or
    // maximum range2 location less than range1 location
	if((DDMaxRange(range1) < range2.location) || (DDMaxRange(range2) < range1.location))
	{
        // Make a range with zero length and location of zero
		return DDMakeRange(0, 0);
	}
	
	result.location = MAX(range1.location, range2.location);
    
    
	result.length   = MIN(DDMaxRange(range1), DDMaxRange(range2)) - result.location;
	
	return result;
}

/**
     Note: C-style method
    param DDRange
    returns NSString
**/
NSString *DDStringFromRange(DDRange range)
{
    // Creates a string with the location and length of a range
	return [NSString stringWithFormat:@"{%qu, %qu}", range.location, range.length];
}

/**
    Creates a DDRange from a string 
    Note: C-style method
    param NSString
    returns DDRange
**/
DDRange DDRangeFromString(NSString *aString)
{
    // DDRange is the functional equivalent of a 64 bit NSRange
	DDRange result = DDMakeRange(0, 0);
	
	// NSRange will ignore '-' characters, but not '+' characters
	NSCharacterSet *cset = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
	
    // programmatic interface for an object that scans values from an NSString object.
	NSScanner *scanner = [NSScanner scannerWithString:aString];
    
    // Sets the set of characters to ignore when scanning for a value representation.
	[scanner setCharactersToBeSkipped:[cset invertedSet]];
	
    
	NSString *str1 = nil;
	NSString *str2 = nil;
	
    // Scans the string as long as characters from a given character set are encountered, accumulating characters into a string that’s returned by reference.
	BOOL found1 = [scanner scanCharactersFromSet:cset intoString:&str1];
    
    //Scans the string as long as characters from a given character set are encountered, accumulating characters into a string that’s returned by reference.
	BOOL found2 = [scanner scanCharactersFromSet:cset intoString:&str2];
	
    // Put the location in the result.location address
	if(found1) [NSNumber parseString:str1 intoUInt64:&result.location];

	// Pugs the length in the result.length address
    if(found2) [NSNumber parseString:str2 intoUInt64:&result.length];
	
	return result;
}

/**
     Note: C-style method
    param DDRangePointer
    param DDRangePointer
    returns NSInteger
**/
NSInteger DDRangeCompare(DDRangePointer pDDRange1, DDRangePointer pDDRange2)
{
	// Comparison basis:
	// Which range would you encouter first if you started at zero, and began walking towards infinity.
	// If you encouter both ranges at the same time, which range would end first.
	
    // Check if the location from range 1 is less than the location from range2
	if(pDDRange1->location < pDDRange2->location)
	{
		return NSOrderedAscending;
	}
    
    // Check if the location from range1 is greater than the location from range2
	if(pDDRange1->location > pDDRange2->location)
	{
		return NSOrderedDescending;
	}
    
    // Check if the length from range1 is less than the length from range2
	if(pDDRange1->length < pDDRange2->length)
	{
		return NSOrderedAscending;
	}
    
    // Check if the length from range1 is greater than the length for range2
	if(pDDRange1->length > pDDRange2->length)
	{
		return NSOrderedDescending;
	}
	
	return NSOrderedSame;
}

@implementation NSValue (NSValueDDRangeExtensions)

/**
    Class method
    param DDRange
    returns NSValue
**/
+ (NSValue *)valueWithDDRange:(DDRange)range
{
    
	return [NSValue valueWithBytes:&range objCType:@encode(DDRange)];
}


/**
    returns DDRange
**/
- (DDRange)ddrangeValue
{
    // DDRange is the functional equivalent of a 64 bit NSRange
	DDRange result;
    
    // Get the address of the result
	[self getValue:&result];
    
    
	return result;
}

/**
    param NSValue
    returns NSInteger
**/
- (NSInteger)ddrangeCompare:(NSValue *)other
{
    // DDRange is the functional equivalent of a 64 bit NSRange
	DDRange r1 = [self ddrangeValue];
	DDRange r2 = [other ddrangeValue];
	
    // Compares the value from range1 and range2
	return DDRangeCompare(&r1, &r2);
}

@end
