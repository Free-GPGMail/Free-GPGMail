/*
 GPGConfReaderTest.m
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
#import "GPGConfReader.h"
#import "GPGStdSetting.h"
#import "GPGArraySetting.h"

@interface GPGConfReaderTest : XCTestCase
@end

@implementation GPGConfReaderTest

- (void) testComponentsSeparatedOnWhitespace {

    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    
    NSString *input = @" a b  c ";
    NSString *trimmedInput = [input stringByTrimmingCharactersInSet:whsp];
    XCTAssertEqualObjects(@"a b  c", trimmedInput, @"Not trimmed as expected!");
    
    NSArray *splitTrimmed = [trimmedInput componentsSeparatedByCharactersInSet:whsp];
	XCTAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
}

- (void) testSplitString {

    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];

    NSString *input = @"a bb  ccc  ddddd";
    NSArray *splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
	XCTAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
    
    XCTAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    XCTAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    XCTAssertEqualObjects(@"ccc", [splitTrimmed objectAtIndex:2], @"Element not as expected!");
    XCTAssertEqualObjects(@"ddddd", [splitTrimmed objectAtIndex:3], @"Element not as expected!");

    input = @"a     bb  ";
    splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
 	XCTAssertTrue(3 == [splitTrimmed count], @"Not split as expected!");
   
    XCTAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    XCTAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    XCTAssertEqualObjects(@"", [splitTrimmed objectAtIndex:2], @"Element not as expected!");

    input = @" a    bb  ";
    splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
	XCTAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
    
    XCTAssertEqualObjects(@"", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    XCTAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    XCTAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:2], @"Element not as expected!");
    XCTAssertEqualObjects(@"", [splitTrimmed objectAtIndex:3], @"Element not as expected!");
}

- (void) testLimitedSplitString {
    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    NSMutableCharacterSet *whspeqsign = [NSMutableCharacterSet characterSetWithCharactersInString:@"="];
    [whspeqsign formUnionWithCharacterSet:whsp];
    
    NSString *input = @"a   = bb ccc    ";
    NSArray *splitTrimmed = [GPGConfReader splitString:input bySet:whspeqsign maxCount:2];
	XCTAssertTrue(2 == [splitTrimmed count], @"Not split as expected!");
    
    XCTAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    XCTAssertEqualObjects(@"bb ccc    ", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
}

- (void) testKeyForLine {

    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    NSString *key = [reader condensedKeyForLine:@" option1 a=b"];
    XCTAssertEqualObjects(@"option1", key, @"Setting key not as expected!");

    key = [reader condensedKeyForLine:@" #option1 a=b"];
    XCTAssertNil(key, @"Unknown commented option not ignored!");

    key = [reader condensedKeyForLine:@" #no-sig-cache"];
    XCTAssertEqualObjects(@"sig-cache", key, @"\"no-\" not removed as expected!");

    key = [reader condensedKeyForLine:@" #no-auto-key-locate"];
    XCTAssertEqualObjects(@"no-auto-key-locate", key, @"Special case not handled as expected!");
}

- (void) testClassForLine {
    
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [reader buildForLine:@" #no-auto-key-locate  "];
    XCTAssertNotNil(setting, @"Unexpectedly nil!");
    XCTAssertEqualObjects(@"no-auto-key-locate", setting.key, @"Unexpected key!");
    XCTAssertTrue([setting isKindOfClass:[GPGStdSetting class]], @"Unexpected class!"); 

    setting = [reader buildForLine:@" export-options   export-minimal"];
    XCTAssertNotNil(setting, @"Unexpectedly nil!");
    XCTAssertEqualObjects(@"export-options", setting.key, @"Unexpected key!");
    XCTAssertTrue([setting isKindOfClass:[GPGArraySetting class]], @"Unexpected class!"); 
}

@end
