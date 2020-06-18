/* GPGSignaturePacket.h
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

#import <Libmacgpg/GPGPacket.h>


// Subpacket tags.
typedef NS_ENUM (NSInteger, GPGSubpacketTag) {
	GPGSignatureCreationTimeTag = 2,
	GPGSignatureExpirationTimeTag = 3,
	GPGExportableCertificationTag = 4,
	GPGTrustSignatureTag = 5,
	GPGRegularExpressionTag = 6,
	GPGRevocableTag = 7,
	GPGKeyExpirationTimeTag = 9,
	GPGPreferredSymmetricAlgorithmsTag = 11,
	GPGRevocationKeyTag = 12,
	GPGIssuerTag = 16,
	GPGNotationDataTag = 20,
	GPGPreferredHashAlgorithmsTag = 21,
	GPGPreferredCompressionAlgorithmsTag = 22,
	GPGKeyServerPreferencesTag = 23,
	GPGPreferredKeyServerTag = 24,
	GPGPrimaryUserIDTag = 25,
	GPGPolicyURITag = 26,
	GPGKeyFlagsTag = 27,
	GPGSignersUserIDTag = 28,
	GPGReasonForRevocationTag = 29,
	GPGFeaturesTag = 30,
	GPGSignatureTargetTag = 31,
	GPGEmbeddedSignatureTag = 32,
	GPGIssuerFingerprintTag = 33
};



@interface GPGSignaturePacket : GPGPacket {
	NSInteger publicAlgorithm;
	NSInteger hashAlgorithm;
	NSInteger type;
	NSInteger version;
	UInt16 hashStart;
	NSString *keyID;
	NSUInteger creationTime;
	NSArray *hashedSubpackets;
	NSArray *unhashedSubpackets;
	NSArray *subpackets;
}

@property (nonatomic, readonly) NSInteger publicAlgorithm;
@property (nonatomic, readonly) NSInteger hashAlgorithm;
/**
 Type of the signature. See: https://tools.ietf.org/html/rfc4880#section-5.2.1
 */
@property (nonatomic, readonly) NSInteger type;
@property (nonatomic, readonly) NSInteger version;
@property (nonatomic, readonly) UInt16 hashStart;
@property (nonatomic, copy, readonly) NSString *keyID;
@property (nonatomic, readonly) NSUInteger creationTime;
/**
 The hashed subpackets of the GPGSignaturePacket.
 @returns List of NSDictionarys, this can change at any time, so you're required to test for it.
 */
@property (nonatomic, copy, readonly) NSArray *hashedSubpackets;
/**
 The unhashed subpackets of the GPGSignaturePacket. They are NOT secured by the signature.
 @returns List of NSDictionarys, this can change at any time, so you're required to test for it.
 */
@property (nonatomic, copy, readonly) NSArray *unhashedSubpackets;
/**
 Array containing all elements of unhashedSubpackets and hashedSubpackets.
 @returns List of NSDictionarys, this can change at any time, so you're required to test for it.
 */
@property (nonatomic, copy, readonly) NSArray *subpackets; // Combination of unhashedSubpackets and hashedSubpackets. Order is undefined!



@end
