/* MailToolbar+GPGMail.m created by Lukas Pitschl on Tue 22-09-2015 */

/*
 * Copyright (c) 2000-2015, GPGTools <team@gpgtools.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools ``AS IS'' AND ANY
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

#import "MailToolbar+GPGMail.h"
#import "GPGMailBundle.h"

@implementation MailToolbar_GPGMail

+ (id)MA_plistForToolbarWithIdentifier:(id)arg1 {
    if(![[GPGMailBundle sharedInstance] hasActiveContractOrActiveTrial]) {
        return [self MA_plistForToolbarWithIdentifier:arg1];
    }
	id ret = [self MA_plistForToolbarWithIdentifier:arg1];
	
	if(![arg1 isEqualToString:@"ComposeWindow"])
		return ret;
	
	NSMutableDictionary *configuration = [ret mutableCopy];
	NSMutableArray *defaultSet = [configuration[@"default set"] mutableCopy];
	[defaultSet addObject:@"toggleSecurityMethod:"];
	[configuration setObject:defaultSet forKey:@"default set"];
	
	return configuration;
}

@end
