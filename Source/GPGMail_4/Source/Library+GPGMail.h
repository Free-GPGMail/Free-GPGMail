/* Library+GPGMail.h created by Lukas Pitschl (@lukele) on Wed 13-Jun-2013 */

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

@class MCMessage, MCMimePart;

@interface Library_GPGMail : NSObject

/**
 This hook is necessary to prevent the plist serialization error (ticket #606).
 In the case that the user is sending a OpenPGP signed or encrypted message
 the sender and to value passed to this method might be GPGFlaggedStrings,
 which can't be serialized into a plist.
 To fix this, they are converted to normal strings first.
 */
+ (id)MAPlistDataForMessage:(id)message subject:(id)subject sender:(id)sender to:(id)to dateSent:(id)dateSent remoteID:(id)remoteID originalMailbox:(id)originalMailbox flags:(long long)flags mergeWithDictionary:(id)mergeWithDictionary;

+ (BOOL)GMGetTopLevelMimePart:(__autoreleasing id *)topLevelMimePart headers:(__autoreleasing id *)headers body:(__autoreleasing id *)body forMessage:(MCMessage *)currentMessage messageData:(NSData *)messageData shouldProcessPGPData:(BOOL)shouldProcessPGPData;

+ (NSData *)GMRawDataForMessage:(MCMessage *)currentMessage topLevelPart:(MCMimePart *)topLevelPart fetchIfNotAvailable:(BOOL)fetchIfNotAvailable;

+ (NSData *)GMMessageDataForMessage:(MCMessage *)currentMessage isCompleteMessageAvailable:(BOOL *)isCompleteMessageAvailable;
@end
