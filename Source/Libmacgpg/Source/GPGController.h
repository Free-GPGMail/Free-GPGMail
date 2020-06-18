/*
 Copyright © Roman Zechmeister, 2017
 
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
#import <Libmacgpg/GPGException.h>


@class GPGSignature;
@class GPGUserIDSignature;
@class GPGController;
@class GPGStream;
@class GPGRemoteKey;


@protocol GPGControllerDelegate
@optional

- (void)gpgController:(GPGController *)gpgc operationDidFinishWithReturnValue:(id)value;
- (void)gpgController:(GPGController *)gpgc operationThrownException:(NSException *)e;
- (void)gpgController:(GPGController *)gpgc keysDidChanged:(NSObject <EnumerationList> *)keys external:(BOOL)external;
- (void)gpgControllerOperationDidStart:(GPGController *)gpgc;
- (void)gpgController:(GPGController *)gpgc progressed:(NSInteger)progressed total:(NSInteger)total;
- (BOOL)gpgControllerShouldDecryptWithoutMDC:(GPGController *)gpgc;


@end



@interface GPGController : NSObject {
	NSMutableArray <NSObject <KeyFingerprint> *> *signerKeys;
	NSMutableArray <NSString *> *comments;
	NSMutableArray <GPGSignature *> *signatures;
	NSString *filename; //May contain the filename after decryption.
	NSString *forceFilename; //May contain the filename after decryption.
	NSString *keyserver;
	NSUInteger keyserverTimeout;
	NSString *proxyServer;
	NSString *gpgHome;
	NSString *passphrase;
	NSDictionary *userInfo;
	NSUndoManager *undoManager;
	BOOL useArmor;
	BOOL useTextMode;
	BOOL printVersion;
	BOOL useDefaultComments;
	BOOL trustAllKeys;
	BOOL async;
	BOOL autoKeyRetrieve;
	BOOL allowNonSelfsignedUid;
	BOOL allowWeakDigestAlgos;
    id lastReturnValue;
	NSDictionary *_pinentryInfo;
    
    GPGHashAlgorithm hashAlgorithm;
    
	
	NSObject <GPGControllerDelegate> *delegate;
	NSException *error;

	
	//Private
	NSString *identifier;
	id asyncProxy; //AsyncProxy
	GPGSignature *lastSignature;
	GPGTask *gpgTask;
	BOOL asyncStarted;
	BOOL canceled;
	NSInteger runningOperations;
	NSUInteger groupedKeyChange;
	NSUInteger timeout;
	BOOL decrypted;
	
	NSMutableSet *gpgKeyservers;
}

@property (nonatomic, assign) NSObject <GPGControllerDelegate> *delegate;
@property (nonatomic, readonly) NSArray <NSObject <KeyFingerprint> *> *signerKeys;
@property (nonatomic, readonly) NSArray <NSString *> *comments;
@property (nonatomic, readonly) NSArray <GPGSignature *> *signatures;
@property (nonatomic, readonly) id lastReturnValue;
@property (nonatomic, readonly) NSException *error;
@property (nonatomic, readonly, retain) NSString *filename;
@property (nonatomic, strong) NSString *forceFilename;
@property (nonatomic, strong) NSString *keyserver;
@property (nonatomic, strong) NSString *proxyServer;
@property (nonatomic, strong) NSString *gpgHome;
@property (nonatomic, strong) NSString *passphrase;
@property (nonatomic) NSUInteger keyserverTimeout;
@property (nonatomic, retain) NSDictionary *userInfo;
@property (nonatomic, retain) NSUndoManager *undoManager;
@property (nonatomic, readonly) BOOL decryptionOkay;
@property (nonatomic, readonly) BOOL wasSigned;
@property (nonatomic) BOOL async;
@property (nonatomic) BOOL useArmor;
@property (nonatomic) BOOL useTextMode;
@property (nonatomic) BOOL printVersion;
@property (nonatomic) BOOL useDefaultComments;
@property (nonatomic) BOOL trustAllKeys;
@property (nonatomic) BOOL autoKeyRetrieve;
@property (nonatomic) BOOL allowNonSelfsignedUid;
@property (nonatomic) BOOL allowWeakDigestAlgos;
@property (nonatomic, readonly) NSDictionary *statusDict;
@property (nonatomic, readonly) GPGHashAlgorithm hashAlgorithm;
@property (nonatomic, readonly, retain) GPGTask *gpgTask;
@property (nonatomic, assign) NSUInteger timeout DEPRECATED_ATTRIBUTE;
/*
 Dictionary with following keys:
 DESCRIPTION: The description displayed in pinentry. Usable playceholders: %FINGERPRINT, %KEYID, %USERID, %EMAIL, %COMMENT, %NAME.
 ICON: The image displayed in pinentry.
 A percent char '%', not used in a placeholder, needs to be replaced with '%25'.
*/
@property (nonatomic, retain) NSDictionary *pinentryInfo; // Needs to percent escaped. 


+ (NSString *)gpgVersion;
+ (NSSet *)publicKeyAlgorithm;
+ (NSSet *)cipherAlgorithm;
+ (NSSet *)digestAlgorithm;
+ (NSSet *)compressAlgorithm;
+ (GPGErrorCode)testGPG;
+ (GPGErrorCode)testGPGError:(NSException **)error;

+ (NSString *)nameForHashAlgorithm:(GPGHashAlgorithm)hashAlgorithm;

- (void)setComment:(NSString *)comment;
- (void)addComment:(NSString *)comment;
- (void)removeCommentAtIndex:(NSUInteger)index;
- (void)setSignerKey:(NSObject <KeyFingerprint> *)signerKey;
- (void)addSignerKey:(NSObject <KeyFingerprint> *)signerKey;
- (void)removeSignerKeyAtIndex:(NSUInteger)index;


+ (id)gpgController;
- (BOOL)isPassphraseForKeyInCache:(NSObject <KeyFingerprint> *)key;
- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSObject <KeyFingerprint> *)key;
- (BOOL)isPassphraseForKeyInKeychain:(NSObject <KeyFingerprint> *)key;
- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key;
- (NSInteger)indexOfSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key;


- (void)cancel;

- (void)cleanKey:(NSObject <KeyFingerprint> *)key;
- (void)cleanKeys:(NSObject <EnumerationList> *)keys;
- (void)minimizeKeys:(NSObject <EnumerationList> *)keys;
- (void)minimizeKey:(NSObject <KeyFingerprint> *)key;
- (void)addPhotoFromPath:(NSString *)path toKey:(NSObject <KeyFingerprint> *)key;
- (void)removeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport;
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport;
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys options:(GPGExportOptions)options;
- (NSData *)generateRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(int)type local:(BOOL)local daysToExpire:(int)daysToExpire;
- (void)signUserIDs:(NSArray <GPGUserID *> *)userIDs signerKey:(NSObject <KeyFingerprint> *)signerKey local:(BOOL)local daysToExpire:(int)daysToExpire;
- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addUserIDToKey:(NSObject <KeyFingerprint> *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment;
- (void)setExpirationDateForSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key daysToExpire:(NSUInteger)daysToExpire;
- (void)setExpirationDate:(NSDate *)expirationDate forSubkeys:(NSArray *)subkeys ofKey:(NSObject <KeyFingerprint> *)key;
- (void)changePassphraseForKey:(NSObject <KeyFingerprint> *)key;
- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys;
- (NSString *)refreshKeysFromServer:(NSObject <EnumerationList> *)keys;
- (NSArray <GPGRemoteKey *> *)searchKeysOnServer:(NSString *)pattern;
- (void)sendKeysToServer:(NSObject <EnumerationList> *)keys;
- (void)testKeyserver;
- (void)testKeyserverWithCompletionHandler:(void (^)(BOOL working))completionHandler;
- (void)keysExistOnServer:(NSArray <GPGKey *> *)keys callback:(void (^)(NSArray <GPGKey *> *existingKeys, NSArray <GPGKey *> *nonExistingKeys))callback;
- (void)removeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)setPrimaryUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (NSString *)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment
							 keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(int)keyLength
						  subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(int)subkeyLength
						daysToExpire:(int)daysToExpire preferences:(NSString *)preferences;
- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode;
- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)key:(NSObject <KeyFingerprint> *)key setDisabled:(BOOL)disabled;
- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust DEPRECATED_ATTRIBUTE;
- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrust:(GPGValidity)trust;

- (void)processTo:(GPGStream *)output data:(GPGStream *)input withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients;
- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients;

- (void)decryptTo:(GPGStream *)output data:(GPGStream *)input;
- (NSData *)decryptData:(NSData *)data;

- (NSArray <GPGSignature *> *)verifySignatureOf:(GPGStream *)signatureInput originalData:(GPGStream *)originalInput;
- (NSArray <GPGSignature *> *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData;

- (NSArray <GPGSignature *> *)verifySignedData:(NSData *)signedData;
- (NSArray <NSDictionary *> *)algorithmPreferencesForKey:(GPGKey *)key;


@end


