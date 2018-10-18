#import <XCTest/XCTest.h>
#import "GPGUnitTest.h"


@interface GPGPacketTest : XCTestCase
@end

@implementation GPGPacketTest


- (void)testKey1 {
	GPGStream *stream = [GPGUnitTest streamForResource:@"key1.gpg"];
	GPGPacketParser *parser = [GPGPacketParser packetParserWithStream:stream];
	GPGPacket *packet;
	NSUInteger i = 0;
	
	NSArray *conditionList = @[
		   @{@"fingerprint": @"77270A31BEE39087C6B7E771F988A4590DB03A7D",
			 @"keyID": @"F988A4590DB03A7D",
			 @"version": @4,
			 @"creationTime": @1313104392,
			 @"publicAlgorithm": @1},
		   @{@"userID": @"GPGTools Test Key (For testing purposes only!) <test@gpgtools.org>"},
		   @{@"keyID": @"F988A4590DB03A7D",
			 @"version": @4,
			 @"creationTime": @1313104392,
			 @"publicAlgorithm": @1,
			 @"hashStart": @65285,
			 @"type": @19,
			 @"hashAlgorithm": @2},
		   @{@"fingerprint": @"30BD46FC8599CB334466CFC5526B09F10AA3DA82",
			 @"keyID": @"526B09F10AA3DA82",
			 @"version": @4,
			 @"creationTime": @1313104392,
			 @"publicAlgorithm": @1},
		   @{@"keyID": @"F988A4590DB03A7D",
			 @"version": @4,
			 @"creationTime": @1313104392,
			 @"publicAlgorithm": @1,
			 @"hashStart": @63416,
			 @"type": @24,
			 @"hashAlgorithm": @2}
		   ];
	
	
	
	while ((packet = [parser nextPacket])) {
		if (i >= conditionList.count) {
			XCTFail(@"Too many packets parsed! (%lu > %lu)", i+1, conditionList.count);
			break;
		}
		
		NSDictionary *conditions = conditionList[i];
		for (NSString *key in conditions) {
			id expectedValue = conditions[key];
			id value = [packet valueForKey:key];
			
			XCTAssertEqualObjects(expectedValue, value, @"Wrong value returned by GPGPacket.");
		}
		
		i++;
	}

	if (i < conditionList.count) {
		XCTFail(@"Not enough packets parsed! (%lu < %lu)", i, conditionList.count);
	}
}


- (void)testCompressed {
	GPGStream *stream = [GPGUnitTest streamForResource:@"compressed1.gpg"];
	GPGPacketParser *parser = [GPGPacketParser packetParserWithStream:stream];
	GPGPacket *packet;
	NSUInteger i = 0;
	
	NSArray *conditionList = @[
							   @{@"format": @98,
								 @"filename": @"tv",
								 @"time": @1436958747,
								 @"content": [NSData dataWithBytes:"ok\n" length:3]},
							   ];
	
	while ((packet = [parser nextPacket])) {
		if (i >= conditionList.count) {
			XCTFail(@"Too many packets parsed! (%lu > %lu)", i+1, conditionList.count);
			break;
		}
		
		NSDictionary *conditions = conditionList[i];
		for (NSString *key in conditions) {
			id expectedValue = conditions[key];
			id value = [packet valueForKey:key];
			
			XCTAssertEqualObjects(expectedValue, value, @"Wrong value returned by GPGPacket.");
		}
		
		i++;
	}
	
	if (i < conditionList.count) {
		XCTFail(@"Not enough packets parsed! (%lu < %lu)", i, conditionList.count);
	}
	
}




@end
