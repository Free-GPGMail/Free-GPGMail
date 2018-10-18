//
//  GPGControllerTest.m
//  Libmacgpg
//
//  Created by Mento on 24.04.17.
//
//

#import <XCTest/XCTest.h>
#import "GPGUnitTest.h"
#import "GPGController.h"


@interface GPGControllerTest : XCTestCase <GPGControllerDelegate>
@property (nonatomic, assign) BOOL allowNoMDC;
@end

@implementation GPGControllerTest

+ (void)setUp {
	[GPGUnitTest setUpTestDirectory];
}

- (void)testDecryptData {
	NSData *encrypted = [GPGUnitTest dataForResource:@"Encrypted.gpg"];
	NSData *decrypted = [gpgc decryptData:encrypted];
	XCTAssertEqualObjects(decrypted, [NSData dataWithBytes:"OK\n" length:3], @"Did not decrypt as expected!");
	XCTAssertFalse(gpgc.wasSigned, @"wasSigned should be NO, but was YES!");
}

- (void)testDecryptCases {
	// Decrypt every "*.gpg" file in the Decrypt folder and compares it with the corresponding ".res".
	
	NSString *resourcePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Decrypt"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *files = [fileManager contentsOfDirectoryAtPath:resourcePath error:nil];
	XCTAssertNotNil(files, @"Unable to find test files!");
	
	
	for (NSString *filename in files) {
		if ([filename.pathExtension isEqualToString:@"gpg"]) {
			NSString *filePath = [resourcePath stringByAppendingPathComponent:filename];
			NSString *resPath = [filePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"res"];
			NSData *expectedData = [NSData dataWithContentsOfFile:resPath];
			
			GPGStream *encrypted = [GPGFileStream fileStreamForReadingAtPath:filePath];
			GPGMemoryStream *decrypted = [GPGMemoryStream memoryStream];
			
			[gpgc decryptTo:decrypted data:encrypted];
			
			NSData *decryptedData = decrypted.readAllData;
			
			if ([decryptedData isEqualToData:expectedData]) {
				printf("%s\n", [[NSString stringWithFormat:@"Test Decrypt %@ passed.", filename] UTF8String]);
			} else {
				XCTFail(@"Test Decrypt %@ failed!", filename);
			}
		}
	}
}

- (BOOL)gpgControllerShouldDecryptWithoutMDC:(GPGController *)gpgc {
	return self.allowNoMDC;
}

- (void)testDecryptNoMDC {
	NSString *expectedString = @"Message without MDC\n";
	NSData *encrypted = [GPGUnitTest dataForResource:@"NoMDC.gpg"];

	id oldDelegate = gpgc.delegate;
	gpgc.delegate = self;
	
	
	self.allowNoMDC = NO;
	NSData *decrypted = [gpgc decryptData:encrypted];
	XCTAssertTrue(decrypted.length == 0, @"Decrypted NoMDC did return some data!");
	XCTAssertTrue([(GPGException *)gpgc.error errorCode] == GPGErrorNoMDC, @"Did not return a NoMDC error!");
	XCTAssertFalse(gpgc.decryptionOkay, @"decryptionOkay should be NO, but was YES!");

	
	self.allowNoMDC = YES;
	decrypted = [gpgc decryptData:encrypted];
	XCTAssertEqualObjects(decrypted, expectedString.UTF8Data, @"Did not decrypt as expected!");
	XCTAssertNil(gpgc.error, @"Did return an error!");
	XCTAssertTrue(gpgc.decryptionOkay, @"decryptionOkay not set!");

	
	gpgc.delegate = oldDelegate;
}


- (void)testNoSecretKey {
	NSData *encrypted = [GPGUnitTest dataForResource:@"NoSecKey.gpg"];

	NSData *decrypted = [gpgc decryptData:encrypted];
	
	XCTAssertTrue(decrypted.length == 0, @"No secret key decryption did return some data!");
	XCTAssertTrue([(GPGException *)gpgc.error errorCode] == GPGErrorNoSecretKey, @"Did not return a NoSecretKey error!");
	XCTAssertFalse(gpgc.decryptionOkay, @"decryptionOkay should be NO, but was YES!");
}


@end
