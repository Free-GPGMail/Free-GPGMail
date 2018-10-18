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

#import "GPGGlobals.h"
#import "GPGTask.h"
#import "GPGKey.h"
#import "NSBundle+GPGLocalization.h"


NSString *localizedLibmacgpgString(NSString *key) {
	
	static dispatch_once_t onceToken;
	static NSBundle *bundle = nil, *englishBundle = nil;
	dispatch_once(&onceToken, ^{
		bundle = [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] retain];
		[bundle useGPGLocalizations];
		englishBundle = [[NSBundle bundleWithPath:[bundle pathForResource:@"en" ofType:@"lproj"]] retain];
	});
	
	NSString *notFoundValue = @"~#*?*#~";
	NSString *localized = [bundle localizedStringForKey:key value:notFoundValue table:nil];
	if (localized == notFoundValue) {
		localized = [englishBundle localizedStringForKey:key value:nil table:nil];
	}
	
	return localized;
}

@implementation NSData (GPGExtension)
- (NSString *)gpgString {
	NSString *retString;
	
	if ([self length] == 0) {
		GPGDebugLog(@"Used Encoding: Zero length");
		return @"";
	}

	retString = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	if (retString) {
		GPGDebugLog(@"Used Encoding: UTF-8.");
		return [retString autorelease];
	}
	
	// Löschen aller ungültigen Zeichen, damit die umwandlung nach UTF-8 funktioniert.
	const uint8_t *inText = [self bytes];
	if (!inText) {
		GPGDebugLog(@"Used Encoding: nil");
		return nil;
	}
	
	NSUInteger i = 0, c = [self length];
	
	uint8_t *outText = malloc(c + 1);
	if (outText) {
		uint8_t *outPos = outText;
		const uint8_t *startChar = nil;
		int multiByte = 0;
		
		for (; i < c; i++) {
			if (multiByte && (*inText & 0xC0) == 0x80) { // Fortsetzung eines Mehrbytezeichen
				multiByte--;
				if (multiByte == 0) {
					while (startChar <= inText) {
						*(outPos++) = *(startChar++);
					}
				}
			} else if ((*inText & 0x80) == 0) { // Normales ASCII Zeichen.
				*(outPos++) = *inText;
				multiByte = 0;
			} else if ((*inText & 0xC0) == 0xC0) { // Beginn eines Mehrbytezeichen.
				if (multiByte) {
					*(outPos++) = '?';
				}
				if (*inText <= 0xDF && *inText >= 0xC2) {
					multiByte = 1;
					startChar = inText;
				} else if (*inText <= 0xEF && *inText >= 0xE0) {
					multiByte = 2;
					startChar = inText;
				} else if (*inText <= 0xF4 && *inText >= 0xF0) {
					multiByte = 3;
					startChar = inText;
				} else {
					*(outPos++) = '?';
					multiByte = 0;
				}
			} else {
				*(outPos++) = '?';
			}
			
			inText++;
		}
		*outPos = 0;
		
		retString = [[[NSString alloc] initWithUTF8String:(char*)outText] autorelease];
		
		free(outText);
		if (retString) {
			GPGDebugLog(@"Used Encoding: Cleaned UTF-8.");
			return retString;
		}
	}
	// Ende der Säuberung.

	
	
	int encodings[3] = {NSISOLatin1StringEncoding, NSISOLatin2StringEncoding, NSASCIIStringEncoding};
	for(i = 0; i < 3; i++) {
		retString = [[[NSString alloc] initWithData:self encoding:encodings[i]] autorelease];
		if([retString length] > 0) {
			GPGDebugLog(@"Used Encoding: %i", encodings[i]);
			return retString;
		}
	}
	
	if (retString == nil) {
		@throw [NSException exceptionWithName:@"GPGUnknownStringEncodingException"
									   reason:@"It was not possible to recognize the string encoding." userInfo:nil];
	}
	
	return retString;
}

- (NSArray *)gpgLines {
	// Split the data object into an array of string (the lines).
	
	if ([self length] == 0) {
		return @[];
	}
	
	// Encode to an NSString using UTF8.
	NSString *string = [[[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding] autorelease];
	if (string) {
		// Split the string into lines, and return it.
		return [string componentsSeparatedByString:@"\n"];
	}
	
	// Not a pure UTF8 string. We need to parse it manually.
	// Step byte by byte through the data to find line endings.
	// Convert every line to an NSString, this allows a different encoding for every line.
	
	NSMutableArray *lines = [NSMutableArray array];
	
	const uint8_t *bytes = [self bytes];
	NSUInteger i = 0, c = [self length];
	NSUInteger start = 0;
	NSUInteger add = 0;
	
	for (; i < c; i++) {
		switch (bytes[i]) {
			case '\r':
				if (i+1 < c && bytes[i+1] == '\n') {
					add = 1;
				}
				// No break!
			case '\n': {
				if (i-start > 0) {
					NSString *line;
					
					// Try some encodings.
					int encodings[3] = {NSUTF8StringEncoding, NSISOLatin1StringEncoding, NSWindowsCP1252StringEncoding};
					for (int j = 0; j < 3; j++) {
						line = [[[NSString alloc] initWithBytes:bytes+start length:i-start encoding:encodings[j]] autorelease];
						
						if (line.length > 0) {
							GPGDebugLog(@"Used Encoding: %i", encodings[j]);
							break;
						}
					}
					
					if (line.length == 0) {
						// Our last chance, use gpgString.
						NSData *subData = [[NSData alloc] initWithBytesNoCopy:(void *)(bytes+start) length:i-start freeWhenDone:NO];
						line = [subData gpgString];
						[subData release];
					}
					
					if (line) {
						[lines addObject:line];
					} else {
						[lines addObject:@""];
					}
				} else {
					[lines addObject:@""];
				}
				
				i += add;
				start = i + 1;
				break;
			}
		}
	}
	return [lines copy];
}

- (NSData *)base64DecodedData {
	NSData *result = nil;
	
	if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_9) {
		NSString *base64String = [[NSString alloc] initWithData:self encoding:NSASCIIStringEncoding];
		result = [[NSData alloc] initWithBase64Encoding:base64String];
		[base64String release];
	} else {
		result = [[NSData alloc] initWithBase64EncodedData:self options:NSDataBase64DecodingIgnoreUnknownCharacters];
	}
	
	return [result autorelease];
}

static const UInt32 crcTable[256] = {
	0x00000000, 0x00864cfb, 0x018ad50d, 0x010c99f6, 0x0393e6e1, 0x0315aa1a,
	0x021933ec, 0x029f7f17, 0x07a18139, 0x0727cdc2, 0x062b5434, 0x06ad18cf,
	0x043267d8, 0x04b42b23, 0x05b8b2d5, 0x053efe2e, 0x0fc54e89, 0x0f430272,
	0x0e4f9b84, 0x0ec9d77f, 0x0c56a868, 0x0cd0e493, 0x0ddc7d65, 0x0d5a319e,
	0x0864cfb0, 0x08e2834b, 0x09ee1abd, 0x09685646, 0x0bf72951, 0x0b7165aa,
	0x0a7dfc5c, 0x0afbb0a7, 0x1f0cd1e9, 0x1f8a9d12, 0x1e8604e4, 0x1e00481f,
	0x1c9f3708, 0x1c197bf3, 0x1d15e205, 0x1d93aefe, 0x18ad50d0, 0x182b1c2b,
	0x192785dd, 0x19a1c926, 0x1b3eb631, 0x1bb8faca, 0x1ab4633c, 0x1a322fc7,
	0x10c99f60, 0x104fd39b, 0x11434a6d, 0x11c50696, 0x135a7981, 0x13dc357a,
	0x12d0ac8c, 0x1256e077, 0x17681e59, 0x17ee52a2, 0x16e2cb54, 0x166487af,
	0x14fbf8b8, 0x147db443, 0x15712db5, 0x15f7614e, 0x3e19a3d2, 0x3e9fef29,
	0x3f9376df, 0x3f153a24, 0x3d8a4533, 0x3d0c09c8, 0x3c00903e, 0x3c86dcc5,
	0x39b822eb, 0x393e6e10, 0x3832f7e6, 0x38b4bb1d, 0x3a2bc40a, 0x3aad88f1,
	0x3ba11107, 0x3b275dfc, 0x31dced5b, 0x315aa1a0, 0x30563856, 0x30d074ad,
	0x324f0bba, 0x32c94741, 0x33c5deb7, 0x3343924c, 0x367d6c62, 0x36fb2099,
	0x37f7b96f, 0x3771f594, 0x35ee8a83, 0x3568c678, 0x34645f8e, 0x34e21375,
	0x2115723b, 0x21933ec0, 0x209fa736, 0x2019ebcd, 0x228694da, 0x2200d821,
	0x230c41d7, 0x238a0d2c, 0x26b4f302, 0x2632bff9, 0x273e260f, 0x27b86af4,
	0x252715e3, 0x25a15918, 0x24adc0ee, 0x242b8c15, 0x2ed03cb2, 0x2e567049,
	0x2f5ae9bf, 0x2fdca544, 0x2d43da53, 0x2dc596a8, 0x2cc90f5e, 0x2c4f43a5,
	0x2971bd8b, 0x29f7f170, 0x28fb6886, 0x287d247d, 0x2ae25b6a, 0x2a641791,
	0x2b688e67, 0x2beec29c, 0x7c3347a4, 0x7cb50b5f, 0x7db992a9, 0x7d3fde52,
	0x7fa0a145, 0x7f26edbe, 0x7e2a7448, 0x7eac38b3, 0x7b92c69d, 0x7b148a66,
	0x7a181390, 0x7a9e5f6b, 0x7801207c, 0x78876c87, 0x798bf571, 0x790db98a,
	0x73f6092d, 0x737045d6, 0x727cdc20, 0x72fa90db, 0x7065efcc, 0x70e3a337,
	0x71ef3ac1, 0x7169763a, 0x74578814, 0x74d1c4ef, 0x75dd5d19, 0x755b11e2,
	0x77c46ef5, 0x7742220e, 0x764ebbf8, 0x76c8f703, 0x633f964d, 0x63b9dab6,
	0x62b54340, 0x62330fbb, 0x60ac70ac, 0x602a3c57, 0x6126a5a1, 0x61a0e95a,
	0x649e1774, 0x64185b8f, 0x6514c279, 0x65928e82, 0x670df195, 0x678bbd6e,
	0x66872498, 0x66016863, 0x6cfad8c4, 0x6c7c943f, 0x6d700dc9, 0x6df64132,
	0x6f693e25, 0x6fef72de, 0x6ee3eb28, 0x6e65a7d3, 0x6b5b59fd, 0x6bdd1506,
	0x6ad18cf0, 0x6a57c00b, 0x68c8bf1c, 0x684ef3e7, 0x69426a11, 0x69c426ea,
	0x422ae476, 0x42aca88d, 0x43a0317b, 0x43267d80, 0x41b90297, 0x413f4e6c,
	0x4033d79a, 0x40b59b61, 0x458b654f, 0x450d29b4, 0x4401b042, 0x4487fcb9,
	0x461883ae, 0x469ecf55, 0x479256a3, 0x47141a58, 0x4defaaff, 0x4d69e604,
	0x4c657ff2, 0x4ce33309, 0x4e7c4c1e, 0x4efa00e5, 0x4ff69913, 0x4f70d5e8,
	0x4a4e2bc6, 0x4ac8673d, 0x4bc4fecb, 0x4b42b230, 0x49ddcd27, 0x495b81dc,
	0x4857182a, 0x48d154d1, 0x5d26359f, 0x5da07964, 0x5cace092, 0x5c2aac69,
	0x5eb5d37e, 0x5e339f85, 0x5f3f0673, 0x5fb94a88, 0x5a87b4a6, 0x5a01f85d,
	0x5b0d61ab, 0x5b8b2d50, 0x59145247, 0x59921ebc, 0x589e874a, 0x5818cbb1,
	0x52e37b16, 0x526537ed, 0x5369ae1b, 0x53efe2e0, 0x51709df7, 0x51f6d10c,
	0x50fa48fa, 0x507c0401, 0x5542fa2f, 0x55c4b6d4, 0x54c82f22, 0x544e63d9,
	0x56d11cce, 0x56575035, 0x575bc9c3, 0x57dd8538
};
- (UInt32)crc24 {
	UInt32 crc = 0xB704CEL;
	const UInt8 *bytes = self.bytes;
	NSUInteger n = self.length;
	
	for (; n; bytes++, n--) {
		crc = (crc << 8) ^ crcTable[((crc >> 16) & 0xff) ^ *bytes];
	}
	
	return crc & 0xFFFFFF;
}


@end

@implementation NSString (GPGExtension)
- (NSData *)UTF8Data {
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSUInteger)UTF8Length {
	return [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)shortKeyID {
	return [self substringFromIndex:[self length] - 8];
}
- (NSString *)keyID {
	return [self substringFromIndex:[self length] - 16];
}
- (NSString *)unescapedString {
	//Wandelt "\\t" -> "\t", "\\x3a" -> ":" usw.
	
	const char *escapedText = [self UTF8String];
	char *unescapedText = malloc(strlen(escapedText) + 1);
	if (!unescapedText) {
		return nil;
	}
	char *unescapedTextPos = unescapedText;
	
	while (*escapedText) {
		if (*escapedText == '\\') {
			escapedText++;
			switch (*escapedText) {
#define DECODE_ONE(match, result) \
case match: \
escapedText++; \
*(unescapedTextPos++) = result; \
break;
					
					DECODE_ONE ('\'', '\'');
					DECODE_ONE ('\"', '\"');
					DECODE_ONE ('\?', '\?');
					DECODE_ONE ('\\', '\\');
					DECODE_ONE ('a', '\a');
					DECODE_ONE ('b', '\b');
					DECODE_ONE ('f', '\f');
					DECODE_ONE ('n', '\n');
					DECODE_ONE ('r', '\r');
					DECODE_ONE ('t', '\t');
					DECODE_ONE ('v', '\v');
					
				case 'x': {
					escapedText++;
					int byte = hexToByte(escapedText);
					if (byte == -1) {
						*(unescapedTextPos++) = '\\';
						*(unescapedTextPos++) = 'x';
					} else {
						if (byte == 0) {
							*(unescapedTextPos++) = '\\';
							*(unescapedTextPos++) = '0';
						} else {
							*(unescapedTextPos++) = (char)byte;
						}
						escapedText += 2;
					}
					break; }
				default:
					*(unescapedTextPos++) = '\\';
					*(unescapedTextPos++) = *(escapedText++);
					break;
			}
		} else {
			*(unescapedTextPos++) = *(escapedText++);
		}
	}
	*unescapedTextPos = 0;
	
	NSString *retString = [NSString stringWithUTF8String:unescapedText];
	free(unescapedText);
	return retString;
}
- (NSDictionary *)splittedUserIDDescription {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
	NSString *workText = self;
	NSUInteger textLength = [workText length];
	NSRange range;
	
	NSString *email = nil;
	NSString *comment = nil;
	

	[dict setObject:workText forKey:@"userIDDescription"];

	if ([workText hasSuffix:@">"]) {
		range = [workText rangeOfString:@"<" options:NSBackwardsSearch];
		if (range.length > 0) {
			range.location += 1;
			range.length = textLength - range.location - 1;
			
			email = [workText substringWithRange:range];
			
			if (range.location > 2) {
				workText = [workText substringToIndex:range.location - 2];
				textLength -= (range.length + 3);
			} else {
				workText = @"";
				textLength = 0;
			}
		}
	}
	if ([workText hasSuffix:@")"]) {
		range = [workText rangeOfString:@"(" options:NSBackwardsSearch];
		if (range.length > 0) {
			range.location += 1;
			range.length = textLength - range.location - 1;
			
			comment = [workText substringWithRange:range];
			
			if (range.location > 2) {
				workText = [workText substringToIndex:range.location - 2];
				textLength -= (range.length + 3);
			} else {
				workText = @"";
				textLength = 0;
			}
		}
	}
	
	
	if (!email && !comment && [workText rangeOfString:@"@"].length > 0) {
		email = workText;
	} else {
		dict[@"name"] = workText;
	}
	if (email) {
		dict[@"email"] = email;
	}
	if (comment) {
		dict[@"comment"] = comment;
	}
	
	return dict;
}


@end

@implementation NSDate (GPGExtension)
+ (id)dateWithGPGString:(NSString *)string {
	if ([string integerValue] == 0) {
		return nil;
	} else if (string.length > 8 && [string characterAtIndex:8] == 'T') {
		NSString *year = [string substringWithRange:NSMakeRange(0, 4)];
		NSString *month = [string substringWithRange:NSMakeRange(4, 2)];
		NSString *day = [string substringWithRange:NSMakeRange(6, 2)];
		NSString *hour = [string substringWithRange:NSMakeRange(9, 2)];
		NSString *minute = [string substringWithRange:NSMakeRange(11, 2)];
		NSString *second = [string substringWithRange:NSMakeRange(13, 2)];
		
		return [NSDate dateWithString:[NSString stringWithFormat:@"%@-%@-%@ %@:%@:%@ +0000", year, month, day, hour, minute, second]];
	} else {
		return [self dateWithTimeIntervalSince1970:[string integerValue]];
	}
}
@end

@implementation NSArray (IndexInfo)
- (NSIndexSet *)indexesOfIdenticalObjects:(id <NSFastEnumeration>)objects {
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	for (id object in objects) {
		NSUInteger aIndex = [self indexOfObjectIdenticalTo:object];
		if (aIndex != NSNotFound) {
			[indexes addIndex:aIndex];
		}
	}
	return indexes;
}
@end

@implementation NSSet (GPGExtension)
- (NSSet *)usableGPGKeys {
	Class gpgKeyClass = [GPGKey class];
	return [self objectsPassingTest:^BOOL(id obj, BOOL *stop) {
		if ([obj isKindOfClass:gpgKeyClass] && ((GPGKey *)obj).validity < GPGValidityInvalid) {
			return YES;
		}
		return NO;
	}];
}
@end


int hexToByte (const char *text) {
	int retVal = 0;
	int i;
	
	for (i = 0; i < 2; i++) {
		if (*text >= '0' && *text <= '9') {
			retVal += *text - '0';
		} else if (*text >= 'A' && *text <= 'F') {
			retVal += 10 + *text - 'A';
		} else if (*text >= 'a' && *text <= 'f') {
			retVal += 10 + *text - 'a';
		} else {
			return -1;
		}
		
		if (i == 0) {
			retVal *= 16;
		}
		text++;
    }
	return retVal;
}
NSString* bytesToHexString(const uint8_t *bytes, NSUInteger length) {
	char table[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	char hexString[length * 2 + 1];
	hexString[length * 2] = 0;
	
	for (int i = 0; i < length; i++) {
		hexString[i*2] = table[bytes[i] >> 4];
		hexString[i*2+1] = table[bytes[i] & 0xF];
	}
	return [NSString stringWithUTF8String:hexString];
}


NSSet *importedFingerprintsFromStatus(NSDictionary *statusDict) {
	NSMutableSet *fingerprints = [NSMutableSet set];
	NSArray *lines = [statusDict objectForKey:@"IMPORT_OK"];
	
	for (NSArray *line in lines) {
		NSString *fingerprint = [line objectAtIndex:1];
		[fingerprints addObject:fingerprint];
	}
	return [fingerprints count] ? fingerprints : nil;
}

void *lm_memmem(const void *big, size_t big_len, const void *little, size_t little_len) {
#if defined (__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7
	if (memmem != NULL) {
		return memmem(big, big_len, little, little_len);
	}
#endif
	if (little_len == 1) {
		return memchr(big, *(const unsigned char *)little, big_len);
	}
	const unsigned char *y = (const unsigned char *)big;
	const unsigned char *x = (const unsigned char *)little;
	size_t j, k, l;
	
	if (little_len > big_len)
		return NULL;
	
	if (x[0] == x[1]) {
		k = 2;
		l = 1;
	} else {
		k = 1;
		l = 2;
	}
	
	j = 0;
	while (j <= big_len-little_len) {
		if (x[1] != y[j+1]) {
			j += k;
		} else {
			if (!memcmp(x+2, y+j+2, little_len-2) && x[0] == y[j])
				return (void *)&y[j];
			j += l;
		}
	}
	
	return NULL;
}



@implementation AsyncProxy
@synthesize realObject;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [realObject methodSignatureForSelector:aSelector];
}
- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(invokeWithPool:)) {
		return YES;
	}
	return [super respondsToSelector:aSelector];
}
- (void)invokeWithPool:(NSInvocation *)anInvocation {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[anInvocation invoke];
	[pool drain];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation setTarget:realObject];
	[anInvocation retainArguments];
	[NSThread detachNewThreadSelector:@selector(invokeWithPool:) toTarget:self withObject:anInvocation];
}
+ (id)proxyWithRealObject:(NSObject *)object {
	return [[[[self class] alloc] initWithRealObject:object] autorelease];
}
- (id)initWithRealObject:(NSObject *)object {
	realObject = object;
	return self;
}
- (id)init {
	return [self initWithRealObject:nil];
}
@end
