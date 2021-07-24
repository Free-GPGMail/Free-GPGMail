/* ConversationMember+GPGMail.m created by Lukas Pitschl (@lukele) on Thu 18-Oct-2013 */

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

#import "ConversationMember+GPGMail.h"
#import "CCLog.h"
#import "NSObject+LPDynamicIvars.h"
#import "MCMessage.h"
#import "Message+GPGMail.h"
#import "GMMessageSecurityFeatures.h"
#import "MUIWebDocument.h"
#import "MCMessageHeaders.h"

#define MAIL_SELF ((ConversationMember *)self)

extern NSString * const kMessageSecurityFeaturesKey;
extern NSString * const kGMComposeMessagePreferredSecurityPropertiesHeaderKeyReferenceMessageEncrypted;

@interface MUIWebDocument (macOS_10_14_1)

- (void)setHasBlockedMessageContent:(BOOL)has;
- (void)setMessageContentTypeToBlock:(long)contentType;

@end

@implementation ConversationMember_GPGMail

- (void)MA_reloadSecurityProperties {
    // TODO: If still necessary, re-implement using security features.
    [self MA_reloadSecurityProperties];
    return;
//    /* Doesn't seem to be used under Yosemite. */
//    MCMessage *message = [(ConversationMember *)self originalMessage];
//    if(((Message_GPGMail *)message).PGPSigned || ((Message_GPGMail *)message).PGPEncrypted) {
//        [self setIsEncrypted:((Message_GPGMail *)message).PGPEncrypted];
//        [self setIsSigned:((Message_GPGMail *)message).PGPSigned];
//        [self setSigners:((Message_GPGMail *)message).PGPSignatures];
//        [self setSignerNames:[((Message_GPGMail *)message) PGPSignatureLabels]];
//        return;
//    }
    
//    [self MA_reloadSecurityProperties];
}

- (long long)MAMessageContentBlockingReason {
	// Bug #981: Prevent Mail from loading any remote content if a message is encrypted
    //
	// Update 2021-07-05
	// -----------------
	// In an older version of GPG Mail the remote content blocking was handled
	// in -[ConversationMember setWebDocument:] by adjusting the values of
	// -[WebDocument messageContentTypeToBlock] and -[WebDocument hasBlockedMessageContent].
	//
	// Further investigation why remote content blocking didn't always work
	// reliably on macOS Big Sur (#1086), revealed however that the most important
	// deciding factor is the content blocking reason which renders the other values
	// obsolete.
	//
	// To make sure that the user is never able to manually allow the remote content to
	// be loaded, the banner responsible for that is always hidden. Have a look at
	// LoadBlockedMessageContentBannerViewController.
	//
	// Original description
	// --------------------
    // A maliciously crafted email could otherwise exploit an error in Apple's mime parser
    // to exfiltrate the decrypted content, by using a non-closed HTML tag (for example img)
    // which is started in one mime part and continued in a different one, with a PGP/MIME
    // tree in between.
    // Once each mime part is processed, the single parts are concatenated and the decrypted
    // contents sent to the URL given in the img tag.
    // For more details see https://efail.de
    //
    // Mail internally calls updateBlockRemoteContent, which should already make sure
    // that remote content is blocked if -[MCMessageBody isEncrypted] returns YES. While
    // that should be the case for PGP messages already, re-check here.
    //
    // == NOTE FOR FUTURE LUKAS ==
    // In High Sierra, even if -[MUIWebDocument setBlockRemoteContent:YES] is called,
    // and remote content is available, the "load remote content" banner or the message
    // that remote content is available is not always displayed. After countless hours
    // of debugging it turns out that, remote content is cached by Mail or a
    // com.apple.WebKit.WebContent process invoked by Mail to display the mail contents,
    // which results in the following problematic behavior:
    //
    // 1.) If remote content was loaded once (even if in a different message) and was
    //     cached, each message which contains the same remote content (for example image)
    //     will display the image, regardless of whether the users allow to display
    //     remote content or not.
    // 2.) If all remote content of a message has already been cached,
    //     -[MUIWebDocument hasBlockedRemoteContent] might return NO, even if the user chose
    //     to block remote content and remote content is available in the message.
    //     It might however also return YES, if the document was rendered in a different
    //     com.apple.WebKit.WebContent process than the one, responsible for loading the
    //     remote content at first try.
    // 3.) The banner alerting users of the existence of remote content in a message
    //     and asking them if they want to load the remote content, relies upon
    //     -[MUIWebDocument hasBlockedRemoteContent] and will thus sometimes be displayed
    //     and sometimes not, based on the cache status of the remote content to be displayed.
    //
    // So Lukas, no, you were not losing your mind, Apple simply tried to fuck with you.
    // Lucky for us, since we don't want the load remote content banner to be displayed
    // for encrypted messages at all, we don't have to care about its faulty behavior,
    // but simply make sure, it is not displayed for encrypted messages.

    // On 10.14.1 this method is checked in order to determine if
    // the user has actively decided to load remote content.
    // Since for encrypted messages GPG Mail doesn't allow that,
    // return the appropriate value based on running OS (5 for macOS Big Sur, 4 for others).
    GMMessageSecurityFeatures *securityFeatures = [(Message_GPGMail *)[MAIL_SELF originalMessage] securityFeatures];
	// If a draft is continued, the original message is no longer pointing to the message
	// being replied to, but to the draft message which itself may or may not be encrypted
	// but doesn't tell the status of the original message. That status is however stored
	// in the draft header key x-gm-reference-encrypted.
	BOOL referenceMessageIsEncrypted = [[(MCMessageHeaders *)[[MAIL_SELF originalMessage] headersFetchIfNotAvailable:NO] firstHeaderForKey:kGMComposeMessagePreferredSecurityPropertiesHeaderKeyReferenceMessageEncrypted] boolValue];
	BOOL isEncrypted = securityFeatures.PGPEncrypted || securityFeatures.PGPPartlyEncrypted || referenceMessageIsEncrypted;
	NSUInteger blockingReason = [self MAMessageContentBlockingReason];
	DebugLog(@"Content blocking reason: %lld", [self MAMessageContentBlockingReason]);

    if(!isEncrypted) {
		DebugLog(@"Message is *not* encrypted - let Mail decide.");
		return blockingReason;
	}

	DebugLog(@"Message is encrypted - prevent remote content loading.");
	// Bug #1086: On Big Sur, under some circumstances remote content is loaded when it shouldn't
	//
	// It appears that before adjusting the blocking reason, remote content would be loaded
	// if the same content was already loaded in a non-encrypted message and as such
	// was already available in the cache.
	// By using blocking reason 5 on Big Sur, it behaves as if remote content loading was
	// disabled completely in `Mail › Preferences › Viewing`.
	if(@available(macOS 10.16, *)) {
		blockingReason = 5;
	}
	else {
		blockingReason = 4;
	}

    return blockingReason;
}

@end

#undef MAIL_SELF
