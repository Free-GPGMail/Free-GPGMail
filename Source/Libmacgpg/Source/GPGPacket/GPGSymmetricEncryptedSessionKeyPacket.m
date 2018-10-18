/* GPGSymmetricEncryptedSessionKeyPacket.m
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

#import "GPGSymmetricEncryptedSessionKeyPacket.h"
#import "GPGPacket_Private.h"

@interface GPGSymmetricEncryptedSessionKeyPacket ()
@property (nonatomic, readwrite) NSInteger symmetricAlgorithm;
@property (nonatomic, readwrite) NSInteger version;
@property (nonatomic, strong, readwrite) NSString *keyID;
@end


@implementation GPGSymmetricEncryptedSessionKeyPacket
@synthesize symmetricAlgorithm, version, keyID;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.version = parser.byte;
	self.symmetricAlgorithm = parser.byte;

	
	// TODO: parse string-to-key.
	
	
	[parser skipRemaining];
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 3;
}

- (void)dealloc {
	self.keyID = nil;
	[super dealloc];
}


@end
