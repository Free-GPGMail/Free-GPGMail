#import "GPGKeyFetcher.h"
#import "Libmacgpg.h"
#import "GPGKeyserver.h"

@implementation GPGKeyFetcher


- (void)fetchKeyForMailAddress:(NSString *)mailAddress block:(void (^)(NSData *data, NSString *verifiedMail, NSError *error))block {
	NSLog(@"Fetch key for '%@'", mailAddress);
	NSString *keyserverAddress = @"hkps://hkps.pool.sks-keyservers.net";
	NSUInteger timeout = 30;
	
	
	mailAddress = mailAddress.lowercaseString; // We need it immutable for NSCache and want it in lower case for comparsion.
	
	// Is the email address in the cache?
	NSDictionary *chachedEntry = [cache objectForKey:mailAddress];
	if (chachedEntry) {
		// Return cached result.
		block(chachedEntry[@"data"], chachedEntry[@"verifiedMail"], nil);
		return;
	}

	
	// Saves the result in the cache if necessary and return the result.
	void (^handleResult)(NSData *, NSHTTPURLResponse *, NSError *) = ^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
		// A valid response contains at least 100 bytes of data and is armored.
		if (data.length > 100 && data.isArmored) {
			// UnArmor the data.
			data = [[GPGUnArmor unArmor:[GPGMemoryStream memoryStreamForReading:data]] readAllData];
		} else {
			data = nil;
		}
		
		
		// Only cache if the server says the key was found or there is no key for this mail address.
		// Don't cache if there was a connectionError or something.
		NSInteger statusCode = response.statusCode;
		if (statusCode == 200 || statusCode == 404) {
			NSDictionary *cacheEntry = [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", nil];
			[cache setObject:cacheEntry forKey:mailAddress];
		}
		
		// Return the result. verifiedMail is alwas nil because we don't have whiteout anymore.
		block(data, nil, error);
	};
	
	
	
	// Use GPGKeyserver to search for all keys with the given email address.
	GPGKeyserver *theSearchServer = [[GPGKeyserver alloc] initWithFinishedHandler:^(GPGKeyserver *searchServer) {
		// Parse the response.
		NSArray *keys = [GPGRemoteKey keysWithListing:searchServer.receivedData.gpgString];
		
		// List of prefered keys.
		// Normally the first valid key is fetched, if one of these keys is found it is fetched instead.
		NSArray *gpgtoolsKeys = @[@"85E38F69046B44C1EC9FB07B76D78F0500D026C4"/*Team*/,
								  @"55AB1B128F18E135A522A12DDD1C907A50FE9D32"/*Alex*/,
								  @"608B00ABE1DAA3501C5FF91AE58271326F9F4937"/*Luke*/,
								  @"BDA498EAC51993F2FC97DAB2DA870C1346A957B0"/*Mento*/,
								  @"8C371C40B31DA620815E01A9779FEB1392CBBADF"/*Steve*/];
		
		GPGRemoteKey *bestKey = nil;
		for (GPGRemoteKey *key in keys) {
			if (key.expired == NO && key.revoked == NO) {
				if ([gpgtoolsKeys containsObject:key]) {
					// Found a GPGTools key, use it.
					bestKey = key;
					break;
				} else if (bestKey == nil) {
					// Found a valid key, remember it.
					bestKey = key;
				}
			}
		}
		
		
		if (bestKey) {
			// Fetch the best key.
			GPGKeyserver *theGetServer = [[GPGKeyserver alloc] initWithFinishedHandler:^(GPGKeyserver *getServer) {
				NSData *data = getServer.receivedData;
				NSHTTPURLResponse *response = getServer.response;
				NSError *error = getServer.error;
				
				// handleResult does the error handling and data processing.
				handleResult(data, response, error);
				
				// Don't forget to release the GPGKeyserver.
				[getServer release];
			}];
			
			theGetServer.keyserver = keyserverAddress;
			theGetServer.timeout = timeout;
			[theGetServer getKey:bestKey.fingerprint];
		} else {
			// No valid key found, possible reasons: invalid/no server response, no key found, all found keys are expired/revoked.
			handleResult(nil, searchServer.response, searchServer.error);
		}
		
		
		// Don't forget to release the GPGKeyserver.
		[searchServer release];
	}];
	
	
	theSearchServer.keyserver = keyserverAddress;
	theSearchServer.timeout = timeout;
	[theSearchServer searchKey:mailAddress];
}


- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	cache = [NSCache new];
	
	return self;
}

- (void)dealloc {
	[cache release];
	[super dealloc];
}



//
//
//
//- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
//	if (async && !asyncStarted) {
//		asyncStarted = YES;
//		[asyncProxy receiveKeysFromServer:keys];
//		return nil;
//	}
//	NSString *retVal = nil;
//	@try {
//		[self operationDidStart];
//		if ([keys count] == 0) {
//			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
//		}
//		
//		
//		__block NSException *exception = nil;
//		__block int32_t serversRunning = keys.count;
//		NSCondition *condition = [NSCondition new];
//		[condition lock];
//		
//		NSMutableData *keysToImport = [NSMutableData data];
//		NSLock *dataLock = [NSLock new];
//		
//		gpg_ks_finishedHandler handler = ^(GPGKeyserver *s) {
//			if (s.exception) {
//				exception = s.exception;
//			} else {
//				NSData *unArmored = [GPGPacket unArmor:s.receivedData];
//				if (unArmored) {
//					[dataLock lock];
//					[keysToImport appendData:unArmored];
//					[dataLock unlock];
//				}
//			}
//			
//			OSAtomicDecrement32Barrier(&serversRunning);
//			if (serversRunning == 0) {
//				[condition signal];
//			}
//		};
//		
//		for (NSString *key in keys) {
//			GPGKeyserver *server = [[GPGKeyserver alloc] initWithFinishedHandler:handler];
//			server.timeout = self.keyserverTimeout;
//			if (self.keyserver) {
//				server.keyserver = self.keyserver;
//			}
//			[gpgKeyservers addObject:server];
//			[server getKey:key.description];
//			[server release];
//		}
//		
//		while (serversRunning > 0) {
//			[condition wait];
//		}
//		
//		[condition unlock];
//		[condition release];
//		condition = nil;
//		
//		
//		[gpgKeyservers removeAllObjects];
//		
//		if (exception && keysToImport.length == 0) {
//			[self handleException:exception];
//		} else {
//			retVal = [self importFromData:keysToImport fullImport:NO];
//		}
//		
//	} @catch (NSException *e) {
//		[self handleException:e];
//	} @finally {
//		[self cleanAfterOperation];
//	}
//	
//	[self operationDidFinishWithReturnValue:retVal];
//	return retVal;
//}
//- (NSArray *)searchKeysOnServer:(NSString *)pattern {
//	if (async && !asyncStarted) {
//		asyncStarted = YES;
//		[asyncProxy searchKeysOnServer:pattern];
//		return nil;
//	}
//	
//	NSArray *keys = nil;
//	
//	@try {
//		[self operationDidStart];
//		
//		pattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//		NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
//		NSString *stringToCheck = nil;
//		
//		switch ([pattern length]) {
//			case 8:
//			case 16:
//			case 32:
//			case 40:
//				stringToCheck = pattern;
//				break;
//			case 9:
//			case 17:
//			case 33:
//			case 41:
//				if ([pattern hasPrefix:@"0"]) {
//					stringToCheck = [pattern substringFromIndex:1];
//				}
//				break;
//		}
//		
//		
//		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:noHexCharSet].length == 0) {
//			pattern = [@"0x" stringByAppendingString:stringToCheck];
//		}
//		
//		
//		__block BOOL running = YES;
//		NSCondition *condition = [NSCondition new];
//		[condition lock];
//		
//		
//		GPGKeyserver *server = [[GPGKeyserver alloc] initWithFinishedHandler:^(GPGKeyserver *s) {
//			running = NO;
//			[condition signal];
//		}];
//		server.timeout = self.keyserverTimeout;
//		if (self.keyserver) {
//			server.keyserver = self.keyserver;
//		}
//		[gpgKeyservers addObject:server];
//		
//		[server searchKey:pattern];
//		
//		
//		while (running) {
//			[condition wait];
//		}
//		
//		[condition unlock];
//		[condition release];
//		condition = nil;
//		
//		[gpgKeyservers removeObject:server];
//		
//		if (server.exception) {
//			[self handleException:server.exception];
//		} else {
//			keys = [GPGRemoteKey keysWithListing:[server.receivedData gpgString]];
//		}
//		
//		[server release];
//	} @catch (NSException *e) {
//		[self handleException:e];
//	} @finally {
//		[self cleanAfterOperation];
//	}
//	
//	[self operationDidFinishWithReturnValue:keys];
//	
//	return keys;
//}
//


@end
