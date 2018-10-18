/* GPGPacket.h
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



// Every subclass of GPGPacket returns one of these tags.
typedef NS_ENUM(NSInteger, GPGPacketTag) {
	GPGPublicKeyEncryptedSessionKeyPacketTag = 1,
	GPGSignaturePacketTag = 2,
	GPGSymmetricEncryptedSessionKeyPacketTag = 3,
	GPGOnePassSignaturePacketTag = 4,
	GPGSecretKeyPacketTag = 5,
	GPGPublicKeyPacketTag = 6,
	GPGSecretSubkeyPacketTag = 7,
	GPGCompressedDataPacketTag = 8,
	GPGEncryptedDataPacketTag = 9,
	GPGMarkerPacketTag = 10,
	GPGLiteralDataPacketTag = 11,
	GPGTrustPacketTag = 12,
	GPGUserIDPacketTag = 13,
	GPGPublicSubkeyPacketTag = 14,
	GPGUserAttributePacketTag = 17,
	GPGEncryptedProtectedDataPacketTag = 18,
};


/**
 GPGPacket is an abstract super-class and should never be used directly.
*/
@interface GPGPacket : NSObject {
	NSData *_data;
}
@property (readonly) GPGPacketTag tag;
@property (nonatomic, copy, readonly) NSData *data;



+ (NSDictionary *)capabilitiesOfPackets:(NSArray *)packets;

+ (id)packetsWithData:(NSData *)data;
+ (void)enumeratePacketsWithData:(NSData *)theData block:(void (^)(GPGPacket *packet, BOOL *stop))block;


// Old methods, only for compatibility:

- (NSInteger)type UNAVAILABLE_ATTRIBUTE;
- (NSString *)keyID UNAVAILABLE_ATTRIBUTE;
- (NSInteger)signatureType UNAVAILABLE_ATTRIBUTE;

+ (NSData *)unArmor:(NSData *)data DEPRECATED_ATTRIBUTE;
+ (NSData *)unArmor:(NSData *)data clearText:(NSData **)clearText DEPRECATED_ATTRIBUTE;


@end
