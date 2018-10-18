/*
 GPGArraySettingTest.m
 Libmacgpg
 
 Copyright (c) 2012 Chris Fraire. All rights reserved.
 
 Libmacgpg is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <XCTest/XCTest.h>
#import "GPGArraySetting.h"
#import "GPGConfReader.h"

@interface GPGArraySettingTest : XCTestCase {
    NSString *key;
    NSArray *testwords;
}

@end

@implementation GPGArraySettingTest

- (void) setUp {
    key = @"auto-key-locate";
    testwords = [NSArray arrayWithObjects:@"cert", @"pka", nil];
}

- (void) tearDown {
    testwords = nil;
}

- (void) testSetValue {
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];

    id value = [setting value];
    XCTAssertNotNil(value, @"Unexpectedly nil!");
    XCTAssertTrue([value count] == [testwords count], @"Incorrect count!");
}

- (void) testSetNil {
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];
    [setting setValue:nil];
    
    id value = [setting value];
    XCTAssertNotNil(value, @"Unexpectedly nil!");
    XCTAssertTrue([value count] == 0, @"Incorrect count!");
}

- (void) testGetValue {    
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"auto-key-locate cert pka\n", desc, @"description not as expected!");
}

- (void) testAppendLine {
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting appendLine:@"auto-key-locate  cert,pka" withReader:reader];
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"#auto-key-locate cert pka\n", desc, @"description not as expected!");
}

@end
