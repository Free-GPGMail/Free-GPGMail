/*
* Copyright (c) 2021, GPGTools GmbH <team@gpgtools.org>
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

#import "MCMessageHeaders+GPGMail.h"

@implementation MCMessageHeaders_GPGMail

- (NSArray *)MAHeadersForKey:(NSString *)key {
    NSArray *headers = [self MAHeadersForKey:key];
    if([key isEqualToString:@"subject"]) {
        // Bug #1001: Message might appear as signed even though it isn't by abusing the subject
        //
        // By using UTF-8 characters and new lines in a subject, it is possible for an attacker
        // to trick an unsuspecting user into believing that a message is signed, even though
        // it is not.
        //
        // Now macOS Mail is even particularly stupid and allows more than one Subject header
        // and concatenates them splitted by new lines...
        //
        // To fix this, GPGMail only allows a single line subject.
        NSString *subject = [headers count] ? headers[0] : nil;
        if(![subject length]) {
            return headers;
        }
        NSRange range = NSMakeRange(0, [subject length]);
        __block NSString *firstSubjectLine = nil;
        [subject enumerateSubstringsInRange:range
                                   options:NSStringEnumerationByParagraphs
                                usingBlock:^(NSString * _Nullable paragraph, NSRange paragraphRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
                                    firstSubjectLine = paragraph;
                                    *stop = YES;
                                }];
        if(![firstSubjectLine length]) {
            return headers;
        }
        return @[firstSubjectLine];
    }
    return headers;
}

@end
