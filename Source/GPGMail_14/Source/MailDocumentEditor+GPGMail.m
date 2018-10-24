/* MailDocumentEditor+GPGMail.m re-created by Lukas Pitschl (@lukele) on Sat 27-Aug-2011 */

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

#import <Libmacgpg/Libmacgpg.h>
#import "NSObject+LPDynamicIvars.h"
#import <MFMailAccount.h>
#import <HeadersEditor.h>
#import "ComposeBackEnd.h"
//#import <MailDocumentEditor.h>
//#import <MailNotificationCenter.h>
#import "GMSecurityMethodAccessoryView.h"
#import "NSWindow+GPGMail.h"
#import "Message+GPGMail.h"
#import "HeadersEditor+GPGMail.h"
#import "MailDocumentEditor+GPGMail.h"
#import "ComposeBackEnd+GPGMail.h"
#import "GPGMailBundle.h"
//#import <MFError.h>
#import "ComposeWindowController+GPGMail.h"
#import "ComposeViewController.h"
#import "ComposeWindowController.h"
#import "GMMessageSecurityFeatures.h"

#import "GMComposeMessagePreferredSecurityProperties.h"

static const NSString *kUnencryptedReplyToEncryptedMessage = @"unencryptedReplyToEncryptedMessage";
extern const NSString *kComposeWindowControllerAllowWindowTearDown;

#define MAIL_SELF(object) ((ComposeViewController *)(object))

@implementation MailDocumentEditor_GPGMail

- (void)didExitFullScreen:(NSNotification *)notification {
    [self performSelectorOnMainThread:@selector(configureSecurityMethodAccessoryViewForNormalMode) withObject:nil waitUntilDone:NO];
}

- (void)configureSecurityMethodAccessoryViewForNormalMode {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return;
    }
	GMSecurityMethodAccessoryView *accessoryView = [self securityMethodAccessoryView]; //[self getIvar:@"SecurityMethodHintAccessoryView"];
    [accessoryView configureForWindow:[self valueForKey:@"_window"]];
}

- (void)setSecurityMethodAccessoryView:(GMSecurityMethodAccessoryView *)securityMethodAccessoryView {
	[self setIvar:@"SecurityMethodAccessoryView" value:securityMethodAccessoryView];
}

- (GMSecurityMethodAccessoryView *)securityMethodAccessoryView {
	return (GMSecurityMethodAccessoryView *)[(NSObject *)[MAIL_SELF(self) delegate] getIvar:@"SecurityMethodAccessoryView"];
}

- (void)updateSecurityMethodHighlight {
    [self updateSecurityMethodAccessoryView];
}

- (void)updateSecurityMethodAccessoryView {
    GMSecurityMethodAccessoryView *accessoryView = [self securityMethodAccessoryView];
    GMComposeMessagePreferredSecurityProperties *securityProperties = ((ComposeBackEnd_GPGMail *)MAIL_SELF(self).backEnd).preferredSecurityProperties;
    
    // Once the security method has been set by the user, it MUST never be changed.
    if(securityProperties.userDidChooseSecurityMethod != YES && accessoryView.previousSecurityMethod != securityProperties.securityMethod) {
        accessoryView.securityMethod = securityProperties.securityMethod;
    }
    accessoryView.active = securityProperties.shouldSignMessage || securityProperties.shouldEncryptMessage;
    
    // TODO: Re-implement the update of the from field somewhere else. The accessory view has nothing to do with it.
}

- (void)updateSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod {
    GMSecurityMethodAccessoryView *accessoryView = [self securityMethodAccessoryView];
    accessoryView.securityMethod = securityMethod;
}

- (void)MABackEndDidLoadInitialContent:(id)content {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        [self MABackEndDidLoadInitialContent:content];
        return;
    }
	if(![GPGMailBundle isElCapitan]) {
		[(NSNotificationCenter *)[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didExitFullScreen:) name:@"NSWindowDidExitFullScreenNotification" object:nil];
	}
	
	// Setup security method hint accessory view in top right corner of the window.
	[self setupSecurityMethodHintAccessoryView];

    ComposeBackEnd *backEnd = MAIL_SELF(self).backEnd;
    GPGMAIL_SECURITY_METHOD securityMethod = ((ComposeBackEnd_GPGMail *)MAIL_SELF(self).backEnd).preferredSecurityProperties.securityMethod;
    [self updateSecurityMethod:securityMethod];

    [self MABackEndDidLoadInitialContent:content];
}

- (void)setupSecurityMethodHintAccessoryView {
	// On El Capitan there's no more space on top of the title bar, so
	// the security method accessory view is inserted as toolbar item in
	// -[ComposeViewController toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:]
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return;
    }
    GMSecurityMethodAccessoryView *accessoryView = nil;
	accessoryView = [self securityMethodAccessoryView];
	accessoryView.delegate = self;
}

- (void)hideSecurityMethodAccessoryView {
	GMSecurityMethodAccessoryView *accessoryView = [self securityMethodAccessoryView]; //[self getIvar:@"SecurityMethodHintAccessoryView"];
    accessoryView.hidden = YES;
}

- (void)securityMethodAccessoryView:(GMSecurityMethodAccessoryView *)accessoryView didChangeSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod {
    ComposeBackEnd *backEnd = MAIL_SELF(self).backEnd;
    ((ComposeBackEnd_GPGMail *)(MAIL_SELF(self)).backEnd).preferredSecurityProperties.securityMethod = securityMethod;
    [(HeadersEditor_GPGMail *)[MAIL_SELF(self) headersEditor] updateFromAndAddSecretKeysIfNecessary:@(securityMethod == GPGMAIL_SECURITY_METHOD_OPENPGP ? YES : NO)];
    [[MAIL_SELF(self) headersEditor] _updateSecurityControls];
}

- (void)MADealloc {
    // Sometimes this fails, so simply ignore it.
    @try {
		[(NSNotificationCenter *)[NSNotificationCenter defaultCenter] removeObserver:self];
//        [(MailNotificationCenter *)[NSClassFromString(@"MailNotificationCenter") defaultCenter] removeObserver:self];
    }
    @catch(NSException *e) {
        
    }
	[self MADealloc];
}

- (BOOL)isUnencryptedReplyToEncryptedMessageWithChecklist:(NSMutableArray *)checklist {
	// While Mail.app internally removes objects from the checklist, we instead add one
	// if the user explicitly told us to continue with sending.
	// We have to handle it this way, since sendMessageAfterChecking is called for each failing
	// check and we can't determine which one is the first call, to correctly add our own item to the checklist,
	// and later remove it, when the check has cleared.
	// So instead we add an item.

	// If there is no checklist, we have nothing to check.
	// If we would still check, we head an infinite loop.
	if (!checklist) {
		return NO;
	}


	ComposeBackEnd *backEnd = (ComposeBackEnd *)[MAIL_SELF(self) backEnd];
	GMComposeMessagePreferredSecurityProperties *securityProperties = [(ComposeBackEnd_GPGMail *)backEnd preferredSecurityProperties];

	BOOL isReply = [(ComposeBackEnd_GPGMail *)backEnd messageIsBeingReplied];
	BOOL isForward = [(ComposeBackEnd_GPGMail *)backEnd messageIsBeingForwarded];
    BOOL originalMessageIsEncrypted = [[((Message_GPGMail *)[backEnd originalMessage]) securityFeatures] PGPEncrypted];
    BOOL replyShouldBeEncrypted = securityProperties.shouldEncryptMessage;

	// If checklist contains the unencryptedReplyToEncryptedMessage item, it means
	// that the user decided to send the message regardless of our warning.
	if((isReply || isForward) && originalMessageIsEncrypted && !replyShouldBeEncrypted && ![checklist containsObject:kUnencryptedReplyToEncryptedMessage]) {
		// Warn the user.
		return YES;
	}

	// Isn't a un-encrypted reply to an encrypted message or
	// the user decided to send the message regardless of our warning
	return NO;
}

- (void)displayWarningForUnencryptedReplyToEncryptedMessageUpdatingChecklist:(NSMutableArray *)checklist {
	NSArray *recipientsMissingCertificates = [(ComposeBackEnd *)[MAIL_SELF(self) backEnd] recipientsThatHaveNoKeyForEncryption];

    ComposeBackEnd *backEnd = (ComposeBackEnd *)[MAIL_SELF(self) backEnd];

    BOOL isForward = [(ComposeBackEnd_GPGMail *)backEnd messageIsBeingForwarded];

    NSString *typePrefix = isForward ? @"UNENCRYPTED_FORWARD_OF_" : @"UNENCRYPTED_REPLY_TO_";

	NSMutableString *recipientWarning = [NSMutableString new];
	for(NSString *recipient in recipientsMissingCertificates) {
		[recipientWarning appendFormat:@"- %@\n", recipient];
	}

    NSMutableString *explanation = [NSMutableString new];
	if([recipientsMissingCertificates count]) {
		NSString *missingKeysString = [GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_MISSING_KEYS", typePrefix]];
		if([recipientsMissingCertificates count] == 1)
			missingKeysString = [GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_MISSING_KEYS_SINGULAR", typePrefix]];
		[explanation appendFormat:@"%@\n", [NSString stringWithFormat:missingKeysString, recipientWarning]];
	}

	[explanation appendString:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_EXPLANATION", typePrefix]]];

	NSMutableString *solutionProposals = [NSMutableString new];
    if(!isForward) {
        [solutionProposals appendString:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_SOLUTION_REMOVE_PREVIOUS_CORRESPONDENCE", typePrefix]]];
    }
	if([recipientsMissingCertificates count]) {
		[solutionProposals appendString:@"\n"];
		if([recipientsMissingCertificates count] == 1)
			[solutionProposals appendString:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_SOLUTION_IMPORT_KEYS_SINGULAR", typePrefix]]];
		else
			[solutionProposals appendString:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_SOLUTION_IMPORT_KEYS", typePrefix]]];
	}
	[explanation appendString:solutionProposals];
	[explanation appendString:@"\n"];

	NSAlert *unencryptedReplyAlert = [NSAlert new];
	[unencryptedReplyAlert setMessageText:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_TITLE", typePrefix]]];
	[unencryptedReplyAlert setInformativeText:explanation];
	[unencryptedReplyAlert addButtonWithTitle:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_BUTTON_CANCEL", typePrefix]]];
	[unencryptedReplyAlert addButtonWithTitle:[GPGMailBundle localizedStringForKey:[NSString stringWithFormat:@"%@ENCRYPTED_MESSAGE_BUTTON_SEND_ANYWAY", typePrefix]]];
	[unencryptedReplyAlert setIcon:[NSImage imageNamed:@"GPGMail"]];

	// On Mavericks and later we can use, beginSheetModalForWindow:.
	// Before that, we have to use NSBeginAlertSheet.
    id __weak weakSelf = self;
    [unencryptedReplyAlert beginSheetModalForWindow:[[MAIL_SELF(self) view] window] completionHandler:^(NSModalResponse returnCode) {
        id __strong strongSelf = weakSelf;

        if(returnCode == NSAlertSecondButtonReturn) {
            // The user pressed send anyway, so add the kUnencryptedReplyToEncryptedMessage item
            // to the checklist, so the next time around sendMessageAfterChecking: is called,
            // we no longer check if the message is sent unencrypted.
            [checklist addObject:kUnencryptedReplyToEncryptedMessage];
            [strongSelf sendMessageAfterChecking:checklist];
        }
    }];
}

- (void)warnAboutUnecryptedReplySheetClosed:(NSWindow *)sheet returnCode:(long long)returnCode contextInfo:(void *)contextInfo {
	NSDictionary *_contextInfo = (__bridge_transfer NSDictionary *)contextInfo;
	if(returnCode == NSAlertAlternateReturn) {
		NSMutableArray *checklist = _contextInfo[@"ThingsToCheck"];
		[checklist addObject:kUnencryptedReplyToEncryptedMessage];
		[MAIL_SELF(self) sendMessageAfterChecking:checklist];
	}
}


- (void)MASendMessageAfterChecking:(NSMutableArray *)checklist {
	// If this is an unencrypted reply to an encrypted message, display a warning
    // to the user and simply return. The message won't be sent until the checklist is cleared.
	// Otherwise call sendMessageAfterChecking so that Mail.app can perform its internal checks.
    // TODO: Fix for Sierra.
    if([self isUnencryptedReplyToEncryptedMessageWithChecklist:checklist]) {
		[self displayWarningForUnencryptedReplyToEncryptedMessageUpdatingChecklist:checklist];
        return;
    }

	[self MASendMessageAfterChecking:checklist];
}

- (void)restoreComposerView {
	ComposeBackEnd *backEnd = (MAIL_SELF(self)).backEnd;
	[backEnd setIsDeliveringMessage:NO];
	[(ComposeWindowController_GPGMail *)[self delegate] restorePositionBeforeAnimation];
	
	ComposeWindowController *windowController = [self delegate];
	ComposeViewController *viewController = (id)[windowController contentViewController];
	HeadersEditor *editor = [viewController valueForKey:@"headersEditor"];
	[editor setValue:viewController forKey:@"composeViewController"];
}

- (BOOL)backEnd:(id)backEnd handleDeliveryError:(NSError *)error {
	
	NSNumber *errorCode = ((NSDictionary *)error.userInfo)[@"GPGErrorCode"];
	// If the pinentry dialog was cancelled, there's no need to show any error.
	// Simply let the user continue editing.
	if(errorCode && [errorCode integerValue] == GPGErrorCancelled) {
		return NO;
	}
	
	return YES;
}

- (void)MABackEnd:(id)backEnd didCancelMessageDeliveryForEncryptionError:(NSError *)error {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        [self MABackEnd:backEnd didCancelMessageDeliveryForEncryptionError:error];
        return;
    }
	if([self backEnd:backEnd handleDeliveryError:error])
		[self MABackEnd:backEnd didCancelMessageDeliveryForEncryptionError:error];
	
//    if([GPGMailBundle isElCapitan])
//        [self restoreComposerView];
}

- (void)MABackEnd:(id)backEnd didCancelMessageDeliveryForError:(NSError *)error {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        [self MABackEnd:backEnd didCancelMessageDeliveryForError:error];
        return;
    }
	if([self backEnd:backEnd handleDeliveryError:error])
		[self MABackEnd:backEnd didCancelMessageDeliveryForEncryptionError:error];

//    if([GPGMailBundle isElCapitan])
//        [self restoreComposerView];
}

- (void)MABackEndDidAppendMessageToOutbox:(id)backEnd result:(long long)result {
	[self MABackEndDidAppendMessageToOutbox:backEnd result:result];
	// If result == 3 the message was successfully sent, and now it's time to really dismiss the tab,
	// in order to free the resources, Mail wanted to free as soon as it started the send animation.
	// Unfortunately, if let it do that at the point of the send animation, there's no way we could
	// display an error.
	if(result == 3) {
        // TODO: Fix for HighSierra. Seems to crash! Timing bug!
//        [self setIvar:kComposeWindowControllerAllowWindowTearDown value:@(YES)];
//        [(ComposeWindowController *)[self delegate] composeViewControllerDidSend:self];
//        [self removeIvar:kComposeWindowControllerAllowWindowTearDown];
	}
}

- (void)MASetDelegate:(id)delegate {
	[self MASetDelegate:delegate];
	// Store the delegate as associated object, otherwise Mail.app releases it to soon (when performing the send animation.)!
	// Will be automatically released, when the ComposeViewController is released.
	[self setIvar:@"GMDelegate" value:delegate];
}

@end
