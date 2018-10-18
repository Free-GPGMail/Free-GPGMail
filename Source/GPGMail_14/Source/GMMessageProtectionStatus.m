/* GMMessageProtectionStatus.m created by Lukas Pitschl (@lukele) on Monday 21-May-2018 */

/*
 * Copyright (c) 2018, GPGTools <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY GPGTools ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GPGTools BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GMMessageProtectionStatus.h"
#import "MimePart+GPGMail.h"

@implementation GMMessageProtectionStatus

- (instancetype)init {
    if((self = [super init])) {
        _plainParts = [NSMutableArray new];
        _encryptedParts = [NSMutableArray new];
        _signedParts = [NSMutableArray new];
    }

    return self;
}

- (BOOL)containsPlainParts {
    return [self.plainParts count] > 0;
}

- (BOOL)containsSignedParts {
    return [self.signedParts count] > 0;
}

- (BOOL)containsEncryptedParts {
    return [self.encryptedParts count] > 0;
}

- (BOOL)containsMixedContent {
    return self.containsPlainParts > 0 && [self containsProtectedContent];
}

- (BOOL)containsProtectedContent {
    return self.containsEncryptedParts || self.containsSignedParts;
}

- (BOOL)containsUnsafeContent {
    if(!self.containsSignedParts && !self.containsEncryptedParts) {
        return YES;
    }
    // If a message is signed it naturally contains plain parts,
    // but if it covers the entire message, it doesn't contain
    // unsafe content.
    if(self.containsSignedParts && self.containsPlainParts) {
        if(self.containsSignedParts > 1) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)messageIsUnprotected {
    return !self.containsEncryptedParts && !self.containsSignedParts;
}

- (BOOL)partsOfMessageAreSigned {
    return [[self signedTextParts] count] && ![self completeMessageIsSigned];
}

- (BOOL)partsOfMessageAreEncrypted {
    return [[self encryptedTextParts] count] && ![self completeMessageIsEncrypted];
}

- (NSArray *)encryptedTextParts {
    return [self.encryptedParts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![(MimePart_GPGMail *)evaluatedObject PGPAttachment];
    }]];
}

- (NSArray *)signedTextParts {
    return [self.signedParts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![(MimePart_GPGMail *)evaluatedObject PGPAttachment];
    }]];
}

- (NSArray *)encryptedAttachmentParts {
    return [self.encryptedParts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [(MimePart_GPGMail *)evaluatedObject PGPAttachment];
    }]];
}

- (NSArray *)signedAttachmentParts {
    return [self.signedParts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [(MimePart_GPGMail *)evaluatedObject PGPAttachment];
    }]];
}

- (BOOL)messageContainsOnlyProtectedAttachments {
    // Is true, if all encrypted or signed mime parts are
    // attachments.
    BOOL onlyAttachments = YES;
    NSArray *encryptedSignedParts = [self.encryptedParts arrayByAddingObjectsFromArray:self.signedParts];
    for(MimePart_GPGMail *mimePart in encryptedSignedParts) {
        if(!mimePart.PGPAttachment) {
            onlyAttachments = NO;
        }
    }
    return onlyAttachments;
}

- (BOOL)completeMessageIsSigned {
    if(![self.signedParts count] || [self.signedParts count] > 1) {
        return NO;
    }
    
    MCMimePart *signedPart = [[self signedParts] objectAtIndex:0];
    MCMimePart *parentPart = signedPart.parentPart;
    if([signedPart isType:@"multipart" subtype:@"signed"]) {
        return parentPart == nil;
    }
    // Inline PGP messages are bascially never completely signed
    // unless there's only a single signed text/plain part.
    if(self.containsPlainParts) {
        return NO;
    }
    
    // Bug #987: PGP/MIME encrypted and signed message are recognized as partially encrypted
    //           - signature not shown
    //
    // A PGP/MIME messages which is encrypted and signed is considered
    // completely signed, if the encrypted part itself is also signed.
    if(self.containsEncryptedParts && [self.encryptedParts count] == 1 && self.encryptedParts[0] == self.signedParts[0]) {
        return YES;
    }
    
    // TODO: ponder about other cases.
    return parentPart == nil;
}

- (BOOL)completeMessageIsEncrypted {
    if(self.containsPlainParts) {
        return NO;
    }
    // Only text parts are considered here, since attachments have their own
    // status and don't have to be isolated.
    if(!self.containsEncryptedParts || [[self encryptedTextParts] count] > 1) {
        return NO;
    }
    
    MCMimePart *encryptedPart = [self.encryptedParts objectAtIndex:0];
    if([self.signedParts count] && self.signedParts[0] != encryptedPart || [self.signedParts count] > 1) {
        return NO;
    }
    
    if([(MimePart_GPGMail *)encryptedPart GMIsEncryptedPGPMIMETree]) {
        return YES;
    }
    // It is possible that the status of an encrypted part has changed
    // to not encrypted after the fact, for example in the case
    // of unencrypted plaintext spoofing.
    if([encryptedPart parentPart] == nil && [encryptedPart isType:@"text" subtype:@"plain"]) {
        return YES;
    }
    
    // Bug #989: Inline messages from Mailvelope display as partly encrypted
    //
    // In the case of only one part being displayed and the part being text/plain
    // it's ok to say the entire message is encrypted, if this is a multipart/alternative
    // message.
    MCMimePart *parentPart = [encryptedPart parentPart];
    if([encryptedPart isType:@"text" subtype:@"plain"] && [parentPart isType:@"multipart" subtype:@"alternative"] && ![parentPart parentPart]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)containsOnlyPlainTextParts {
    __block BOOL onlyPlainTextParts = YES;
    [self.plainParts enumerateObjectsUsingBlock:^(MCMimePart * _Nonnull obj, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        if(![obj isType:@"text" subtype:@"plain"]) {
            onlyPlainTextParts = NO;
            *stop = YES;
        }
    }];
    return onlyPlainTextParts;
}

@end
