/* GMMessageProtectionStatus.h created by Lukas Pitschl (@lukele) on Monday 21-May-2018 */

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

#import <Foundation/Foundation.h>
#import "MCMimePart.h"

@interface GMMessageProtectionStatus : NSObject

- (instancetype)init;
- (BOOL)containsUnsafeContent;
- (BOOL)completeMessageIsSigned;
- (BOOL)completeMessageIsEncrypted;
- (BOOL)partsOfMessageAreSigned;
- (BOOL)partsOfMessageAreEncrypted;
- (BOOL)messageIsUnprotected;
- (BOOL)messageContainsOnlyProtectedAttachments;

@property (assign, readonly) BOOL containsPlainParts;
@property (retain) NSMutableArray<MCMimePart *> *plainParts;
@property (assign, readonly) BOOL containsEncryptedParts;
@property (retain) NSMutableArray<MCMimePart *> *encryptedParts;
@property (assign, readonly) BOOL containsSignedParts;
@property (retain) NSMutableArray<MCMimePart *> *signedParts;

@end

