/* GPGSignaturePacket.m
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

#import "GPGSignaturePacket.h"
#import "GPGPacket_Private.h"

@interface GPGSignaturePacket ()
@property (nonatomic, readwrite) NSInteger publicAlgorithm;
@property (nonatomic, readwrite) NSInteger hashAlgorithm;
@property (nonatomic, readwrite) NSInteger type;
@property (nonatomic, readwrite) NSInteger version;
@property (nonatomic, readwrite) UInt16 hashStart;
@property (nonatomic, readwrite) NSUInteger creationTime;
@property (nonatomic, copy, readwrite) NSString *keyID;
@property (nonatomic, copy, readwrite) NSString *fingerprint;
@property (nonatomic, copy, readwrite) NSArray *hashedSubpackets;
@property (nonatomic, copy, readwrite) NSArray *unhashedSubpackets;
@property (nonatomic, copy, readwrite) NSArray *subpackets;
@end


@implementation GPGSignaturePacket
@synthesize publicAlgorithm, hashAlgorithm, type, version, hashStart, keyID, creationTime,
	hashedSubpackets, unhashedSubpackets, subpackets;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.version = parser.byte;
	cancelInitOnEOF();
	
	switch (version) {
		case 2:
		case 3:
			// Old format.
			
			[parser byte]; // Ignore (length of type(1 byte) and creationTime(4 bytes). MUST be 5.)
			self.type = parser.byte;
			self.creationTime = parser.time;
			
			// KeyID of the issuer.
			self.keyID = parser.keyID;
			self.publicAlgorithm = parser.byte;
			self.hashAlgorithm = parser.byte;
			// The first 16 bit of the hash, verified by this signature.
			self.hashStart = parser.uint16;
			
			switch (publicAlgorithm) {
				case 1:
				case 2:
				case 3:
					[parser multiPrecisionInteger]; // "RSA m^d mod n"
					break;
				case 16:
				case 20:
					[parser multiPrecisionInteger]; // "ElGamal a = g^k mod p"
					[parser multiPrecisionInteger]; // "ElGamal b = (h - a*x)/k mod p - 1"
					break;
				case 17:
					[parser multiPrecisionInteger]; // "DSA r"
					[parser multiPrecisionInteger]; // "DSA s"
					break;
				default:
					[parser skip:length - 19];
					break;
			}
			
			break;
		case 4: {
			// New format.
			
			self.type = parser.byte;
			self.publicAlgorithm = parser.byte;
			self.hashAlgorithm = parser.byte;
			
			NSUInteger hsplen = parser.uint16; // Length of the hashed subpackets.
			// The hashed subpackets are secured by the signature itself.
			self.hashedSubpackets = [parser signatureSubpacketsWithLength:hsplen];
			
			NSUInteger usplen = parser.uint16; // Length of the unhashed subpackets.
			// The unhashed subpackets are NOT secured. Don't trust them.
			self.unhashedSubpackets = [parser signatureSubpacketsWithLength:usplen];

			cancelInitOnEOF();

			// Combined list of subpackets for convenience.
			NSMutableArray *theSubpackets = [NSMutableArray arrayWithArray:unhashedSubpackets];
			[theSubpackets addObjectsFromArray:hashedSubpackets];
			self.subpackets = theSubpackets;


			// Get some infos out of the subpackets.
			for (NSDictionary *subpacket in subpackets) {
				switch ((GPGSubpacketTag)[subpacket[@"tag"] integerValue]) {
					case GPGSignatureCreationTimeTag:
						self.creationTime = [subpacket[@"time"] unsignedIntegerValue];
						break;
					case GPGIssuerTag:
						self.keyID = subpacket[@"keyID"];
						break;
					case GPGIssuerFingerprintTag:
						self.fingerprint = subpacket[@"fingerprint"];
						break;
					default:
						break;
				}
			}
			
			
			// The first 16 bit of the hash, verified by this signature.
			self.hashStart = parser.uint16;
			
			// Ignore the MPIs.
			switch (publicAlgorithm) {
				case 1:
				case 2:
				case 3:
					[parser multiPrecisionInteger]; // "RSA m^d mod n"
					break;
				case 16:
				case 20:
					[parser multiPrecisionInteger]; // "ElGamal a = g^k mod p"
					[parser multiPrecisionInteger]; // "ElGamal b = (h - a*x)/k mod p - 1"
					break;
				case 17:
					[parser multiPrecisionInteger]; // "DSA r"
					[parser multiPrecisionInteger]; // "DSA s"
					break;
				default:
					[parser skip:length - 10 - hsplen - usplen];
					break;
			}
			break;
		}
		default:
			// Unknown signature packet.
			[parser skip:length - 1];
			break;
	}
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 2;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ v%li: %li\nIssuer: %@\nCreation Time: %lu", self.className,
			(long)self.version,
			(long)self.type,
			self.fingerprint ? self.fingerprint : self.keyID,
			(unsigned long)self.creationTime];
}

- (void)dealloc {
	self.keyID = nil;
	self.hashedSubpackets = nil;
	self.unhashedSubpackets = nil;
	[super dealloc];
}






@end
