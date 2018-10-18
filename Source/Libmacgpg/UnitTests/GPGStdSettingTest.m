/*
 GPGStdSettingTest.m
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
#import "GPGStdSetting.h"
#import "GPGConfReader.h"

@interface GPGStdSettingTest : XCTestCase
@end

@implementation GPGStdSettingTest

- (void) testSetString {
    NSString *key = @"keyserver", *value = @"hkp://domain.com";
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting setValue:value];

    id value2 = [setting value];
    XCTAssertNotNil(value2, @"Unexpectedly nil!");
}

- (void) testSetNil {
    NSString *key = @"keyserver";
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting setValue:nil];
    
    id value2 = [setting value];
    XCTAssertNil(value2, @"Unexpectedly defined!");
}

- (void) testDescription {
    NSString *key = @"keyserver", *value = @"hkp://domain.com";
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting setValue:value];

    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"keyserver hkp://domain.com\n", desc, @"description not as expected!");

    [setting setValue:nil];
    desc = [setting description];
    XCTAssertEqualObjects(@"#keyserver\n", desc, @"description not as expected!");

}

- (void) testAppendLineString {
    NSString *key = @"keyserver";
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting appendLine:@"keyserver     hkp://domain.com" withReader:reader];
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"#keyserver hkp://domain.com\n", desc, @"description not as expected!");
    
}

- (void) testAppendLineTRUE {
    NSString *key = @"ask-cert-level";
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting appendLine:@"ask-cert-level    " withReader:reader];

    id value = [setting value];
    XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"Not NSNumber as expected!");
    XCTAssertTrue([value boolValue], @"Not TRUE as expected!");

    setting.isActive = FALSE;
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"#ask-cert-level\n", desc, @"description not as expected!");
    
}

- (void) testAppendLineFALSE {
    NSString *key = @"ask-cert-level";
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];
    [setting appendLine:@"no-ask-cert-level    " withReader:reader];
    
    id value = [setting value];
    XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"Not NSNumber as expected!");
    XCTAssertFalse([value boolValue], @"Not FALSE as expected!");
    
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    XCTAssertEqualObjects(@"#no-ask-cert-level\n", desc, @"description not as expected!");
    
}

- (void) testgpgdotconf1 {
    NSString *key = @"ask-cert-level";
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [[GPGStdSetting alloc] initForKey:key];

    NSArray *lines = [NSArray arrayWithObjects:
                      @"# Some comment.",
                      @"# More comment. ",
                      @"ask-cert-level    ",
                      @"# Another comment. ",
                      @"no-ask-cert-level    ", nil];
    for (NSString *line in lines) {
        [setting appendLine:line withReader:reader];
    }

    id value = [setting value];
    XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"Not NSNumber as expected!");
    XCTAssertFalse([value boolValue], @"Not FALSE as expected!");

    NSString* desc = [setting description];
    NSString* expected = [NSString stringWithFormat:@"%@\n", [lines componentsJoinedByString:@"\n"]];
    XCTAssertEqualObjects(expected, desc, @"description not as expected!");

    setting.isActive = FALSE;
    desc = [setting description];
    expected = @"# Some comment.\n# More comment. \n#no-ask-cert-level\n";
    XCTAssertEqualObjects(expected, desc, @"description not as expected!");

}

@end
