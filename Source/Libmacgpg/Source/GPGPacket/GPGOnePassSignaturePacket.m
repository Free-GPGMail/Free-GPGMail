/* GPGOnePassSignaturePacket.m
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

#import "GPGOnePassSignaturePacket.h"
#import "GPGPacket_Private.h"

@interface GPGOnePassSignaturePacket ()
@property (nonatomic, readwrite) NSInteger publicAlgorithm;
@property (nonatomic, readwrite) NSInteger hashAlgorithm;
@property (nonatomic, readwrite) NSInteger type;
@property (nonatomic, readwrite) NSInteger version;
@property (nonatomic, strong, readwrite) NSString *keyID;
@end


@implementation GPGOnePassSignaturePacket
@synthesize publicAlgorithm, hashAlgorithm, type, version, keyID;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.version = parser.byte;
	self.type = parser.byte;
	self.hashAlgorithm = parser.byte;
	self.publicAlgorithm = parser.byte;
	self.keyID = parser.keyID;

	[parser byte]; // Ignore (0 means the next packet is another one-pass signature)
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 4;
}

- (void)dealloc {
	self.keyID = nil;
	[super dealloc];
}


@end
