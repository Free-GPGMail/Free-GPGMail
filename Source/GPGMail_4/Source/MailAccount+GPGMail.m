/* MailAccount+GPGMail.h created by Lukas Pitschl (@lukele) on Wed 03-Aug-2011 */

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

#import <MFMailAccount.h>
#import "MailAccount+GPGMail.h"
#import "GPGMailBundle.h"
#import <objc/runtime.h>
#import "MessageRouter+GPGMail.h"
#import "GMCodeInjector.h"


static NSString *GPGMailSwizzledMethodPrefix = @"MA";

@implementation MailAccount_GPGMail

+ (BOOL)MAAccountExistsForSigning {
    BOOL PGPAccountExistsForSigning = ((GPGMailBundle *)[GPGMailBundle sharedInstance]).accountExistsForSigning;
    if(PGPAccountExistsForSigning)
        return YES;
    
    return [self MAAccountExistsForSigning];
}


+(void)MACompleteDeferredAccountInitialization{
    /*
     *  MFMessageRouter will load rules in its +initialization method -- which is inadvertently called during injection.
     *  Because Rules often include mailbox information this try to load mailboxes prior to accounts being loaded, leading
     *  to undetermined effects.
     *
     *  A further conflict occur with MailTags because MailTags will swizzle the loading of rules and a deadlock may occur
     *  ( a race condition as far as I can tell )
     *
     *  The resolution to this situation is to defer code injection until after Account initialization is complete.
     *  When GPGMail is loaded, it swizzles the completeDeferredAccountInitialization -- which then performs the
     *  injection for MessageRouter methods
     *
     */
    
    [self MACompleteDeferredAccountInitialization];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		if (![GPGMailBundle isElCapitan]) {
			NSString *messageRouterClassName = nil;
			if (NSClassFromString(@"MessageRouter")) {
				messageRouterClassName = @"MessageRouter";
			}
			else if (NSClassFromString(@"MFMessageRouter")) {
				messageRouterClassName = @"MFMessageRouter";
			}
			// No MessageRouter class available? bail out.
			if(!messageRouterClassName) {
				return;
			}

			NSDictionary * deferredHooks = @{
											 messageRouterClassName: @[
													 @"putRulesThatWantsToHandleMessage:intoArray:colorRulesOnly:"
													 ]
											 };
			[GMCodeInjector injectUsingMethodPrefix:GPGMailSwizzledMethodPrefix hooks:deferredHooks];

		}
    });
    
}

@end
