//
//  GPGVerifyingKeyserver.m
//  Libmacgpg
//
//  Created by Mento on 24.06.19.
//
#if !__has_feature(objc_arc)
#error This files requires ARC.
#endif

#import "GPGVerifyingKeyserver.h"
#import "GPGException.h"
#import "GPGUnArmor.h"
#import "GPGMemoryStream.h"


NSString * const GPGVKSStateUnpublished = @"unpublished";
NSString * const GPGVKSStatePending = @"pending";
NSString * const GPGVKSStatePublished = @"published";
NSString * const GPGVKSStateRevoked = @"revoked";



@implementation GPGVerifyingKeyserver


- (void)uploadKey:(NSString *)armored callback:(GPGVKSUploadCallback)callback {
	if (armored.length == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No key given" userInfo:nil];
	}
	if (!callback) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No callback given" userInfo:nil];
	}
	callback = [callback copy];

	
	GPGVKSUploadCallback asyncCallback = [^(NSArray *fingerprintsArg, NSDictionary<NSString *,NSString *> *statusArg, NSString *tokenArg, NSError *errorArg) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			callback(fingerprintsArg, statusArg, tokenArg, errorArg);
		});
	} copy];
	#define failed(x) do { asyncCallback(nil, nil, nil, x); return; } while (0) // Helper macro to return an error.
	
	
	// The upload request contains the armored key in the JSON field "keytext".
	// For details see: https://keys.openpgp.org/about/api
	NSDictionary *uploadDict = @{@"keytext": armored};

	NSURL *url = [self urlWithQuery:@"/vks/v1/upload"];
	
	
	[self sendRequestToURL:url data:uploadDict completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
		
		if (error) {
			// The request failed.
			failed(error);
		}
		
		NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (error) {
			// JSON could not be parsed.
			failed(error);
		}
		
		if (response.statusCode != 200) {
			// The server returned an error. Return the error from JSON if possible.
			NSString *errorDescription = nil;
			if ([result isKindOfClass:NSDictionary.class] && result[@"error"]) {
				errorDescription = result[@"error"];
			} else {
				// The JSON does not contain an "error" field. Should not happen.
				errorDescription = @"Invalid response: error is missing.";
			}
			failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: errorDescription}]);
		}
		
		
		if ([result isKindOfClass:NSDictionary.class]) {
			// The normal case. A "single" key was successfully uploaded.
			/* result is a dictionary in the form:
			 * @{
			 *     @"key_fpr": @"Fingerprint of the uploaded key",
			 *     @"token": @"token_value",
			 *     @"status": @{
			 *         @"e-mail-address1": @"unpublished",
			 *         @"e-mail-address2": @"pending"
			 *     }
			 * }
			 */
			
			// Verify "result" looks like it should.
			NSString *fingerprint = result[@"key_fpr"];
			if (![fingerprint isKindOfClass:NSString.class] || fingerprint.length != 40) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: key_fpr"}]);
			}
			
			NSString *responseToken = result[@"token"];
			if (![responseToken isKindOfClass:NSString.class] || responseToken.length == 0) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: token."}]);
			}
			
			NSDictionary *status = result[@"status"];
			if (![status isKindOfClass:NSDictionary.class]) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: status not a dictionary."}]);
			}
			
			NSArray *validStates = @[GPGVKSStateUnpublished, GPGVKSStatePending, GPGVKSStatePublished, GPGVKSStateRevoked];
			for (NSString *emailAddress in status) {
				NSString *state = status[emailAddress];
				if (![state isKindOfClass:NSString.class] || ![validStates containsObject:state]) {
					failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: status not valid."}]);
				}
			}
			
			// Upload successful, time for the callback.
			asyncCallback(@[fingerprint], status, responseToken, nil);
			
		} else if ([result isKindOfClass:NSArray.class]) {
			// Multiple keys were uploaded.
			// The result is an array containing the fingerprints of the uploaded keys.
			
			NSArray *arrayResult = (NSArray *)result;
			asyncCallback(arrayResult, nil, nil, nil);
			
		} else {
			// The JSON should be a dictionary or array, but it was not.
			failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Unknown JSON response"}]);
		}

	}];
	
	#undef failed
}


- (void)requestVerification:(NSArray *)emailAddresses token:(NSString *)token callback:(GPGVKSUploadCallback)callback {
	if (emailAddresses.count == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No Email addresses given" userInfo:nil];
	}
	if (token.length == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No token given" userInfo:nil];
	}
	if (!callback) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No callback given" userInfo:nil];
	}
	callback = [callback copy];

	
	GPGVKSUploadCallback asyncCallback = [^(NSArray *fingerprintsArg, NSDictionary<NSString *,NSString *> *statusArg, NSString *tokenArg, NSError *errorArg) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			callback(fingerprintsArg, statusArg, tokenArg, errorArg);
		});
	} copy];
	#define failed(x) do { asyncCallback(nil, nil, nil, x); return; } while (0) // Helper macro to return an error.

	
	// Request the verify email to be in the user's language.
	NSString *languageCode = [NSLocale currentLocale].languageCode;

	
	// The verify request contains at least the array of email addresses and the token.
	// For details see: https://keys.openpgp.org/about/api
	NSDictionary *verifyDict = @{@"addresses": emailAddresses,
								 @"token": token,
								 @"locale": @[languageCode]};
	
	NSURL *url = [self urlWithQuery:@"/vks/v1/request-verify"];


	[self sendRequestToURL:url data:verifyDict completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

		if (error) {
			// The request failed.
			failed(error);
		}
		
		NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (error) {
			// JSON could not be parsed.
			failed(error);
		}
		
		if (response.statusCode != 200) {
			// The server returned an error. Return the error from JSON if possible.
			NSString *errorDescription = nil;
			if ([result isKindOfClass:NSDictionary.class] && result[@"error"]) {
				errorDescription = result[@"error"];
			} else {
				// The JSON does not contain an "error" field. Should not happen.
				errorDescription = @"Invalid response: error is missing.";
			}
			failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: errorDescription}]);
		}
		
		
		if ([result isKindOfClass:NSDictionary.class]) {
			// The normal response.
			/* result is a dictionary in the form:
			 * @{
			 *     @"key_fpr": @"Fingerprint of the uploaded key",
			 *     @"token": @"token_value",
			 *     @"status": @{
			 *         @"e-mail-address1": @"unpublished",
			 *         @"e-mail-address2": @"pending"
			 *     }
			 * }
			 */
			
			// Verify "result" looks like it should.
			NSString *fingerprint = result[@"key_fpr"];
			if (![fingerprint isKindOfClass:NSString.class] || fingerprint.length != 40) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: key_fpr"}]);
			}
			
			NSString *responseToken = result[@"token"];
			if (![responseToken isKindOfClass:NSString.class] || responseToken.length == 0) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: token."}]);
			}
			
			NSDictionary *status = result[@"status"];
			if (![status isKindOfClass:NSDictionary.class]) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: status not a dictionary."}]);
			}
			
			NSArray *validStates = @[GPGVKSStateUnpublished, GPGVKSStatePending, GPGVKSStatePublished, GPGVKSStateRevoked];
			for (NSString *emailAddress in status) {
				NSString *state = status[emailAddress];
				if (![state isKindOfClass:NSString.class] || ![validStates containsObject:state]) {
					failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Invalid response: status not valid."}]);
				}
			}
			
			// Request successful, time for the callback.
			asyncCallback(@[fingerprint], status, responseToken, nil);
			
		} else {
			// The JSON should be a dictionary, but it was not.
			failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Unknown JSON response"}]);
		}

	}];
	
	#undef failed
}


- (void)downloadKeys:(NSArray *)identifiers callback:(GPGVKSDownloadCallback)callback {
	if (identifiers.count == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No identifiers given" userInfo:nil];
	}
	if (!callback) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No callback given" userInfo:nil];
	}
	callback = [callback copy];
	
	
	GPGVKSDownloadCallback asyncCallback = [^(NSData *keyDataArg, NSError *errorArg) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			callback(keyDataArg, errorArg);
		});
	} copy];
	#define failed(x) do { asyncCallback(nil, x); return; } while (0) // Helper macro to return an error.

	
	// Build a list of all urls to fetch.
	NSMutableArray *urls = [NSMutableArray new];
	NSCharacterSet *nonHexCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"].invertedSet;
	for (NSString *theIdentifier in identifiers) {
		NSString *identifier = theIdentifier.description; // Use description here, if searchTerm is a GPGKey instead of an NSString.
		NSString *searchTyp;
		if ([identifier rangeOfString:@"@"].location != NSNotFound) {
			// identifier is an email-address.
			searchTyp = @"email";
		} else {
			NSUInteger length = identifier.length;
			BOOL onlyHexChars = [identifier rangeOfCharacterFromSet:nonHexCharSet].location == NSNotFound;
			if (onlyHexChars && length == 40) {
				// identifier is a fingerprint.
				searchTyp = @"fingerprint";
			} else if (onlyHexChars && length == 16) {
				// identifier is a keyID.
				searchTyp = @"keyid";
			} else {
				// identifier is not valid.
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Invalid identifier" userInfo:nil];
			}
		}
		
		NSString *escapedIdentifier = [identifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSURL *url = [self urlWithQuery:[NSString stringWithFormat:@"/vks/v1/by-%@/%@", searchTyp, escapedIdentifier]];
		[urls addObject:url];
	}
	
	
	__block NSObject *lock = [NSObject new];
	__block BOOL canceled = NO;
	__block NSMutableData *receivedData = [NSMutableData new];
	dispatch_group_t dispatchGroup = dispatch_group_create();
	dispatch_group_enter(dispatchGroup); // dispatch_group_enter and _leave are used, to run this block, after all downloads.
	
	
	dispatch_group_notify(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// This block is called, after all keys are downloaded.

		// canceled is YES when an error occurred and the callback has run.
		if (!canceled) {
			asyncCallback(receivedData.copy, nil);
		}
	});
	
	
	// Download the keys in parallel.
	for (NSURL *url in urls) {
		dispatch_group_enter(dispatchGroup);
		
		
		[self sendRequestToURL:url data:nil completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
			
			if (!error && !canceled && response.statusCode == 200) {
				// A key was found.
				GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:data];
				GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
				NSData *unarmoredData = [unArmor decodeAll];
				if (unarmoredData.length < 10) {
					error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Unarmor failed"}];
				} else {
					@synchronized (lock) {
						[receivedData appendData:unarmoredData];
					}
				}
			}
			if (error) {
				@synchronized (lock) {
					if (!canceled) {
						canceled = YES;
						
						// Only the first error triggers the failed callback.
						failed(error);
					}
				}
			}
			
			dispatch_group_leave(dispatchGroup);

		}];

	}
	dispatch_group_leave(dispatchGroup);

	#undef failed
}


- (void)searchKeys:(NSArray *)searchTerms callback:(GPGVKSSearchCallback)callback {
	if (searchTerms.count == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No identifiers given" userInfo:nil];
	}
	if (!callback) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No callback given" userInfo:nil];
	}
	callback = [callback copy];
	
	
	GPGVKSDownloadCallback asyncCallback = [^(NSArray<GPGRemoteKey *> *foundKeysArg, NSError *errorArg) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			callback(foundKeysArg, errorArg);
		});
	} copy];
	#define failed(x) do { asyncCallback(nil, x); return; } while (0) // Helper macro to return an error.
	
	
	__block NSObject *lock = [NSObject new];
	__block BOOL canceled = NO;
	__block NSMutableArray<GPGRemoteKey *> *foundKeys = [NSMutableArray new];
	dispatch_group_t dispatchGroup = dispatch_group_create();
	dispatch_group_enter(dispatchGroup); // dispatch_group_enter and _leave are used, to run this block, after all downloads.
	
	
	dispatch_group_notify(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// This block is called, after all search requests completed.
		
		 // canceled is YES when an error occurred and the callback has run.
		if (!canceled) {
			asyncCallback(foundKeys.copy, nil);
		}
	});
	
	
	// Search the keys in parallel.
	for (NSString *searchTerm in searchTerms) {
		dispatch_group_enter(dispatchGroup);
		
		NSString *escapedTerm = [searchTerm.description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]; // Use description here, if searchTerm is a GPGKey instead of an NSString.
		
		// Use pks instead of vks here, so we get info about the key and don't have to parse the key.
		// In a future version, this can be changed, to get more detaild infomation about the key.
		NSURL *url = [self urlWithQuery:[NSString stringWithFormat:@"/pks/lookup?op=index&options=mr&search=%@", escapedTerm]];

		
		[self sendRequestToURL:url data:nil completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

			if (!error && !canceled && response.statusCode == 200) {
				// A key was found.
				@try { // -keysWithListing: may throw an exception, if the listing isn't well-formed.
					NSString *listing = data.gpgString;
					NSArray<GPGRemoteKey *> *remoteKeys = [GPGRemoteKey keysWithListing:listing fromVKS:YES];
					@synchronized (lock) {
						[foundKeys addObjectsFromArray:remoteKeys];
					}
				} @catch (NSException *exception) {
					error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorKeyServerError userInfo:@{NSLocalizedDescriptionKey: @"Unable to parse key listing"}];
				}
			}
			if (error) {
				@synchronized (lock) {
					if (!canceled) {
						canceled = YES;
						
						// Only the first error triggers the failed callback.
						failed(error);
					}
				}
			}
			
			dispatch_group_leave(dispatchGroup);
			
		}];
		
	}
	dispatch_group_leave(dispatchGroup);
	
	#undef failed
}




- (NSURLSessionDataTask *)sendRequestToURL:(NSURL *)url data:(id)data completionHandler:(void (^)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
	// This method handles the complexity of NSURLRequest, NSURLSession and NSURLSessionDataTask.

	NSError *error = nil;
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:0 timeoutInterval:self.timeout];
	completionHandler = [completionHandler copy];
	#define failed(x) do { completionHandler(nil, nil, x); return nil; } while (0) // Helper macro to return an error.

	
	if (data) {
		// data can be NSDictionary, NSString or NSData.
		// The request will have a JSON body.
		
		NSData *encodedData;
		if ([data isKindOfClass:NSDictionary.class]) {
			encodedData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
			if (!encodedData) {
				failed(error);
			}
		} else if ([data isKindOfClass:NSString.class]) {
			encodedData = [data dataUsingEncoding:NSUTF8StringEncoding];
			if (!encodedData) {
				failed([NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorUnsupportedEncoding userInfo:@{NSLocalizedDescriptionKey: @"data is not an UTF8 string"}]);
			}
		} else if ([data isKindOfClass:NSData.class]) {
			encodedData = data;
		} else {
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"data should ne NSDictionary, NSString or NSData" userInfo:nil];
		}
		
		[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		request.HTTPMethod = @"POST";
		request.HTTPBody = encodedData;
	}

	
	// Send the request asynchronous to the server.
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
	
	// Call completionHandler, when the request has finished.
	NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable theData, NSURLResponse * _Nullable theResponse, NSError * _Nullable theError) {
		NSHTTPURLResponse *response = (NSHTTPURLResponse *)theResponse; // We did a HTTP request, so it is always an NSHTTPURLResponse.
		completionHandler(theData, response, theError);
	}];
	
	// Send the request.
	[dataTask resume];

	
	#undef failed
	return dataTask;
}


- (NSURL *)urlWithQuery:(NSString *)query {
	// self.keyserver should to be as server address with scheme and domain, without any trailing chars like a slash or so.
	NSString *urlString = [NSString stringWithFormat:@"%@%@", self.keyserver, query];
	return [NSURL URLWithString:urlString];
}


- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	
	self.keyserver = @"https://keys.openpgp.org";
	self.timeout = 20;
	
	return self;
}



@end
