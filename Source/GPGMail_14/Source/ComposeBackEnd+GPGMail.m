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
#import <_MCOutgoingMimeBody.h>
//#import <MessageBody.h>
#import <MCMimeBody.h>
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
#define restrict
#import <RegexKit/RegexKit.h>

#import "ComposeViewController.h"
#import "HeadersEditor.h"
#import "MCActivityMonitor.h"

#import "MCKeychainManager.h"

#import "NSArray+Functional.h"
#import "GPGConstants.h"

#import "GMComposeMessagePreferredSecurityProperties.h"

#define MAIL_SELF ((ComposeBackEnd *)self)

const NSString *kComposeBackEndPreferredSecurityPropertiesKey = @"PreferredSecurityPropertiesKey";
NSString * const kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey = @"ReturnCompleteBodyDataForComposeBackEnd";

@implementation ComposeBackEnd_GPGMail

- (id)MASender {
	// TODO: Find out if this is still necessary, if there might be a better way to do this.
    // If a message is to be redirected, the flagged from string,
	// which might have been set in -[ComposeBackEnd _makeMessageWithContents:isDraft:shouldSign:shouldEncrypt:shouldSkipSignature:shouldBePlainText:]
	// is replaced with this value, which of course is a simple string and
	// not a flagged value.
	// So in that case, they from header is checked and if it is
	// a flagged string it is returned instead of invoking the MASender
	// method.
	// This way the flagged from string makes it through to the newSignedPart method.
	
	// Not a resend? Out of here!
	if([(ComposeBackEnd *)self type] != 7)
		return [self MASender];
	
	// Fetch the from header from the clean headers to check
	// if this message should be pgp signed.
	NSDictionary *cleanHeaders = [(ComposeBackEnd *)self cleanHeaders];
	id sender = cleanHeaders[@"from"];
	// Not a GPGFlaggedString. Out of here!
	if(![sender respondsToSelector:@selector(setValue:forFlag:)])
		return [self MASender];
	
    // On Sierra from 10.12.4b1, Mail calls senderWithValidation in -[ComposeBackEnd sender]
    // TODO: Figure out how this is implemented now.
//    if([self respondsToSelector:@selector(senderWithValidation:)]) {
//        sender = [MAIL_SELF senderWithValidation:NO];
//    }
//    else {
//        // Now emulate what -[ComposeBackEnd sender] does internally.
//        // At least part of it.
//        MFMailAccount *account = [MFMailAccount accountContainingEmailAddress:sender];
//        // Not sure what to do in this case, so let's fall back.
//        if(!account)
//            return [self MASender];
//    }
	// IF we're still in here, return the flagged sender.
	return sender;
}

- (id)MA_makeMessageWithContents:(WebComposeMessageContents *)contents isDraft:(BOOL)isDraft shouldSign:(BOOL)shouldSign shouldEncrypt:(BOOL)shouldEncrypt shouldSkipSignature:(BOOL)shouldSkipSignature shouldBePlainText:(BOOL)shouldBePlainText {
    GMComposeMessagePreferredSecurityProperties *securityProperties = self.preferredSecurityProperties;
    
	GPGMAIL_SECURITY_METHOD securityMethod = securityProperties.securityMethod;
    
    BOOL bailOut = NO;
    
    // Currently there are three cases where it's time to bail out early.
    // 1.) securityMethod is SMIME
    // 2.) The message is a calendar event which is sent from iCal without user interaction.
    //     In this case, `userShouldSignMessage` and `userShouldEncryptMessage` will be set to `ThreeStateBooleanUndetermined`
    // 3.) The message is neither a draft nor should it be encrypted or signed.
    bailOut = securityMethod != GPGMAIL_SECURITY_METHOD_OPENPGP;
    if(!bailOut) {
        bailOut = [self sentActionInvokedFromiCalWithContents:contents] && securityProperties.userShouldSignMessage == ThreeStateBooleanUndetermined && securityProperties.userShouldEncryptMessage == ThreeStateBooleanUndetermined;
    }
    if(!bailOut) {
        bailOut = !isDraft && !shouldSign && !shouldEncrypt;
    }
    
    if(bailOut) {
        return [self MA_makeMessageWithContents:contents isDraft:isDraft shouldSign:shouldSign shouldEncrypt:shouldEncrypt shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
    }
    
    // OpenPGP Drafts are encrypted by default (unless the user disabled that feature. In that case
    // shouldEncrypt is set to YES regardless of its current value.
    // It's important however to store the original values for shouldEncrypt and shouldSign in case of a draft,
    // since these values are automatically restored once the draft is continued by the user.
    BOOL userWantsDraftsEncrypted = [[GPGOptions sharedOptions] boolForKey:@"OptionallyEncryptDrafts"];
    BOOL userWantsInlinePGP = [[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPInlineToSend"];
    
    // TODO: Find out how to port the flagging of keys to the new method based on certificates and no longer on NSStrings.
    
    // First handle PGP/MIME, since that requires less manual changes (at the moment).
    
    
    // Fix up text to be signed.
    if(shouldSign) {
        contents.plainText = [self plainTextFixedForSigning:[contents.plainText mutableCopy] shouldAddNewLine:shouldSign && !shouldEncrypt];
    }
    
    // TODO: Remove before release.
    // FOR STEVE ONLY.
    //  NSAssert(!shouldSign, @"Yeah, I can't allow you to sign this message. Also, we want to test the crash reporter.");
    
    // Before the message is created in -[ComposeBackEnd outgoingMessageUsingWriter:contents:headers:isDraft:shouldBePlainText:]
    // additional headers have to be added. If they're added here, they might disappear.
    // In order for the headers not to be removed, they have to be added in -[ComposeBackEnd outgoingMessageUsingWriter:contents:headers:isDraft:shouldBePlainText:].
    // Since the following values are not all available in that method, they are attached to the contents object, and later add to the headers.
    // This is later checked, to determine the real isDraft value.
    [contents setIvar:@"IsDraft" value:@(isDraft)];
    // For drafts, Mail doesn't pass in the real states of the encrypt and sign buttons, so they are fetched from the
    // security properties.
    [contents setIvar:@"ShouldEncrypt" value:@(securityProperties.shouldEncryptMessage)];
    [contents setIvar:@"ShouldSign" value:@(securityProperties.shouldSignMessage)];
    
    // TODO: Find out how to properly handle encryption of drafts in regards to available keys and stuff.
    BOOL encryptDraft = userWantsDraftsEncrypted;
    
    // On to creating the actual message.
    // Drafts and "normal" outgoing messages are handled a bit differently.
    // Drafts are *never* signed, otherwise the user would have to enter their passphrase everytime a draft is created,
    // depending on the cache time set.
    // Also by default Mail doesn't encrypt or sign drafts. In addition, Mail only creates a very basic MIME tree for drafts,
    // which would be unsuitable for PGP/MIME processed messages.
    // In order to force Mail to encrypt messages even if a draft is created, isDraft is always passed as NO to the native
    // method.
    BOOL signMessage = isDraft ? NO : securityProperties.shouldSignMessage;
    BOOL encryptMessage = isDraft ? encryptDraft : securityProperties.shouldEncryptMessage;
    
    MCOutgoingMessage *outgoingMessage = [self MA_makeMessageWithContents:contents isDraft:NO shouldSign:signMessage shouldEncrypt:encryptMessage shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
    
    // NOTE: The monitor is set on the threadDictionary of the current thread. So as long as any error which
    //       might occur during message creation is set on the same thread, it's reliably matching this message.
    NSError *creationError = [(MCActivityMonitor *)[MCActivityMonitor currentMonitor] error];
    // When message creation failed, `outgoingMessage` will be `nil`.
    // It's however also possible that the user cancelled the pinentry dialog, in which case
    // `outgoingMessage` contains a valid message but an error is set on the current activity monitor.
    BOOL messageCreationSucceeded = outgoingMessage != nil && !creationError;
    if(!messageCreationSucceeded) {
        // If a draft should have been created, the user is presented with an error message and
        // is allowed to continue editing the message, after reacting to the error message.
        BOOL signingCancelled = [creationError.userInfo[@"GPGErrorCode"] integerValue] == GPGErrorCancelled;
        
        if(isDraft) {
            // It should also be possible to simply cancel the activity monitor.
            // TODO: Properly test this!.
            [[MCActivityMonitor currentMonitor] cancel];
            // Cancel saving to prevent the default error message.
            //[self setIvar:@"cancelSaving" value:(id)kCFBooleanTrue];
            
            // In case an error occured due to the user cancelling out the pinentry request, no error is displayed.
            if(!signingCancelled) {
                // The error message should be set on the current activity monitor, so we
                // simply have to fetch it.
                GM_CAST_CLASS(NSError *, id) error = (NSError *)[(MCActivityMonitor *)[MCActivityMonitor currentMonitor] error];
                [self performSelectorOnMainThread:@selector(didCancelMessageDeliveryForError:) withObject:error waitUntilDone:NO];
            }
        }
        return nil;
    }
    
    return outgoingMessage;
    
//    // ORIGINAL IMPLEMENTATION.
//    
//    //NSDictionary *securityProperties = self.securityProperties;
//    // The encryption part is a little tricky that's why
//    // Mail.app is gonna do the heavy lifting with our GPG encryption method
//    // instead of the S/MIME one.
//    // After that's done, we only have to extract the encrypted part.
//    BOOL shouldPGPEncrypt = shouldEncrypt;
//    BOOL shouldPGPSign = shouldSign;
//	BOOL shouldPGPInlineSign = NO;
//    BOOL shouldPGPInlineEncrypt = NO;
//    
//	// If this message is to be saved as draft, force encryption.
//    if (isDraft && !shouldPGPEncrypt && [[GPGOptions sharedOptions] boolForKey:@"OptionallyEncryptDrafts"])
//		shouldPGPEncrypt = YES;
//	
//    // It might not be possible to inline encrypt drafts, since contents.text is nil.
//    // Maybe it's not problem, and simply html should be used. (TODO: Figure that out.)
//    BOOL shouldCreatePGPInlineMessage = [[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPInlineToSend"] && !isDraft;
//    
//	// If this message is a calendar event which is being sent from iCal without user interaction (ForceSign and ForceEncrypt are NOT set),
//	// it should never be encrypted nor signed.
//	if(securityProperties.userShouldSignMessage == ThreeStateBooleanUndetermined &&
//       securityProperties.userShouldEncryptMessage == ThreeStateBooleanUndetermined &&
//	   [self sentActionInvokedFromiCalWithContents:contents]) {
//		shouldPGPEncrypt = NO;
//		shouldPGPSign = NO;
//		shouldSign = NO;
//		shouldEncrypt = NO;
//	}
//	
//    // At the moment for drafts signing and encrypting is disabled.
//    // GPG not enabled, or neither encrypt nor sign are checked, let's get the shit out of here.
//    // TODO: Maybe combine this with first early return.
//    if(!shouldPGPEncrypt && !shouldPGPSign) {
//        MCOutgoingMessage *outMessage = [self MA_makeMessageWithContents:contents isDraft:isDraft shouldSign:shouldSign shouldEncrypt:shouldEncrypt shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
//        return outMessage;
//    }
//
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    // Save the original headers.
//    // If isDraft is set cleanHeaders are an NSDictionary they need to be a NSMutableDictionary
//    // though, since Mail.app otherwise complains.
//    // The isDraft flag is removed before calling the makeMessageWithContents method, otherwise
//    // the encrypting and signing methods wouldn't be invoked.
//    // Mail.app only wants NSMutableDictionary cleanHeaders if it's not a draft.
//    // Since the isDraft flag is removed, Mail.app assumes it creates a normal message
//    // to send out and therefore wants NSMutableDictionary clean headers.
//    id copiedCleanHeaders = nil;
//    copiedCleanHeaders = [[(ComposeBackEnd *)self cleanHeaders] mutableCopy];
//
//    [self setIvar:@"originalCleanHeaders" value:copiedCleanHeaders];
//    // If isDraft is set the cleanHeaders are an NSDictionary instead of an NSMutableDictionary.
//    // Using mutableCopy they are converted into an NSMutableDictionary.
//    copiedCleanHeaders = [[(ComposeBackEnd *)self cleanHeaders] mutableCopy];
//    [self setValue:copiedCleanHeaders forKey:@"_cleanHeaders"];
//    
//	// Inject the headers needed in newEncryptedPart and newSignedPart.
//	[self _addGPGFlaggedStringsToHeaders:[(ComposeBackEnd *)self cleanHeaders] forEncrypting:shouldPGPEncrypt forSigning:shouldPGPSign forSymmetric:shouldPGPSymmetric isDraft:isDraft];
//
//    // If the message is supposed to be encrypted or signed inline,
//    // GPGMail does that directly in the Compose back end, and not use
//    // the message write to create it, yet, to get an OutgoingMessage to work with.
//    // Mail.app is instructed to create the Outgoing message with no encrypting and no
//    // signing. 
//    // After that the body is replaced by the pgp inline data.
//    if(shouldCreatePGPInlineMessage) {
//        shouldPGPInlineSign = shouldPGPSign;
//        shouldPGPInlineEncrypt = shouldPGPEncrypt;
//		shouldPGPInlineSymmetric = shouldPGPSymmetric;
//        shouldPGPSign = NO;
//        shouldPGPEncrypt = NO;
//		shouldPGPSymmetric = NO;
//    }
//	
//	NSMutableAttributedString *plainText = (NSMutableAttributedString *)contents.plainText;
//	NSMutableString *plainString = [plainText mutableString];
//	
//	// If we are only signing and there isn't a newline at the end of the plaintext, append it.
//	// We need this to prevent servers from doing this.
//	if (shouldPGPSign && !shouldPGPEncrypt && !shouldPGPSymmetric) {
//		if ([plainString characterAtIndex:plainString.length - 1] != '\n') {
//			[plainString appendString:@"\n"];
//		}
//	}
//	if (shouldPGPSign) {
//		// Remove all whitespaces at the end of lines. But don't kill attachments.
//		RKRegex *regex = [RKRegex regexWithRegexString:@"[\\t\\f\\r\\p{Z}]+$" options:RKCompileMultiline];
//		RKEnumerator *rkEnum = [plainString matchEnumeratorWithRegex:regex];
//		
//		NSMutableArray *ranges = [NSMutableArray array];
//		
//		// Get all matches and reverse the order.
//		for (NSArray *match in rkEnum) {
//			[ranges insertObject:match[0] atIndex:0];
//		}
//		// Removed matched characters.
//		for (NSValue *range in ranges) {
//			[plainString replaceCharactersInRange:range.rangeValue withString:@""];
//		}
//	}
//    
//	// This is later checked, to determine the real isDraft value.
//	[contents setIvar:@"IsDraft" value:@(isDraft)];
//	[contents setIvar:@"ShouldEncrypt" value:@(shouldPGPEncrypt || shouldPGPInlineEncrypt)];
//	[contents setIvar:@"ShouldSign" value:@(shouldPGPSign || shouldPGPInlineSign)];
//	
//    if(isDraft) {
//        // If there's a public key available to encrypt the draft,
//        // it's encrypted, otherwise we disable encryption.
//        GPGKey *encryptDraftPublicKey = [[[(ComposeBackEnd *)self cleanHeaders] valueForKey:@"from"] valueForFlag:@"DraftPublicKey"];
//        if(encryptDraftPublicKey) {
//            // Drafts mustn't be signed, otherwise Mail creates duplicate zombie drafts again.
//            shouldPGPSign = NO;
//            shouldPGPSymmetric = NO;
//            shouldPGPEncrypt = YES;
//        }
//        else {
//            shouldPGPEncrypt = NO;
//            shouldPGPSign = NO;
//            shouldPGPSymmetric = NO;
//        }
//    }
//    
//	// Drafts store the messages with a very minor set of headers and mime types
//    // not suitable for encrypted/signed messages. But fortunately, Mail.app doesn't
//    // have a problem if a normal message is stored as draft, so GPGMail just needs
//    // to disable the isDraft parameter, Mail.app will take care of the rest.
//    MCOutgoingMessage *outgoingMessage = [self MA_makeMessageWithContents:contents isDraft:NO shouldSign:shouldPGPSign shouldEncrypt:shouldPGPEncrypt || shouldPGPSymmetric shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
//	
//	// If there was an error creating the outgoing message it's gonna be nil
//    // and the error is stored away for later display.
//    if(!outgoingMessage) {
//		if (isDraft) {
//			// Cancel saving to prevent the default error message.
//			[self setIvar:@"cancelSaving" value:(id)kCFBooleanTrue];
//			
//            [(ComposeViewController *)[(ComposeBackEnd *)self delegate] _setUserSavedMessageAndPostNotification:NO];
//			
//			// The error message should be set on the current activity monitor, so we
//			// simply have to fetch it.
//			GM_CAST_CLASS(NSError *, id) error = (NSError *)[(MCActivityMonitor *)[MCActivityMonitor currentMonitor] error];
//			[self performSelectorOnMainThread:@selector(didCancelMessageDeliveryForError:) withObject:error waitUntilDone:NO];
//		}
//		// Restore the clean headers so BCC is removed as well.
//		[(ComposeBackEnd *)self setValue:[self getIvar:@"originalCleanHeaders"] forKey:@"_cleanHeaders"];
//        return nil;
//	}
//
//    // Fetch the encrypted data from the body data.
//    NSData *encryptedData = [((_MCOutgoingMimeBody *)[outgoingMessage mimeBody]) rawData];
//	
//
//	// Search for an errorCode in encryptedData:
//	NSRange range = [encryptedData rangeOfData:[gpgErrorIdentifier dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, [encryptedData length])];
//	if (range.length > 0) {
//		GPGErrorCode errorCode = 0;
//		char *readPos = (char *)[encryptedData bytes];
//		char *endPos = readPos + [encryptedData length];
//		
//		// Extract the errorCode.
//		readPos += range.location + range.length;
//		for (; readPos < endPos && *readPos <= '9' && *readPos >= '0'; readPos++) {
//			errorCode = errorCode * 10 + *readPos - '0';
//		}
//		
//		if (errorCode == GPGErrorCancelled) {
//			if (isDraft) {
//				// If the user cancel the signing, we cancel the saving and mark the message as unsaved.
//				[self setIvar:@"cancelSaving" value:(id)kCFBooleanTrue];
//				[(ComposeViewController *)[(ComposeBackEnd *)self delegate] _setUserSavedMessageAndPostNotification:NO];
//			}
//		}
//		[(ComposeBackEnd *)self setValue:[self getIvar:@"originalCleanHeaders"] forKey:@"_cleanHeaders"];
//		return nil;
//	}
//	
//    // And restore the original headers.
//    [(ComposeBackEnd *)self setValue:[self getIvar:@"originalCleanHeaders"] forKey:@"_cleanHeaders"];
//
//	
//	
//	BOOL attachKeys = shouldPGPSign && [[GPGOptions sharedOptions] boolForKey:@"AttachKeyToOutgoingMessages"];
//	NSData *keysToAttach = nil;
//
//	if (!shouldCreatePGPInlineMessage && attachKeys) {
//		// Get the signer key and export it, so we can attach it to the message.
//		GPGKey *key = [self getIvar:@"gpgKeyForSigning"];
//		if (key) {
//			GPGController *gpgc = [[GPGController alloc] init];
//			@try {
//				gpgc.useArmor = YES;
//				keysToAttach = [gpgc exportKeys:@[key] options:GPGExportMinimal];
//			}
//			@catch (NSException *exception) {
//				GPGDebugLog(@"Exception during exporting keys: %@", exception);
//			}
//		}
//
//	}
//		
//	
//    // Signing only results in an outgoing message which can be sent
//    // out exactly as created by Mail.app. No need to further modify.
//    // Only encrypted messages have to be adjusted.
//    if(shouldPGPSign && !shouldPGPEncrypt && !shouldPGPSymmetric && !shouldCreatePGPInlineMessage && keysToAttach.length == 0) {
//        if(!isDraft)
//            [GMSecurityHistory addEntryForSender:((ComposeBackEnd *)self).sender recipients:[((ComposeBackEnd *)self) allRecipients] securityMethod:GPGMAIL_SECURITY_METHOD_OPENPGP didSign:shouldPGPSign didEncrypt:shouldPGPEncrypt];
//        return outgoingMessage;
//    }
//
//	
//	
//    MCSubdata *newBodyData = nil;
//    
//	// Check for preferences here, and set mime or plain version
//    if(!shouldCreatePGPInlineMessage) {
//		
//		if (shouldPGPEncrypt || shouldPGPSymmetric) {
//			newBodyData = [self _newPGPBodyDataWithEncryptedData:encryptedData headers:[outgoingMessage headers] shouldBeMIME:YES keysToAttach:keysToAttach];
//		} else {
//			newBodyData = [self _newPGPBodyDataWithOriginalData:encryptedData headers:[outgoingMessage headers] keysToAttach:keysToAttach];
//		}
//    } else {
//        newBodyData = [self _newPGPInlineBodyDataWithData:[[contents.plainText string] dataUsingEncoding:NSUTF8StringEncoding] headers:[outgoingMessage headers] shouldSign:shouldPGPInlineSign shouldEncrypt:shouldPGPInlineEncrypt];
//    }
//
//	if (newBodyData) {
//		// AND NOW replace the current message body with the new gpg message body.
//		// The subdata contains the range of the actual body excluding the headers
//		// but references the entrie message (NSMutableData).
//		[(_MCOutgoingMimeBody *)[outgoingMessage mimeBody] setValue:newBodyData forKey:@"_rawData"];
//		// _rawData instance variable has to hold the NSMutableData which
//		// contains the data of the entire message including the header data.
//		// Not sure why it's done this way, but HECK it works!
//		[outgoingMessage setValue:[newBodyData valueForKey:@"_parentData"] forKey:@"_rawData"];
//	}
//    
//    if(!isDraft)
//        [GMSecurityHistory addEntryForSender:((ComposeBackEnd *)self).sender recipients:[((ComposeBackEnd *)self) allRecipients] securityMethod:GPGMAIL_SECURITY_METHOD_OPENPGP didSign:shouldPGPSign didEncrypt:shouldPGPEncrypt];
//    
//    return outgoingMessage;
}

- (NSAttributedString *)plainTextFixedForSigning:(NSMutableAttributedString *)plainText shouldAddNewLine:(BOOL)shouldAddNewLine {
    NSMutableString *plainString = [plainText mutableString];
    
    // If we are only signing and there isn't a newline at the end of the plaintext, append it.
    // We need this to prevent servers from doing this.
    if (shouldAddNewLine) {
        if ([plainString characterAtIndex:plainString.length - 1] != '\n') {
            [plainString appendString:@"\n"];
        }
    }
    
    // Remove all whitespaces at the end of lines. But don't kill attachments.
    RKRegex *regex = [RKRegex regexWithRegexString:@"[\\t\\f\\r\\p{Z}]+$" options:RKCompileMultiline];
    RKEnumerator *rkEnum = [plainString matchEnumeratorWithRegex:regex];
    
    NSMutableArray *ranges = [NSMutableArray array];
    
    // Get all matches and reverse the order.
    for (NSArray *match in rkEnum) {
        [ranges insertObject:match[0] atIndex:0];
    }
    // Removed matched characters.
    for (NSValue *range in ranges) {
        [plainString replaceCharactersInRange:range.rangeValue withString:@""];
    }
    
    // TODO: Fix and verify that the data is really transformed.
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
	// On Yosemite or higher there's a property to read the shouldDownloadRemoteAttachments flag.
	// otherwise, we have to access the _flags struct.
	BOOL shouldDownloadRemoteAttachments = NO;
	if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_9) {
		shouldDownloadRemoteAttachments = [[self valueForKey:@"_shouldDownloadRemoteAttachments"] boolValue];
	}
	else {
		mailFlags backEndFlags;
		Ivar flags = class_getInstanceVariable([self class], "_flags");
		
		CFTypeRef cfSelf = CFBridgingRetain(self);
		backEndFlags = *(mailFlags *)((uint8_t *)cfSelf + ivar_getOffset(flags));
		shouldDownloadRemoteAttachments = backEndFlags.shouldDownloadRemoteAttachments;
		CFBridgingRelease(cfSelf);
	}
	
	return shouldDownloadRemoteAttachments;
}

/**
 makeMessageWithContents:isDraft:shouldSign:shouldEncrypt:shouldSkipSignature:shouldBePlainText: sets the encrpyt and sign flags
 internal on the message write. For drafts however, these flags are not set, which leads to unencrypted, unsigned drafts.
 Our workaround forces drafts to be encrypted and/or signed by disabling the draft setting.
 The problem is, while that works for normal IMAP accounts, it doesn't for GMail, which creates a new message for each
 draft if "Store drafts on server" is activated.
 We hook into this message, to force the draft setting to be on for drafts, AFTER the encrypt and sign flags are set.
 This way, the messages remain actual drafts, and GMail is satisfied as well and behaves as it should.
 
 On Mavericks the method is called: newOutgoingMessageUsingWriter:contents:headers:isDraft:shouldBePlainText:
 On (Mountain)Lion the method is called: outgoingMessageUsingWriter:contents:headers:isDraft:shouldBePlainText:
 
 GMCodeInjector makes sure, that the correct method is overridden by our own.
 */
- (id)MAOutgoingMessageUsingWriter:(id)writer contents:(id)contents headers:(id)headers isDraft:(BOOL)isDraft shouldBePlainText:(BOOL)shouldBePlainText NS_RETURNS_RETAINED {
	if([contents ivarExists:@"IsDraft"])
		isDraft = [[contents getIvar:@"IsDraft"] boolValue];
	if([contents ivarExists:@"IsDraft"] && isDraft) {
		// Prevent hang on 10.10 when restoring drafts.
		// Mail on 10.10 needs the "x-apple-mail-remote-attachments" header in every draft mail.
		// See: https://gpgtools.lighthouseapp.com/projects/65764-gpgmail/tickets/871
		[headers setHeader:self.GMShouldDownloadRemoteAttachments ? @"YES" : @"NO" forKey:@"x-apple-mail-remote-attachments"];


		// Mail doesn't pass in the sign status, when saving a draft, so we have to get it ourselves.
		// For encrypt we also use the state of the button, shouldEncrypt is overriden by our own
		// logic to always encrypt drafts if possible.
        GMComposeMessagePreferredSecurityProperties *securityProperties = [self preferredSecurityProperties];
        BOOL shouldSign = securityProperties.shouldSignMessage;
		BOOL shouldEncrypt = securityProperties.shouldEncryptMessage;
		
        [headers setHeader:shouldEncrypt ? @"YES" : @"NO" forKey:@"x-should-pgp-encrypt"];
		[headers setHeader:shouldSign ? @"YES" : @"NO" forKey:@"x-should-pgp-sign"];
		
		// MailTags seems to duplicate our mail headers, if the message is to be encrypted.
		// This behaviour is worked around in [MCMessageGenerator _newDataForMimePart:withPartData:]
		// by removing the duplicate mail headers.
		// We should however only interfere, if a draft is being created, since this workaround might not be suitable
		// for every type of message.
		// In order for the MCMessageGenerator instance to know if a draft is being created,
		// we add a flag to it.
		[writer setIvar:@"IsDraft" value:@(YES)];

        // If a draft is being created which should be encrypted, but not encryptionCertificates are setup
        // on the writer, a fitting certificate is added at this point.
        BOOL userWantsDraftsEncrypted = [[GPGOptions sharedOptions] boolForKey:@"OptionallyEncryptDrafts"];
        id smimeLock = [self valueForKey:@"_smimeLock"];
        // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
        //
        // _smimeLock is no longer a simple object to be used with @synchronized but instead
        // a real NSLock.
        if([smimeLock isKindOfClass:[NSLock class]]) {
            @try {
                [smimeLock lock];
                [self GMConfigureEncryptionCertificatesForMessageGenerator:writer shouldEncryptDraft:userWantsDraftsEncrypted];
            }
            @catch(NSException *e) {}
            @finally {
                [smimeLock unlock];
            }
        }
        else {
            @synchronized (smimeLock) {
                [self GMConfigureEncryptionCertificatesForMessageGenerator:writer shouldEncryptDraft:userWantsDraftsEncrypted];
            }
        }
	}
	else {
		[headers removeHeaderForKey:@"x-should-pgp-encrypt"];
		[headers removeHeaderForKey:@"x-should-pgp-sign"];
	}
	return [self MAOutgoingMessageUsingWriter:writer contents:contents headers:headers isDraft:isDraft shouldBePlainText:shouldBePlainText];
}

- (void)GMConfigureEncryptionCertificatesForMessageGenerator:(MCMessageGenerator *)messageGenerator shouldEncryptDraft:(BOOL)shouldEncryptDraft {
    // In case the user doesn't want drafts encrypted, -[MCMessageGenerator encryptionCertificates] has
    // to be nil instead of an empty array.
    GMComposeMessagePreferredSecurityProperties *securityProperties = [self preferredSecurityProperties];
    NSMutableArray *keys = nil;
    GPGKey *encryptionKeyForDraft = nil;
    if(shouldEncryptDraft) {
        // Bug #951: GPGMail tries to encrypt draft even though no PGP key is available
        //
        // In case no PGP key is returned by -[GMComposeMessagePreferredSecurityProperties encryptionKeyForDraft],
        // the Mail's writer object is currently passed an empty array, which errorneously causes Mail to try to
        // encrypt the message even thogh no key is available.
        // In order to fix that, the array has to be niled
        encryptionKeyForDraft = [securityProperties encryptionKeyForDraft];
        if(encryptionKeyForDraft) {
            keys = [NSMutableArray arrayWithObject:encryptionKeyForDraft];
        }
    }
    // TODO: If userWantsDraftsEncrypted is enabled, but no appropriate key could be found
    // warn the user that draft is not going to be encrypted.
    [messageGenerator setEncryptionCertificates:[keys copy]];
}

- (void)didCancelMessageDeliveryForError:(NSError *)error {
    [(ComposeViewController *)[(ComposeBackEnd *)self delegate] backEnd:self didCancelMessageDeliveryForEncryptionError:error];
}

- (void)_addGPGFlaggedStringsToHeaders:(NSMutableDictionary *)headers forEncrypting:(BOOL)forEncrypting forSigning:(BOOL)forSigning forSymmetric:(BOOL)forSymmetric isDraft:(BOOL)isDraft {
	// To decide whether S/MIME or PGP operations should be performed on
	// the message, different headers have to be flagged.
	//
	// F̶o̶r̶ ̶s̶i̶g̶n̶i̶n̶g̶ Always:
	// * flag the "from" value with "gpgKey" = GPGKey.
	//
	// For encrypting:
	// * temporarily add the flagged sender ("recipientType" = "from") to the bcc recipients list,
	//   to encrypt for self, so each message can also be decrypted by the sender.
	//   (the "from" value is not inlucded in the recipients list passed to the encryption
	//    method)
	//   Also flag all bcc recipients with "recipientType" = "bcc".
	//
	// For symmetric:
	// * flag the "from" value with "symmetricEncrypt" = YES,
	//   if forEncrypting isn't set flag additionally with "doNotPublicEncrypt" = YES.
	//
	// Is draft:
	// * flag the "from" value with "isDraft" = YES.
	//

	
	GPGFlaggedString *flaggedString = [headers[@"from"] flaggedStringWithFlag:@"recipientType" value:@"from"];
	if (forSymmetric) {
		[flaggedString setValue:@YES forFlag:@"symmetricEncrypt"];
		if (!forEncrypting) {
			[flaggedString setValue:@YES forFlag:@"doNotPublicEncrypt"];
		}
	}
	GPGKey *key = [self getIvar:@"gpgKeyForSigning"];
	if (key) {
		[flaggedString setValue:key forFlag:@"gpgKey"];
	}

    if (isDraft) {
        [flaggedString setValue:@YES forFlag:@"isDraft"];
        // If this message is saved as draft, check if we have a gpg key which belongs to the
        // specified sender. If it's not available, try to find any secret key available.
        GPGKey *encryptDraftPublicKey = key.primaryKey;
        if(!encryptDraftPublicKey)
            encryptDraftPublicKey = [[GPGMailBundle sharedInstance] anyPersonalPublicKeyWithPreferenceAddress:[headers[@"from"] gpgNormalizedEmail]];
        // Store the appropriate public key to encrypt.
        if(encryptDraftPublicKey)
            [flaggedString setValue:encryptDraftPublicKey forFlag:@"DraftPublicKey"];
    }
	headers[@"from"] = flaggedString;
	
	// Save the original bcc recipients, to restore later.
	[self setIvar:@"originalBCCRecipients" value:[headers valueForKey:@"bcc"]];
    if (forEncrypting) {
        NSMutableArray *newBCCList = [NSMutableArray array];
        // Flag BCCs as bcc, so we can use hidden-recipient.
        NSArray *bccRecipients = [headers valueForKey:@"bcc"];
        for(NSString *bcc in bccRecipients)
            [newBCCList addObject:[bcc flaggedStringWithFlag:@"recipientType" value:@"bcc"]];

        [newBCCList addObject:flaggedString];
        [headers setValue:newBCCList forKey:@"bcc"];
    }
}

- (MCSubdata *)_newPGPBodyDataWithOriginalData:(NSData *)originalData headers:(MCMutableMessageHeaders *)headers keysToAttach:(NSData *)keysToAttach {
	
	if (keysToAttach.length == 0 || originalData.length < 100) {
		// If originalData's length < 100: No boundarys! (Should never happen)
		return nil;
	}
	

	// Find the MIME boundary.
	NSData *start = [NSData dataWithBytes:"\n--" length:3];
	NSData *end = [NSData dataWithBytes:"--\n" length:3];
	
	NSRange searchRange = NSMakeRange(originalData.length - 30, 30);
	NSRange endRange = [originalData rangeOfData:end options:NSDataSearchBackwards range:searchRange];
	if (endRange.length == 0) {
		return nil;
	}
	
	searchRange = NSMakeRange(endRange.location - 70, 70);
	NSRange startRange = [originalData rangeOfData:start options:NSDataSearchBackwards range:searchRange];
	if (startRange.length == 0) {
		return nil;
	}
	
	searchRange.location = startRange.location;
	searchRange.length = endRange.location + 3 - searchRange.location;
	
	NSData *bounddary = [originalData subdataWithRange:searchRange];
	
	
	// Build the message.
	NSData *headerData = [headers encodedHeaders];
	
	NSMutableData *mutableBodyData = [NSMutableData data];
	[mutableBodyData appendData:headerData];
	[mutableBodyData appendData:[originalData subdataWithRange:NSMakeRange(0, endRange.location)]];
	[mutableBodyData appendBytes:"\nContent-Transfer-Encoding: 7bit\nContent-Type: application/pgp-keys\n\n" length:69];
	[mutableBodyData appendData:keysToAttach];
	[mutableBodyData appendData:bounddary];
	
	
	NSRange contentRange = NSMakeRange(headerData.length, mutableBodyData.length - headerData.length);
	MCSubdata *contentSubdata = [[GM_MAIL_CLASS(@"Subdata") alloc] initWithParent:mutableBodyData range:contentRange];
	
	return contentSubdata;
	
}

- (MCSubdata *)_newPGPBodyDataWithEncryptedData:(NSData *)encryptedData headers:(MCMutableMessageHeaders *)headers shouldBeMIME:(BOOL)shouldBeMIME keysToAttach:(NSData *)keysToAttach {
    // Now on to creating a new body and replacing the old one.
    // TODO: Figure out how to create a mime boundary in Sierra!
    //NSString *boundary = (NSString *)[GM_MAIL_CLASS(@"MimeBody") newMimeBoundary];
    NSString *boundary = [NSString stringWithFormat:@"Apple-Mail=_%@", [[NSUUID new] UUIDString]];
    NSData *topData;
    NSData *versionData;
    MCMimePart *topPart;
    MCMimePart *versionPart;
    MCMimePart *dataPart;
    MCMimePart *keysPart;
	
    Class MimePart = GM_MAIL_CLASS(@"MimePart");
    
    if(!shouldBeMIME) {
        topPart = [[MimePart alloc] init];
        [topPart setType:@"text"];
        [topPart setSubtype:@"plain"];
        topPart.contentTransferEncoding = @"8bit";
        [topPart setBodyParameter:@"utf8" forKey:@"charset"];
        topData = encryptedData;
    }
    else {
        // 1. Create the top level part.
        topPart = [[MimePart alloc] init];
        [topPart setType:@"multipart"];
        [topPart setSubtype:@"encrypted"];
        [topPart setBodyParameter:@"application/pgp-encrypted" forKey:@"protocol"];
        // It's extremely important to set the boundaries for the parts
        // that need them, otherwise the body data will not be properly generated
        // by appendDataForMimePart.
        [topPart setBodyParameter:boundary forKey:@"boundary"];
        topPart.contentTransferEncoding = @"7bit";
        // 2. Create the first subpart - the version.
        versionPart = [[MimePart alloc] init];
        [versionPart setType:@"application"];
        [versionPart setSubtype:@"pgp-encrypted"];
        [versionPart setContentDescription:@"PGP/MIME Versions Identification"];
        versionPart.contentTransferEncoding = @"7bit";
        // 3. Create the pgp data subpart.
        dataPart = [[MimePart alloc] init];
        [dataPart setType:@"application"];
        [dataPart setSubtype:@"octet-stream"];
        [dataPart setBodyParameter:@"encrypted.asc" forKey:@"name"];
        dataPart.contentTransferEncoding = @"7bit";
        [dataPart setDisposition:@"inline"];
        [dataPart setDispositionParameter:@"encrypted.asc" forKey:@"filename"];
        [dataPart setContentDescription:@"OpenPGP encrypted message"];		
        // 5. Append both parts to the top level part.
        [topPart addSubpart:versionPart];
        [topPart addSubpart:dataPart];
		
		
		// 6. Optionally attch the OpenPGP key(s).
		if (keysToAttach.length > 0) {
			keysPart = [[MimePart alloc] init];
			[keysPart setType:@"application"];
			[keysPart setSubtype:@"pgp-keys"];

			[topPart addSubpart:keysPart];
		}
		
		

        // Again Mail.app will do the heavy lifting for us, only thing we need to do
        // is create a map of mime parts and body data.
        // The problem with that is, mime part can't be used a as a key with
        // a normal NSDictionary, since that wants to copy all keys.
        // So instad we use a CFDictionary which only retains keys.
        versionData = [@"Version: 1\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        topData = [@"This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)" dataUsingEncoding:NSASCIIStringEncoding];
    }

    CFMutableDictionaryRef partBodyMapRef = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    CFDictionaryAddValue(partBodyMapRef, (__bridge const void *)(topPart), (__bridge const void *)(topData));
    if(shouldBeMIME) {
        CFDictionaryAddValue(partBodyMapRef, (__bridge const void *)(versionPart), (__bridge const void *)(versionData));
        CFDictionaryAddValue(partBodyMapRef, (__bridge const void *)(dataPart), (__bridge const void *)(encryptedData));
		if (keysToAttach.length > 0) CFDictionaryAddValue(partBodyMapRef, (__bridge const void *)(keysPart), (__bridge const void *)(keysToAttach));
    }

    NSMutableDictionary *partBodyMap = (__bridge NSMutableDictionary *)partBodyMapRef;
    // The body is done, now on to updating the headers since we'll use the original headers
    // but have to change the top part headers.
    // And also add our own special GPGMail header.
    // Create the new top part headers.
    NSMutableData *contentTypeData = [[NSMutableData alloc] initWithLength:0];
    [contentTypeData appendData:[[NSString stringWithFormat:@"%@/%@;", [topPart type], [topPart subtype]] dataUsingEncoding:NSASCIIStringEncoding]];
    for(id key in [topPart bodyParameterKeys])
        [contentTypeData appendData:[[NSString stringWithFormat:@"\n\t%@=\"%@\";", key, [topPart bodyParameterForKey:key]] dataUsingEncoding:NSASCIIStringEncoding]];
    [headers setHeader:contentTypeData forKey:@"content-type"];
    [headers setHeader:@"7bit" forKey:@"content-transfer-encoding"];
    [headers removeHeaderForKey:@"content-disposition"];
    [headers removeHeaderForKey:@"from "];

	// Set the original bcc recipients.
    NSArray *originalBCCRecipients = (NSArray *)[self getIvar:@"originalBCCRecipients"];
    if([originalBCCRecipients count])
        [headers setHeader:originalBCCRecipients forKey:@"bcc"];
	else
        [headers removeHeaderForKey:@"bcc"];
    // Create the actualy body data.
    NSData *headerData = [headers encodedHeaders];
    NSMutableData *bodyData = [[NSMutableData alloc] init];
    // First add the header data.
    [bodyData appendData:headerData];
    // Now the mime parts.
    MCMessageGenerator *messageWriter = [[GM_MAIL_CLASS(@"MCMessageGenerator") alloc] init];
    [messageWriter appendDataForMimePart:topPart toData:bodyData withPartData:partBodyMap];
    CFRelease(partBodyMapRef);
    // Contains the range, which separates the mail headers
    // from the actual mime content.
    // JUST FOR INFO: messageDataIncludingFromSpace: returns an instance of NSMutableData, so basically
    // it might be the same as _rawData. But we don't need that, so, that's alright.
    NSRange contentRange = NSMakeRange([headerData length],
                                       ([bodyData length] - [headerData length]));
    MCSubdata *contentSubdata = [[GM_MAIL_CLASS(@"Subdata") alloc] initWithParent:bodyData range:contentRange];
    return contentSubdata;
}

- (MCSubdata *)_newPGPInlineBodyDataWithData:(NSData *)data headers:(MCMutableMessageHeaders *)headers shouldSign:(BOOL)shouldSign shouldEncrypt:(BOOL)shouldEncrypt {
    if (!data)
        return nil;
    // Now on to creating a new body and replacing the old one. 
    NSData *topData = nil;
    MCMimePart *topPart;
    
    NSData *signedData = data;
    NSData *encryptedData = nil;
    
	Class MimePart = [GPGMailBundle resolveMailClassFromName:@"MimePart"];
	
    topPart = [[MimePart alloc] init];
    [topPart setValue:@"text" forKey:@"type"];
    [topPart setSubtype:@"plain"];
    [topPart setContentTransferEncoding:@"8bit"];
    [topPart setBodyParameter:@"utf8" forKey:@"charset"];
    
    if(shouldSign) {
        signedData = [(MimePart_GPGMail *)topPart inlineSignedDataForData:data sender:[headers firstAddressForKey:@"from"]];
        if (!signedData) {
            return nil;
        }
        topData = signedData;
    }

    id newlyEncryptedPart = nil;
    if(shouldEncrypt) {
        NSMutableArray *recipients = [[NSMutableArray alloc] init];
        [recipients addObjectsFromArray:[headers addressListForKey:@"to"]];
        [recipients addObjectsFromArray:[headers addressListForKey:@"cc"]];
        [recipients addObjectsFromArray:[headers addressListForKey:@"bcc"]];
#warning TODO: Figure out how to implement this in Sierra!
        //newEncryptedPartWithData:(id)arg1 certificates:(id)arg2 encryptedData:(id *)arg3;
        // newlyEncryptedPart = [topPart newEncryptedPartWithData:signedData recipients:recipients encryptedData:&encryptedData];
        topData = encryptedData;
    }

    if(!topData) {
        return nil;
    }
    
    // The body is done, now on to updating the headers since we'll use the original headers
    // but have to change the top part headers.
    // And also add our own special GPGMail header.
    // Create the new top part headers.
    NSMutableData *contentTypeData = [[NSMutableData alloc] initWithLength:0];
    NSString *topType = [topPart valueForKey:@"type"];
	NSString *topSubtype = [topPart valueForKey:@"subtype"];
	
	[contentTypeData appendData:[[NSString stringWithFormat:@"%@/%@;", topType, topSubtype] dataUsingEncoding:NSASCIIStringEncoding]];
    for(id key in [topPart bodyParameterKeys])
        [contentTypeData appendData:[[NSString stringWithFormat:@"\n\t%@=\"%@\";", key, [topPart bodyParameterForKey:key]] dataUsingEncoding:NSASCIIStringEncoding]];
    [headers setHeader:contentTypeData forKey:@"content-type"];
    [headers setHeader:[topPart contentTransferEncoding] forKey:@"content-transfer-encoding"];
    [headers removeHeaderForKey:@"content-disposition"];
    [headers removeHeaderForKey:@"from "];	
	
	// Set the original bcc recipients.
    NSArray *originalBCCRecipients = (NSArray *)[self getIvar:@"originalBCCRecipients"];
    if([originalBCCRecipients count])
        [headers setHeader:originalBCCRecipients forKey:@"bcc"];
	else
        [headers removeHeaderForKey:@"bcc"];
    // Create the actualy body data.
    NSData *headerData = [headers encodedHeaders];
    NSMutableData *bodyData = [[NSMutableData alloc] init];
    // First add the header data.
    [bodyData appendData:headerData];
    [bodyData appendData:topData];
    // Contains the range, which separates the mail headers
    // from the actual mime content.
    // JUST FOR INFO: messageDataIncludingFromSpace: returns an instance of NSMutableData, so basically
    // it might be the same as _rawData. But we don't need that, so, that's alright.
    NSRange contentRange = NSMakeRange([headerData length], 
                                       ([bodyData length] - [headerData length]));
    MCSubdata *contentSubdata = [[GM_MAIL_CLASS(@"Subdata") alloc] initWithParent:bodyData range:contentRange];
    return contentSubdata;
}

- (id)MARecipientsThatHaveNoKeyForEncryption {
    if(![((ComposeBackEnd *)self) delegate])
		return [NSArray array];
	
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    id smimeLock = [self valueForKey:@"_smimeLock"];
    NSMutableArray *nonEligibleRecipients = [NSMutableArray array];
    if([smimeLock isKindOfClass:[NSLock class]]) {
        @try {
            [smimeLock lock];
            nonEligibleRecipients = [self _GMRecipientsThatHaveNoKeyForEncryption];
        }
        @catch(NSException *e) {}
        @finally {
            [smimeLock unlock];
        }
    }
    else {
        @synchronized(smimeLock) {
            nonEligibleRecipients = [self _GMRecipientsThatHaveNoKeyForEncryption];
        }
    }

    return nonEligibleRecipients;
}

- (id)_GMRecipientsThatHaveNoKeyForEncryption {
    NSMutableArray *nonEligibleRecipients = [NSMutableArray array];

    GPGMAIL_SECURITY_METHOD securityMethod = self.preferredSecurityProperties.securityMethod;
    BOOL isSMIME = securityMethod == GPGMAIL_SECURITY_METHOD_SMIME;
    // Bug #961: Deadlock when using S/MIME and trying to toggle encryption state of a message on macOS 10.13
    //
    // -[ComposeBackEnd recipientsThatHaveNoKeyForEncryption] uses the smimeLock internally.
    // Since the calling method of _GMRecipientsThatHaveNoKeyForEncryption already uses the smimeLock,
    // a deadlock is triggered when calling the original mail method.
    //
    // Since the code for checking for missing S/MIME certificates is by now almost identical to the
    // check performed for OpenPGP keys, there's no need to call into the original mail method anymore.
    for(NSString *recipient in [((ComposeBackEnd *)self) allRecipients]) {
        // For Apple's S/MIME implementation it's important that the full recipient matches the certificate.
        // For OpenPGP the email address of the recipient suffices.
        NSString *recipientAddress = isSMIME ? recipient : [recipient gpgNormalizedEmail];
        NSDictionary *encryptionCertificates = [self valueForKey:@"_encryptionCertificates"];
        if(!encryptionCertificates[recipientAddress] || encryptionCertificates[recipientAddress] == [NSNull null]) {
            [nonEligibleRecipients addObject:recipient];
        }
    }

    return nonEligibleRecipients;
}

- (BOOL)messageIsBeingReplied {
    // 1 = Reply
    // 2 = Reply to all.
    // 3 = Forward.
    // 4 = Restored Reply window.
    NSInteger type = [(ComposeBackEnd *)self type];
    return (type == 1 || type == 2 || type == 4) && ![self draftIsContinued];
}

- (BOOL)messageIsBeingForwarded {
    NSInteger type = [MAIL_SELF type];
    return type == 3 && ![self draftIsContinued];
}


- (BOOL)draftIsContinued {
    MCMessageHeaders *headers = [MAIL_SELF originalMessageHeaders];
    BOOL draftIsContinued = [headers firstHeaderForKey:@"x-should-pgp-sign"] != nil || [headers firstHeaderForKey:@"x-should-pgp-encrypt"] != nil;
    return draftIsContinued;
}

- (BOOL)MA_saveThreadShouldCancel {
	if ([[self getIvar:@"cancelSaving"] boolValue]) {
		[self setIvar:@"cancelSaving" value:(id)kCFBooleanFalse];
		return YES;
	}
	return [self MA_saveThreadShouldCancel];
}

- (GMComposeMessagePreferredSecurityProperties *)preferredSecurityProperties {
    GMComposeMessagePreferredSecurityProperties *securityProperties = nil;
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    securityProperties = [self getIvar:kComposeBackEndPreferredSecurityPropertiesKey];

    return securityProperties;
}

- (void)setPreferredSecurityProperties:(GMComposeMessagePreferredSecurityProperties *)preferredSecurityProperties {
    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    //
    // _smimeLock is no longer a simple object to be used with @synchronized but instead
    // a real NSLock.
    [self setIvar:kComposeBackEndPreferredSecurityPropertiesKey value:preferredSecurityProperties];
}

// TODO: Possibly remove later. only for testing
- (void)MAUpdateSMIMEStatus:(void(^)(void))onComplete {
    // Re-Implementation of Mail's updateSMIMEStatus.
    // updateSMIMEStatus is invoked by updateSecurityControls, which is responsible for any UI updates.
    // If we're *not* on the main thread, we let Mail handle the logging of the error.
    if(![NSThread isMainThread]) {
        [self MAUpdateSMIMEStatus:onComplete];
        return;
    }
    [MAIL_SELF setDefaultSenderIfNeeded];
    NSString *sender = nil;
//    if([MAIL_SELF respondsToSelector:@selector(senderWithValidation:)]) {
//        sender = [MAIL_SELF senderWithValidation:YES];
//    }
//    else {
        sender = [MAIL_SELF sender];
//    }
    NSArray *recipients = [MAIL_SELF allRecipients];
    if(sender) {
        recipients = [recipients arrayByAddingObject:sender];
    }
    
    NSOperationQueue *smimeQueue = [MAIL_SELF smimeQueue];
    [smimeQueue cancelAllOperations];
    [smimeQueue addOperationWithBlock:^{
        void (^checkCertificates)(void) = ^{
            NSMutableDictionary *signingIdentitiesMap = [self valueForKey:@"_signingIdentities"];
            // Remove signing identities not matching the current sender.
            NSSet *signingIdentities = [signingIdentitiesMap keysOfEntriesPassingTest:^BOOL(id key, __unused id obj, __unused BOOL *stop) {
                return ![key isEqual:sender];
            }];
            [signingIdentitiesMap removeObjectsForKeys:[signingIdentities allObjects]];
            
            // Remove encryption certificates not matching the current recipients.
            NSMutableDictionary *encryptionCertificatesMap = [self valueForKey:@"_encryptionCertificates"];
            NSSet *encryptionCertificates = [encryptionCertificatesMap keysOfEntriesPassingTest:^BOOL(id key, __unused id obj, __unused BOOL *stop) {
                return ![recipients containsObject:key];
            }];
            [encryptionCertificatesMap removeObjectsForKeys:[encryptionCertificates allObjects]];
            
            // If there are already preferredSecurityProperties determined, copy the userShouldSignMessage and
            // userShouldEncryptMessage on to the new security properties.
            GMComposeMessagePreferredSecurityProperties *currentSecurityProperties = self.preferredSecurityProperties;
            GPGKey *signingKey = [currentSecurityProperties.signingSender isEqualToString:sender] ? currentSecurityProperties.signingKey : nil;
            GMComposeMessagePreferredSecurityProperties *preferredSecurityProperties = [[GMComposeMessagePreferredSecurityProperties alloc] initWithSender:sender signingKey:signingKey invalidSigningIdentityError:currentSecurityProperties.invalidSigningIdentityError recipients:recipients userShouldSignMessage:currentSecurityProperties ? currentSecurityProperties.userShouldSignMessage : ThreeStateBooleanUndetermined userShouldEncryptMessage:currentSecurityProperties ? currentSecurityProperties.userShouldEncryptMessage : ThreeStateBooleanUndetermined];
            preferredSecurityProperties.cachedSigningIdentities = [self valueForKey:@"_signingIdentities"];
            preferredSecurityProperties.cachedEncryptionCertificates = [self valueForKey:@"_encryptionCertificates"];
            
            [preferredSecurityProperties addHintsFromBackEnd:self];
            [preferredSecurityProperties computePreferredSecurityPropertiesForSecurityMethod:currentSecurityProperties.securityMethod];
            
            [MAIL_SELF setCanSign:preferredSecurityProperties.canSign];
            [MAIL_SELF setCanEncrypt:preferredSecurityProperties.canEncrypt];
            [self setValue:[preferredSecurityProperties.cachedSigningIdentities mutableCopy] forKey:@"_signingIdentities"];
            [self setValue:[preferredSecurityProperties.cachedEncryptionCertificates mutableCopy] forKey:@"_encryptionCertificates"];
            if([MAIL_SELF respondsToSelector:@selector(setInvalidSigningIdentityError:)]) {
                [MAIL_SELF setInvalidSigningIdentityError:preferredSecurityProperties.invalidSigningIdentityError];
            }

            self.preferredSecurityProperties = preferredSecurityProperties;
        };

        id smimeLock = [self valueForKey:@"_smimeLock"];
        // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
        //
        // _smimeLock is no longer a simple object to be used with @synchronized but instead
        // a real NSLock.
        if([smimeLock isKindOfClass:[NSLock class]]) {
            @try {
                [smimeLock lock];
                checkCertificates();
            }
            @catch(NSException *e) {}
            @finally {
                [smimeLock unlock];
            }
        }
        else {
            @synchronized(smimeLock) {
                checkCertificates();
            }
        }
        
        // We have our certificate information, now onto running the UI code.
        if(onComplete) {
            onComplete();
        }
            
// TODO: ORIGINAL IMPLEMENTATION: MAYBE REMOVED LATER.
//            BOOL canSign = YES;
//            if(sender) {
//                id signingIdentity = signingIdentitiesMap[sender];
//                if(signingIdentity) {
//                    canSign = signingIdentity != [NSNull null];
//                }
//                else {
//                    signingIdentity = [MCKeychainManager copySigningIdentityForAddress:sender];
//                    if(signingIdentity) {
//                        signingIdentitiesMap[sender] = signingIdentity;
//                        // Mail internally doesn't set canSign to YES in this case, which is quite strange.
//                    }
//                    else {
//                        signingIdentitiesMap[sender] = [NSNull null];
//                        canSign = NO;
//                    }
//                }
//            }
//            [MAIL_SELF setCanSign:canSign];
//            // S/MIME only allows to encrypt message, if a signing key is available as well.
//            // There's no such restriction in PGP, so we'll later modify this part to check
//            // for encryption certificates in any case.
//            if(canSign) {
//                BOOL canEncrypt = [recipients count] ? YES : NO;
//                for(id recipient in recipients) {
//                    id certificate = encryptionCertificatesMap[recipient];
//                    if(certificate) {
//                        if(certificate == [NSNull null]) {
//                            canEncrypt = NO;
//                        }
//                    }
//                    else {
//                        certificate = [MCKeychainManager copyEncryptionCertificateForAddress:recipient];
//                        if(certificate) {
//                            encryptionCertificatesMap[recipient] = certificate;
//                        }
//                        else {
//                            encryptionCertificatesMap[recipient] = [NSNull null];
//                            canEncrypt = NO;
//                        }
//                    }
//                }
//                [MAIL_SELF setCanEncrypt:canEncrypt];
//            }
//            else {
//                [MAIL_SELF setCanEncrypt:NO];
//            }
//        }
//        // We have our certificate information, now onto running the UI code.
//        if(onComplete) {
//            onComplete();
//        }
    }];
    
    // Note: canSign is set to YES by default.
    // Based on debugging information the default value for canSign is YES.
    // Assembly for this instruction is
    // 00000001000fa70b         setne      bl
    // Hoper says:
    // rbx = COND_BYTE_SET(NE)
    // The value effectively assigned to rbx depends on whether or not the zero flag is set.
    // If it's not set, rbx will be YES otherwise NO. In this case, the zero flag is not set.
    // It can be read out the zeroflag using:
    // lldb$ register read $rflags & 0x40.
    // It can be manipulated by running:
    // lldb$ register write rflags `$rflags|0x40`
}

- (void)MA_generateParsedMessageFromOriginalMessages {
    // It's necessary to tell GPGMal that the whole body is required in preparation
    // for a reply and that its allowed to decrypt the content, if necessary.
    [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey];
    [self MA_generateParsedMessageFromOriginalMessages];
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:kLibraryMimeBodyReturnCompleteBodyDataForComposeBackendKey];
}

@end

#undef MAIL_SELF
