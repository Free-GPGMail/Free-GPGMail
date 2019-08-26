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
 
 Diese Datei basiert auf GPGOptions.m von MacGPGME.
*/

#import "NSBundle+Sandbox.h"
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#import "GPGOptions.h"
#import "GPGConf.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "GPGGlobals.h"
#import "GPGUserDefaults.h"
#import "GPGWatcher.h"
#import "GPGTask.h"
#import "GPGTaskHelper.h"
#import "GPGController.h"

NSString * const GPGOptionsChangedNotification = @"GPGOptionsChangedNotification";
NSString * const GPGConfigurationModifiedNotification = @"GPGConfigurationModifiedNotification";
NSString * const GPGKeysFromVerifyingKeyserverKey = @"KeysFromVerifyingKeyserver";
NSString * const GPGUseSKSKeyserverAsBackupKey = @"UseSKSKeyserverAsBackup";

@interface GPGOptions ()
@property (nonatomic, readonly) NSMutableDictionary *commonDefaults;
@property (nonatomic, readonly) NSMutableDictionary *standardDefaults;
- (GPGConf *)gpgConf;
- (GPGConf *)gpgAgentConf;
- (GPGConf *)dirmngrConf;
+ (GPGOptionsDomain)domainForKey:(NSString *)key;
- (void)valueChanged:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)valueChangedNotification:(NSNotification *)notification;
- (void)dotConfChangedNotification:(NSNotification *)notification;

- (void)stopSystemConfigurationWatch;
@end


@implementation GPGOptions

NSString *commonDefaultsDomain = @"org.gpgtools.common";
NSDictionary *domainKeys;
NSMutableDictionary *defaults = nil;
uint8 debugLog;

static NSString * const kGpgConfKVKey = @"gpgConf";
static NSString * const kGpgAgentConfKVKey = @"gpgAgentConf";
static NSString * const kDirmngrConfKVKey = @"dirmngrConf";

// Methods to configure GPGOptions.
- (BOOL)autoSave {
	return autoSave;
}
- (void)setAutoSave:(BOOL)value {
	autoSave = value;
}

- (NSString *)standardDomain {
	return [[standardDomain retain] autorelease];
}
- (void)setStandardDomain:(NSString *)value {
	if (value != standardDomain) {
		[standardDefaults release];
		standardDefaults = nil;
		[standardDomain release];
		standardDomain = [value retain];
	}
}

- (void)registerDefaults:(NSDictionary *)dictionary {
	if (!defaults) {
		defaults = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
	} else {
		for (NSString *key in dictionary) {
			[defaults setObject:[dictionary objectForKey:key] forKey:key];
		}
	}
}



// Methods to get and set values.
- (void)setObject:(id)value forKey:(NSString *)key {
	[self setValue:value forKey:key];
}
- (id)objectForKey:(NSString *)key {
	return [self valueForKey:key];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithInteger:value] forKey:key];
}
- (NSInteger)integerForKey:(NSString *)key {
	return [[self valueForKey:key] integerValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithBool:value] forKey:key];
}
- (BOOL)boolForKey:(NSString *)key {
	return [[self valueForKey:key] boolValue];
}

- (void)setFloat:(float)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithFloat:value] forKey:key];
}
- (float)floatForKey:(NSString *)key {
	return [[self valueForKey:key] floatValue];
}

- (NSString *)stringForKey:(NSString *)key {
	NSString *obj = [self valueForKey:key];
	if (obj && [obj isKindOfClass:[NSString class]]) {
		return obj;
	}
	return nil;
}

- (NSArray *)arrayForKey:(NSString *)key {
	NSArray *obj = [self valueForKey:key];
	if (obj && [obj isKindOfClass:[NSArray class]]) {
		return obj;
	}
	return nil;
}


- (id)valueForKey:(NSString *)key {
	key = [[self class] standardizedKey:key];
	id value = [self valueForKey:key inDomain:[self domainForKey:key]];
	if (!value) {
		value = [defaults objectForKey:key];
	}
	return value;
}
- (void)setValue:(id)value forKey:(NSString *)key {
	key = [[self class] standardizedKey:key];
	[self setValue:value forKey:key inDomain:[self domainForKey:key]];
}

- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	NSObject *value = nil;
	switch (domain) {
		case GPGDomain_gpgConf:
			value = [self valueInGPGConfForKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			value = [self valueInGPGAgentConfForKey:key];
			break;
		case GPGDomain_dirmngrConf:
			value = [self valueInDirmngrConfForKey:key];
			break;
		case GPGDomain_standard:
			value = [self valueInStandardDefaultsForKey:key];
			break;
		case GPGDomain_common:
			value = [self valueInCommonDefaultsForKey:key];
			break;
		case GPGDomain_special:
			value = [self specialValueForKey:key];
			break;
		default:
			[NSException raise:NSInvalidArgumentException format:@"Illegal domain: %i", domain]; 
	}
	return value;
}
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	switch (domain) {
		case GPGDomain_gpgConf:
			[self setValueInGPGConf:value forKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			[self setValueInGPGAgentConf:value forKey:key];
			break;
		case GPGDomain_dirmngrConf:
			[self setValueInDirmngrConf:value forKey:key];
			break;
		case GPGDomain_standard:
			[self setValueInStandardDefaults:value forKey:key];
			break;
		case GPGDomain_common:
			[self setValueInCommonDefaults:value forKey:key];
			break;
		case GPGDomain_special:
			[self setSpecialValue:value forKey:key];
			break;
		default:
			[NSException raise:NSInvalidArgumentException format:@"Illegal domain: %i", domain]; 
			break;
	}
}


- (id)specialValueForKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		return [NSNumber numberWithBool:[[self.gpgConf valueForKey:@"trust-model"] isEqualToString:@"always"]];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		return [self valueInGPGAgentConfForKey:@"default-cache-ttl"];
	} else if ([key isEqualToString:@"httpProxy"]) {
		return self.httpProxy;
	} else if ([key isEqualToString:@"keyservers"]) {
		return self.keyservers;
	} else if ([key isEqualToString:@"keyserver"]) {
		return self.keyserver;
	}
	return nil;
}
- (void)setSpecialValue:(id)value forKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		[self.gpgConf setValue:[value intValue] ? @"always" : nil forKey:@"trust-model"];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		NSString *defaultCacheTtl = nil, *maxCacheTtl = nil;
		if (value) {
			int cacheTime = [value intValue];
			defaultCacheTtl = [NSString stringWithFormat:@"%i", cacheTime];
			maxCacheTtl = [NSString stringWithFormat:@"%i", cacheTime * 12];
		}
		
		[self setValueInGPGAgentConf:defaultCacheTtl forKey:@"default-cache-ttl"];
		[self setValueInGPGAgentConf:maxCacheTtl forKey:@"max-cache-ttl"];
		[self setValueInGPGAgentConf:defaultCacheTtl forKey:@"default-cache-ttl-ssh"];
		[self setValueInGPGAgentConf:maxCacheTtl forKey:@"max-cache-ttl-ssh"];
	} else if ([key isEqualToString:@"keyserver"]) {
		self.keyserver = value;
	}
}


- (id)valueInStandardDefaultsForKey:(NSString *)key {
	if (self.standardDefaults) {
		return [self.standardDefaults objectForKey:key];
	} else {
		return [[GPGUserDefaults standardUserDefaults] objectForKey:key];
	}
}
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key {
	if (self.standardDefaults) {
		NSObject *oldValue = [self.standardDefaults objectForKey:key];
		if(value != oldValue && ![value isEqual:oldValue]) {
			if (!value) {
				[self.standardDefaults removeObjectForKey:key];
			} else {
				[self.standardDefaults setObject:value forKey:key];
			}
			if (self.autoSave) [self saveStandardDefaults];
			[self valueChanged:value forKey:key inDomain:GPGDomain_standard];
		}
	} else {
		[[GPGUserDefaults standardUserDefaults] setObject:value forKey:key];
		[self valueChanged:value forKey:key inDomain:GPGDomain_standard];
	}
}
- (void)saveStandardDefaults {
	if (self.standardDefaults) {
		[[GPGUserDefaults standardUserDefaults] setPersistentDomain:self.standardDefaults forName:standardDomain];
	} else {
		[[GPGUserDefaults standardUserDefaults] synchronize];
	}
}
- (NSMutableDictionary *)standardDefaults {
	if (standardDomain) {
		if (!standardDefaults) {
			standardDefaults = [[NSMutableDictionary alloc] initWithDictionary:[[GPGUserDefaults standardUserDefaults] persistentDomainForName:standardDomain]];
		}
		return [[standardDefaults retain] autorelease];
	}
	return nil;
}


- (id)valueInCommonDefaultsForKey:(NSString *)key {
	id value = [self.commonDefaults objectForKey:key];
	if (!value) {
		value = [@{@"UseKeychain": @YES,
				   GPGUseSKSKeyserverAsBackupKey: @YES
				   } valueForKey:key];
	}
	return value;
}
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key {
    NSObject *oldValue = [self.commonDefaults objectForKey:key];
	if(value != oldValue && ![value isEqual:oldValue]) {
		if (!value) {
			[self.commonDefaults removeObjectForKey:key];
		} else {
			[self.commonDefaults setObject:value forKey:key];
		}
		if (self.autoSave) [self saveCommonDefaults];
		[self valueChanged:value forKey:key inDomain:GPGDomain_common];
	}
}
- (void)saveCommonDefaults {
	[[GPGUserDefaults standardUserDefaults] setPersistentDomain:commonDefaults forName:commonDefaultsDomain];
}
- (NSMutableDictionary *)commonDefaults {
	if (!commonDefaults) {
		commonDefaults = [[NSMutableDictionary alloc] initWithDictionary:[[GPGUserDefaults standardUserDefaults] persistentDomainForName:commonDefaultsDomain]];
	}
	return [[commonDefaults retain] autorelease];
}

- (id)valueInGPGConfForKey:(NSString *)key {
	return [self.gpgConf valueForKey:key];
}
- (void)setValueInGPGConf:(id)value forKey:(NSString *)key {
	[self.gpgConf setValue:value forKey:key];
	[self valueChanged:value forKey:key inDomain:GPGDomain_gpgConf];
	
	if (self.autoSave) [self.gpgConf saveConfig];
}

- (id)valueInGPGAgentConfForKey:(NSString *)key {
	return [self.gpgAgentConf valueForKey:key];
}
- (void)setValueInGPGAgentConf:(id)value forKey:(NSString *)key {
	[self.gpgAgentConf setValue:value forKey:key];
	[self valueChanged:value forKey:key inDomain:GPGDomain_gpgAgentConf];
	
	if (self.autoSave) {
		[self.gpgAgentConf saveConfig];
		[self gpgAgentFlush];
	}
}

- (id)valueInDirmngrConfForKey:(NSString *)key {
	return [self.dirmngrConf valueForKey:key];
}
- (void)setValueInDirmngrConf:(id)value forKey:(NSString *)key {
	[self.dirmngrConf setValue:value forKey:key];
	[self valueChanged:value forKey:key inDomain:GPGDomain_dirmngrConf];
	
	if (self.autoSave) {
		[self.dirmngrConf saveConfig];
		[self dirmngrFlush];
	}
}


/*
 * Checks the gpg config, disables invalid options and removes invalid keyserver-options.
 */
- (void)repairGPGConfForce:(BOOL)force {
	static BOOL repaired = NO;
	
	// Do not use dispatch_once here to prevent possible deadlocks.
	if (OSAtomicTestAndSet(0, &repaired) && !force) {
		return;
	}
	
	
	if ([GPGTask sandboxed]) {
		// Can not repair the config from within the sandbox.
		return;
	}
	
	[self pinentryPath];
	
	GPGTask *gpgTask = [GPGTask gpgTaskWithArguments:@[@"--gpgconf-test"]];
	gpgTask.nonBlocking = YES;
	gpgTask.timeout = GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY;
	[gpgTask setEnvironmentVariables:@{@"LANG": @"C"}];
	[gpgTask start];

	
	NSString *errText = gpgTask.errText;
	if (errText.length > 0) {
		BOOL modified = NO;
		NSString *config = [self.gpgConf getContents];
		
		
		// Parse errText and store the indexes of invalid options in indexesToDisable.
		NSMutableIndexSet *indexesToDisable = [NSMutableIndexSet indexSet];
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^.*:(\\d+): .*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
		[regex enumerateMatchesInString:errText options:0 range:NSMakeRange(0, errText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange range = [result rangeAtIndex:1];
			NSInteger line = [[errText substringWithRange:range] integerValue];
			if (line > 0) {
				[indexesToDisable addIndex:line - 1];
			}
		}];
		if (indexesToDisable.count > 0) {
			modified = YES;
			
			// Prepand all invalid lines with "# Disabled: ".
			NSMutableArray *lines = [NSMutableArray arrayWithArray:[config componentsSeparatedByString:@"\n"]];
			[indexesToDisable enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
				NSString *line = [lines objectAtIndex:idx];
				line = [NSString stringWithFormat:@"# Disabled: %@", line];
				[lines replaceObjectAtIndex:idx withObject:line];
			}];
			
			// Save the config.
			config = [lines componentsJoinedByString:@"\n"];
			if (config) {
				[self.gpgConf loadContents:config];
			}
		}
		
		
		// Remove invalid or obsolete keyserver options.
		NSMutableArray *optionsToRemove = [[NSMutableArray new] autorelease];
		regex = [NSRegularExpression regularExpressionWithPattern:@"^.*keyserver option '(.+)' is.*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
		[regex enumerateMatchesInString:errText options:0 range:NSMakeRange(0, errText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange range = [result rangeAtIndex:1];
			[optionsToRemove addObject:[errText substringWithRange:range]];
		}];
		if (optionsToRemove.count > 0) {
			modified = YES;
			
			NSArray *keyserverOptions = [self.gpgConf valueForKey:@"keyserver-options"];
			if ([keyserverOptions isKindOfClass:[NSArray class]]) {
				NSMutableArray *temp = [[keyserverOptions mutableCopy] autorelease];
				[temp removeObjectsInArray:optionsToRemove];
				keyserverOptions = temp;
			} else {
				keyserverOptions = nil;
			}
			
			[self.gpgConf setValue:keyserverOptions forKey:@"keyserver-options"];
		}
		
		if (modified) {
			[self.gpgConf saveConfig];
		}
	}
	
	
	// Use dirmngr.conf only with gpg >= 2.1
	NSArray *parts = [[GPGController gpgVersion] componentsSeparatedByString:@"."];
	if (parts.count >= 2 && (([parts[0] integerValue] == 2 && [parts[1] integerValue] >= 1) || [parts[0] integerValue] > 2)) {
		// Move keyserver option from gpg.conf to dirmngr.conf.
		// Set a default keyserver, if no keyserver is set.
		NSString *keyserver = [self.dirmngrConf valueForKey:@"keyserver"];
		NSString *gpgConfKeyserver = [ self.gpgConf valueForKey:@"keyserver"];
		if (!keyserver || ![keyserver isKindOfClass:[NSString class]]) {
			keyserver = gpgConfKeyserver;
			if (!keyserver || ![keyserver isKindOfClass:[NSString class]]) {
				keyserver = GPG_DEFAULT_KEYSERVER;
			}
			[self.dirmngrConf setValue:keyserver forKey:@"keyserver"];
			[self.dirmngrConf saveConfig];
			[self dirmngrFlush];
		}
		if (gpgConfKeyserver) {
			[self.gpgConf setValue:nil forKey:@"keyserver"];
			[self.gpgConf saveConfig];
		}
	}
	
	
	BOOL gpgConfChanged = NO;
	BOOL autoKeyRetrieve = NO;
	NSMutableArray *keyserverOptions = [[[self.gpgConf valueForKey:@"keyserver-options"] mutableCopy] autorelease];
	if ([keyserverOptions containsObject:@"auto-key-retrieve"]) {
		[keyserverOptions removeObject:@"auto-key-retrieve"];
		autoKeyRetrieve = YES;
		gpgConfChanged = YES;
	}
	if ([keyserverOptions containsObject:@"no-auto-key-retrieve"]) {
		[keyserverOptions removeObject:@"no-auto-key-retrieve"];
		gpgConfChanged = YES;
	}
	if (autoKeyRetrieve) {
		[self.gpgConf setValue:@YES forKey:@"auto-key-retrieve"];
	}
	if (gpgConfChanged) {
		[self.gpgConf setValue:keyserverOptions forKey:@"keyserver-options"];
		[self.gpgConf saveConfig];
	}

}

- (void)repairGPGConf {
	[self repairGPGConfForce:NO];
}



- (void)loadGPGConfDefaults {
	BOOL needSave = NO;
	id value = [gpgConf valueForKey:@"emit-version"];
	
	if (!value) {
		[gpgConf setValue:@(NO) forKey:@"emit-version"];
		needSave = YES;
	}
	
	if (needSave) {
		[gpgConf saveConfig];
	}
}


// Propertys.
- (GPGConf *)gpgConf {
    @synchronized(syncRoot) {
        if (!gpgConf) {
            NSString *gpath = [[self gpgHome] stringByAppendingPathComponent:@"gpg.conf"];
            gpgConf = [[GPGConf alloc] initWithPath:gpath andDomain:GPGDomain_gpgConf];
			[self loadGPGConfDefaults];
        }
        return [[gpgConf retain] autorelease];
    }
}
- (GPGConf *)gpgAgentConf {
	@synchronized(syncRoot) {
		if (!gpgAgentConf) {
			NSString *gpath = [[self gpgHome] stringByAppendingPathComponent:@"gpg-agent.conf"];
			gpgAgentConf = [[GPGConf alloc] initWithPath:gpath andDomain:GPGDomain_gpgAgentConf];
		}
		return [[gpgAgentConf retain] autorelease];
	}
}
- (GPGConf *)dirmngrConf {
	@synchronized(syncRoot) {
		if (!dirmngrConf) {
			NSString *gpath = [[self gpgHome] stringByAppendingPathComponent:@"dirmngr.conf"];
			dirmngrConf = [[GPGConf alloc] initWithPath:gpath andDomain:GPGDomain_dirmngrConf];
		}
		return [[dirmngrConf retain] autorelease];
	}
}

- (NSString *)gpgHome {
	NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@".gnupg"];
	// Find the real path, in case we're sandboxed.
	struct passwd *pw = getpwuid(getuid());
	if(pw != NULL) {
		NSString *realPath = [[NSString stringWithUTF8String:pw->pw_dir] stringByAppendingPathComponent:@".gnupg"];
		if(![path isEqualToString:realPath])
			path = realPath;
	}
	return path;
}


- (NSArray *)keyserversInPlist {
	NSURL *keyserversPlistURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Keyservers" withExtension:@"plist"];
    return [NSArray arrayWithContentsOfURL:keyserversPlistURL];
}

- (NSArray *)keyservers { // Returns a list of possible keyservers.
	NSMutableArray *uniqueServers = [NSMutableArray array];
	
	NSArray *servers = self.keyserversInPlist;
	for (NSString *server in servers) {
		if (![uniqueServers containsObject:server]) {
			[uniqueServers addObject:server];
		}
	}

	
	servers = [self valueInCommonDefaultsForKey:@"keyservers"];
	if ([servers isKindOfClass:[NSArray class]]) {
		for (NSString *server in servers) {
			if (![uniqueServers containsObject:server]) {
				[uniqueServers addObject:server];
			}
		}
	}
	
	
    return uniqueServers;
}
- (void)setKeyservers:(NSArray *)keyservers {
	NSArray *servers = self.keyserversInPlist;
	NSMutableArray *uniqueServers = [NSMutableArray array];
	
	for (NSString *server in servers) {
		if (![servers containsObject:server]) {
			[uniqueServers addObject:server];
		}
	}
	[self setValueInCommonDefaults:uniqueServers forKey:@"keyservers"];
}


+ (BOOL)isVerifyingKeyserver:(NSString *)keyserver {
	NSURL *keyserverURL = [NSURL URLWithString:keyserver];
	if (!keyserverURL.host) {
		keyserverURL = [NSURL URLWithString:[@"hkps://" stringByAppendingString:keyserver]];
	}
	if ([keyserverURL.host isEqualToString:@"keys.openpgp.org"]) {
		return YES;
	}
	return NO;
}
- (BOOL)isVerifyingKeyserver {
	return [self.class isVerifyingKeyserver:self.keyserver];
}
- (NSString *)keyserver {
	return [self valueInDirmngrConfForKey:@"keyserver"];
}
- (void)setKeyserver:(NSString *)keyserver {
	[self setValueInDirmngrConf:keyserver forKey:@"keyserver"];

	// Force dirmngr to reload the config.
	[self dirmngrFlush];

	[self addKeyserver:keyserver];
}
- (void)addKeyserver:(NSString *)keyserver {
	if ([keyserver isKindOfClass:[NSString class]] && [keyserver length] > 1) {
		if (![self.keyserversInPlist containsObject:keyserver]) {
			NSArray *servers = [self valueInCommonDefaultsForKey:@"keyservers"];
			if (![servers containsObject:keyserver]) {
				[self willChangeValueForKey:@"keyservers"];
				NSMutableArray *newServers = [NSMutableArray arrayWithArray:servers];
				[newServers addObject:keyserver];
				[self setValueInCommonDefaults:newServers forKey:@"keyservers"];
				[self didChangeValueForKey:@"keyservers"];
			}
		}
		
	}
}
- (void)removeKeyserver:(NSString *)keyserver {
	if (keyserver) {
		NSArray *servers = [self valueInCommonDefaultsForKey:@"keyservers"];
		if ([servers containsObject:keyserver]) {
			NSMutableArray *newServers = [servers mutableCopy];
			[newServers removeObject:keyserver];
			[self willChangeValueForKey:@"keyservers"];
			[self setValueInCommonDefaults:newServers forKey:@"keyservers"];
			[self didChangeValueForKey:@"keyservers"];
		}
	}
}


- (NSArray *)sksKeyserversInPlist {
	NSURL *keyserversPlistURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"sks-keyservers" withExtension:@"plist"];
	return [NSArray arrayWithContentsOfURL:keyserversPlistURL];
}
- (NSArray *)sksKeyservers {
	NSMutableArray *uniqueServers = [NSMutableArray array];
	
	NSArray *servers = self.sksKeyserversInPlist;
	for (NSString *server in servers) {
		if (![uniqueServers containsObject:server]) {
			[uniqueServers addObject:server];
		}
	}
	
	
	servers = [self valueInCommonDefaultsForKey:@"sks-keyservers"];
	if ([servers isKindOfClass:[NSArray class]]) {
		for (NSString *server in servers) {
			if (![uniqueServers containsObject:server]) {
				[uniqueServers addObject:server];
			}
		}
	}
	
	
	return uniqueServers;
}
- (BOOL)isSKSKeyserver:(NSString *)keyserver {
	NSURL *keyserverURL = [NSURL URLWithString:keyserver];
	if (!keyserverURL.host) {
		// URLWithString only works, if the scheme is given. So add it and try again.
		keyserverURL = [NSURL URLWithString:[@"hkp://" stringByAppendingString:keyserver]];
	}
	NSString *host = keyserverURL.host;
	if (!host) {
		// Not a valid URL, can't test if it is a SKS keyserver.
		return NO;
	}
	host = host.lowercaseString;
	
	if ([keyserverURL.host isEqualToString:@"keys.openpgp.org"]) {
		// This check is an early return in case keys.openpgp.org is used.
		return NO;
	}

	if ([host rangeOfString:@"sks-keyservers.net"].location != NSNotFound) {
		// Is a pool address of sks-keyservers.net
		return YES;
	}
	
	// Now test if the server is in the list of known SKS keyserver.
	NSArray *sksKeyservers = self.sksKeyservers;
	if ([sksKeyservers containsObject:host]) {
		// Yep, it is in the list.
		return YES;
	}
	
	return NO;
}
- (BOOL)isSKSKeyserver {
	return [self isSKSKeyserver:self.keyserver];
}




- (NSString *)httpProxy {
	if (!httpProxy) {
		NSDictionary *proxyConfig = (NSDictionary *)SCDynamicStoreCopyProxies(nil);
		if ([[proxyConfig objectForKey:@"HTTPEnable"] intValue]) {
			httpProxy = [[NSString alloc] initWithFormat:@"%@:%@", [proxyConfig objectForKey:@"HTTPProxy"], [proxyConfig objectForKey:@"HTTPPort"]];
		} else {
			httpProxy = @"";
		}
		CFRelease(proxyConfig);
	}
	return [[httpProxy retain] autorelease];
}

- (BOOL)debugLog {
	if (debugLog < 128) {
		debugLog = [self boolForKey:@"DebugLog"] | 128;
	}
	return debugLog & 127;
}
+ (BOOL)debugLog {
	if (debugLog < 128) {
		[[self sharedOptions] debugLog];
	}
	return debugLog & 127;
}

- (NSString *)pinentryPath {
	if (!_pinentryPath) {
		static NSString * const kPinentry_program = @"pinentry-program";
		
		// MacGPG2 has the default path to pinentry-mac hardcoded
		// so we don't need to force set a path in gpg-agent.conf.
		
		
		// Read pinentry path from gpg-agent.conf.
		
		NSString *pinentryPath = [self valueInGPGAgentConfForKey:kPinentry_program];
		pinentryPath = [pinentryPath stringByStandardizingPath];
		
		if (pinentryPath) {
			NSFileManager *fileManager = [NSFileManager defaultManager];

			// Remove an invalid path from gpg-agent.conf.
			// A pinentry in Libmacgpg is an old version, don't use it anymore.
			if ([pinentryPath rangeOfString:@"/Libmacgpg.framework/"].length > 0 || ![fileManager isExecutableFileAtPath:pinentryPath]) {
				pinentryPath = nil;
				[self setValueInGPGAgentConf:nil forKey:kPinentry_program];
				[self gpgAgentFlush];
			}
		}
		
		if (!pinentryPath) {
			pinentryPath = @"/usr/local/MacGPG2/libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac";
		}

		NSString *temp = _pinentryPath;
		_pinentryPath = [pinentryPath retain];
		[temp release];
	}
	return [[_pinentryPath retain] autorelease];
}


// Helper methods.
- (GPGOptionsDomain)domainForKey:(NSString *)key {
    return [GPGOptions domainForKey:key];
}
+ (GPGOptionsDomain)domainForKey:(NSString *)key {
	for (NSNumber *keyType in domainKeys) {
		NSSet *keys = [domainKeys objectForKey:keyType];
		if ([keys containsObject:key]) {
			return [keyType intValue];
		}
	}
	return GPGDomain_standard;
}

+ (BOOL)isKnownKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
    NSSet *keys = [domainKeys objectForKey:@(domain)];
    return [keys containsObject:key];
}

+ (NSString *)standardizedKey:(NSString *)key {
	if ([key rangeOfString:@"_"].length > 0) {
		return [key stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
	}
	return key;
}

- (void)gpgAgentFlush {
	system("killall -HUP gpg-agent");
}

- (void)gpgAgentTerminate {
	system("killall gpg-agent");
}

- (void)dirmngrFlush {
	system("killall -HUP dirmngr");
}


// Notification handling.
void SystemConfigurationDidChange(SCPreferencesRef prefs, SCPreferencesNotification notificationType, void *info) {
	if (notificationType & kSCPreferencesNotificationApply) {
		[((GPGOptions *)info)->httpProxy release];
		((GPGOptions *)info)->httpProxy = nil;
	}
}
- (void)initSystemConfigurationWatch {
	SCPreferencesContext context = {0, self, nil, nil, nil};
    preferences = SCPreferencesCreate(nil, (CFStringRef)[[NSProcessInfo processInfo] processName], nil);
    SCPreferencesSetCallback(preferences, SystemConfigurationDidChange, &context);
    SCPreferencesScheduleWithRunLoop(preferences, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}	

- (void)stopSystemConfigurationWatch {
    SCPreferencesUnscheduleFromRunLoop(preferences, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    CFRelease(preferences);
}

- (void)valueChanged:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	if (!updating) {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:key, @"key", value, @"value", [NSNumber numberWithInt:domain], @"domain", (domain == GPGDomain_standard && standardDomain) ? standardDomain : nil, @"domainName", nil];
		NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
		[center postNotificationName:GPGOptionsChangedNotification object:identifier userInfo:userInfo options:NSNotificationPostToAllSessions | NSNotificationDeliverImmediately];		
		[self willChangeValueForKey:key];
		[self didChangeValueForKey:key];
	}
}
- (void)valueChangedNotification:(NSNotification *)notification {
	if (self != notification.object && ![identifier isEqualTo:notification.object]) {
		NSDictionary *userInfo = notification.userInfo;
		NSString *key = [userInfo objectForKey:@"key"];
		GPGOptionsDomain domain = [[userInfo objectForKey:@"domain"] intValue];
		
		if (domain == GPGDomain_standard && (!standardDomain || ![[userInfo objectForKey:@"domainName"] isEqualToString:standardDomain])) {
			if (![userInfo objectForKey:@"domainName"] && !standardDomain) {
				// Hack for [NSUserDefaults standardUserDefaults]
				[self willChangeValueForKey:key];
				[self didChangeValueForKey:key];
			}
			return;
		}
		
		BOOL oldAutoSave = self.autoSave;
		self.autoSave = NO;
		updating++;
		[self willChangeValueForKey:key];
		[self setValue:[userInfo objectForKey:@"value"] forKey:key inDomain:domain];
		[self didChangeValueForKey:key];
		updating--;
		self.autoSave = oldAutoSave;
	}
}

- (void)dotConfChangedNotification:(NSNotification *)notification {
    [self willChangeValueForKey:kGpgConfKVKey];
	[self willChangeValueForKey:kGpgAgentConfKVKey];
	[self willChangeValueForKey:kDirmngrConfKVKey];
    @synchronized(syncRoot) {
        [gpgConf release];
        gpgConf = nil;
		[gpgAgentConf release];
		gpgAgentConf = nil;
		[dirmngrConf release];
		dirmngrConf = nil;
    }
    [self didChangeValueForKey:kGpgConfKVKey];
	[self didChangeValueForKey:kGpgAgentConfKVKey];
	[self didChangeValueForKey:kDirmngrConfKVKey];
}

// Whatever…
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {

    NSMutableSet *keyPaths = [NSMutableSet setWithSet:[super keyPathsForValuesAffectingValueForKey:key]];
    // standard key will always be set; affectingKey may be set
    NSString *standardKey = key;
	NSString *affectingKey = nil;
	if ([key rangeOfString:@"_"].length > 0) {
		NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_"] invertedSet];
		if ([key rangeOfCharacterFromSet:set].length == 0) {
			affectingKey = [self standardizedKey:key];
		}
	}
	if (!affectingKey) {
		if ([key isEqualToString:@"TrustAllKeys"]) {
			affectingKey = @"trust-model";
		} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
			affectingKey = @"default-cache-ttl";
			affectingKey = @"default-cache-ttl-ssh";
			affectingKey = @"max-cache-ttl";
			affectingKey = @"max-cache-ttl-ssh";
		}
	}
	if (affectingKey) {
		[keyPaths addObject:affectingKey];
		standardKey = affectingKey;
	}

    // .conf dependents
    switch ([GPGOptions domainForKey:standardKey]) {
        case GPGDomain_gpgConf:
            [keyPaths addObject:kGpgConfKVKey];
            break;
		case GPGDomain_gpgAgentConf:
			[keyPaths addObject:kGpgAgentConfKVKey];
			break;
		case GPGDomain_dirmngrConf:
			[keyPaths addObject:kDirmngrConfKVKey];
			break;
        default:
            // nothing
            break;
    }

    return keyPaths;
}



// Alloc, init etc.
+ (void)initialize {
	static BOOL initialized = NO;
	if (initialized) {
		// Prevent double initialization.
		return;
	}
	initialized = YES;

    NSSet *gpgConfKeys = [NSSet setWithObjects:@"agent-program", @"allow-freeform-uid",
                          @"allow-multiple-messages", @"allow-multisig-verification",
                          @"allow-non-selfsigned-uid", @"allow-secret-key-import",
                          @"always-trust", @"armor", @"armour", @"ask-cert-expire",
                          @"ask-cert-level", @"ask-sig-expire", @"attribute-fd",
                          @"attribute-file", @"auto-check-trustdb", @"auto-key-locate",
                          @"auto-key-retrieve", @"bzip2-compress-level",
                          @"bzip2-decompress-lowmem", @"cert-digest-algo", @"cert-notation",
                          @"cert-policy-url", @"charset", @"check-sig", @"cipher-algo",
                          @"command-fd", @"command-file", @"comment", @"completes-needed",
                          @"compress-algo", @"compress-keys", @"compress-level",
                          @"compress-sigs", @"compression-algo", @"debug-quick-random",
                          @"default-cert-check-level", @"default-cert-expire",
                          @"default-cert-level", @"default-comment", @"default-key",
                          @"default-keyserver-url", @"default-preference-list",
                          @"default-recipient", @"default-recipient-self",
                          @"default-sig-expire", @"digest-algo", @"disable-cipher-algo",
                          @"disable-dsa2", @"disable-mdc", @"disable-pubkey-algo",
                          @"display-charset", @"dry-run", @"emit-version", @"enable-dsa2",
                          @"enable-progress-filter", @"enable-special-filenames",
                          @"encrypt-to", @"escape-from-lines", @"exec-path",
                          @"exit-on-status-write-error", @"expert", @"export-options",
                          @"fast-list-mode", @"fixed-list-mode", @"for-your-eyes-only",
                          @"force-mdc", @"force-ownertrust", @"force-v3-sigs",
                          @"force-v4-certs", @"gnupg", @"gpg-agent-info", @"group",
                          @"hidden-encrypt-to", @"hidden-recipient", @"honor-http-proxy",
                          @"ignore-crc-error", @"ignore-mdc-error", @"ignore-time-conflict",
                          @"ignore-valid-from", @"import-options", @"interactive",
                          @"keyid-format", @"keyring"/*, @"keyserver"*/, @"keyserver-options",
                          @"limit-card-insert-tries", @"list-key", @"list-only",
                          @"list-options", @"list-sig", @"load-extension", @"local-user",
                          @"lock-multiple", @"lock-never", @"lock-once", @"logger-fd",
                          @"logger-file", @"mangle-dos-filenames", @"marginals-needed",
                          @"max-cert-depth", @"max-output", @"merge-only", @"min-cert-level",
                          @"multifile", @"no", @"no-allow-freeform-uid",
                          @"no-allow-multiple-messages", @"no-allow-non-selfsigned-uid",
                          @"no-armor", @"no-armour", @"no-ask-cert-expire",
                          @"no-ask-cert-level", @"no-ask-sig-expire",
                          @"no-auto-check-trustdb", @"no-auto-key-locate",
                          @"no-auto-key-retrieve", @"no-batch", @"no-comments",
                          @"no-default-keyring", @"no-default-recipient", @"no-disable-mdc",
                          @"no-emit-version", @"no-encrypt-to", @"no-escape-from-lines",
                          @"no-expensive-trust-checks", @"no-expert",
                          @"no-for-your-eyes-only", @"no-force-mdc", @"no-force-v3-sigs",
                          @"no-force-v4-certs", @"no-greeting", @"no-groups", @"no-literal",
                          @"no-mangle-dos-filenames", @"no-mdc-warning", @"no-options",
                          @"no-permission-warning", @"no-pgp2", @"no-pgp6", @"no-pgp7",
                          @"no-pgp8", @"no-random-seed-file", @"no-require-backsigs",
                          @"no-require-cross-certification", @"no-require-secmem",
                          @"no-rfc2440-text", @"no-secmem-warning", @"no-show-notation",
                          @"no-show-photos", @"no-show-policy-url", @"no-sig-cache",
                          @"no-sig-create-check", @"no-sk-comments",
                          @"no-skip-hidden-recipients", @"no-strict", @"no-textmode",
                          @"no-throw-keyid", @"no-throw-keyids", @"no-tty", @"no-use-agent",
                          @"no-use-embedded-filename", @"no-utf8-strings", @"no-verbose",
                          @"no-version", @"not-dash-escaped", @"notation-data", @"openpgp",
                          @"output", @"override-session-key", @"passphrase", @"passphrase-fd",
                          @"passphrase-file", @"passphrase-repeat",
                          @"personal-cipher-preferences", @"personal-cipher-prefs",
                          @"personal-compress-preferences", @"personal-compress-prefs",
                          @"personal-digest-preferences", @"personal-digest-prefs", @"pgp2",
                          @"pgp6", @"pgp7", @"pgp8", @"photo-viewer", @"preserve-permissions",
                          @"primary-keyring", @"recipient", @"remote-user",
                          @"require-backsigs", @"require-cross-certification",
                          @"require-secmem", @"rfc1991", @"rfc2440", @"rfc2440-text",
                          @"rfc4880", @"s2k-cipher-algo", @"s2k-count", @"s2k-digest-algo",
                          @"s2k-mode", @"secret-keyring", @"set-filename", @"set-filesize",
                          @"set-notation", @"set-policy-url", @"show-keyring",
                          @"show-notation", @"show-photos", @"show-policy-url",
                          @"show-session-key", @"sig-keyserver-url", @"sig-notation",
                          @"sig-policy-url", @"sign-with", @"simple-sk-checksum",
                          @"sk-comments", @"skip-hidden-recipients", @"skip-verify",
                          @"status-fd", @"status-file", @"strict", @"temp-directory",
                          @"textmode", @"throw-keyid", @"throw-keyids", @"trust-model",
                          @"trustdb-name", @"trusted-key", @"try-all-secrets", @"ungroup",
                          @"use-agent", @"use-embedded-filename", @"user", @"utf8-strings",
                          @"verify-options", @"with-colons", @"with-fingerprint",
                          @"with-key-data", @"with-sig-check", @"with-sig-list", @"yes", nil];
    
    NSSet *gpgAgentConfKeys = [NSSet setWithObjects:@"allow-mark-trusted",
                               @"allow-preset-passphrase", @"check-passphrase-pattern", @"csh",
                               @"daemon", @"debug-wait", @"default-cache-ttl",
                               @"default-cache-ttl-ssh", @"disable-scdaemon",
                               @"enable-passphrase-history", @"enable-ssh-support",
                               @"enforce-passphrase-constraints", @"faked-system-time",
                               @"ignore-cache-for-signing", @"keep-display", @"keep-tty",
                               @"max-cache-ttl", @"max-cache-ttl-ssh", @"max-passphrase-days",
                               @"min-passphrase-len", @"min-passphrase-nonalpha", @"no-detach",
                               @"no-grab", @"no-use-standard-socket", @"pinentry-program",
                               @"pinentry-touch-file", @"scdaemon-program", @"server", @"sh",
                               @"use-standard-socket", @"write-env-file", nil];
	
	NSSet *dirmngrConfKeys = [NSSet setWithObjects:@"nameserver", nil];

	
    NSSet *commonKeys = [NSSet setWithObjects:@"PathToGPG", @"ShowPassphrase",
                         @"UseKeychain", @"DisableKeychain", @"DebugLog",
						 GPGKeysFromVerifyingKeyserverKey, GPGUseSKSKeyserverAsBackupKey, nil];
    
    NSSet *specialKeys = [NSSet setWithObjects:@"httpProxy", @"keyservers",
                          @"PassphraseCacheTime", @"TrustAllKeys", @"keyserver", nil];
    					
	domainKeys = [[NSDictionary alloc] initWithObjectsAndKeys:
				  gpgConfKeys, [NSNumber numberWithInt:GPGDomain_gpgConf], 
				  gpgAgentConfKeys, [NSNumber numberWithInt:GPGDomain_gpgAgentConf],
				  dirmngrConfKeys, [NSNumber numberWithInt:GPGDomain_dirmngrConf],
				  commonKeys, [NSNumber numberWithInt:GPGDomain_common],
				  specialKeys, [NSNumber numberWithInt:GPGDomain_special],				  
				  nil];
	
	
	// Do not activate the GPGWatcher from within this method to prevent a possible deadlock.
	[[GPGWatcher class] performSelectorOnMainThread:@selector(activate) withObject:nil waitUntilDone:NO];
}

+ (instancetype)sharedOptions {
    static dispatch_once_t onceToken;
    static GPGOptions *_sharedInstance = nil;

    dispatch_once(&onceToken, ^{
        _sharedInstance = [[GPGOptions alloc] init];
    });
	[_sharedInstance repairGPGConfForce:NO];

    return _sharedInstance;
}
- (id)init {
	self = [super init];
    if(self) {
        syncRoot = [[NSObject alloc] init];
        autoSave = YES;
        identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];
        NSDistributedNotificationCenter *notifsCenter = [NSDistributedNotificationCenter defaultCenter];
        [notifsCenter addObserver:self selector:@selector(valueChangedNotification:) name:GPGOptionsChangedNotification object:nil];
        [notifsCenter addObserver:self selector:@selector(dotConfChangedNotification:) name:GPGConfigurationModifiedNotification object:nil];
        [self initSystemConfigurationWatch];
		debugLog = [self boolForKey:@"DebugLog"] | 128;
	}
	return self;
}

- (void)dealloc 
{
    NSDistributedNotificationCenter *notifsCenter = [NSDistributedNotificationCenter defaultCenter];
    [notifsCenter removeObserver:self];
    [self stopSystemConfigurationWatch];

    [identifier release];
	[standardDefaults release];
	[commonDefaults release];
	[httpProxy release];
	[standardDomain release];
	[gpgConf release];
	[gpgAgentConf release];
	[dirmngrConf release];
    [syncRoot release];
	[_pinentryPath release];
    [super dealloc];
}

@end
