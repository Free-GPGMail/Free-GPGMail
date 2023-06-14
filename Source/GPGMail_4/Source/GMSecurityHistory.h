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

#import <Foundation/Foundation.h>
#import "GPGConstants.h"

#define GPGMAIL_SECURITY_OPTIONS_HISTORY_FILE @"security-options-history.data"
#define GPGMAIL_SECURITY_OPTIONS_HISTORY_DOMAIN @"org.gpgtools.gpgmail"

@class GMSecurityOptions, MCMessage;

@interface GMSecurityHistory : NSObject

+ (GPGMAIL_SECURITY_METHOD)defaultSecurityMethod;

- (GMSecurityOptions *)securityOptionsFromDefaults;

- (GMSecurityOptions *)bestSecurityOptionsForSignFlags:(GPGMAIL_SIGN_FLAG)signFlags
                                          encryptFlags:(GPGMAIL_ENCRYPT_FLAG)encryptFlags;
- (GMSecurityOptions *)bestSecurityOptionsForReplyToMessage:(MCMessage *)message signFlags:(GPGMAIL_SIGN_FLAG)signFlags
                                               encryptFlags:(GPGMAIL_ENCRYPT_FLAG)encryptFlags;

@end

@interface GMSecurityOptions : NSObject {
    GPGMAIL_SECURITY_METHOD _securityMethod;
    BOOL _shouldSign;
    BOOL _shouldEncrypt;
}

- (id)initWithSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod shouldSign:(BOOL)shouldSign shouldEncrypt:(BOOL)shouldEncrypt;
+ (GMSecurityOptions *)securityOptionsWithSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod shouldSign:(BOOL)shouldSign shouldEncrypt:(BOOL)shouldEncrypt;

@property (nonatomic, assign, readonly) GPGMAIL_SECURITY_METHOD securityMethod;
@property (nonatomic, assign, readonly) BOOL shouldSign;
@property (nonatomic, assign, readonly) BOOL shouldEncrypt;

@end
