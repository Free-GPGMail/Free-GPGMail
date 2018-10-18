/* GPGKeyMaterialPacket.m
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

#import "GPGKeyMaterialPacket.h"
#import "GPGPacket_Private.h"
#import "GPGGlobals.h"
#import <CommonCrypto/CommonDigest.h>

@interface GPGPublicKeyPacket ()
@property (nonatomic, readwrite) NSInteger publicAlgorithm;
@property (nonatomic, readwrite) NSInteger version;
@property (nonatomic, readwrite) NSInteger validDays;
@property (nonatomic, readwrite) NSUInteger creationTime;
@property (nonatomic, strong, readwrite) NSString *fingerprint;
@property (nonatomic, strong, readwrite) NSString *keyID;
@end


@implementation GPGPublicKeyPacket
@synthesize publicAlgorithm, version, validDays, creationTime, fingerprint, keyID;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}

	self.version = parser.byte;
	cancelInitOnEOF();

	switch (version) {
		case 2:
		case 3: {
			// Old format, deprecated and weak!
			
			self.creationTime = parser.time;
			self.validDays = parser.uint16; // How many days the key is valid.
			
			self.publicAlgorithm = parser.byte; // Should be 1 (RSA).
			
			
			NSData *modulus = [parser multiPrecisionInteger]; // "RSA n"
			if (modulus.length >= 8) {
				// The Key ID is the low 64 bits of the modulus.
				self.keyID = bytesToHexString(modulus.bytes + modulus.length - 8, 8);
			}
			NSData *exponent = [parser multiPrecisionInteger]; // "RSA e"
			cancelInitOnEOF();

			
			// The fingerprint is the MD5 of modulus and exponent.
			CC_MD5_CTX md5;
			CC_MD5_Init(&md5);
			CC_MD5_Update(&md5, modulus.bytes, (CC_LONG)modulus.length); // Hash modulus,
			CC_MD5_Update(&md5, exponent.bytes, (CC_LONG)exponent.length); // and exponent.
			UInt8 fingerprintBytes[16];
			CC_MD5_Final(fingerprintBytes, &md5);
			self.fingerprint = bytesToHexString(fingerprintBytes, 16);
			
			
			break;
		}
		case 4: {
			// New format.
			
			
			// The fingerprint is the SHA1 over "0x99, (UInt16)length, 0x04 and the remaining bytes of the packet.
			// We use the byteCallback to put every byte into dataToHash.
			NSUInteger dataLength = length + 3;
			NSMutableData *dataToHash = [NSMutableData dataWithLength:dataLength];
			__block UInt8 *bytesToHash = dataToHash.mutableBytes;
			bytesToHash[0] = 0x99;
			bytesToHash[1] = (length >> 8) & 0xFF;
			bytesToHash[2] = length & 0xFF;
			bytesToHash[3] = 4; // Version
			__block NSUInteger i = 4;
			
			
			// The callback get every byte read from the parser, so we can calculate the SHA1.
			ByteCallback callback = ^(NSInteger byte) {
				if (i < dataLength) {
					// Append byte to bytesToHash;
					bytesToHash[i++] = (UInt8)byte;
				}
			};
			// Set the callback.
			parser.byteCallback = callback;

			
			self.creationTime = parser.time;
			self.publicAlgorithm = parser.byte;
			
			// Ignore the MPIs. But we recognize them.
			switch (publicAlgorithm) {
				case 1:
				case 2:
				case 3:
					[parser multiPrecisionInteger]; // "RSA n"
					[parser multiPrecisionInteger]; // "RSA e"
					break;
				case 16:
				case 20:
					[parser multiPrecisionInteger]; // "ElGamal p"
					[parser multiPrecisionInteger]; // "ElGamal g"
					[parser multiPrecisionInteger]; // "ElGamal y"
					break;
				case 17:
					[parser multiPrecisionInteger]; // "DSA p"
					[parser multiPrecisionInteger]; // "DSA q"
					[parser multiPrecisionInteger]; // "DSA g"
					[parser multiPrecisionInteger]; // "DSA y"
					break;
				default:
					[parser skip:length - 6];
					break;
			}
			
			// We have all bytes for the SHA1. Unset the callback.
			parser.byteCallback = nil;
			
			cancelInitOnEOF();

			
			// Get the fingerprint by hashing bytesToHash using SHA1.
			uint8_t fingerprintBytes[20];
			CC_SHA1(bytesToHash, (CC_LONG)dataLength, fingerprintBytes);
			
			
			self.fingerprint = bytesToHexString(fingerprintBytes, 20);
			// The Key ID is the low 64 bits of the fingerprint.
			self.keyID = [fingerprint keyID];

			break;
		}
		default:
			// Unknown key format, ignore the content.
			[parser skip:length - 1];
			break;
	}

	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 6;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ v%li: %li\nFingerprint: %@\nKeyID: %@\nCreation Time: %lu", self.className,
			(long)self.version,
			(long)self.publicAlgorithm,
			self.fingerprint,
			self.keyID,
			(unsigned long)self.creationTime];
}

- (void)dealloc {
	self.fingerprint = nil;
	self.keyID = nil;
	[super dealloc];
}
@end


@implementation GPGPublicSubkeyPacket
- (GPGPacketTag)tag {
	return 14;
}
@end


@implementation GPGSecretKeyPacket
- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super initWithParser:parser length:length];
	if (!self) {
		return nil;
	}
	
	//TODO: Parse secret-key.
	
	[parser skipRemaining];
	
	return self;
}

- (GPGPacketTag)tag {
	return 5;
}
@end


@implementation GPGSecretSubkeyPacket
- (GPGPacketTag)tag {
	return 7;
}
@end



