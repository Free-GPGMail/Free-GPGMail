/* MessageHeaderDisplay+GPGMail.h created by Lukas Pitschl (@lukele) on Wed 03-Aug-2011 */

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

@interface MessageHeaderDisplay_GPGMail : NSObject

/**
 Is invoked whenever either the encrypt or sign icon is clicked in
 a message view.
 
 Based on the link the signature panel is displayed or the message is decrypted.
 */
- (BOOL)MATextView:(id)textView clickedOnLink:(id)link atIndex:(unsigned long long)index;

/**
 Creates and displayes the signature panel.
 */
- (void)_showSignaturePanel;

- (void)_showAttachmentsPanel;

/**
 This method displays the S/MIME security headers.
 If a message is encrypted a encrypted icon is displayed. If a message is signed,
 a signed icon is displayed, accompanied by the email address(es) of the sender.
 It also is the entry point for the new message view GPGMail UI.
 
 It checks if the message is pgp encrypted and adds the encrypted icon and encrypted
 string.
 After that it checks if the message is pgp signed and adds the signed icon and message
 signers.
 */
- (id)MA_attributedStringForSecurityHeader;

/**
 Create the signature part based on the found signatures and errors.
 */
- (NSAttributedString *)securityHeaderSignaturePartForMessage:(Message *)message;

- (void)setShowDetails:(long long)showDetails;

@end

@interface MessageHeaderDisplay_GPGMail (NotImplemented)

/**
  This method no longer exists under Yosemite, but we need to make sure it's defined, otherwise
  we'll have to deal with compiler errors.
 */
- (void)_updateDetailsButton;

@end

@interface NSAlert (NotImplemented)

+ (id)alertForError:(id)error defaultButton:(id)defaultButton alternateButton:(id)alternateButton otherButton:(id)otherButton;
+ (id)alertForError:(id)arg1 firstButton:(id)arg2 secondButton:(id)arg3 thirdButton:(id)arg4;


@end
