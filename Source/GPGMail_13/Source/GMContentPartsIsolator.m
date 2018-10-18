/* GMContentPartsIsolator.m created by Lukas Pitschl (@lukele) on Monday 21-May-2018 */

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

#import "GMContentPartsIsolator.h"
#import "MCMessageBody.h"
#import "MimePart+GPGMail.h"

@class GMContentPartsIsolator;
@class GMIsolatedContentPart;


@implementation GMIsolatedContentPart

- (instancetype)initWithContent:(NSString *)content mimePart:(MCMimePart *)mimePart isolationMarkup:(NSString *)isolationMarkup {
    if((self = [super init])) {
        _content = [content copy];
        _mimePart = mimePart;
        _isolationMarkup = [isolationMarkup length] ? [isolationMarkup copy] : [[self class] newIsolationMarkupForContent:content];
    }

    return self;
}

- (instancetype)initWithContent:(NSString *)content mimePart:(MCMimePart *)mimePart {
    return [self initWithContent:content mimePart:mimePart isolationMarkup:nil];
}

+ (NSString *)generateIsolationID {
    NSUUID *uuid = [NSUUID new];
    return [NSString stringWithFormat:@"isolated-part-%@", [uuid UUIDString]];
}

+ (NSString *)newIsolationMarkup {
    NSString *isolationID = [[self class] generateIsolationID];
    return [NSString stringWithFormat:@"<%@ />", isolationID];
}

+ (NSString *)newIsolationMarkupForContent:(NSString *)content {
    NSString *isolationID = [[self class] generateIsolationID];
    return [NSString stringWithFormat:@"<%@>%@</%@>", isolationID, content, isolationID];
}

@end

@implementation GMContentPartsIsolator

- (instancetype)init {
    if((self = [super init])) {
        _contentParts = [NSMutableArray new];
        _isCreatingIsolatedContent = NO;
    }
    return self;
}

- (NSString *)isolationMarkupForContent:(NSString *)content mimePart:(MCMimePart *)mimePart {
    GMIsolatedContentPart *isolatedContentPart = [[GMIsolatedContentPart alloc] initWithContent:content mimePart:mimePart];
    if(!_isCreatingIsolatedContent) {
        [_contentParts addObject:isolatedContentPart];
    }

    return isolatedContentPart.isolationMarkup;
}

- (void)isolateAttachmentContent:(NSString *)attachmentContent mimePart:(MCMimePart *)mimePart {
    // Attachment markup is unique by default, thus no custom markup is necessary for the attachment.
    GMIsolatedContentPart *isolatedContentPart = [[GMIsolatedContentPart alloc] initWithContent:attachmentContent mimePart:mimePart isolationMarkup:attachmentContent];
    if(!_isCreatingIsolatedContent) {
        [_contentParts addObject:isolatedContentPart];
    }
}

- (BOOL)containsIsolatedMimePart:(MCMimePart *)mimePart {
    for(GMIsolatedContentPart *part in _contentParts) {
        if(part.mimePart == mimePart) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)isolatedContentForDecodedContent:(id)decodedContent {
    _isCreatingIsolatedContent = YES;
    MCMessageBody *messageBody = [decodedContent isKindOfClass:[MCMessageBody class]] ? decodedContent : nil;
    NSString *content = [decodedContent isKindOfClass:[MCMessageBody class]] ? [decodedContent html] : decodedContent;
    if(![_contentParts count] || ![content length]) {
        return content;
    }
    MimePart_GPGMail *firstIsolatedPartMimePart = (MimePart_GPGMail *)[[_contentParts objectAtIndex:0] mimePart];
    BOOL isolateContent = YES;
    if([firstIsolatedPartMimePart respondsToSelector:@selector(isContentThatNeedsIsolationAvailableForContentPartsIsolator:)]) {
        isolateContent = [firstIsolatedPartMimePart isContentThatNeedsIsolationAvailableForContentPartsIsolator:self];
    }

    NSMutableString *isolatedContent = [NSMutableString new];
    NSString *safeContent = nil;
    NSString *unsafeContent = nil;
    NSRange unsafeContentRange = NSMakeRange(0, 0);
    
    // Bug #XXXX: Isolated parts are considered unsafe under special circumstances
    //
    // The old method worked under the assumption, that the order isolated parts
    // are stored, matches the order in which they appear in the content.
    // While that's probably true in most cases, there are some messages (see #991)
    // where that is not the case. As a result, an attachment for example might
    // be considered an unsafe part even though it is not.
    //
    // The new method works regardless of the order in which the isolated parts
    // were added to the isolator.
    [_contentParts sortUsingComparator:^NSComparisonResult(GMIsolatedContentPart * _Nonnull obj1, GMIsolatedContentPart * _Nonnull obj2) {
        NSRange range1 = [content rangeOfString:obj1.isolationMarkup];
        NSRange range2 = [content rangeOfString:obj2.isolationMarkup];
        
        if(range1.location == range2.location) {
            return NSOrderedSame;
        }
        if(range1.location > range2.location) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }];
    
    for(GMIsolatedContentPart *isolatedPart in _contentParts) {
        NSRange isolatedPartRange = [content rangeOfString:isolatedPart.isolationMarkup];
        if(isolatedPartRange.location == NSNotFound) {
            continue;
        }
        // It is possible that attachments are contained within already
        // isolated content parts, in which case, if the current location
        // is already at a later point than where the next isolated range
        // is found, it's no longer necessary to process any other
        // isolated content, since a previous isolated part already covered
        // that part.
        if(isolatedPartRange.location < unsafeContentRange.location) {
            break;
        }
        //NSAssert(isolatedPartRange.location != NSNotFound, @"Isolation part gone missing. What happened?");

        unsafeContentRange.length = isolatedPartRange.location - unsafeContentRange.location;
        unsafeContent = [content substringWithRange:unsafeContentRange];
        if([unsafeContent length]) {
            if(isolateContent) {
                safeContent = [self isolatedContentMarkupForUnsafeContent:unsafeContent];
            }
            else {
                safeContent = unsafeContent;
            }
            [isolatedContent appendString:safeContent];
        }
        MimePart_GPGMail *mimePart = (MimePart_GPGMail *)isolatedPart.mimePart;
        NSString *alternativeContent = nil;
        if([mimePart respondsToSelector:@selector(contentPartsIsolator:alternativeContentForIsolatedPart:messageBody:)]) {
            alternativeContent = [mimePart contentPartsIsolator:self alternativeContentForIsolatedPart:isolatedPart messageBody:messageBody];
        }
        if(!alternativeContent) {
            alternativeContent = isolatedPart.content;
        }
        [isolatedContent appendString:alternativeContent];
        unsafeContentRange.location = isolatedPartRange.location + isolatedPartRange.length;
    }
    if([content length] - unsafeContentRange.location > 0) {
        unsafeContentRange.length = [content length] - unsafeContentRange.location;
        unsafeContent = [content substringFromIndex:unsafeContentRange.location];
        if([unsafeContent length]) {
            if(isolateContent) {
                safeContent = [self isolatedContentMarkupForUnsafeContent:unsafeContent];
            }
            else {
                safeContent = unsafeContent;
            }
        }
        [isolatedContent appendString:safeContent];
    }
    _isCreatingIsolatedContent = NO;
    return isolatedContent;
}

- (NSString *)isolatedContentMarkupForUnsafeContent:(NSString *)content {
    // Might have to be a different encoding, based on data, but we'll find out.
    content = [NSString stringWithFormat:@"<iframe-content>%@</iframe-content>", content];
    NSString *encodedContent = [[content dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSString *isolatedContent = [NSString stringWithFormat:@"<iframe class=\"untrusted-content-test\" scrolling=\"auto\" width=\"200\" height=\"20\" style=\"border:none;display:block;overflow:auto;\" data-src=\"data:text/html;charset=UTF-8;base64,%@\" sandbox=\"allow-scripts\"></iframe>", encodedContent];

    return isolatedContent;
}

@end
