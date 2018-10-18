/* GPGLiteralDataPacket.m
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

#import "GPGLiteralDataPacket.h"
#import "GPGPacket_Private.h"

@interface GPGLiteralDataPacket ()
@property (nonatomic, readwrite) NSInteger format;
@property (nonatomic, strong, readwrite) NSString *filename;
@property (nonatomic, readwrite) NSUInteger time;
@property (nonatomic, copy, readwrite) NSData *content;
@end


@implementation GPGLiteralDataPacket
@synthesize format, filename, time, content;


- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	 // 'b': binary, 't': text (convert line-endings), 'u': like 't' but UTF8.
	self.format = parser.byte;
	
	// filename could be empty.
	NSUInteger filenameLength = parser.byte;
	self.filename = [parser stringWithLength:filenameLength];
	
	self.time = parser.time;
	
	// Decrement by the number of bytes read.
	length = length - 6 - filenameLength;
	
	cancelInitOnEOF();
	
	// Read the content bytes of the packet.
	NSMutableData *tempData = [NSMutableData data];
	NSUInteger i = 0;
	while (length > 0) {
		tempData.length += length;
		UInt8 *bytes = tempData.mutableBytes;
		
		for (NSUInteger j = 0; j < length; j++) {
			bytes[i++] = (UInt8)parser.byte;
			cancelInitOnEOF();
		}
		
		if (parser.partial) {
			length = parser.nextPartialLength;
		} else {
			length = 0;
		}
	}
	
	self.content = tempData;
	
	cancelInitOnEOF();
	return self;
}

- (GPGPacketTag)tag {
	return 11;
}

- (void)dealloc {
	self.filename = nil;
	self.content = nil;
	[super dealloc];
}


@end

