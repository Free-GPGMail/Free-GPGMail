/* GPGPacket_Private.h
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

#import "GPGPacketParser_Private.h"

// If the end of file is reached during init, the packet
// is invalid: Release it and return nil.
#define cancelInitOnEOF() if (parser.eofReached) {[self release]; return nil;}


@class GPGPacketParser;

@interface GPGPacket ()
@property (nonatomic, copy, readwrite) NSData *data;

// This is the designated initializer of the sub-classes.
// This method may read up to length bytes from parser,
// it could read more, if it's a partial packet.
- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length;

@end
