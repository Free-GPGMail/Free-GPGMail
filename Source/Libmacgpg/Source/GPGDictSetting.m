/*
 GPGDictSetting.m
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

#import "GPGDictSetting.h"
#import "GPGConfReader.h"

static NSMutableCharacterSet *whspeq_;
static NSMutableCharacterSet *whspcomma_;

@interface GPGDictSetting (hidden)
+ (NSString *) joinSettings:(id)value;
@end 

@implementation GPGDictSetting

+ (void)initialize {
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;

        whspeq_ = [[NSMutableCharacterSet characterSetWithCharactersInString:@"="] retain];
        [whspeq_ formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];

        whspcomma_ = [[NSMutableCharacterSet characterSetWithCharactersInString:@","] retain];
        [whspcomma_ formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

- (id) initForKey:(NSString *)key {
    if ((self = [super initForKey:key])) {
        value_ = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
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
    else if ([value isKindOfClass:[NSDictionary class]]) {
        [raw_ release];
        raw_ = nil;
        NSMutableDictionary *sanitizedValue = [NSMutableDictionary dictionary];
        for(id key in value) {
            id v = [value objectForKey:key];
            if([v isKindOfClass:[NSString class]])
                v = [self sanitizedValueForValue:v];
            [sanitizedValue setObject:v forKey:key];
        }
        [value_ removeAllObjects];
        [value_ addEntriesFromDictionary:sanitizedValue];
        self.isActive = TRUE;
    }
}

- (NSString *) encodeValue {
    NSMutableString *result = [NSMutableString stringWithCapacity:0];
    if (value_ && [value_ count] > 0) {
        for (id key in value_) {
            if (!self.isActive) 
                [result appendString:@"#"];
            NSString *jvalue = [GPGDictSetting joinSettings:[value_ objectForKey:key]];
            [result appendFormat:@"%@ %@=%@\n", self.key, key, jvalue];
        }
    }
    else {
        [result appendFormat:@"#%@\n", self.key];
    }
    return result;
}

+ (NSString *) joinSettings:(id)value {
    if ([value isKindOfClass:[NSArray class]]) {
        return [value componentsJoinedByString:@" "]; 
    }
    else {
        return [value description];
    }
}

- (void) incorporate:(NSString *)setting forFullKey:fullKey {
    if (setting) {
        NSArray *kvparts = [GPGConfReader splitString:setting bySet:whspeq_ maxCount:2ul];
        NSArray *vsplit = [NSArray array];
        if ([kvparts count] > 1) {
            vsplit = [GPGConfReader splitString:[kvparts objectAtIndex:1] 
                                          bySet:whspcomma_
                                       maxCount:NSIntegerMax];
        }
        if ([kvparts count] > 0) {
            [value_ setObject:vsplit forKey:[kvparts objectAtIndex:0]];
            isActive_ = TRUE;
        }
    }
}

@end
