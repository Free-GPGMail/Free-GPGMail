//
//  GPGKeyMonitoring.m
//  Libmacgpg
//
//  Created by Mento on 05.07.18.
//

#import "GPGKeyMonitoring.h"
#import "GPGKeyManager.h"
#import "GPGKey.h"
#import "GPGOptions.h"
#import "GPGGlobals.h"
#import "GPGController.h"


static NSString * const keyMonitoringKey = @"keyMonitoring"; // NSDictionary.
static NSString * const lastWarningTimeKey = @"lastWarningTime"; // NSNumber with double.
static NSString * const doNotWarnAgainKey = @"doNotWarnAgain"; // NSNumber with bool.

static NSString * const keyMonitoringPing = @"GPGKeyMonitoringPing";
static NSString * const keyMonitoringPong = @"GPGKeyMonitoringPong";



@interface GPGKeyWarningInfo : NSObject
@property (nonatomic, strong) GPGKey *primaryKey;
@property (nonatomic, strong) NSMutableArray<GPGKey *> *keys;
@property (nonatomic) BOOL warnForPirmary;
@property (nonatomic) NSTimeInterval expirationTime;
@end
@implementation GPGKeyWarningInfo
- (instancetype)init {
	self = [super init];
	self.keys = [[NSMutableArray new] autorelease];
	return self;
}
- (void)dealloc {
	self.keys = nil;
	self.primaryKey = nil;
	[super dealloc];
}
@end




@interface GPGKeyMonitoring ()
@property (nonatomic) dispatch_source_t timer;
@property (nonatomic) BOOL pongReceived;
@property (nonatomic, getter=isMasterInstance) BOOL masterInstance;
@property (nonatomic) uint64_t timestamp;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) NSLock *lock;
@end


@implementation GPGKeyMonitoring

- (void)setupMonitoring {
	self.timestamp = (uint64_t)([NSDate date].timeIntervalSinceReferenceDate * 1000000);
	self.identifier = [NSString stringWithFormat:@"%llu %@", self.timestamp, [NSUUID UUID].UUIDString];

	NSDistributedNotificationCenter *notificationCenter = [NSDistributedNotificationCenter defaultCenter];
	
	// Look for notifications from KeyMonitoring instances in other apps.
	[notificationCenter addObserver:self selector:@selector(handleKeyMonitoringPong:) name:keyMonitoringPong object:nil];
	[notificationCenter addObserver:self selector:@selector(handleKeyMonitoringPing:) name:keyMonitoringPing object:nil];

	
	// Wait a second to give other possible instances time to set up.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), self.dispatchQueue, ^{
		// Test if another KeyMonitoring instance is out there. Send a Ping and wait for a Pong.
		[notificationCenter postNotificationName:keyMonitoringPing object:self.identifier userInfo:nil deliverImmediately:YES];
		
		
		// Wait 4 seconds for a possible Pong.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), self.dispatchQueue, ^{
			if (self.pongReceived) {
				// Some other KeyMonitoring instance is already running.
				self.masterInstance = NO;
			} else {
				// There was no Pong. This is the one and only KeyMonitoring instance.
				dispatch_async(self.dispatchQueue, ^{
					[self checkKeysFirstTime:YES];
				});
			}
			
			uint64_t firstRun = 20; // Check keys for the first time after 20 minutes.
			uint64_t interval = 180; // Check again every 3 hours.
			
			uint64_t minute = 60 * NSEC_PER_SEC;
			dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.dispatchQueue);
			dispatch_time_t timerStart = dispatch_time(DISPATCH_TIME_NOW, firstRun * minute);
			dispatch_source_set_timer(timer, timerStart, interval * minute, 10 * minute);
			
			dispatch_source_set_event_handler(timer, ^{
				if (self.isMasterInstance) {
					// Only the master instace checks the keys, to prevent multiple dialogs from different apps.
					[self checkKeysFirstTime:NO];
				} else {
					// The last time we tried, another instace was there. Test again, if it's still there.
					self.pongReceived = NO;
					[notificationCenter postNotificationName:keyMonitoringPing object:self.identifier userInfo:nil deliverImmediately:YES];
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), self.dispatchQueue, ^{
						if (!self.pongReceived) {
							self.masterInstance = YES;
							[self checkKeysFirstTime:NO];
						}
					});
				}
			});
			dispatch_resume(timer);
			
			self.timer = timer;
		});
	});
}

- (void)handleKeyMonitoringPing:(NSNotification *)notification {
	if (!self.isMasterInstance) {
		// We are not the master.
		return;
	}
	NSString *object = notification.object;
	if ([self.identifier isEqual:object]) {
		// Ignore own notifications.
		return;
	}
	
	// Tell the other app, we are already running. Ping -> Pong.
	NSDistributedNotificationCenter *notificationCenter = [NSDistributedNotificationCenter defaultCenter];
	[notificationCenter postNotificationName:keyMonitoringPong object:self.identifier userInfo:nil deliverImmediately:YES];
}
- (void)handleKeyMonitoringPong:(NSNotification *)notification {
	NSString *object = notification.object;
	if ([self.identifier isEqual:object]) {
		// Ignore own notifications.
		return;
	}
	
	if (![object isKindOfClass:[NSString class]]) {
		// object should be a string.
		return;
	}
	
	
	NSScanner *scanner = [NSScanner scannerWithString:object];
	uint64_t timestamp = 0;
	[scanner scanUnsignedLongLong:&timestamp];
	
	if (timestamp == 0 || timestamp > self.timestamp) {
		// The other instance is older than this instance.
		return;
	}

	self.pongReceived = YES;
}


- (void)checkKeysFirstTime:(BOOL)firstTime {
	// Checks all secret keys if they expire soon.
	// When firstTime is YES a dialog is only displayed, if a key expires very soon.
	
	if ([NSThread isMainThread]) {
		GPGDebugLog(@"GPGKeyMonitoring -checkKeysFirstTime: called on main thread!");
		return;
	}
	if (![self.lock tryLock]) {
		// Another check is in progress.
		// Most likely the user is not at the computer and a dialog waits for input.
		return;
	}
	
	NSTimeInterval week = 86400 * 7;
	NSTimeInterval instantWarnTime = week; // If a key expires in this time, the warning is dislpayed immediately after the start.
	NSTimeInterval maxExpiredTime = 4 * week; // If a key is expired since more than this time, the warning is not shown.
	NSTimeInterval normalWarnTime = 4 * week; // Do not warn for this keys, if firstTime is YES.
	NSTimeInterval warnSubkeyTolerance = 2 * week; // If a subkey expires not more than two weeks after the primary, both are extended together.

	
	GPGKeyManager *keyManager = [GPGKeyManager sharedInstance];
	NSSet *secretKeys = [keyManager secretKeys];
	NSTimeInterval currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
	NSMutableDictionary *keyMonitoring = [[GPGOptions sharedOptions] valueInCommonDefaultsForKey:keyMonitoringKey];
	NSMutableArray<GPGKeyWarningInfo *> *instantWarnings = [[NSMutableArray new] autorelease];
	NSMutableArray<GPGKeyWarningInfo *> *normalWarnings = [[NSMutableArray new] autorelease];

	
	if (!keyMonitoring || ![keyMonitoring isKindOfClass:[NSDictionary class]]) {
		keyMonitoring = [[NSMutableDictionary new] autorelease];
	} else {
		keyMonitoring = [keyMonitoring.mutableCopy autorelease];
	}
	
	
	for (GPGKey *primaryKey in secretKeys) {
		__block GPGKeyWarningInfo *warningInfo = [[GPGKeyWarningInfo new] autorelease];
		__block BOOL shouldWarnInstant = NO;
		__block BOOL shouldWarn = NO;
		__block BOOL doNotWarn = NO; // Is set to yes if the key is invalid or the user decided to never warn again.
		
		warningInfo.primaryKey = primaryKey;
		
		void (^checkKey)(GPGKey *, NSUInteger, BOOL *) = ^(GPGKey *key, __unused NSUInteger idx, __unused BOOL *stop) {
			NSString *fingerprint = key.fingerprint;
			NSDictionary *dict = keyMonitoring[fingerprint];
			
			BOOL doNotWarnAgain = [dict[doNotWarnAgainKey] boolValue] || [keyMonitoring[key.primaryKey.fingerprint][doNotWarnAgainKey] boolValue];
			if (doNotWarnAgain) {
				doNotWarn = YES;
				return;
			}
			
			NSTimeInterval lastWarning = [dict[lastWarningTimeKey] doubleValue];
			NSTimeInterval expires = key.expirationDate.timeIntervalSinceReferenceDate;
	
			if (expires == 0) {
				// The key never expires.
				return;
			}
			if ((key.validity & ~GPGValidityExpired) >= GPGValidityInvalid) {
				// The key is invalid, revoked or disabled.
				doNotWarn = YES;
				return;
			}
	
			
			if (currentTime - lastWarning < 1 * week) {
				// The user was warned less than one week before.
				return;
			}

			NSTimeInterval timeToExpire = expires - currentTime;
			if (timeToExpire < instantWarnTime) {
				if (timeToExpire < 0 - maxExpiredTime) {
					// The key is already expired for a too long time.
					doNotWarn = YES;
					return;
				}
				
				// The key will expire very soon.
				shouldWarnInstant = YES;
			}

			if (timeToExpire < normalWarnTime ) {
				// The key will expire in the near future.
				shouldWarn = YES;
			}
			
			if (timeToExpire < normalWarnTime + warnSubkeyTolerance) {
				// Every key in the tolerance time will be added to the list.
				// But only if shouldWarn is set for at least one of the (sub)keys, the warning alert is shown.
				
				if (warningInfo.expirationTime == 0 || expires < warningInfo.expirationTime) {
					// Store the earliest expiration set.
					warningInfo.expirationTime = expires;
				}
				[warningInfo.keys addObject:key];
				if (key.primaryKey == key) {
					warningInfo.warnForPirmary = YES;
				}
			}
		};
		
		// First check if we should warn for the primary key.
		checkKey(primaryKey, 0, nil);
		if (!doNotWarn) {
			// Only check the subkeys, if the primary key is not invalid and the user did not disable the warning.
			[primaryKey.subkeys enumerateObjectsUsingBlock:checkKey];
		}
		
		if (!shouldWarn) {
			// No need to warn for this key.
			continue;
		}
		
		if (shouldWarnInstant) {
			[instantWarnings addObject:warningInfo];
		} else {
			[normalWarnings addObject:warningInfo];
		}
	}
	
	
	if (instantWarnings.count > 0 || (normalWarnings.count > 0 && firstTime == NO)) {
		// First warn for keys which expire soon.
		[instantWarnings addObjectsFromArray:normalWarnings];
		
		for (GPGKeyWarningInfo *info in instantWarnings) {
			BOOL doNotWarnAgain = [self showExpiryWarning:info];
			
			// Update the plist.
			for (GPGKey *key in info.keys) {
				NSMutableDictionary *dict = keyMonitoring[key.fingerprint];
				
				if ([dict isKindOfClass:[NSDictionary class]]) {
					dict = [dict.mutableCopy autorelease];
				} else {
					dict = [[NSMutableDictionary new] autorelease];
				}
				dict[lastWarningTimeKey] = @([NSDate timeIntervalSinceReferenceDate]);
				if (doNotWarnAgain) {
					dict[doNotWarnAgainKey] = @YES;
				}
				
				keyMonitoring[key.fingerprint] = dict;
				[[GPGOptions sharedOptions] setValueInCommonDefaults:[keyMonitoring.copy autorelease] forKey:keyMonitoringKey];
			}
			
		}
	}
	
	[self.lock unlock];
}

- (BOOL)showExpiryWarning:(GPGKeyWarningInfo *)info {
	// Retunrs YES when the user clicked on "Do Not Ask Again"
	
	NSString *prefix = info.warnForPirmary ? @"KeyExpiryWarning" : @"SubkeyExpiryWarning";

	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];

	NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceReferenceDate:info.expirationTime];
	NSString *formattedDate = [NSDateFormatter localizedStringFromDate:expirationDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];

	NSArray *listedKeys;
	if (info.warnForPirmary) {
		listedKeys = @[info.primaryKey];
	} else {
		listedKeys = info.keys;
	}
	NSString *keyDescription = [[GPGKeyManager sharedInstance] descriptionForKeys:listedKeys];
	
	
	NSModalResponse response = [self showAlertWithButtons:@[@"Yes", @"No", @"Suppress"] prefix:prefix, formattedDate, keyDescription];
	
	
	if (response == NSAlertThirdButtonReturn) {
		// Do not show a warning for this key again.
		return YES;
	}
	if (response != NSAlertFirstButtonReturn) {
		// Do not extend this key.
		return NO;
	}
	
	
	
	
	// Asnc test if the key exists on the keyserver.
	__block BOOL keyExistsOnServer = NO;
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	dispatch_retain(semaphore);
	
	GPGController *keyExistsGPGC = [GPGController gpgController];
	keyExistsGPGC.keyserverTimeout = 2;
	[keyExistsGPGC keysExistOnServer:@[info.primaryKey] callback:^(NSArray *existingKeys, NSArray *nonExistingKeys) {
		keyExistsOnServer = existingKeys.count == 1;
		
		dispatch_semaphore_signal(semaphore);
		dispatch_release(semaphore);
	}];

	
	
	
	GPGController *gpgc = [GPGController gpgController];
	BOOL failed = NO;
	NSArray<GPGKey *> *keys = info.keys;
	NSUInteger i = 0;
	NSUInteger count = keys.count;
	
	for (; i < count;) {
		BOOL tryAgain = NO;
		GPGKey *key = keys[i];
		GPGKey *subkey = key == info.primaryKey ? nil : key;
		
		[gpgc setExpirationDate:[NSDate dateWithTimeIntervalSinceNow:86400 * 365 * 2]
					 forSubkeys:subkey ? @[subkey] : nil
						  ofKey:info.primaryKey];
		
		if (gpgc.error) {
			failed = YES;
			NSException *exception = gpgc.error;
			if ([exception isKindOfClass:[GPGException class]]) {
				GPGErrorCode errorCode = ((GPGException *)exception).errorCode;
				if (errorCode == GPGErrorCancelled) {
					break;
				}
				if (errorCode == GPGErrorBadPassphrase) {
					tryAgain = [self wrongPasswordEnteredForKey:key];
					if (tryAgain) {
						failed = NO;
						continue; // Do not increment i.
					} else {
						break;
					}
				}
				
			}
			
			[self showAlertWithButtons:nil prefix:@"KeyExpiryFailed", keyDescription, exception.description];
			break;
		}
		
		
		// Incerment i here, so continue can be used to jump over the increment.
		i++;
	}

	if (!failed) {
		// Wait for the result from -keysExistOnServer.
		dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
		dispatch_semaphore_wait(semaphore, timeout);

		
		NSArray *buttons;
		NSModalResponse yesButton;
		if (keyExistsOnServer) {
			buttons = @[@"Yes", @"No"];
			yesButton = NSAlertFirstButtonReturn;
		} else {
			buttons = @[@"No", @"Yes"];
			yesButton = NSAlertSecondButtonReturn;
		}
		
		NSModalResponse result = [self showAlertWithButtons:buttons prefix:@"KeyExtendedWantToUpload"];
		if (result == yesButton) {
			[gpgc sendKeysToServer:@[info.primaryKey]];
			
			if (gpgc.error) {
				[self showAlertWithButtons:nil prefix:@"UploadFailed", gpgc.error.description];
			}
		}
	}
	
	dispatch_release(semaphore);

	
	return NO;
}

- (BOOL)wrongPasswordEnteredForKey:(GPGKey *)key {
	NSModalResponse result = [self showAlertWithButtons:@[@"Yes", @"No"] prefix:@"WrongPasswordTryAgain"];
	if (result == NSAlertFirstButtonReturn) {
		return YES;
	}

	return NO;
}


- (NSModalResponse)showAlertWithButtons:(NSArray<NSString *> *)buttons prefix:(NSString *)prefix, ...  {
	prefix = [prefix stringByAppendingString:@"_"];

	NSString *title = localizedLibmacgpgString([prefix stringByAppendingString:@"Title"]);

	NSString *format = localizedLibmacgpgString([prefix stringByAppendingString:@"Msg"]);
	va_list args;
	va_start(args, prefix);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);

	__block NSModalResponse result;
	
	void (^block)() = ^{
		NSAlert *alert = [[NSAlert new] autorelease];
		alert.messageText = title;
		alert.informativeText = message;
		
		for (NSString *button in buttons) {
			[alert addButtonWithTitle:localizedLibmacgpgString([prefix stringByAppendingString:button])];
		}

		NSWindow *sheetWindow = self.sheetWindow;
		if (sheetWindow) {
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
			
			[alert beginSheetModalForWindow:sheetWindow completionHandler:^(NSModalResponse returnCode) {
				result = returnCode;
				dispatch_semaphore_signal(semaphore);
			}];
			
			dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
		} else {
			result = [alert runModal];
		}
	};
	
	if ([NSThread isMainThread]) {
		block();
	} else {
		dispatch_sync(dispatch_get_main_queue(), block);
	}

	return result;
}


#pragma mark Singleton

+ (instancetype)sharedInstance {
	static dispatch_once_t onceToken;
	static GPGKeyMonitoring *sharedInstance;
	
	dispatch_once(&onceToken, ^{
		sharedInstance = [[super allocWithZone:nil] realInit];
	});
	
	return sharedInstance;
}

- (instancetype)realInit {
	if (!(self = [super init])) {
		return nil;
	}
	
	self.lock = [[NSLock new] autorelease];
	self.masterInstance = YES;
	self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);

	[self performSelectorOnMainThread:@selector(setupMonitoring) withObject:nil waitUntilDone:NO];

	return self;
}

+ (id)allocWithZone:(NSZone *)zone {
	return [[self sharedInstance] retain];
}

- (instancetype)init {
	return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
	return self;
}

- (instancetype)retain {
	return self;
}

- (NSUInteger)retainCount {
	return NSUIntegerMax;
}

- (oneway void)release {
}

- (instancetype)autorelease {
	return self;
}



@end
