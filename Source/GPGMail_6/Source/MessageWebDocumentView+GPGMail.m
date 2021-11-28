/* MessageWebDocumentView+GPGMail.m created by Lukas Pitschl (@lukele) on May 25 2020 */

/*
 * Copyright (c) 2020, GPGTools GmbH <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Team nor the names of GPGMail
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

#import "MessageWebDocumentView+GPGMail.h"
#import "MUIWebDocumentView.h"
#import "MUIWebDocument.h"

#import "NSObject+LPDynamicIvars.h"
#import "CCLog.h"
#import "GMMessageSecurityFeatures.h"

#define mailself ((MUIWebDocumentView *)self)
#define cast_mailself(object) ((MUIWebDocumentView *)(object))

extern NSString * const kMessageSecurityFeaturesKey;

@implementation MessageWebDocumentView_GPGMail

// Bug #1057: Partly signed or encrypted message can't be scrolled if their content exceeds
//            the window height in macOS Catalina.
//
// In macOS versions before macOS Catalina -[MessageWebDocumentView setContentSize:]
// would configure the width and height of the document view of the message scroll view
// so scrolling is properly setup if the content height exceeds the height of the window.
// -[MessageWebDocumentView setContentSize:] was called only for the main frame.
//
// In macOS Catalina however -[MessageWebDocumentView setContentSize:] is called for the
// main frame as well as any <iframe>s used within the HTML document, which results
// in the content height of the document view being set to the last iframe encountered
// preventing the user from scrolling the content and cutting off the content.
//
// Based on the truth that the real document height always exceeds the size of any
// <iframe>, since it includes the height of any <iframe>s encountered,
// -[MessageWebDocumentView setContentSize:] will only update the document view's size
// if the new height value is larger than the currently configured height.
- (void)MASetContentSize:(CGSize)contentSize {
    // Size calls before the security features of the message are available
    // are irrelevant since it's not known yet, whether or not the message
    // is partly signed / encrypted and it is only necessary to adjust the
    // content size if the message is partly signed or partly encrypted.
    GMMessageSecurityFeatures *securityFeatures = [[mailself webDocument] getIvar:kMessageSecurityFeaturesKey];
    BOOL adjustContentSize = [securityFeatures PGPPartlyEncrypted] || [securityFeatures PGPPartlySigned];
    DebugLog(@"[FixScrollSize]: Should adjust content size: %@", adjustContentSize ? @"YES" : @"NO");

    if(!adjustContentSize) {
        [self MASetContentSize:contentSize];
        return;
    }

    BOOL updateContentSize = YES;

    NSSize frameSize = [mailself frame].size;
    NSSize currentContentSize = [mailself contentSize];

    DebugLog(@"[FixScrollSize]:\n{\n\tframe size: %@,\n\tcurrent content size: %@,\n\tnew content size: %@,\n}",
             NSStringFromSize(frameSize), NSStringFromSize(currentContentSize), NSStringFromSize(contentSize));
    // By creating a NSSize variable with the width of the current content size but the height
    // of the new content size, it's possible to compare if the width has changed, in which case
    // the new height would automatically be applied.
    NSSize compareSize = NSMakeSize(currentContentSize.width, contentSize.height);

    // If different height values are received for the same width, the largest height
    // is the real content height, since the <iframe>'s content height will always be smaller
    // than the total height of all content including all <iframe>s.
    //
    // If however the new width is different from the current width, in most cases it
    // means that the window width has changed and thus the height is reset to
    // the new height, regardless of whether it is larger or smaller than the current height.
    // Otherwise the largest ever recorded value for any window width would win,
    // and the scrollable area will not match the actual content height.
    if(currentContentSize.height > contentSize.height && NSEqualSizes(contentSize, compareSize)) {
        DebugLog(@"[FixScrollSize]: Current document size is larger: %@ > %@", NSStringFromSize(currentContentSize),
                 NSStringFromSize(contentSize));
        contentSize.height = currentContentSize.height;
    }

    // If the new width doesn't match the web view frame's width ignore the change.
    // For some reason calls with width = 1 are seen but it's unclear what they mean.
    // In some cases the width might only differ by less than a pixel, in which case
    // a new height would be dropped. To account for the difference the width is rounded.
    // (seen by user on iMac).
    CGFloat difference = fabs(frameSize.width - contentSize.width);
    DebugLog(@"[FixScrollSize]: Width difference: %f", difference);
    if(difference >= 2.0) {
        DebugLog(@"[FixScrollSize]: Ignore new content size. Width doesn't match: %@ - %@", NSStringFromSize(compareSize),
                 NSStringFromSize(frameSize));
        updateContentSize = NO;
    }

    if(updateContentSize) {
        DebugLog(@"[FixScrollSize]: Updating document size: %@", NSStringFromSize(contentSize), NSStringFromSize(contentSize));
        [self MASetContentSize:contentSize];
    }
}

@end

#undef mailself
#undef cast_mailself
