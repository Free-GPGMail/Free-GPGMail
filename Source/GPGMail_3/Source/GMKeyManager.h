/* GMKeyManager.h created by Lukas Pitschl (@lukele) on Wed 13-Jun-2013 */

/*
 * Copyright (c) 2000-2013, GPGTools Team <team@gpgtools.org>
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

#import <Foundation/Foundation.h>

@interface GMKeyManager : NSObject <GPGControllerDelegate> {
	// Key caches for quick access.
	NSSet *_secretKeys;
	NSDictionary *_secretKeysByID;
	// All secret keys also holds keys that are disabled, since
	// those keys are still able to decrypt messages.
	// If only enabled secret keys are checked against the keys
	// which passphrase is in the gpg-agent cache, there's a chance
	// that a pinentry request might pop up even though not all keys
	// necessary are in the agent cache.
	NSSet *_allSecretKeys;
	NSDictionary *_allSecretKeysByID;
	NSDictionary *_secretKeysByEmail;
	NSDictionary *_secretKeyMap;
	
	NSSet *_publicKeys;
	NSDictionary *_publicKeysByID;
	NSDictionary *_publicKeysByEmail;
	NSDictionary *_publicKeyMap;
	
	NSDictionary *_groups;
	
	dispatch_semaphore_t _keyCacheLock;
}

/**
 Returns the matching secret key to a given key ID.
 */
- (GPGKey *)secretKeyForKeyID:(NSString *)keyID;

- (GPGKey *)secretKeyForKeyID:(NSString *)keyID includeDisabled:(BOOL)includeDisabled;

/**
 Returns the public key to one of the available secret keys.
 The public key to a secret key matching the passed preference address, will be returned
 first if available. Otherwise, any secret key's public key will do.
 */
- (GPGKey *)anyPersonalPublicKeyWithPreferenceAddress:(NSString *)address;

/**
 Return all secret keys which are available for a specified address.
 */
- (NSMutableSet *)signingKeyListForAddress:(NSString *)address;

/**
 Return all public keys which are available for the specified addresses.
 */
- (NSMutableSet *)publicKeyListForAddresses:(NSArray *)addresses;

/**
 Returns the key or subkey matching the given fingerprint.
 */
- (GPGKey *)keyForFingerprint:(NSString *)fingerprint;

/**
 Returns whether or not there's a secret key matching the given address.
 */
- (BOOL)secretKeyExistsForAddress:(NSString *)address;

/**
 Returns whether or not there's a public key matching the given address.
 */
- (BOOL)publicKeyExistsForAddress:(NSString *)address;

/**
 Returns a key which matches the given hint. User ID's, fingerprints are checked
 if they match.
 Only secret defines that only secret keys should be searched.
 */
- (GPGKey *)findKeyByHint:(NSString *)hint onlySecret:(BOOL)onlySecret;

/**
 Loads the keys in the background and returns immediately.
 */
- (void)scheduleInitialKeyUpdate;

/**
 Contains all GPG keys available.
 */
@property (nonatomic, strong, readonly) NSSet *allKeys;

/**
 Contains all secret GPG keys available.
 */
@property (nonatomic, strong, readonly) NSSet *secretKeys;

@end
