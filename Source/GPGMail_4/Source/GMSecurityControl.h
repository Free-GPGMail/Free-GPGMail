/*
 * Copyright (c) 2000-2012, GPGTools Project Team <gpgtools-devel@lists.gpgtools.org>
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
 * THIS SOFTWARE IS PROVIDED BY GPGTools Project Team AND CONTRIBUTORS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GPGTools Project Team AND CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define ENCRYPT_LOCK_UNLOCKED_IMAGE @"NSLockUnlockedTemplate"
#define ENCRYPT_LOCK_LOCKED_IMAGE @"NSLockLockedTemplate"
#define SIGN_ON_IMAGE @"SignatureOnTemplate"
#define SIGN_OFF_IMAGE @"SignatureOffTemplate"

typedef enum {
    SECURITY_BUTTON_ENCRYPT_TAG = 1,
    SECURITY_BUTTON_SIGN_TAG = 2
} SECURITY_BUTTON_TAG;

/**
 GMSecurityControl replaces the NSSegmentedControl which is used for the 
 sign and encrypt button in the composer window in order to completely
 control when the status of the buttons as well as the information of when
 to encrypt and when to sign a message.
 
 By definition GPGMail should sign messages if replying to a message which
 was signed and encrypt to a message which was encrypted.
 
 Mail itself chooses the options to use, based on the last selected option,
 so we have to change the status ourselve.
 
 -[ComposeBackEnd signIfPossible:] and -[ComposeBackEnd encryptIfPossible:]
 is called, once the user clicks on our control. Those methods internally
 check the image of the control and based on that decide whether to enable
 or disable encrypt and sign.
 They call imageForSegment on the control to find out which image is used
 (SIGN_OFF_IMAGE, SIGN_ON_IMAGE or ENCRYPT_LOCK_UNLOCKED_IMAGE, ENCRYPT_LOCK_LOCKED_IMAGE)
 and set the inverted status.
 
 When a compose window is first loaded, the enabled status of the control is set
 by Mail. We also control that status, since otherwise there was a small delay the
 user was seeing, about a second after they opened a new editor the image would switch
 to the right state.
 
 This way we can check the ComposeBackEnd EncryptIsPossible and SignIsPossible
 ivar which is set by GPGMail based on the values of canEncryptForAddresses and
 canSignFromAddress and set the enabled status based on that information and avoid
 the delayed image status change.
 
 YES, THIS IS ALL FOR TOTAL CONTROL AND GREATEST USER EXPERIENCE! HA!
*/

@interface GMSecurityControl : NSObject {
    NSSegmentedControl *_control;
    SECURITY_BUTTON_TAG _securityTag;
    NSString *_forcedImageName;
}

/**
 Set the NSSegmentedControl to delegate calls to. The tag attribute decides
 whether this GMSecurityControl replaces the sign or encrypt button.
*/ 
- (id)initWithControl:(NSSegmentedControl *)control tag:(SECURITY_BUTTON_TAG)tag;

/* Forward any selector to the control which is not implemented. */
- (id)forwardingTargetForSelector:(SEL)aSelector;

/**
 Override the incoming enabled flag by checking ComposeBackEnd EncryptIsPossible
 and SignIsPossible.
 */
- (void)setEnabled:(BOOL)enabled;

/**
 If this is a reply set the image based on the signed and encrypted status
 of the message which is being replied.
 */
- (void)setImage:(id)image forSegment:(NSInteger)segment;

/**
 Sets the image which is set on the next call to setImage:forSegment based
 on the fromImage image. The forced image is the opposite of the fromImage.
 
 Mail.app doesn't completely know how to deal with the GMSecurityControl
 so this image has to be set by GPGMail to display the right status 
 (on|off for encrypt and sign)
 */
- (void)updateStatusFromImage:(NSImage *)image;

@property (nonatomic, strong) NSSegmentedControl *control;
@property (nonatomic, assign) SECURITY_BUTTON_TAG securityTag;
@property (nonatomic, strong) NSString *forcedImageName;

@end

