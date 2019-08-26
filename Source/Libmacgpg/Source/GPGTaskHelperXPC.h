#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080

/* GPGTaskHelperXPC.h created by Lukas Pitschl (@lukele) on Mon 22-Apr-2014 */

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

/**
 * GPGTaskHelperXPC is responsible for creating the connection to the
 * org.gpgtools.Libmacgpg.xpc XPC service, which is responsible for running
 * the gpg2 task, since the in a sandboxed environment it can't be run directly.
 *
 * GPGTaskHelperXPC is used internally by GPGTaskHelper and is only used if the
 * host app is sandboxed.
 * It keeps a weak reference to the GPGTaskHelper and returns the result of the invoked
 * XPC method to the GPGTask so that the use of XPC instead of direct launching
 * of the gpg2 task is completely transparent to the host application.
 *
 * By default status and progress messages from the gpg2 task are not handled
 * by GPGTaskHelperXPC, but an API is exposed to setup handlers for those messages.
 */
#import <Libmacgpg/JailfreeProtocol.h>

@interface GPGTaskHelperXPC : NSObject <Jail> {
	NSData *(^_processStatus)(NSString *keyword, NSString *value);
	void (^_progressHandler)(NSUInteger processedBytes, NSUInteger totalBytes);
	NSXPCConnection *_connection;
	dispatch_semaphore_t _taskLock;
	id <Jailfree> _jailfree;
	BOOL _wasShutdown;
	NSException *_connectionError;
	NSException *_callError;
	NSException *_taskError;
	BOOL _success;
}

- (id)init;
- (NSDictionary *)launchGPGWithArguments:(NSArray *)arguments data:(NSData *)data readAttributes:(BOOL)readAttributes closeInput:(BOOL)closeInput;
- (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait;
- (void)shutdown;
- (NSString *)loadConfigFileAtPath:(NSString *)path;
- (NSDictionary *)loadUserDefaultsForName:(NSString *)domainName;
- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName;
- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSString *)key;
- (BOOL)validSupportContractAvailableForProduct:(NSString *)identifier activationInfo:(NSDictionary **)activationInfo;
- (BOOL)activateSupportContractWithEmail:(NSString *)email activationCode:(NSString *)activationCode error:(NSError **)error;
- (BOOL)startTrial;
- (BOOL)deactivateSupportPlanWithError:(NSError **)error;
- (BOOL)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments;

@property (nonatomic, copy) NSData *(^processStatus)(NSString *keyword, NSString *value);
@property (nonatomic, copy) void (^progressHandler)(NSUInteger processedBytes, NSUInteger totalBytes);

@property (nonatomic, retain, readonly) NSException *connectionError;

@end

#endif
