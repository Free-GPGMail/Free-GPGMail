/* GPGPacketParser.m
 Based on pgpdump (https://github.com/kazu-yamamoto/pgpdump) from Kazuhiko Yamamoto.
 Copyright © Roman Zechmeister, 2017
 
 This file is part of Libmacgpg.
 
 Libmacgpg is free software; you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 Libmacgpg is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA
 */

#import "GPGPacketParser.h"
#import "GPGStream.h"
#import "GPGGlobals.h"
#import "GPGException.h"
#import "GPGPacket.h"
#import "GPGPacket_Private.h"
#import "GPGPublicKeyEncryptedSessionKeyPacket.h"
#import "GPGSignaturePacket.h"
#import "GPGSymmetricEncryptedSessionKeyPacket.h"
#import "GPGOnePassSignaturePacket.h"
#import "GPGKeyMaterialPacket.h"
#import "GPGIgnoredPackets.h"
#import "GPGLiteralDataPacket.h"
#import "GPGUserIDPacket.h"
#import "GPGUserAttributePacket.h"
#import "GPGCompressedDataPacket_Private.h"


#define BINARY_TAG_FLAG 0x80
#define NEW_TAG_FLAG    0x40
#define TAG_MASK        0x3f
#define PARTIAL_MASK    0x1f
#define TAG_COMPRESSED  8

#define OLD_TAG_SHIFT   2
#define OLD_LEN_MASK    0x03

#define CRITICAL_BIT    0x80
#define CRITICAL_MASK   0x7f

// Return a GPGErrorEOF, if the end of file is reached unexpected.
#define returnErrorOnEOF() if (eofReached) {self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorEOF userInfo:nil]; return nil;}
// Return 0 or nil, if the end of file is reached.
#define stopOnEOF()	if (eofReached) {return 0;}



static NSArray *tagClasses = nil;

@interface GPGPacketParser ()
@property (nonatomic, readwrite, strong) NSError *error;
@property (nonatomic, strong) GPGStream *stream;
@property (nonatomic, strong) GPGCompressedDataPacket *compressedPacket;
@end


@implementation GPGPacketParser
@synthesize stream, compressedPacket;
@synthesize error;
@synthesize byteCallback;

#pragma mark Main methods

- (GPGPacket *)nextPacket {

	@try {
		if (compressedPacket.canDecompress) {
			// We have a compressed packet, get the next decompressed packet.
			GPGPacket *tempPacket = [compressedPacket nextPacket];
			
			if (tempPacket) {
				return tempPacket;
			} else {
				// It was the last packet in the compressed packet.
				// Now we run normally to get the remaining packet, if any.
				self.compressedPacket = nil;
			}
		}
		returnErrorOnEOF();
		
		
		NSInteger c = [stream readByte];
		if (c == EOF) {
			// We have no (more) data.
			self.error = nil;
			return nil;
		}
		if ((c & BINARY_TAG_FLAG) == 0) {
			// The high-bit of the first byte MUST be 1.
			self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorInvalidData userInfo:nil];
			return nil;
		}
		
		packetData = [NSMutableData data];
		{
			char bytes[] = {(char)c};
			[packetData appendBytes:bytes length:1];
		}
		
		
		NSInteger tag = c & TAG_MASK;
		NSUInteger length = 0;
		partial = NO;
		
		if (c & NEW_TAG_FLAG) {
			// New format.
			
			// Get the packet length.
			c = self.byte;
			returnErrorOnEOF();

			length = [self getNewLen:c];
			returnErrorOnEOF();

			partial = isPartial(c);
			if (partial && length < 512) {
				// The first partial packet MUST be at least 512 byte long.
				self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorBadData userInfo:nil];
				return nil;
			}
		} else {
			// Old format.

			// The two low-bits define how the length of the packet is stored.
			// So we have to shift the tag accordingly.
			tag >>= OLD_TAG_SHIFT;

			switch (c & OLD_LEN_MASK) {
				case 0:
					length = self.byte;
					break;
				case 1:
					length = (self.byte << 8);
					length += self.byte;
					break;
				case 2:
					length = self.byte << 24;
					length |= self.byte << 16;
					length |= self.byte << 8;
					length |= self.byte;
					break;
				case 3:
					length = NSUIntegerMax;
					break;
			}

			returnErrorOnEOF();
		}
		
		GPGPacket *packet = nil;
		
		if (tag < tagClasses.count) {
			// Get the right GPGPacket subclass for this packet.
			Class class = tagClasses[tag];
			
			if (class == [NSNull null]) {
				// Reserved/unknown packet, skip it.
				[self skip:length];
			} else {
				// Store the packet length for skipRemaining.
				packetLength = length;
				
				// The packet content is parsed in -initWithParser:length:.
				packet = [[[class alloc] initWithParser:self length:length] autorelease];
				
				returnErrorOnEOF();

				
				if (tag == TAG_COMPRESSED && [(GPGCompressedDataPacket *)packet canDecompress]) {
					// We have a compressed packet, we are able to decompress.
					
					// Store a reference for the next run of [self nextPacket].
					self.compressedPacket = (GPGCompressedDataPacket *)packet;
					
					// Get the first packet inside of the compressed packet.
					GPGPacket *tempPacket = [compressedPacket nextPacket];
					
					if (tempPacket) {
						return tempPacket;
					} else {
						// We don't have any packet inside,
						// return the GPGCompressedDataPacket itself.
						self.compressedPacket = nil;
					}
				}
			}
		} else {
			// Skip unknown packets.
			[self skip:length];
		}
		returnErrorOnEOF();

		// Skip remaining data of a partial packet.
		while (partial == YES) {
			c = self.byte;
			length = [self getNewLen:c];
			partial = isPartial(c);
			returnErrorOnEOF();

			[self skip:length];
		}
		returnErrorOnEOF();
		
		if (packetData) {
			packet.data = packetData;
			packetData = nil;
		}
		
		return packet;
	} @catch (NSException *exception) {
		// Never throw an exception, instead log it and set self.error.
		NSLog(@"Uncaught exception in [GPGPacketParser nextPacket]: \"%@\"", exception);
		self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorUnexpected userInfo:@{@"exception": exception}];
	}

	return nil;
}


#pragma mark Helper

- (NSInteger)byte {
	// Gets the next byte from the strem.
	// If the end of file is reached sets eofReached and returns EOF.
	
	if (eofReached) {
		return EOF;
	}
	
	NSInteger byte = [stream readByte];
	packetLength--;
	
	if (byte == EOF) {
		eofReached = YES;
	} else {
		if (packetData) {
			char bytes[] = {(char)byte};
			[packetData appendBytes:bytes length:1];
		}
		if (byteCallback) {
			byteCallback(byte);
		}
	}
	
	return byte;
}

- (BOOL)eofReached {
	return eofReached;
}

- (void)skip:(NSUInteger)count {
	// skip count bytes.
	for (; count > 0; count--) {
		if (self.byte == EOF) {
			return;
		}
	}
}

static BOOL isPartial(NSInteger c) {
	if (c < 224 || c == 255) {
		return NO;
	} else {
		return YES;
	}
}

- (NSUInteger)getNewLen:(NSInteger)c {
	// Get the packet new format packet length.
	
	NSUInteger length;
	
	if (c < 192) {
		length = c;
	} else if (c < 224) {
		length = ((c - 192) << 8) + self.byte + 192;
	} else if (c == 255) {
		length = (self.byte << 24);
		length |= (self.byte << 16);
		length |= (self.byte << 8);
		length |= self.byte;
	} else {
		length = 1 << (c & PARTIAL_MASK);
	}
	stopOnEOF();

	return length;
}


#pragma mark Helper methods used by GPGPacket

- (NSUInteger)nextPartialLength {
	// Returns the length of the next part.

	if (partial == NO) {
		return 0;
	}

	NSInteger c = self.byte;
	NSUInteger length = [self getNewLen:c];
	partial = isPartial(c);

	stopOnEOF();

	return length;
}

- (BOOL)partial {
	return partial;
}

- (void)skipRemaining {
	// Skip the remaining byte of the current packet.
	
	[self skip:packetLength];
}


#pragma mark Parsing methods used by GPGPacket

- (NSString *)keyID {
	// Read a key ID. Consumes 8 bytes.
	
	NSString *keyID = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X",
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte];
	
	stopOnEOF();
	return keyID;
}

- (NSString *)hexStringOfLength:(NSUInteger)length {
	// Read length bytes and return as hex string.
	
	NSMutableString *hexString = [NSMutableString stringWithCapacity:length * 2];
	
	for (NSUInteger i = 0; i < length; i++) {
		[hexString appendFormat:@"%02X", (UInt8)self.byte];
	}
	
	stopOnEOF();
	return [hexString.copy autorelease];
}

- (id)multiPrecisionInteger {
	// Read a MPI.

	NSUInteger byteCount;
	NSUInteger bits = self.byte * 256;
	bits += self.byte;
	byteCount = (bits + 7) / 8;
	stopOnEOF();

	NSMutableData *data = [NSMutableData dataWithLength:byteCount];
	UInt8 *bytes = data.mutableBytes;
	
	for (NSUInteger i = 0; i < byteCount; i++) {
		bytes[i] = (UInt8)self.byte;
		stopOnEOF();
	}
	
	
	return data;
}

- (NSUInteger)time {
	// Read a date. Consumes 4 bytes.

	NSUInteger time;
	
	time = self.byte << 24;
	time |= self.byte << 16;
	time |= self.byte << 8;
	time |= self.byte;
	
	stopOnEOF();
	return time;
}

- (UInt16)uint16 {
	// Read a unsigned 16-bit integer. Consumes 2 bytes.

	UInt16 value = (UInt16)((self.byte << 8) | self.byte);

	stopOnEOF();
	return value;
}

- (NSString *)stringWithLength:(NSUInteger)length {
	// Read an UTF8 string.

	stopOnEOF();
	if (length > 100000) {
		return nil;
	}
	char *tempString = malloc(length + 1);
	if (tempString == nil) {
		return nil;
	}
	tempString[length] = 0;
	for (NSUInteger i = 0; i < length; i++) {
		tempString[i] = (char)self.byte;
		stopOnEOF();
	}

	NSString *string = [NSString stringWithUTF8String:tempString];
	free(tempString);

	return string;
}

- (NSArray *)signatureSubpacketsWithLength:(NSUInteger)fullLength {
	// Parse the signature subpackets.
	// fullLength is the length of all subpackets.

	stopOnEOF();
	NSMutableArray *packets = [NSMutableArray array];

	while (fullLength > 0) {

		// Get the length of the subpacket.
		NSUInteger length = self.byte;
		if (length < 192) {
			fullLength--;
		} else if (length < 255) {
			length = ((length - 192) << 8) + self.byte + 192;
			fullLength -= 2;
		} else if (length == 255) {
			length = self.byte << 24;
			length |= self.byte << 16;
			length |= self.byte << 8;
			length |= self.byte;
			fullLength -= 5;
		}
		fullLength -= length;


		// Used to skip the remaining subpacket bytes.
		NSUInteger remainingLength = packetLength - length;


		GPGSubpacketTag subtag = self.byte; // length includes this byte.
		stopOnEOF();
		length--;


		/* Handle critical bit of subpacket type */
		BOOL critical = NO;
		if (subtag & CRITICAL_BIT) {
			critical = YES;
			subtag &= CRITICAL_MASK;
		}
		
		
		// Currently a subpacket is represented by a NSDictionary. This can change in the future.
		NSMutableDictionary *packet = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(subtag), @"tag", nil];
		
		if (critical) {
			packet[@"critical"] = @YES;
		}
		
		// Parse the subpacket content.
		switch (subtag) {
			case GPGSignatureCreationTimeTag:
			case GPGSignatureExpirationTimeTag:
			case GPGKeyExpirationTimeTag: {
				NSUInteger time = [self time];
				if (time) {
					packet[@"time"] = @(time);
				}
				break;
			}
			case GPGIssuerTag: {
				NSString *keyID = [self keyID];
				if (keyID) {
					packet[@"keyID"] = keyID;
				}
				break;
			}
			case GPGPolicyURITag:
			case GPGPreferredKeyServerTag:
			case GPGSignersUserIDTag: {
				NSString *string = [self stringWithLength:length];
				if (string) {
					if (subtag == GPGSignersUserIDTag) {
						packet[@"userID"] = string;
					} else {
						packet[@"URI"] = string;
					}
				}
				break;
			}
			case GPGPrimaryUserIDTag: {
				BOOL primary = !!self.byte;
				packet[@"primary"] = @(primary);
				break;
			}
			case GPGKeyFlagsTag: {
				NSInteger flags = self.byte;
				
				packet[@"canCertify"] = @(!!(flags & 0x01));
				packet[@"canSign"] = @(!!(flags & 0x02));
				packet[@"canEncryptCommunications"] = @(!!(flags & 0x04));
				packet[@"canEncryptStorage"] = @(!!(flags & 0x08));
				packet[@"maySplitted"] = @(!!(flags & 0x10));
				packet[@"canAuthentication"] = @(!!(flags & 0x20));
				packet[@"multipleOwners"] = @(!!(flags & 0x80));
				
				break;
			}
			case GPGReasonForRevocationTag: {
				packet[@"code"] = @(self.byte);
				NSString *string = [self stringWithLength:length - 1];
				if (string) {
					packet[@"reason"] = string;
				}
				break;
			}
			case GPGSignatureTargetTag: {
				packet[@"publicAlgorithm"] = @(self.byte);
				packet[@"hashAlgorithm"] = @(self.byte);
				length -= 2;
				
				stopOnEOF();
				NSMutableData *data = [NSMutableData dataWithLength:length];
				if (data) {
					UInt8 *bytes = data.mutableBytes;
					
					for (NSUInteger i = 0; i < length; i++) {
						bytes[i] = (UInt8)self.byte;
						stopOnEOF();
					}
					
					packet[@"hash"] = [[data copy] autorelease];
				}
				break;
			}
			case GPGIssuerFingerprintTag: {
				NSInteger keyVersion = self.byte;
				NSString *fingerprint = nil;
				
				if (keyVersion == 4) {
					fingerprint = [self hexStringOfLength:20];
				} else if (keyVersion == 5) {
					fingerprint = [self hexStringOfLength:32];
				}
				if (fingerprint) {
					packet[@"fingerprint"] = fingerprint;
				}
				break;
			}
			default:
				break;
		}

		stopOnEOF();


		// Add the subpacket to the list.
		[packets addObject:packet];
		
		// Skip all remaining bytes of this subpacket, if any.
		length = packetLength - remainingLength;
		[self skip:length];

		stopOnEOF();
	}


	return packets;
}


#pragma mark init etc.

+ (instancetype)packetParserWithStream:(GPGStream *)stream {
	return [[(GPGPacketParser *)[self alloc] initWithStream:stream] autorelease];
}

- (instancetype)initWithStream:(GPGStream *)theStream {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.stream = theStream;
	
	return self;
}

+ (void)initialize {
	// This list of GPGPacket subclasses.
	tagClasses = [@[
				   [NSNull null],
				   [GPGPublicKeyEncryptedSessionKeyPacket class], // 1
				   [GPGSignaturePacket class], // 2
				   [GPGSymmetricEncryptedSessionKeyPacket class], // 3
				   [GPGOnePassSignaturePacket class], // 4
				   [GPGSecretKeyPacket class], // 5
				   [GPGPublicKeyPacket class], // 6
				   [GPGSecretSubkeyPacket class], // 7
				   [GPGCompressedDataPacket class], // 8
				   [GPGEncryptedDataPacket class], // 9
				   [GPGMarkerPacket class], // 10
				   [GPGLiteralDataPacket class], // 11
				   [GPGTrustPacket class], // 12
				   [GPGUserIDPacket class], // 13
				   [GPGPublicSubkeyPacket class], // 14
				   [NSNull null], // 15
				   [NSNull null], // 16
				   [GPGUserAttributePacket class], // 17
				   [GPGEncryptedProtectedDataPacket class] // 18
				   ] retain];
}

- (void)dealloc {
	self.stream = nil;
	self.error = nil;
	self.compressedPacket = nil;
	self.byteCallback = nil;
	[super dealloc];
}


@end
