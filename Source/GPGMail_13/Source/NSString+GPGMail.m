/* NSString+GPGMail.m created by dave on Mon 29-Oct-2001 */

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

#include <CommonCrypto/CommonDigest.h>
#define restrict
#import <RegexKit/RegexKit.h>
#import <Foundation/Foundation.h>
#import "NSString+GPGMail.h"
#import "GPGMailBundle.h"
#import "EAEmailAddressParser.h"

@implementation NSString (GPGMail)

- (NSString *)gpgNormalizedEmail {
	if([self respondsToSelector:@selector(uncommentedAddress)])
        return [[self lowercaseString] uncommentedAddress];
    
	// 10.7 and 10.8 have uncommentedAddress.
	// 10.9 uses EAEmailAddressParser to perform the same operation.
	Class AddressParser = NSClassFromString(@"EAEmailAddressParser");
	
    if(AddressParser)
        return [[AddressParser rawAddressFromFullAddress:self] lowercaseString];
    
    NSLog(@"[GPGMail] Attention: uncommentedAddress no longer exists.");
    return [self lowercaseString];
}

- (NSString *)stringByDeletingPGPExtension {
    NSArray *PGPExtensions = @[@"pgp", @"gpg", @"asc"];
    NSString *extension = [self pathExtension];
    if([PGPExtensions containsObject:extension])
        return [self stringByDeletingPathExtension];
    
    return [NSString stringWithString:self];
}

- (NSString *)stringByDeletingAttachmentsWithNames:(NSArray *)names {
    // Attachments in parsed messages have the following format.
    // <object name="name" data="cid:xxxx" type=application/x-apple-msg-attachment></object>
    // So best is to look for <object> tags which have a type of application/x-apple-msg-attachment and a .sig in the filename.
    // Let's hope normal attachments don't have that.
    NSString *attachmentRegex = @"(?sm)(?<all><object([^>]*)name=\"(?<name>[^\"]+)\"([^>]*)application/x-apple-msg-attachment([^>]*)></object>)";
    
    RKEnumerator *matchEnumerator = [self matchEnumeratorWithRegex:attachmentRegex];
    
    NSMutableString *withoutAttachments = [self mutableCopy];
    
    while([matchEnumerator nextRanges] != NULL) {
        __autoreleasing NSString *all = nil, __autoreleasing *name = nil;
        
        [matchEnumerator getCapturesWithReferences:@"${all}", &all, @"${name}", &name, nil];
        
        if(![names containsObject:name])
            continue;
        
        [withoutAttachments replaceOccurrencesOfString:all withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [withoutAttachments length])];
    }
    
    return withoutAttachments;
}

- (NSString *)SHA1 {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *stringBytes = [self dataUsingEncoding: NSUTF8StringEncoding];
    if (!CC_SHA1([stringBytes bytes], (CC_LONG)[stringBytes length], digest))
        return nil;
    
    NSMutableString *sha1 = [NSMutableString string];
    
    for(unsigned int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        NSLog(@"%02x", digest[i]);
        [sha1 appendFormat:@"%02x", digest[i]];
    }
    
    return (NSString *)sha1;
}

@end
