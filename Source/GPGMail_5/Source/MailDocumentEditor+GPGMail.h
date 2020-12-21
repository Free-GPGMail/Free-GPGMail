/* MailDocumentEditor+GPGMail.h re-created by Lukas Pitschl (@lukele) on Sat 27-Aug-2011 */

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

#import "GMSecurityMethodAccessoryView.h"
#import "ComposeBackEnd+GPGMail.h"

@interface MailDocumentEditor_GPGMail : NSObject <NSMenuDelegate, GMSecurityMethodAccessoryViewDelegate>

/**
 Is called if the user exits fullscreen.
 Calls the method to re-configure the security method accessory view for normal mode.
 */
- (void)didExitFullScreen:(NSNotification *)notification;

/**
 Re-configures the security method accessory view for normal mode.
 */
- (void)configureSecurityMethodAccessoryViewForNormalMode;

/**
 The backend calls this method from setSignIfPossible and setEncryptIfPossible
 to reflect the chosen security method and sign and encrypt status.
 
 Updates the security method accessory view, the sender selector to add
 additional keys for OpenPGP if necessary.
 
 Deprecated: use updateSecurityMethodAccessoryView instead.
 */
- (void)updateSecurityMethodHighlight;

/**
 Deprecates updateSecurityMethodHighlight.
 */
- (void)updateSecurityMethodAccessoryView;

/**
 Updates the security method accessory view to show the new security method.
 YEAH, this doesn't make sense. Let's investigate!
 */
- (void)updateSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod;

/**
 Is injected to setup notifications and security method accessory view
 once the document editor almost finished loading.
 */
- (void)MABackEndDidLoadInitialContent:(id)content;

/**
 Setup the security method accessory view and add it to the theme frame.
 */
- (void)setupSecurityMethodHintAccessoryView;

/**
 Called from NSWindow toggleFullScreen: to hide the accessory view.
 */
- (void)hideSecurityMethodAccessoryView;

/**
 Delegate method which is used by the security method accessory view to inform
 the delegate that the user changed the security method.
 */
- (void)securityMethodAccessoryView:(GMSecurityMethodAccessoryView *)accessoryView didChangeSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod;

/**
 Inject to un-observe any notifications.
 */
- (void)MADealloc;

- (void)_updateSecurityControls;

@property (nonatomic, retain) GMSecurityMethodAccessoryView	*securityMethodAccessoryView;

/**
 Property indicating whether or not the compose view controller is allowed
 to tear down immediately. See #998 for details.
 */
- (BOOL)GMShouldPostponeTearDown;

@end

@interface MailDocumentEditor_GPGMail (NotImplemented)

- (id)delegate;

@end
