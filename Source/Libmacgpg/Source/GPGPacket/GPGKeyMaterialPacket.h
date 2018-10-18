/* GPGKeyMaterialPacket.h
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

@interface GPGPublicKeyPacket : GPGPacket {
	NSInteger publicAlgorithm;
	NSInteger version;
	NSInteger validDays;
	NSUInteger creationTime;
	NSString *fingerprint;
	NSString *keyID;
}

/**
 Public-Key Algorithm used. See: https://tools.ietf.org/html/rfc4880#section-9.1
 */
@property (nonatomic, readonly) NSInteger publicAlgorithm;
@property (nonatomic, readonly) NSInteger version;
@property (nonatomic, readonly) NSInteger validDays; // Only set on old keys.
@property (nonatomic, readonly) NSUInteger creationTime;
@property (nonatomic, strong, readonly) NSString *fingerprint;
@property (nonatomic, strong, readonly) NSString *keyID;


@end

@interface GPGPublicSubkeyPacket : GPGPublicKeyPacket
@end


@interface GPGSecretKeyPacket : GPGPublicKeyPacket
@end


@interface GPGSecretSubkeyPacket : GPGSecretKeyPacket
@end



