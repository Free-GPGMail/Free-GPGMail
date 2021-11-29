/* MessageContentController+GPGMail.h created by Lukas Pitschl (@lukele) on Wed 03-Aug-2011 */

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

//#import <MessageContentController.h>

@interface MessageContentController_GPGMail : NSObject

/**
 This method is called when the encrypted icon is clicked in a message view.
 It's only used in the case, when encrypted messages should not be decrypted automatically,
 but manually by a user interaction.
 
 It adds some information to the message, so decodeWithContext knows it should return
 the decrypted body.
 
 Calling MessageContentController.reloadCurrentMessageShouldReparseBody: reloads the current
 message in a separate thread, showing a spinner animation while the body data is retrieved
 using decodeWithContext which returns the decrypted message body. 
 Upon receiving the decrypted message body, the spinner animation fades and the decrypted message
 is displayed. (All done automatically by Mail! that's how I like it!)
 
 TODO: Only decrypt the message, if it's not already displayed decrypted.
 */
- (void)decryptPGPMessage;

/**
 Invoked by Mail.app if the user selects a message.
 
 It's important to intercept this call, to set an internal variable UserSelectedMessage which
 is checked by -[Message shouldBePGPProcessed].
 -[Message shouldBePGPProcessed] needs to know whether a message was selected
 by the user or if Mail.app tries to process it for generating the snippets.
 */
- (void)MASetMessageToDisplay:(id)message;

@end
