/* GPGPacket.m
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

#import "Libmacgpg.h"
#import "GPGPacket.h"
#import "GPGPacket_Private.h"
#import "GPGPacketParser.h"

#import "GPGMemoryStream.h"
#import "GPGUnArmor.h"


@implementation GPGPacket
@synthesize data=_data;

// Only placeholder methods.
- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	return [super init];
}
- (GPGPacketTag)tag {
	return 0;
}



+ (NSDictionary *)capabilitiesOfPackets:(NSArray *)packets {
	BOOL canEncrypt = NO;
	BOOL canSign = NO;
	BOOL revoked = NO;
	BOOL invalid = NO;
	BOOL stop = NO;
	NSUInteger expirationTime = 0;
	GPGPacketTag lastTag;
	GPGPacket *lastPacket;
	
	
	if (packets.count == 0) {
		return nil;
	}
	
	
	GPGPublicKeyPacket *mainPacket = packets[0];
	switch (mainPacket.tag) {
		case 5:
		case 6:
			lastTag = mainPacket.tag;
			lastPacket = mainPacket;
			if (mainPacket.version != 4) {
				// Only version 4 key are considered valid.
				invalid = YES;
			}
			break;
		default:
			return nil;
	}
	
	NSString *keyID = mainPacket.keyID;
	NSUInteger now = (NSUInteger)[[NSDate date] timeIntervalSince1970];
	
	
	
	
	
	for (GPGPacket *packet in packets) {
		NSInteger tag = packet.tag;
		
		switch (tag) {
			case 5:
			case 6: { // Public/Secret Key
				GPGPublicKeyPacket *realPacket = (id)packet;
				if (![keyID isEqualToString:realPacket.keyID]) {
					// Start of another key.
					// Only parse the first key.
					stop = YES;
				}
				break;
			}
			case 7:
			case 14: {
				GPGPublicSubkeyPacket *realPacket = (id)packet;
				if (realPacket.version != 4) {
					// Ignore the signatures of this subkey.
					tag = 0;
				}
				break;
			}
			case 2: { // Signature Packet
				GPGSignaturePacket *realPacket = (id)packet;
				switch (realPacket.type) {
					case 16:
					case 17:
					case 18:
					case 19: { // UserID signature.
						if ([keyID isEqualToString:realPacket.keyID]) {
							// Self-signature.
							for (NSDictionary *subpacket in realPacket.subpackets) {
								NSInteger subTag = [subpacket[@"tag"] integerValue];

								if (subTag == 9) { // Key Expiration Time
									NSUInteger tempExpirationTime = [subpacket[@"time"] unsignedIntegerValue];
									if (tempExpirationTime) {
										tempExpirationTime = realPacket.creationTime + tempExpirationTime;
										
										if (tempExpirationTime > expirationTime) {
											// Save the latest expiration time.
											expirationTime = tempExpirationTime;
										}
										break;
									}
								} else if (subTag == 27) {
									canEncrypt = canEncrypt || [subpacket[@"canEncryptCommunications"] boolValue] || [subpacket[@"canEncryptStorage"] boolValue];
									canSign = canSign || [subpacket[@"canSign"] boolValue];
								}
							}
						}
						break;
					}
					case 24: { // Subkey Binding Signature
						if ((lastTag == 7 || lastTag == 14) && [keyID isEqualToString:realPacket.keyID]) {
							// Last packet was a subkey and it's issued by the primary key.
							
							BOOL subkeyCanEncrypt = NO;
							BOOL subkeyCanSign = NO;
							
							for (NSDictionary *subpacket in realPacket.subpackets) {
								NSInteger subTag = [subpacket[@"tag"] integerValue];
								if (subTag == 9) { // Key Expiration Time
									NSUInteger tempExpirationTime = [subpacket[@"time"] unsignedIntegerValue];
									if (tempExpirationTime && now - [(GPGPublicSubkeyPacket *)lastPacket creationTime] >= tempExpirationTime) {
										// The subkey is expired.
										subkeyCanEncrypt = NO;
										subkeyCanSign = NO;
										break;
									}
								} else if (subTag == 27) { // Key Flags
									subkeyCanEncrypt = subkeyCanEncrypt || [subpacket[@"canEncryptCommunications"] boolValue] || [subpacket[@"canEncryptStorage"] boolValue];
									subkeyCanSign = subkeyCanSign || [subpacket[@"canSign"] boolValue];
								}
							}
							
							canEncrypt = canEncrypt || subkeyCanEncrypt;
							canSign = canSign || subkeyCanSign;
						}
						break;
					}
					case 32: { // Key revocation signature
						if ((lastTag == 5 || lastTag == 6) && [keyID isEqualToString:realPacket.keyID]) {
							revoked = YES;
						}
						break;
					}
					default:
						break;
				} // End switch (realPacket.type)
				break;
			}
				
				
			default:
				break;
		}
		lastTag = tag;
		lastPacket = packet;
		
		if (stop) {
			break;
		}
	}
	
	BOOL expired = expirationTime > 0 && now >= expirationTime;
	
	NSDictionary *capabilities = @{@"canEncrypt": @(canEncrypt),
								   @"canSign": @(canSign),
								   @"revoked": @(revoked),
								   @"expired": @(expired),
								   @"invalid": @(invalid)
								   };
	
	return capabilities;
}





+ (id)packetsWithData:(NSData *)theData {
	NSMutableArray *packets = [NSMutableArray array];
	
	[self enumeratePacketsWithData:theData block:^(GPGPacket *packet, BOOL *stop) {
		[packets addObject:packet];
	}];
	
	return packets;
}

+ (void)enumeratePacketsWithData:(NSData *)theData block:(void (^)(GPGPacket *packet, BOOL *stop))block {
	theData = [theData copy];
	
	if (theData.isArmored) {
		GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:theData];
		GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
		
		[unArmor decodeAll];
		
		[theData release];
		theData = [unArmor.data retain];
	}
	
	if (theData.length < 10) {
		[theData release];
		return;
	}
	
	GPGMemoryStream *stream = [[GPGMemoryStream alloc] initForReading:theData];
	GPGPacketParser *parser = [[GPGPacketParser alloc] initWithStream:stream];
	GPGPacket *packet;
	
	while ((packet = [parser nextPacket])) {
		BOOL stop = NO;
		block(packet, &stop);
		if (stop) {
			break;
		}
	}
	
	[parser release];
	[stream release];
	[theData release];
}


// Old methods, only for compatibility.
// They will be removed in the future.

- (NSInteger)type {
	return self.tag;
}
- (NSString *)keyID {
	return nil;
}
- (NSInteger)signatureType {
	if (self.tag == GPGSignaturePacketTag) {
		return [self type];
	} else {
		return 0;
	}
}

// if return nil, input stream is not armored; should be reset and used directly
+ (NSData *)unArmor:(NSData *)data {
	return [self unArmor:data clearText:nil];
}
+ (NSData *)unArmor:(NSData *)data clearText:(NSData **)clearText {
	GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:data];
	GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
	
	[unArmor decodeAll];
	
	if (clearText) {
		*clearText = unArmor.clearText;
	}
	
	return unArmor.data;
}





@end
