/*
* Copyright (c) 2021, GPGTools GmbH <team@gpgtools.org>
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
* THIS SOFTWARE IS PROVIDED BY GPGTools ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL GPGTools BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "GMSPCommon.h"
#import "GPGMailPreferences.h"
#import "GPGMailBundle.h"

#import "MailApp+GPGMail.h"

@implementation MailApp_GPGMail

- (void)MATabView:(id)tabView didSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem {
    [self MATabView:tabView didSelectTabViewItem:tabViewItem];
    if([[[tabViewItem viewController] representedObject] isKindOfClass:[GPGMailPreferences class]]) {
        [[[tabViewItem viewController] representedObject] willBeDisplayed];
    }
}

- (BOOL)MAHandleMailToURL:(NSString *)url {
    NSRange activationDataRange = [url rangeOfString:@"mailto:gmsp-activate+"];
    if(activationDataRange.location == NSNotFound) {
        return [self MAHandleMailToURL:url];
    }

    NSString *activationData = [url substringFromIndex:activationDataRange.location + activationDataRange.length];
    activationDataRange = [activationData rangeOfString:@"@support-plan.gpgtools.org"];

    if(activationDataRange.location == NSNotFound) {
        return YES;
    }

    activationData = [activationData substringWithRange:NSMakeRange(0, activationDataRange.location)];
    // Re-convert to proper base64, since normal base64 couldn contain =+/ which are not allowed
    // in email addresses.
    activationData = [activationData stringByReplacingOccurrencesOfString:@"_-_" withString:@"/"];
    activationData = [activationData stringByReplacingOccurrencesOfString:@"_" withString:@"="];
    activationData = [activationData stringByReplacingOccurrencesOfString:@"-" withString:@"+"];

    activationData = [activationData GMSP_base64Decode];

    if(![activationData length]) {
        return YES;
    }

    NSArray *activationComponents = [activationData componentsSeparatedByString:@":"];

    if([activationComponents count] != 2) {
        return YES;
    }

    [[GPGMailBundle sharedInstance] startSupportContractWizardWithActivationCode:activationComponents[0] email:activationComponents[1]];

    return YES;
}

@end
