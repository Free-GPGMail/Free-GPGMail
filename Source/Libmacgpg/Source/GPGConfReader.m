/*
 GPGConfReader.m
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

#import "GPGConfReader.h"
#import "GPGStdSetting.h"
#import "GPGLinesSetting.h"
#import "GPGDictSetting.h"
#import "GPGArraySetting.h"
#import "GPGOptions.h"

@implementation GPGConfReader

// maps some setting names to GPGStdSetting classes;
// other setting names will be heuristically determined (e.g., "no-" options
// and "-options" options
static NSMutableDictionary *settingTypeMap_;
static NSMutableCharacterSet *commentChars_;

+ (id) readerForDomain:(GPGOptionsDomain)domain {
    return [[[self alloc] initForDomain:domain] autorelease];
}

+ (void)initialize {
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;

        settingTypeMap_ = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
        [settingTypeMap_ setObject:[GPGArraySetting class] forKey:@"auto-key-locate"];
        [settingTypeMap_ setObject:[GPGLinesSetting class] forKey:@"comment"];
        [settingTypeMap_ setObject:[GPGLinesSetting class] forKey:@"secret-keyring"];
        [settingTypeMap_ setObject:[GPGLinesSetting class] forKey:@"keyring"];
        [settingTypeMap_ setObject:[GPGDictSetting class] forKey:@"group"];
        // "no-auto-key-locate" is not the inverse of "auto-key-locate parameters"
        [settingTypeMap_ setObject:[GPGStdSetting class] forKey:@"no-auto-key-locate"];
        // "no-options" is boolean
        [settingTypeMap_ setObject:[GPGStdSetting class] forKey:@"no-options"];
        
        commentChars_ = [[NSMutableCharacterSet characterSetWithCharactersInString:@"#"] retain];
        [commentChars_ formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

- (id) init {
    return [self initForDomain:GPGDomain_gpgConf];
}

- (id) initForDomain:(GPGOptionsDomain)domain {
    if (self = [super init]) {
        domain_ = domain;
    }
    return self; 
}

- (NSString *) condensedKeyForLine:(NSString *)line {
    NSString *key;
    [self settingForLine:line outFullKey:&key];
    if (!key)
        return nil;

    // Remove "no-", unless it is a mapped key name
    if ([key hasPrefix:@"no-"] && [settingTypeMap_ objectForKey:key] == nil) {
        key = [key substringFromIndex:3ul];
    }

    return key;
}

- (NSString *) settingForLine:(NSString *)line outFullKey:(NSString **)key {
    NSString *trline = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trline length] < 1) {
        *key = nil;
        return nil;
    }
    
    // split in twain by whitespace
    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    NSArray *trsplit = [GPGConfReader splitString:trline bySet:whsp maxCount:2ul];
    NSString *elem1 = [trsplit objectAtIndex:0];
    
    // for a comment, try to recognize commented options "#<option name>" or else return nil
    if ([elem1 hasPrefix:@"#"]) {
        elem1 = [elem1 substringFromIndex:1];
		if (![GPGOptions isKnownKey:elem1 inDomain:domain_]) {
            *key = nil;
            return nil;
        }
    }

    *key = elem1;
    return ([trsplit count] > 1) ? [trsplit objectAtIndex:1] : nil;     
}

- (id) buildForLine:(NSString *)line {
    NSString *key = [self condensedKeyForLine:line];
    if (!key)
        return nil;

    Class mappedClass;
    if ((mappedClass = [settingTypeMap_ objectForKey:key]) != nil) {
        // yay
    }
    else if ([key hasSuffix:@"-options"]) {
        mappedClass = [GPGArraySetting class];
    }
    else {
        mappedClass = [GPGStdSetting class];
    }

    id setting = [[[mappedClass alloc] initForKey:key] autorelease];
    return setting;
}

+ (NSArray *) splitString:(NSString *)string bySet:(NSCharacterSet *)separator maxCount:(NSUInteger)maximum {
    if (!string)
        return nil;

    NSCharacterSet *inversion = [separator invertedSet];
    NSUInteger maxPos = [string length];
    NSRange searchRange;
    searchRange.location = 0;
    searchRange.length = maxPos;

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:2ul];
    
    while (searchRange.location < maxPos && [result count] < maximum) {
        NSRange found = [string rangeOfCharacterFromSet:separator options:0 range:searchRange];
        if (found.location == NSIntegerMax || [result count] + 1 >= maximum) {
            // take the rest of the string
            [result addObject:[string substringWithRange:searchRange]];
            searchRange.location += searchRange.length;
            searchRange.length = 0;
        }
        else {
            // take the substring
            NSRange subRange = searchRange;
            subRange.length = found.location - searchRange.location;
            [result addObject:[string substringWithRange:subRange]];
            
            // advance past separator
            searchRange.location += subRange.length;
            searchRange.length -= subRange.length;
            found = [string rangeOfCharacterFromSet:inversion options:0 range:searchRange];

            if (found.location == NSIntegerMax) {
                [result addObject:@""];
                break;
            }
            subRange = searchRange;
            subRange.length = found.location - searchRange.location;
            searchRange.location += subRange.length;
            searchRange.length -= subRange.length;
        }
    }

    return result;
}

@end
