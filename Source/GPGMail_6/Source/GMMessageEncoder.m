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

#import <Libmacgpg/Libmacgpg.h>

#import "MCMimePart.h"
#import "MCMessageGenerator.h"
#import "MCMutableMessageHeaders.h"
#import "MCOutgoingMessage.h"

#import "NSData+GPGMail.h"

#import "GPGMailBundle.h"

#import "GMMessageEncoder.h"

@implementation GMMessageEncoder

- (instancetype)initWithData:(NSData *)messageData writer:(MCMessageGenerator *)writer {
    if((self = [super init])) {
        _messageData = [messageData copy];
        self.writer = writer;
    }

    return self;
}

+ (GPGController *)standardGPGController {
    GPGController *gpg = [[GPGController alloc] init];
    gpg.useArmor = YES;
    gpg.useTextMode = YES;
    gpg.trustAllKeys = YES;

    return gpg;
}

+ (NSError *)localizedErrorForSigningFailureWithSender:(NSString *)sender gpgErrorCode:(GPGErrorCode)errorCode error:(NSException *)error {
    NSString *title = nil;
    NSString *description = nil;
    NSString *errorText = nil;
    if([error isKindOfClass:[GPGException class]])
        errorText = ((GPGException *)error).gpgTask.errText;
    else if([error isKindOfClass:[NSException class]])
        errorText = ((NSException *)error).reason;

    BOOL appendContactGPGToolsInfo = YES;

    switch (errorCode) {
        case GPGErrorNoPINEntry: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_NO_PINENTRY_TITLE");

            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_NO_PINENTRY_DESCRIPTION");
            break;
        }
        case GPGErrorNoAgent: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_NO_AGENT_TITLE");

            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_NO_AGENT_DESCRIPTION");

            break;
        }
        case GPGErrorAgentError: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_AGENT_ERROR_TITLE");

            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_AGENT_ERROR_DESCRIPTION");

            break;
        }
        case GPGErrorBadPassphrase: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_WRONG_PASSPHRASE_TITLE");
            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_WRONG_PASSPHRASE_DESCRIPTION");

            appendContactGPGToolsInfo = NO;

            break;
        }
        case GPGErrorEOF: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_PINENTRY_CRASH_TITLE");
            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_PINENTRY_CRASH_DESCRIPTION");

            break;
        }
        case GPGErrorXPCBinaryError:
        case GPGErrorXPCConnectionError:
        case GPGErrorXPCConnectionInterruptedError: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_XPC_DAMAGED_TITLE");
            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_XPC_DAMAGED_DESCRIPTION");

            appendContactGPGToolsInfo = NO;

            break;
        }
        default:
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_UNKNOWN_ERROR_TITLE");

            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_UNKNOWN_ERROR_DESCRIPTION");

            break;
    }

    if(errorText.length && appendContactGPGToolsInfo) {
        description = [description stringByAppendingFormat:GMLocalizedString(@"CONTACT_GPGTOOLS_WITH_INFO_MESSAGE"), errorText];
    }

    // The error domain is checked in certain occasion, so let's use the system
    // dependent one.

    id mailError = [GPGMailBundle errorWithCode:1036 userInfo:@{@"NSLocalizedDescription": description,
                                                    @"_MFShortDescription": title,
                                                    @"GPGErrorCode": @((long)errorCode)}];
    return mailError;
//
//
//    // Puh, this was all but easy, to find out where the error is used.
//    // Overreleasing allows to track it's path as an NSZombie in Instruments!
//    [(MCActivityMonitor *)[GM_MAIL_CLASS(@"ActivityMonitor") currentMonitor] setError:mailError];
}

+ (NSError *)localizedErrorForEncryptionFailureWithGPGErrorCode:(GPGErrorCode)errorCode error:(NSException *)error {
    NSString *title = nil;
    NSString *description = nil;
    NSString *errorText = nil;
    if([error isKindOfClass:[GPGException class]])
        errorText = ((GPGException *)error).gpgTask.errText;
    else if([error isKindOfClass:[NSException class]])
        errorText = ((NSException *)error).reason;

    switch (errorCode) {
        case GPGErrorXPCBinaryError:
        case GPGErrorXPCConnectionError:
        case GPGErrorXPCConnectionInterruptedError: {
            title = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_XPC_DAMAGED_TITLE");
            description = GMLocalizedString(@"MESSAGE_SIGNING_ERROR_XPC_DAMAGED_DESCRIPTION");

            break;
        }
        default: {
            title = GMLocalizedString(@"MESSAGE_ENCRYPTION_ERROR_UNKNOWN_ERROR_TITLE");

            description = GMLocalizedString(@"MESSAGE_ENCRYPTION_ERROR_UNKNOWN_ERROR_DESCRIPTION");

            break;
        }
    }

    if(errorText.length) {
        description = [description stringByAppendingFormat:GMLocalizedString(@"CONTACT_GPGTOOLS_WITH_INFO_MESSAGE"), errorText];
    }

    // The error domain is checked in certain occasion, so let's use the system
    // dependent one.
    NSError *mailError = (NSError *)[GPGMailBundle errorWithCode:1035 userInfo:@{@"NSLocalizedDescription": description,
                                                    @"_MFShortDescription": title,
                                                    @"GPGErrorCode": @((long)errorCode)}];

    return mailError;
}

- (MCOutgoingMessage *)outgoingMessageFromTopLevelMimePart:(MCMimePart *)topLevelMimePart topLevelHeaders:(MCMutableMessageHeaders *)topLevelHeaders partData:(NSMapTable *)partData {

    // Bug #1103: Thunderbird shows signed or encrypted messages as empty
    //
    // If the top level headers include a content-transfer-encoding header with a
    // value different from 7bit, 8bit or binary in case of a multipart top level
    // part, Thunderbird shows the message as emtpy. It appears that Thunderbird
    // strictly follows the RFC 1341 here, which states:
    //
    // `As stated in the definition of the Content-Transfer-Encoding field,
    //  no encoding other than "7bit", "8bit", or "binary" is permitted for
    //  entities of type "multipart".`
    //
    // If the top level content-type is multipart, the content-transfer-encoding is removed.
    if([topLevelMimePart isType:@"multipart" subtype:nil]) {
        [topLevelHeaders removeHeaderForKey:@"content-transfer-encoding"];
    }

    MCMessageGenerator *generator = self.writer;
    [generator setEncoder:nil];
    // In case the message is encrypted, no top level headers are necessary.
    // TODO: Consider that they might as well be and compared to the decrypted headers. Not sure if that makes sense.

    MCOutgoingMessage *outgoingMessage = [generator _newOutgoingMessageFromTopLevelMimePart:topLevelMimePart
                                                            topLevelHeaders:topLevelHeaders
                                                               withPartData:partData];
    return outgoingMessage;
}

- (NSData *)dataForMimePart:(MCMimePart *)mimePart partData:(NSMapTable *)partData {
    MCMessageGenerator *generator = self.writer;
    [generator setEncoder:nil];

    return [generator _newDataForMimePart:mimePart withPartData:partData];
}

- (NSData *)messageDataFromTopLevelMimePart:(MCMimePart *)topLevelMimePart topLevelHeaders:(MCMessageHeaders *)topLevelHeaders partData:(NSMapTable *)partData {
    MCOutgoingMessage *outgoingMessage = [self outgoingMessageFromTopLevelMimePart:topLevelMimePart topLevelHeaders:topLevelHeaders partData:partData];
    return [outgoingMessage rawData];
}

- (NSData *)messageDataFromTopLevelPart:(MCMimePart *)topLevelPart partData:(NSMapTable * __nullable)partData {
    partData = partData == nil ? [[NSMapTable alloc] initWithKeyOptions:0 valueOptions:0 capacity:0] : partData;
    [topLevelPart enumerateSubPartsWithOptions:0 usingBlock:^(MCMimePart *part) {
        // Encoded body
        // Only set the original mime part data for the parts
        // that are not overridden in `partData`.
        if([partData objectForKey:part]) {
            return;
        }
        if([part isType:@"multipart" subtype:nil]) {
            return;
        }
        [partData setObject:[part encodedBodyData] forKey:part];
    }];

    NSData *messageData = [self dataForMimePart:topLevelPart partData:partData];

    return messageData;
}

- (NSData *)signedDataForBodyData:(NSData *)bodyData sender:(NSString *)sender signingKey:(GPGKey *)signingKey hashAlgorithm:(GPGHashAlgorithm *)hashAlgorithm error:(NSError __autoreleasing **)error {
    NSData *signedData = nil;
    GPGController *gpg = [[self class] standardGPGController];

    gpg.signerKey = signingKey;
    GPGHashAlgorithm algorithm = 0;

    bodyData = [bodyData dataPreparedForVerification];

    @try {
        signedData = [gpg processData:bodyData withEncryptSignMode:GPGDetachedSign recipients:nil hiddenRecipients:nil];
        algorithm = gpg.hashAlgorithm;

        if(gpg.error) {
            @throw gpg.error;
        }
    }
    @catch(GPGException *exception) {
        *error = [[self class] localizedErrorForSigningFailureWithSender:sender gpgErrorCode:exception.errorCode error:exception];
        if(exception.errorCode == GPGErrorCancelled) {
            // TODO: Check if it is necessary to handle this case special
            // or if the information on the localized error is enough.
        }
        return nil;
    }
    @catch(NSException *exception) {
        *error = [[self class] localizedErrorForSigningFailureWithSender:sender gpgErrorCode:1 error:exception];
        return nil;
    }
    @finally {
        // Don't think this is necessary.
        gpg = nil;
    }

    if(algorithm <= 0) {
        algorithm = GPGHashAlgorithmSHA1;
    }
    if(hashAlgorithm) {
        *hashAlgorithm = algorithm;
    }

    return signedData;
}

- (NSData *)encryptedDataForBodyData:(NSData *)bodyData recipients:(NSArray <GPGKey *> *)recipients hiddenRecipients:(NSArray <GPGKey *> *)hiddenRecipients error:(NSError __autoreleasing **)error {
    GPGController *gpg = [[self class] standardGPGController];
    NSData *encryptedData = nil;
    @try {
        GPGEncryptSignMode encryptMode = GPGPublicKeyEncrypt;
        encryptedData = [gpg processData:bodyData withEncryptSignMode:encryptMode recipients:recipients hiddenRecipients:hiddenRecipients];

        if (gpg.error) {
            @throw gpg.error;
        }
    }
    @catch(NSException *exception) {
        GPGErrorCode errorCode = [exception isKindOfClass:[GPGException class]] ? ((GPGException *)exception).errorCode : 1;
        *error = [[self class] localizedErrorForEncryptionFailureWithGPGErrorCode:errorCode error:gpg.error];
        if(errorCode == GPGErrorCancelled) {
            // TODO: Is there anything special to do for cancelled but checking
            // the returned error?
        }
        return nil;
    }
    @finally {
        gpg = nil;
    }

    return encryptedData;
}

- (MCMimePart *)encryptedMimeTreeWithData:(NSData *)data partData:(NSMapTable *)partData {
    MCMimePart *dataPart = [MCMimePart new];

    [dataPart setType:@"application"];
    [dataPart setSubtype:@"octet-stream"];
    [dataPart setBodyParameter:@"encrypted.asc" forKey:@"name"];
    dataPart.contentTransferEncoding = @"7bit";
    [dataPart setDisposition:@"inline"];
    [dataPart setDispositionParameter:@"encrypted.asc" forKey:@"filename"];
    [dataPart setContentDescription:@"OpenPGP encrypted message"];

    MCMimePart *versionPart = [MCMimePart new];
    [versionPart setType:@"application"];
    [versionPart setSubtype:@"pgp-encrypted"];
    [versionPart setContentDescription:@"PGP/MIME Versions Identification"];
    versionPart.contentTransferEncoding = @"7bit";

    MCMimePart *topLevelEncryptedPart = [MCMimePart new];
    [topLevelEncryptedPart setType:@"multipart"];
    [topLevelEncryptedPart setSubtype:@"encrypted"];
    [topLevelEncryptedPart setBodyParameter:@"application/pgp-encrypted" forKey:@"protocol"];

    [topLevelEncryptedPart addSubpart:versionPart];
    [topLevelEncryptedPart addSubpart:dataPart];

    NSData *versionData = [@"Version: 1\r\n" dataUsingEncoding:NSASCIIStringEncoding];

    [partData setObject:versionData forKey:versionPart];
    [partData setObject:data forKey:dataPart];

    NSData *topData = [@"This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)" dataUsingEncoding:NSASCIIStringEncoding];
    [partData setObject:topData forKey:topLevelEncryptedPart];

    return topLevelEncryptedPart;
}

- (MCMimePart *)signedMimeTreeWithData:(NSData *)data signatureData:(NSData *)signatureData partData:(NSMapTable *)partData hashAlgorithmName:(NSString *)hashAlgorithmName {
    MCMimePart *topPart = [MCMimePart new];
    topPart.type = @"multipart";
    topPart.subtype = @"signed";
    [topPart setBodyParameter:[NSString stringWithFormat:@"pgp-%@", hashAlgorithmName] forKey:@"micalg"];
    [topPart setBodyParameter:@"application/pgp-signature" forKey:@"protocol"];

    MCMimePart *signaturePart = [MCMimePart new];
    signaturePart.type = @"application";
    signaturePart.subtype = @"pgp-signature";
    [signaturePart setBodyParameter:@"signature.asc" forKey:@"name"];
    signaturePart.contentTransferEncoding = @"7bit";
    signaturePart.disposition = @"attachment";
    [signaturePart setDispositionParameter:@"signature.asc" forKey:@"filename"];
    signaturePart.contentDescription = @"Message signed with OpenPGP";

    MCMimePart *partTreeToSign = [[MCMimePart alloc] initWithEncodedData:data];
    [partTreeToSign parse];

    [partData setObject:signatureData forKey:signaturePart];

    [partTreeToSign enumerateSubPartsWithOptions:0 usingBlock:^(MCMimePart *mimePart) {
        NSLog(@"Mime Part: %@", mimePart);
        NSData *bodyData = [mimePart encodedBodyData];
        if([partData objectForKey:mimePart]) {
            return;
        }
        if([mimePart isType:@"multipart" subtype:nil]) {
            return;
        }
        if([bodyData length] >= 0) {
            [partData setObject:bodyData forKey:mimePart];
        }
    }];

    // Self is actually the whole current message part.
    // So the only thing to do is, add self to our top part
    // and add the signature part to the top part and voila!
    [topPart addSubpart:partTreeToSign];
    [topPart addSubpart:signaturePart];

    return topPart;
}

- (NSData *)partialMessageDataWithoutHeaders:(MCMutableMessageHeaders * __autoreleasing *)outHeaders {
    MCMimePart *topLevelPart = [[MCMimePart alloc] initWithEncodedData:self.messageData];
    MCMutableMessageHeaders *headers = [[MCMutableMessageHeaders alloc] initWithHeaderData:[topLevelPart headerData] encodingHint:0];
    [topLevelPart parse];

    // Message data is a full RFC822 message, so re-create the data without the complete
    // headers.
    NSMapTable *partData = [[NSMapTable alloc] initWithKeyOptions:0 valueOptions:0 capacity:0];
    NSData *bodyData = [self messageDataFromTopLevelPart:topLevelPart partData:partData];

    if(outHeaders != NULL) {
        *outHeaders = headers;
    }

    return bodyData;
}

- (MCOutgoingMessage *)messageSignedFromSender:(NSString *)sender signingKey:(GPGKey *)signingKey error:(NSError * __autoreleasing *)error {
    MCMutableMessageHeaders __autoreleasing *headers = nil;
    NSData *bodyData = [self partialMessageDataWithoutHeaders:&headers];

    GPGHashAlgorithm hashAlgorithm = 0;
    NSData *signatureData = [self signedDataForBodyData:bodyData sender:sender signingKey:signingKey hashAlgorithm:&hashAlgorithm error:error];
    if(!signatureData) {
        return nil;
    }

    if(hashAlgorithm <= 0) {
        hashAlgorithm = GPGHashAlgorithmSHA1;
    }
    NSString *hashAlgorithmName = [GPGController nameForHashAlgorithm:hashAlgorithm];

    NSMapTable *partData = [[NSMapTable alloc] initWithKeyOptions:0 valueOptions:0 capacity:0];
    MCMimePart *signedTopLevelPart = [self signedMimeTreeWithData:bodyData signatureData:signatureData partData:partData hashAlgorithmName:hashAlgorithmName];

    return [self outgoingMessageFromTopLevelMimePart:signedTopLevelPart topLevelHeaders:headers partData:partData];
}

- (MCOutgoingMessage *)messageEncryptedForRecipients:(NSArray <GPGKey *> *)recipients hiddenRecipients:(NSArray <GPGKey *> *)hiddenRecipients error:(NSError * __autoreleasing *)error {
    MCMutableMessageHeaders __autoreleasing *headers = nil;
    NSData *bodyData = [self partialMessageDataWithoutHeaders:&headers];

    NSData *encryptedData = [self encryptedDataForBodyData:bodyData recipients:recipients hiddenRecipients:hiddenRecipients error:error];

    if(!encryptedData) {
        return nil;
    }

    NSMapTable *partData = [[NSMapTable alloc] initWithKeyOptions:0 valueOptions:0 capacity:0];
    MCMimePart *encryptedTopLevelPart = [self encryptedMimeTreeWithData:encryptedData partData:partData];

    return [self outgoingMessageFromTopLevelMimePart:encryptedTopLevelPart topLevelHeaders:headers partData:partData];
}

@end
