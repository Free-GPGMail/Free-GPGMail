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

#import "Libmacgpg.h"
#import "GPGTaskOrder.h"
#import "GPGTypesRW.h"
#import "GPGKeyserver.h"
#import "GPGTaskHelper.h"
#import "GPGWatcher.h"
#import "GPGTask_Private.h"
#import "GPGVerifyingKeyserver.h"
#import <sys/stat.h>
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
#import "GPGTaskHelperXPC.h"
#import "NSBundle+Sandbox.h"
#endif

#define cancelCheck if (canceled) {@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Operation cancelled") errorCode:GPGErrorCancelled];}


static NSString * const keysOnServerCacheKey = @"KeysOnServerCache";

@interface GPGController () <GPGTaskDelegate>
@property (nonatomic, retain) GPGSignature *lastSignature;
@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) GPGTask *gpgTask;
- (void)addArgumentsForKeyserver;
- (void)addArgumentsForSignerKeys;
- (void)addArgumentsForComments;
- (void)addArgumentsForOptions;
- (void)operationDidStart;
- (void)handleException:(NSException *)e;
- (void)operationDidFinishWithReturnValue:(id)value;
- (void)keysHaveChanged:(NSNotification *)notification;
- (void)cleanAfterOperation;
- (void)keysChanged:(NSObject <EnumerationList> *)keys;
- (void)keyChanged:(NSObject <KeyFingerprint> *)key;
+ (GPGErrorCode)readGPGConfig;
+ (GPGErrorCode)readGPGConfigError:(NSException **)error;
- (void)setLastReturnValue:(id)value;
- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName;
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys;
- (void)logException:(NSException *)e;
@end


@implementation GPGController
@synthesize delegate, keyserver, keyserverTimeout, proxyServer, async, userInfo, useArmor, useTextMode, printVersion, useDefaultComments,
trustAllKeys, signatures, lastSignature, gpgHome, passphrase, autoKeyRetrieve, lastReturnValue, error, undoManager, hashAlgorithm,
timeout, filename, forceFilename, pinentryInfo=_pinentryInfo, allowNonSelfsignedUid, allowWeakDigestAlgos;

NSString *gpgVersion = nil;
NSSet *publicKeyAlgorithm = nil, *cipherAlgorithm = nil, *digestAlgorithm = nil, *compressAlgorithm = nil;
BOOL gpgConfigReaded = NO;



+ (NSString *)gpgVersion {
	[self readGPGConfig];
	return gpgVersion;
}
+ (NSSet *)publicKeyAlgorithm {
	[self readGPGConfig];
	return publicKeyAlgorithm;
}
+ (NSSet *)cipherAlgorithm {
	[self readGPGConfig];
	return cipherAlgorithm;
}
+ (NSSet *)digestAlgorithm {
	[self readGPGConfig];
	return digestAlgorithm;
}
+ (NSSet *)compressAlgorithm {
	[self readGPGConfig];
	return compressAlgorithm;
}

+ (NSString *)nameForHashAlgorithm:(GPGHashAlgorithm)hashAlgorithm {
    NSString *hashAlgorithmName = nil;
    
    switch (hashAlgorithm) {
        case GPGHashAlgorithmMD5:
            hashAlgorithmName = @"md5";
            break;
        
        case GPGHashAlgorithmSHA1:
            hashAlgorithmName = @"sha1";
            break;
        
        case GPGHashAlgorithmRMD160:
            hashAlgorithmName = @"ripemd160";
            break;
        
        case GPGHashAlgorithmSHA256:
            hashAlgorithmName = @"sha256";
            break;
        
        case GPGHashAlgorithmSHA384:
            hashAlgorithmName = @"sha384";
            break;
        
        case GPGHashAlgorithmSHA512:
            hashAlgorithmName = @"sha512";
            break;
        
        case GPGHashAlgorithmSHA224:
            hashAlgorithmName = @"sha225";
            break;
            
        default:
            break;
    }
    
    return hashAlgorithmName;
}




- (NSArray <NSString *> *)comments {
	return [[comments copy] autorelease];
}
- (NSArray <NSObject <KeyFingerprint> *> *)signerKeys {
	return [[signerKeys copy] autorelease];
}
- (void)setComment:(NSString *)comment {
	[self willChangeValueForKey:@"comments"];
	[comments removeAllObjects];
	if (comment) {
		[comments addObject:comment];
	}
	[self didChangeValueForKey:@"comments"];
}
- (void)addComment:(NSString *)comment {
	[self willChangeValueForKey:@"comments"];
	[comments addObject:comment];
	[self didChangeValueForKey:@"comments"];
}
- (void)removeCommentAtIndex:(NSUInteger)index {
	[self willChangeValueForKey:@"comments"];
	[comments removeObjectAtIndex:index];
	[self didChangeValueForKey:@"comments"];
}
- (void)setSignerKey:(NSObject <KeyFingerprint> *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeAllObjects];
	if (signerKey) {
		[signerKeys addObject:signerKey];
	}
	[self didChangeValueForKey:@"signerKeys"];
}
- (void)addSignerKey:(NSObject <KeyFingerprint> *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys addObject:signerKey];
	[self didChangeValueForKey:@"signerKeys"];
}
- (void)removeSignerKeyAtIndex:(NSUInteger)index {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeObjectAtIndex:index];
	[self didChangeValueForKey:@"signerKeys"];
}
- (BOOL)decryptionOkay {
	return error == nil && decrypted;
}
- (BOOL)wasSigned {
	return self.signatures.count > 0;
}
- (NSDictionary *)statusDict {
	return gpgTask.statusDict;
}
- (void)setGpgTask:(GPGTask *)value {
	if (value != gpgTask) {
		GPGTask *old = gpgTask;
		gpgTask = [value retain];
		[old release];
	}
}
- (GPGTask *)gpgTask {
	return [[gpgTask retain] autorelease];
}


#pragma mark Init

+ (id)gpgController {
	return [[[[self class] alloc] init] autorelease];
}

- (id)init {
	if ((self = [super init]) == nil) {
		return nil;
	}
	[self.class readGPGConfigError:nil];
	
	identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];
	comments = [[NSMutableArray alloc] init];
	signerKeys = [[NSMutableArray alloc] init];
	signatures = [[NSMutableArray alloc] init];
	gpgKeyservers = [[NSMutableSet alloc] init];
	keyserverTimeout = 30; // Give the slow keyservers some time to answer.
	asyncProxy = [[AsyncProxy alloc] initWithRealObject:self];
	useDefaultComments = YES;
	
	GPGOptions *options = [GPGOptions sharedOptions];
	id value;
	
	if ((value = [options valueInGPGConfForKey:@"armor"])) {
		GPGDebugLog(@"armor: %@", value);
		useArmor = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"emit-version"])) {
		GPGDebugLog(@"emit-version: %@", value);
		printVersion = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"textmode"])) {
		GPGDebugLog(@"textmode: %@", value);
		useTextMode = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"auto-key-retrieve"])) {
		GPGDebugLog(@"auto-key-retrieve: %@", value);
		autoKeyRetrieve = [value boolValue];
	}
	
	return self;
}


- (void)cancel {
	canceled = YES;
	if (gpgTask.isRunning) {
		[gpgTask cancel];
	}
	for (GPGKeyserver *server in gpgKeyservers) {
		if (server.isRunning) {
			[server cancel];
		}
	}
}


#pragma mark Encrypt, decrypt, sign and verify

- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy processData:data withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
		return nil;
	}

    GPGMemoryStream *output = [[GPGMemoryStream alloc] init];
    GPGMemoryStream *input = [GPGMemoryStream memoryStreamForReading:data];

    [self operationDidStart];
    [self processTo:output data:input withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
	[self cleanAfterOperation];
	NSData *processedData = [output readAllData];
	[self operationDidFinishWithReturnValue:processedData];
	[output release];
	return processedData;
}

- (void)processTo:(GPGStream *)output data:(GPGStream *)input withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject<EnumerationList> *)recipients hiddenRecipients:(NSObject<EnumerationList> *)hiddenRecipients {
    // asyncProxy not recognized here

	@try {		
		if ((mode & (GPGEncryptFlags | GPGSignFlags)) == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Unknown mode: %i!", mode];
		}
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
		// Should be YES maybe, but detached sign doesn't ask for a passphrase
		// so, basically, it's NO until further testing.
		gpgTask.batchMode = NO;
		
		[self addArgumentsForComments];
		[self addArgumentsForSignerKeys];
		
		
		if (mode & GPGPublicKeyEncrypt) {
			[gpgTask addArgument:@"--encrypt"];
			if ([recipients count] + [hiddenRecipients count] == 0) {
				[NSException raise:NSInvalidArgumentException format:@"No recipient specified!"];
			}
			
			Class gpgKeyClass = [GPGKey class];
			
			for (GPGKey *recipient in recipients) {
				[gpgTask addArgument:@"--recipient"];
				
				if ([recipient isKindOfClass:gpgKeyClass] && recipient.primaryKey != recipient) {
					// Is a subkey. Force gpg to use exact this subkey.
					[gpgTask addArgument:[NSString stringWithFormat:@"%@!", recipient.description]];
				} else {
					[gpgTask addArgument:recipient.description];
				}
			}
			for (GPGKey *recipient in hiddenRecipients) {
				[gpgTask addArgument:@"--hidden-recipient"];
				
				if ([recipient isKindOfClass:gpgKeyClass] && recipient.primaryKey != recipient) {
					// Is a subkey. Force gpg to use exact this subkey.
					[gpgTask addArgument:[NSString stringWithFormat:@"%@!", recipient.description]];
				} else {
					[gpgTask addArgument:recipient.description];
				}
			}
		}
		if (mode & GPGSymetricEncrypt) {
			[gpgTask addArgument:@"--symmetric"];
		}
		
		if ((mode & GPGSeparateSign) && (mode & GPGEncryptFlags)) {
			// save object; processTo: will overwrite without releasing
			GPGTask *tempTask = gpgTask;

			// create new in-memory writeable stream
			GPGMemoryStream *sigoutput = [GPGMemoryStream memoryStream];
			[self processTo:sigoutput data:input withEncryptSignMode:mode & ~(GPGEncryptFlags | GPGSeparateSign) recipients:nil hiddenRecipients:nil];
			input = sigoutput;

			// reset back to the outer gpg task
			self.gpgTask = tempTask;
		} else {
			switch (mode & GPGSignFlags & ~GPGSeparateSign) {
				case GPGSign:
					[gpgTask addArgument:@"--sign"];
					break;
				case GPGClearSign:
					[gpgTask addArgument:@"--clearsign"];
					break;
				case GPGDetachedSign:
					[gpgTask addArgument:@"--detach-sign"];
					break;
				case 0:
					if (mode & GPGSeparateSign) {
						[gpgTask addArgument:@"--sign"];
					}
					break;
				default:			
					[NSException raise:NSInvalidArgumentException format:@"Unknown sign mode: %i!", mode & GPGSignFlags];
					break;
			}			
		}
		if (self.forceFilename) {
			[gpgTask addArgument:@"--set-filename"];
			[gpgTask addArgument:self.forceFilename];
		}
		
		gpgTask.outStream = output;
		[gpgTask setInput:input];

		[gpgTask start];
		
		// The status FAILURE is issued, whenever a sign or encrypt operation failed.
		// It is better to only use FAILURE and ignore exitcode and other status codes.
		if (gpgTask.statusDict[@"FAILURE"]) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Encrypt/sign failed!") gpgTask:gpgTask];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	}	
}

- (NSData *)decryptData:(NSData *)data {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy decryptData:data];
		return nil;
	}
    
    GPGMemoryStream *output = [GPGMemoryStream memoryStream];
    GPGMemoryStream *input = [GPGMemoryStream memoryStreamForReading:data];

    [self operationDidStart];    
    [self decryptTo:output data:input];
    NSData *retVal = [output readAllData];
    [self cleanAfterOperation];
    [self operationDidFinishWithReturnValue:retVal];	
    return retVal;
}

- (GPGMemoryStream *)packetWithSignature:(GPGStream *)signature clearText:(NSData *)clearText {
	GPGPacketParser *parser = [[[GPGPacketParser alloc] initWithStream:signature] autorelease];
	GPGSignaturePacket *packet = (GPGSignaturePacket *)[parser nextPacket];
	
	if (packet.tag != GPGSignaturePacketTag) {
		return nil;
	}
	
	uint8 onePassSig[15];
	onePassSig[0] = 0x90; // One-Pass Signature Packet. Tag 4.
	onePassSig[1] = 0x0D; // Length.
	onePassSig[2] = 0x03; // Version 3.
	onePassSig[3] = (uint8)packet.type;
	onePassSig[4] = (uint8)packet.hashAlgorithm;
	onePassSig[5] = (uint8)packet.publicAlgorithm;
	const char *keyID = packet.keyID.UTF8String;
	onePassSig[6] = (uint8)hexToByte(keyID);
	onePassSig[7] = (uint8)hexToByte(keyID+2);
	onePassSig[8] = (uint8)hexToByte(keyID+4);
	onePassSig[9] = (uint8)hexToByte(keyID+6);
	onePassSig[10] = (uint8)hexToByte(keyID+8);
	onePassSig[11] = (uint8)hexToByte(keyID+10);
	onePassSig[12] = (uint8)hexToByte(keyID+12);
	onePassSig[13] = (uint8)hexToByte(keyID+14);
	onePassSig[14] = 1; // Last of this type.
	
	
	uint8 literal[12];
	NSUInteger length = clearText.length + 6;
	literal[0] = 0xCB; // Literal Data Packet. Tag 11.
	literal[1] = 0xFF; // Length encoded with 4 bytes.
	literal[2] = (length >> 24) & 0xFF;
	literal[3] = (length >> 16) & 0xFF;
	literal[4] = (length >> 8) & 0xFF;
	literal[5] = length & 0xFF;
	literal[6] = packet.type == 1 ? 't' : 'b'; // Binary or text.
	literal[7] = 0; // No filename.
	literal[8] = 0; // No Date (4 bytes).
	literal[9] = 0;
	literal[10] = 0;
	literal[11] = 0;
	
	
	NSMutableData *packetData = [NSMutableData data];
	[packetData appendBytes:onePassSig length:15];
	[packetData appendBytes:literal length:12];
	[packetData appendData:clearText];
	[packetData appendData:signature.readAllData];
	
	return [GPGMemoryStream memoryStreamForReading:packetData];
}

- (void)decryptTo:(GPGStream *)output data:(GPGStream *)input {
	@try {
		NSData *clearText = nil;
		input = [GPGUnArmor unArmor:input clearText:&clearText];
		
		if (clearText != nil) {
			// Build a new package for the clear-signed message.
			// Other possible solutions:
			// a. Do not unarmor clear-sigend messages. Drawback: Malformed messages can't be nadled.
			// b. Call verify and set clearText as decrypted content. Verify if this is secure!
			// c. Use this solution.
			
			GPGStream *packet = [self packetWithSignature:input clearText:clearText];
			if (packet) {
				input = packet;
			}
		}
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask setInput:input];
		gpgTask.outStream = output;
		
		[gpgTask addArgument:@"--decrypt"];
		
		[gpgTask start]; // Ignore exit code from gpg. It's useless.
		
		
		__block BOOL failed = NO;
		__block NSString *errorDecription = nil;
		__block GPGErrorCode errorCode = 0;
		NSArray <NSNumber *> *errorCodes = gpgTask.errorCodes;

		// Check the error codes and some specific status codes to detect errors or possible attacks.
		if (gpgTask.errorCode == GPGErrorCancelled) {
			failed = YES;
			errorCode = GPGErrorCancelled;
			errorDecription = @"Decryption cancelled!";
		}
			
		if (!failed && [errorCodes containsObject:@(GPGErrorBadMDC)]) {
			failed = YES;
			errorCode = GPGErrorBadMDC;
			errorDecription = @"Decryption failed: Bad MDC!";
		}
		if (!failed && [errorCodes containsObject:@(GPGErrorBadData)]) {
			failed = YES;
			errorCode = GPGErrorBadData;
			errorDecription = @"Decryption failed: Bad Data!";
		}
		if (!failed && [errorCodes containsObject:@(GPGErrorDecryptionFailed)]) {
			BOOL hasNoMDC = NO;
			BOOL otherError = NO;
			for (NSNumber *errorNumber in errorCodes) {
				switch (errorNumber.intValue) {
					case GPGErrorNoMDC:
						// Ignore a failed decryption because of NoMDC at this point.
						hasNoMDC = YES;
						break;
					case GPGErrorDecryptionFailed:
						break;
					case GPGErrorNoSecretKey:
						failed = YES;
						errorCode = GPGErrorNoSecretKey;
						errorDecription = @"Decryption failed: No secret key!";
					default: {
						otherError = YES;
						break;
					}
				}
			}
			
			if (!failed && otherError) {
				// Handle decrypt specific errors.
				NSArray *errors = gpgTask.statusDict[@"ERROR"];
				for (NSArray<NSString *> *parts in errors) {
					if (parts.count < 2) {
						continue;
					}
					GPGErrorCode theErrorCode = (GPGErrorCode)parts[1].integerValue & 0xFFFF;
					NSString *errorLocation = parts[0];
					
					if ([errorLocation isEqualToString:@"decrypt.algorithm"]) {
						failed = YES;
						errorCode = theErrorCode;
						errorDecription = @"Decryption failed: Algorithm!";
						break;
					} else if ([errorLocation isEqualToString:@"decrypt.keyusage"]) {
						if (theErrorCode == GPGErrorWrongKeyUsage) {
							failed = YES;
							errorCode = GPGErrorWrongKeyUsage;
							errorDecription = @"Decryption failed: Wrong key usage!";
							break;
						}
					} else if ([errorLocation isEqualToString:@"pkdecrypt_failed"]) {
						if (theErrorCode == GPGErrorBadPassphrase) {
							failed = YES;
							errorCode = GPGErrorBadPassphrase;
							errorDecription = @"Decryption failed: Bad passphrase!";
							break;
						}
					}
				}
			}
			
			
			
			if (!hasNoMDC && !failed) {
				// The decryption failed because of an unknwown reason.
				failed = YES;
				errorCode = GPGErrorDecryptionFailed;
				errorDecription = @"Decryption failed!";
			}
		}
		if (!failed && gpgTask.statusDict[@"NODATA"]) {
			failed = YES;
			errorCode = GPGErrorNoData;
			errorDecription = @"Decryption failed: No Data!";
		}
		if (!failed && gpgTask.statusDict[@"FAILURE"]) {
			failed = YES;
			// Unknown error.
			errorDecription = @"Decryption failed: Other Failure!";
		}
		if (!failed) {
			// Check if there is an unencrypted plaintext in an encrypted message.
			// Normally the plaintext should be in an encrypted packet, inside of the encrypted message.
			
			BOOL inDecryptedPacket = NO;
			BOOL hasUnencryptedPlaintext = NO;
			BOOL hasDecryptedPacket = NO;

			for (GPGStatusLine *status in gpgTask.statusArray) {
				switch (status.code) {
					case GPG_STATUS_BEGIN_DECRYPTION:
						inDecryptedPacket = YES;
						hasDecryptedPacket = YES;
						break;
					case GPG_STATUS_END_DECRYPTION:
						inDecryptedPacket = NO;
						break;
					case GPG_STATUS_PLAINTEXT:
						if (!inDecryptedPacket) {
							hasUnencryptedPlaintext = YES;
						}
						break;
				}
			}
			
			if (hasUnencryptedPlaintext && hasDecryptedPacket) {
				failed = YES;
				errorCode = GPGErrorBadData;
				errorDecription = @"Decryption failed: Unencrypted Plaintext!";
			}
		}
		if (!failed && [errorCodes containsObject:@(GPGErrorNoMDC)]) {
			if (![delegate respondsToSelector:@selector(gpgControllerShouldDecryptWithoutMDC:)] || ![delegate gpgControllerShouldDecryptWithoutMDC:self]) {
				failed = YES;
				errorCode = GPGErrorNoMDC;
				errorDecription = @"Decryption failed: No MDC!";
			} else {
				[gpgTask unsetErrorCode:GPGErrorNoMDC];
			}
		}

		
		
		
		
		if (failed) {
			if (!errorDecription) {
				errorDecription = @"Decryption failed: Unknown Error!";
			}
			[output seekToBeginning];
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(errorDecription) errorCode:errorCode gpgTask:gpgTask];
		} else {
			if (gpgTask.statusDict[@"END_DECRYPTION"]) {
				decrypted = YES;
			}
		}
	} @catch (NSException *e) {
		[self handleException:e];
	}
}

- (NSArray <GPGSignature *> *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy verifySignature:signatureData originalData:originalData];
		return nil;
	}
    
    GPGMemoryStream *signatureInput = [GPGMemoryStream memoryStreamForReading:signatureData];
    GPGMemoryStream *originalInput = nil;
    if (originalData)
        originalInput = [GPGMemoryStream memoryStreamForReading:originalData];
    return [self verifySignatureOf:signatureInput originalData:originalInput];
}

- (NSArray <GPGSignature *> *)verifySignatureOf:(GPGStream *)signatureInput originalData:(GPGStream *)originalInput {
#warning There's a good chance verifySignature will modify the keys if auto-retrieve-keys is set. In that case it might make sense, that we send the notification ourselves with the potential key which might get imported. We do have the fingerprint, and there's no need to rebuild the whole keyring only to update one key.
	
	NSArray <GPGSignature *> *retVal;
	@try {
		[self operationDidStart];

		NSData *originalData = nil;
		signatureInput = [GPGUnArmor unArmor:signatureInput clearText:originalInput ? nil : &originalData];
		if (originalData) {
			originalInput = [GPGMemoryStream memoryStreamForReading:originalData];
		}
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask setInput:signatureInput];
		[gpgTask addArgument:@"--verify"];
		
		[gpgTask addArgument:@"-"];
		
		NSString *fifoPath = nil;
		if (originalInput) {
			
			
			NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"org.gpgtools.libmacgpg"];
			NSError *theError = nil;
			if (![[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&theError]) {
				[NSException raise:NSGenericException format:@"createDirectory failed: %@", theError.localizedDescription];
			}

			NSString *guid = [NSProcessInfo processInfo].globallyUniqueString ;
			NSString *fifoName = [NSString stringWithFormat:@"gpgtmp_%@.fifo", guid];
			fifoPath = [tempDir stringByAppendingPathComponent:fifoName];
			
			if (mkfifo(fifoPath.UTF8String, 0600) != 0) {
				[NSException raise:NSGenericException format:@"mkfifo failed: %s", strerror(errno)];
			}
			

			dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_async(queue, ^{
				@autoreleasepool {
					@try {
						NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:fifoPath];
						NSData *dataToWrite;
						if ([originalInput isKindOfClass:[GPGMemoryStream class]]) {
							// A GPGMemoryStream already holds the whole data in the RAM.
							dataToWrite = originalInput.readAllData;
							[fileHandle writeData:dataToWrite];
						} else {
							// A GPGFileStream doesn't already hold the whole data in the RAM.
							// Do a chunked read/write to save RAM.
							BOOL hasData = YES;
							const NSUInteger chunkSize = 1024 * 1024 * 20;
							do {
								@autoreleasepool {
									dataToWrite = [originalInput readDataOfLength:chunkSize];
									if (dataToWrite.length < chunkSize) {
										hasData = NO;
									}
									if (dataToWrite.length > 0) {
										[fileHandle writeData:dataToWrite];
									}
								}
							} while (hasData);
						}
						[fileHandle closeFile];
					} @catch (NSException *exception) {
						// An exception is possible, when the file handle has closed too soon.
						// Simply ignore it.
					}
				}
			});

			[gpgTask addArgument:fifoPath];
		}

		[gpgTask start];
		
		if (fifoPath) {
			[[NSFileManager defaultManager] removeItemAtPath:fifoPath error:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		retVal = self.signatures;
		[self cleanAfterOperation];
		[self operationDidFinishWithReturnValue:retVal];	
	}
	
	return retVal;
}

- (NSArray <GPGSignature *> *)verifySignedData:(NSData *)signedData {
	return [self verifySignature:signedData originalData:nil];
}




#pragma mark Edit keys

- (NSString *)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment
							 keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(int)keyLength
						  subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(int)subkeyLength
						daysToExpire:(int)daysToExpire preferences:(NSString *)preferences {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateNewKeyWithName:name email:email comment:comment 
								   keyType:keyType keyLength:keyLength subkeyType:subkeyType subkeyLength:subkeyLength 
							  daysToExpire:daysToExpire preferences:preferences];
		return nil;
	}
	NSString *fingerprint = nil;
	@try {
		[self operationDidStart];
		
		NSMutableString *cmdText = [NSMutableString string];
		
		
		[cmdText appendFormat:@"Key-Type: %i\n", keyType];
		[cmdText appendFormat:@"Key-Length: %i\n", keyLength];
		
		if(keyType == GPG_RSAAlgorithm || keyType == GPG_DSAAlgorithm) {
			[cmdText appendFormat:@"Key-Usage: %@\n", @"sign"];
		}
		
		if (subkeyType) {
			[cmdText appendFormat:@"Subkey-Type: %i\n", subkeyType];
			[cmdText appendFormat:@"Subkey-Length: %i\n", subkeyLength];
			if(keyType == GPG_RSAAlgorithm || keyType == GPG_ElgamalEncryptOnlyAlgorithm) {
				[cmdText appendFormat:@"Subkey-Usage: %@\n", @"encrypt"];
			}
		}
		
		if (comment.length == 0 && name.length > 1) {
			NSRange firstBracket = [name rangeOfString:@"("];
			NSRange lastBracket = [name rangeOfString:@")" options:NSBackwardsSearch];
			
			if (firstBracket.location != NSNotFound && lastBracket.location != NSNotFound && firstBracket.location < lastBracket.location) {
				// The Name contains a part between brackets. Append an empty comment so the brackets are not treated as a comment.
				NSString *append = @"()";
				if ([name characterAtIndex:name.length - 1] != ' ') {
					append = @" ()";
				}
				name = [name stringByAppendingString:append];
			}
		}
		
		if (name.length > 0) {
			[cmdText appendFormat:@"Name-Real: %@\n", name];
		}
		if (email.length > 0) {
			[cmdText appendFormat:@"Name-Email: %@\n", email];
		}
		if (comment.length > 0) {
			[cmdText appendFormat:@"Name-Comment: %@\n", comment];
		}
		
		[cmdText appendFormat:@"Expire-Date: %i\n", daysToExpire];
		
		if (preferences) {
			[cmdText appendFormat:@"Preferences: %@\n", preferences];
		}
		
		[cmdText appendString:@"%ask-passphrase\n"];
		[cmdText appendString:@"%commit\n"];
		
		self.gpgTask = [GPGTask gpgTaskWithArgument:@"--gen-key"];
		[gpgTask addArgument:@"--allow-freeform-uid"];
		[self addArgumentsForOptions];
		gpgTask.batchMode = YES;
		[gpgTask setInText:cmdText];
		
		
		[gpgTask start];
			
		NSString *statusText = gpgTask.statusText;

		NSRange range = [statusText rangeOfString:@"[GNUPG:] KEY_CREATED "];
		if (range.length > 0) {
			range = [statusText lineRangeForRange:range];
			range.length--;
			fingerprint = [[[statusText substringWithRange:range] componentsSeparatedByString:@" "] objectAtIndex:3];
			
			if ([undoManager isUndoRegistrationEnabled]) {
				[[undoManager prepareWithInvocationTarget:self] deleteKeys:[NSSet setWithObject:fingerprint] withMode:GPGDeletePublicAndSecretKey];
				[undoManager setActionName:localizedLibmacgpgString(@"Undo_NewKey")];
			}
			
			[[GPGKeyManager sharedInstance] loadKeys:[NSSet setWithObject:fingerprint] fetchSignatures:NO fetchUserAttributes:NO];
			[self keyChanged:fingerprint];
		
			// Create and save revocation certificate.
			NSString *path = [[GPGOptions sharedOptions] gpgHome];
			path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"openpgp-revocs.d/%@.rev", fingerprint]];
			
			if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
				GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
				[order addInt:0 prompt:@"ask_revocation_reason.code" optional:YES];
				[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
				[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
				
				self.gpgTask = [GPGTask gpgTask];
				[self addArgumentsForOptions];
				gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
				[gpgTask addArgument:@"-a"];
				[gpgTask addArgument:@"-o"];
				[gpgTask addArgument:path];
				[gpgTask addArgument:@"--gen-revoke"];
				[gpgTask addArgument:fingerprint];
				[gpgTask start];
			}
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Generate new key failed!") gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:fingerprint];
	return fingerprint;
}

- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy deleteKeys:keys withMode:mode];
		return;
	}
	@try {
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_Delete"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:[GPGTaskOrder orderWithYesToAll] forKey:@"order"]; 
		
		switch (mode) {
			case GPGDeleteSecretKey:
				[gpgTask addArgument:@"--delete-secret-keys"];
				break;
			case GPGDeletePublicAndSecretKey:
				[gpgTask addArgument:@"--delete-secret-and-public-key"];
				break;
			case GPGDeletePublicKey:
				[gpgTask addArgument:@"--delete-keys"];
				break;
			default:
				[NSException raise:NSInvalidArgumentException format:@"Unknown GPGDeleteKeyMode: %i", mode];
		}
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:[NSString stringWithFormat:localizedLibmacgpgString(@"Delete keys (%@) failed!"), keys] gpgTask:gpgTask];
		}
		
		[self keysChanged:nil]; //TODO: Probleme verhindern, wenn die gelöschten Schlüssel angegeben werden.
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)cleanKeys:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy cleanKeys:keys];
		return;
	}
	@try {
		groupedKeyChange++;
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_CleanKey"];
		
		for (GPGKey *key in keys) {
			[self cleanKey:key];
		}

	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		groupedKeyChange--;
		[self keysChanged:keys];
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)cleanKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy cleanKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_CleanKey"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"clean"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Clean failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)minimizeKeys:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy minimizeKeys:keys];
		return;
	}
	@try {
		groupedKeyChange++;
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_MinimizeKey"];
		
		for (GPGKey *key in keys) {
			[self minimizeKey:key];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		groupedKeyChange--;
		[self keysChanged:keys];
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)minimizeKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy minimizeKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_MinimizeKey"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"minimize"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Minimize failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (NSData *)generateRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateRevokeCertificateForKey:key reason:reason description:description];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
		if (description) {
			NSArray *lines = [description componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
			}
		}
		[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
		[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"-a"];
		[gpgTask addArgument:@"--gen-revoke"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0 || gpgTask.outData.length == 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Generate revoke certificate failed!") gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}

	NSData *retVal = [gpgTask outData];
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeKey"];
		
		NSData *revocationData = [self generateRevokeCertificateForKey:key reason:reason description:description];
		[self importFromData:revocationData fullImport:YES];
		// Keys have been changed, so trigger a KeyChanged Notification.
		[self keyChanged:key];
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)setExpirationDateForSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key daysToExpire:(NSUInteger)daysToExpire {
	NSDate *expirationDate = nil;
	NSArray *subkeys = nil;
	if (daysToExpire > 0) {
		expirationDate = [NSDate dateWithTimeIntervalSinceNow:daysToExpire * 86400];
	}
	if (subkey) {
		subkeys = @[subkey];
	}
	[self setExpirationDate:expirationDate forSubkeys:subkeys ofKey:key];
}
- (void)setExpirationDate:(NSDate *)expirationDate forSubkeys:(NSArray *)subkeys ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setExpirationDate:expirationDate forSubkeys:subkeys ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_ChangeExpirationDate"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];

		[gpgTask addArgument:@"--quick-set-expire"];
		[gpgTask addArgument:[key description]];
		
		if (expirationDate) {
			NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
			[formatter setDateFormat:@"yyyyMMdd'T'HHmmss"];
			
			[gpgTask addArgument:[formatter stringFromDate:expirationDate]];
		} else {
			[gpgTask addArgument:@"never"];
		}
		
		
		if (subkeys.count > 0) {
			for (GPGKey *subkey in subkeys) {
				[gpgTask addArgument:[subkey description]];
			}
		}

		[gpgTask start];
		
		if (gpgTask.errorCode) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Change expiration date failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)changePassphraseForKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy changePassphraseForKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_ChangePassphrase"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArguments:@[@"--passwd", key.description]];
		gpgTask.userInfo = @{@"order": order};
		
		if ([gpgTask start] != 0) {
			
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Change passphrase failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


- (NSArray <NSDictionary *> *)algorithmPreferencesForKey:(GPGKey *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:@"quit"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"algorithmPreferencesForKey: failed!") gpgTask:gpgTask];
	}
	
	NSMutableArray *list = [NSMutableArray array];
	
	NSArray *lines = [gpgTask.outText componentsSeparatedByString:@"\n"];
	
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"]) {
			NSArray *parts = [line componentsSeparatedByString:@":"];
			NSArray *split = [[parts objectAtIndex:12] componentsSeparatedByString:@","];
			NSString *userIDDescription = [parts objectAtIndex:9];
			NSString *prefs = [split objectAtIndex:0];
			
			NSRange range, searchRange;
			NSUInteger stringLength = [prefs length];
			searchRange.location = 0;
			searchRange.length = stringLength;
			
			NSArray *compressPreferences, *digestPreferences, *cipherPreferences;
			
			range = [prefs rangeOfString:@"Z" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				compressPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				compressPreferences = [NSArray array];
			}
			
			range = [prefs rangeOfString:@"H" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				digestPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				digestPreferences = [NSArray array];
			}
			
			range = [prefs rangeOfString:@"S" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				cipherPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				cipherPreferences = [NSArray array];
			}
			
			//TODO: Support for [mdc] [no-ks-modify]!
			NSDictionary *preferences = @{@"userIDDescription":userIDDescription, @"compressPreferences":compressPreferences, @"digestPreferences":digestPreferences, @"cipherPreferences":cipherPreferences};
			[list addObject:preferences];
		}
	}

	return list;
}




- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setAlgorithmPreferences:preferences forUserID:hashID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AlgorithmPreferences"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		if (hashID) {
			NSInteger uid = [self indexOfUserID:hashID fromKey:key];
			
			if (uid <= 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
			}
			[order addCmd:[NSString stringWithFormat:@"uid %li\n", (long)uid] prompt:@"keyedit.prompt"];
		}
		[order addCmd:[NSString stringWithFormat:@"setpref %@\n", preferences] prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set preferences failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)key:(NSObject <KeyFingerprint> *)key setDisabled:(BOOL)disabled {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy key:key setDisabled:disabled];
		return;
	}
	@try {
		[self operationDidStart];
		//No undo for this operation.
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:disabled ? @"disable" : @"enable"];
		[gpgTask addArgument:@"quit"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(disabled ? @"Disable key failed!" : @"Enable key failed!") gpgTask:gpgTask];			
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrust:(GPGValidity)trust {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy key:key setOwnerTrust:trust];
		return;
	}
	@try {
		[self operationDidStart];
		//No undo for this operation.
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"trust\n" prompt:@"keyedit.prompt"];
		[order addInt:trust prompt:@"edit_ownertrust.value"];
		[order addCmd:@"quit\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set trust failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust {
	[self key:key setOwnerTrust:trust];
}


#pragma mark Import and export

- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport {
	NSString *statusText = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy importFromData:data fullImport:fullImport];
		return nil;
	}
	@try {
		
		
        NSData *dataToCheck = data;
        NSSet *keys = nil;
		int i = 3; // Max 3 loops.
        
        while (dataToCheck.length > 0 && i-- > 0) {
			NSData *unchangedData = dataToCheck;
			BOOL encrypted = NO;

			NSData *tempData = dataToCheck;
			if (tempData.isArmored) {
				GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:tempData]];
				tempData = [unArmor decodeAll];
			}
            keys = [self keysInExportedData:tempData encrypted:&encrypted];

            if (keys.count > 0) {
                data = tempData;
                break;
            } else if (encrypted) {
				// Decrypt to allow import of encrypted keys.
				dataToCheck = [self decryptData:dataToCheck];
				if (dataToCheck.isArmored) {
					GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:dataToCheck]];
					dataToCheck = [unArmor decodeAll];
				}
			} else if (dataToCheck.length > 4 && memcmp(dataToCheck.bytes, "{\\rtf", 4) == 0) {
				// Data is RTF encoded.
				
				//Get keys from RTF data.
				dataToCheck = [[[[NSAttributedString alloc] initWithData:data options:@{} documentAttributes:nil error:nil] string] dataUsingEncoding:NSUTF8StringEncoding];
				if (dataToCheck.isArmored) {
					GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:dataToCheck]];
					dataToCheck = [unArmor decodeAll];
				}
			}
			if (unchangedData == dataToCheck) {
				break;
			}
        }
		
		
		
		//TODO: Uncomment the following lines when keysInExportedData: fully works!
		/*if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"No keys to import!"];
		}*/
		
		
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_Import"];
		
		//GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		//gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask setInData:data];
		[gpgTask addArgument:@"--import"];
		if (fullImport) {
			[gpgTask addArgument:@"--import-options"];
			[gpgTask addArgument:@"import-local-sigs"];
			[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
			[gpgTask addArgument:@"--allow-weak-digest-algos"];
		}
		
		
		[gpgTask start];
		
		statusText = gpgTask.statusText;
		
		
		NSRange range = [statusText rangeOfString:@"[GNUPG:] IMPORT_RES "];
		
		if (range.length == 0 || [statusText characterAtIndex:range.location + range.length] == '0') {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Import failed!") gpgTask:gpgTask];
		}
		
		[self keysChanged:keys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:statusText];	
	return statusText;
}

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys options:(GPGExportOptions)options {
	NSData *exportedData = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy exportKeys:keys options:options];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
		[arguments addObject:@"--export"];
		
		NSMutableArray *exportOptions = [NSMutableArray array];
		if (options & GPGExportAttributes) {
			[exportOptions addObject:@"export-attributes"];
		}
		if (options & GPGExportClean) {
			[exportOptions addObject:@"export-clean"];
		}
		if (options & GPGExportLocalSigs) {
			[exportOptions addObject:@"export-local-sigs"];
		}
		if (options & GPGExportMinimal) {
			[exportOptions addObject:@"export-minimal"];
		}
		if (options & GPGExportResetSubkeyPassword) {
			[exportOptions addObject:@"export-reset-subkey-passwd"];
		}
		if (options & GPGExportSensitiveRevkeys) {
			[exportOptions addObject:@"export-sensitive-revkeys"];
		}

		if (exportOptions.count) {
			[arguments addObject:@"--export-options"];
			[arguments addObject:[exportOptions componentsJoinedByString:@","]];
		}
		
		
		for (NSObject <KeyFingerprint> * key in keys) {
			[arguments addObject:[key description]];
		}
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForComments];
		[gpgTask addArguments:arguments];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") gpgTask:gpgTask];
		}
		exportedData = [gpgTask outData];
		
		
		if (options & GPGExportSecretKeys) {
			[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[self addArgumentsForComments];
			[gpgTask addArguments:arguments];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") gpgTask:gpgTask];
			}
			NSMutableData *concatExportedData = [NSMutableData dataWithData:[gpgTask outData]];
			[concatExportedData appendData:exportedData];
            exportedData = concatExportedData;
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:exportedData];
	return exportedData;
}

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	return [self exportKeys:keys options:(fullExport ? GPGExportLocalSigs | GPGExportSensitiveRevkeys : 0) | (allowSec ? GPGExportSecretKeys : 0)];
}


#pragma mark Working with Signatures

- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(int)type local:(BOOL)local daysToExpire:(int)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy signUserID:hashID ofKey:key signKey:signKey type:type local:local daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddSignature"];

		NSString *uid;
		if (!hashID) {
			uid = @"uid *\n";
		} else {
			int uidIndex = (int)[self indexOfUserID:hashID fromKey:key];
			if (uidIndex > 0) {
				uid = [NSString stringWithFormat:@"uid %i\n", uidIndex];
			} else {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
			}
		}
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:uid prompt:@"keyedit.prompt"];
		[order addCmd:local ? @"lsign\n" : @"sign\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"n\n" prompt:@"sign_uid.expire" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", daysToExpire] prompt:@"siggen.valid" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", type] prompt:@"sign_uid.class" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		if (signKey) {
			[gpgTask addArgument:@"-u"];
			[gpgTask addArgument:[signKey description]];
		}
		[gpgTask addArgument:@"--ask-cert-expire"];
		[gpgTask addArgument:@"--ask-cert-level"];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Sign userID failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)signUserIDs:(NSArray <GPGUserID *> *)userIDs signerKey:(NSObject <KeyFingerprint> *)signerKey local:(BOOL)local daysToExpire:(int)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy signUserIDs:userIDs signerKey:signerKey local:local daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		
		NSIndexSet *indexes = [self indexesOfUserIDs:userIDs];
		if (indexes.count == 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:nil errorCode:GPGErrorNoUserID gpgTask:nil];
		}
		NSString *fingerprint = [userIDs[0] primaryKey].fingerprint;
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[order addCmd:[NSString stringWithFormat:@"uid %lu", (unsigned long)idx] prompt:@"keyedit.prompt"];
		}];
		[order addCmd:local ? @"lsign\n" : @"sign\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"n\n" prompt:@"sign_uid.expire" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", daysToExpire] prompt:@"siggen.valid" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
		if (signerKey) {
			[gpgTask addArgument:@"-u"];
			[gpgTask addArgument:[signerKey description]];
		}
		[gpgTask addArgument:@"--ask-cert-expire"];
		[gpgTask addArgument:@"--no-ask-cert-level"];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:fingerprint];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Sign userID failed!") gpgTask:gpgTask];
		}
		[self keyChanged:fingerprint];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)removeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSignature:signature fromUserID:userID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveSignature"];

		NSInteger uid = [self indexOfUserID:userID.hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %li\n", (long)uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"delsig\n" prompt:@"keyedit.prompt"];
			
			NSArray *userIDsignatures = userID.signatures;
			for (GPGUserIDSignature *aSignature in userIDsignatures) {
				if (aSignature == signature) {
					[order addCmd:@"y\n" prompt:@[@"keyedit.delsig.valid", @"keyedit.delsig.invalid", @"keyedit.delsig.unknown"]];
					if ([[signature keyID] isEqualToString:[key.description keyID]]) {
						[order addCmd:@"y\n" prompt:@"keyedit.delsig.selfsig"];
					}
				} else {
					[order addCmd:@"n\n" prompt:@[@"keyedit.delsig.valid", @"keyedit.delsig.invalid", @"keyedit.delsig.unknown"]];
				}
			}
			
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove signature failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSignature:signature fromUserID:userID ofKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeSignature"];

		int uid = (int)[self indexOfUserID:userID.hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"revsig\n" prompt:@"keyedit.prompt"];
			
			NSArray *userIDsignatures = userID.signatures;
			for (GPGUserIDSignature *aSignature in userIDsignatures) {
				if (aSignature.revocation == NO && aSignature.primaryKey.secret) {
					if (aSignature == signature) {
						[order addCmd:@"y\n" prompt:@"ask_revoke_sig.one"];
					} else {
						[order addCmd:@"n\n" prompt:@"ask_revoke_sig.one"];
					}
				}
			}
			[order addCmd:@"y\n" prompt:@"ask_revoke_sig.okay" optional:YES];
			[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
			if (description) {
				NSArray *lines = [description componentsSeparatedByString:@"\n"];
				for (NSString *line in lines) {
					[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
				}
			}
			[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke signature failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with Subkeys

- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addSubkeyToKey:key type:type length:length daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddSubkey"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"addkey\n" prompt:@"keyedit.prompt"];
		[order addInt:type prompt:@"keygen.algo"];
		[order addInt:length prompt:@"keygen.size"];
		[order addInt:daysToExpire prompt:@"keygen.valid"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add subkey failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSubkey:subkey fromKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveSubkey"];

		NSInteger index = [self indexOfSubkey:subkey fromKey:key];
		
		if (index > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"key %li\n", (long)index] prompt:@"keyedit.prompt"];
			[order addCmd:@"delkey\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove subkey failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Subkey not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil] errorCode:GPGErrorSubkeyNotFound gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSubkey:subkey fromKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeSubkey"];

		NSInteger index = [self indexOfSubkey:subkey fromKey:key];
		
		if (index > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"key %li\n", (long)index] prompt:@"keyedit.prompt"];
			[order addCmd:@"revkey\n" prompt:@"keyedit.prompt"];
			[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
			if (description) {
				NSArray *lines = [description componentsSeparatedByString:@"\n"];
				for (NSString *line in lines) {
					[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
				}
			}
			[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke subkey failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Subkey not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil] errorCode:GPGErrorSubkeyNotFound gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with User IDs

- (void)addUserIDToKey:(NSObject <KeyFingerprint> *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addUserIDToKey:key name:name email:email comment:comment];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddUserID"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"adduid\n" prompt:@"keyedit.prompt"];
		[order addCmd:name prompt:@"keygen.name"];
		[order addCmd:email prompt:@"keygen.email"];
		[order addCmd:comment prompt:@"keygen.comment"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[gpgTask addArgument:@"--allow-freeform-uid"];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add userID failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeUserID:hashID fromKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveUserID"];
		
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %li\n", (long)uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"deluid\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeUserID:hashID fromKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeUserID"];
		
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %li\n", (long)uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"revuid\n" prompt:@"keyedit.prompt"];
			[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
			if (description) {
				NSArray *lines = [description componentsSeparatedByString:@"\n"];
				for (NSString *line in lines) {
					[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
				}
			}
			[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)setPrimaryUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setPrimaryUserID:hashID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_PrimaryUserID"];
		
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			[gpgTask addArgument:[NSString stringWithFormat:@"%li", (long)uid]];
			[gpgTask addArgument:@"primary"];
			[gpgTask addArgument:@"save"];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set primary userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)addPhotoFromPath:(NSString *)path toKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addPhotoFromPath:path toKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddPhoto"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		[order addCmd:path prompt:@"photoid.jpeg.add"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"addphoto"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add photo failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with keyserver

- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	return [self receiveKeysFromServer:keys refresh:NO];
}
- (NSString *)refreshKeysFromServer:(NSObject <EnumerationList> *)keys {
	return [self receiveKeysFromServer:keys refresh:YES];
}
- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys refresh:(BOOL)refresh {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy receiveKeysFromServer:keys refresh:refresh];
		return nil;
	}
	// When refresh is YES, a verifying keyserver (vks) is used and UseSKSKeyserverAsBackup is YES,
	// the old sks keyserver is also queried and the results are combined.
	
	NSString *retVal = nil; // On success, contains the statusText of the import/recv-keys operation.
	@try {
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_ReceiveFromServer"];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		if ([GPGOptions sharedOptions].isVerifyingKeyserver) {
			NSData *sksData = nil;
			NSError *sksError = nil;
			__block NSData *vksData = nil;
			__block NSError *vksError = nil;

			BOOL useSKS = [[GPGOptions sharedOptions] boolForKey:GPGUseSKSKeyserverAsBackupKey];
			if (!useSKS) {
				// Only use both servers, if the sks fallback is enabled.
				refresh = NO;
			}
			
			// keys can be an NSArray or NSSet, convert to an NSArray of fingerprints.
			NSMutableArray *fingerprints = [NSMutableArray array];
			for (GPGKey *key in keys) {
				[fingerprints addObject:key.description];
				
				/* When GPGUseSKSKeyserverAsBackupKey is set and
				   all objects in "keys" are GPGRemoteKey with fromVKS == NO, the old sks keyserver is uesd.
				 */
				if (useSKS && (![key respondsToSelector:@selector(fromVKS)] || [(GPGRemoteKey *)key fromVKS])) {
					useSKS = NO;
				}
			}
			
			BOOL useVKS = !useSKS;
			if (refresh) {
				useSKS = YES;
				useVKS = YES;
			}
			
			
			
			if (useSKS) {
				/* If useSKS is YES download all keys using GPGKeyserver from the old sks keyserver.
				 * GPGKeyserver uses a callback, so all downloads are performed at the same time, the results
				 * are stored in the two arrays: datas and errors. After all downloads are completed without
				 * an error, all the received keys are un-armored and combined to be imported.
				 */
				
				NSMutableArray<NSData *> *datas = [NSMutableArray array];
				NSMutableArray<NSError *> *errors = [NSMutableArray array];
				__block NSMutableArray<NSData *> *blockDatas = datas;
				__block NSMutableArray<NSError *> *blockErrors = errors;

				dispatch_group_t dispatchGroup = dispatch_group_create();

				for (NSString *fingerprint in fingerprints) {
					GPGKeyserver *sksKeyserver = [[GPGKeyserver new] autorelease];
					[gpgKeyservers addObject:sksKeyserver];
					sksKeyserver.finishedHandler = ^(GPGKeyserver *server) {
						NSData *serverData = server.receivedData;
						NSError *serverError = server.error;
						
						@synchronized (datas) {
							if (serverData) {
								[blockDatas addObject:serverData];
							}
							if (serverError) {
								[blockErrors addObject:serverError];
							}
						}
						
						dispatch_group_leave(dispatchGroup);
					};
					
					dispatch_group_enter(dispatchGroup);
					[sksKeyserver getKey:fingerprint];
				}
				
				// Do not wait more than 30 seconds for the sks keyservers.
				BOOL timedOut = (dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != noErr);
				dispatch_release(dispatchGroup);

				// Prevent the finishedHandler from modifying our arrays anymore.
				@synchronized (datas) {
					blockDatas = nil;
					blockErrors = nil;
				}
				
				// Cancel any possible running keyserver and clear the list.
				for (GPGKeyserver *sksKeyserver in gpgKeyservers) {
					[sksKeyserver cancel];
				}
				[gpgKeyservers removeAllObjects];
				
				
				if (blockErrors.count > 0) {
					// At least one error occured, return the first.
					sksError = blockErrors[0];
				} else if (timedOut) {
					// Timeout. Return an error.
					sksError = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorTimeout userInfo:nil];
				} else {
					// Un-armor all received data and prepare for import.
					NSMutableData *allData = [NSMutableData data];
					for (NSData *serverData in datas) {
						if (serverData.length > 100 && serverData.isArmored) {
							// Un-armor the data.
							NSData *unarmoredData = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:serverData]].decodeAll;
							if (unarmoredData) {
								[allData appendData:unarmoredData];
							}
						}
					}
					sksData = allData;
				}
				
			}
			
			if (useVKS) {
				// A semaphore is used, because the old GPGController methods don't support callbacks.
				dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
				// Download the keys from the server and store the returned data and errror for later use.
				GPGVerifyingKeyserver *verifyingKeyserver = [[GPGVerifyingKeyserver new] autorelease];
				[verifyingKeyserver downloadKeys:fingerprints callback:^(NSData *keyData, NSError *theError) {
					vksData = [keyData retain];
					vksError = [theError retain];
					dispatch_semaphore_signal(semaphore);
				}];
				dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
				dispatch_release(semaphore);
				[vksData autorelease]; // No ARC here, manually add to the autorelease pool.
				[vksError autorelease]; // No ARC here, manually add to the autorelease pool.
			}

			
			if (sksError) {
				sksData = nil;
			}
			if (vksError) {
				vksData = nil;
			}
			if ((sksError || vksError) && sksData.length == 0 && vksData.length == 0) {
				// GPGController uses Exception for it's error handling. Not nice.
				@throw [GPGException exceptionWithReason:sksError.localizedDescription errorCode:(GPGErrorCode)sksError.code];
			}
			
			
			NSData *data;
			if (sksData.length > 0 && vksData.length > 0) {
				NSMutableData *newData = [NSMutableData dataWithCapacity:sksData.length + vksData.length];
				[newData appendData:vksData];
				[newData appendData:sksData];
				data = newData;
			} else if (sksData.length > 0) {
				data = sksData;
			} else {
				data = vksData;
			}
			
			
			// If data is empty, it means no keys were found. This is not an error.
			if (data.length > 0) { // Some keys were downloaded.
				// Import the downloaded keys.
				retVal = [self importFromData:data fullImport:NO];
				if (self.error) {
					// The import failed.
					retVal = nil;
					@throw self.error; // self.error is an NSException, not an NSError!
				}
				
				if (!useSKS) {
					// Remember these keys came from keys.openpgp.org and the email-addresses are verified.
					[self rememberDownloadedKeysAsVerified:data];
				}
			}
			
		} else {
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[self addArgumentsForKeyserver];
			[gpgTask addArgument:@"--recv-keys"];
			for (id key in keys) {
				[gpgTask addArgument:[key description]];
			}
			
			if ([gpgTask start] != 0 && ![gpgTask.statusDict objectForKey:@"IMPORT_RES"] && gpgTask.errorCode != GPGErrorNoData) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Receive keys failed!") gpgTask:gpgTask];
			}

			retVal = [gpgTask statusText];
		}
		
		NSSet *changedKeys = importedFingerprintsFromStatus(gpgTask.statusDict);
		[self keysChanged:changedKeys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:retVal];
	return retVal;
}
- (void)rememberDownloadedKeysAsVerified:(NSData *)keyData {
	// Add the keys and email-addresses to the keysFromVerifyingKeyserverKey dictionary.
	// keysFromVerifyingKeyserverKey is a dict with verified email-addresses for a fingerprint.
	
	GPGOptions *options = [GPGOptions sharedOptions];
	NSDate *now = [NSDate date];
	__block NSMutableDictionary *keysFromVerifyingKeyserver = [options valueForKey:GPGKeysFromVerifyingKeyserverKey];
	if ([keysFromVerifyingKeyserver isKindOfClass:[NSDictionary class]]) {
		keysFromVerifyingKeyserver = [[keysFromVerifyingKeyserver mutableCopy] autorelease];
	} else {
		keysFromVerifyingKeyserver = [NSMutableDictionary dictionary];
	}
	
	__block NSMutableArray *addresses = nil;
	__block NSString *fingerprint = nil;
	[GPGPacket enumeratePacketsWithData:keyData block:^(GPGPacket *packet, BOOL *stop) {
		switch (packet.tag) {
			case GPGPublicKeyPacketTag:
			case GPGSecretKeyPacketTag:
				if (fingerprint) {
					keysFromVerifyingKeyserver[fingerprint] = @{@"addresses": addresses, @"date": now};
				}
				if (packet.tag == GPGPublicKeyPacketTag) {
					fingerprint = ((GPGPublicKeyPacket *)packet).fingerprint;
					addresses = [NSMutableArray array];
				} else {
					// Secret key packets should not be downloaded from a keyserver, ignore them.
					fingerprint = nil;
				}
				break;
			case GPGUserIDPacketTag: {
				NSDictionary<NSString *, NSString *> *dict = ((GPGUserIDPacket *)packet).userID.splittedUserIDDescription;
				if (dict[@"email"].length > 0) {
					[addresses addObject:dict[@"email"]];
				}
				break;
			}
			default:
				break;
		}
	}];
	if (fingerprint) {
		keysFromVerifyingKeyserver[fingerprint] = @{@"addresses": addresses, @"date": now};
	}
	
	[options setValue:keysFromVerifyingKeyserver forKey:GPGKeysFromVerifyingKeyserverKey];
}


- (void)sendKeysToServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy sendKeysToServer:keys];
		return;
	}
	@try {
		[self operationDidStart];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		
		
		if ([GPGOptions sharedOptions].isVerifyingKeyserver) {
			
			// Export the keys ASCII armored and without any foreign signatures.
			self.useArmor = YES;
			NSData *exportedKeys = [self exportKeys:keys options:GPGExportMinimal];
			if (self.error) {
				@throw self.error;
			}
			
			// Convert the ASCII armored data to a string.
			NSString *keytext = exportedKeys.gpgString;
			if (keytext.length < 10) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") errorCode:GPGErrorEncodingProblem];
			}
			
			
			// A semaphore is used, because the old GPGController methods don't support callbacks.
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
			
			// Upload to keys to the server and store a possible errror for later use.
			__block NSError *blockError = nil;
			GPGVerifyingKeyserver *verifyingKeyserver = [[GPGVerifyingKeyserver new] autorelease];
			[verifyingKeyserver uploadKey:keytext callback:^(NSArray *fingerprints, NSDictionary<NSString *,NSString *> *status, NSString *token, NSError *theError) {
				if (theError) {
					// Only return the error.
					blockError = [theError retain];
					dispatch_semaphore_signal(semaphore);
					return;
				}

				// Get list of emailAddresses which are not published.
				NSMutableArray *emailAddressesToVerify = [NSMutableArray array];
				for (NSString *email in status) {
					NSString *state = status[email];
					if ([state isEqualToString:GPGVKSStateUnpublished] || [state isEqualToString:GPGVKSStatePending]) {
						[emailAddressesToVerify addObject:email];
					}
				}
				
				if (emailAddressesToVerify.count > 0) {
					// Request verification emails for all unpublished addresses of the key.
					
					[verifyingKeyserver requestVerification:emailAddressesToVerify token:token callback:^(NSArray *fingerprints2, NSDictionary<NSString *,NSString *> *status2, NSString *token2, NSError *error2) {
						if (error2) {
							// The verification request failed, return the error.
							blockError = [theError retain];
						}
						dispatch_semaphore_signal(semaphore);
					}];
				} else {
					dispatch_semaphore_signal(semaphore);
				}

			}];
			dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
			[blockError autorelease]; // No ARC here, manually add to the autorelease pool.
			
			if (blockError) {
				// The upload or verification request did fail.
				@throw [GPGException exceptionWithReason:blockError.localizedDescription errorCode:(GPGErrorCode)blockError.code];
			}
			
		} else {
			NSDictionary *cache = [[GPGOptions sharedOptions] valueInCommonDefaultsForKey:keysOnServerCacheKey];
			NSMutableDictionary *mutableCache = nil;
			if ([cache isKindOfClass:[NSDictionary class]]) {
				mutableCache = [[cache mutableCopy] autorelease];
			}
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[self addArgumentsForKeyserver];
			[gpgTask addArgument:@"--send-keys"];
			for (id key in keys) {
				NSString *fingerprint = [key description];
				[gpgTask addArgument:fingerprint];
				if ([mutableCache[fingerprint][@"exists"] boolValue] == NO) {
					[mutableCache removeObjectForKey:fingerprint];
				}
			}
			
			if (mutableCache && ![mutableCache isEqualToDictionary:cache]) {
				[[GPGOptions sharedOptions] setValueInCommonDefaults:mutableCache forKey:keysOnServerCacheKey];
			}
			
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Send keys failed!") gpgTask:gpgTask];
			}
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	[self operationDidFinishWithReturnValue:nil];
}

- (NSArray <GPGRemoteKey *> *)searchKeysOnServer:(NSString *)pattern {
	NSArray <GPGRemoteKey *> *keys = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy searchKeysOnServer:pattern];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		
		// Remove all white-spaces.
		NSString *nospacePattern = [[pattern componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
		NSString *stringToCheck = nil;
		NSString *patternForSKS = nil;
		
		switch (nospacePattern.length) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = nospacePattern;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([pattern hasPrefix:@"0"]) {
					stringToCheck = [nospacePattern substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([pattern hasPrefix:@"0x"]) {
					stringToCheck = [nospacePattern substringFromIndex:2];
				}
				break;
		}
		
		BOOL isVerifyingKeyserver = [GPGOptions sharedOptions].isVerifyingKeyserver;
		
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet]].length == 0) {
			// The pattern is a keyID or fingerprint.
			
			// gpg needs "0x" as prefix for the key search.
			pattern = [@"0x" stringByAppendingString:stringToCheck];

			if (isVerifyingKeyserver) {
				// Store the fingerprint with "0x" prefix", for the sks backup search.
				patternForSKS = pattern;
				
				// The fingerprint/keyID should not start with "0x" for hagrid.
				pattern = stringToCheck;
			}
		} else {
			// The pattern is any other text.
			pattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		}
		
		
		
		/* If an old sks keyserver is set, gpg --search-keys is used.
		 * But when keys.openpgp.org is set GPGVerifyingKeyserver is used.
		 * Additionally when GPGUseSKSKeyserverAsBackupKey is YES, the sks pool is searched too.
		 * The searches are perfomred parallel. sks is ignored, when vks finds something usefull.
		 */
		
		
		if (isVerifyingKeyserver) {
            dispatch_group_t dispatchGroup = dispatch_group_create();

            GPGKeyserver *sksKeyserver = nil;
			BOOL alsoUseSKS = [[GPGOptions sharedOptions] boolForKey:GPGUseSKSKeyserverAsBackupKey];

            BOOL __block sksSearchIsRunning = NO;
            BOOL __block vksSearchIsRunning = NO;

            NSArray<GPGRemoteKey *> *results = nil;
			__block NSArray<GPGRemoteKey *> *sksResults = nil;

			if (alsoUseSKS) {
                sksKeyserver = [[GPGKeyserver new] autorelease];
				// Add to gpgKeyservers array, so the user can cancel it.
                [gpgKeyservers addObject:sksKeyserver];
                dispatch_group_enter(dispatchGroup);

                sksKeyserver.finishedHandler = ^(GPGKeyserver *server) {
                    sksSearchIsRunning = NO;
					// retain the results here and autorelease it after dispatch_group_wait.
                    sksResults = [[GPGRemoteKey keysWithListing:server.receivedData.gpgString] retain];
                    dispatch_group_leave(dispatchGroup);
                };

                // The old sks keyservers need a "0x" prefix for fingerprints. patternForSKS has this prefix.
                sksSearchIsRunning = YES;
                [sksKeyserver searchKey:patternForSKS ? patternForSKS : pattern];
			}

            // Search for the keys and store the returned data and errror for later use.
			__block NSArray<GPGRemoteKey *> *vksResults = nil;
			__block NSError *blockError = nil;

            dispatch_group_enter(dispatchGroup);
            GPGVerifyingKeyserver *verifyingKeyserver = [[GPGVerifyingKeyserver new] autorelease];
            vksSearchIsRunning = YES;
            [verifyingKeyserver searchKeys:@[pattern] callback:^(NSArray<GPGRemoteKey *> *theFoundKeys, NSError *theError) {
                vksSearchIsRunning = NO;
                blockError = [theError retain];

                // If the SKS search is still running, check the vks results.
                // If they are usable – a key found with user id's, then kill
                // SKS search.
                // Otherwise wait for SKS to return results as backup.
                GPGRemoteKey *key = [theFoundKeys count] == 1 ? theFoundKeys[0] : nil;
				// First test blockError, so GPGKeyManager is not used if something got wrong.
                BOOL isValidVKSResult = !blockError && (key.userIDs.count > 0 || [[[GPGKeyManager sharedInstance] allKeys] member:key]);
                if(isValidVKSResult) {
                    if(sksSearchIsRunning) {
                        [sksKeyserver cancel];
                    }

                    vksResults = [theFoundKeys retain];
                }
                dispatch_group_leave(dispatchGroup);
			}];

            dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
            dispatch_release(dispatchGroup);
			
			// autorelease all the retained __block objects and not only the returned results.
			[vksResults autorelease];
			[sksResults autorelease];
			[blockError autorelease];

			if (sksKeyserver) {
				[gpgKeyservers removeObject:sksKeyserver];
			}
			
			
			

            // All results are in, now on to distinguish which one to use.
            if([vksResults count] == 1) {
                // Always prefer VKS results.
                results = vksResults;
            }
            else if([sksResults count] > 0) {
                results = sksResults;
                // Found keys on sks, ignore a possible vks error.
                blockError = nil;
            }
            
            if (blockError) {
                @throw [GPGException exceptionWithReason:blockError.localizedDescription errorCode:(GPGErrorCode)blockError.code];
            } else {
                keys = results;
            }
		} else {
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.batchMode = YES;
			[self addArgumentsForKeyserver];
			[gpgTask addArgument:@"--search-keys"];
			[gpgTask addArgument:@"--"];
			[gpgTask addArgument:pattern];
			
			if ([gpgTask start] != 0 &&
				gpgTask.errorCode != GPGErrorNoData &&  // Key not found response from old (< 2.2.12) gpg.
				gpgTask.errorCode != GPGErrorNotFound) { // Key not found response from new (>= 2.2.12) gpg.
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Search keys failed!") gpgTask:gpgTask];
			}
			
			keys = [GPGRemoteKey keysWithListing:gpgTask.outText];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:keys];
	
	return keys;
}

- (void)testKeyserverWithCompletionHandler:(void (^)(BOOL working))completionHandler {
	completionHandler = [[completionHandler copy] autorelease];

	if (keyserver) {
		NSURL *keyserverURL = [NSURL URLWithString:keyserver];
		if (!keyserverURL.host) {
			keyserverURL = [NSURL URLWithString:[@"hkp://" stringByAppendingString:keyserver]];
			if (keyserverURL) {
				// Repair the URL. gpg doesn't want URLs without a scheme.
				self.keyserver = keyserverURL.absoluteString;
			}
		}
		if ([keyserverURL.host isEqualToString:@"keys.openpgp.org"]) {
			// Assume keys.openpgp.org is working, because wo don't wont it marked invalid, if only the user's internet connection is broken.
			// If keys.openpgp.org is used, always use hkps://keys.openpgp.org as the URL.
			self.keyserver = GPG_DEFAULT_KEYSERVER;
			completionHandler(YES);
			return;
		}
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
			BOOL result = NO;
			@try {
				[self operationDidStart];
				
				self.gpgTask = [GPGTask gpgTask];
				
				[self addArgumentsForOptions];
				NSUInteger oldTimeout = keyserverTimeout;
				keyserverTimeout = 20; // This should be enough time for a healthy keyserver to answer.
				[self addArgumentsForKeyserver];
				keyserverTimeout = oldTimeout;
				
				gpgTask.batchMode = YES;
				gpgTask.nonBlocking = YES;
				[gpgTask addArgument:@"--search-keys"];
				[gpgTask addArgument:@"libmacgpg@0x0000000000000000000000000000000000000000.org"]; // Search for a non-existing key.
				
				
				dispatch_group_t dispatchGroup = dispatch_group_create();
				dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					[gpgTask start];
				});
				// Wait a maximum of 30 seconds for the answer. 10 seconds more than the keyserver timeout, to give some setup time.
				if (dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0) {
					if (gpgTask.errorCode == GPGErrorNoError || // Everything is good. Very unlikely, but ok.
						gpgTask.errorCode == GPGErrorCancelled || // Test was cancelled. No need to show a warning.
						gpgTask.errorCode == GPGErrorNoData || // Normal (key not found) response from old (< 2.2.12) gpg.
						gpgTask.errorCode == GPGErrorNotFound) { // Normal (key not found) response from new (>= 2.2.12) gpg.
						result = YES;
					}
				} else {
					[gpgTask cancel];
				}
				dispatch_release(dispatchGroup);
				
			} @catch (NSException *e) {
			} @finally {
				[self cleanAfterOperation];
			}
			
			completionHandler(result);
		}
	});
}
- (void)testKeyserver {
	// This method is always async!
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
			BOOL result = NO;
			@try {
				[self operationDidStart];
				
				
				if (keyserver) {
					NSURL *keyserverURL = [NSURL URLWithString:keyserver];
					if (!keyserverURL.host) {
						keyserverURL = [NSURL URLWithString:[@"hkps://" stringByAppendingString:keyserver]];
					}
					if ([keyserverURL.host isEqualToString:@"keys.openpgp.org"]) {
						// Assume keys.openpgp.org is working, because wo don't wont it marked invalid, if only the user's internet connection is broken.
						result = YES;
						// If keys.openpgp.org is used, always use hkps://keys.openpgp.org as the URL.
						self.keyserver = GPG_DEFAULT_KEYSERVER;
					}
				}
				
				if (!result) {
					self.gpgTask = [GPGTask gpgTask];
					
					[self addArgumentsForOptions];
					NSUInteger oldTimeout = keyserverTimeout;
					keyserverTimeout = 20; // This should be enough time for a healthy keyserver to answer.
					[self addArgumentsForKeyserver];
					keyserverTimeout = oldTimeout;
					
					gpgTask.batchMode = YES;
					gpgTask.nonBlocking = YES;
					[gpgTask addArgument:@"--search-keys"];
					[gpgTask addArgument:@"libmacgpg@0x0000000000000000000000000000000000000000.org"]; // Search for a non-existing key.
					
					
					dispatch_group_t dispatchGroup = dispatch_group_create();
					dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
						[gpgTask start];
					});
					// Wait a maximum of 30 seconds for the answer. 10 seconds more than the keyserver timeout, to give some setup time.
					if (dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0) {
						if (gpgTask.errorCode == GPGErrorNoError || // Everything is good. Very unlikely, but ok.
							gpgTask.errorCode == GPGErrorCancelled || // Test was cancelled. No need to show a warning.
							gpgTask.errorCode == GPGErrorNoData || // Normal (key not found) response from old (< 2.2.12) gpg.
							gpgTask.errorCode == GPGErrorNotFound) { // Normal (key not found) response from new (>= 2.2.12) gpg.
							result = YES;
						}
					} else {
						[gpgTask cancel];
					}
					dispatch_release(dispatchGroup);
				}
				
			} @catch (NSException *e) {
			} @finally {
				[self cleanAfterOperation];
			}
			
			[self operationDidFinishWithReturnValue:@(result)];
		}
	});
	return;
}


- (void)keysExistOnServer:(NSArray <GPGKey *> *)keys callback:(void (^)(NSArray <GPGKey *> *existingKeys, NSArray <GPGKey *> *nonExistingKeys))callback {
	
	// Check if GPGKeyserver should be used.
	// GPGKeyserver is faster than gpg, but only supports http(s) requests.
	BOOL useGPGKeyserver = NO;
//	NSURL *url = [NSURL URLWithString:[[GPGOptions sharedOptions] keyserver]];
//	if (url) {
//		NSString *scheme = url.scheme;
//		if (!scheme || [scheme isEqualToString:@"hkp"] || [scheme isEqualToString:@"hkps"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
//			useGPGKeyserver = YES;
//		}
//	}
	
	
	// Prepare cache.
	NSDictionary *cache = [[GPGOptions sharedOptions] valueInCommonDefaultsForKey:keysOnServerCacheKey];
	if (![cache isKindOfClass:[NSDictionary class]]) {
		cache = [[NSDictionary new] autorelease];
	}
	NSDate *now = [NSDate date];
	
	
	
	NSUInteger count = keys.count;
	NSUInteger i = 0;
	// resultsData is used as an array. 0 = error, -1 = not on server, 1 = extists on server.
	__block NSMutableData *resultsData = [[NSMutableData alloc] initWithLength:count];
	__block char *results = resultsData.mutableBytes;
	
	
	
	dispatch_group_t dispatchGroup = dispatch_group_create();
	dispatch_group_enter(dispatchGroup);
	
	dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
		// This block fills the cache and runs the callback.
		NSMutableArray *existingKeys = [[NSMutableArray new] autorelease];
		NSMutableArray *nonExistingKeys = [[NSMutableArray new] autorelease];
		NSMutableDictionary *mutableCache = [[cache mutableCopy] autorelease];
		
		for (NSUInteger j = 0; j < count; j++) {
			NSInteger value = results[j];
			
			GPGKey *key = keys[j];
			if (value == 1) {
				NSString *fingerprint = key.description;
				mutableCache[fingerprint] = @{@"exists": @YES, @"date": now};
				[existingKeys addObject:key];
			} else {
				[nonExistingKeys addObject:key];
			}
		}
		
		[[GPGOptions sharedOptions] setValueInCommonDefaults:mutableCache forKey:keysOnServerCacheKey];
		
		callback([[existingKeys copy] autorelease], [[nonExistingKeys copy] autorelease]);
		
		[resultsData release];
	});

	
	
	// Search async for every key in the array.
	for (GPGKey *key in keys) {
		dispatch_group_enter(dispatchGroup);
		NSString *fingerprint = key.description;
		
		
		// Is there a cached result?
		NSDictionary *cacheEntry = cache[fingerprint];
		BOOL cacheUsed = NO;
		if ([cacheEntry[@"exists"] boolValue]) {
			cacheUsed = YES;
			results[i] = 1;
		}
		
		
		if (cacheUsed) {
			dispatch_group_leave(dispatchGroup);
		} else {
			
			if (useGPGKeyserver) {
				
				GPGKeyserver *gpgKeyserver = [[GPGKeyserver new] autorelease];
				
				gpgKeyserver.finishedHandler = ^(GPGKeyserver *server) {
					if (server.error) {
					} else {
						NSData *receivedData = server.receivedData;
						NSData *searchData = [[NSString stringWithFormat:@"pub:%@:", fingerprint] dataUsingEncoding:NSUTF8StringEncoding];
						
						if ([receivedData rangeOfData:searchData options:0 range:NSMakeRange(0, receivedData.length)].length > 0) {
							results[i] = 1;
						} else {
							results[i] = -1;
						}
					}
					dispatch_group_leave(dispatchGroup);
				};
				[gpgKeyserver searchKey:[@"0x" stringByAppendingString:fingerprint]];
				
			} else {
				
				self.gpgTask = [GPGTask gpgTask];
				[self addArgumentsForOptions];
				gpgTask.batchMode = YES;
				[self addArgumentsForKeyserver];
				gpgTask.nonBlocking = YES;
				[gpgTask addArgument:@"--search-keys"];
				[gpgTask addArgument:@"--"];
				[gpgTask addArgument:[@"0x" stringByAppendingString:fingerprint]];
				GPGTask *searchTask = gpgTask;
				
				
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					if ([searchTask start] != 0 && gpgTask.errorCode != GPGErrorNoData) {
					} else {
						NSData *receivedData = searchTask.outData;
						NSData *searchData = [[NSString stringWithFormat:@"pub:%@:", fingerprint] dataUsingEncoding:NSUTF8StringEncoding];
						
						if ([receivedData rangeOfData:searchData options:0 range:NSMakeRange(0, receivedData.length)].length > 0) {
							results[i] = 1;
						} else {
							results[i] = -1;
						}
					}
					dispatch_group_leave(dispatchGroup);
				});
				
			}
		}
		i++;
	}

	
	dispatch_group_leave(dispatchGroup);

}



#pragma mark Help methods

- (BOOL)isPassphraseForKeyInCache:(NSObject <KeyFingerprint> *)key {
	return [self isPassphraseForKeyInGPGAgentCache:key] || [self isPassphraseForKeyInKeychain:key];
}

- (BOOL)isPassphraseForKeyInKeychain:(NSObject <KeyFingerprint> *)key {
	NSString *fingerprint = [key description];
	return SecKeychainFindGenericPassword (nil, strlen(GPG_SERVICE_NAME), GPG_SERVICE_NAME, (UInt32)fingerprint.UTF8Length, fingerprint.UTF8String, nil, nil, nil) == 0;
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSObject <KeyFingerprint> *)key {
	if([GPGTask sandboxed]) {
		GPGTaskHelperXPC *taskHelper = [[GPGTaskHelperXPC alloc] init];
		BOOL inCache = NO;
		@try {
			inCache = [taskHelper isPassphraseForKeyInGPGAgentCache:[key description]];
		}
		@catch (NSException *exception) {
			return NO;
		}
		@finally {
			[taskHelper release];
		}
		
		return inCache;
	}

	return [GPGTaskHelper isPassphraseInGPGAgentCache:(NSObject <KeyFingerprint> *)key];
}

- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:[key description]];
	
	[gpgTask start];
	
	NSString *outText = gpgTask.outText;
	
	NSRange range = [outText rangeOfString:[NSString stringWithFormat:@":%@:", hashID]];
	if (range.length != 0) {
		NSInteger index = 0;
		NSArray *lines = [[outText substringToIndex:range.location] componentsSeparatedByString:@"\n"];
		for (NSString *line in lines) {
			if ([line hasPrefix:@"uid:"] || [line hasPrefix:@"uat:"]) {
				index++;
			}
		}
		return index;
	}
	
	return 0;
}
- (NSIndexSet *)indexesOfUserIDs:(NSArray *)userIDs {
	if (userIDs.count == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No userIDs given" userInfo:nil];
	}
	
	NSMutableArray *hashIDs = [[NSMutableArray new] autorelease];
	
	NSString *fingerprint = [(GPGUserID *)userIDs[0] primaryKey].fingerprint;
	for (GPGUserID *userID in userIDs) {
		if (![userID.primaryKey.fingerprint isEqualToString:fingerprint]) {
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"userIDs from more than one key" userInfo:nil];
		}
		[hashIDs addObject:userID.hashID];
	}

	
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:fingerprint];
	
	[gpgTask start];
	
	NSString *outText = gpgTask.outText;
	NSArray *lines = [outText componentsSeparatedByString:@"\n"];
	
	NSMutableIndexSet *indexSet = [[NSMutableIndexSet new] autorelease];
	
	NSUInteger index = 0;
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"] || [line hasPrefix:@"uat:"]) {
			index++;
			NSArray *parts = [line componentsSeparatedByString:@":"];
			if (parts.count >= 8) {
				NSString *hashID = parts[7];
				if ([hashIDs containsObject:hashID]) {
					[indexSet addIndex:index];
				}
			}
		}
	}
	
	return indexSet;
}


- (NSInteger)indexOfSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:@"--allow-weak-digest-algos"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"indexOfSubkey failed!") gpgTask:gpgTask];
	}
	
	NSString *outText = gpgTask.outText;
	
	
	NSRange range = [outText rangeOfString:[NSString stringWithFormat:@":%@:", [subkey description]]];
	if (range.length != 0) {
		NSInteger index = 0;
		NSArray *lines = [[outText substringToIndex:range.location] componentsSeparatedByString:@"\n"];
		for (NSString *line in lines) {
			if ([line hasPrefix:@"sub:"]) {
				index++;
			}
		}
		return index;
	}
	
	return 0;
}

- (NSSet *)keysInExportedData:(NSData *)data encrypted:(BOOL *)encrypted {
	// Returns a set of fingerprints and keyIDs of keys and key-parts (like signatures) in the data.
	
	NSMutableSet *keys = [NSMutableSet set];
	NSMutableSet *keyIDs = [NSMutableSet set];

	
	GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:data];
	GPGPacketParser *parser = [GPGPacketParser packetParserWithStream:stream];
	
	GPGPacket *packet;
	
	while ((packet = parser.nextPacket)) {
		switch (packet.tag) {
			case GPGPublicKeyPacketTag:
			case GPGSecretKeyPacketTag:
			case GPGPublicSubkeyPacketTag:
			case GPGSecretSubkeyPacketTag:
				[keys addObject:[(GPGPublicKeyPacket *)packet fingerprint]];
				break;
			case GPGSymmetricEncryptedSessionKeyPacketTag:
			case GPGPublicKeyEncryptedSessionKeyPacketTag:
				if (encrypted) {
					*encrypted = YES;
				}
				break;
			case GPGSignaturePacketTag: {
				GPGSignaturePacket *signaturePacket = (GPGSignaturePacket *)packet;
				if (signaturePacket.keyID) {
					[keyIDs addObject:signaturePacket.keyID];
				}
				break;
			}
			default:
				break;
		}
	}
	
	if (keyIDs.count > 0) {
		for (NSString *fingerprint in keys) {
			NSString *keyID = fingerprint.keyID;
			[keyIDs removeObject:keyID];
		}
		[keys unionSet:keyIDs];
	}

	return keys;
}



- (void)parseStatusForSignatures:(NSInteger)status prompt:(NSString *)prompt  {
	BOOL parseFingerprint = NO;

	if (status == GPG_STATUS_NEWSIG) {
		return;
	} else if (status >= GPG_STATUS_GOODSIG && status <= GPG_STATUS_ERRSIG) { // New signature
		/*
		 status is one of: GPG_STATUS_GOODSIG, GPG_STATUS_EXPSIG, GPG_STATUS_EXPKEYSIG, GPG_STATUS_REVKEYSIG, GPG_STATUS_BADSIG, GPG_STATUS_ERRSIG
		*/
		self.lastSignature = [[[GPGSignature alloc] init] autorelease];
		[signatures addObject:self.lastSignature];
		parseFingerprint = YES;
	}
	
	
	NSArray<NSString *> *components = [prompt componentsSeparatedByString:@" "];
	
	switch (status) {
		case GPG_STATUS_GOODSIG:
			self.lastSignature.status = GPGErrorNoError;
			break;
		case GPG_STATUS_EXPSIG:
			self.lastSignature.status = GPGErrorSignatureExpired;
			break;
		case GPG_STATUS_EXPKEYSIG:
			self.lastSignature.status = GPGErrorKeyExpired;
			break;
		case GPG_STATUS_BADSIG:
			self.lastSignature.status = GPGErrorBadSignature;
			break;
		case GPG_STATUS_REVKEYSIG:
			self.lastSignature.status = GPGErrorCertificateRevoked;
			break;
		case GPG_STATUS_ERRSIG:
			self.lastSignature.publicKeyAlgorithm = components[1].intValue;
			self.lastSignature.hashAlgorithm = components[2].intValue;
			self.lastSignature.signatureClass = hexToByte(components[3].UTF8String);
			self.lastSignature.creationDate = [NSDate dateWithGPGString:components[4]];
			switch (components[5].intValue) {
				case 4:
					self.lastSignature.status = GPGErrorUnknownAlgorithm;
					break;
				case 9:
					self.lastSignature.status = GPGErrorNoPublicKey;
					break;
				default:
					self.lastSignature.status = GPGErrorGeneralError;
					break;
			}
			// Add the signers key fingerprint, if available.
			if (components.count >= 7 && components[6].length == 40) {
				self.lastSignature.fingerprint = components[6];
			}
			break;
			
		case GPG_STATUS_VALIDSIG:
			parseFingerprint = YES;
			self.lastSignature.creationDate = [NSDate dateWithGPGString:components[2]];
			self.lastSignature.expirationDate = [NSDate dateWithGPGString:components[3]];
			self.lastSignature.version = components[4].intValue;
			self.lastSignature.publicKeyAlgorithm = components[6].intValue;
			self.lastSignature.hashAlgorithm = components[7].intValue;
			self.lastSignature.signatureClass = hexToByte(components[8].UTF8String);
			break;
		case GPG_STATUS_TRUST_UNDEFINED:
			self.lastSignature.trust = GPGValidityUndefined;
			break;
		case GPG_STATUS_TRUST_NEVER:
			self.lastSignature.trust = GPGValidityNever;
			break;
		case GPG_STATUS_TRUST_MARGINAL:
			self.lastSignature.trust = GPGValidityMarginal;
			break;
		case GPG_STATUS_TRUST_FULLY:
			self.lastSignature.trust = GPGValidityFull;
			break;
		case GPG_STATUS_TRUST_ULTIMATE:
			self.lastSignature.trust = GPGValidityUltimate;
			break;
	}
	
	
	if (parseFingerprint) {
		
		GPGKeyManager *keyManager = [GPGKeyManager sharedInstance];
		// If the signature already contains a fingerprint, do not overwrite it with the keyID.
		NSString *fingerprint = self.lastSignature.fingerprint ? self.lastSignature.fingerprint : components[0];
		GPGKey *key;
		
		if (fingerprint.length == 16) { // KeyID
			key = [keyManager.keysByKeyID objectForKey:fingerprint];
		} else { // Fingerprint
			key = [keyManager.allKeysAndSubkeys member:fingerprint];
			
			// If no key is available, but components[0] is a fingerprint it means that our
			// list of keys is outdated. In that case, the specific key is reloaded.
			if(!key && components[0].length >= 32) {
				[keyManager loadKeys:[NSSet setWithObject:fingerprint] fetchSignatures:NO fetchUserAttributes:NO];
				key = [keyManager.allKeysAndSubkeys member:fingerprint];
			}
		}
		
		if (key) {
			self.lastSignature.key = key;
			self.lastSignature.fingerprint = key.fingerprint;
		} else {
			self.lastSignature.fingerprint = fingerprint;
		}
	}
}


#pragma mark Delegate method

- (id)gpgTask:(GPGTask *)task statusCode:(NSInteger)status prompt:(NSString *)prompt {
	switch (status) {
		case GPG_STATUS_GET_LINE:
		case GPG_STATUS_GET_BOOL:
		case GPG_STATUS_GET_HIDDEN: {
			GPGTaskOrder *order = [[task userInfo] objectForKey:@"order"];;
			if (order && [order isKindOfClass:[GPGTaskOrder class]]) {
				NSString *cmd = [order cmdForPrompt:prompt statusCode:status];
				if (cmd && ![cmd hasSuffix:@"\n"]) {
					cmd = [cmd stringByAppendingString:@"\n"];
				}
				return cmd;
			} else {
				return @"\n";
			}
			break; }
			
		case GPG_STATUS_GOODSIG:
		case GPG_STATUS_EXPSIG:
		case GPG_STATUS_EXPKEYSIG:
		case GPG_STATUS_BADSIG:
		case GPG_STATUS_ERRSIG:
		case GPG_STATUS_REVKEYSIG:
		case GPG_STATUS_NEWSIG:
		case GPG_STATUS_VALIDSIG:
		case GPG_STATUS_TRUST_UNDEFINED:
		case GPG_STATUS_TRUST_NEVER:
		case GPG_STATUS_TRUST_MARGINAL:
		case GPG_STATUS_TRUST_FULLY:
		case GPG_STATUS_TRUST_ULTIMATE:
			[self parseStatusForSignatures:status prompt:prompt];
			break;
			
        // Store the hash algorithm.
        case GPG_STATUS_SIG_CREATED: {
            // Split the line by space, index 2 has the hash algorithm.
            NSArray *promptComponents = [prompt componentsSeparatedByString:@" "];
            NSUInteger hashAlgo = 0;
            if([promptComponents count] == 6) {
                NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
                [f setNumberStyle:NSNumberFormatterDecimalStyle];
                NSNumber *algorithmNr = [f numberFromString:[promptComponents objectAtIndex:2]];
                hashAlgo = [algorithmNr unsignedIntegerValue];
                [f release];
            }
            hashAlgorithm = hashAlgo;
            break;
        }
		case GPG_STATUS_PLAINTEXT: {
            NSArray *promptComponents = [prompt componentsSeparatedByString:@" "];
			if (promptComponents.count == 3) {
				NSString *tempFilename = [[promptComponents objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				NSRange extensionRange = [tempFilename rangeOfString:@"."];
				self.filename = tempFilename.length > 0 ? tempFilename : nil;
				
				// For some reason, in some occassions, GPG only prints a number instead
				// of the filename.
				// If the file is a binary file and doesn't have an extension, we'll reset the filename to
				// nil.
				if([[promptComponents objectAtIndex:0] integerValue] == 62 &&
				   (extensionRange.location == NSNotFound || extensionRange.location == 0))
					self.filename = nil;
			}
			break;
		}
	}
	return nil;
}

- (void)gpgTaskWillStart:(GPGTask *)task {
	if ([signatures count] > 0) {
		self.lastSignature = nil;
		[signatures release];
		signatures = [[NSMutableArray alloc] init];	
	}
}

- (void)gpgTask:(GPGTask *)gpgTask progressed:(NSInteger)progressed total:(NSInteger)total {
	[delegate gpgController:self progressed:progressed total:total];
}


#pragma mark Notify delegate

- (void)handleException:(NSException *)e {
	if (asyncStarted && runningOperations == 1 && [delegate respondsToSelector:@selector(gpgController:operationThrownException:)]) {
		[delegate gpgController:self operationThrownException:e];
	}
	[e retain];
	[error release];
	error = e;
	[self logException:e];
}

- (void)operationDidStart {
	if (runningOperations == 0) {
		self.gpgTask = nil;
		[error release];
		error = nil;
		decrypted = NO;
		if ([delegate respondsToSelector:@selector(gpgControllerOperationDidStart:)]) {
			[delegate gpgControllerOperationDidStart:self];
		}		
	}
	runningOperations++;
}
- (void)operationDidFinishWithReturnValue:(id)value {
	if (runningOperations == 0) {
		self.lastReturnValue = value;
		if ([delegate respondsToSelector:@selector(gpgController:operationDidFinishWithReturnValue:)]) {
			[delegate gpgController:self operationDidFinishWithReturnValue:value];
		}		
	}
}

- (void)keysHaveChanged:(NSNotification *)notification {
	if (self != notification.object && ![identifier isEqualTo:notification.object] && [delegate respondsToSelector:@selector(gpgController:keysDidChanged:external:)]) {
		NSDictionary *dictionary = notification.userInfo;
		NSObject <EnumerationList> *keys = [dictionary objectForKey:@"keys"];
		
		if (!keys || [keys isKindOfClass:[NSArray class]] || [keys isKindOfClass:[NSSet class]]) {
			[delegate gpgController:self keysDidChanged:keys external:YES];
		}
	}
}



#pragma mark Private

- (void)logException:(NSException *)e {
	GPGDebugLog(@"GPGController: %@", e.description);
	if ([e isKindOfClass:[GPGException class]]) {
		GPGDebugLog(@"Error text: %@\nStatus text: %@", [(GPGException *)e gpgTask].errText, [(GPGException *)e gpgTask].statusText);
	}
}

- (void)keysChanged:(NSObject <EnumerationList> *)keys {
	if (groupedKeyChange == 0) {
		NSDictionary *dictionary = nil;
		if (keys) {
			NSMutableArray *fingerprints = [NSMutableArray arrayWithCapacity:[keys count]];
			for (NSObject *key in keys) {
				[fingerprints addObject:[key description]];
			}
			dictionary = [NSDictionary dictionaryWithObjectsAndKeys:fingerprints, @"keys", nil];
		}
		if ([delegate respondsToSelector:@selector(gpgController:keysDidChanged:external:)]) {
			[delegate gpgController:self keysDidChanged:keys external:NO];
		}
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:dictionary options:NSNotificationPostToAllSessions | NSNotificationDeliverImmediately];
	}
}
- (void)keyChanged:(NSObject <KeyFingerprint> *)key {
	if (key) {
		[self keysChanged:[NSSet setWithObject:key]];
	} else {
		[self keysChanged:nil];
	}
}


- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data { //Löscht die übergebenen Schlüssel und importiert data.
	[self registerUndoForKeys:keys withName:nil];
	
	[undoManager disableUndoRegistration];
	groupedKeyChange++;
	BOOL oldAsync = self.async;
	self.async = NO;
	
	@try {
		[self deleteKeys:keys withMode:GPGDeletePublicAndSecretKey];
	} @catch (NSException *exception) {
	} 
	
	if ([data length] > 0) {
		@try {
			[self importFromData:data fullImport:YES];
		} @catch (NSException *exception) {
		} 
	}
	
	self.async = oldAsync;
	groupedKeyChange--;
	[self keysChanged:keys];
	[undoManager enableUndoRegistration];
}

- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName {
	if ([undoManager isUndoRegistrationEnabled]) {
		BOOL oldAsync = self.async;
		self.async = NO;
		if ([NSThread isMainThread]) {
			[self registerUndoForKeys:keys];
		} else {
			[self performSelectorOnMainThread:@selector(registerUndoForKeys:) withObject:keys waitUntilDone:YES];
		}
		self.async = oldAsync;
		
		if (actionName && ![undoManager isUndoing] && ![undoManager isRedoing]) {
			[undoManager setActionName:localizedLibmacgpgString(actionName)];
		}
	}
}
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName {
	[self registerUndoForKeys:[NSSet setWithObject:key] withName:actionName];
}
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys {
	GPGTask *oldGPGTask = self.gpgTask;
	[[undoManager prepareWithInvocationTarget:self] restoreKeys:keys withData:[self exportKeys:keys allowSecret:YES fullExport:YES]];
	self.gpgTask = oldGPGTask;
} 




- (void)cleanAfterOperation {
	if (runningOperations == 1) {
		asyncStarted = NO;
		canceled = NO;
	}
	runningOperations--;
}

- (void)addArgumentsForSignerKeys {
	for (GPGKey *key in signerKeys) {
		[gpgTask addArgument:@"-u"];
		if ([key isKindOfClass:[GPGKey class]] && key.primaryKey != key) {
			// Is a subkey. Force gpg to use exact this subkey.
			[gpgTask addArgument:[NSString stringWithFormat:@"%@!", key.description]];
		} else {
			[gpgTask addArgument:key.description];
		}
	}
}

- (void)addArgumentsForKeyserver {
	if (keyserver) {
		[gpgTask addArgument:@"--keyserver"];
		[gpgTask addArgument:keyserver];			
	}
	[gpgTask addArgument:@"--keyserver-options"];
	
	NSMutableString *keyserverOptions = [NSMutableString stringWithCapacity:50];
	
	[keyserverOptions appendFormat:@"timeout=%lu", (unsigned long)keyserverTimeout];
	
	NSString *proxy = proxyServer ? proxyServer : [[GPGOptions sharedOptions] httpProxy];
	if ([proxy length] > 0) {
		if ([proxy rangeOfString:@"://"].length == 0) {
			proxy = [@"http://" stringByAppendingString:proxy]; 
		}
		[keyserverOptions appendFormat:@",http-proxy=%@", proxy];
	}
	
	
	[gpgTask addArgument:keyserverOptions];
}

- (void)addArgumentsForComments {
	if (!useDefaultComments) {
		[gpgTask addArgument:@"--no-comments"];
	}
	for (NSString *comment in comments) {
		[gpgTask addArgument:@"--comment"];
		[gpgTask addArgument:comment];
	}
}

- (void)addArgumentsForOptions {
	[gpgTask addArgument:useArmor ? @"--armor" : @"--no-armor"];
	[gpgTask addArgument:useTextMode ? @"--textmode" : @"--no-textmode"];
	[gpgTask addArgument:printVersion ? @"--emit-version" : @"--no-emit-version"];
	[gpgTask addArgument:autoKeyRetrieve ? @"--auto-key-retrieve" : @"--no-auto-key-retrieve"];
	if (trustAllKeys) {
		[gpgTask addArgument:@"--trust-model"];
		[gpgTask addArgument:@"always"];
	}
	if (gpgHome) {
		[gpgTask addArgument:@"--homedir"];
		[gpgTask addArgument:gpgHome];
	}
	if (allowNonSelfsignedUid) {
		[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
	}
	if (allowWeakDigestAlgos) {
		[gpgTask addArgument:@"--allow-weak-digest-algos"];
	}
	if (_pinentryInfo) {
		NSMutableString *pinentryUserData =  [NSMutableString string];
		for (NSString *key in _pinentryInfo) {
			NSString *value = [_pinentryInfo objectForKey:key];
			NSString *encodedValue = [self encodeStringForPinentry:value];
			[pinentryUserData appendFormat:@"%@=%@,", key, encodedValue];
		}
		NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:pinentryUserData, @"PINENTRY_USER_DATA", nil];
		gpgTask.environmentVariables = env;
	}
	if (passphrase) {
		gpgTask.passphrase = passphrase;
		
		NSArray *parts = [[self.class gpgVersion] componentsSeparatedByString:@"."];
		if (parts.count >= 2) {
			if (([parts[0] integerValue] == 2 && [parts[1] integerValue] >= 1) || [parts[0] integerValue] > 2) {
				[gpgTask addArgument:@"--pinentry-mode"];
				[gpgTask addArgument:@"loopback"];
			}
		}
	}
	
	gpgTask.delegate = self;
	if ([delegate respondsToSelector:@selector(gpgController:progressed:total:)]) {
		gpgTask.progressInfo = YES;
	}
}

- (NSString *)encodeStringForPinentry:(NSString *)string {
	const char *chars = [string UTF8String];
	NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	char *newChars = malloc(length * 3);
	if (!newChars) {
		return nil;
	}
	char *charsPointer = newChars;

	char table[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	
	while (*chars) {
		switch (*chars) {
			case ',':
			case '\n':
			case '\r':
				charsPointer[0] = '%';
				charsPointer[1] = table[*chars >> 4];
				charsPointer[2] = table[*chars & 0xF];
				charsPointer += 3;
				break;
			default:
				*charsPointer = *chars;
				charsPointer++;
				break;
		}
		
		chars++;
	}
	*charsPointer = 0;
	
	NSString *encodedString = [NSString stringWithUTF8String:newChars];
	free(newChars);
	return encodedString;
}




- (void)dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	
	[signerKeys release];
	[comments release];
	[signatures release];
	[keyserver release];
	[gpgHome release];
	[userInfo release];
	[lastSignature release];
	[_pinentryInfo release];	
	[asyncProxy release];
	[identifier release];
	[error release];
	[lastReturnValue release];
	[proxyServer release];
	[undoManager release];
	[gpgKeyservers release];
	[forceFilename release];
	[filename release];
	[gpgTask release];
	
	[super dealloc];
}


+ (NSSet *)algorithmSetFromString:(NSString *)string {
	NSMutableSet *algorithm = [NSMutableSet set];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@";"];
	NSInteger value;
	
	while ([scanner scanInteger:&value]) {
		[algorithm addObject:[NSNumber numberWithInteger:value]];
	}
	return [[algorithm copy] autorelease];
}


+ (GPGErrorCode)testGPG {
	gpgConfigReaded = NO;
	return [self readGPGConfig];
}
+ (GPGErrorCode)testGPGError:(NSException **)error {
	gpgConfigReaded = NO;
	return [self readGPGConfigError:error];
}

+ (GPGErrorCode)readGPGConfig {
	return [self readGPGConfigError:nil];
}
+ (GPGErrorCode)readGPGConfigError:(NSException **)error {
	if (gpgConfigReaded) {
		return GPGErrorNoError;
	}
	
	@try {
		GPGTask *gpgTask = [GPGTask gpgTask];
		// Should return as quick as possible if the xpc helper is not available.
		gpgTask.timeout = GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY;
		gpgTask.nonBlocking = YES;
		[gpgTask addArgument:@"--no-options"];
		[gpgTask addArgument:@"--list-config"];
		[gpgTask start];
		
		NSString *outText = [gpgTask outText];
		NSArray *lines = [outText componentsSeparatedByString:@"\n"];
		
		for (NSString *line in lines) {
			if ([line hasPrefix:@"cfg:"]) {
				NSArray *parts = [line componentsSeparatedByString:@":"];
				if (parts.count > 2) {
					NSString *name = parts[1];
					NSString *value = parts[2];
					
					if ([name isEqualToString:@"version"]) {
						gpgVersion = [value retain];
					} else if ([name isEqualToString:@"pubkey"]) {
						publicKeyAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"cipher"]) {
						cipherAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"digest"]) {
						digestAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"compress"]) {
						compressAlgorithm = [[self algorithmSetFromString:value] retain];
					}
				}
			}
		}
		
		if (!gpgVersion) {
			GPGDebugLog(@"GPGController -readGPGConfig: GPGErrorGeneralError");
			GPGDebugLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
			if (error) {
				*error = [GPGException exceptionWithReason:@"GPGErrorGeneralError" errorCode:GPGErrorGeneralError gpgTask:gpgTask];
			}
			return GPGErrorGeneralError;
		}
		gpgConfigReaded = YES;

		
		// Repair the config if needed.
		[[GPGOptions sharedOptions] repairGPGConf];

		
		gpgTask = [GPGTask gpgTask];
		// Should return as quick as possible if the xpc helper is not available.
		gpgTask.timeout = GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY;
		gpgTask.nonBlocking = YES;
		[gpgTask addArgument:@"--gpgconf-test"];
		[gpgTask start];
		
		NSArray *failure = gpgTask.statusDict[@"FAILURE"];
		if ([failure isKindOfClass:[NSArray class]] && [failure[0][0] isEqualToString:@"option-parser"]) {
			GPGDebugLog(@"GPGController -readGPGConfig: GPGErrorConfigurationError");
			GPGDebugLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
			if (error) {
				*error = [GPGException exceptionWithReason:@"GPGErrorConfigurationError" errorCode:GPGErrorConfigurationError gpgTask:gpgTask];
			}
			return GPGErrorConfigurationError;
		}
		
		
	} @catch (GPGException *exception) {
		GPGDebugLog(@"GPGController -readGPGConfig: %@", exception.description);
		GPGDebugLog(@"Error text: %@\nStatus text: %@", [exception gpgTask].errText, [exception gpgTask].statusText);
		if (exception.errorCode) {
			return exception.errorCode;
		} else {
			return GPGErrorGeneralError;
		}
	} @catch (NSException *exception) {
		GPGDebugLog(@"GPGController -readGPGConfig: %@", exception.description);
		return GPGErrorGeneralError;
	}
	
	return GPGErrorNoError;
}


- (void)setLastReturnValue:(id)value {
	if (value != lastReturnValue) {
		[lastReturnValue release];
		lastReturnValue = [value retain];
	}
}

@end



