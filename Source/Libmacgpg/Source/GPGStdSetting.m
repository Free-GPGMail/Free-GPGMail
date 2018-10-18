/*
 GPGStdSetting.m
 Libmacgpg
 
 Created by Chris Fraire on 2/21/12.
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

#import "GPGStdSetting.h"
#import "GPGConfReader.h"

@implementation GPGStdSetting

@synthesize key=key_;
@synthesize isActive=isActive_;

- (void) setIsActive:(BOOL)isActive {
    [raw_ release];
    raw_ = nil;        
    isActive_ = isActive;
}

- (id)init {
    return [self initForKey:nil];
}

// Designated initializer
- (id) initForKey:(NSString *)key {
    if ((self = [super init])) {
        raw_ = [[NSMutableString stringWithCapacity:0] retain];
        endComments_ = FALSE;
        firstComment_ = nil;
        self.key = key;
        isActive_ = FALSE;
        value_ = nil;
    }
    return self;
}

- (void) dealloc {
    [key_ release];
    [firstComment_ release];
    [raw_ release];
    [value_ release];
    [super dealloc];
}

- (NSString *) description {
    if (raw_)
        return [NSString stringWithString:raw_];

    NSMutableString *result = [NSMutableString stringWithCapacity:0];
    if (firstComment_) {
        [result appendString:firstComment_];
    }
    NSString *encoding = [self encodeValue];
    if (encoding) {
        [result appendString:encoding];
    }
    return result;
}

- (void) setComment:(NSString *)comment {
    [raw_ release];
    raw_ = nil;

    [firstComment_ release];
    firstComment_ = [[NSMutableString stringWithString:comment] retain];
    if (![comment hasSuffix:@"\n"])
        [firstComment_ appendString:@"\n"];
}

- (id) value {
    return [[value_ copy] autorelease];
}

- (void) setValue:(id)value {
    [raw_ release];
    raw_ = nil;        

    [value_ release];
    if([value isKindOfClass:[NSString class]])
        value_ = [[self sanitizedValueForValue:value] copy];
    else
        value_ = [value copy];
    self.isActive = (value != nil);
}

- (NSString *) encodeValue {
    NSMutableString *result = [NSMutableString stringWithCapacity:0];
	
	//value_ is NSNumber, NSString or nil.
	
	BOOL isBool = NO;
	if ([value_ isKindOfClass:[NSNumber class]]) {
		char objCType = *[value_ objCType];
		if (objCType == 'B' || objCType == 'c') {
			isBool = YES;
		}
	}
	
	if (isBool) {
        if (!self.isActive)
            [result appendString:@"#"];
        
        if ([value_ boolValue]) {
            [result appendFormat:@"%@\n", self.key];
        } else {
            [result appendFormat:@"no-%@\n", self.key];
        }
    } 
    else if (value_) {
        if (!self.isActive)
            [result appendString:@"#"];
        [result appendFormat:@"%@ %@\n", self.key, value_];        
    }
    else {
        [result appendFormat:@"#%@\n", self.key];
    }

    return result;
}

- (void) appendLine:(NSString *)line withReader:(GPGConfReader *)reader {
    if (!raw_) {
        @throw [NSException exceptionWithName:@"GPGInvalidOperationException" 
                                       reason:@"Cannot appendLine if setting has been changed" 
                                     userInfo:nil];
    }

    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    NSString *trimmed = [line stringByTrimmingCharactersInSet:whsp];
    NSString *fullKey;
    NSString *setting = [reader settingForLine:line outFullKey:&fullKey];
    BOOL isComment = [trimmed hasPrefix:@"#"];

    if (fullKey != nil)
        endComments_ = TRUE;

    if (isComment || [trimmed length] < 1) {
        if (!endComments_) {
            if (!firstComment_) 
                firstComment_ = [[NSMutableString stringWithCapacity:0] retain];
            
            [firstComment_ appendString:line];
            if (![line hasSuffix:@"\n"])
                [firstComment_ appendString:@"\n"];
        }
    }
    else {
        [self incorporate:setting forFullKey:fullKey];
    }

    [raw_ appendString:line];
    if (![line hasSuffix:@"\n"])
        [raw_ appendString:@"\n"];
}

- (void) incorporate:(NSString *)setting forFullKey:fullKey {
    if ([fullKey hasPrefix:@"no-"]) {
        [value_ release];
        value_ = [[NSNumber numberWithBool:FALSE] retain];
    }
    else if (setting != nil) {
        [value_ release];
        value_ = [setting copy];
    }
    else {
        [value_ release];
        value_ = [[NSNumber numberWithBool:TRUE] retain];
    }

    self->isActive_ = TRUE;
}

- (NSString *)sanitizedValueForValue:(NSString *)value {
    NSArray *invalidChars = [NSArray arrayWithObjects:@"\n", @"\r", nil];
    NSMutableString *validString = [value mutableCopy];
    for(NSString *invalidChar in invalidChars)
        [validString replaceOccurrencesOfString:invalidChar withString:@"" options:0 range:NSMakeRange(0, [validString length])];
    return (NSString *)[validString autorelease];
}

@end
