/*
 Copyright © Roman Zechmeister, 2017
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "GPGTransformer.h"
#import "GPGGlobals.h"
#import "GPGKey.h"
#import "GPGUserIDSignature.h"

#define maybeLocalize(key) (!_keepUnlocalized ? localizedLibmacgpgString(key) : key)

@implementation GPGKeyAlgorithmNameTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return [self transformedIntegerValue:[value integerValue]];
}
- (id)transformedIntegerValue:(NSInteger)value {
	switch (value) {
		case GPG_RSAAlgorithm:
			return maybeLocalize(@"GPG_RSAAlgorithm");
		case GPG_RSAEncryptOnlyAlgorithm:
			return maybeLocalize(@"GPG_RSAEncryptOnlyAlgorithm");
		case GPG_RSASignOnlyAlgorithm:
			return maybeLocalize(@"GPG_RSASignOnlyAlgorithm");
		case GPG_ElgamalEncryptOnlyAlgorithm:
			return maybeLocalize(@"GPG_ElgamalEncryptOnlyAlgorithm");
		case GPG_DSAAlgorithm:
			return maybeLocalize(@"GPG_DSAAlgorithm");
		case GPG_ECDHAlgorithm:
			return maybeLocalize(@"GPG_ECDHAlgorithm");
		case GPG_ECDSAAlgorithm:
			return maybeLocalize(@"GPG_ECDSAAlgorithm");
		case GPG_ElgamalAlgorithm:
			return maybeLocalize(@"GPG_ElgamalAlgorithm");
		case GPG_DiffieHellmanAlgorithm:
			return maybeLocalize(@"GPG_DiffieHellmanAlgorithm");
		case GPG_EdDSAAlgorithm:
			return maybeLocalize(@"GPG_EdDSAAlgorithm");
		case 0:
			return @"";
		default:
			return [NSString stringWithFormat:maybeLocalize(@"Algorithm_%i"), value];
	}
}

@end

@implementation GPGHashAlgorithmNameTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return [self transformedIntegerValue:[value integerValue]];
}

- (id)transformedIntegerValue:(NSInteger)value {
	switch (value) {
		case GPGHashAlgorithmMD5:
			return maybeLocalize(@"DIGEST_ALGO_MD5");
		case GPGHashAlgorithmSHA1:
			return maybeLocalize(@"DIGEST_ALGO_SHA1");
		case GPGHashAlgorithmRMD160:
			return maybeLocalize(@"DIGEST_ALGO_RMD160");
		case GPGHashAlgorithmSHA256:
			return maybeLocalize(@"DIGEST_ALGO_SHA256");
		case GPGHashAlgorithmSHA384:
			return maybeLocalize(@"DIGEST_ALGO_SHA384");
		case GPGHashAlgorithmSHA512:
			return maybeLocalize(@"DIGEST_ALGO_SHA512");
		case GPGHashAlgorithmSHA224:
			return maybeLocalize(@"DIGEST_ALGO_SHA224");
		case 0:
			return @"";
		default:
			return [NSString stringWithFormat:maybeLocalize(@"Algorithm_%i"), value];
	}
}

@end

@implementation GPGValidityDescriptionTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSMutableArray *strings = [NSMutableArray array];
	NSInteger intValue;
//	GPGUserIDSignature *revSig = nil;
	
	if ([value isKindOfClass:[NSNumber class]]) {
		intValue = [value integerValue];
	} else {
		GPGKey *key = value;
		intValue = key.validity;
//		if ([key respondsToSelector:@selector(revocationSignature)]) {
//			revSig = key.revocationSignature;
//		}
	}
	
	
	switch (intValue & 7) {
		case 2:
			[strings addObject:maybeLocalize(@"Never")];
			break;
		case 3:
			[strings addObject:maybeLocalize(@"Marginal")];
			break;
		case 4:
			[strings addObject:maybeLocalize(@"Full")];
			break;
		case 5:
			[strings addObject:maybeLocalize(@"Ultimate")];
			break;
		default:
			if (intValue < GPGValidityInvalid) {
				[strings addObject:maybeLocalize(@"Unknown")];
			}
			break;
	}
	
	if (intValue & GPGValidityInvalid) {
		[strings addObject:maybeLocalize(@"Invalid")];
	}
	if (intValue & GPGValidityRevoked) {
		NSString *revString = maybeLocalize(@"Revoked");
//		if (revSig) {
//			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//			dateFormatter.timeStyle = NSDateFormatterNoStyle;
//			dateFormatter.dateStyle = NSDateFormatterLongStyle;
//			
//			NSString *dateString = [dateFormatter stringFromDate:revSig.creationDate];
//			[dateFormatter release];
//			
//			revString = [NSString stringWithFormat:@"%@ (%@)", revString, dateString];
//		}
		
		[strings addObject:revString];
	}
	if (intValue & GPGValidityExpired) {
		[strings addObject:maybeLocalize(@"Expired")];
	}
	if (intValue & GPGValidityDisabled) {
		[strings addObject:maybeLocalize(@"Disabled")];
	}
	
	return [strings componentsJoinedByString:@", "];
}

@end

@implementation GPGFingerprintTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSString *fingerprint = [value description];
	NSUInteger length = [fingerprint lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	const char *original = [fingerprint UTF8String];
	char *format;
	
	switch (length) {
		case 40:
			format = "XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX";
			break;
		case 32:
			format = "XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX";
			break;
		case 16:
			format = "XXXX XXXX  XXXX XXXX";
			break;
		case 8:
			format = "XXXX XXXX";
			break;
		case 0:
			return @"";
		default:
			return fingerprint;
	}
	
	NSUInteger formatLength = strlen(format);
	NSMutableData *buffer = [NSMutableData dataWithLength:formatLength];
	char *bytes = [buffer mutableBytes];
	NSUInteger i1 = 0, i2 = 0;
	
	for (; i1 < formatLength; i1++) {
		char byte = 0;
		switch (format[i1]) {
			case ' ':
				byte = ' ';
				break;
			default:
				byte = original[i2++];
				break;
		}
		bytes[i1] = byte;
	}
	
	return [[[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding] autorelease];
}
@end


@implementation GPGNoBreakFingerprintTransformer
- (id)transformedValue:(id)value {
	NSString *transformed = [super transformedValue:value];
	transformed = [transformed stringByReplacingOccurrencesOfString:@" " withString:@"\xC2\xA0"];
	return transformed;
}
+ (id)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static id _sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[self alloc] init];
	});
	return _sharedInstance;
}
@end




@implementation SplitFormatter
@synthesize blockSize;

- (id)init {
	if (self = [super init]) {
		blockSize = 4;
	}
	return self;
}

- (NSString *)stringForObjectValue:(id)obj {
	NSString *fingerprint = [obj description];
	NSUInteger length = [fingerprint length];
	if (length == 0) {
		return @"";
	}
	if (blockSize == 0) {
		return fingerprint;
	}
	
	NSMutableString *formattedFingerprint = [NSMutableString stringWithCapacity:length + (length - 1) / blockSize];
	
	NSRange range;
	range.location = 0;
	range.length = blockSize;
	
	
	for (; range.location + blockSize < length; range.location += blockSize) {
		[formattedFingerprint appendFormat:@"%@ ", [fingerprint substringWithRange:range]];
	}
	range.length = length - range.location;
	[formattedFingerprint appendString:[fingerprint substringWithRange:range]];
	
	return formattedFingerprint;
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error {
	*obj = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
	return YES;
}
- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	return YES;
}

@end


@implementation NSNumber (GPGValidityCompare)
- (NSComparisonResult)compareGPGValidity:(NSNumber *)otherNumber {
	int aValue = self.intValue;
	int bValue = otherNumber.intValue;
	int mask = 7;
	int aFlags = aValue & ~mask;
	int bFlags = bValue & ~mask;
	aValue = aValue & mask;
	bValue = bValue & mask;
	
	// Never is lower than unkown.
	if (aValue == GPGValidityNever) {
		aValue = -1;
	}
	if (bValue == GPGValidityNever) {
		bValue = -1;
	}
	
	// Substract the invalidity flags to get a negativ number for invalid keys.
	aValue -= aFlags;
	bValue -= bFlags;
	
	if (aValue > bValue) {
		return NSOrderedDescending;
	} else if (aValue < bValue) {
		return NSOrderedAscending;
	} else {
		return NSOrderedSame;
	}
}
@end




