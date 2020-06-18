/* HeadersEditor+GPGMail.h re-created by Lukas Pitschl (@lukele) on Wed 25-Aug-2011 */

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

@interface HeadersEditor_GPGMail : NSObject <NSWindowDelegate>

/**
 Is called whenever the user clicks on either the sign or encrypt icon
 in a message composer.
 For the signed and|or encrypted drafts to work, it's necessary, to tell
 the back end it has changes, every time the user changes the encrypt, sign
 options for the message, so it saves a new draft.
 */
- (void)MASecurityControlChanged:(id)securityControl;


/**
 Is called whenever the From NSPopUpButton is filled.
 We need it to add the different secret keys.
 */
- (void)MA_updateFromAndSignatureControls:(id)arg1;

/**
 This is called asynchronously from updateSecurityControls on a invocation queue.
 */
- (void)MA_updateSecurityStateInBackgroundForRecipients:(NSArray *)recipients sender:(id)sender;

/**
 Adds or removes the secret keys to the From NSPopUpButton.
 */
- (void)updateFromAndAddSecretKeysIfNecessary:(NSNumber *)necessary;

/**
 Is called whenever the user select a account in the PopUp.
 Is used to set the GPGKey in the back-end.
 */
- (void)MAChangeFromHeader:(NSPopUpButton *)sender;

/**
  Norification handling.
 */
- (void)keyringUpdated:(NSNotification *)notification;

- (void)updateSymmetricButton;

- (void)_updateSecurityControls;
- (void)updateSecurityControls;
- (NSPopUpButton *)fromPopup;
- (void)_setVisibilityForFromView:(BOOL)visible;

@end

@interface HeadersEditor_GPGMail (NotImplemented)

- (id)composeViewController;

@end
