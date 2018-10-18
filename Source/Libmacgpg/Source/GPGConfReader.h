/*
 GPGConfReader.h
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
#import "GPGOptions.h"

@class GPGStdSetting;

@interface GPGConfReader : NSObject {
    GPGOptionsDomain domain_;
}

+ (id) readerForDomain:(GPGOptionsDomain)domain;
+ (void) initialize;
- (id) initForDomain:(GPGOptionsDomain)domain;

// Get the condensed setting key name from the specified line, or nil if the 
// line is a straight-up comment or blank line.
// "Condensed" means to remove name modifiers like "no-".
- (NSString *) condensedKeyForLine:(NSString *)line;

// Split the specified line into full key and expression and return/assign.
// E.g, "keyserver-options   server1=parameters" will result in
// *key == "keyserver-options" and return value "server1=parameters"
- (NSString *) settingForLine:(NSString *)line outFullKey:(NSString **)key;

// Get a new GPGStdSetting for the specified line, or nil if the line is not a valid option 
// (e.g., if it is an empty line or a straight-up comment). 
// Note: line will not be appended yet to the newly-built instance in order to allow
// for handling preceding comments 
- (id) buildForLine:(NSString *)line;

// Split an NSString into the specified max number of components.
// Unlike NSString componentsSeparatedByString, this split method will treat adjacent
// split characters as one separator.
+ (NSArray *) splitString:(NSString *)string bySet:(NSCharacterSet *)separator maxCount:(NSUInteger)maximum;
@end
