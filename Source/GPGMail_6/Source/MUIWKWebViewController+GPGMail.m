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

#import "NSObject+LPDynamicIvars.h"
#import "GPGMailBundle.h"
#import "MUIWebDocument.h"

#import "MUIWKWebViewController+GPGMail.h"

@implementation MUIWKWebViewController_GPGMail
- (void)MAWebView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // Bug #981: Efail
    //
    // By default macOS Mail allows HTML-Emails to contain HTML forms
    // which can be submitted directly from the email.
    // An attack has been shown, which uses mime part concatenation
    // to wrap a form around legitimate encrypted content and uses
    // CSS to make the entire email clickable and thus submitting the
    // form.
    //
    // In order to mitigate against this attack in OpenPGP and S/MIME
    // messages, form submission of any kind is disallowed within
    // messages containing encrypted data.
    //
    // In order for S/MIME to be less broken, introduce a dialog
    // asking the user if they really want to click on that link.
    BOOL isEncrypted = [[self representedObject] isEncrypted];
    BOOL isSMIMEEncrypted = isEncrypted && ![[self representedObject] getIvar:@"GMMessageSecurityFeatures"];

    if(!isEncrypted) {
        [self MAWebView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
        return;
    }

    // Ignore any form events.
    if(navigationAction.navigationType == WKNavigationTypeFormSubmitted ||
       navigationAction.navigationType == WKNavigationTypeFormResubmitted) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    // Ignore any other events besides link clicks.
    if(navigationAction.navigationType != WKNavigationTypeLinkActivated) {
        [self MAWebView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
        return;
    }

    if(isSMIMEEncrypted) {
        NSAlert *alert = [GPGMailBundle customAlert];
        [alert setMessageText:[GPGMailBundle localizedStringForKey:@"NAVIGATION_ACTION_FROM_ENCRYPTED_MESSAGE_TITLE"]];
        [alert setInformativeText:[NSString stringWithFormat:[GPGMailBundle localizedStringForKey:@"NAVIGATION_ACTION_FROM_ENCRYPTED_MESSAGE_MESSAGE"], navigationAction.request.URL]];
        [alert addButtonWithTitle:[GPGMailBundle localizedStringForKey:@"NAVIGATION_ACTION_FROM_ENCRYPTED_MESSAGE_BUTTON_YES"]];
        [alert addButtonWithTitle:[GPGMailBundle localizedStringForKey:@"NAVIGATION_ACTION_FROM_ENCRYPTED_MESSAGE_BUTTON_CANCEL"]];
        [alert setAlertStyle:NSWarningAlertStyle];

        [alert beginSheetModalForWindow:[(id)[(id)self view] window] completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertSecondButtonReturn) {
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
            [self MAWebView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
        }];
        return;
    }

    // Invoke original handler, otherwise no navigation action will work.
    [self MAWebView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
}


@end
