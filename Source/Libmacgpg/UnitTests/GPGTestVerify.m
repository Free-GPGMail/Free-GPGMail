//
//  GPGTestVerify.h
//  Libmacgpg
//
//  Created by Chris Fraire on 3/22/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "Libmacgpg.h"
#import "GPGUnitTest.h"
//#import "GPGController.h"
//#import "GPGResourceUtil.h"
//#import "GPGSignature.h"



@interface GPGTestVerify : XCTestCase
@end

@implementation GPGTestVerify

+ (void)setUp {
	[GPGUnitTest setUpTestDirectory];
}

- (void)testCheckTestKey {
    GPGKey *key = [manager.allKeys member:testKey];
	XCTAssertNotNil(key, @"Test key not imported!");
	XCTAssertTrue([key.fingerprint isEqualToString:testKey], @"Test key fingerprint does not match!");
}

- (void)testVerifyDataLF {
    NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringLF.txt"];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];

	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorNoError, @"Did not verify as expected!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
	XCTAssertTrue(gpgc.wasSigned, @"wasSigned was not set!");

}


- (void)testVerifyDataCRLF {
	NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringCRLF.txt"];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];
	
	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorNoError, @"Did not verify as expected!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
}

- (void)testVerifyDataCR {
	NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringCR.txt"];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];
	
	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorNoError, @"Did not verify as expected!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
}

- (void)testVerifyForceLF_to_CRLF {
	NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringLF.txt"];
    NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
    data = [dstring UTF8Data];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];
	
	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorNoError, @"Did not verify as expected!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
}

- (void)testVerifyForceCRLF_to_LF {
	NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringCRLF.txt"];
	NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    data = [dstring UTF8Data];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];
	
	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorNoError, @"Did not verify as expected!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
}

- (void)testBadVerifyForceCR_to_LF {
	NSData *data = [GPGUnitTest dataForResource:@"SignedInputStringCR.txt"];
	NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    data = [dstring UTF8Data];
	
	NSArray *sigs = [gpgc verifySignature:data originalData:nil];
	
	XCTAssertTrue(sigs.count == 1, @"Did not verify as expected!");
	GPGSignature *signature = sigs[0];
	XCTAssertEqual(signature.status, GPGErrorBadSignature, @"Verified unexpectedly!");
	XCTAssertEqualObjects(signature.fingerprint, testSubkey, @"Did not verify as expected!");
}

@end
