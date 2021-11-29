/* MessageCriterion+GPGMail.h created by Lukas Pitschl (@lukele) on Wed 10-Jun-2013 */

/*
 * Copyright (c) 2000-2013, GPGTools Team <team@gpgtools.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "MFMessageCriterion.h"

@class MCMessage;

/**
 It's necessary to hook into this class, since Mail.app only checks
 the message flags, to determine whether a message is signed or encrypted.
 In some occasions though, for PGP processed messages, the message flags are not
 yet set correctly.
 
 For that reason, _evaluateIsDigitallySignedCriterion and _evaluateIsEncryptedCriterion
 use GPGMail's own variables to determine the signed and encrypted status of a message.
 */

@interface MessageCriterion_GPGMail : NSObject

/**
 Return YES if either the message flags have the signed bit on
 or [message isSigned] returns YES.
 */
- (BOOL)MA_evaluateIsDigitallySignedCriterion:(MCMessage *)message;

/**
 Return YES if either the message flags have the encrypted bit on
 or [message isEncrypted] returns YES.
 */
- (BOOL)MA_evaluateIsEncryptedCriterion:(MCMessage *)message;

@end
