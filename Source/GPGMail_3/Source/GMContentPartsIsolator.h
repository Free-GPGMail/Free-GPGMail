/* GMContentPartsIsolator.h created by Lukas Pitschl (@lukele) on Monday 21-May-2018 */

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

@interface GMIsolatedContentPart : NSObject

- (instancetype)initWithContent:(NSString *)content mimePart:(MCMimePart *)mimePart;
- (instancetype)initWithContent:(NSString *)content mimePart:(MCMimePart *)mimePart isolationMarkup:(NSString *)isolationMarkup;

@property (copy, readonly) NSString *content;
@property (weak, readonly) MCMimePart *mimePart;
@property (copy, readonly) NSString *isolationMarkup;

@end

@interface GMContentPartsIsolator : NSObject {
    NSMutableArray <GMIsolatedContentPart *> *_contentParts;
    BOOL _isCreatingIsolatedContent;
}

- (instancetype)init;
- (NSString *)isolationMarkupForContent:(NSString *)content mimePart:(MCMimePart *)mimePart;
- (void)isolateAttachmentContent:(NSString *)attachmentContent mimePart:(MCMimePart *)mimePart;
- (NSString *)isolatedContentForDecodedContent:(id)decodedContent;
- (BOOL)needsProtectedContentIsolation;
- (BOOL)containsIsolatedMimePart:(MCMimePart *)mimePart;

@end

@protocol GMContentPartsIsolatorDelegate

- (NSString *)contentPartsIsolator:(GMContentPartsIsolator *)isolator alternativeContentForIsolatedPart:(GMIsolatedContentPart *)isolatedPart messageBody:(MCMessageBody *)messageBody;
- (BOOL)isContentThatNeedsIsolationAvailableForContentPartsIsolator:(GMContentPartsIsolator *)isolator;

@end
