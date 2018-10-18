/* GPGPublicKeyEncryptedSessionKeyPacket.m
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

#import "GPGPublicKeyEncryptedSessionKeyPacket.h"
#import "GPGPacket_Private.h"

@interface GPGPublicKeyEncryptedSessionKeyPacket ()
@property (nonatomic, readwrite) NSInteger publicAlgorithm;
@property (nonatomic, readwrite) NSInteger version;
@property (nonatomic, strong, readwrite) NSString *keyID;
@end


@implementation GPGPublicKeyEncryptedSessionKeyPacket
@synthesize publicAlgorithm, version, keyID;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.version = parser.byte;
	self.keyID = parser.keyID;
	self.publicAlgorithm = parser.byte;
	
	// We ignore the MPIs at the moment.
	switch (publicAlgorithm) {
		case 1:
		case 2:
		case 3:
			[parser multiPrecisionInteger]; // "RSA m^e mod n"
			break;
		case 16:
		case 20:
			[parser multiPrecisionInteger]; // "ElGamal g^k mod p"
			[parser multiPrecisionInteger]; // "ElGamal m * y^k mod p"
			break;
		case 17:
			[parser multiPrecisionInteger]; // "DSA ?"
			[parser multiPrecisionInteger]; // "DSA ?"
			break;
		default:
			[parser skip:length - 10];
			break;
	}
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 1;
}

- (void)dealloc {
	self.keyID = nil;
	[super dealloc];
}


@end
