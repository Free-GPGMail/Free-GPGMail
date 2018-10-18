/* GPGPacketParser.h
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

@class GPGStream;
@class GPGPacket;
@class GPGCompressedDataPacket;

typedef void (^ByteCallback)(NSInteger);


@interface GPGPacketParser : NSObject {
	
	// Properties
	GPGStream *stream;
	NSError *error;
	
	ByteCallback byteCallback;
	GPGCompressedDataPacket *compressedPacket;
	
	BOOL partial;
	NSUInteger packetLength;


	// Private
	BOOL eofReached;
	NSMutableData *packetData;
}

@property (nonatomic, readonly, strong) NSError *error;


+ (instancetype)packetParserWithStream:(GPGStream *)stream;

- (instancetype)initWithStream:(GPGStream *)stream;
/**
 Get the next packet from the stream.
 Sets error if an error occurred.
 @returns The next packet (subclass of GPGPacket) or nil if an error occurred or it was the last packet.
 */
- (GPGPacket *)nextPacket;

@end
