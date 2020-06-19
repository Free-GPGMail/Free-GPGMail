/* MFLibraryMessage+GPGMail.m created by Lukas Pitschl (@lukele) on Sun 19-Mar-2017 */

/*
 * Copyright (c) 2017, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
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

#import "MFLibraryMessage+GPGMail.h"

#import "NSObject+LPDynamicIvars.h"

extern NSString * const kLibraryMessagePreventSnippingAttachmentDataKey;

@implementation MFLibraryMessage_GPGMail

- (BOOL)MAShouldSnipAttachmentData {
    // By returning NO here, Mail is prevented from creating a partial message and
    // instead creates an .emlx file with the whole message.
    // This is of utmost importance for PGP/MIME signed messages, since the body re-construction
    // is very error prone for signed messages.
    BOOL preventSnipping = [[self getIvar:kLibraryMessagePreventSnippingAttachmentDataKey] boolValue];
    if(preventSnipping) {
        return NO;
    }
    return [self MAShouldSnipAttachmentData];
}

@end
