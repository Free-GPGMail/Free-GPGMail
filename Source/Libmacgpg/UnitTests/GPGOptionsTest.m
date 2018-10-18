#import <XCTest/XCTest.h>
#import "GPGOptions.h"

@interface GPGOptionsTest : XCTestCase

@end

@implementation GPGOptionsTest

- (void)testDomainForKey1 {

    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"marginals-needed"];
    XCTAssertEqual(domain, GPGDomain_gpgConf, @"unexpected domain");
}

- (void)testDomainForKey2 {
    
    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"min-passphrase-nonalpha"];
    XCTAssertEqual(domain, GPGDomain_gpgAgentConf, @"unexpected domain");
}

- (void)testDomainForKey3 {
    
    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"ShowPassphrase"];
    XCTAssertEqual(domain, GPGDomain_common, @"unexpected domain");
}

- (void)testDomainForKey4 {

	GPGOptions *options = [GPGOptions sharedOptions];
	GPGOptionsDomain domain = [options domainForKey:@"nameserver"];
	XCTAssertEqual(domain, GPGDomain_dirmngrConf, @"unexpected domain");
}

@end
