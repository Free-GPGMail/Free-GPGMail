/* GPGFlaggedString.h created by lukele on Thu 09-Aug-2011 */

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

#import <Foundation/Foundation.h>

/**
 GPGFlaggedString allows the MimePart->newEncryptedPart and MimePart->newSignedPart
 methods to determine, whether the message should be PGP or S/MIME encrypted|signed.
 
 Before creating a message, some header values (from, bcc, to) are replaced with 
 GPGFlaggedStrings.
 In MimePart->newEncryptedPart and MimePart->newSignedPart, it's checked if the sender
 or recipients are GPGFlaggedStrings or simple strings.
 In the first case PGP encryption and signing methods are used, in the latter S/MIME methods.
 
 For classes that don't know about GPGFlaggedStrings it looks and presents itself
 as a standard NSString. Even for isKindOfClass:[NSString class] checks, it returns true.
 This is necessary, since Mail.app would otherwise discard the object when using it for header values
 due to the fact, that it only allows NSData, NSArray and NSString.
 
 Unfortunately subclassing NSString is everything but easy (see Apple Documentation for NSString),
 so the best option is to forward any non found selectors to the underlying original string.
 */
@interface GPGFlaggedString : NSObject {
	NSString *string;
	NSMutableDictionary *flags;
    GPGFlaggedString *_uncommentedFlaggedValue;
}
@property (readonly, copy) NSString *string;
@property (readonly) NSDictionary *flags;

/**
 Create a new GPGFlaggedString.
 GPGFlaggedStrings behave exactly like strings, since all
 methods are forwarded to the underlying string, but the ones
 that are needed to modify the string.
 */
- (id)initWithString:(NSString *)string flag:(NSString *)flag value:(id)value;

- (id)initWithString:(NSString *)theString flags:(NSMutableDictionary *)theFlags;

/**
 Sets the value for the given flag.
 */
- (void)setValue:(id)value forFlag:(NSString *)flag;

/**
 It's necessary to implement uncommentedAddress, since it's
 called before the addresses are passed into the signing and encryption
 methods and the flagged value would be replaced with the simple string.
 */
- (id)uncommentedAddress;

/**
 Returns always true, but since this method is also implemented
 on NSString using a category, it can be used to check if a string like
 variable is indeed a flagged value or a simple string.
 */
- (BOOL)isFlaggedValue;

/**
 Return the value saved for flag.
 */
- (id)valueForFlag:(NSString *)flag;

/**
 Returns true for [NSString class] so Mail.app doesn't discard it.
 */
- (BOOL)isKindOfClass:(Class)aClass;

/**
 Every non-implemented method is forwarded to the 
 underlying original string.
 */
- (id)forwardingTargetForSelector:(SEL)aSelector;


@end

/**
 Category adding some of GPGFlaggedString methods
 to NSString so they can be used interchangeably.
 */
@interface NSString (GPGFlaggedString)

/**
 Creates a new GPGFlaggedString with the given flag and value.
 */
- (GPGFlaggedString *)flaggedStringWithFlag:(NSString *)flag value:(id)value;

/**
 Returns always false, since a simple string is never a flagged value.
 */
- (BOOL)isFlaggedValue;

/**
 Return always nil, but is necessary so NSStrings and GPGFlaggedStrings
 can be used interchangeably.
 */
- (id)valueForFlag:(NSString *)flag;

@end
