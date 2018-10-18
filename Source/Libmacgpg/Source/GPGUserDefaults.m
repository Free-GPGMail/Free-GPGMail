/* GPGUserDefaults.m created by Lukas Pitschl (@lukele) on Thu 25-Apr-2014 */

/*
 * Copyright (c) 2000-2017, GPGTools Team <team@gpgtools.org>
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
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSBundle+Sandbox.h"
#import "GPGTaskHelper.h"
#import "GPGTaskHelperXPC.h"
#import "GPGUserDefaults.h"
#import "GPGTask.h"

@implementation GPGUserDefaults

@synthesize target=_target;

+ (GPGUserDefaults *)standardUserDefaults {
	static GPGUserDefaults *_sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[GPGUserDefaults alloc] init];
	});
	return _sharedInstance;
}

- (id)init {
	self = [super init];
	if(self) {
		_target = [NSUserDefaults standardUserDefaults];
	}
	return self;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
	return _target;
}

- (NSDictionary *)persistentDomainForName:(NSString *)domainName {
	// Sandbox is not enabled? No need to go through the XPC.
	if(![GPGTask sandboxed])
		return [_target persistentDomainForName:domainName];
	
	// Otherwise, no way around it. XPC is necessary, but no
	// big deal either.
	GPGTaskHelperXPC *taskHelper = [[GPGTaskHelperXPC alloc] init];
	
	NSDictionary *defaults = nil;
	
	@try {
		defaults = [taskHelper loadUserDefaultsForName:domainName];
	}
	@catch (NSException *exception) {
	}
	@finally {
		[taskHelper release];
	}
	
	return defaults;
}

- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)domainName {
	// Sandbox is not enabled? No need to go through the XPC.
	if(![GPGTask sandboxed]) {
		[_target setPersistentDomain:domain forName:domainName];
		return;
	}
	
	GPGTaskHelperXPC *taskHelper = [[GPGTaskHelperXPC alloc] init];
	
	@try {
		[taskHelper setUserDefaults:domain forName:domainName];
	}
	@catch (NSException *exception) {
	}
	@finally {
		[taskHelper release];
	}
}

@end
