
#import "GPGKeyManager.h"
#import "GPGTypesRW.h"
#import "GPGWatcher.h"
#import "GPGTask.h"
#import "GPGKeyMonitoring.h"
#import "GPGTransformer.h"

NSString * const GPGKeyManagerKeysDidChangeNotification = @"GPGKeyManagerKeysDidChangeNotification";

@interface GPGKeyManager () <GPGTaskDelegate>

@property (nonatomic, copy, readwrite) NSDictionary *keysByKeyID;
@property (nonatomic, copy, readwrite) NSSet *secretKeys;

@end

@implementation GPGKeyManager

@synthesize allKeys=_allKeys, keysByKeyID=_keysByKeyID,
			secretKeys=_secretKeys, completionQueue=_completionQueue,
			allowWeakDigestAlgos=_allowWeakDigestAlgos,
			homedir=_homedir;


#pragma mark Load keys

- (void)loadAllKeys {
	[self loadKeys:nil fetchSignatures:NO fetchUserAttributes:NO];
}

- (void)loadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchUserAttributes:(BOOL)fetchUserAttributes {
	[self _queueLoadKeys:keys fetchSignatures:fetchSignatures fetchAttributes:fetchUserAttributes sync:YES completionHandler:nil];
}

- (void)loadKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:NO fetchAttributes:NO completionHandler:completionHandler];
}

- (void)loadSignaturesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:YES fetchAttributes:NO completionHandler:completionHandler];
}

- (void)loadAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:NO fetchAttributes:YES completionHandler:completionHandler];
}

- (void)loadSignaturesAndAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:YES fetchAttributes:YES completionHandler:completionHandler];
}




#pragma mark Private methods for key loading

/*
 * Load keys using a queue, because many simultaneous gpg operations are bad.
 */
- (void)_queueLoadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchAttributes:(BOOL)fetchAttributes sync:(BOOL)sync completionHandler:(void(^)())completionHandler {
	void (^handler)();
	dispatch_semaphore_t semaphore;
	
	if (sync) {
		// Use a semaphore to wait at the end of method until the keys are loaded.
		semaphore = dispatch_semaphore_create(0);
		
		// Always copy blocks.
		completionHandler = [[completionHandler copy] autorelease];
		
		// Call completionHandler if set and signal the semaphore when the keys are loaded.
		handler = ^() {
			if (completionHandler) {
				completionHandler();
			}
			dispatch_semaphore_signal(semaphore);
		};
	} else {
		// Only call the completionHandler when the keys are loaded.
		handler = completionHandler;
	}
	if (keys == nil) {
		// Use an empty set, because nil isn't allowed in an NSDictionary.
		keys = [NSSet set];
	}
	
	NSUInteger flags = fetchSignatures ? 1 : 0;
	flags |= fetchAttributes ? 2 : 0;
	
	// Never forget to copy blocks.
	handler = [[handler copy] autorelease];
	
	// Use dictionaryWithObjectsAndKeys here because handler could be nil.
	NSDictionary *operation = [NSDictionary dictionaryWithObjectsAndKeys:keys, @"keys", @(flags), @"flags", handler, @"completionHandler", nil];
	
	
	// Locked access to _keyLoadingOperations.
	dispatch_sync(_keyLoadingOperationsLock, ^{
		[_keyLoadingOperations addObject:operation];
	});
	
	// _processKeyLoadingOperations returns immediately.
	[self _processKeyLoadingOperations];
	
	
	if (sync) {
		// Wait until the keys are loaded.
		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
		dispatch_release(semaphore);
	}
}

/*
 * Load keys as queued in _keyLoadingOperations.
 * If possible combine operations to load more keys at the same time.
 */
- (void)_processKeyLoadingOperations {
	// Run asynchronous.
	dispatch_async(_keyLoadingQueue, ^{
		
		// Repeat until _keyLoadingOperations is empty.
		while (1) {
			__block NSArray *operations = nil;
			
			// Locked access to _keyLoadingOperations.
			dispatch_sync(_keyLoadingOperationsLock, ^{
				if (_keyLoadingOperations.count > 0) {
					operations = [[_keyLoadingOperations copy] autorelease];
				}
			});
			
			if (operations == nil) {
				// No more keys to laod.
				break;
			}
			
			// Get the next operation.
			NSDictionary *operation = operations[0];
			
			// Which keys should be loaded?
			NSSet *keys = operation[@"keys"];
			NSMutableSet *keysToLoad = nil;
			// If keys is nil or empty, all keys should be loaded.
			if (keys.count > 0) {
				// Only selected keys should be loaded, collect them in keysToLoad;
				keysToLoad = [[keys mutableCopy] autorelease];
			}
			
			
			// Only loading operations with the same flags are combined.
			// flags indicates whether signatures or attributes should be fetched.
			NSUInteger flags = [operation[@"flags"] unsignedIntegerValue];
			
			
			NSMutableArray *completionHandlers = [NSMutableArray array];
			// If there is a completion handler, add it to the list.
			if (operation[@"completionHandler"]) {
				[completionHandlers addObject:operation[@"completionHandler"]];
			}
			
			// Indexes of operation in _keyLoadingOperations which are removed.
			NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSetWithIndex:0];
			
			// Iterate through all remaining operations in operations.
			NSUInteger count = operations.count;
			for (NSUInteger i = 1; i < count; i++) {
				operation = operations[i];
				
				// Only combine if the flags are equal.
				if ([operation[@"flags"] unsignedIntegerValue] == flags) {
					
					// Add selected keys to loadAllKeys if appropriate.
					if (keysToLoad) {
						keys = operation[@"keys"];
						if (keys.count == 0) {
							// Load all keys.
							keysToLoad = nil;
						} else {
							[keysToLoad unionSet:keys];
						}
					}
					
					// If there is a completion handler, add it to the list.
					if (operation[@"completionHandler"]) {
						[completionHandlers addObject:operation[@"completionHandler"]];
					}
					
					// Remove this operation from _keyLoadingOperations.
					[indexesToRemove addIndex:i];
				}
			}
			
			// Locked access to _keyLoadingOperations.
			dispatch_sync(_keyLoadingOperationsLock, ^{
				// Remove all combined operations.
				[_keyLoadingOperations removeObjectsAtIndexes:indexesToRemove];
			});
			
			
			// Load the keys. This is a synchronous method.
			[self _loadKeys:keysToLoad fetchSignatures:flags & 1 fetchUserAttributes:flags & 2];
			
			// Call all completion handlers.
			for (void (^completionHandler)() in completionHandlers) {
				completionHandler();
			}
			
		}
	});
}


- (void)_loadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchUserAttributes:(BOOL)fetchUserAttributes {
	NSSet *newKeysSet = nil;
	
	//NSLog(@"[%@]: Loading keys!", [NSThread currentThread]);
	@try {
		NSArray *keyArguments = [[keys valueForKey:@"description"] allObjects];
		
		_fetchSignatures = fetchSignatures;
		_fetchUserAttributes = fetchUserAttributes;
		
		// 1. Fetch all secret keys.
		@try {
			// Get all fingerprints of the secret keys.
			GPGTask *gpgTask = [GPGTask gpgTask];
			gpgTask.nonBlocking = YES;
			if (_homedir) {
				[gpgTask addArgument:@"--homedir"];
				[gpgTask addArgument:_homedir];
			}
			gpgTask.batchMode = YES;
			if (self.allowWeakDigestAlgos) {
				[gpgTask addArgument:@"--allow-weak-digest-algos"];
			}
			[gpgTask addArgument:@"--list-secret-keys"];
			[gpgTask addArgument:@"--with-fingerprint"];
			[gpgTask addArgument:@"--with-fingerprint"];
			[gpgTask addArguments:keyArguments];
				
			[gpgTask start];
				
			self->_secKeyInfos = [[self parseSecColonListing:gpgTask.outData.gpgLines] retain];
        }
		@catch (NSException *exception) {
			//TODO: Set error code.
			GPGDebugLog(@"Unable to load secret keys.")
		}
		
		// Get the infos from gpg.
		GPGTask *gpgTask = [GPGTask gpgTask];
		gpgTask.nonBlocking = YES;
		if (_homedir) {
			[gpgTask addArgument:@"--homedir"];
			[gpgTask addArgument:_homedir];
		}
		if (fetchSignatures) {
			[gpgTask addArgument:@"--check-sigs"];
			[gpgTask addArgument:@"--list-options"];
			[gpgTask addArgument:@"show-sig-subpackets=29,show-sig-subpackets=30"];
		} else {
			[gpgTask addArgument:@"--list-keys"];
		}
		if (fetchUserAttributes) {
			_attributeInfos = [[NSMutableDictionary alloc] init];
			_attributeDataLocation = 0;
			gpgTask.getAttributeData = YES;
			gpgTask.delegate = self;
		}
		if (self.allowWeakDigestAlgos) {
			[gpgTask addArgument:@"--allow-weak-digest-algos"];
		}
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:keyArguments];
		
		// TODO: We might have to retain this task, since it might be used in a delegate.
		[gpgTask start];
		
		// ======= Parsing =======

		_attributeData = [gpgTask.attributeData retain]; //attributeData is only needed for UATs (PhotoID).
		_keyLines = gpgTask.outData.gpgLines;

		dispatch_queue_t dispatchQueue = NULL;
		if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
			dispatchQueue = dispatch_queue_create("org.gpgtools.libmacgpg._loadKeys.gpgTask", DISPATCH_QUEUE_CONCURRENT);
		else {
			dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_retain(dispatchQueue);
		}
		dispatch_group_t dispatchGroup = dispatch_group_create();

		NSMutableArray *newKeys = [[NSMutableArray alloc] init];
		
		// Loop thru all lines. Starting with the last line.
		NSUInteger lastLine = _keyLines.count;
		NSInteger index = lastLine - 1;
		for (; index >= 0; index--) {
			NSString *line = [_keyLines objectAtIndex:index];
			if ([line hasPrefix:@"pub"]) {
				GPGKey *key = [[GPGKey alloc] init];
				[newKeys addObject:key];
				[key release];
				
				@autoreleasepool {
					[self fillKey:key withRange:NSMakeRange(index, lastLine - index)];
				}

				lastLine = index;
			}
		}
		
		dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        dispatch_release(dispatchGroup);
        dispatch_release(dispatchQueue);
		
		[_attributeData release];
		[_attributeInfos release];
		_attributeInfos = nil;
		
		// TODO: Es kann vorkommen, dass ein Key doppelt von gpg2 gelistet wird. Einmal mit und einmal ohne Signaturen.
		// Wenn das passiert, kann es sein, dass der Key mit mehr Signaturen nicht im newKeysSet landet.
		newKeysSet = [NSSet setWithArray:newKeys];
		[newKeys release];
		
		if (keys) {
			[_mutableAllKeys minusSet:keys];
			[_mutableAllKeys minusSet:newKeysSet];
		} else {
			[_mutableAllKeys removeAllObjects];
		}
		[_mutableAllKeys unionSet:newKeysSet];
		
		
		
		
		NSMutableDictionary *keysByKeyID = [[NSMutableDictionary alloc] init];
		NSMutableSet *secretKeys = [[NSMutableSet alloc] init];
		
		for (GPGKey *key in _mutableAllKeys) {
			if (key.secret) {
				[secretKeys addObject:key];
			}
			[keysByKeyID setObject:key forKey:key.keyID];
			for (GPGKey *subkey in key.subkeys) {
				[keysByKeyID setObject:subkey forKey:subkey.keyID];
			}
		}
		
		self.secretKeys = secretKeys;
		[secretKeys release];
		
		self.keysByKeyID = keysByKeyID;
		if (fetchSignatures) {
			for (GPGKey *key in _mutableAllKeys) {
				for (GPGUserID *uid in key.userIDs) {
					for (GPGUserIDSignature *sig in uid.signatures) {
						sig.primaryKey = [keysByKeyID objectForKey:sig.keyID]; // Set the key used to create the signature.
					}
				}
			}
		}
		[keysByKeyID release];

				
	}
	@catch (NSException *exception) {
		//TODO: Detect unavailable keyring.
		
		GPGDebugLog(@"loadKeys failed: %@", exception);
		_mutableAllKeys = nil;
#ifdef DEBUGGING
		if ([exception respondsToSelector:@selector(errorCode)] && [(GPGException *)exception errorCode] != GPGErrorNotFound) {
			@throw exception;
		}
#endif
	}
	@finally {
		[_secKeyInfos release];
		_secKeyInfos = nil;
		
		NSSet *oldAllKeys = _allKeys;
		_allKeys = [_mutableAllKeys copy];
		[oldAllKeys release];
	}
	
	// Inform all listeners that the keys were loaded.
	dispatch_async(dispatch_get_main_queue(), ^{
		NSArray *affectedKeys = [[[newKeysSet setByAddingObjectsFromSet:keys] valueForKey:@"description"] allObjects];
		NSDictionary *userInfo = nil;
		if (affectedKeys) {
			userInfo = [NSDictionary dictionaryWithObject:affectedKeys forKey:@"affectedKeys"];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:GPGKeyManagerKeysDidChangeNotification object:[[self class] description] userInfo:userInfo];
		
#warning Remove the NSDistributedNotificationCenter line in the next version. It's only for compatibility.
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyManagerKeysDidChangeNotification object:[[self class] description] userInfo:userInfo];
	});

	// Start the key ring watcher.
	[self startKeyringWatcher];
}

- (void)fillKey:(GPGKey *)primaryKey withRange:(NSRange)lineRange {
	
	NSMutableArray *userIDs = nil, *subkeys = nil, *signatures = nil;
	GPGKey *key = nil;
	GPGKey *signedObject = nil; // A GPGUserID or GPGKey.
	
	GPGUserIDSignature *signature = nil;
	BOOL isPub = NO, isUid = NO, isRev = NO; // Used to differentiate pub/sub, uid/uat and sig/rev, because they are using the same if branch.
	NSUInteger uatIndex = 0;
	
	
	NSUInteger i = lineRange.location;
	NSUInteger end = i + lineRange.length;
	
	for (; i < end; i++) {
		NSArray *parts = [[_keyLines objectAtIndex:i] componentsSeparatedByString:@":"];
		NSString *type = [parts objectAtIndex:0];
		
		if (([type isEqualToString:@"pub"] && (isPub = YES)) || [type isEqualToString:@"sub"]) { // Primary-key or subkey.
			if (_fetchSignatures) {
				signedObject.signatures = signatures;
				signatures = [NSMutableArray array];
			}
			if (isPub) {
				key = primaryKey;
			} else {
				key = [[[GPGKey alloc] init] autorelease];
			}
			signedObject = key;
			
			
			GPGValidity validity = [self validityForLetter:[parts objectAtIndex:1]];
			
			key.length = [[parts objectAtIndex:2] intValue];
			
			key.algorithm = [[parts objectAtIndex:3] intValue];
			
			key.keyID = [parts objectAtIndex:4];
			
			key.creationDate = [NSDate dateWithGPGString:[parts objectAtIndex:5]];
			
			NSDate *expirationDate = [NSDate dateWithGPGString:[parts objectAtIndex:6]];
			key.expirationDate = expirationDate;
			if (!(validity & GPGValidityExpired) && expirationDate && [[NSDate date] isGreaterThanOrEqualTo:expirationDate]) {
				validity |= GPGValidityExpired;
			}
			
			key.ownerTrust = [self validityForLetter:[parts objectAtIndex:8]];
			
			const char *capabilities = [[parts objectAtIndex:11] UTF8String];
			for (; *capabilities; capabilities++) {
				switch (*capabilities) {
					case 'd':
					case 'D':
						validity |= GPGValidityDisabled;
						break;
					case 'e':
						key.canEncrypt = YES;
					case 'E':
						key.canAnyEncrypt = YES;
						break;
					case 's':
						key.canSign = YES;
					case 'S':
						key.canAnySign = YES;
						break;
					case 'c':
						key.canCertify = YES;
					case 'C':
						key.canAnyCertify = YES;
						break;
					case 'a':
						key.canAuthenticate = YES;
					case 'A':
						key.canAnyAuthenticate = YES;
						break;
				}
			}
			
			key.validity = validity;
			
			if (isPub) {
				isPub = NO;
				
				userIDs = [[NSMutableArray alloc] init];
				subkeys = [[NSMutableArray alloc] init];
			} else {
				[subkeys addObject:key];
			}
			key.primaryKey = primaryKey;
			
		}
		else if (([type isEqualToString:@"uid"] && (isUid = YES)) || [type isEqualToString:@"uat"]) { // UserID or UAT (PhotoID).
			if (_fetchSignatures) {
				signedObject.signatures = signatures;
				signatures = [NSMutableArray array];
			}

			GPGUserID *userID = [[[GPGUserID alloc] init] autorelease];
			userID.primaryKey = primaryKey;
			signedObject = (GPGKey *)userID; // signedObject is a GPGKey or GPGUserID. It's only casted to allow "signedObject.signatures = signatures".
			
			
			GPGValidity validity = [self validityForLetter:[parts objectAtIndex:1]];
			
			userID.creationDate = [NSDate dateWithGPGString:[parts objectAtIndex:5]];
			
			NSDate *expirationDate = [NSDate dateWithGPGString:[parts objectAtIndex:6]];
			userID.expirationDate = expirationDate;
			if (!(validity & GPGValidityExpired) && expirationDate && [[NSDate date] isGreaterThanOrEqualTo:expirationDate]) {
				validity |= GPGValidityExpired;
			}
			
			userID.hashID = [parts objectAtIndex:7];
			
			
			if (parts.count > 11 && [[parts objectAtIndex:11] rangeOfString:@"D"].length > 0) {
				validity |= GPGValidityDisabled;
			}
			
			userID.validity = validity;
			
			
			if (isUid) {
				isUid = NO;
				NSDictionary *dict = [[[parts objectAtIndex:9] unescapedString] splittedUserIDDescription];
				userID.userIDDescription = [dict objectForKey:@"userIDDescription"];
				userID.name = [dict objectForKey:@"name"];
				userID.email = [dict objectForKey:@"email"];
				userID.comment = [dict objectForKey:@"comment"];

			} else {
				userID.isUat = YES;
				
				if (_fetchUserAttributes) { // Process attribute data.
					NSArray *infos = [_attributeInfos objectForKey:primaryKey.fingerprint];
					if (infos) {
						NSInteger index, count;
						
						do {
							NSDictionary *info = [infos objectAtIndex:uatIndex];
							uatIndex++;
							
							index = [[info objectForKey:@"index"] integerValue];
							count = [[info objectForKey:@"count"] integerValue];
							NSInteger location = [[info objectForKey:@"location"] integerValue];
							NSInteger length = [[info objectForKey:@"length"] integerValue];
							NSInteger uatType = [[info objectForKey:@"type"] integerValue];
							
							
							switch (uatType) {
								case 1: { // Image
									NSImage *image = [[NSImage alloc] initWithData:[_attributeData subdataWithRange:NSMakeRange(location + 16, length - 16)]];
									
									if (image) {
										NSImageRep *imageRep = [[image representations] objectAtIndex:0];
										NSSize size = imageRep.size;
										if (size.width != imageRep.pixelsWide || size.height != imageRep.pixelsHigh) { // Fix image size if needed.
											size.width = imageRep.pixelsWide;
											size.height = imageRep.pixelsHigh;
											imageRep.size = size;
											[image setSize:size];
										}
										
										userID.image = image;
										[image release];
									}
									
									break;
								}
							}
							
						} while (index < count);
					}
				}
				
			}
				
			
			[userIDs addObject:userID];
		}
		else if ([type isEqualToString:@"fpr"]) { // Fingerprint.
			NSString *fingerprint = [parts objectAtIndex:9];
			if ([fingerprint isEqualToString:@"00000000000000000000000000000000"]) {
				fingerprint = primaryKey.keyID;
			}
			
			key.fingerprint = fingerprint;
			
			NSDictionary *secKeyInfo = [_secKeyInfos objectForKey:fingerprint];
			if (secKeyInfo) {
				key.secret = YES;
				NSString *cardID = [secKeyInfo objectForKey:@"cardID"];
				key.cardID = cardID;
			}
		}
		else if ([type isEqualToString:@"sig"] || ([type isEqualToString:@"rev"] && (isRev = YES))) { // Signature.
			signature = [[[GPGUserIDSignature alloc] init] autorelease];
			
			NSString *validityString = parts[1];
			if (validityString.length == 1) {
				unichar character = [validityString characterAtIndex:0];
				switch (character) {
					case '!':
						signature.validity = GPGValidityUltimate;
						break;
					case '?':
						signature.validity = GPGValidityUndefined;
						break;
					case '-':
						signature.validity = GPGValidityNever;
						break;
					case '%':
						signature.validity = GPGValidityInvalid;
						break;
				}
			}
			
			signature.revocation = isRev;
			
			signature.algorithm = [parts[3] intValue];
			
			signature.keyID = parts[4];
			
			signature.creationDate = [NSDate dateWithGPGString:parts[5]];
			
			signature.expirationDate = [NSDate dateWithGPGString:parts[6]];
			
			NSString *field = parts[10];
			signature.signatureClass = hexToByte(field.UTF8String);
			signature.local = [field hasSuffix:@"l"];
			
			if (parts.count > 15) {
				signature.hashAlgorithm = [parts[15] intValue];
			}
			
			[signatures addObject:signature];
			
			isRev = NO;
		}
		else if ([type isEqualToString:@"spk"]) { // Signature subpacket. Needed for the revocation reason.
			switch ([[parts objectAtIndex:1] integerValue]) {
				case 29:
					signature.reason = [[parts objectAtIndex:4] unescapedString];
					break;
				case 30: {
					NSString *value = parts[4];
					signature.mdcSupport = value.length > 2 && [[value substringToIndex:3] isEqualToString:@"%01"];
					break;
				}
			}
		}
		
	}

	if (_fetchSignatures && signatures) {
		signedObject.signatures = signatures;
	}
	
	primaryKey.userIDs = userIDs;
	primaryKey.subkeys = subkeys;
	
	BOOL mdcSupport = YES;
	for (GPGUserID *userID in primaryKey.userIDs) {
		if (userID.selfSignature.mdcSupport) {
			userID.mdcSupport = YES;
		} else {
			if (userID.validity < GPGValidityInvalid && !userID.isUat) {
				mdcSupport = NO;
			}
		}
	}
	primaryKey.mdcSupport = mdcSupport;
	
	
	
	
	[userIDs release];
	[subkeys release];
}

- (void)startKeyringWatcher {
    // The keyring watcher is only to be started after all the keys have
    // been loaded at least once.
    // In order to make sure of that, this method is always called after loadAllKeys
    // has completed, but using dispatch_once we'll also make sure that it's only started
    // once.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [GPGWatcher activate];
    });
}

- (void)_loadExtrasForKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchAttributes:(BOOL)fetchAttributes completionHandler:(void(^)(NSSet *))completionHandler {
	// Keys might be either a list of real keys or fingerprints.
	// In any way, only the fingerprints are of interest for us, since
	// they'll be used to load the appropriate keys.
	__block GPGKeyManager *weakSelf = self;
	
	NSSet *keysCopy = [keys copy];
	NSSet *fingerprints = [keysCopy valueForKey:@"description"];
	[keysCopy release];
	
	[self _queueLoadKeys:keys fetchSignatures:fetchSignatures fetchAttributes:fetchAttributes sync:NO completionHandler:^{
		if(completionHandler) {
			
			// All requested extras should be available for the keys.
			// Now let's get them via their fingerprint.
			NSSet *keysWithSignatures = [weakSelf->_allKeys objectsPassingTest:^BOOL(GPGKey *key, BOOL *stop) {
				return [fingerprints containsObject:[key description]];
			}];
			
			dispatch_async(self.completionQueue != nil ? self.completionQueue : dispatch_get_main_queue(), ^{
				completionHandler(keysWithSignatures);
			});
		}
	}];
}





#pragma mark Properties

- (NSDictionary *)keysByKeyID {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if(!_keysByKeyID)
			[self loadAllKeys];
	});
	
	return [[_keysByKeyID retain] autorelease];
}

- (NSSet *)allKeys {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if(!_allKeys)
			[self loadAllKeys];
	});
	
	return [[_allKeys retain] autorelease];
}

- (NSSet *)allKeysAndSubkeys {
	/* TODO: Must be declared __weak once ARC! */
	static id oldAllKeys = (id)1;
	
	dispatch_semaphore_wait(_allKeysAndSubkeysOnce, DISPATCH_TIME_FOREVER);
	
	NSSet *allKeys = self.allKeys;
	
	if (oldAllKeys != allKeys) {
		oldAllKeys = allKeys;
		
		NSMutableSet *allKeysAndSubkeys = [[NSMutableSet alloc] initWithSet:allKeys copyItems:NO];
		
		for (GPGKey *key in allKeys) {
			[allKeysAndSubkeys addObjectsFromArray:key.subkeys];
		}
		
		id old = _allKeysAndSubkeys;
		_allKeysAndSubkeys = [allKeysAndSubkeys copy];
		[old release];
		[allKeysAndSubkeys release];
	}
	
	dispatch_semaphore_signal(_allKeysAndSubkeysOnce);

	return [[_allKeysAndSubkeys retain] autorelease];
}

- (NSSet *)secretKeys {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (!_secretKeys) {
			[self loadAllKeys];
		}
	});
	
	return [[_secretKeys retain] autorelease];
}

- (void)setCompletionQueue:(dispatch_queue_t)completionQueue {
	NSAssert(completionQueue != nil, @"nil or NULL is not allowed for completionQueue");
	if(completionQueue == _completionQueue)
		return;
	
	if(_completionQueue) {
		dispatch_release(_completionQueue);
		_completionQueue = NULL;
	}
	if(completionQueue) {
		dispatch_retain(completionQueue);
		_completionQueue = completionQueue;
	}
	
}


#pragma mark Key Descriptions

- (NSString *)descriptionForKeys:(NSArray *)keys {
	NSMutableString *descriptions = [NSMutableString string];
	Class gpgKeyClass = [GPGKey class];
	NSUInteger i = 0, count = keys.count;
	NSUInteger lines = 10;
	if (count == 0) {
		return @"";
	}
	if (lines > 0 && count > lines) {
		lines = lines - 1;
	} else {
		lines = NSUIntegerMax;
	}
	BOOL singleKey = count == 1;
	BOOL indent = NO;
	
	
	NSString *lineBreak = indent ? @"\n\t" : @"\n";
	if (indent) {
		[descriptions appendString:@"\t"];
	}
	
	NSString *normalSeperator = [@"," stringByAppendingString:lineBreak];
	NSString *seperator = @"";
	
	for (__strong GPGKey *key in keys) {
		if (i >= lines && i > 0) {
			[descriptions appendString:lineBreak];
			[descriptions appendFormat:localizedLibmacgpgString(@"KeyDescriptionAndMore"), count - i];
			break;
		}
		
		if (![key isKindOfClass:gpgKeyClass]) {
			NSString *keyID = (id)key;
			GPGKey *realKey = nil;
			if (keyID.length == 16) {
				realKey = self.keysByKeyID[keyID];
			} else {
				realKey = [self.allKeysAndSubkeys member:key];
			}
			
			if (!realKey) {
				realKey = [[self keysByKeyID] objectForKey:key.keyID];
			}
			if (realKey) {
				key = realKey;
			}
		}
		
		if (i > 0) {
			seperator = normalSeperator;
		}
		
		if ([key isKindOfClass:gpgKeyClass]) {
			GPGKey *primaryKey = key.primaryKey;
			
			NSString *name = primaryKey.name;
			NSString *email = primaryKey.email;
			NSString *keyID = [[GPGNoBreakFingerprintTransformer sharedInstance] transformedValue:key.fingerprint];
			
			if (name.length == 0) {
				name = email;
				email = nil;
			}
			
			if (email.length > 0) {
				if (singleKey) {
					[descriptions appendFormat:@"%@%@ <%@>%@%@", seperator, name, email, lineBreak, keyID];
				} else {
					[descriptions appendFormat:@"%@%@ <%@> (%@)", seperator, name, email, keyID];
				}
			} else {
				if (singleKey) {
					[descriptions appendFormat:@"%@%@%@%@", seperator, name, lineBreak, keyID];
				} else {
					[descriptions appendFormat:@"%@%@ (%@)", seperator, name, keyID];
				}
			}
			
		} else {
			[descriptions appendFormat:@"%@%@", seperator, [[GPGNoBreakFingerprintTransformer sharedInstance] transformedValue:key]];
		}
		
		
		i++;
	}
	
	return [descriptions.copy autorelease];
}



#pragma mark Helper methods

- (GPGValidity)validityForLetter:(NSString *)letter {
	if ([letter length] == 0) {
		return GPGValidityUnknown;
	}
	switch ([letter characterAtIndex:0]) {
		case 'q':
			return GPGValidityUndefined;
		case 'n':
			return GPGValidityNever;
		case 'm':
			return GPGValidityMarginal;
		case 'f':
			return GPGValidityFull;
		case 'u':
			return GPGValidityUltimate;
		case 'i':
			return GPGValidityInvalid;
		case 'r':
			return GPGValidityRevoked;
		case 'e':
			return GPGValidityExpired;
		case 'd':
			return GPGValidityDisabled;
	}
	return GPGValidityUnknown;
}

- (NSDictionary *)parseSecColonListing:(NSArray *)lines {
	NSMutableDictionary *infos = [NSMutableDictionary dictionary];
	NSUInteger count = lines.count;
	
	NSDictionary *keyInfo = @{};
	
	
	for (NSInteger i = 0; i < count; i++) { // Loop backwards through the lines.
		NSArray *parts = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
		NSString *type = [parts objectAtIndex:0];
		
		if ([type isEqualToString:@"sec"] || [type isEqualToString:@"ssb"]) {
			NSString *cardID = [parts objectAtIndex:14];
			if (cardID.length > 0) {
				keyInfo = @{@"cardID":cardID};
			} else {
				keyInfo = @{};
			}
		} else if ([type isEqualToString:@"fpr"]) {
			NSString *fingerprint = [parts objectAtIndex:9];
			[infos setObject:keyInfo forKey:fingerprint];
		}
	}
	
	return infos;
}



#pragma mark Delegate

- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt {
	
	switch (status) {
		case GPG_STATUS_ATTRIBUTE: {
			NSArray *parts = [prompt componentsSeparatedByString:@" "];
			NSString *fingerprint = [parts objectAtIndex:0];
			NSInteger length = [[parts objectAtIndex:1] integerValue];
			NSString *type = [parts objectAtIndex:2];
			NSString *index = [parts objectAtIndex:3];
			NSString *count = [parts objectAtIndex:4];

			
			NSNumber *location = [NSNumber numberWithUnsignedInteger:_attributeDataLocation];
			_attributeDataLocation += length;
			
			NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSNumber numberWithInteger:length], @"length",
								  type, @"type",
								  location, @"location",
								  index, @"index", 
								  count, @"count", 
								  nil];
			
			NSMutableArray *infos = [_attributeInfos objectForKey:fingerprint];
			if (!infos) {
				infos = [[NSMutableArray alloc] init];
				[_attributeInfos setObject:infos forKey:fingerprint];
				[infos release];
			}
			
			[infos addObject:info];
			
			break;
		}
			
	}
	return nil;
}



#pragma mark Keyring modifications notification handler

- (void)keysDidChange:(NSNotification *)notification {
	// If notification doesn't contain any keys, all keys have
	// to be rebuild.
	// If only a few keys were modified, the notification info will contain
	// the affected keys, and only these have to be rebuilt.
	// Because of security concerns, simply ignore the list of keys and
	// rebuild all of them.
	
	// We're on the main queue, so we should use asnyc loading.
	[self _queueLoadKeys:nil fetchSignatures:NO fetchAttributes:NO sync:NO completionHandler:nil];
}



#pragma mark Singleton

+ (GPGKeyManager *)sharedInstance {
	static dispatch_once_t onceToken;
    static GPGKeyManager *sharedInstance;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:nil] realInit];
    });
    
    return sharedInstance;
}

- (id)realInit {
	if (!(self = [super init])) {
		return nil;
	}
	
	// Repair the config if needed.
	[[GPGOptions sharedOptions] repairGPGConf];

	_mutableAllKeys = [[NSMutableSet alloc] init];
	_keyLoadingQueue = dispatch_queue_create("org.gpgtools.libmacgpg.GPGKeyManager.key-loader", NULL);
	_keyChangeNotificationQueue = dispatch_queue_create("org.gpgtools.libmacgpg.GPGKeyManager.key-change", NULL);
	// Start listening to keyring modifications notifcations.
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeysChangedNotification object:nil];
	_completionQueue = NULL;
	
	_allKeysAndSubkeysOnce = dispatch_semaphore_create(1);

	
	_keyLoadingOperations = [[NSMutableArray alloc] init];
	_keyLoadingOperationsLock = dispatch_queue_create("org.gpgtools.libmacgpg.GPGKeyManager.key-loader-lock", NULL);

	[GPGKeyMonitoring sharedInstance];
	
	return self;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];
}

- (id)init {
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

- (oneway void)release {
}

- (id)autorelease {
    return self;
}



@end
