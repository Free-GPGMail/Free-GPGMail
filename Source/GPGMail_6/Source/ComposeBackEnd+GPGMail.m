//
//  ComposeBackEnd+GPGMail.m
//  GPGMail
//
//  Created by Lukas Pitschl on 31.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "objc/runtime.h"
#import <AppKit/AppKit.h>
#import <MCOutgoingMessage.h>
//#import <MessageBody.h>
#import <MCMimePart.h>
#import <MCMessageGenerator.h>
//#import <NSString-EmailAddressString.h>
//#import <NSString-NSStringUtils.h>
#import <MCMutableMessageHeaders.h>
//#import <MailNotificationCenter.h>
#import <ComposeBackEnd.h>
#import "MFMailAccount.h"
#import "MCAttachment.h"
#import "CCLog.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSString+GPGMail.h"
#import "NSData+GPGMail.h"
#import "MimePart+GPGMail.h"
#import "Message+GPGMail.h"
#import "GPGFlaggedString.h"
#import "GMSecurityHistory.h"
#import "GPGMailBundle.h"
//#import "HeadersEditor+GPGMail.h"
//#import "MailDocumentEditor.h"
#import "MailDocumentEditor+GPGMail.h"
#import "ComposeBackEnd+GPGMail.h"
//#import "ActivityMonitor.h"
//#import <MFError.h>
//#import "NSData-MessageAdditions.h"

#import "ComposeViewController.h"
#import "HeadersEditor.h"
#import "MCActivityMonitor.h"

#import "MCKeychainManager.h"

#import "NSArray+Functional.h"
#import "GPGConstants.h"

#import "GMComposeMessagePreferredSecurityProperties.h"
#import "GMMessageEncoder.h"

//#import <MailKit/MailKit.h>

#define MAIL_SELF ((ComposeBackEnd *)self)

extern NSString * const kComposeViewControllerPreventAutoSave;
extern NSString * const kMCMessageGeneratorSecurityMethodKey;

const NSString *kComposeBackEndPreferredSecurityPropertiesKey = @"PreferredSecurityPropertiesKey";
NSString * const kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey = @"ReturnCompleteBodyDataForComposeBackEnd";
NSString * const kComposeBackEndPreferredSecurityPropertiesAccessLockKey = @"ComposeBackEndPreferredSecurityPropertiesAccessLockKey";
NSString * const kComposeBackEndSecurityUpdateQueueKey = @"kComposeBackEndSecurityUpdateQueue";

// TODO: Import MailKit instead, once Xcode is updated on CI.

@interface MEComposeContext : NSObject

- (void)setShouldSign:(BOOL)shouldSign;
- (void)setShouldEncrypt:(BOOL)shouldEncrypt;

@end

@interface ComposeBackEnd_GPGMail ()

- (NSArray *)GMRealRecipients;

@property (nonatomic, retain) NSRecursiveLock *preferredSecurityPropertiesAccessLock;

@end

@implementation ComposeBackEnd_GPGMail

- (NSAttributedString *)plainTextFixedForSigning:(NSMutableAttributedString *)plainText shouldAddNewLine:(BOOL)shouldAddNewLine {
    // Bug #1079: Sending empty signed message crashes GPG Mail 5.
    //
    // NSRegularExpression doesn't handle nil strings gracefully, so
    // in case plainText is nil, return immediately.
    if(!plainText) {
        return plainText;
    }

    NSMutableString *plainString = [plainText mutableString];
    
    // If we are only signing and there isn't a newline at the end of the plaintext, append it.
    // We need this to prevent servers from doing this.
    if (shouldAddNewLine) {
        if ([plainString characterAtIndex:plainString.length - 1] != '\n') {
            [plainString appendString:@"\n"];
        }
    }
    
    // Remove all whitespaces at the end of lines. But don't kill attachments.
    NSMutableArray *ranges = [NSMutableArray array];
    NSError __autoreleasing *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[\\t\\f\\r\\p{Z}]+$" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    // Get all matches and reverse the order.
    [regex enumerateMatchesInString:plainString options:0 range:NSMakeRange(0, [plainString length]) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags __unused flags, BOOL * _Nonnull __unused  stop) {
        [ranges insertObject:result atIndex:0];
    }];

    for (NSTextCheckingResult *result in ranges) {
        [plainString replaceCharactersInRange:result.range withString:@""];
    }
    
    return plainText;
}



- (BOOL)sentActionInvokedFromiCalWithContents:(WebComposeMessageContents *)contents {
	if([contents.attachmentsAndHtmlStrings count] == 0)
		return NO;
	
	
	BOOL fromiCal = NO;
	for(id item in contents.attachmentsAndHtmlStrings) {
		if([item isKindOfClass:GM_MAIL_CLASS(@"MCAttachment")]) {
			MCAttachment *attachment = (MCAttachment *)item;
			// For some non apparent reason, iCal invitations are not recognized by isCalendarInvitation anymore...
			// so let's check for text/calendar AND isCalendarInvitation.
			if(([[[attachment mimeType] lowercaseString] isEqualToString:@"text/calendar"] || attachment.isCalendarInvitation) &&
			   [[attachment filename] rangeOfString:@"iCal"].location != NSNotFound &&
			   [[attachment filename] rangeOfString:@".ics"].location != NSNotFound) {
				fromiCal = YES;
				break;
			}
		}
	}
	
	return fromiCal;
}

- (BOOL)GMShouldDownloadRemoteAttachments {
	BOOL shouldDownloadRemoteAttachments = [[self valueForKey:@"_shouldDownloadRemoteAttachments"] boolValue];
	
	return shouldDownloadRemoteAttachments;
}

- (id)MA_newOutgoingMessageUsingWriter:(MCMessageGenerator *)writer contents:(WebComposeMessageContents *)contents headers:(MCMutableMessageHeaders *)headers isDraft:(BOOL)isDraft NS_RETURNS_RETAINED {
    // Note for macMonterey:
    //
    // This method is now called multiple times when a message is sent, since Mail
    // creates a separate outgoing message instance for the installed extensions (even
    // if no extension is installed) in order to allow the extension to perform
    // validation on it, before sending.
    //
    // While that is no problem, it makes it harder to debug errors. To temporarily
    // disable the separate outgoing message for extensions, the `CheckAppExtensionValidationErrors`
    // key from the checks array in `-[ComposeViewController sendMessageAferChecking]`
    //
    // It might be a problem for preventing auto-saves to happen, *when* a message is being
    // prepared for sending, since messageIsBeingPreparedForSending is also called multiple times.
    id (^original)(void) = ^id (void) {
        return [self MA_newOutgoingMessageUsingWriter:writer contents:contents headers:headers isDraft:isDraft];
    };
    
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return original();
    }
    
    GMComposeMessagePreferredSecurityProperties *securityProperties = self.preferredSecurityProperties;
    GPGMAIL_SECURITY_METHOD securityMethod = securityProperties.securityMethod;
    
    // If this is a draft that is being saved, the security properties are stored
    // as header keys so they can later be restored, when the draft is being continued.
    // Otherwise, any security properties related header keys are removed.
    NSDictionary *secureDraftHeaders = nil;
    if(isDraft) {
        [self.preferredSecurityPropertiesAccessLock lock];
        secureDraftHeaders = [[securityProperties secureDraftHeaders] copy];
        [self.preferredSecurityPropertiesAccessLock unlock];
        
        // Prevent hang on 10.10 when restoring drafts.
        // Mail on 10.10 needs the "x-apple-mail-remote-attachments" header in every draft mail.
        // See: https://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/871
        [headers setHeader:self.GMShouldDownloadRemoteAttachments ? @"YES" : @"NO" forKey:@"x-apple-mail-remote-attachments"];

        for(NSString *headerKey in secureDraftHeaders) {
            [headers setHeader:[secureDraftHeaders objectForKey:headerKey] forKey:headerKey];
        }
    }
    else {
        for(NSString *headerKey in [securityProperties secureDraftHeadersKeys]) {
            [headers removeHeaderForKey:headerKey];
        }
    }
    
    if (@available(macOS 12.0, *)) {
        if(securityMethod == GPGMAIL_SECURITY_METHOD_SMIME) {
            // Configure the S/MIME compose context otherwise the S/MIME
            // handler won't kick in.
            MEComposeContext *composeContext = [self valueForKey:@"_composeExtensionContext"];
            [composeContext setShouldSign:securityProperties.shouldSignMessage];
            [composeContext setShouldEncrypt:securityProperties.shouldEncryptMessage];
        }
    }
    BOOL bailOut = NO;

    // Based on the following three cases it might be possible to bail out and leave the
    // remaining work to macOS Mail.
    // 1.) securityMethod is SMIME
    // 2.) The message is a calendar event which is sent from iCal without user interaction.
    //     In this case, `userShouldSignMessage` and `userShouldEncryptMessage` will be set to `ThreeStateBooleanUndetermined`
    // 3.) The message is neither a draft nor should it be encrypted or signed.
    BOOL isInvokedFromCalendar = [self sentActionInvokedFromiCalWithContents:contents];
    if((securityMethod != GPGMAIL_SECURITY_METHOD_OPENPGP) ||
       // Case 2.
       (isInvokedFromCalendar &&
        securityProperties.userShouldSignMessage == ThreeStateBooleanUndetermined &&
        securityProperties.userShouldEncryptMessage == ThreeStateBooleanUndetermined) ||
       // Case 3.
       (!isDraft &&
        !securityProperties.shouldSignMessage &&
        !securityProperties.shouldEncryptMessage)) {
        bailOut = YES;
    }
    
    if(bailOut) {
        return original();
    }
    
    // Next step, Mail is instructed to create the message to sign or encrypt,
    // but to make sure that the message is not processed by the S/MIME encoder
    // remove the encoder.
    [writer setEncoder:nil];
    // If the message is to be signed, the text content has to be fixed up first by removing
    // any additional spaces before a new line, since they will result in invalid signatures.
    if(securityProperties.shouldSignMessage) {
        contents.plainText = [self plainTextFixedForSigning:[contents.plainText mutableCopy] shouldAddNewLine:securityProperties.shouldSignMessage && !securityProperties.shouldEncryptMessage];
    }
    MCOutgoingMessage *outgoingMessage = original();
    // In case the outgoing message is nil, there's probably been an error.
    // Bail out early.
    if(outgoingMessage == nil) {
        return outgoingMessage;
    }
    
    BOOL userWantsDraftsEncrypted = [[GPGOptions sharedOptions] boolForKey:@"OptionallyEncryptDrafts"];
    // If the user doesn't want for drafts to be encrypted, the created outgoing
    // message is handed over to Mail.
    if(isDraft && !userWantsDraftsEncrypted) {
        return outgoingMessage;
    }
    
    NSData *messageData = [outgoingMessage rawData];

    [self.preferredSecurityPropertiesAccessLock lock];
    GPGKey *signingKey = securityProperties.signingKey;
    BOOL shouldSign = securityProperties.shouldSignMessage && !isDraft;
    BOOL shouldEncrypt = isDraft || securityProperties.shouldEncryptMessage;
    NSString *sender = [MAIL_SELF sender];
    [self.preferredSecurityPropertiesAccessLock unlock];
    
    // Drafts are never signed.
    
#if DEBUG
    // TODO: REMOVE. only for quick testing the code.
//    shouldSign = YES;
#endif
    NSError __autoreleasing *error = nil;
    if(shouldSign) {
        GMMessageEncoder *encoder = [[GMMessageEncoder alloc] initWithData:messageData writer:writer];
        outgoingMessage = [encoder messageSignedFromSender:sender signingKey:signingKey error:&error];
        messageData = [outgoingMessage rawData];
    }
    if(shouldEncrypt && error == nil) {
        GMMessageEncoder *encoder = [[GMMessageEncoder alloc] initWithData:messageData writer:writer];
        NSMutableSet <GPGKey *> *recipientKeys = [NSMutableSet new];
        NSMutableSet <GPGKey *> *hiddenRecipientKeys = [NSMutableSet new];
        
        if(!isDraft) {
            NSMutableArray <NSString *> *recipients = [NSMutableArray new];
            NSMutableArray <NSString *> *bccRecipients = [NSMutableArray new];
            // It is possible that the sender does not only match a private key
            // but also a separate public key which might not be related to the
            // private key, for example if an older key is available in the keyring
            // with the same address.
            // To guarantee that the messsage can be read by the sender, a recipient
            // with the same address is removed from the recipients and bcc-recipients
            // keys and added separately later.
            // If the sender is included in the recipients list it is excluded,
            // since there might be a public key
            for(NSString *recipient in [MAIL_SELF _structuredListForHeader:@"bcc"]) {
                if([recipient isEqualToString:sender] ||
                   [recipient isKindOfClass:[GMComposeMessageReplyToDummyKey class]]) {
                    continue;
                }
                [bccRecipients addObject:recipient];
            }
            for(NSString *recipient in [self GMRealRecipients]) {
                if([bccRecipients containsObject:recipient] ||
                   [recipient isEqualToString:sender] ||
                   [recipient isKindOfClass:[GMComposeMessageReplyToDummyKey class]]) {
                    continue;
                }
                [recipients addObject:recipient];
            }
            if(signingKey) {
                [recipientKeys addObject:signingKey];
            }
            if([recipients count] > 0) {
                [recipientKeys addObjectsFromArray:[securityProperties encryptionKeysForRecipients:recipients]];
            }
            if([bccRecipients count] > 0) {
                [hiddenRecipientKeys addObjectsFromArray:[securityProperties encryptionKeysForRecipients:recipients]];
            }
        }
        else {
            // Drafts are always encrypted with the users private key if available.
            GPGKey *encryptionKeyForDraft = [securityProperties encryptionKeyForDraft];
            if(encryptionKeyForDraft) {
                [recipientKeys addObject:encryptionKeyForDraft];
            }
            // TODO: If userWantsDraftsEncrypted is enabled, but no appropriate key could be found
        }
        
        outgoingMessage = [encoder messageEncryptedForRecipients:[recipientKeys allObjects] hiddenRecipients:[hiddenRecipientKeys allObjects] error:&error];
    }
    
    // An error that occurs during message creation is handled differently by Mail
    // based on whether a draft is being created or a message to be sent.
    //
    // Draft:
    // In case of an error that occurs during creation of a draft, by default
    // a standard Mail error message would be displayed, instead of our custom one.
    // To prevent that from happening, the activity monitor is cancelled and GPG Mail
    // is the one responsible for displaying an error message.
    //
    // Message to be sent:
    // In case of an error that occurs during creation of a message to be sent,
    // displaying the error message is left to Mail, since GPG Mail has hooks installed
    // in the responsible error displaying methods like `-[ComposeViewController backEnd:didCancelMessageDeliveryForEncryptionError:]`
    if(error) {
        [[MCActivityMonitor currentMonitor] setError:error];
        if(isDraft) {
            // Mail is prevented from displaying its default error by
            // canceling the message creation via activity monitor.
            [[MCActivityMonitor currentMonitor] cancel];
            [self performSelectorOnMainThread:@selector(didCancelMessageDeliveryForError:) withObject:error waitUntilDone:NO];
        }
        return nil;
    }
    
    return outgoingMessage;
}

- (void)didCancelMessageDeliveryForError:(NSError *)error {
    [(ComposeViewController *)[(ComposeBackEnd *)self delegate] backEnd:self didCancelMessageDeliveryForEncryptionError:error];
}

- (BOOL)messageIsBeingReplied {
    // 1 = Reply
    // 2 = Reply to all.
    // 3 = Forward.
    // 4 = Restored Reply window.
    // 12 = Restored window after send error.
    // Bug #1043: Security button states not properly restored
    //            after message fails to send
    //
    // A restored reply after a send error uses the `type` 12. So
    // in order to properly restore the security button states
    // 12 is added to the list of allowed values for type for a reply.
    NSInteger type = [(ComposeBackEnd *)self type];
    return (type == 1 || type == 2 || type == 4 || type == 12);
}

- (BOOL)messageIsBeingForwarded {
    NSInteger type = [MAIL_SELF type];
    return type == 3;
}

- (GMComposeMessagePreferredSecurityProperties *)preferredSecurityProperties {
    GMComposeMessagePreferredSecurityProperties *securityProperties = nil;
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    [self.preferredSecurityPropertiesAccessLock lock];
    securityProperties = [self getIvar:kComposeBackEndPreferredSecurityPropertiesKey];
    [self.preferredSecurityPropertiesAccessLock unlock];

    return securityProperties;
}

- (void)setPreferredSecurityProperties:(GMComposeMessagePreferredSecurityProperties *)preferredSecurityProperties {
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    [self setIvar:kComposeBackEndPreferredSecurityPropertiesKey value:preferredSecurityProperties];
}

// INFO: No longer relevant on Monterey.
//- (void)MAUpdateSMIMEStatus:(void(^)(void))onComplete {
//    // Re-Implementation of Mail's updateSMIMEStatus.
//    // updateSMIMEStatus is invoked by updateSecurityControls, which is responsible for any UI updates.
//    // If we're *not* on the main thread, we let Mail handle the logging of the error.
//    [self MAUpdateSMIMEStatus:onComplete];
//    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
//        [self MAUpdateSMIMEStatus:onComplete];
//        return;
//    }
//    if(![NSThread isMainThread]) {
//        [self MAUpdateSMIMEStatus:onComplete];
//        return;
//    }
//    [MAIL_SELF setDefaultSenderIfNeeded];
//}

#pragma mark - macOS Monterey: update security status

- (void)MA_updateMessageSecurityStatusWithCompletion:(void(^)(void))onComplete {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return [self MA_updateMessageSecurityStatusWithCompletion:onComplete];
    }

    NSString *sender = nil;
    sender = [MAIL_SELF sender];
    NSArray *recipients = [self GMRealRecipients];

    // Bug #1048: Encryption button stays checked and active even if all
    //           recipient fields are empty.
    //
    // Previously the encryption button stayed enabled and checked, since the
    // sender is always added to the list of recipients (encrypt-to-self).
    //
    // When a new composing window is created however, the encryption button is
    // disabled. So to make the state consistent, don't add the sender to the
    // recipients if the recipient fields are empty which results in the encryption
    // button being disabled, if all recipient fields are emptied.
    if([recipients count] > 0 && sender) {
        recipients = [recipients arrayByAddingObject:sender];
    }

    // Update the security properties with the current sender and recipient information.
    NSMutableArray *replyToAddresses = [NSMutableArray new];
    for(NSString *address in [MAIL_SELF _structuredListForHeader:@"reply-to"]) {
        // If the reply-to address is also contained in the recipients list
        // it must not be added to the replyToAddress list, since otherwise
        // the message would not be encrypted for it.
        if(![recipients containsObject:address]) {
            [replyToAddresses addObject:address];
        }
    }
    
    // Setting `encryptionState` to 0 indicates that the security update
    // is not completed yet.
    // This property is checked in `-[ComposeViewController sendMessageAfterChecking:]` to determine
    // whether the message can be sent or not.
    [self runBlockProtectedBySMIMELock:^{
        [MAIL_SELF setEncryptionState:0];
    }];
    
    NSOperationQueue *updateQueue = self.securityUpdatesQueue;
    [updateQueue cancelAllOperations];
    [updateQueue addOperationWithBlock:^{
        void (^checkCertificates)(void) = ^{
            GMComposeMessagePreferredSecurityProperties *currentSecurityProperties = self.preferredSecurityProperties;
            NSAssert(currentSecurityProperties != nil, @"Preferred security properties are setup when the back end is initialized. Can't be nil");
            // The update of the security properties needs to be locked.
            @try {
                [self.preferredSecurityPropertiesAccessLock lock];

                [currentSecurityProperties updateSender:sender recipients:recipients replyToAddresses:replyToAddresses];

                // Update the security status on the back end on the back end as well.
                [MAIL_SELF setCanSign:currentSecurityProperties.canSign];
                [MAIL_SELF setCanEncrypt:currentSecurityProperties.canEncrypt];
                [MAIL_SELF setEncryptionState:1];
                
                // Retrieving an S/MIME certificate might result in an error, so this error also
                // has to be set on the back end.
                if([MAIL_SELF respondsToSelector:@selector(setInvalidSigningIdentityError:)]) {
                    [MAIL_SELF setInvalidSigningIdentityError:currentSecurityProperties.invalidSigningIdentityError];
                }
                [MAIL_SELF setRecipientsThatHaveNoKeyForEncryption:[self.preferredSecurityProperties recipientsThatHaveNoEncryptionKey]];
            }
            @catch(NSException *error) {
                DebugLog(@"Failed to update security properties - error: %@", error);
            }
            @finally {
                [self.preferredSecurityPropertiesAccessLock unlock];
            }
        };
        [self runBlockProtectedBySMIMELock:^{
            checkCertificates();
        }];
        
        // We have our certificate information, now onto running the UI code.
        if(onComplete) {
            onComplete();
        }
    }];
}

- (void)runBlockProtectedBySMIMELock:(dispatch_block_t)block {
    id smimeLock = [self valueForKey:@"_smimeLock"];
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    if([smimeLock isKindOfClass:[NSLock class]]) {
        @try {
            [smimeLock lock];
            block();
        }
        @catch(NSException *e) {}
        @finally {
            [smimeLock unlock];
        }
    }
    else {
        @synchronized(smimeLock) {
            block();
        }
    }
}

- (NSArray *)GMRealRecipients {
    // -[ComposeBackEnd allRecipients] also includes addresses entered in reply-to
    // since Mail seems to believe that they should be treated
    // as recipients as well.
    //
    // This method returns all *real* recipients.
    NSMutableArray *recipients = [[MAIL_SELF _structuredListForHeader:@"to"] mutableCopy];
    [recipients addObjectsFromArray:[MAIL_SELF _structuredListForHeader:@"cc"]];
    [recipients addObjectsFromArray:[MAIL_SELF _structuredListForHeader:@"bcc"]];

    return [recipients copy];
}

- (void)MA_generateParsedMessageFromOriginalMessages {
    // It's necessary to tell GPGMal that the whole body is required in preparation
    // for a reply and that its allowed to decrypt the content, if necessary.
    [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey];
    [self MA_generateParsedMessageFromOriginalMessages];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey];
}

// Bug #1031: If a message fails to send, it might be replaced by its draft version prior
//              to being sent at a later time.
//
// -[ComposeBackEnd setIsUndeliverable:] is called when sending a message
// has failed. When this method is called, a new compose view controller has
// been created, so the old prevent-auto-save-flag is no longer available
// and has to be set again on the new compose view controller so auto-save is
// prevented from running, until the user has made any changes.
- (void)MASetIsUndeliverable:(BOOL)isUndeliverable {
    if(isUndeliverable) {
        [[MAIL_SELF delegate] setIvar:kComposeViewControllerPreventAutoSave value:@(YES)];
    }
    [self MASetIsUndeliverable:isUndeliverable];
}

#pragma mark - Bug #976

- (id)MAInit {
    // The compose message security properties for the message are
    // initialized when the back end is first initialized, and updated
    // whenever necessary.
    ComposeBackEnd_GPGMail *object = [self MAInit];
    GMComposeMessagePreferredSecurityProperties *securityProperties = [GMComposeMessagePreferredSecurityProperties new];
    object.preferredSecurityProperties = securityProperties;

    // The access to the security properties will be guarded by
    // a lock. The _smimeLock doesn't work here, since it might
    // be used recursively by mistake.
    NSRecursiveLock *accessLock = [NSRecursiveLock new];
    object.preferredSecurityPropertiesAccessLock = accessLock;
    
    // Since Monterey uses extensions to query the security
    // status, the NSOperationQueue for SMIME is no longer available,
    // so a a custom one is created.
    NSOperationQueue *securityUpdatesQueue = [NSOperationQueue new];
    [securityUpdatesQueue setName:@"Free-GPGMail Queue"];
    [securityUpdatesQueue setMaxConcurrentOperationCount:1];
    self.securityUpdatesQueue = securityUpdatesQueue;
    
    return self;
}

- (NSOperationQueue *)securityUpdatesQueue {
    return [self getIvar:kComposeBackEndSecurityUpdateQueueKey];
}

- (void)setSecurityUpdatesQueue:(NSOperationQueue *)queue {
    [self setIvar:kComposeBackEndSecurityUpdateQueueKey value:queue];
}

- (NSRecursiveLock *)preferredSecurityPropertiesAccessLock {
    return [self getIvar:kComposeBackEndPreferredSecurityPropertiesAccessLockKey];
}

- (void)setPreferredSecurityPropertiesAccessLock:(NSRecursiveLock *)preferredSecurityPropertiesAccessLock {
    [self setIvar:kComposeBackEndPreferredSecurityPropertiesAccessLockKey value:preferredSecurityPropertiesAccessLock];
}

#pragma mark

@end

#undef MAIL_SELF
