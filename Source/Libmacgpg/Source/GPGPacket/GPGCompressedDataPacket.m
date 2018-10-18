/* GPGCompressedDataPacket.m
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

#import "GPGCompressedDataPacket.h"
#import "GPGCompressedDataPacket_Private.h"
#import "GPGPacket_Private.h"
#import "GPGPacketParser.h"
#import "GPGStream.h"
#import <zlib.h>
#import <bzlib.h>

// A primitive GPGStream to read data out of compressed packets.
@interface GPGDecompressStream : GPGStream {
	GPGPacketParser *parser;
	NSInteger algorithm;
	z_stream zStream;
	bz_stream bzStream;
	
	NSUInteger packetLength;
	
	BOOL streamEnd;
	NSUInteger availablePacketBytes;
	NSMutableData *inputData;
	UInt8 *inputBytes;
	NSUInteger inputSize;
	
	NSMutableData *cacheData;
	UInt8 *cacheBytes;
	
	NSUInteger cacheLocation;
	NSUInteger cacheAvailableBytes;
}
- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length algorithm:(NSInteger)algorithm;
@end



@interface GPGCompressedDataPacket ()
@property (nonatomic, readwrite) NSInteger compressAlgorithm;
@property (nonatomic, strong, readwrite) GPGDecompressStream *decompressStream;
@property (nonatomic, strong) GPGPacketParser *subParser;
@end


@implementation GPGCompressedDataPacket
@synthesize compressAlgorithm, decompressStream, subParser;

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	self.compressAlgorithm = parser.byte;
	length--;
	
	switch (compressAlgorithm) {
		case 0: // Uncompressed. Why should this happen?
		case 1: // ZIP [RFC1951]
		case 2: // ZLIB [RFC1950]
		case 3: // BZip2
			break;
		default:
			// Unknown/invalid compression algorithm.
			[parser skip:length];
			return self;
	}
	cancelInitOnEOF();
	
	// The GPGDecompressStream will be given to a new GPGPacketParser, to decode the packets inside of this packet.
	self.decompressStream = [[GPGDecompressStream alloc] initWithParser:parser length:length algorithm:compressAlgorithm];
	if (decompressStream) {
		self.subParser = [[GPGPacketParser alloc] initWithStream:self.decompressStream];
	}
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacket *)nextPacket {
	// Return the next decompressed packet.
	GPGPacket *packet = [subParser nextPacket];
	if (!packet) {
		self.decompressStream = nil;
		self.subParser = nil;
	}
	return packet;
}

- (BOOL)canDecompress {
	// Indicate if we are able to decompress this packet.
	return !!subParser;
}

- (GPGPacketTag)tag {
	return 8;
}

- (void)dealloc {
	self.decompressStream = nil;
	self.subParser = nil;
	[super dealloc];
}
@end



@implementation GPGDecompressStream
const NSUInteger cacheSize = 1024 * 32;

- (void)dealloc {
	[cacheData release];
	[inputData release];
	[parser release];
	[super dealloc];
}

- (instancetype)initWithParser:(GPGPacketParser *)theParser length:(NSUInteger)length algorithm:(NSInteger)theAlgorithm {
	self = [super init];
	if (!self) {
		return nil;
	}

	
	parser = [theParser retain];
	algorithm = theAlgorithm;
	packetLength = length;
	availablePacketBytes = packetLength;

	inputData = [[NSMutableData alloc] initWithLength:cacheSize];
	cacheData = [[NSMutableData alloc] initWithLength:cacheSize];

	// Initialize the right decompression engine.
	int status = 0;
	switch (algorithm) {
		case 0:
			// No compresseion.
			[inputData release];
			inputData = [cacheData retain];
			break;
		case 1:
			// ZIP (zlib with another init)
			status = inflateInit2(&zStream, -13);
			break;
		case 2:
			// ZLIB
			status = inflateInit(&zStream);
			break;
		case 3:
			// BZip2
			status = BZ2_bzDecompressInit(&bzStream, 0, 0);
			break;
	}
	
	if (status != 0) {
		// Something went wrong.
		[self release];
		return nil;
	}
	
	inputBytes = inputData.mutableBytes;
	cacheBytes = cacheData.mutableBytes;

	return self;
}

- (void)fillInput {
	// Read up to cacheSize bytes and store it in inputBytes.
	
	inputSize = 0;
	if (packetLength != 0) {
		for (; inputSize < cacheSize; inputSize++) {
			// Read a byte.
			NSInteger byte = parser.byte;
			if (byte == EOF) {
				break;
			}
			// Store it in inputBytes.
			inputBytes[inputSize] = (UInt8)byte;
			availablePacketBytes--;
			
			
			if (availablePacketBytes == 0) {
				// We have reached the end of this packet/part.
				
				if (parser.partial) {
					// It's a partial packet, we have to read the next part.
					packetLength = parser.nextPartialLength;
					availablePacketBytes = packetLength;
				} else {
					// It's a normal packet, so we are really at the end.
					packetLength = 0;
				}
				if (packetLength == 0) {
					// We have no more data.
					break;
				}
			}
		}
	}

}

- (BOOL)zlibFillCache {
	// Fill our cache by decompressing using zlib.
	
	// Let zlib write directly in our cache.
	zStream.avail_out = cacheSize;
	zStream.next_out = cacheBytes;
	
	do {
		if (zStream.avail_in == 0) {
			// We need more input Data, fill the buffer.
			[self fillInput];
			zStream.avail_in = (uInt)inputSize;
			zStream.next_in = inputBytes;
		}
		
		// Decompress.
		int status = inflate(&zStream, Z_SYNC_FLUSH);
		
		if (status != Z_OK) {
			inflateEnd(&zStream);
			streamEnd = YES;
			if (status != Z_STREAM_END) {
				// Something went wrong.
				return NO;
			}
		}
		
	} while (zStream.avail_out == cacheSize);
	
	// Calculate number of bytes in cache.
	cacheAvailableBytes = cacheSize - zStream.avail_out;
	
	return YES;
}

- (BOOL)bzFillCache {
	// Fill our cache by decompressing using bzip2.

	// Let bzip2 write directly in our cache.
	bzStream.avail_out = cacheSize;
	bzStream.next_out = (char *)cacheBytes;
	
	do {
		if (bzStream.avail_in == 0) {
			// We need more input Data, fill the buffer.
			[self fillInput];
			bzStream.avail_in = (uInt)inputSize;
			bzStream.next_in = (char *)inputBytes;
		}
		
		// Decompress.
		int status = BZ2_bzDecompress(&bzStream);
		
		if (status != BZ_OK) {
			BZ2_bzDecompressEnd(&bzStream);
			streamEnd = YES;
			if (status != BZ_STREAM_END) {
				// Something went wrong.
				return NO;
			}
		}
		
	} while (bzStream.avail_out == cacheSize);
	
	
	// Calculate number of bytes in cache.
	cacheAvailableBytes = cacheSize - bzStream.avail_out;
	
	return YES;
}

- (BOOL)uncompressedFillCache {
	// inputData and cacheData are the same, so we have simply to fill the input,
	// and set the number of bytes in cache to inputSize.
	
	[self fillInput];
	
	if (inputSize == 0) {
		streamEnd = YES;
		return NO;
	}
	cacheAvailableBytes = inputSize;
	
	return YES;
}

- (NSInteger)readByte {
	// Read the next byte from the cache.
	// Refill the cache if empty.
	
	if (cacheAvailableBytes == 0) { // Cache is emtpy.
		
		if (streamEnd) {
			// We have already reached the end of the stream.
			return EOF;
		}
		cacheLocation = 0; // Reset the cache read "pointer".
		
		
		// Fill the cache.
		BOOL moreData = NO;
		switch (algorithm) {
			case 0:
				moreData = [self uncompressedFillCache];
				break;
			case 1:
			case 2:
				moreData = [self zlibFillCache];
				break;
			case 3:
				moreData = [self bzFillCache];
				break;
		}
		
		if (streamEnd) {
			// We have reached the end of the stream.
			// Release the parser to prevent a retain cycle.
			[parser release];
			parser = nil;
		}
		if (!moreData) {
			return EOF;
		}

	}
	
	cacheAvailableBytes--;
	return cacheBytes[cacheLocation++];
}

@end
