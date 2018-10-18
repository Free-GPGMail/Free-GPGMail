/*
 GPGStdSetting.h
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

#import <Foundation/Foundation.h>

@class GPGConfReader;

// Represents an options line from .conf for a boolean or simple string option.
// E.g., "no-auto-key-locate"
// E.g., "compress-level 5"
@interface GPGStdSetting : NSObject {
    BOOL isActive_;
    NSMutableString * firstComment_;
    BOOL endComments_;
    NSMutableString * raw_;  // as read from .conf
    id value_;
    NSString *key_;
}

// Get or set the option key 
@property (nonatomic, copy, readwrite) NSString *key;

// Get or set a value indicating whether the option is active;
// (If not active, the option may still exist in configuration, but in a deactivated
// state—e.g., prefixed by a '#')
@property (nonatomic, setter=setIsActive:) BOOL isActive;

// Designated initializer. isActive will be FALSE
- (id) initForKey:(NSString *)key;

// Get a new block of text encoding the setting. If no change
// has been made via setComment or setValue, then this should reflect
// the raw configuration as read from .conf; otherwise, it will return
// a block of configuration text built from comment and encodeValue.
//
// The value includes line breaks and a trailing line break.
- (NSString *) description;

// Set a comment for the instance, overwriting any comments read while parsing
- (void) setComment:(NSString *)comment;

// Get the value (possibly nil) for the setting
- (id) value;

// Set a value for the instance, overwriting any value read while parsing.
// Subclasses should implement for their specific value type.
// isActive will be set to TRUE.
- (void) setValue:(id)value;

// Get a new block of text encoding the value.
//
// E.g., "#no-encrypt-to"
// E.g., "keyserver hkp://blahblah.com
//
// Subclasses should implement for their specific value type
- (NSString *) encodeValue;

// Used when parsing .conf to add a configuration line to the setting
- (void) appendLine:(NSString *)line withReader:(GPGConfReader *)reader;

// Used when parsing .conf to incorporate the split elements of a configuration line.
// Called by appendLine:withReader:; shouldn't be used directly.
// Subclasses should implement for their specific value type
- (void) incorporate:(NSString *)setting forFullKey:(NSString *)fullKey;

// Values may not contain \n chars, so those are replaced.
// Other invalid chars might also be removed at a later point.
- (NSString *)sanitizedValueForValue:(NSString *)value;

@end
