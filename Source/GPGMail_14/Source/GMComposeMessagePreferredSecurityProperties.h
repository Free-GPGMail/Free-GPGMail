//
//  GMComposeMessagePreferredSecurityProperties.h
//  GPGMail
//
//  Created by Lukas Pitschl on 22.11.16.
//
//

#import <Foundation/Foundation.h>

#import "GPGConstants.h"

#import "MCMessage.h"
#import "ComposeBackEnd.h"

@class GPGKey;

typedef enum {
    ThreeStateBooleanFalse,
    ThreeStateBooleanTrue,
    ThreeStateBooleanUndetermined
} ThreeStateBoolean;

@interface GMComposeMessagePreferredSecurityProperties : NSObject {
    BOOL _messageIsDraft;
    BOOL _messageIsReply;
    BOOL _messageIsFowarded;
    
    NSDictionary *_SMIMESigningIdentities;
    NSDictionary *_SMIMEEncryptionCertificates;
    
    NSDictionary *_PGPSigningKeys;
    NSDictionary *_PGPEncryptionKeys;
    
    ThreeStateBoolean _userShouldSignMessage;
    ThreeStateBoolean _userShouldEncryptMessage;

    GPGKey *_signingKey;
    NSString *_signingSender;

    // Bug #957: Adapt GPGMail to the S/MIME changes introduced in Mail for 10.13.2b3
    NSError *_invalidSigningIdentityError;
}

+ (GPGMAIL_SECURITY_METHOD)defaultSecurityMethod;

- (id)initWithSender:(NSString *)sender recipients:(NSArray *)recipients;
- (id)initWithSender:(NSString *)sender signingKey:(GPGKey *)signingKey invalidSigningIdentityError:(NSError *)invalidSigningIdentitiyError recipients:(NSArray *)recipients userShouldSignMessage:(ThreeStateBoolean)userShouldSign userShouldEncryptMessage:(ThreeStateBoolean)userShouldEncrypt;
- (void)addHintsFromBackEnd:(ComposeBackEnd *)backEnd;

- (void)computePreferredSecurityPropertiesForSecurityMethod:(GPGMAIL_SECURITY_METHOD)securityMethod;

- (void)updateSigningKey:(GPGKey *)signingKey forSender:(NSString *)sender;

- (GPGKey *)encryptionKeyForDraft;

@property (nonatomic, readonly, assign) BOOL canPGPSign;
@property (nonatomic, readonly, assign) BOOL canPGPEncrypt;
@property (nonatomic, readonly, assign) BOOL canSMIMESign;
@property (nonatomic, readonly, assign) BOOL canSMIMEEncrypt;

@property (nonatomic, readonly, copy) NSDictionary *SMIMESigningIdentities;
@property (nonatomic, readonly, copy) NSDictionary *SMIMEEncryptionCertificates;

@property (nonatomic, readonly, copy) NSDictionary *PGPSigningKeys;
@property (nonatomic, readonly, copy) NSDictionary *PGPEncryptionKeys;

@property (nonatomic, readonly, assign) BOOL canSign;
@property (nonatomic, readonly, assign) BOOL canEncrypt;

/* Computed properties which will either return the user decision (userShouldSignMessage, userShouldEncryptMessage)
 * if available, or otherwise the best default based on GPGMail settings.
 */
@property (nonatomic, readonly, assign) BOOL shouldSignMessage;
@property (nonatomic, readonly, assign) BOOL shouldEncryptMessage;

/* These two properties store the status that the user chose, by clicking on the
 * sign or encrypt button. Internally these bools use a three state boolean.
 *
 * IMPORTANT: You must only write this property, not read it. should<Sign|Ecnrypt>Message will contain
 * the correct status to use.
 */
@property (nonatomic, assign) ThreeStateBoolean userShouldSignMessage;
@property (nonatomic, assign) ThreeStateBoolean userShouldEncryptMessage;

@property (nonatomic, readonly, assign) BOOL shouldSignDecidedByUser;

@property (nonatomic, copy) NSString *sender;
@property (nonatomic, copy) NSArray *recipients;

@property (nonatomic, readonly, retain) GPGKey *signingKey;
@property (nonatomic, readonly, retain) NSString *signingSender;

@property (nonatomic, copy) NSDictionary *cachedSigningIdentities;
@property (nonatomic, copy) NSDictionary *cachedEncryptionCertificates;

@property (nonatomic, readwrite, assign) GPGMAIL_SECURITY_METHOD securityMethod;

@property (nonatomic, readonly, retain) MCMessage *message;

@property (nonatomic, readonly, assign) BOOL userDidChooseSecurityMethod;

@property (nonatomic, readonly, copy) NSError *invalidSigningIdentityError;

@end
