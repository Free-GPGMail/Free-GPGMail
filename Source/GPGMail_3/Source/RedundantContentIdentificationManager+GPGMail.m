/* RedundantContentIdentificationManager+GPGMail.m created by Lukas Pitschl (@lukele) on Sat 18-Mar-2017 */

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

#import "RedundantContentIdentificationManager+GPGMail.h"

extern NSString * const kLibraryMimeBodyReturnCompleteBodyDataKey;
extern NSString * const kLibraryMimeBodyReturnCompleteBodyDataForMessageKey;

@implementation RedundantContentIdentificationManager_GPGMail

- (id)MARedundantContentMarkupForMessage:(id)message inConversation:(id)conversation {
    // +[MFLibrary mimeBodyForMessage:] is responsible for fetching or re-constructing the entire
    // message body, but it is only allowed to do so, if the call to it is on the same thread
    // as this method call. Otherwise it's possible, that the message fetching starts on a different thread
    // and is not yet completed once this method is called, which could result in the user seeing a non-decrypted
    // version of the message.
    // If a different call to +[Library mimeBodyForMessage:] started the fetching process, every other
    // call receives the standard partial body.
    // This method must however always receive the complete body data.
    // Since method is only called if the message was actively selected by the user, it's also telling
    // GPGMail that it's ok to decrypt messages (which might trigger pinentry to ask for the passphrase).
    [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:kLibraryMimeBodyReturnCompleteBodyDataKey];
    [[[NSThread currentThread] threadDictionary] setObject:message forKey:kLibraryMimeBodyReturnCompleteBodyDataForMessageKey];
    id ret = [self MARedundantContentMarkupForMessage:message inConversation:conversation];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:kLibraryMimeBodyReturnCompleteBodyDataKey];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:kLibraryMimeBodyReturnCompleteBodyDataForMessageKey];
    return ret;
}

@end
