/*
 GPGLinesSettingTest.m
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
#import "GPGLinesSetting.h"
#import "GPGConfReader.h"

@interface GPGLinesSettingTest : XCTestCase {
    NSString *key;
    NSArray *testlines;
}

@end

@implementation GPGLinesSettingTest

- (void) setUp {
    key = @"comment";
    testlines = [NSArray arrayWithObjects:@"abc", @"def", nil];
}

- (void) testSetValue {
    GPGLinesSetting *setting = [[GPGLinesSetting alloc] initForKey:key];
    [setting setValue:testlines];

    id value = [setting value];
    XCTAssertNotNil(value, @"Unexpectedly nil!");
    XCTAssertTrue([value count] == [testlines count], @"Incorrect count!");
}

- (void) testSetNil {
    GPGLinesSetting *setting = [[GPGLinesSetting alloc] initForKey:key];
    [setting setValue:testlines];
    [setting setValue:nil];
    
    id value = [setting value];
    XCTAssertNotNil(value, @"Unexpectedly nil!");
    XCTAssertTrue([value count] == 0, @"Incorrect count!");
}

- (void) testGetValue {    
    GPGLinesSetting *setting = [[GPGLinesSetting alloc] initForKey:key];
    [setting setValue:testlines];
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"comment abc\ncomment def\n", desc, @"description not as expected!");
    
}

- (void) testAppendLine {
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGLinesSetting *setting = [[GPGLinesSetting alloc] initForKey:key];
    [setting appendLine:@"comment   line 1." withReader:reader];
    [setting appendLine:@"comment   line 2." withReader:reader];
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"#comment line 1.\n#comment line 2.\n", desc, @"description not as expected!");
}

@end
