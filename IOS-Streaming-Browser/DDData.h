#import <Foundation/Foundation.h>

@interface NSData (DDData)

/**
    @brief An MD5 digest of 128 bits is represented as 32 ASCII printable characters. The bits in the 128 bit digest are converted from most significant to least significant bit, four bits at a time to their ASCII presentation as follows. Each four bits is represented by its familiar hexadecimal notation from the characters 0123456789abcdef. That is, binary 0000 gets represented by the character '0', 0001, by '1', and so on up to the representation of 1111 as 'f'.
    @return NSData
**/
- (NSData *)md5Digest;

/**
    @brief Produces a 160-bit message digest based on principles similar to those used by Ronald L. Rivest of MIT in the design of the MD4 and MD5 message digest algorithms, but has a more conservative design.
    @return NSData
**/
- (NSData *)sha1Digest;

/**
    @brief Base 16 value
    @return NSString
**/
- (NSString *)hexStringValue;

/**
    @brief Encodes ASCII values into a binary format.  The purpose is to encode binary data into a format which is transferred over media which is designed for textual data
    @return NSString
**/
- (NSString *)base64Encoded;

/**
    @brief Decodes binary formated data into ASCII values
    @return NSData
**/
- (NSData *)base64Decoded;

@end
