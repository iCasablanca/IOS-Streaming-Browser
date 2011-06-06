

#import <Foundation/NSValue.h>
#import <Foundation/NSObjCRuntime.h>

@class NSString;


/**
 * DDRange is the functional equivalent of a 64 bit NSRange.
 * The HTTP Server is designed to support very large files.
 * On 32 bit architectures (ppc, i386) NSRange uses unsigned 32 bit integers.
 * This only supports a range of up to 4 gigabytes.
 * By defining our own variant, we can support a range up to 16 exabytes.
 * 
 * All effort is given such that DDRange functions EXACTLY the same as NSRange.
 **/


/** 
 *
 * \struct _DDRange
 *
 * \brief 
 **/
typedef struct _DDRange {
    UInt64 location;  ///< location within the range of bytes
    UInt64 length;   ///< length of the range of bytes
} DDRange;

typedef DDRange *DDRangePointer;

/**
    @brief Makes a range with a location and length
    @param UInt64
    @param UInt64
    @return DDRange
**/
NS_INLINE DDRange DDMakeRange(UInt64 loc, UInt64 len) {
    
    // Localized attribute
    DDRange r;
    
    // Gets the range location passed into this method
    r.location = loc;
    
    // Gets the range length passed into this method
    r.length = len;
    
    // returns the range 
    return r;
}

/**
    @brief Returns the location and length
    @param DDRange
    @return UInt64
**/
NS_INLINE UInt64 DDMaxRange(DDRange range) {
    return (range.location + range.length);
}

/**
    @brief Returns the location within a range
    @param UInt64
    @param DDRange
    @return BOOL
**/
NS_INLINE BOOL DDLocationInRange(UInt64 loc, DDRange range) {
    return (loc - range.location < range.length);
}

/**
    @brief Whether range1 and range2 are equal
    @param DDRange
    @param DDRange
    @return BOOL
**/
NS_INLINE BOOL DDEqualRanges(DDRange range1, DDRange range2) {
    return ((range1.location == range2.location) && (range1.length == range2.length));
}

/**
    @brief Gets the union of two ranges
    @param DDRange
    @param DDRange
    @return DDRange
**/
FOUNDATION_EXPORT DDRange DDUnionRange(DDRange range1, DDRange range2);

/**
    @brief Gets the intersection of two ranges
    @param DDRange
    @param DDRange
    @return DDRange
**/
FOUNDATION_EXPORT DDRange DDIntersectionRange(DDRange range1, DDRange range2);

/**
    @brief Gets a string from a range
    @param DDRange
    @return NSString
**/
FOUNDATION_EXPORT NSString *DDStringFromRange(DDRange range);

/**
    @brief Gets a range from a string
    @param NSString
    @return DDRange
**/
FOUNDATION_EXPORT DDRange DDRangeFromString(NSString *aString);

/**
    @brief Compares two ranges
    @param DDRangePointer
    @param DDRangePointer
    @return NSInteger
**/
NSInteger DDRangeCompare(DDRangePointer pDDRange1, DDRangePointer pDDRange2);

@interface NSValue (NSValueDDRangeExtensions)

/**
    Class method
    @param DDRange
    @return NSValue
**/
+ (NSValue *)valueWithDDRange:(DDRange)range;

/**
    @return DDRange
**/
- (DDRange)ddrangeValue;

/**
    @param NSValue
    @return NSInteger
**/
- (NSInteger)ddrangeCompare:(NSValue *)ddrangeValue;

@end
