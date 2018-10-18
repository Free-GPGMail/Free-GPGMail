/*
 Copyright © Roman Zechmeister und Lukas Pitschl (@lukele), 2017
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
 */

#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGUserID.h>
@class GPGUserIDSignature;

@interface GPGKey : NSObject <KeyFingerprint, GPGUserIDProtocol> {
	NSString *_keyID;
	NSString *_fingerprint;
	NSString *_cardID; // The id of the smartcard, the key is located on. Only on secret keys.
	NSDate *_creationDate;
	NSDate *_expirationDate;
	unsigned int _length;
	GPGValidity _ownerTrust;
	GPGValidity _validity;
	GPGPublicKeyAlgorithm _algorithm;
	BOOL _secret;
	
	BOOL _canSign;
	BOOL _canEncrypt;
	BOOL _canCertify;
	BOOL _canAuthenticate;
	
	// All the any* properties are based on the properties
	// of subkeys and key together.
	BOOL _canAnySign;
	BOOL _canAnyEncrypt;
	BOOL _canAnyCertify;
	BOOL _canAnyAuthenticate;
	
	
	NSArray *_subkeys;
	NSArray *_userIDs;
	NSArray *_signatures;
	GPGUserIDSignature *_revocationSignature;
	
	// Contains all information of the key concatenated for quicker search.
	NSString *_textForFilter;
	dispatch_semaphore_t _textForFilterOnce;
	// Contains all fingerprints of subkeys.
	NSSet *_fingerprints;
	dispatch_semaphore_t _fingerprintsOnce;
	
	// If this is a subkey, points to its primaryKey, otherwise
	// to self.
	GPGKey *_primaryKey;
	GPGUserID *_primaryUserID;
}

- (instancetype)initWithFingerprint:(NSString *)fingerprint;
- (void)setSubkeys:(NSArray *)subkeys;
- (void)setUserIDs:(NSArray *)userIDs;

@property (copy, nonatomic, readonly) NSString *keyID;
@property (copy, nonatomic, readonly) NSString *shortKeyID;
@property (copy, nonatomic, readonly) NSString *fingerprint;
@property (copy, nonatomic, readonly) NSString *cardID;
@property (copy, nonatomic, readonly) NSDate *creationDate;
@property (copy, nonatomic, readonly) NSDate *expirationDate;
@property (nonatomic, readonly) unsigned int length;
@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, readonly) NSInteger status DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly) GPGValidity ownerTrust;
@property (nonatomic, readonly) GPGValidity validity;

@property (nonatomic, readonly) NSArray *subkeys;
@property (nonatomic, readonly) NSArray *userIDs;
@property (nonatomic, readonly) NSArray *signatures;
@property (nonatomic, readonly) GPGUserIDSignature *revocationSignature;

@property (nonatomic, readonly) GPGKey *primaryKey;
@property (nonatomic, readonly) GPGUserID *primaryUserID;

@property (nonatomic, readonly) BOOL secret;
@property (nonatomic, readonly) BOOL disabled;
@property (nonatomic, readonly) BOOL invalid;
@property (nonatomic, readonly) BOOL revoked;
@property (nonatomic, readonly) BOOL expired;

@property (nonatomic, readonly) BOOL isSubkey;

@property (nonatomic, readonly) BOOL canSign;
@property (nonatomic, readonly) BOOL canEncrypt;
@property (nonatomic, readonly) BOOL canCertify;
@property (nonatomic, readonly) BOOL canAuthenticate;
@property (nonatomic, readonly) BOOL canAnySign;
@property (nonatomic, readonly) BOOL canAnyEncrypt;
@property (nonatomic, readonly) BOOL canAnyCertify;
@property (nonatomic, readonly) BOOL canAnyAuthenticate;

@property (nonatomic, readonly) BOOL mdcSupport;

// Calculated properties.
@property (nonatomic, readonly) NSString *textForFilter;
@property (nonatomic, readonly) NSSet *allFingerprints;

// Properties of the primary user ID.
@property (nonatomic, readonly) NSString *userIDDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;
@property (nonatomic, readonly) NSImage *image;

@end
