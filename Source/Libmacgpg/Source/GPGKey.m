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

#import <Libmacgpg/GPGKey.h>
#import <Libmacgpg/GPGTypesRW.h>


@implementation GPGKey
@synthesize subkeys=_subkeys, userIDs=_userIDs, signatures=_signatures, fingerprint=_fingerprint, cardID=_cardID, ownerTrust=_ownerTrust, secret=_secret, canSign=_canSign, canEncrypt=_canEncrypt, canCertify=_canCertify, canAuthenticate=_canAuthenticate, canAnySign=_canAnySign, canAnyEncrypt=_canAnyEncrypt, canAnyCertify=_canAnyCertify, canAnyAuthenticate=_canAnyAuthenticate, textForFilter=_textForFilter, primaryKey=_primaryKey, primaryUserID=_primaryUserID, keyID=_keyID, allFingerprints=_fingerprints, expirationDate=_expirationDate, creationDate=_creationDate, length=_length, algorithm=_algorithm, validity=_validity;

- (instancetype)init {
	return [self initWithFingerprint:nil];
}

- (instancetype)initWithFingerprint:(NSString *)fingerprint {
	if(self = [super init]) {
		_fingerprint = [fingerprint copy];
		// Each semaphore can be consumed exactly once, that's why it's initiated with 1.
		_textForFilterOnce = dispatch_semaphore_create(1);
		_fingerprintsOnce = dispatch_semaphore_create(1);
	}
	return self;
}

- (void)setSubkeys:(NSArray *)subkeys {
	if(subkeys != _subkeys)
		[_subkeys release];
	
	_subkeys = [subkeys copy];
	// This gpg key will become the primary key of
	// each subkey.
	for(GPGKey *subkey in _subkeys)
		subkey.primaryKey = self;
}

- (void)setUserIDs:(NSArray *)userIDs {
	if(userIDs != _userIDs)
		[_userIDs release];
	
	_userIDs = [userIDs copy];
	if([_userIDs count])
		self.primaryUserID = [_userIDs objectAtIndex:0];
}
- (void)setSignatures:(NSArray *)signatures {
	if (signatures != _signatures) {
		id oldValue = _signatures;
		_signatures = [signatures copy];
		[oldValue release];
		
		GPGUserIDSignature *revSig = nil;
		for (GPGUserIDSignature *sig in signatures) {
			if (sig.revocation) {
				revSig = sig;
				break;
			}
		}
		if (revSig != _revocationSignature) {
			oldValue = _revocationSignature;
			_revocationSignature = [revSig retain];
			[oldValue release];
		}

	}
}
- (NSArray *)signatures {
	return [[_signatures retain] autorelease];
}
- (GPGUserIDSignature *)revocationSignature {
	return [[_revocationSignature retain] autorelease];
}

- (NSString *)email {
	return self.primaryUserID.email;
}

- (NSString *)name {
	return self.primaryUserID.name;
}

- (NSString *)comment {
	return self.primaryUserID.comment;
}

- (BOOL)disabled {
	return _validity & GPGValidityDisabled;
}
- (BOOL)revoked {
	return _validity & GPGValidityRevoked;
}
- (BOOL)invalid {
	return _validity & GPGValidityInvalid;
}
- (BOOL)expired {
	return _validity & GPGValidityExpired;
}

- (NSString *)userIDDescription {
	return self.primaryUserID.userIDDescription;
}

- (NSImage *)image {
	return self.primaryUserID.image;
}

- (NSSet *)allFingerprints {
	dispatch_semaphore_wait(_fingerprintsOnce, DISPATCH_TIME_FOREVER);
	if(!_fingerprints) {
		NSMutableSet *fingerprints = [[NSMutableSet alloc] initWithCapacity:[self.subkeys count] + 1];
		[fingerprints addObject:self.fingerprint];
		if([self.subkeys count])
			[fingerprints addObjectsFromArray:[self.subkeys valueForKey:@"fingerprint"]];
		_fingerprints = [fingerprints copy];
		[fingerprints release];
	}
	dispatch_semaphore_signal(_fingerprintsOnce);
	
	return [[_fingerprints retain] autorelease];
}

- (NSString *)textForFilter {
	dispatch_semaphore_wait(_textForFilterOnce, DISPATCH_TIME_FOREVER);
	if(!_textForFilter) {
		NSMutableString *textForFilter = [[NSMutableString alloc] init];
		[textForFilter appendFormat:@"0x%@\n0x%@\n0x%@\n", self.fingerprint, self.keyID, [self.keyID shortKeyID]];
		for(GPGKey *key in self.subkeys) {
			[textForFilter appendFormat:@"0x%@\n0x%@\n0x%@\n", key.fingerprint, key.keyID, [key.keyID shortKeyID]];
		}
		for(GPGUserID *userID in self.userIDs) {
			[textForFilter appendFormat:@"%@\n", userID.userIDDescription];
		}
		_textForFilter = [textForFilter copy];
		[textForFilter release];
	}
	dispatch_semaphore_signal(_textForFilterOnce);
	
	return [[_textForFilter retain] autorelease];
}

- (BOOL)isSubkey {
	return self.primaryKey != self;
}

- (NSString *)shortKeyID {
	return [self.keyID shortKeyID];
}

- (NSInteger)status {
	return 0;
}

- (NSUInteger)hash {
	return [self.fingerprint hash];
}

- (BOOL)isEqual:(id)anObject {
	return [self.fingerprint isEqualToString:[anObject description]];
}

- (NSString *)description {
	return self.fingerprint;
}

- (id)copy {
	return [self retain];
}

- (void)dealloc {
	[_keyID release];
	_keyID = nil;
	[_fingerprint release];
	_fingerprint = nil;
	// Make sure that each subkey which might survive
	// the parent has a primaryKey, otherwise a dangling
	// pointer might lead to a crash.
	for(GPGKey *key in _subkeys)
		key.primaryKey = nil;
	[_subkeys release];
	_subkeys = nil;
	for(GPGUserID *userID in _userIDs)
		userID.primaryKey = nil;
	[_userIDs release];
	_userIDs = nil;
	
	[_signatures release];
	_signatures = nil;
	
	[_cardID release];
	_cardID = nil;
	
	[_revocationSignature release];
	_revocationSignature = nil;
	
	
	dispatch_release(_textForFilterOnce);
	_textForFilterOnce = NULL;
	[_textForFilter release];
	_textForFilter = nil;
	
	dispatch_release(_fingerprintsOnce);
	_fingerprintsOnce = NULL;
	[_fingerprints release];
	_fingerprints = nil;
	
	_primaryKey = nil;
	_primaryUserID = nil;
	
	_secret = NO;
	_canEncrypt = NO;
	_canSign = NO;
	_ownerTrust = GPGValidityUnknown;
	
	[super dealloc];
}

@end
