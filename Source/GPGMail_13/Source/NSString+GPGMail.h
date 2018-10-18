/* NSString+GPGMail.h created by dave on Mon 29-Oct-2001 */

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

#import <Foundation/NSString.h>


@interface NSString (GPGMail)

/**
 Return the lowercase and uncommented version of an email address.
 
 If the email address is using the commented form, being 
 "Some Comment <address@me.com>", the commented part "Some Comment <>" is stripped
 and only the actual address (e.g.: address@me.com) returned.
 
 The comment part might be a name of the owner of the email address.
 */
- (NSString *)gpgNormalizedEmail;

/**
 Removes any known pgp extension if any is found.
 */
- (NSString *)stringByDeletingPGPExtension;

/**
 Removes <object> elements with filename matching the given filenames.
 */
- (NSString *)stringByDeletingAttachmentsWithNames:(NSArray *)names;

@end

/**
 The methods in this category are available at runtime, but might
 have been removed in newer releases.
 */

@interface NSString (NotImplemented)

- (NSString *)uncommentedAddress;

@end
