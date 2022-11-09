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

#import "GPGMailBundle.h"

#import "MUIWKWebViewConfigurationManager.h"

#import "MUIWKWebViewConfigurationManager+GPGMail.h"


@interface _WKUserStyleSheet

- (instancetype)initWithSource:(NSString *)source forMainFrameOnly:(BOOL)forMainFrameOnly;

@end

@interface WKUserContentController (Private)

- (void)_addUserStyleSheet:(_WKUserStyleSheet *)userStyleSheet;

@end

@implementation MUIWKWebViewConfigurationManager_GPGMail

- (id)MAInit {
    id ret = [self MAInit];

    WKUserScript *resizeScript = [[WKUserScript alloc] initWithSource:[NSString stringWithContentsOfURL:[[GPGMailBundle bundle] URLForResource:@"iframeResizer" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil] injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    WKUserScript *configureResizerScript = [[WKUserScript alloc] initWithSource:[NSString stringWithContentsOfURL:[[GPGMailBundle bundle] URLForResource:@"content-isolator" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil] injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    WKUserScript *iframeHeightScriptBegin = [[WKUserScript alloc] initWithSource:[NSString stringWithContentsOfURL:[[GPGMailBundle bundle] URLForResource:@"iframeResizer.contentWindow" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil] injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];

    [[[(MUIWKWebViewConfigurationManager *)ret configuration] userContentController] addUserScript:resizeScript];
    [[[(MUIWKWebViewConfigurationManager *)ret configuration] userContentController] addUserScript:configureResizerScript];
    [[[(MUIWKWebViewConfigurationManager *)ret configuration] userContentController] addUserScript:iframeHeightScriptBegin];

    id styleSheet = [[NSClassFromString(@"_WKUserStyleSheet") alloc] initWithSource:[(MUIWKWebViewConfigurationManager *)self effectiveUserStyle] forMainFrameOnly:NO];
    id styleSheet2 = [[NSClassFromString(@"_WKUserStyleSheet") alloc] initWithSource:[NSString stringWithContentsOfURL:[[GPGMailBundle bundle] URLForResource:@"content-isolator" withExtension:@"css"] encoding:NSUTF8StringEncoding error:nil] forMainFrameOnly:NO];

    [[[(MUIWKWebViewConfigurationManager *)ret configuration] userContentController] _addUserStyleSheet:styleSheet];
    [[[(MUIWKWebViewConfigurationManager *)ret configuration] userContentController] _addUserStyleSheet:styleSheet2];
    return ret;
}

@end
