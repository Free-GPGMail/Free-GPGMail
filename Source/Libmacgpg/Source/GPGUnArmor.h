#import <Foundation/Foundation.h>
#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGStream.h>



@interface GPGUnArmor : NSObject {
	GPGStream *stream;
	
	// Cache
	NSMutableData *cacheData;
	const UInt8 *cacheBytes;
	NSUInteger cacheIndex;
	NSUInteger cacheEnd;
	NSUInteger streamOffset;
	NSUInteger maxBytesToRead;
	
	// State vars for parsing.
	NSMutableData *base64Data;
	NSMutableIndexSet *possibleStarts;
	BOOL preferAlternative;
	NSUInteger alternativeStart;
	BOOL invalidCharInLine;
	
	NSInteger equalsAdded;
	BOOL haveCRC;
	UInt8 crcBytes[4];
	BOOL crLineEnding;
	
	
	// Properties
	NSError *error;
	NSData *clearText;
	NSData *data;
	BOOL eof;
}

@property (nonatomic, readonly, strong) NSError *error;
@property (nonatomic, readonly, strong) NSData *clearText;
@property (nonatomic, readonly, strong) NSData *data;
@property (nonatomic, readonly) BOOL eof;


/**
 * Decodes and returns all packets in the stream.
 * If the input is not armored, it returns the original data from the stream.
 *
 * @param clear Upon return contains the clear-text, if any. Pass NULL if you do not want the clear-text.
 * @param error If an error occurs, upon return contains an NSError object that describes the problem. Pass NULL if you do not want error information.
 * @return A GPGStream containing the decoded data or the original stream, if the input wasn't armored.
 */
+ (GPGStream *)unArmor:(GPGStream *)stream clearText:(NSData **)clearText error:(NSError **)error;

/**
 * Decodes and returns all packets in the stream.
 * If the input is not armored, it returns the original data from the stream.
 *
 * @param clear Upon return contains the clear-text, if any. Pass NULL if you do not want the clear-text.
 * @return A GPGStream containing the decoded data or the original stream, if the input wasn't armored.
 */
+ (GPGStream *)unArmor:(GPGStream *)stream clearText:(NSData **)clearText;

/**
 * Decodes and returns all packets in the stream.
 * If the input is not armored, it returns the original data from the stream.
 *
 * @return A GPGStream containing the decoded data or the original stream, if the input wasn't armored.
 */
+ (GPGStream *)unArmor:(GPGStream *)stream;





+ (instancetype)unArmorWithGPGStream:(GPGStream *)theStream;
- (instancetype)initWithGPGStream:(GPGStream *)stream;

/**
 * Decodes and returns the next armored packet in the stream.
 *
 * @return The decoded data or NULL if the input wasn't armored.
 */
- (NSData *)decodeNext;

/**
 * Decodes and returns all packets in the stream.
 *
 * @return The decoded data or NULL if the input wasn't armored.
 */
- (NSData *)decodeAll;

/**
 * Decodes and returns only the beginning of the stream.
 * Do not call this method before or after another decode method.
 *
 * @return The decoded data or NULL if the input wasn't armored.
 */
- (NSData *)decodeHeader;


@end

@interface GPGStream (IsArmoredExtension)
- (BOOL)isArmored;
@end
@interface NSData (IsArmoredExtension)
- (BOOL)isArmored;
@end

