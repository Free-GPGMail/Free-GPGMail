/* GPGUserIDPacket.m
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

#import "GPGUserIDPacket.h"
#import "GPGPacket_Private.h"

@interface GPGUserIDPacket ()
@property (nonatomic, strong, readwrite) NSString *userID;
@end


@implementation GPGUserIDPacket
@synthesize userID;


- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.userID = [parser stringWithLength:length];
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 13;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@: \"%@\"", self.className, self.userID];
}

- (void)dealloc {
	self.userID = nil;
	[super dealloc];
}


@end

