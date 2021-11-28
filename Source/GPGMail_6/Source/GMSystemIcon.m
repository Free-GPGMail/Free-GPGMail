/* GMSystemIcon.h created by Lukas Pitschl (@lukele) on Tue 04-Aug-2020 */

/*
 * Copyright (c) 2020, GPGTools Gmbh <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools nor the names of GPG Mail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools GmbH ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools GmbH BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GMSystemIcon.h"

NSString * const kGMSystemIconNameLockClosed = @"GMSystemIconNameLockClosed";
NSString * const kGMSystemIconNameLockOpen = @"GMSystemIconNameLockOpen";
NSString * const kGMSystemIconNameSignatureValid = @"GMSystemIconNameSignatureValid";
NSString * const kGMSystemIconNameSignatureInvalid = @"GMSystemIconNameSignatureInvalid";
NSString * const kGMSystemIconNamePaperclip = @"GMSystemIconNamePaperclip";

@interface NSImage (SFSymbolsAddition)

+ (NSImage *)imageWithSystemSymbolName:(NSString *)systemName accessibilityDescription:(NSString *)description;

@end

@implementation GMSystemIcon

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GMSystemIcon *_sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[GMSystemIcon alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    if((self = [super init])) {
        _icons = [NSMutableDictionary new];
        [self configureIcons];
    }

    return self;
}

- (void)configureIcons {
    _icons[kGMSystemIconNameLockClosed] = @{
        @"symbol": @"lock.fill",
        @"bundle": @"NSLockLockedTemplate",
        @"description": @"Message is encrypted"
    };
    _icons[kGMSystemIconNameLockOpen] = @{
        @"symbol": @"lock.open.fill",
        @"bundle": @"NSLockUnlockedTemplate",
        @"description": @"Message was decrypted"
    };
    _icons[kGMSystemIconNameSignatureValid] = @{
        @"symbol": @"checkmark.seal.fill",
        @"bundle": @"SignatureOnTemplate",
        @"description": @"OpenPGP Signature is valid"
    };
    _icons[kGMSystemIconNameSignatureInvalid] = @{
        @"symbol": @"xmark.seal.fill",
        @"bundle": @"SignatureOffTemplate",
        @"desciprition": @"OpenPGP Signature is invalid"
    };
    _icons[kGMSystemIconNamePaperclip] = @{
        @"symbol": @"paperclip",
        @"bundle": @"MessageListAttachmentTemplate",
        @"description": @"OpenPGP signed/encrypted attachments"
    };
}

- (NSImage *)iconForName:(NSString *)name accessibilityDescription:(NSString *)description {
    NSImage *icon = nil;
    description = description != nil ? description : _icons[name][@"description"];
    if(@available(macOS 10.16, *)) {
        NSString *systemName = _icons[name][@"symbol"];
        icon = [NSImage imageWithSystemSymbolName:systemName accessibilityDescription:description];
    }
    else {
        NSString *systemName = _icons[name][@"bundle"];
        icon = [NSImage imageNamed:systemName];
        [icon setAccessibilityDescription:description];
    }

    return icon;
}

+ (NSImage *)iconNamed:(NSString *)name {
    return [[self sharedInstance] iconForName:name accessibilityDescription:nil];
}

+ (NSImage *)iconNamed:(NSString *)name accessibilityDescription:(NSString *)description {
    return [[self sharedInstance] iconForName:name accessibilityDescription:description];
}

@end
