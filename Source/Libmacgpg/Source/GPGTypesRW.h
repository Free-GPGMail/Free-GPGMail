/* GPGTypesRW.h created by Lukas Pitschl (@lukele) on Sun 21-Jul-2014 */

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
 *     * Neither the name of GPGTools Team nor the names of Libmacgpg
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

#import <Libmacgpg/GPGKey.h>
#import <Libmacgpg/GPGUserID.h>
#import <Libmacgpg/GPGUserIDSignature.h>
#import <Libmacgpg/GPGSignature.h>


@interface GPGKey ()

@property (nonatomic, copy, readwrite) NSString *keyID;
@property (nonatomic, copy, readwrite) NSString *fingerprint;
@property (nonatomic, copy, readwrite) NSString *cardID;
@property (nonatomic, copy, readwrite) NSDate *creationDate;
@property (nonatomic, copy, readwrite) NSDate *expirationDate;
@property (nonatomic, assign, readwrite) unsigned int length;
@property (nonatomic, assign, readwrite) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, assign, readwrite) GPGValidity ownerTrust;
@property (nonatomic, assign, readwrite) GPGValidity validity;

@property (nonatomic, copy, readwrite) NSArray *subkeys;
@property (nonatomic, copy, readwrite) NSArray *userIDs;
@property (nonatomic, copy, readwrite) NSArray *signatures;

@property (nonatomic, assign, readwrite) GPGKey *primaryKey;
@property (nonatomic, assign, readwrite) GPGUserID *primaryUserID;

@property (nonatomic, assign, readwrite) BOOL secret;

@property (nonatomic, assign, readwrite) BOOL canSign;
@property (nonatomic, assign, readwrite) BOOL canEncrypt;
@property (nonatomic, assign, readwrite) BOOL canCertify;
@property (nonatomic, assign, readwrite) BOOL canAuthenticate;
@property (nonatomic, assign, readwrite) BOOL canAnySign;
@property (nonatomic, assign, readwrite) BOOL canAnyEncrypt;
@property (nonatomic, assign, readwrite) BOOL canAnyCertify;
@property (nonatomic, assign, readwrite) BOOL canAnyAuthenticate;

@property (nonatomic, assign, readwrite) BOOL mdcSupport;

@end

@interface GPGUserID ()

@property (nonatomic, copy, readwrite) NSString *userIDDescription;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *email;
@property (nonatomic, copy, readwrite) NSString *comment;
@property (nonatomic, copy, readwrite) NSString *hashID;
@property (nonatomic, copy, readwrite) NSImage *image;
@property (nonatomic, copy, readwrite) NSDate *creationDate;
@property (nonatomic, copy, readwrite) NSDate *expirationDate;
@property (nonatomic, assign, readwrite) GPGValidity validity;

@property (nonatomic, copy, readwrite) NSArray *signatures;
@property (nonatomic, assign, readwrite) GPGKey *primaryKey;

@property (nonatomic, assign, readwrite) BOOL mdcSupport;
@property (nonatomic, assign, readwrite) BOOL isUat;

@end

@interface GPGUserIDSignature ()

@property (nonatomic, copy, readwrite) NSString *keyID;
@property (nonatomic, assign, readwrite) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, copy, readwrite) NSDate *creationDate;
@property (nonatomic, copy, readwrite) NSDate *expirationDate;
@property (nonatomic, copy, readwrite) NSString *reason;
@property (nonatomic, assign, readwrite) int signatureClass;
@property (nonatomic, assign, readwrite) BOOL revocation;
@property (nonatomic, assign, readwrite) BOOL local;
@property (nonatomic, assign, readwrite) BOOL mdcSupport;
@property (nonatomic, assign, readwrite) BOOL selfSignature;
@property (nonatomic, assign, readwrite) GPGHashAlgorithm hashAlgorithm;
@property (nonatomic, assign, readwrite) GPGValidity validity;

@property (nonatomic, assign, readwrite) GPGKey *primaryKey;

@end

@interface GPGSignature ()

@property (nonatomic, assign, readwrite) GPGValidity trust;
@property (nonatomic, assign, readwrite) GPGErrorCode status;
@property (nonatomic, copy, readwrite) NSString *fingerprint;
@property (nonatomic, copy, readwrite) NSDate *creationDate;
@property (nonatomic, assign, readwrite) int signatureClass;
@property (nonatomic, copy, readwrite) NSDate *expirationDate;
@property (nonatomic, assign, readwrite) int version;
@property (nonatomic, assign, readwrite) GPGPublicKeyAlgorithm publicKeyAlgorithm;
@property (nonatomic, assign, readwrite) GPGHashAlgorithm hashAlgorithm;

@end

