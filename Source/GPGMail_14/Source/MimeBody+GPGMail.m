/* MimeBody+GPGMail.m created by stephane on Thu 06-Jul-2000 */

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

#import <Foundation/Foundation.h>
#import <Libmacgpg/Libmacgpg.h>
#import "CCLog.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSData+GPGMail.h"
//#import "Message.h"
//#import "MessageStore.h"
//#import "MimeBody.h"
#import "Message+GPGMail.h"
#import "MimeBody+GPGMail.h"
#import "MimePart+GPGMail.h"

#import "GMMessageSecurityFeatures.h"

#define MAIL_SELF ((MCMimeBody *)self)

extern NSString * const kMessageSecurityFeaturesKey;
const NSString *kMimeBodyMessageKey = @"MimeBodyMessageKey";

@interface MimeBody_GPGMail (NotImplemented)

- (id)messageDataIncludingFromSpace:(BOOL)arg1 newDocumentID:(id)arg2 fetchIfNotAvailable:(BOOL)arg3;

@end

@implementation MimeBody_GPGMail

// TODO: Gone in High Sierra. Remove? Find replacement?
//- (BOOL)MAIsSignedByMe {
//    // This method tries to check the
//    // signatures internally, if some are set.
//    // This results in a crash, since Mail.app
//    // can't handle GPGSignature signatures.
//    GMMessageSecurityFeatures *securityProperties = [self securityFeatures];
//    NSArray *messageSigners = [securityProperties PGPSignatures];
//    if([messageSigners count] && [messageSigners[0] isKindOfClass:[GPGSignature class]]) {
//        return YES;
//    }
//    // Otherwise call the original method.
//    BOOL ret = [self MAIsSignedByMe];
//    return ret;
//}

/**
 It's not exactly clear when this method is used, but internally it
 checks the message for mime parts signaling S/MIME encrypted or signed
 messages.
 
 It can't be bad to fix it for PGP messages, anyway.
 Instead of the mime parts, which due to inline PGP are not reliable enough,
 GPGMail checks for PGP armor, which is included in inline and PGP/MIME messages.
 
 Apparently 
 
 */
// TODO: Gone in High Sierra. Remove? Find replacement?
//- (BOOL)MA_isPossiblySignedOrEncrypted {
//    // Check if message should be processed (-[Message shouldBePGPProcessed] - Snippet generation check)
//    // otherwise out of here!
//    if(![(MimePart_GPGMail *)[MAIL_SELF topLevelPart] shouldBePGPProcessed])
//        return [self MA_isPossiblySignedOrEncrypted];
//}

- (BOOL)mightContainPGPMIMESignedData {
    __block BOOL foundMIMESignedTopLevel = NO;
    __block BOOL foundMIMESignature = NO;
    [(MimePart_GPGMail *)[MAIL_SELF topLevelPart] enumerateSubpartsWithBlock:^(MCMimePart *mimePart) {
        if([mimePart isType:@"multipart" subtype:@"signed"]) {
            foundMIMESignedTopLevel = YES;
        }
        if([mimePart isType:@"application" subtype:@"pgp-signature"]) {
            foundMIMESignature = YES;
        }
    }];

    return foundMIMESignedTopLevel && foundMIMESignature;
}

- (BOOL)mightContainPGPData {
    __block BOOL mightContainPGPData = NO;
    __block BOOL mightContainSMIMEData = NO;

    NSArray *pgpExtensions = @[@"pgp", @"gpg", @"asc", @"sig"];
    NSArray *smimeExtensions = @[@"p7m", @"p7s", @"p7c", @"p7z"];
    [(MimePart_GPGMail *)[MAIL_SELF topLevelPart] enumerateSubpartsWithBlock:^(MCMimePart *mimePart) {
        // Check for S/MIME hints.
        if(([mimePart isType:@"multipart" subtype:@"signed"] && [[[mimePart bodyParameterForKey:@"protocol"] lowercaseString] isEqualToString:@"application/pkcs7-signature"]) ||
           [smimeExtensions containsObject:[[[mimePart bodyParameterForKey:@"filename"] lowercaseString] pathExtension]] ||
           [smimeExtensions containsObject:[[[mimePart bodyParameterForKey:@"name"] lowercaseString] pathExtension]] ||
           [mimePart isType:@"application" subtype:@"pkcs7-mime"]) {
            mightContainSMIMEData = YES;
            return;
        }
        BOOL mimeSigned = [mimePart isType:@"multipart" subtype:@"signed"] && ![[[mimePart bodyParameterForKey:@"protocol"] lowercaseString] isEqualToString:@"application/pkcs7-signature"];
        if([mimePart isType:@"multipart" subtype:@"encrypted"] ||
           mimeSigned ||
           [mimePart isType:@"application" subtype:@"pgp-encrypted"] ||
           [mimePart isType:@"application" subtype:@"pgp-signature"]) {
            mightContainPGPData = YES;
            return;
        }

        NSString *nameParameter = [[mimePart bodyParameterForKey:@"name"] lowercaseString];
        NSString *filenameParameter = [[mimePart bodyParameterForKey:@"filename"] lowercaseString];

        NSString *nameExt = [nameParameter pathExtension];
        NSString *filenameExt = [filenameParameter pathExtension];

        if([pgpExtensions containsObject:nameExt] || [pgpExtensions containsObject:filenameExt]) {
            mightContainPGPData = YES;
            return;
        }

        // Last but not least, check for winmail.dat files, which could contain
        // signed or encrypted data, where the mime structure was altered by
        // MS Exchange.
        if([mimePart isType:@"application" subtype:@"ms-tnef"] ||
           [nameParameter isEqualToString:@"winmail.dat"] ||
           [nameParameter isEqualToString:@"win.dat"] ||
           [filenameParameter isEqualToString:@"winmail.dat"] ||
           [filenameParameter isEqualToString:@"win.dat"]) {
            mightContainPGPData = YES;
            return;
        }

        // And another special case seems to be fixed by rebuilding the message.
        // If message/rfc822 mime part is included in the received message,
        // Mail seems to fuck up the data source necessary to decode that message.
        // As a result, only parts of the message are displayed.
        // If however GPGMail rebuilds the message internally from cached data,
        // the data source is properly setup and it's possible to decode the message.
        // While the message might not contain PGP data, YES is still returned
        // from this method, in order to instruct GPGMail to rebuild the message.
        if([mimePart isType:@"message" subtype:@"rfc822"]) {
            mightContainPGPData = YES;
            return;
        }

    }];

    return mightContainPGPData && !mightContainSMIMEData;
}

- (MCMessage *)GMMessage {
    return [self getIvar:kMimeBodyMessageKey];
}

- (NSData *)MAParsedMessage {
    DebugLog(@"Has message? %@", [self getIvar:kMimeBodyMessageKey]);
    id parsedMessage = [self MAParsedMessage];
    [parsedMessage setIvar:kMimeBodyMessageKey value:[self getIvar:kMimeBodyMessageKey]];
    
    [self collectSecurityFeatures];
    [parsedMessage setIvar:kMessageSecurityFeaturesKey value:[self securityFeatures]];
    
    return parsedMessage;
}

- (void)collectSecurityFeatures {
    // Collect the security parse result.
    GMMessageSecurityFeatures *securityFeatures = [GMMessageSecurityFeatures securityFeaturesFromMimeBody:self];
    // TODO: What to do if the security features are already set?
    [self setSecurityFeatures:securityFeatures];
    [[self getIvar:kMimeBodyMessageKey] setIvar:kMessageSecurityFeaturesKey value:securityFeatures];
}

- (void)setSecurityFeatures:(GMMessageSecurityFeatures *)securityFeatures {
    [self setIvar:kMessageSecurityFeaturesKey value:securityFeatures];
}

- (GMMessageSecurityFeatures *)securityFeatures {
    return [self getIvar:kMessageSecurityFeaturesKey];
}

@end

#undef MAIL_SELF

