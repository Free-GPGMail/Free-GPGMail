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

#import "GPGSignature.h"
#import "GPGKey.h"
#import "GPGTransformer.h"
#import "GPGTypesRW.h"


@implementation GPGSignature
@synthesize trust=_trust, status=_status, fingerprint=_fingerprint, creationDate=_creationDate, expirationDate=_expirationDate, version=_version, publicKeyAlgorithm=_publicKeyAlgorithm, hashAlgorithm=_hashAlgorithm, key=_key, signatureClass=_signatureClass;

- (instancetype)init {
	return [self initWithFingerprint:nil status:GPGErrorGeneralError];
}

- (instancetype)initWithFingerprint:(NSString *)fingerprint status:(GPGErrorCode)status {
	if(self = [super init]) {
		_fingerprint = [fingerprint copy];
		_status = status;
	}
	return self;
}

- (GPGKey *)primaryKey {
	return self.key.primaryKey;
}

- (NSString *)userIDDescription {
	return self.primaryKey.userIDDescription;
}

- (NSString *)name {
	return self.primaryKey.name;
}

- (NSString *)email {
	return self.primaryKey.email;
}

- (NSString *)comment {
	return self.primaryKey.comment;
}

- (NSString *)primaryFingerprint {
	return self.primaryKey.fingerprint;
}

- (NSImage *)image {
	return self.primaryKey.image;
}


- (void)dealloc {
	_trust = GPGValidityUnknown;
	_status = GPGErrorGeneralError;
	
	[_fingerprint release];
	_fingerprint = nil;
	[_creationDate release];
	_creationDate = nil;
	[_expirationDate release];
	_expirationDate = nil;
	_version = 0;
	_publicKeyAlgorithm = 0;
	_hashAlgorithm = 0;
	
	[_key release];
	_key = nil;
		
	[super dealloc];
}

- (NSString *)humanReadableDescription {
    return [self humanReadableDescriptionShouldLocalize:YES];
}

#define maybeLocalize(key) (shouldLocalize ? localizedLibmacgpgString(key) : key)

- (NSString *)humanReadableDescriptionShouldLocalize:(BOOL)shouldLocalize {
    NSString *sigStatus;
    switch (self.status) {
        case GPGErrorNoError:
            sigStatus = maybeLocalize(@"Signed");
            break;
        case GPGErrorSignatureExpired:
        case GPGErrorKeyExpired:
            sigStatus = maybeLocalize(@"Signature expired");
            break;
        case GPGErrorCertificateRevoked:
            sigStatus = maybeLocalize(@"Signature revoked");
            break;
        case GPGErrorUnknownAlgorithm:
            sigStatus = maybeLocalize(@"Unverifiable signature");
            break;
        case GPGErrorNoPublicKey:
            sigStatus = maybeLocalize(@"Signed by stranger");
            break;
        case GPGErrorBadSignature:
            sigStatus = maybeLocalize(@"Bad signature");
            break;
        default:
            sigStatus = maybeLocalize(@"Signature error");
            break;
    }
    
    NSMutableString *desc = [NSMutableString stringWithString:sigStatus];
    if (self.userIDDescription && [self.userIDDescription length]) {
        [desc appendFormat:@" (%@)", self.userIDDescription];
    }
    else if (self.fingerprint && [self.fingerprint length]) {
        GPGKeyAlgorithmNameTransformer *algTransformer = [[GPGKeyAlgorithmNameTransformer alloc] init];
        algTransformer.keepUnlocalized = !shouldLocalize;

        NSString *algorithmDesc = [algTransformer transformedIntegerValue:self.publicKeyAlgorithm];
        [desc appendFormat:@" (%@ %@)", self.fingerprint, algorithmDesc];
        [algTransformer release];
    }
    
    return desc;
}

@end
