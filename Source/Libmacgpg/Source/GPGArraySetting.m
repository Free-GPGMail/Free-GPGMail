/*
 GPGArraySetting.m
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

#import "GPGArraySetting.h"
#import "GPGConfReader.h"

static NSMutableCharacterSet *whspcomma_;

@implementation GPGArraySetting

+ (void)initialize {
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
        whspcomma_ = [[NSMutableCharacterSet characterSetWithCharactersInString:@","] retain];
        [whspcomma_ formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

- (id) initForKey:(NSString *)key {
    if ((self = [super initForKey:key])) {
        value_ = [[NSMutableArray arrayWithCapacity:0] retain];
    }
    return self;
}

- (void) setValue:(id)value {
    if (!value) {
        [raw_ release];
        raw_ = nil;
        [value_ removeAllObjects];
        self.isActive = FALSE;
    }
    else if ([value isKindOfClass:[NSArray class]]) {
        [raw_ release];
        raw_ = nil;
        NSMutableArray *sanitizedValue = [NSMutableArray array];
        for(id v in value) {
            if([v isKindOfClass:[NSString class]])
                v = [self sanitizedValueForValue:v];
            [sanitizedValue addObject:v];
        }
        [value_ removeAllObjects];
        [value_ addObjectsFromArray:sanitizedValue];
        self.isActive = TRUE;
    }
}

- (NSString *) encodeValue {
    NSMutableString *result = [NSMutableString stringWithCapacity:0];
    if (value_ && [value_ count] > 0) {
        if (!self.isActive) 
            [result appendString:@"#"];
        [result appendFormat:@"%@ %@\n", self.key, [value_ componentsJoinedByString:@" "]];
    }
    else {
        [result appendFormat:@"#%@\n", self.key];
    }
    return result;
}

- (void) incorporate:(NSString *)setting forFullKey:fullKey {
    if (setting) {
        NSArray *vparts = [GPGConfReader splitString:setting bySet:whspcomma_ maxCount:NSIntegerMax];
        [value_ addObjectsFromArray:vparts];
        if ([vparts count] > 0) 
            isActive_ = TRUE;
    }
}

@end
