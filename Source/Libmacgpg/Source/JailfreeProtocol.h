/* JailfreeProtocol.h created by Lukas Pitschl (@lukele) on Tue 23-Apr-2014 */

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

#import <Foundation/Foundation.h>

@protocol Jailfree <NSObject>

- (void)testConnection:(void (^)(BOOL))reply;
- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSData *)data readAttributes:(BOOL)readAttributes closeInput:(BOOL)closeInput reply:(void (^)(NSDictionary *))reply;
- (void)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait reply:(void (^)(BOOL))reply;

- (void)startGPGWatcher;
- (void)loadConfigFileAtPath:(NSString *)path reply:(void (^)(NSString *))reply;
- (void)loadUserDefaultsForName:(NSString *)domainName reply:(void (^)(NSDictionary *))reply;
- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName reply:(void (^)(BOOL result))reply;
- (void)isPassphraseForKeyInGPGAgentCache:(NSString *)key reply:(void (^)(BOOL result))reply;
- (void)showGPGSuitePreferencesWithArguments:(NSDictionary *)arguments reply:(void (^)(BOOL result))reply;

@end

@protocol Jail <NSObject>

@optional
- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *response))reply;
- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total;
- (void)postNotificationName:(NSString *)name object:(NSString *)object;

@end
