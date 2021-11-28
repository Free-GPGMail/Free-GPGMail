/* GPGFlaggedString.m created by lukele on Thu 09-Aug-2011 */

/*
 * Copyright (c) 2000-2011, GPGTools Project Team <gpgtools-devel@lists.gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Project Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CCLog.h"
//#import "NSString-EmailAddressString.h"
#import "GPGFlaggedString.h"
#import "NSString+GPGMail.h"

@interface GPGFlaggedString ()
@property (copy) NSString *string;
- (id)initWithString:(NSString *)theString flags:(NSMutableDictionary *)theFlags;
@end


@implementation GPGFlaggedString
@synthesize string, flags;

- (id)initWithString:(NSString *)theString flag:(NSString *)flag value:(id)value {
	return [self initWithString:theString flags:[NSMutableDictionary dictionaryWithObject:value forKey:flag]];
}

- (id)initWithString:(NSString *)theString flags:(NSMutableDictionary *)theFlags {
    self = [super init];
    if (self) {
		self.string = theString;
		flags = [theFlags mutableCopy];
    }
    return self;
}

- (void)setValue:(id)value forFlag:(NSString *)flag {
	flags[flag] = value;
}

- (id)description {
    return [string description];
}

- (id)uncommentedAddress {
    // Don't autorelease it here, otherwise the object is overreleased,
    // after the message is sent.
    // Only create once. The NSString uncommentedAddress behaves the same way.
    if(!_uncommentedFlaggedValue) {
        _uncommentedFlaggedValue = [[GPGFlaggedString alloc] initWithString:[string gpgNormalizedEmail] flags:flags];
    }
    return _uncommentedFlaggedValue;
}

- (BOOL)isFlaggedValue {
    return YES;
}

- (id)valueForFlag:(NSString *)flag {
	return flags[flag];
}

- (BOOL)isKindOfClass:(Class)aClass {
    if(aClass == NSClassFromString(@"NSString"))
        return YES;
	if(aClass == NSClassFromString(@"GPGFlaggedString"))
		return YES;
    return NO;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return string;
}

@end

@implementation NSString (GPGFlaggedString)

- (GPGFlaggedString *)flaggedStringWithFlag:(NSString *)flag value:(id)value {
    // Don't autorelease it here, otherwise the object is overreleased,
    // after the message is sent.
	return [[GPGFlaggedString alloc] initWithString:self flag:flag value:value];
}

- (BOOL)isFlaggedValue {
    return NO;
}

- (id)valueForFlag:(NSString *)flag {
	return nil;
}

@end

